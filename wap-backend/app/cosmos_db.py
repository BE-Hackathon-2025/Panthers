"""Azure Cosmos DB service — primary data store for all backend operations."""

from __future__ import annotations

import os
import uuid
from typing import Any, Dict, List, Optional, Tuple
from datetime import datetime, timezone

from azure.cosmos import CosmosClient, PartitionKey, exceptions as cosmos_exc

from app.config import settings


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class CosmosService:
    """Service for Azure Cosmos DB (NoSQL API) operations."""

    DATABASE_NAME: str = "swap-db"

    # Container → partition key mapping
    CONTAINERS: Dict[str, str] = {
        "profiles": "/uid",
        "conversations": "/conversation_id",
        "messages": "/conversation_id",
        "swap_requests": "/uid",
        "blocks": "/uid",
        "reports": "/uid",
        "points_transactions": "/uid",
        "skills": "/posted_by",
    }

    def __init__(self) -> None:
        self._client: Optional[CosmosClient] = None
        self._db = None
        self._initialized = False
        self._init_cosmos()

    # ── Initialisation ────────────────────────────────────────────────────────

    def _init_cosmos(self) -> None:
        if self._initialized:
            return

        conn_str = getattr(settings, "cosmos_connection_string", None) or os.getenv(
            "COSMOS_CONNECTION_STRING"
        )
        if not conn_str:
            raise RuntimeError(
                "COSMOS_CONNECTION_STRING is not set. "
                "Provide it via the environment or Key Vault."
            )

        self._client = CosmosClient.from_connection_string(conn_str)
        db_name = getattr(settings, "cosmos_database_name", self.DATABASE_NAME)
        self._db = self._client.create_database_if_not_exists(id=db_name)

        for container_name, partition_key in self.CONTAINERS.items():
            self._db.create_container_if_not_exists(
                id=container_name,
                partition_key=PartitionKey(path=partition_key),
            )

        self._initialized = True

    def _container(self, name: str):
        if not self._initialized:
            self._init_cosmos()
        return self._db.get_container_client(name)

    # ── Profiles ──────────────────────────────────────────────────────────────

    def create_profile(self, uid: str, profile_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new profile document."""
        now = _utcnow_iso()
        doc = {
            "id": uid,
            "uid": uid,
            "created_at": now,
            "updated_at": now,
            **profile_data,
        }
        self._container("profiles").create_item(body=doc)
        return doc

    def get_profile(self, uid: str) -> Optional[Dict[str, Any]]:
        """Fetch a profile by UID. Returns None if not found."""
        try:
            doc = self._container("profiles").read_item(item=uid, partition_key=uid)
            return _clean(doc)
        except cosmos_exc.CosmosResourceNotFoundError:
            return None

    def update_profile(self, uid: str, profile_data: Dict[str, Any]) -> Dict[str, Any]:
        """Partially update an existing profile (merge patch)."""
        existing = self.get_profile(uid)
        if existing is None:
            raise KeyError(f"Profile {uid} not found")

        profile_data["updated_at"] = _utcnow_iso()
        merged = {**existing, **profile_data, "id": uid, "uid": uid}
        self._container("profiles").replace_item(item=uid, body=merged)
        return _clean(merged)

    def upsert_profile(self, uid: str, profile_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create or update a profile."""
        existing = self.get_profile(uid)
        now = _utcnow_iso()

        if existing:
            profile_data["updated_at"] = now
            profile_data.setdefault("created_at", existing.get("created_at", now))
        else:
            profile_data["created_at"] = now
            profile_data["updated_at"] = now

        doc = {"id": uid, "uid": uid, **profile_data}
        self._container("profiles").upsert_item(body=doc)
        return _clean(doc)

    def delete_profile(self, uid: str) -> bool:
        """Delete a profile. Returns True on success."""
        self._container("profiles").delete_item(item=uid, partition_key=uid)
        return True

    def list_profiles(self, limit: int = 100) -> List[Dict[str, Any]]:
        """List profiles (up to limit)."""
        query = f"SELECT * FROM c OFFSET 0 LIMIT {limit}"
        items = list(
            self._container("profiles").query_items(
                query=query, enable_cross_partition_query=True
            )
        )
        return [_clean(i) for i in items]

    def get_profile_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Query profiles by email address."""
        query = "SELECT * FROM c WHERE c.email = @email OFFSET 0 LIMIT 1"
        params = [{"name": "@email", "value": email}]
        items = list(
            self._container("profiles").query_items(
                query=query,
                parameters=params,
                enable_cross_partition_query=True,
            )
        )
        return _clean(items[0]) if items else None

    # ── Conversations ─────────────────────────────────────────────────────────

    def create_conversation(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new conversation. Returns doc with generated id."""
        conv_id = str(uuid.uuid4())
        now = _utcnow_iso()
        doc = {
            "id": conv_id,
            "conversation_id": conv_id,
            "created_at": now,
            "updated_at": now,
            **data,
        }
        self._container("conversations").create_item(body=doc)
        return _clean(doc)

    def get_conversation(self, conversation_id: str) -> Optional[Dict[str, Any]]:
        """Fetch a conversation by ID. Returns None if not found."""
        try:
            doc = self._container("conversations").read_item(
                item=conversation_id, partition_key=conversation_id
            )
            return _clean(doc)
        except cosmos_exc.CosmosResourceNotFoundError:
            return None

    def update_conversation(self, conversation_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """Merge-update a conversation document."""
        existing = self.get_conversation(conversation_id)
        if existing is None:
            raise KeyError(f"Conversation {conversation_id} not found")
        update_data["updated_at"] = _utcnow_iso()
        merged = {**existing, **update_data, "id": conversation_id, "conversation_id": conversation_id}
        self._container("conversations").replace_item(item=conversation_id, body=merged)
        return _clean(merged)

    def query_conversations_for_user(self, uid: str) -> List[Dict[str, Any]]:
        """Return all conversations where uid is a participant."""
        query = "SELECT * FROM c WHERE ARRAY_CONTAINS(c.participant_uids, @uid)"
        params = [{"name": "@uid", "value": uid}]
        items = list(
            self._container("conversations").query_items(
                query=query, parameters=params, enable_cross_partition_query=True
            )
        )
        return [_clean(i) for i in items]

    # ── Messages ──────────────────────────────────────────────────────────────

    def create_message(self, conversation_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a message in a conversation."""
        msg_id = str(uuid.uuid4())
        doc = {
            "id": msg_id,
            "conversation_id": conversation_id,
            **data,
        }
        self._container("messages").create_item(body=doc)
        return _clean(doc)

    def get_messages(
        self, conversation_id: str, limit: int = 50, before: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Fetch messages for a conversation, newest first. Optional cursor via `before` (ISO timestamp)."""
        if before:
            query = (
                f"SELECT * FROM c WHERE c.conversation_id = @conv_id"
                f" AND c.sent_at < @before ORDER BY c.sent_at DESC OFFSET 0 LIMIT {limit}"
            )
            params = [
                {"name": "@conv_id", "value": conversation_id},
                {"name": "@before", "value": before},
            ]
        else:
            query = (
                f"SELECT * FROM c WHERE c.conversation_id = @conv_id"
                f" ORDER BY c.sent_at DESC OFFSET 0 LIMIT {limit}"
            )
            params = [{"name": "@conv_id", "value": conversation_id}]
        items = list(
            self._container("messages").query_items(
                query=query, parameters=params, partition_key=conversation_id
            )
        )
        return [_clean(i) for i in items]

    def get_all_messages_in_conversation(self, conversation_id: str) -> List[Dict[str, Any]]:
        """Return all messages in a conversation (used for mark-read)."""
        query = "SELECT * FROM c WHERE c.conversation_id = @conv_id"
        params = [{"name": "@conv_id", "value": conversation_id}]
        items = list(
            self._container("messages").query_items(
                query=query, parameters=params, partition_key=conversation_id
            )
        )
        return [_clean(i) for i in items]

    def update_message(self, conversation_id: str, message_id: str, data: Dict[str, Any]) -> None:
        """Merge-update a single message."""
        items = list(
            self._container("messages").query_items(
                query="SELECT * FROM c WHERE c.id = @id",
                parameters=[{"name": "@id", "value": message_id}],
                partition_key=conversation_id,
            )
        )
        if not items:
            return
        merged = {**items[0], **data}
        self._container("messages").replace_item(item=message_id, body=merged)

    # ── Swap Requests ─────────────────────────────────────────────────────────

    def create_swap_request(self, requester_uid: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a swap request. Uses requester_uid as partition key."""
        req_id = str(uuid.uuid4())
        now = _utcnow_iso()
        doc = {
            "id": req_id,
            "uid": requester_uid,  # partition key
            "created_at": now,
            "updated_at": now,
            **data,
        }
        self._container("swap_requests").create_item(body=doc)
        return _clean(doc)

    def get_swap_request_by_id(self, request_id: str) -> Optional[Dict[str, Any]]:
        """Fetch a swap request by its ID (cross-partition)."""
        query = "SELECT * FROM c WHERE c.id = @id"
        params = [{"name": "@id", "value": request_id}]
        items = list(
            self._container("swap_requests").query_items(
                query=query, parameters=params, enable_cross_partition_query=True
            )
        )
        return _clean(items[0]) if items else None

    def update_swap_request(
        self, request_id: str, requester_uid: str, update_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Merge-update a swap request."""
        existing = self.get_swap_request_by_id(request_id)
        if existing is None:
            raise KeyError(f"Swap request {request_id} not found")
        update_data["updated_at"] = _utcnow_iso()
        merged = {**existing, **update_data, "id": request_id, "uid": requester_uid}
        self._container("swap_requests").replace_item(item=request_id, body=merged)
        return _clean(merged)

    def query_outgoing_requests(
        self, requester_uid: str, status: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Requests sent BY requester_uid (within partition — efficient)."""
        if status:
            query = "SELECT * FROM c WHERE c.requester_uid = @uid AND c.status = @status"
            params = [{"name": "@uid", "value": requester_uid}, {"name": "@status", "value": status}]
        else:
            query = "SELECT * FROM c WHERE c.requester_uid = @uid"
            params = [{"name": "@uid", "value": requester_uid}]
        items = list(
            self._container("swap_requests").query_items(
                query=query, parameters=params, partition_key=requester_uid
            )
        )
        results = [_clean(i) for i in items]
        results.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return results

    def query_incoming_requests(
        self, recipient_uid: str, status: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Requests received BY recipient_uid (cross-partition query)."""
        if status:
            query = "SELECT * FROM c WHERE c.recipient_uid = @uid AND c.status = @status"
            params = [{"name": "@uid", "value": recipient_uid}, {"name": "@status", "value": status}]
        else:
            query = "SELECT * FROM c WHERE c.recipient_uid = @uid"
            params = [{"name": "@uid", "value": recipient_uid}]
        items = list(
            self._container("swap_requests").query_items(
                query=query, parameters=params, enable_cross_partition_query=True
            )
        )
        results = [_clean(i) for i in items]
        results.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return results

    def check_pending_request_exists(self, requester_uid: str, recipient_uid: str) -> bool:
        """Return True if a pending request already exists from requester → recipient."""
        query = (
            "SELECT c.id FROM c WHERE c.requester_uid = @req AND"
            " c.recipient_uid = @rec AND c.status = 'pending'"
        )
        params = [{"name": "@req", "value": requester_uid}, {"name": "@rec", "value": recipient_uid}]
        items = list(
            self._container("swap_requests").query_items(
                query=query, parameters=params, partition_key=requester_uid
            )
        )
        return len(items) > 0

    # ── Blocks ────────────────────────────────────────────────────────────────

    def create_block(self, blocker_uid: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a block record. Uses blocker_uid as partition key."""
        block_id = str(uuid.uuid4())
        now = _utcnow_iso()
        doc = {
            "id": block_id,
            "uid": blocker_uid,  # partition key
            "created_at": now,
            **data,
        }
        self._container("blocks").create_item(body=doc)
        return _clean(doc)

    def get_block(self, blocker_uid: str, blocked_uid: str) -> Optional[Dict[str, Any]]:
        """Fetch a specific block record (within blocker's partition)."""
        query = "SELECT * FROM c WHERE c.blocker_uid = @blocker AND c.blocked_uid = @blocked"
        params = [{"name": "@blocker", "value": blocker_uid}, {"name": "@blocked", "value": blocked_uid}]
        items = list(
            self._container("blocks").query_items(
                query=query, parameters=params, partition_key=blocker_uid
            )
        )
        return _clean(items[0]) if items else None

    def delete_block(self, block_id: str, blocker_uid: str) -> None:
        """Delete a block record."""
        self._container("blocks").delete_item(item=block_id, partition_key=blocker_uid)

    def list_blocks_by_user(self, blocker_uid: str) -> List[Dict[str, Any]]:
        """List all blocks created by blocker_uid."""
        query = "SELECT * FROM c WHERE c.blocker_uid = @uid"
        params = [{"name": "@uid", "value": blocker_uid}]
        items = list(
            self._container("blocks").query_items(
                query=query, parameters=params, partition_key=blocker_uid
            )
        )
        results = [_clean(i) for i in items]
        results.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return results

    def check_blocked(self, uid1: str, uid2: str) -> bool:
        """Return True if uid1 has blocked uid2 OR uid2 has blocked uid1."""
        block_fwd = self.get_block(uid1, uid2)
        if block_fwd:
            return True
        block_rev = self.get_block(uid2, uid1)
        return block_rev is not None

    # ── Reports ───────────────────────────────────────────────────────────────

    def create_report(self, reporter_uid: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a user report. Uses reporter_uid as partition key."""
        report_id = str(uuid.uuid4())
        now = _utcnow_iso()
        doc = {
            "id": report_id,
            "uid": reporter_uid,  # partition key
            "created_at": now,
            **data,
        }
        self._container("reports").create_item(body=doc)
        return _clean(doc)

    def list_user_reports(self, reporter_uid: str) -> List[Dict[str, Any]]:
        """List all reports filed by reporter_uid."""
        query = "SELECT * FROM c WHERE c.reporter_uid = @uid"
        params = [{"name": "@uid", "value": reporter_uid}]
        items = list(
            self._container("reports").query_items(
                query=query, parameters=params, partition_key=reporter_uid
            )
        )
        results = [_clean(i) for i in items]
        results.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return results

    # ── Points / Credits ─────────────────────────────────────────────────────

    def create_points_transaction(self, uid: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a points/credits transaction record."""
        txn_id = str(uuid.uuid4())
        now = _utcnow_iso()
        doc = {
            "id": txn_id,
            "uid": uid,
            "created_at": now,
            **data,
        }
        self._container("points_transactions").create_item(body=doc)
        return _clean(doc)

    def get_points_balance(self, uid: str) -> Dict[str, int]:
        """Calculate current points and credits balance for a user."""
        query = "SELECT c.type, c.points, c.credits FROM c WHERE c.uid = @uid"
        params = [{"name": "@uid", "value": uid}]
        items = list(
            self._container("points_transactions").query_items(
                query=query, parameters=params, partition_key=uid
            )
        )
        total_points = 0
        total_credits = 0
        for item in items:
            if item.get("type") == "earned":
                total_points += item.get("points", 0)
                total_credits += item.get("credits", 0)
            elif item.get("type") == "spent":
                total_points -= item.get("points", 0)
                total_credits -= item.get("credits", 0)
        return {"points": max(total_points, 0), "credits": max(total_credits, 0)}

    def get_points_history(self, uid: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get transaction history for a user, newest first."""
        query = f"SELECT * FROM c WHERE c.uid = @uid ORDER BY c.created_at DESC OFFSET 0 LIMIT {limit}"
        params = [{"name": "@uid", "value": uid}]
        items = list(
            self._container("points_transactions").query_items(
                query=query, parameters=params, partition_key=uid
            )
        )
        return [_clean(i) for i in items]

    # ── Skills ────────────────────────────────────────────────────────────────

    def create_skill(self, uid: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a skill document. Uses posted_by (uid) as partition key."""
        skill_id = str(uuid.uuid4())
        now = _utcnow_iso()
        doc = {
            "id": skill_id,
            "posted_by": uid,
            "created_at": now,
            "updated_at": now,
            **data,
        }
        self._container("skills").create_item(body=doc)
        return _clean(doc)

    def get_skill(self, skill_id: str, posted_by: str) -> Optional[Dict[str, Any]]:
        """Fetch a skill by ID + partition key."""
        try:
            doc = self._container("skills").read_item(item=skill_id, partition_key=posted_by)
            return _clean(doc)
        except cosmos_exc.CosmosResourceNotFoundError:
            return None

    def get_skills_by_user(self, uid: str) -> List[Dict[str, Any]]:
        """List all skills posted by a user."""
        query = "SELECT * FROM c WHERE c.posted_by = @uid ORDER BY c.created_at DESC"
        params = [{"name": "@uid", "value": uid}]
        items = list(
            self._container("skills").query_items(
                query=query, parameters=params, partition_key=uid
            )
        )
        return [_clean(i) for i in items]

    def delete_skill(self, skill_id: str, posted_by: str) -> None:
        """Delete a skill document."""
        self._container("skills").delete_item(item=skill_id, partition_key=posted_by)

    # ── Generic helpers (used by migration script) ────────────────────────────

    def get_container(self, name: str):
        """Return a raw container client (for the migration script)."""
        return self._container(name)

    def upsert_item(self, container_name: str, item: Dict[str, Any]) -> None:
        """Generic upsert used by the migration script."""
        self._container(container_name).upsert_item(body=item)


# ── Internal helpers ──────────────────────────────────────────────────────────

def _clean(doc: Dict[str, Any]) -> Dict[str, Any]:
    """Remove Cosmos internal metadata fields before returning to callers."""
    cosmos_keys = {"_rid", "_self", "_etag", "_attachments", "_ts"}
    return {k: v for k, v in doc.items() if k not in cosmos_keys}


# ── Singleton ─────────────────────────────────────────────────────────────────

_cosmos_service: Optional[CosmosService] = None


def get_cosmos_service() -> CosmosService:
    """Return (or lazily create) the singleton CosmosService."""
    global _cosmos_service
    if _cosmos_service is None:
        _cosmos_service = CosmosService()
    return _cosmos_service
