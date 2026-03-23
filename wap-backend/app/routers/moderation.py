"""Moderation endpoints for blocking and reporting users."""

from typing import List
from datetime import datetime
from fastapi import APIRouter, HTTPException, Query

from app.schemas import (
    BlockCreate,
    BlockResponse,
    ReportCreate,
    ReportResponse,
    ConversationStatus,
)
from app.cosmos_db import get_cosmos_service

router = APIRouter(prefix="/moderation", tags=["moderation"])


def _convert_timestamp(value) -> str:
    """Convert a timestamp to ISO string."""
    if value is None:
        return datetime.utcnow().isoformat()
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


@router.post("/block", response_model=BlockResponse)
def block_user(
    block: BlockCreate,
    uid: str = Query(..., description="UID of the user doing the blocking"),
):
    """
    Block another user.

    Effects:
    1. Creates block record in Cosmos DB
    2. Updates any shared conversation status to 'blocked'
    3. Prevents future swap requests between users
    4. Prevents messaging
    """
    cosmos = get_cosmos_service()

    if uid == block.blocked_uid:
        raise HTTPException(status_code=400, detail="Cannot block yourself")

    existing = cosmos.get_block(uid, block.blocked_uid)
    if existing:
        raise HTTPException(status_code=400, detail="User is already blocked")

    block_doc = cosmos.create_block(
        blocker_uid=uid,
        data={
            "blocker_uid": uid,
            "blocked_uid": block.blocked_uid,
            "reason": block.reason,
        },
    )

    # Update any shared conversations to blocked status
    conversations = cosmos.query_conversations_for_user(uid)
    for conv in conversations:
        if block.blocked_uid in conv.get("participant_uids", []):
            cosmos.update_conversation(
                conv["id"],
                {"status": ConversationStatus.blocked.value},
            )

    return BlockResponse(
        id=block_doc["id"],
        blocker_uid=uid,
        blocked_uid=block.blocked_uid,
        created_at=block_doc.get("created_at", datetime.utcnow().isoformat()),
        reason=block.reason,
    )


@router.delete("/block/{blocked_uid}")
def unblock_user(
    blocked_uid: str,
    uid: str = Query(..., description="UID of the user doing the unblocking"),
):
    """
    Unblock a previously blocked user.

    Effects:
    1. Removes block record
    2. Restores conversation status to 'active' (if the other user hasn't also blocked)
    """
    cosmos = get_cosmos_service()

    block = cosmos.get_block(uid, blocked_uid)
    if not block:
        raise HTTPException(status_code=404, detail="Block not found")

    cosmos.delete_block(block["id"], uid)

    # Only restore conversations if the reverse block doesn't exist either
    reverse_block = cosmos.get_block(blocked_uid, uid)
    if not reverse_block:
        conversations = cosmos.query_conversations_for_user(uid)
        for conv in conversations:
            if blocked_uid in conv.get("participant_uids", []):
                if conv.get("status") == ConversationStatus.blocked.value:
                    cosmos.update_conversation(conv["id"], {"status": ConversationStatus.active.value})

    return {"message": "User unblocked", "blocked_uid": blocked_uid}


@router.get("/blocked", response_model=List[BlockResponse])
def list_blocked_users(
    uid: str = Query(..., description="UID of the user"),
):
    """List all users blocked by this user."""
    cosmos = get_cosmos_service()
    blocks = cosmos.list_blocks_by_user(uid)

    return [
        BlockResponse(
            id=b["id"],
            blocker_uid=b.get("blocker_uid"),
            blocked_uid=b.get("blocked_uid"),
            created_at=_convert_timestamp(b.get("created_at")),
            reason=b.get("reason"),
        )
        for b in blocks
    ]


@router.post("/report", response_model=ReportResponse)
def report_user(
    report: ReportCreate,
    uid: str = Query(..., description="UID of the reporter"),
):
    """
    Report a user for policy violation.

    - Creates report in Cosmos DB for admin review
    - Optionally includes message context
    """
    cosmos = get_cosmos_service()

    if uid == report.reported_uid:
        raise HTTPException(status_code=400, detail="Cannot report yourself")

    cosmos.create_report(
        reporter_uid=uid,
        data={
            "reporter_uid": uid,
            "reported_uid": report.reported_uid,
            "conversation_id": report.conversation_id,
            "message_id": report.message_id,
            "reason": report.reason.value,
            "details": report.details,
            "status": "pending",
            "reviewed_at": None,
            "reviewed_by": None,
            "resolution_notes": None,
        },
    )

    return ReportResponse(
        id="submitted",
        status="pending",
        message="Report submitted. We'll review it within 24-48 hours.",
    )


@router.get("/reports")
def list_my_reports(
    uid: str = Query(..., description="UID of the user"),
):
    """List reports submitted by this user."""
    cosmos = get_cosmos_service()
    reports = cosmos.list_user_reports(uid)

    return [
        {
            "id": r["id"],
            "reported_uid": r.get("reported_uid"),
            "reason": r.get("reason"),
            "status": r.get("status"),
            "created_at": _convert_timestamp(r.get("created_at")),
        }
        for r in reports
    ]
