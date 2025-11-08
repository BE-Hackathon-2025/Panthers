"""Profile management endpoints."""

from typing import Optional
from fastapi import APIRouter, HTTPException
from datetime import datetime

from app.schemas import ProfileCreate, ProfileUpdate, ProfileResponse
from app.firebase_db import get_firebase_service
from app.embeddings import get_embedding_service
from app.qdrant_client import get_qdrant_service

router = APIRouter(prefix="/profiles", tags=["profiles"])


@router.post("/upsert", response_model=ProfileResponse)
def upsert_profile(profile_data: ProfileCreate):
    """
    Create or update a profile in both Firestore and Qdrant.
    
    This endpoint:
    1. Stores/updates the profile in Firestore
    2. Generates embeddings for can_offer and wants_learn
    3. Upserts vectors to Qdrant with profile metadata
    
    The profile uses Firebase Auth UID as the unique identifier,
    combining authentication fields (uid, email, displayName, photoUrl)
    with skill-swap fields (can_offer, wants_learn, etc.)
    """
    # Get services
    firebase_service = get_firebase_service()
    embedding_service = get_embedding_service()
    qdrant_service = get_qdrant_service()
    
    # Prepare profile data for Firestore
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
    
    # Upsert to Firestore
    saved_profile = firebase_service.upsert_profile(profile_data.uid, profile_dict)
    
    # Generate embeddings (only if skills are provided)
    if profile_data.skills_to_offer and profile_data.services_needed:
        offer_vec = embedding_service.encode(profile_data.skills_to_offer)
        need_vec = embedding_service.encode(profile_data.services_needed)
        
        # Prepare payload for Qdrant (include all searchable fields)
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
        }
        
        # Upsert to Qdrant (use uid as the point ID)
        qdrant_service.upsert_profile(
            username=profile_data.uid,
            offer_vec=offer_vec,
            need_vec=need_vec,
            payload=payload,
        )
    
    return ProfileResponse(**saved_profile)


@router.get("/{uid}", response_model=ProfileResponse)
def get_profile(uid: str):
    """
    Get a profile by Firebase Auth UID.
    
    Args:
        uid: Firebase Auth user ID
        
    Returns:
        User profile with all fields
    """
    firebase_service = get_firebase_service()
    profile = firebase_service.get_profile(uid)
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    return ProfileResponse(**profile)


@router.get("/email/{email}", response_model=ProfileResponse)
def get_profile_by_email(email: str):
    """
    Get a profile by email address.
    
    Args:
        email: User email
        
    Returns:
        User profile
    """
    firebase_service = get_firebase_service()
    profile = firebase_service.get_profile_by_email(email)
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    return ProfileResponse(**profile)


@router.patch("/{uid}", response_model=ProfileResponse)
def update_profile(uid: str, profile_update: ProfileUpdate):
    """
    Partially update a profile.
    
    Args:
        uid: Firebase Auth user ID
        profile_update: Fields to update (only provided fields will be updated)
        
    Returns:
        Updated profile
    """
    firebase_service = get_firebase_service()
    embedding_service = get_embedding_service()
    qdrant_service = get_qdrant_service()
    
    # Check if profile exists
    existing_profile = firebase_service.get_profile(uid)
    if not existing_profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Prepare update data (only include provided fields)
    update_dict = profile_update.model_dump(exclude_unset=True)
    
    # Update Firestore
    updated_profile = firebase_service.update_profile(uid, update_dict)
    
    # If skills changed, update Qdrant embeddings
    if 'skills_to_offer' in update_dict or 'services_needed' in update_dict:
        skills_to_offer = updated_profile.get('skills_to_offer', existing_profile.get('skills_to_offer'))
        services_needed = updated_profile.get('services_needed', existing_profile.get('services_needed'))
        
        # Only update Qdrant if both skills are present
        if skills_to_offer and services_needed:
            # Regenerate embeddings
            offer_vec = embedding_service.encode(skills_to_offer)
            need_vec = embedding_service.encode(services_needed)
            
            # Update Qdrant
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
            }
            
            qdrant_service.upsert_profile(
                username=uid,
                offer_vec=offer_vec,
                need_vec=need_vec,
                payload=payload,
            )
    
    return ProfileResponse(**updated_profile)


@router.delete("/{uid}")
def delete_profile(uid: str):
    """
    Delete a profile from both Firestore and Qdrant.
    
    Args:
        uid: Firebase Auth user ID
        
    Returns:
        Success message
    """
    firebase_service = get_firebase_service()
    qdrant_service = get_qdrant_service()
    
    # Check if profile exists
    existing_profile = firebase_service.get_profile(uid)
    if not existing_profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Delete from Firestore
    firebase_service.delete_profile(uid)
    
    # Delete from Qdrant
    qdrant_service.delete_profile(uid)
    
    return {"message": "Profile deleted successfully", "uid": uid}

