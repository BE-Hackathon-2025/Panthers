"""Swap request management endpoints."""

from typing import Optional, List
from datetime import datetime
from fastapi import APIRouter, HTTPException, Query

from app.schemas import (
    SwapRequestCreate,
    SwapRequestResponse,
    SwapRequestAction,
    SwapRequestStatus,
    SwapParticipant,
    SwapConfirmRequest,
    ConversationStatus,
)
from app.cosmos_db import get_cosmos_service
from app.email_service import get_email_service
from app.routers.points import award_swap_points

router = APIRouter(prefix="/swap-requests", tags=["swap-requests"])


def _get_participant_profile(uid: str) -> Optional[SwapParticipant]:
    """Get minimal profile info for a swap participant."""
    cosmos = get_cosmos_service()
    profile = cosmos.get_profile(uid)
    if not profile:
        return None
    return SwapParticipant(
        uid=profile.get("uid", uid),
        display_name=profile.get("display_name"),
        photo_url=profile.get("photo_url"),
        email=profile.get("email"),
        skills_to_offer=profile.get("skills_to_offer"),
        services_needed=profile.get("services_needed"),
    )


def _convert_timestamps(data: dict) -> dict:
    """Ensure timestamp fields are ISO strings."""
    for field in ["created_at", "updated_at", "responded_at"]:
        if field in data and data[field]:
            if hasattr(data[field], "isoformat"):
                data[field] = data[field].isoformat()
            elif not isinstance(data[field], str):
                data[field] = str(data[field])
    return data


def _enrich_swap_request(request_data: dict) -> SwapRequestResponse:
    """Enrich swap request with participant profiles."""
    request_data = _convert_timestamps(request_data)
    requester_profile = _get_participant_profile(request_data["requester_uid"])
    recipient_profile = _get_participant_profile(request_data["recipient_uid"])
    return SwapRequestResponse(
        **request_data,
        requester_profile=requester_profile,
        recipient_profile=recipient_profile,
    )


@router.post("", response_model=SwapRequestResponse)
def create_swap_request(
    request: SwapRequestCreate,
    requester_uid: str = Query(..., description="UID of the requester"),
):
    """
    Create a new swap request.

    - Creates a pending swap request in Cosmos DB
    - Sends email notification to recipient if email_updates enabled
    - Returns the created request with participant profiles
    """
    cosmos = get_cosmos_service()
    email_service = get_email_service()

    if requester_uid == request.recipient_uid:
        raise HTTPException(status_code=400, detail="Cannot send swap request to yourself")

    if cosmos.check_blocked(requester_uid, request.recipient_uid):
        raise HTTPException(status_code=403, detail="Cannot send request to this user")

    recipient_profile = cosmos.get_profile(request.recipient_uid)
    if not recipient_profile:
        raise HTTPException(status_code=404, detail="Recipient not found")

    if cosmos.check_pending_request_exists(requester_uid, request.recipient_uid):
        raise HTTPException(status_code=400, detail="You already have a pending request to this user")

    now = datetime.utcnow().isoformat()
    request_doc = cosmos.create_swap_request(
        requester_uid=requester_uid,
        data={
            "requester_uid": requester_uid,
            "recipient_uid": request.recipient_uid,
            "status": SwapRequestStatus.pending.value,
            "requester_offer": request.requester_offer,
            "requester_need": request.requester_need,
            "message": request.message,
            "responded_at": None,
            "conversation_id": None,
            "requester_confirmed": False,
            "recipient_confirmed": False,
            "requester_offer_skill_id": request.requester_offer_skill_id,
            "requester_need_skill_id": request.requester_need_skill_id,
        },
    )

    requester_profile = cosmos.get_profile(requester_uid)
    if recipient_profile.get("email_updates", True) and recipient_profile.get("email"):
        email_service.send_swap_request_notification(
            to_email=recipient_profile["email"],
            recipient_name=recipient_profile.get("display_name", "there"),
            requester_name=requester_profile.get("display_name", "Someone") if requester_profile else "Someone",
            requester_offers=request.requester_offer,
            requester_needs=request.requester_need,
            message=request.message,
            request_id=request_doc["id"],
        )

    return _enrich_swap_request(request_doc)


@router.get("/incoming", response_model=List[SwapRequestResponse])
def get_incoming_requests(
    uid: str = Query(..., description="UID of the user"),
    status: Optional[SwapRequestStatus] = Query(None, description="Filter by status"),
):
    """Get swap requests sent TO the user (they are the recipient)."""
    cosmos = get_cosmos_service()
    items = cosmos.query_incoming_requests(
        recipient_uid=uid,
        status=status.value if status else None,
    )
    return [_enrich_swap_request(item) for item in items]


@router.get("/outgoing", response_model=List[SwapRequestResponse])
def get_outgoing_requests(
    uid: str = Query(..., description="UID of the user"),
    status: Optional[SwapRequestStatus] = Query(None, description="Filter by status"),
):
    """Get swap requests sent BY the user (they are the requester)."""
    cosmos = get_cosmos_service()
    items = cosmos.query_outgoing_requests(
        requester_uid=uid,
        status=status.value if status else None,
    )
    return [_enrich_swap_request(item) for item in items]


@router.post("/{request_id}/respond", response_model=SwapRequestResponse)
def respond_to_request(
    request_id: str,
    action: SwapRequestAction,
    uid: str = Query(..., description="UID of the responding user"),
):
    """
    Accept or decline a swap request.

    - Only the recipient can respond
    - If accepted: creates a conversation and updates the request
    - Sends email notification to the requester about the decision
    """
    cosmos = get_cosmos_service()
    email_service = get_email_service()

    request_data = cosmos.get_swap_request_by_id(request_id)
    if not request_data:
        raise HTTPException(status_code=404, detail="Swap request not found")

    if request_data["recipient_uid"] != uid:
        raise HTTPException(status_code=403, detail="Only the recipient can respond to this request")

    if request_data["status"] != SwapRequestStatus.pending.value:
        raise HTTPException(status_code=400, detail="This request has already been responded to")

    now = datetime.utcnow().isoformat()
    conversation_id = None

    if action.action == "accept":
        participant_uids = sorted([request_data["requester_uid"], request_data["recipient_uid"]])
        conv = cosmos.create_conversation(
            data={
                "participant_uids": participant_uids,
                "swap_request_id": request_id,
                "last_message": None,
                "unread_counts": {
                    request_data["requester_uid"]: 0,
                    request_data["recipient_uid"]: 0,
                },
                "status": ConversationStatus.active.value,
            }
        )
        conversation_id = conv["id"]

        cosmos.create_message(
            conversation_id=conversation_id,
            data={
                "sender_uid": "system",
                "content": "Swap accepted! You can now start chatting.",
                "sent_at": now,
                "read_at": None,
                "read_by": [],
                "type": "system",
            },
        )
        new_status = SwapRequestStatus.accepted.value
    else:
        new_status = SwapRequestStatus.declined.value

    updated = cosmos.update_swap_request(
        request_id=request_id,
        requester_uid=request_data["requester_uid"],
        update_data={
            "status": new_status,
            "responded_at": now,
            "conversation_id": conversation_id,
        },
    )

    requester_profile = cosmos.get_profile(request_data["requester_uid"])
    recipient_profile = cosmos.get_profile(uid)

    if requester_profile and requester_profile.get("email_updates", True) and requester_profile.get("email"):
        email_service.send_swap_response_notification(
            to_email=requester_profile["email"],
            requester_name=requester_profile.get("display_name", "there"),
            recipient_name=recipient_profile.get("display_name", "Someone") if recipient_profile else "Someone",
            accepted=(action.action == "accept"),
            conversation_id=conversation_id,
        )

    return _enrich_swap_request(updated)


@router.delete("/{request_id}")
def cancel_request(
    request_id: str,
    uid: str = Query(..., description="UID of the user cancelling"),
):
    """Cancel a pending swap request. Only the requester can cancel."""
    cosmos = get_cosmos_service()

    request_data = cosmos.get_swap_request_by_id(request_id)
    if not request_data:
        raise HTTPException(status_code=404, detail="Swap request not found")

    if request_data["requester_uid"] != uid:
        raise HTTPException(status_code=403, detail="Only the requester can cancel this request")

    if request_data["status"] != SwapRequestStatus.pending.value:
        raise HTTPException(status_code=400, detail="Can only cancel pending requests")

    cosmos.update_swap_request(
        request_id=request_id,
        requester_uid=uid,
        update_data={"status": SwapRequestStatus.cancelled.value},
    )

    return {"message": "Swap request cancelled", "id": request_id}


@router.get("/{request_id}", response_model=SwapRequestResponse)
def get_swap_request(
    request_id: str,
    uid: str = Query(..., description="UID of the requesting user"),
):
    """Get a specific swap request by ID."""
    cosmos = get_cosmos_service()

    request_data = cosmos.get_swap_request_by_id(request_id)
    if not request_data:
        raise HTTPException(status_code=404, detail="Swap request not found")

    if uid not in [request_data["requester_uid"], request_data["recipient_uid"]]:
        raise HTTPException(status_code=403, detail="Not authorized to view this request")

    return _enrich_swap_request(request_data)


@router.post("/{request_id}/confirm-completion", response_model=SwapRequestResponse)
def confirm_completion(
    request_id: str,
    confirmation: SwapConfirmRequest,
    uid: str = Query(..., description="UID of the confirming user"),
):
    """
    Confirm swap completion. Both participants must confirm before points are awarded.

    1. Validates user is a participant and status is accepted
    2. Marks the caller's side as confirmed
    3. If BOTH confirmed: awards points, marks status=completed, sends system messages
    4. Returns updated swap request
    """
    cosmos = get_cosmos_service()

    swap_req = cosmos.get_swap_request_by_id(request_id)
    if not swap_req:
        raise HTTPException(status_code=404, detail="Swap request not found")

    requester_uid = swap_req["requester_uid"]
    recipient_uid = swap_req["recipient_uid"]

    if uid not in [requester_uid, recipient_uid]:
        raise HTTPException(status_code=403, detail="Not a participant in this swap")

    if swap_req["status"] != SwapRequestStatus.accepted.value:
        raise HTTPException(
            status_code=400,
            detail=f"Can only complete accepted swaps (current status: {swap_req['status']})",
        )

    # Determine which side is confirming
    is_requester = uid == requester_uid
    confirm_field = "requester_confirmed" if is_requester else "recipient_confirmed"

    if swap_req.get(confirm_field, False):
        raise HTTPException(status_code=400, detail="You have already confirmed completion")

    update_data = {confirm_field: True}

    # Check if the OTHER side has already confirmed
    other_field = "recipient_confirmed" if is_requester else "requester_confirmed"
    both_confirmed = swap_req.get(other_field, False)

    conversation_id = swap_req.get("conversation_id")

    if both_confirmed:
        # BOTH confirmed — award points and mark completed
        points_earned = award_swap_points(
            cosmos,
            request_id=request_id,
            requester_uid=requester_uid,
            recipient_uid=recipient_uid,
            hours=confirmation.hours,
            skill_level=confirmation.skill_level,
            notes=confirmation.notes,
        )
        update_data["status"] = SwapRequestStatus.completed.value

        # Send system messages
        if conversation_id:
            now = datetime.utcnow().isoformat()
            cosmos.create_message(
                conversation_id=conversation_id,
                data={
                    "sender_uid": "system",
                    "content": f"Both parties confirmed! Swap completed — {points_earned} points awarded to each.",
                    "sent_at": now,
                    "read_at": None,
                    "read_by": [],
                    "type": "system",
                },
            )
    else:
        # First confirmation — send system message
        if conversation_id:
            confirmer_profile = cosmos.get_profile(uid)
            confirmer_name = (confirmer_profile or {}).get("display_name", "A participant")
            now = datetime.utcnow().isoformat()
            cosmos.create_message(
                conversation_id=conversation_id,
                data={
                    "sender_uid": "system",
                    "content": f"{confirmer_name} has confirmed the swap is complete.",
                    "sent_at": now,
                    "read_at": None,
                    "read_by": [],
                    "type": "system",
                },
            )

    updated = cosmos.update_swap_request(
        request_id=request_id,
        requester_uid=requester_uid,
        update_data=update_data,
    )

    return _enrich_swap_request(updated)
