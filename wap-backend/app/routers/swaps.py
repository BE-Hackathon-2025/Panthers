"""Swap matching endpoints."""

from typing import List
from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.schemas import ReciprocalMatchResult
from app.matching import compute_reciprocal_matches

router = APIRouter(prefix="/match", tags=["matching"])


class ReciprocalMatchRequest(BaseModel):
    """Request model for reciprocal matching."""
    
    my_offer_text: str = Field(..., min_length=1, description="What you can teach")
    my_need_text: str = Field(..., min_length=1, description="What you want to learn")
    limit: int = Field(10, ge=1, le=50, description="Max results")


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
    
    return [ReciprocalMatchResult(**result) for result in results]

