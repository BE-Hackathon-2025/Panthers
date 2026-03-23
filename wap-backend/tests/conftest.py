"""Pytest configuration and shared fixtures.

All external services (Cosmos DB, Azure Search, Redis, ACS Email, OpenAI) are
mocked so tests run fully offline with no credentials.
"""
from __future__ import annotations

import os
import sys
import uuid
from datetime import datetime, timezone
from types import ModuleType
from typing import Any, Dict, List, Optional
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient


# ── Mock Azure SDKs if not installed (dev/CI environments) ────────────────────

def _install_azure_mocks():
    """Pre-populate sys.modules with stubs for Azure SDKs so import succeeds."""
    _azure = MagicMock()

    # Cosmos exceptions must be real exception subclasses for try/except
    _azure.cosmos.exceptions.CosmosResourceNotFoundError = type(
        "CosmosResourceNotFoundError", (Exception,), {}
    )
    _azure.cosmos.exceptions.CosmosHttpResponseError = type(
        "CosmosHttpResponseError", (Exception,), {}
    )

    for mod_path in [
        "azure", "azure.cosmos", "azure.cosmos.exceptions",
        "azure.core", "azure.core.credentials",
        "azure.search", "azure.search.documents",
        "azure.search.documents.indexes",
        "azure.search.documents.indexes.models",
        "azure.search.documents.models",
        "azure.identity",
        "azure.communication", "azure.communication.email",
    ]:
        parts = mod_path.split(".")
        obj = _azure
        for p in parts[1:]:
            obj = getattr(obj, p)
        sys.modules.setdefault(mod_path, obj)

if "azure.cosmos" not in sys.modules:
    _install_azure_mocks()


# ── Environment ───────────────────────────────────────────────────────────────

@pytest.fixture(scope="session", autouse=True)
def setup_test_env():
    """Configure env vars before any module is imported."""
    os.environ.setdefault("DEBUG", "true")
    os.environ.setdefault("REDIS_ENABLED", "false")
    os.environ.setdefault("EMAIL_ENABLED", "false")
    os.environ.setdefault("COSMOS_CONNECTION_STRING", "AccountEndpoint=https://test.documents.azure.com:443/;AccountKey=dGVzdA==;")
    os.environ.setdefault("AZURE_OPENAI_ENDPOINT", "https://test.openai.azure.com/")
    os.environ.setdefault("AZURE_OPENAI_API_KEY", "test-openai-key")
    os.environ.setdefault("AZURE_SEARCH_ENDPOINT", "https://test.search.windows.net")
    os.environ.setdefault("AZURE_SEARCH_API_KEY", "test-search-key")
    os.environ.setdefault("AZURE_ENTRA_TENANT_NAME", "testciam")
    os.environ.setdefault("AZURE_ENTRA_TENANT_ID", "test-tenant-id")
    os.environ.setdefault("AZURE_ENTRA_CLIENT_ID", "test-client-id")
    os.environ.setdefault("AZURE_ENTRA_AUDIENCE", "api://swap-api/access_as_user")


# ── In-memory Cosmos-compatible store ─────────────────────────────────────────

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class InMemoryStore:
    """Dict-backed store that implements the CosmosService interface."""

    def __init__(self):
        self._profiles: Dict[str, Dict] = {}
        self._blocks: Dict[str, Dict] = {}       # key: "{blocker}:{blocked}"
        self._reports: Dict[str, Dict] = {}
        self._swap_requests: Dict[str, Dict] = {}
        self._conversations: Dict[str, Dict] = {}
        self._messages: Dict[str, Dict] = {}

    def clear(self):
        self._profiles.clear()
        self._blocks.clear()
        self._reports.clear()
        self._swap_requests.clear()
        self._conversations.clear()
        self._messages.clear()

    # ── Profiles ──────────────────────────────────────────────────────────────

    def create_profile(self, uid: str, data: Dict) -> Dict:
        now = _now()
        doc = {"uid": uid, "created_at": now, "updated_at": now, **data}
        self._profiles[uid] = doc
        return dict(doc)

    def get_profile(self, uid: str) -> Optional[Dict]:
        return dict(self._profiles[uid]) if uid in self._profiles else None

    def update_profile(self, uid: str, data: Dict) -> Dict:
        if uid not in self._profiles:
            raise KeyError(f"Profile {uid} not found")
        data["updated_at"] = _now()
        self._profiles[uid].update(data)
        return dict(self._profiles[uid])

    def upsert_profile(self, uid: str, data: Dict) -> Dict:
        now = _now()
        if uid in self._profiles:
            data["updated_at"] = now
            self._profiles[uid].update(data)
        else:
            self._profiles[uid] = {"uid": uid, "created_at": now, "updated_at": now, **data}
        return dict(self._profiles[uid])

    def delete_profile(self, uid: str) -> bool:
        self._profiles.pop(uid, None)
        return True

    def list_profiles(self, limit: int = 100) -> List:
        return list(self._profiles.values())[:limit]

    def get_profile_by_email(self, email: str) -> Optional[Dict]:
        for doc in self._profiles.values():
            if doc.get("email") == email:
                return dict(doc)
        return None

    # ── Blocks ────────────────────────────────────────────────────────────────

    def create_block(self, blocker_uid: str, data: Dict) -> Dict:
        doc_id = str(uuid.uuid4())
        now = _now()
        doc = {"id": doc_id, "uid": blocker_uid, "created_at": now, **data}
        key = f"{data['blocker_uid']}:{data['blocked_uid']}"
        self._blocks[key] = doc
        return dict(doc)

    def get_block(self, blocker_uid: str, blocked_uid: str) -> Optional[Dict]:
        key = f"{blocker_uid}:{blocked_uid}"
        item = self._blocks.get(key)
        return dict(item) if item else None

    def delete_block(self, blocker_uid: str, blocked_uid: str) -> bool:
        key = f"{blocker_uid}:{blocked_uid}"
        if key not in self._blocks:
            return False
        del self._blocks[key]
        return True

    def list_blocks_by_user(self, uid: str) -> List:
        return [dict(v) for v in self._blocks.values() if v.get("blocker_uid") == uid]

    def check_blocked(self, uid1: str, uid2: str) -> bool:
        return (
            f"{uid1}:{uid2}" in self._blocks
            or f"{uid2}:{uid1}" in self._blocks
        )

    # ── Reports ───────────────────────────────────────────────────────────────

    def create_report(self, reporter_uid: str, data: Dict) -> Dict:
        doc_id = str(uuid.uuid4())
        now = _now()
        doc = {"id": doc_id, "uid": reporter_uid, "created_at": now, "updated_at": now, **data}
        self._reports[doc_id] = doc
        return dict(doc)

    def list_user_reports(self, uid: str) -> List:
        return [dict(v) for v in self._reports.values() if v.get("reporter_uid") == uid]

    # ── Swap Requests ─────────────────────────────────────────────────────────

    def create_swap_request(self, data: Dict) -> Dict:
        doc_id = str(uuid.uuid4())
        now = _now()
        doc = {"id": doc_id, "uid": data.get("requester_uid", ""), "created_at": now, "updated_at": now, **data}
        self._swap_requests[doc_id] = doc
        return dict(doc)

    def get_swap_request_by_id(self, request_id: str) -> Optional[Dict]:
        item = self._swap_requests.get(request_id)
        return dict(item) if item else None

    def update_swap_request(self, request_id: str, data: Dict) -> Dict:
        if request_id not in self._swap_requests:
            raise KeyError(f"SwapRequest {request_id} not found")
        data["updated_at"] = _now()
        self._swap_requests[request_id].update(data)
        return dict(self._swap_requests[request_id])

    def query_incoming_requests(self, recipient_uid: str, status: Optional[str] = None) -> List:
        results = [
            dict(v) for v in self._swap_requests.values()
            if v.get("recipient_uid") == recipient_uid
        ]
        if status:
            results = [r for r in results if r.get("status") == status]
        return results

    def query_outgoing_requests(self, requester_uid: str, status: Optional[str] = None) -> List:
        results = [
            dict(v) for v in self._swap_requests.values()
            if v.get("requester_uid") == requester_uid
        ]
        if status:
            results = [r for r in results if r.get("status") == status]
        return results

    def check_pending_request_exists(self, requester_uid: str, recipient_uid: str) -> bool:
        return any(
            v.get("requester_uid") == requester_uid
            and v.get("recipient_uid") == recipient_uid
            and v.get("status") == "pending"
            for v in self._swap_requests.values()
        )

    # ── Conversations ─────────────────────────────────────────────────────────

    def create_conversation(self, data: Dict) -> Dict:
        conv_id = str(uuid.uuid4())
        now = _now()
        doc = {"id": conv_id, "conversation_id": conv_id, "created_at": now, "updated_at": now, **data}
        self._conversations[conv_id] = doc
        return dict(doc)

    def get_conversation(self, conversation_id: str) -> Optional[Dict]:
        item = self._conversations.get(conversation_id)
        return dict(item) if item else None

    def update_conversation(self, conversation_id: str, data: Dict) -> Dict:
        if conversation_id not in self._conversations:
            raise KeyError(f"Conversation {conversation_id} not found")
        data["updated_at"] = _now()
        self._conversations[conversation_id].update(data)
        return dict(self._conversations[conversation_id])

    def query_conversations_for_user(self, uid: str) -> List:
        return [
            dict(v) for v in self._conversations.values()
            if uid in v.get("participant_uids", [])
        ]

    # ── Messages ──────────────────────────────────────────────────────────────

    def create_message(self, data: Dict) -> Dict:
        msg_id = str(uuid.uuid4())
        now = _now()
        doc = {"id": msg_id, "created_at": now, **data}
        self._messages[msg_id] = doc
        return dict(doc)

    def get_messages(
        self, conversation_id: str, limit: int = 50, before_id: Optional[str] = None
    ) -> List:
        msgs = [
            dict(v) for v in self._messages.values()
            if v.get("conversation_id") == conversation_id
        ]
        msgs.sort(key=lambda m: m.get("created_at", ""), reverse=True)
        if before_id:
            idx = next((i for i, m in enumerate(msgs) if m["id"] == before_id), None)
            if idx is not None:
                msgs = msgs[idx + 1:]
        return msgs[:limit]

    def get_all_messages_in_conversation(self, conversation_id: str) -> List:
        msgs = [
            dict(v) for v in self._messages.values()
            if v.get("conversation_id") == conversation_id
        ]
        msgs.sort(key=lambda m: m.get("created_at", ""))
        return msgs

    def update_message(self, conversation_id: str, message_id: str, data: Dict) -> Dict:
        if message_id not in self._messages:
            raise KeyError(f"Message {message_id} not found")
        self._messages[message_id].update(data)
        return dict(self._messages[message_id])


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def store() -> InMemoryStore:
    return InMemoryStore()


@pytest.fixture(autouse=True)
def clear_store(store):
    """Reset in-memory store before each test."""
    store.clear()


@pytest.fixture(scope="session")
def mock_search_service():
    svc = MagicMock()
    svc.upsert_profile.return_value = None
    svc.delete_profile.return_value = None
    svc.search.return_value = []
    return svc


@pytest.fixture(scope="session")
def mock_embedding_service():
    svc = MagicMock()
    svc.encode.return_value = [0.1] * 1536
    svc.encode_batch.return_value = [[0.1] * 1536]
    svc.dimension = 1536
    return svc


@pytest.fixture
def client(store, mock_search_service, mock_embedding_service):
    """Test client with all external services mocked."""
    with (
        patch("app.cosmos_db.get_cosmos_service", return_value=store),
        patch("app.azure_search.get_azure_search_service", return_value=mock_search_service),
        patch("app.embeddings.get_embedding_service", return_value=mock_embedding_service),
        patch("app.routers.profiles.get_cosmos_service", return_value=store),
        patch("app.routers.profiles.get_azure_search_service", return_value=mock_search_service),
        patch("app.routers.profiles.get_embedding_service", return_value=mock_embedding_service),
        patch("app.routers.swap_requests.get_cosmos_service", return_value=store),
        patch("app.routers.messages.get_cosmos_service", return_value=store),
        patch("app.routers.moderation.get_cosmos_service", return_value=store),
        patch("app.routers.profiles.get_email_service", return_value=MagicMock()),
        patch("app.routers.swap_requests.get_email_service", return_value=MagicMock()),
        patch("app.routers.messages.get_email_service", return_value=MagicMock()),
    ):
        from app.main import app
        yield TestClient(app, raise_server_exceptions=True)
