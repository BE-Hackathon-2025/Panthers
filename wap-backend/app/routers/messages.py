"""Messaging endpoints for conversations and messages."""

from typing import Optional, List
from datetime import datetime
from fastapi import APIRouter, HTTPException, Query

from app.schemas import (
    MessageCreate,
    MessageResponse,
    ConversationResponse,
    ConversationListResponse,
    ConversationStatus,
    LastMessage,
    OtherParticipant,
    SwapRequestStatus,
    MessageType,
)
from app.cosmos_db import get_cosmos_service
from app.email_service import get_email_service
from app.cache import get_cache_service

router = APIRouter(prefix="/conversations", tags=["messaging"])


def _convert_timestamp(value) -> Optional[str]:
    """Convert a timestamp to ISO string."""
    if value is None:
        return None
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _get_other_participant(participant_uids: List[str], current_uid: str) -> Optional[OtherParticipant]:
    """Get the other participant's profile info."""
    other_uid = next((uid for uid in participant_uids if uid != current_uid), None)
    if not other_uid:
        return None
    cosmos = get_cosmos_service()
    profile = cosmos.get_profile(other_uid)
    if not profile:
        return None
    return OtherParticipant(
        uid=other_uid,
        display_name=profile.get("display_name"),
        photo_url=profile.get("photo_url"),
        skills_to_offer=profile.get("skills_to_offer"),
    )


def _build_conversation_response(data: dict, uid: str) -> ConversationResponse:
    """Build a ConversationResponse from a Cosmos document."""
    unread_counts = data.get("unread_counts", {})
    unread_count = unread_counts.get(uid, 0)

    last_message = None
    if data.get("last_message"):
        lm = data["last_message"]
        last_message = LastMessage(
            content=lm.get("content", ""),
            sender_uid=lm.get("sender_uid", ""),
            sent_at=_convert_timestamp(lm.get("sent_at")) or datetime.utcnow().isoformat(),
        )

    other_participant = _get_other_participant(data.get("participant_uids", []), uid)

    return ConversationResponse(
        id=data["id"],
        participant_uids=data.get("participant_uids", []),
        swap_request_id=data.get("swap_request_id", ""),
        created_at=_convert_timestamp(data.get("created_at")) or datetime.utcnow().isoformat(),
        updated_at=_convert_timestamp(data.get("updated_at")) or datetime.utcnow().isoformat(),
        last_message=last_message,
        unread_count=unread_count,
        status=ConversationStatus(data.get("status", "active")),
        other_participant=other_participant,
    )


@router.get("", response_model=ConversationListResponse)
def list_conversations(
    uid: str = Query(..., description="UID of the user"),
    limit: int = Query(20, ge=1, le=50, description="Max conversations to return"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
):
    """
    List all conversations for a user.

    - Returns conversations sorted by updated_at (most recent first)
    - Includes last message preview and unread count
    - Enriches with other participant's profile info
    - Excludes blocked conversations
    """
    cosmos = get_cosmos_service()
    all_docs = cosmos.query_conversations_for_user(uid)

    # Filter to active conversations only
    active = [d for d in all_docs if d.get("status") == ConversationStatus.active.value]

    # Sort by updated_at descending
    active.sort(key=lambda d: d.get("updated_at", ""), reverse=True)

    total = len(active)
    paginated = active[offset: offset + limit]
    has_more = (offset + limit) < total

    conversations = [_build_conversation_response(d, uid) for d in paginated]

    return ConversationListResponse(conversations=conversations, total=total, has_more=has_more)


@router.get("/unread-count")
def get_total_unread(uid: str = Query(..., description="UID of the user")):
    """Get total unread message count across all conversations."""
    cosmos = get_cosmos_service()
    all_docs = cosmos.query_conversations_for_user(uid)

    total_unread = sum(
        d.get("unread_counts", {}).get(uid, 0)
        for d in all_docs
        if d.get("status") == ConversationStatus.active.value
    )
    return {"total_unread": total_unread}


@router.get("/{conversation_id}", response_model=ConversationResponse)
def get_conversation(
    conversation_id: str,
    uid: str = Query(..., description="UID of the requesting user"),
):
    """Get a single conversation by ID."""
    cosmos = get_cosmos_service()

    data = cosmos.get_conversation(conversation_id)
    if not data:
        raise HTTPException(status_code=404, detail="Conversation not found")

    if uid not in data.get("participant_uids", []):
        raise HTTPException(status_code=403, detail="Not authorized to view this conversation")

    return _build_conversation_response(data, uid)


@router.get("/{conversation_id}/messages", response_model=List[MessageResponse])
def get_messages(
    conversation_id: str,
    uid: str = Query(..., description="UID of the requesting user"),
    limit: int = Query(50, ge=1, le=100, description="Max messages to return"),
    before: Optional[str] = Query(None, description="Cursor: get messages before this timestamp (ISO format)"),
):
    """
    Get messages in a conversation with cursor pagination.

    - Returns messages sorted by sent_at descending (newest first)
    - Use 'before' parameter for pagination (pass the oldest message's sent_at)
    """
    cosmos = get_cosmos_service()

    conv = cosmos.get_conversation(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if uid not in conv.get("participant_uids", []):
        raise HTTPException(status_code=403, detail="Not authorized to view this conversation")

    messages = cosmos.get_messages(conversation_id, limit=limit, before=before)

    return [
        MessageResponse(
            id=m["id"],
            conversation_id=conversation_id,
            sender_uid=m.get("sender_uid", ""),
            content=m.get("content", ""),
            sent_at=_convert_timestamp(m.get("sent_at")) or datetime.utcnow().isoformat(),
            read_at=_convert_timestamp(m.get("read_at")),
            read_by=m.get("read_by", []),
            type=MessageType(m.get("type", "text")),
        )
        for m in messages
    ]


@router.post("/{conversation_id}/messages", response_model=MessageResponse)
def send_message(
    conversation_id: str,
    message: MessageCreate,
    uid: str = Query(..., description="UID of the sender"),
):
    """
    Send a message in a conversation.

    - Validates user is a participant
    - Validates conversation is active
    - Validates associated swap request is accepted
    - Updates conversation's last_message and unread_counts
    - Sends email notification to recipient
    """
    cosmos = get_cosmos_service()
    email_service = get_email_service()

    conv = cosmos.get_conversation(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    if uid not in conv.get("participant_uids", []):
        raise HTTPException(status_code=403, detail="Not a participant in this conversation")

    if conv.get("status") == ConversationStatus.blocked.value:
        raise HTTPException(status_code=403, detail="This conversation has been blocked")

    # Validate swap request is still accepted
    swap_request_id = conv.get("swap_request_id")
    if swap_request_id:
        swap = cosmos.get_swap_request_by_id(swap_request_id)
        if swap and swap.get("status") != SwapRequestStatus.accepted.value:
            raise HTTPException(status_code=403, detail="Swap request is no longer accepted")

    now = datetime.utcnow().isoformat()

    msg = cosmos.create_message(
        conversation_id=conversation_id,
        data={
            "sender_uid": uid,
            "content": message.content,
            "sent_at": now,
            "read_at": None,
            "read_by": [uid],
            "type": MessageType.text.value,
        },
    )

    # Update conversation unread counts + last_message
    participant_uids = conv.get("participant_uids", [])
    other_uid = next((u for u in participant_uids if u != uid), None)

    unread_counts = dict(conv.get("unread_counts", {}))
    if other_uid:
        unread_counts[other_uid] = unread_counts.get(other_uid, 0) + 1

    cosmos.update_conversation(
        conversation_id=conversation_id,
        update_data={
            "last_message": {
                "content": message.content[:100],
                "sender_uid": uid,
                "sent_at": now,
            },
            "unread_counts": unread_counts,
        },
    )

    # Email notification to other participant
    if other_uid:
        other_profile = cosmos.get_profile(other_uid)
        sender_profile = cosmos.get_profile(uid)
        if other_profile and other_profile.get("email_updates", True) and other_profile.get("email"):
            email_service.send_new_message_notification(
                to_email=other_profile["email"],
                recipient_uid=other_uid,
                recipient_name=other_profile.get("display_name", "there"),
                sender_name=sender_profile.get("display_name", "Someone") if sender_profile else "Someone",
                message_preview=message.content[:100],
                conversation_id=conversation_id,
            )

    return MessageResponse(
        id=msg["id"],
        conversation_id=conversation_id,
        sender_uid=uid,
        content=message.content,
        sent_at=now,
        read_at=None,
        read_by=[uid],
        type=MessageType.text,
    )


@router.post("/{conversation_id}/mark-read")
def mark_conversation_read(
    conversation_id: str,
    uid: str = Query(..., description="UID of the user"),
):
    """
    Mark all messages in a conversation as read by this user.

    - Updates all unread messages with read_at and read_by
    - Resets unread_count for this user to 0
    """
    cosmos = get_cosmos_service()

    conv = cosmos.get_conversation(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    if uid not in conv.get("participant_uids", []):
        raise HTTPException(status_code=403, detail="Not authorized")

    now = datetime.utcnow().isoformat()

    all_messages = cosmos.get_all_messages_in_conversation(conversation_id)
    for msg in all_messages:
        read_by = msg.get("read_by", [])
        if uid not in read_by and msg.get("sender_uid") != uid:
            cosmos.update_message(
                conversation_id=conversation_id,
                message_id=msg["id"],
                data={"read_by": read_by + [uid], "read_at": now},
            )

    unread_counts = dict(conv.get("unread_counts", {}))
    unread_counts[uid] = 0
    cosmos.update_conversation(conversation_id, {"unread_counts": unread_counts})

    return {"message": "Marked as read", "conversation_id": conversation_id}
