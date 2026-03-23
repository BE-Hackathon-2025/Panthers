"""Skills CRUD endpoints."""

from typing import List
from fastapi import APIRouter, HTTPException, Query

from app.schemas import SkillCreate, SkillResponse
from app.cosmos_db import get_cosmos_service
from app.embeddings import get_embedding_service
from app.azure_search import get_skills_search_service

router = APIRouter(prefix="/skills", tags=["skills"])


def _build_embedding_text(data: dict) -> str:
    """Build text for embedding from skill data."""
    title = data.get("title", "")
    description = data.get("description", "")
    category = data.get("category", "")
    difficulty = data.get("difficulty", "")
    return f"{title} - {description}. Category: {category}. Level: {difficulty}"


def _rebuild_profile_skills(cosmos, uid: str) -> None:
    """Rebuild the profile skills_to_offer string from individual skill docs."""
    skills = cosmos.get_skills_by_user(uid)
    skill_strings = [
        f"{s['title']} ({s.get('difficulty', '')})" for s in skills if s.get("title")
    ]
    skills_to_offer = ", ".join(skill_strings) if skill_strings else ""
    cosmos.update_profile(uid, {"skills_to_offer": skills_to_offer})


@router.post("", response_model=SkillResponse)
def create_skill(
    skill: SkillCreate,
    uid: str = Query(..., description="UID of the user posting the skill"),
):
    """Create a new skill and index it for search."""
    cosmos = get_cosmos_service()
    embedding_service = get_embedding_service()
    skills_search = get_skills_search_service()

    # Verify user exists
    profile = cosmos.get_profile(uid)
    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found")

    # Create skill doc in Cosmos
    skill_data = skill.model_dump()
    skill_doc = cosmos.create_skill(uid, skill_data)

    # Generate embedding and upsert to search index
    embed_text = _build_embedding_text(skill_doc)
    skill_vec = embedding_service.encode(embed_text)

    skills_search.upsert_skill(
        skill_id=skill_doc["id"],
        skill_vec=skill_vec,
        payload={
            **skill_doc,
            "poster_name": profile.get("display_name") or profile.get("full_name", ""),
            "poster_city": profile.get("city", ""),
            "poster_swap_credits": profile.get("swap_credits", 0),
        },
    )

    # Update profile skills_to_offer for backward compat
    _rebuild_profile_skills(cosmos, uid)

    return SkillResponse(**skill_doc)


@router.get("/user/{uid}", response_model=List[SkillResponse])
def get_skills_by_user(uid: str):
    """List all skills posted by a user."""
    cosmos = get_cosmos_service()
    skills = cosmos.get_skills_by_user(uid)
    return [SkillResponse(**s) for s in skills]


@router.get("/{skill_id}", response_model=SkillResponse)
def get_skill(
    skill_id: str,
    uid: str = Query(..., description="UID of the skill poster (partition key)"),
):
    """Get a single skill by ID."""
    cosmos = get_cosmos_service()
    skill = cosmos.get_skill(skill_id, uid)
    if not skill:
        raise HTTPException(status_code=404, detail="Skill not found")
    return SkillResponse(**skill)


@router.delete("/{skill_id}")
def delete_skill(
    skill_id: str,
    uid: str = Query(..., description="UID of the skill poster"),
):
    """Delete a skill from Cosmos and search index."""
    cosmos = get_cosmos_service()
    skills_search = get_skills_search_service()

    skill = cosmos.get_skill(skill_id, uid)
    if not skill:
        raise HTTPException(status_code=404, detail="Skill not found")

    cosmos.delete_skill(skill_id, uid)
    skills_search.delete_skill(skill_id)

    # Rebuild profile skills_to_offer
    _rebuild_profile_skills(cosmos, uid)

    return {"message": "Skill deleted", "id": skill_id}
