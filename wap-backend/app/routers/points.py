"""Points and credits system for skill swaps."""

from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, HTTPException, Query

from app.schemas import (
    SwapCompletionRequest,
    PointsTransactionResponse,
    PointsBalanceResponse,
    PointsSpendRequest,
    PointsTransactionType,
    PointsTransactionReason,
    SkillLevel,
    SwapRequestStatus,
)
from app.cosmos_db import get_cosmos_service

router = APIRouter(prefix="/points", tags=["points"])

# ── Points calculation ──────────────────────────────────────────────────────

_SKILL_LEVEL_MULTIPLIERS = {
    SkillLevel.beginner: 0.75,
    SkillLevel.intermediate: 1.0,
    SkillLevel.advanced: 1.25,
}

_BASE_POINTS_PER_HOUR = 10
_BASE_CREDITS_PER_HOUR = 10

# ── Spending costs ──────────────────────────────────────────────────────────

_PRIORITY_BOOST_COST = 5  # points per hour of boost
_REQUEST_WITHOUT_RECIPROCITY_COST = 50  # flat points cost


def calculate_points(hours: float, skill_level: SkillLevel) -> int:
    """Calculate points earned from a completed swap."""
    multiplier = _SKILL_LEVEL_MULTIPLIERS.get(skill_level, 1.0)
    return max(1, int(hours * _BASE_POINTS_PER_HOUR * multiplier))


def calculate_credits(hours: float, skill_level: SkillLevel) -> int:
    """Calculate credits earned from a completed swap."""
    multiplier = _SKILL_LEVEL_MULTIPLIERS.get(skill_level, 1.0)
    return max(1, int(hours * _BASE_CREDITS_PER_HOUR * multiplier))


def award_swap_points(
    cosmos,
    request_id: str,
    requester_uid: str,
    recipient_uid: str,
    hours: float,
    skill_level: SkillLevel,
    notes: str | None = None,
) -> int:
    """Award points/credits to both participants and update their profiles. Returns points earned."""
    points = calculate_points(hours, skill_level)
    credits = calculate_credits(hours, skill_level)

    description = f"Swap completed: {hours}h at {skill_level.value} level"
    if notes:
        description += f" — {notes}"

    for uid in [requester_uid, recipient_uid]:
        cosmos.create_points_transaction(
            uid=uid,
            data={
                "type": PointsTransactionType.earned.value,
                "reason": PointsTransactionReason.swap_completed.value,
                "points": points,
                "credits": credits,
                "description": description,
                "swap_request_id": request_id,
            },
        )

    # Update each participant's profile with accumulated credits & swap count
    for uid in [requester_uid, recipient_uid]:
        bal = cosmos.get_points_balance(uid)
        out = cosmos.query_outgoing_requests(uid, status="completed")
        inc = cosmos.query_incoming_requests(uid, status="completed")
        cosmos.update_profile(uid, {
            "swap_credits": bal["credits"],
            "swaps_completed": len(out) + len(inc),
        })

    return points


# Backward compat aliases
_calculate_points = calculate_points
_calculate_credits = calculate_credits


# ── Endpoints ───────────────────────────────────────────────────────────────

@router.get("/balance", response_model=PointsBalanceResponse)
def get_balance(uid: str = Query(..., description="User UID")):
    """Get the current points and credits balance for a user."""
    cosmos = get_cosmos_service()

    balance = cosmos.get_points_balance(uid)

    # Count completed swaps
    outgoing = cosmos.query_outgoing_requests(uid, status="completed")
    incoming = cosmos.query_incoming_requests(uid, status="completed")
    total_completed = len(outgoing) + len(incoming)

    return PointsBalanceResponse(
        uid=uid,
        points=balance["points"],
        credits=balance["credits"],
        total_swaps_completed=total_completed,
    )


@router.get("/history", response_model=List[PointsTransactionResponse])
def get_history(
    uid: str = Query(..., description="User UID"),
    limit: int = Query(50, ge=1, le=200, description="Max records"),
):
    """Get points/credits transaction history for a user."""
    cosmos = get_cosmos_service()
    items = cosmos.get_points_history(uid, limit=limit)
    return [PointsTransactionResponse(**item) for item in items]


@router.post("/complete-swap/{request_id}", response_model=PointsBalanceResponse)
def complete_swap(
    request_id: str,
    completion: SwapCompletionRequest,
    uid: str = Query(..., description="UID of the user marking completion"),
):
    """
    Mark a swap as completed and award points + credits to both participants.

    Points formula: hours * 10 * skill_level_multiplier
      - Beginner: 0.75x
      - Intermediate: 1.0x
      - Advanced: 1.25x

    Credits formula: same as points (1:1 ratio)

    Both the requester and recipient earn points/credits when a swap is completed.
    """
    cosmos = get_cosmos_service()

    swap_req = cosmos.get_swap_request_by_id(request_id)
    if not swap_req:
        raise HTTPException(status_code=404, detail="Swap request not found")

    if uid not in [swap_req["requester_uid"], swap_req["recipient_uid"]]:
        raise HTTPException(status_code=403, detail="Not a participant in this swap")

    if swap_req["status"] != SwapRequestStatus.accepted.value:
        raise HTTPException(
            status_code=400,
            detail=f"Can only complete accepted swaps (current status: {swap_req['status']})"
        )

    # Award points and mark completed
    award_swap_points(
        cosmos,
        request_id=request_id,
        requester_uid=swap_req["requester_uid"],
        recipient_uid=swap_req["recipient_uid"],
        hours=completion.hours,
        skill_level=completion.skill_level,
        notes=completion.notes,
    )

    cosmos.update_swap_request(
        request_id=request_id,
        requester_uid=swap_req["requester_uid"],
        update_data={"status": SwapRequestStatus.completed.value},
    )

    # Return updated balance for the completing user
    balance = cosmos.get_points_balance(uid)
    outgoing = cosmos.query_outgoing_requests(uid, status="completed")
    incoming = cosmos.query_incoming_requests(uid, status="completed")

    return PointsBalanceResponse(
        uid=uid,
        points=balance["points"],
        credits=balance["credits"],
        total_swaps_completed=len(outgoing) + len(incoming),
    )


@router.post("/spend", response_model=PointsTransactionResponse)
def spend_points(
    request: PointsSpendRequest,
    uid: str = Query(..., description="User UID"),
):
    """
    Spend points on platform features.

    - Priority Boost: 5 points per hour (1-168 hours)
    - Request Without Reciprocity: 50 points flat
    """
    cosmos = get_cosmos_service()
    balance = cosmos.get_points_balance(uid)

    if request.reason == PointsTransactionReason.priority_boost:
        if not request.duration_hours:
            raise HTTPException(status_code=400, detail="duration_hours required for priority boost")
        cost = request.duration_hours * _PRIORITY_BOOST_COST
        description = f"Priority boost for {request.duration_hours}h"

    elif request.reason == PointsTransactionReason.request_without_reciprocity:
        cost = _REQUEST_WITHOUT_RECIPROCITY_COST
        description = "Request without reciprocity"

    else:
        raise HTTPException(status_code=400, detail=f"Cannot spend on reason: {request.reason.value}")

    if balance["points"] < cost:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient points. Need {cost}, have {balance['points']}"
        )

    txn = cosmos.create_points_transaction(
        uid=uid,
        data={
            "type": PointsTransactionType.spent.value,
            "reason": request.reason.value,
            "points": cost,
            "credits": 0,
            "description": description,
        },
    )

    return PointsTransactionResponse(**txn)
