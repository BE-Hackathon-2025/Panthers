"""Profile management endpoints."""

from typing import Optional
from fastapi import APIRouter, HTTPException
from datetime import datetime

from app.config import settings
from app.schemas import ProfileCreate, ProfileUpdate, ProfileResponse
from app.cosmos_db import get_cosmos_service
from app.embeddings import get_embedding_service
from app.azure_search import get_azure_search_service
from app.cache import get_cache_service
from app.email_service import get_email_service

router = APIRouter(prefix="/profiles", tags=["profiles"])


@router.post("/upsert", response_model=ProfileResponse)
def upsert_profile(profile_data: ProfileCreate):
    """
    Create or update a profile in Cosmos DB and Azure AI Search.

    1. Stores/updates the profile in Cosmos DB
    2. Generates embeddings for skills_to_offer and services_needed
    3. Upserts vectors to Azure AI Search
    """
    # Get services
    cosmos_service = get_cosmos_service()
    embedding_service = get_embedding_service()
    search_service = get_azure_search_service()
    email_service = get_email_service()

    # Check if this is a new profile (for welcome email)
    existing_profile = cosmos_service.get_profile(profile_data.uid)
    is_new_profile = existing_profile is None

    # Prepare profile data for Cosmos DB
    profile_dict = {
        "email": profile_data.email,
        "display_name": profile_data.display_name,
        "photo_url": profile_data.photo_url,
        "full_name": profile_data.full_name,
        "username": profile_data.username,
        "bio": profile_data.bio,
        "city": profile_data.city,
        "timezone": profile_data.timezone,
        "skills_to_offer": profile_data.skills_to_offer,
        "services_needed": profile_data.services_needed,
        "dm_open": profile_data.dm_open if profile_data.dm_open is not None else True,
        "email_updates": profile_data.email_updates if profile_data.email_updates is not None else True,
        "show_city": profile_data.show_city if profile_data.show_city is not None else True,
    }
    
    # Upsert to Cosmos DB
    saved_profile = cosmos_service.upsert_profile(profile_data.uid, profile_dict)
    
    # Generate embeddings if either skills_to_offer or services_needed is provided.
    # Use a zero vector for whichever field is empty so the profile is still searchable.
    has_offers = bool(profile_data.skills_to_offer and profile_data.skills_to_offer.strip())
    has_needs = bool(profile_data.services_needed and profile_data.services_needed.strip())

    if has_offers or has_needs:
        zero_vec = [0.0] * settings.vector_dim
        offer_vec = embedding_service.encode(profile_data.skills_to_offer) if has_offers else zero_vec
        need_vec = embedding_service.encode(profile_data.services_needed) if has_needs else zero_vec

        payload = {
            "uid": profile_data.uid,
            "email": profile_data.email,
            "display_name": profile_data.display_name,
            "photo_url": profile_data.photo_url,
            "full_name": profile_data.full_name,
            "username": profile_data.username,
            "bio": profile_data.bio,
            "city": profile_data.city,
            "timezone": profile_data.timezone,
            "skills_to_offer": profile_data.skills_to_offer,
            "services_needed": profile_data.services_needed,
            "dm_open": profile_data.dm_open if profile_data.dm_open is not None else True,
            "show_city": profile_data.show_city if profile_data.show_city is not None else True,
            "swap_credits": saved_profile.get("swap_credits", 0),
            "swaps_completed": saved_profile.get("swaps_completed", 0),
        }

        search_service.upsert_profile(
            username=profile_data.uid,
            offer_vec=offer_vec,
            need_vec=need_vec,
            payload=payload,
        )
    
    # Invalidate search cache when profile changes
    cache_service = get_cache_service()
    cleared = cache_service.clear_pattern("search:*")
    if cleared > 0:
        print(f"Cleared {cleared} cached search results (profile updated)")

    # Send welcome email for new profiles (if email updates enabled)
    if is_new_profile and profile_data.email_updates is not False:
        email_service.send_welcome(
            to_email=profile_data.email,
            user_name=profile_data.display_name,
            skills_to_offer=profile_data.skills_to_offer,
            services_needed=profile_data.services_needed,
        )

    return ProfileResponse(**saved_profile)


@router.get("/{uid}", response_model=ProfileResponse)
def get_profile(uid: str):
    """Get a profile by UID."""
    cosmos_service = get_cosmos_service()
    profile = cosmos_service.get_profile(uid)

    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    return ProfileResponse(**profile)


@router.get("/email/{email}", response_model=ProfileResponse)
def get_profile_by_email(email: str):
    """Get a profile by email address."""
    cosmos_service = get_cosmos_service()
    profile = cosmos_service.get_profile_by_email(email)

    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    return ProfileResponse(**profile)


@router.patch("/{uid}", response_model=ProfileResponse)
def update_profile(uid: str, profile_update: ProfileUpdate):
    """Partially update a profile."""
    cosmos_service = get_cosmos_service()
    embedding_service = get_embedding_service()
    search_service = get_azure_search_service()

    # Check if profile exists
    existing_profile = cosmos_service.get_profile(uid)
    if not existing_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Prepare update data (only include provided fields)
    update_dict = profile_update.model_dump(exclude_unset=True)

    # Update Cosmos DB
    updated_profile = cosmos_service.update_profile(uid, update_dict)
    
    # If skills changed, update search index embeddings
    if 'skills_to_offer' in update_dict or 'services_needed' in update_dict:
        skills_to_offer = updated_profile.get('skills_to_offer', existing_profile.get('skills_to_offer', ''))
        services_needed = updated_profile.get('services_needed', existing_profile.get('services_needed', ''))

        has_offers = bool(skills_to_offer and skills_to_offer.strip())
        has_needs = bool(services_needed and services_needed.strip())

        if has_offers or has_needs:
            zero_vec = [0.0] * settings.vector_dim
            offer_vec = embedding_service.encode(skills_to_offer) if has_offers else zero_vec
            need_vec = embedding_service.encode(services_needed) if has_needs else zero_vec

            payload = {
                "uid": uid,
                "email": updated_profile.get('email'),
                "display_name": updated_profile.get('display_name'),
                "photo_url": updated_profile.get('photo_url'),
                "full_name": updated_profile.get('full_name'),
                "username": updated_profile.get('username'),
                "bio": updated_profile.get('bio'),
                "city": updated_profile.get('city'),
                "timezone": updated_profile.get('timezone'),
                "skills_to_offer": skills_to_offer,
                "services_needed": services_needed,
                "dm_open": updated_profile.get('dm_open', True),
                "show_city": updated_profile.get('show_city', True),
                "swap_credits": updated_profile.get('swap_credits', 0),
                "swaps_completed": updated_profile.get('swaps_completed', 0),
            }

            search_service.upsert_profile(
                username=uid,
                offer_vec=offer_vec,
                need_vec=need_vec,
                payload=payload,
            )
    
    return ProfileResponse(**updated_profile)


@router.delete("/{uid}")
def delete_profile(uid: str):
    """Delete a profile from Cosmos DB and Azure AI Search."""
    cosmos_service = get_cosmos_service()
    search_service = get_azure_search_service()

    existing_profile = cosmos_service.get_profile(uid)
    if not existing_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    cosmos_service.delete_profile(uid)
    search_service.delete_profile(uid)

    return {"message": "Profile deleted successfully", "uid": uid}

