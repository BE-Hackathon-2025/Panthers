#!/usr/bin/env python3
"""Script to reindex all profiles from Firestore to Qdrant."""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.firebase_db import get_firebase_service
from app.embeddings import get_embedding_service
from app.qdrant_client import get_qdrant_service


def reindex_all_profiles():
    """Reindex all profiles from Firestore to Qdrant."""
    firebase_service = get_firebase_service()
    embedding_service = get_embedding_service()
    qdrant_service = get_qdrant_service()
    
    profiles = firebase_service.list_profiles(limit=10000)
    print(f"Found {len(profiles)} profiles to reindex")
    
    if not profiles:
        print("No profiles found in Firestore")
        return
    
    for i, profile in enumerate(profiles, 1):
        uid = profile.get('uid')
        print(f"[{i}/{len(profiles)}] Indexing {uid}...")
        
        try:
            # Check if profile has skills to offer and needs
            skills_to_offer = profile.get('skills_to_offer')
            services_needed = profile.get('services_needed')
            
            if not skills_to_offer or not services_needed:
                print(f"  ⊘ Skipped {uid} (no skills defined)")
                continue
            
            # Generate embeddings
            offer_vec = embedding_service.encode(skills_to_offer)
            need_vec = embedding_service.encode(services_needed)
            
            # Prepare payload
            payload = {
                "uid": uid,
                "email": profile.get('email'),
                "display_name": profile.get('display_name'),
                "photo_url": profile.get('photo_url'),
                "full_name": profile.get('full_name'),
                "username": profile.get('username'),
                "bio": profile.get('bio'),
                "city": profile.get('city'),
                "timezone": profile.get('timezone'),
                "skills_to_offer": skills_to_offer,
                "services_needed": services_needed,
                "dm_open": profile.get('dm_open', True),
                "show_city": profile.get('show_city', True),
            }
            
            # Upsert to Qdrant (use uid as point ID)
            qdrant_service.upsert_profile(
                username=uid,
                offer_vec=offer_vec,
                need_vec=need_vec,
                payload=payload,
            )
            print(f"  ✓ Indexed {uid}")
            
        except Exception as e:
            print(f"  ✗ Error indexing {uid}: {e}")
            continue
    
    print("\n✓ Reindexing complete!")


if __name__ == "__main__":
    reindex_all_profiles()

