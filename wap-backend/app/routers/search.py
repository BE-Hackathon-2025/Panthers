"""Search endpoints."""

from typing import List, Literal, Dict, Any, Optional
from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.schemas import ProfileSearchResult, SkillSearchResult
from app.embeddings import get_embedding_service
from app.azure_search import get_azure_search_service, get_skills_search_service
from app.cache import get_cache_service

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
    Semantic search for profiles with optional Redis caching.

    Uses Azure OpenAI embeddings to find profiles whose skills semantically match
    the search query. Results are cached for 1 hour to improve performance.

    Performance:
        - Cache Hit: ~5ms (16x faster)
        - Cache Miss: ~80ms (normal Azure AI Search)

    Example:
        Query: "teach me guitar and music"
        Returns: Profiles of people who can teach guitar, music theory, etc.
    """
    cache_service = get_cache_service()
    embedding_service = get_embedding_service()
    search_service = get_azure_search_service()
    
    # Try cache first
    cache_key = cache_service._generate_key(
        "search",
        {
            "query": request.query,
            "limit": request.limit,
            "threshold": request.score_threshold,
            "mode": request.mode,
        }
    )
    
    cached = cache_service.get(cache_key)
    if cached:
        print(f"✅ Cache HIT: '{request.query}' (mode={request.mode})")
        return [ProfileSearchResult(**result) for result in cached]
    
    print(f"❌ Cache MISS: '{request.query}' (mode={request.mode})")
    
    # Generate query embedding
    query_vec = embedding_service.encode(request.query)
    
    # Search by mode
    mode = request.mode
    if mode == "offers":
        results = search_service.search_offers(
            query_vec=query_vec,
            limit=request.limit,
            score_threshold=request.score_threshold,
        )
        # Cache the results
        cache_service.set(cache_key, results, ttl=3600)
        return [ProfileSearchResult(**result) for result in results]
    if mode == "needs":
        results = search_service.search_needs(
            query_vec=query_vec,
            limit=request.limit,
            score_threshold=request.score_threshold,
        )
        # Cache the results
        cache_service.set(cache_key, results, ttl=3600)
        return [ProfileSearchResult(**result) for result in results]

    # mode == "both": combine offers and needs; pick the higher score per uid
    offer_results = search_service.search_offers(
        query_vec=query_vec,
        limit=request.limit,
        score_threshold=request.score_threshold,
    )
    need_results = search_service.search_needs(
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
    
    # Cache the results
    cache_service.set(cache_key, combined_list, ttl=3600)
    
    return [ProfileSearchResult(**result) for result in combined_list]


class SkillSearchRequest(BaseModel):
    """Request model for skill-centric search."""
    query: str = Field(..., min_length=1, description="Search query")
    limit: int = Field(10, ge=1, le=100, description="Max results")
    category: Optional[str] = Field(None, description="Filter by category")


@router.post("/skills", response_model=List[SkillSearchResult])
def search_skills(request: SkillSearchRequest):
    """
    Semantic search for individual skills (skill-centric marketplace).

    Returns skill cards with poster info denormalized.
    """
    cache_service = get_cache_service()
    embedding_service = get_embedding_service()
    skills_search = get_skills_search_service()

    cache_key = cache_service._generate_key(
        "skill_search",
        {"query": request.query, "limit": request.limit, "category": request.category or ""},
    )

    cached = cache_service.get(cache_key)
    if cached:
        return [SkillSearchResult(**r) for r in cached]

    query_vec = embedding_service.encode(request.query)
    results = skills_search.search_skills(
        query_vec=query_vec,
        limit=request.limit,
        category_filter=request.category,
    )

    cache_service.set(cache_key, results, ttl=3600)
    return [SkillSearchResult(**r) for r in results]


class SkillRecommendationRequest(BaseModel):
    """Request for skill recommendations."""
    
    current_skills: str = Field(..., min_length=1, description="User's current skills or interests")
    limit: int = Field(5, ge=1, le=20, description="Number of recommendations")


class SkillRecommendation(BaseModel):
    """A recommended skill."""
    
    skill: str
    score: float
    reason: str


@router.post("/recommend-skills", response_model=List[SkillRecommendation])
def recommend_skills(request: SkillRecommendationRequest):
    """
    Recommend complementary skills based on user's current skills.
    
    Analyzes what skills are commonly learned together by finding profiles
    with similar skills and extracting their other skills.
    
    Example:
        Input: "Python programming"
        Output: ["SQL databases", "Docker", "Git version control", ...]
    """
    cache_service = get_cache_service()
    embedding_service = get_embedding_service()
    search_service = get_azure_search_service()

    # Try cache first
    cache_key = cache_service._generate_key(
        "skill_recommend",
        {"skills": request.current_skills, "limit": request.limit}
    )
    
    cached = cache_service.get(cache_key)
    if cached:
        print(f"✅ Cache HIT: Skill recommendations for '{request.current_skills}'")
        return [SkillRecommendation(**rec) for rec in cached]
    
    print(f"❌ Cache MISS: Generating skill recommendations for '{request.current_skills}'")
    
    # Encode the current skills
    query_vec = embedding_service.encode(request.current_skills)
    
    # Search for people with similar skills (both offers and needs)
    similar_offers = search_service.search_offers(
        query_vec=query_vec,
        limit=20,
        score_threshold=0.4,
    )

    similar_needs = search_service.search_needs(
        query_vec=query_vec,
        limit=20,
        score_threshold=0.4,
    )
    
    # Extract and rank complementary skills
    skill_frequencies: Dict[str, Dict[str, Any]] = {}
    
    # Process offers (what people can teach)
    for profile in similar_offers:
        offers = profile.get("skills_to_offer", "")
        if offers and offers.strip():
            # Simple extraction: split by common delimiters
            skills = [s.strip() for s in offers.replace(",", ".").split(".") if s.strip()]
            for skill in skills[:5]:  # Limit to first 5 skills per profile
                if skill and len(skill) > 10:  # Only meaningful skills
                    if skill not in skill_frequencies:
                        skill_frequencies[skill] = {"count": 0, "total_score": 0.0}
                    skill_frequencies[skill]["count"] += 1
                    skill_frequencies[skill]["total_score"] += profile.get("score", 0.5)
    
    # Process needs (what people want to learn - indicates trending skills)
    for profile in similar_needs:
        needs = profile.get("services_needed", "")
        if needs and needs.strip():
            skills = [s.strip() for s in needs.replace(",", ".").split(".") if s.strip()]
            for skill in skills[:5]:
                if skill and len(skill) > 10:
                    if skill not in skill_frequencies:
                        skill_frequencies[skill] = {"count": 0, "total_score": 0.0}
                    skill_frequencies[skill]["count"] += 1
                    skill_frequencies[skill]["total_score"] += profile.get("score", 0.5) * 0.8  # Weight needs slightly lower
    
    # Rank by frequency and relevance
    recommendations = []
    for skill, data in skill_frequencies.items():
        avg_score = data["total_score"] / max(data["count"], 1)
        combined_score = (data["count"] * 0.3) + (avg_score * 0.7)  # Balance frequency and relevance
        
        reason = f"Common among {data['count']} similar profiles"
        recommendations.append({
            "skill": skill,
            "score": round(combined_score, 3),
            "reason": reason
        })
    
    # Sort by combined score and take top N
    recommendations.sort(key=lambda x: x["score"], reverse=True)
    recommendations = recommendations[:request.limit]
    
    # Cache for 2 hours
    cache_service.set(cache_key, recommendations, ttl=7200)
    
    return [SkillRecommendation(**rec) for rec in recommendations]

