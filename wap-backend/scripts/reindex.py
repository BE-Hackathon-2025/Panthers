#!/usr/bin/env python3
"""Reindex all profiles from Azure Cosmos DB to Azure AI Search.

Usage:
    cd wap-backend
    python scripts/reindex.py
    python scripts/reindex.py --limit 500
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.embeddings import get_embedding_service
from app.azure_search import get_azure_search_service


def reindex_all_profiles(limit: int = 10000) -> None:
    """Reindex all profiles from Cosmos DB to Azure AI Search."""
    from app.cosmos_db import get_cosmos_service

    svc = get_cosmos_service()
    profiles = svc.list_profiles(limit=limit)

    print(f"Found {len(profiles)} profiles in Cosmos DB")

    if not profiles:
        print("No profiles found")
        return

    embedding_service = get_embedding_service()
    search_service = get_azure_search_service()

    ok = 0
    skipped = 0
    failed = 0

    for i, profile in enumerate(profiles, 1):
        uid = profile.get("uid")
        print(f"[{i}/{len(profiles)}] Indexing {uid}...")

        try:
            skills_to_offer = profile.get("skills_to_offer")
            services_needed = profile.get("services_needed")

            if not skills_to_offer or not services_needed:
                print(f"  - Skipped {uid} (no skills defined)")
                skipped += 1
                continue

            offer_vec = embedding_service.encode(skills_to_offer)
            need_vec = embedding_service.encode(services_needed)

            payload = {
                "uid": uid,
                "email": profile.get("email"),
                "display_name": profile.get("display_name"),
                "photo_url": profile.get("photo_url"),
                "full_name": profile.get("full_name"),
                "username": profile.get("username"),
                "bio": profile.get("bio"),
                "city": profile.get("city"),
                "timezone": profile.get("timezone"),
                "skills_to_offer": skills_to_offer,
                "services_needed": services_needed,
                "dm_open": profile.get("dm_open", True),
                "show_city": profile.get("show_city", True),
            }

            search_service.upsert_profile(
                username=uid,
                offer_vec=offer_vec,
                need_vec=need_vec,
                payload=payload,
            )
            print(f"  + Indexed {uid}")
            ok += 1

        except Exception as exc:
            print(f"  ! Error indexing {uid}: {exc}")
            failed += 1
            continue

    print(f"\nReindex complete — {ok} indexed, {skipped} skipped, {failed} failed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reindex profiles into Azure AI Search")
    parser.add_argument("--limit", type=int, default=10000, help="Max profiles to process")
    args = parser.parse_args()
    reindex_all_profiles(limit=args.limit)
