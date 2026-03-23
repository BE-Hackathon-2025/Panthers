#!/usr/bin/env python3
"""Import Firestore JSON export files into Azure Cosmos DB.

Firebase has been removed from the codebase. This script reads JSON files
exported from the Firebase Console and upserts them into Cosmos DB.

Usage:
    cd wap-backend
    python scripts/migrate_firestore_to_cosmos.py data/profiles.json [data/conversations.json ...]
    python scripts/migrate_firestore_to_cosmos.py --dir data/   # import all .json files in a directory
    python scripts/migrate_firestore_to_cosmos.py --dry-run data/profiles.json

Each JSON file should be either:
  - A JSON array of documents: [{...}, {...}, ...]
  - A JSON object keyed by document ID: {"docId1": {...}, "docId2": {...}, ...}

The collection name is derived from the filename (e.g., profiles.json → profiles).

After import, run `python scripts/reindex.py` to populate Azure AI Search.
"""

from __future__ import annotations

import argparse
import json
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

# Add parent directory so we can import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.cosmos_db import get_cosmos_service  # noqa: E402

# Partition-key field per collection (must match cosmos_db.py CONTAINERS map)
PARTITION_KEY_FIELD: dict[str, str] = {
    "profiles": "uid",
    "blocks": "uid",
    "reports": "uid",
    "conversations": "conversation_id",
    "messages": "conversation_id",
    "swap_requests": "uid",
}


def _load_documents(path: Path) -> list[dict]:
    """Load a JSON file and return a list of document dicts."""
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)

    if isinstance(raw, list):
        return raw
    if isinstance(raw, dict):
        # Object keyed by document ID
        docs = []
        for doc_id, doc_data in raw.items():
            if isinstance(doc_data, dict):
                doc_data.setdefault("id", doc_id)
                docs.append(doc_data)
        return docs

    print(f"  WARNING: unexpected JSON shape in {path.name}, skipping")
    return []


def import_file(
    path: Path,
    cosmos_svc,
    dry_run: bool,
) -> tuple[int, int, list[dict]]:
    """Import one JSON file into Cosmos DB.

    Returns (imported_count, error_count, error_rows).
    """
    collection = path.stem  # e.g. "profiles.json" → "profiles"
    pk_field = PARTITION_KEY_FIELD.get(collection, "id")

    docs = _load_documents(path)
    print(f"\n[{collection}] {len(docs)} documents in {path.name}")

    imported = 0
    errors = 0
    error_rows: list[dict] = []

    for i, data in enumerate(docs):
        doc_id = data.get("id", f"doc_{i}")
        try:
            # Ensure required fields
            data.setdefault("id", doc_id)
            if pk_field not in data:
                data[pk_field] = doc_id

            if not dry_run:
                cosmos_svc.upsert_item(collection, data)

            imported += 1
            if imported % 100 == 0:
                print(f"  … {imported}/{len(docs)}")

        except Exception as exc:
            errors += 1
            error_rows.append(
                {
                    "collection": collection,
                    "doc_id": doc_id,
                    "error": str(exc),
                    "traceback": traceback.format_exc(),
                }
            )
            print(f"  ✗ {doc_id}: {exc}")

    print(f"  ✓ {imported} imported, {errors} errors")
    return imported, errors, error_rows


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import Firestore JSON exports into Cosmos DB"
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="JSON files to import (collection name derived from filename)",
    )
    parser.add_argument(
        "--dir",
        help="Import all .json files from this directory",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse JSON but do NOT write to Cosmos DB",
    )
    args = parser.parse_args()

    paths: list[Path] = []
    if args.dir:
        d = Path(args.dir)
        if not d.is_dir():
            print(f"Not a directory: {d}")
            sys.exit(1)
        paths.extend(sorted(d.glob("*.json")))
    for f in args.files or []:
        p = Path(f)
        if not p.exists():
            print(f"File not found: {p}")
            sys.exit(1)
        paths.append(p)

    if not paths:
        print("No files specified. Use positional args or --dir.")
        parser.print_help()
        sys.exit(1)

    print("=" * 60)
    print("$wap  JSON → Cosmos DB import")
    print(f"Mode: {'DRY RUN (no writes)' if args.dry_run else 'LIVE'}")
    print(f"Files: {[p.name for p in paths]}")
    print("=" * 60)

    cosmos_svc = None if args.dry_run else get_cosmos_service()

    total_imported = 0
    total_errors = 0

    for path in paths:
        imported, errors, _ = import_file(path, cosmos_svc, args.dry_run)
        total_imported += imported
        total_errors += errors

    print("\n" + "=" * 60)
    print("IMPORT SUMMARY")
    print(f"  Total imported : {total_imported}")
    print(f"  Total errors   : {total_errors}")

    if args.dry_run:
        print("\nDRY RUN complete — nothing was written to Cosmos DB.")
    else:
        print("\nNext step: python scripts/reindex.py")

    print("=" * 60)


if __name__ == "__main__":
    main()
