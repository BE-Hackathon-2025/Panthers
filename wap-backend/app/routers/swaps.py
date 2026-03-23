"""Swap matching endpoints."""

from typing import List, Optional
from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.schemas import ReciprocalMatchResult
from app.matching import compute_reciprocal_matches
from app.cosmos_db import get_cosmos_service
from app.email_service import get_email_service

router = APIRouter(prefix="/match", tags=["matching"])

# Track recently notified matches to avoid spam (simple in-memory cache)
_notified_pairs: set = set()


class ReciprocalMatchRequest(BaseModel):
    """Request model for reciprocal matching."""

    my_offer_text: str = Field(..., min_length=1, description="What you can teach")
    my_need_text: str = Field(..., min_length=1, description="What you want to learn")
    limit: int = Field(10, ge=1, le=50, description="Max results")
    my_uid: Optional[str] = Field(None, description="Your user ID (required for notifications)")
    notify_matches: bool = Field(False, description="Send email notifications to high-score matches")


@router.post("/reciprocal", response_model=List[ReciprocalMatchResult])
def find_reciprocal_matches(request: ReciprocalMatchRequest):
    """
    Find reciprocal skill swap matches using semantic similarity and harmonic mean.

    This is the core matching algorithm that finds fair mutual skill exchanges:

    Algorithm:
    1. Search for profiles whose needs match what you offer (they want what you teach)
    2. Search for profiles whose offers match what you need (they teach what you want)
    3. Find intersection of both result sets (mutual matches)
    4. Compute harmonic mean: 2 * (score_A * score_B) / (score_A + score_B)
    5. Return top matches sorted by reciprocal score

    Optional: If notify_matches=true and my_uid is provided, sends email
    notifications to high-score matches (>70%) who have email_updates enabled.

    Example:
        You offer: "Python programming"
        You need: "Guitar lessons"

        Returns: Guitarists who want to learn Python, ranked by how well
                 both sides of the skill swap match.
    """
    results = compute_reciprocal_matches(
        my_offer_text=request.my_offer_text,
        my_need_text=request.my_need_text,
        limit=request.limit,
    )

    # Send notifications for high-score matches if requested
    if request.notify_matches and request.my_uid:
        _send_match_notifications(request.my_uid, results)

    return [ReciprocalMatchResult(**result) for result in results]


def _send_match_notifications(my_uid: str, matches: List[dict]):
    """Send email notifications to high-score matches."""
    cosmos = get_cosmos_service()
    email_service = get_email_service()

    # Get the requesting user's profile
    my_profile = cosmos.get_profile(my_uid)
    if not my_profile:
        return

    my_name = my_profile.get("display_name") or my_profile.get("username") or "Someone"

    # Notify high-score matches
    for match in matches:
        score = match.get("reciprocal_score", 0)
        match_uid = match.get("uid")

        # Only notify for strong matches (>70%)
        if score < 0.7 or not match_uid:
            continue

        # Avoid duplicate notifications (simple rate limiting)
        pair_key = tuple(sorted([my_uid, match_uid]))
        if pair_key in _notified_pairs:
            continue

        # Get match's full profile for email preference
        match_profile = cosmos.get_profile(match_uid)
        if not match_profile:
            continue

        # Check if match has email updates enabled
        if not match_profile.get("email_updates", True):
            continue

        match_email = match_profile.get("email")
        if not match_email:
            continue

        # Build notification about the requesting user (not about the match)
        notification_data = {
            "display_name": my_name,
            "skills_to_offer": my_profile.get("skills_to_offer", ""),
            "services_needed": my_profile.get("services_needed", ""),
            "reciprocal_score": score,
            "uid": my_uid,
        }

        # Send notification
        match_name = match_profile.get("display_name") or match_profile.get("username")
        email_service.send_match_notification(
            to_email=match_email,
            user_name=match_name,
            match=notification_data,
        )

        # Mark as notified
        _notified_pairs.add(pair_key)

