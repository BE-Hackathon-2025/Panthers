"""Search endpoints."""

from typing import List, Literal
from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.schemas import ProfileSearchResult
from app.embeddings import get_embedding_service
from app.qdrant_client import get_qdrant_service

router = APIRouter(prefix="/search", tags=["search"])


class SearchRequest(BaseModel):
    """Request model for semantic search."""
    
    query: str = Field(..., min_length=1, description="Search query")
    limit: int = Field(10, ge=1, le=100, description="Max results")
    score_threshold: float = Field(0.3, ge=0, le=1, description="Minimum similarity score")
    mode: Literal["offers", "needs", "both"] = Field("offers", description="Which vector to search")


@router.post("", response_model=List[ProfileSearchResult])
def search_profiles(request: SearchRequest):
    """
    Semantic search for profiles based on what they can offer.
    
    Uses BERT embeddings to find profiles whose skills semantically match
    the search query. Searches the offer_vec field in Qdrant.
    
    Example:
        Query: "teach me guitar and music"
        Returns: Profiles of people who can teach guitar, music theory, etc.
    """
    embedding_service = get_embedding_service()
    qdrant_service = get_qdrant_service()
    
    # Generate query embedding
    query_vec = embedding_service.encode(request.query)
    
    # Search by mode
    mode = request.mode
    if mode == "offers":
        results = qdrant_service.search_offers(
            query_vec=query_vec,
            limit=request.limit,
            score_threshold=request.score_threshold,
        )
        return [ProfileSearchResult(**result) for result in results]
    if mode == "needs":
        results = qdrant_service.search_needs(
            query_vec=query_vec,
            limit=request.limit,
            score_threshold=request.score_threshold,
        )
        return [ProfileSearchResult(**result) for result in results]
    
    # mode == "both": combine offers and needs; pick the higher score per uid
    offer_results = qdrant_service.search_offers(
        query_vec=query_vec,
        limit=request.limit,
        score_threshold=request.score_threshold,
    )
    need_results = qdrant_service.search_needs(
        query_vec=query_vec,
        limit=request.limit,
        score_threshold=request.score_threshold,
    )
    
    combined_by_uid = {}
    for item in offer_results + need_results:
        uid = item.get("uid") or item.get("username")
        if uid is None:
            # Fallback to pushing without dedupe if no uid present
            combined_by_uid[item.get("username")] = item
            continue
        prev = combined_by_uid.get(uid)
        if prev is None or item.get("score", 0) > prev.get("score", 0):
            combined_by_uid[uid] = item
    
    combined_list = list(combined_by_uid.values())
    # Sort by score desc and cap to limit
    combined_list.sort(key=lambda x: x.get("score", 0), reverse=True)
    combined_list = combined_list[: request.limit]
    return [ProfileSearchResult(**result) for result in combined_list]

