"""Matching logic for reciprocal skill swaps."""

from typing import List, Dict, Any

from app.embeddings import get_embedding_service
from app.qdrant_client import get_qdrant_service


def compute_reciprocal_matches(
    my_offer_text: str,
    my_need_text: str,
    limit: int = 10,
) -> List[Dict[str, Any]]:
    """
    Find reciprocal skill swap matches using harmonic mean.
    
    The algorithm:
    1. Embed my_offer_text and search for profiles whose needs match (they want what I offer)
    2. Embed my_need_text and search for profiles whose offers match (they offer what I want)
    3. Compute harmonic mean of scores for profiles in both result sets
    4. Return top-k by harmonic mean score
    
    Args:
        my_offer_text: What I can offer
        my_need_text: What I want to learn
        limit: Number of results to return
        
    Returns:
        List of matched profiles with reciprocal scores
    """
    embedding_service = get_embedding_service()
    qdrant_service = get_qdrant_service()
    
    # Generate embeddings
    my_offer_vec = embedding_service.encode(my_offer_text)
    my_need_vec = embedding_service.encode(my_need_text)
    
    # Search 1: Find people who want what I offer (search their needs)
    they_need_matches = qdrant_service.search_needs(
        query_vec=my_offer_vec,
        limit=50,
        score_threshold=0.2,
    )
    
    # Search 2: Find people who offer what I need (search their offers)
    they_offer_matches = qdrant_service.search_offers(
        query_vec=my_need_vec,
        limit=50,
        score_threshold=0.2,
    )
    
    # Build score dictionaries (using uid as key)
    need_scores = {m.get("uid", m.get("username")): m["score"] for m in they_need_matches}
    offer_scores = {m.get("uid", m.get("username")): m["score"] for m in they_offer_matches}
    
    # Find intersection and compute harmonic mean
    common_users = set(need_scores.keys()).intersection(offer_scores.keys())
    
    reciprocal_matches = []
    for user_id in common_users:
        score_they_need = need_scores[user_id]
        score_they_offer = offer_scores[user_id]
        
        # Harmonic mean
        harmonic_mean = (
            2 * score_they_need * score_they_offer
        ) / (score_they_need + score_they_offer)
        
        # Get full profile from one of the result sets
        profile = next(
            (m for m in they_need_matches if m.get("uid", m.get("username")) == user_id), None
        )
        
        if profile:
            profile["reciprocal_score"] = round(harmonic_mean, 4)
            profile["offer_match_score"] = round(score_they_offer, 4)
            profile["need_match_score"] = round(score_they_need, 4)
            reciprocal_matches.append(profile)
    
    # Sort by reciprocal score
    reciprocal_matches.sort(key=lambda x: x["reciprocal_score"], reverse=True)
    
    return reciprocal_matches[:limit]

