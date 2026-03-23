"""Unit tests for CosmosService (azure_cosmos mocked — no real Azure needed)."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict
from unittest.mock import MagicMock, patch, call

import pytest

# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_cosmos_service():
    """Create a CosmosService with a fully mocked CosmosClient."""
    mock_client = MagicMock()
    mock_db = MagicMock()
    mock_client.create_database_if_not_exists.return_value = mock_db
    mock_db.create_container_if_not_exists.return_value = MagicMock()

    with patch("app.cosmos_db.CosmosClient") as MockClient:
        MockClient.from_connection_string.return_value = mock_client
        from app.cosmos_db import CosmosService
        svc = CosmosService.__new__(CosmosService)
        svc._initialized = False
        svc._client = None
        svc._db = None
        # Trigger init manually
        svc._client = mock_client
        svc._db = mock_db
        svc._initialized = True
        return svc, mock_db


def _make_item(uid: str, extra: Dict[str, Any] = None) -> Dict:
    doc = {
        "id": uid,
        "uid": uid,
        "email": f"{uid}@example.com",
        "display_name": f"User {uid}",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if extra:
        doc.update(extra)
    return doc


# ── CosmosService.get_profile ─────────────────────────────────────────────────

class TestGetProfile:
    def test_returns_profile_when_found(self):
        svc, mock_db = _make_cosmos_service()
        expected = _make_item("uid123")
        container = MagicMock()
        container.read_item.return_value = expected
        mock_db.get_container_client.return_value = container

        result = svc.get_profile("uid123")

        container.read_item.assert_called_once_with(item="uid123", partition_key="uid123")
        assert result["uid"] == "uid123"

    def test_returns_none_when_not_found(self):
        from azure.cosmos import exceptions as cosmos_exc
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        container.read_item.side_effect = cosmos_exc.CosmosResourceNotFoundError(
            status_code=404, message="Not found"
        )
        mock_db.get_container_client.return_value = container

        result = svc.get_profile("nonexistent")
        assert result is None

    def test_strips_cosmos_internal_fields(self):
        svc, mock_db = _make_cosmos_service()
        raw = {**_make_item("uid1"), "_rid": "abc", "_self": "/dbs/x", "_etag": "etag", "_ts": 123}
        container = MagicMock()
        container.read_item.return_value = raw
        mock_db.get_container_client.return_value = container

        result = svc.get_profile("uid1")
        for internal_key in ("_rid", "_self", "_etag", "_ts", "_attachments"):
            assert internal_key not in result


# ── CosmosService.create_profile ──────────────────────────────────────────────

class TestCreateProfile:
    def test_creates_and_returns_profile(self):
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        mock_db.get_container_client.return_value = container

        result = svc.create_profile("new_uid", {"email": "new@example.com"})

        assert result["uid"] == "new_uid"
        assert result["id"] == "new_uid"
        assert result["email"] == "new@example.com"
        assert "created_at" in result
        assert "updated_at" in result
        container.create_item.assert_called_once()

    def test_timestamps_are_iso_strings(self):
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        mock_db.get_container_client.return_value = container

        result = svc.create_profile("ts_uid", {})
        # Both timestamps should be parseable ISO strings
        datetime.fromisoformat(result["created_at"])
        datetime.fromisoformat(result["updated_at"])


# ── CosmosService.update_profile ─────────────────────────────────────────────

class TestUpdateProfile:
    def test_updates_existing_profile(self):
        svc, mock_db = _make_cosmos_service()
        existing = _make_item("up_uid", {"bio": "old bio"})
        container = MagicMock()
        container.read_item.return_value = existing
        mock_db.get_container_client.return_value = container

        result = svc.update_profile("up_uid", {"bio": "new bio"})

        container.replace_item.assert_called_once()
        assert result["bio"] == "new bio"

    def test_raises_key_error_when_not_found(self):
        from azure.cosmos import exceptions as cosmos_exc
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        container.read_item.side_effect = cosmos_exc.CosmosResourceNotFoundError(
            status_code=404, message="Not found"
        )
        mock_db.get_container_client.return_value = container

        with pytest.raises(KeyError):
            svc.update_profile("missing", {"bio": "x"})

    def test_updated_at_is_refreshed(self):
        svc, mock_db = _make_cosmos_service()
        old_ts = "2024-01-01T00:00:00+00:00"
        existing = _make_item("ts_uid", {"updated_at": old_ts})
        container = MagicMock()
        container.read_item.return_value = existing
        mock_db.get_container_client.return_value = container

        result = svc.update_profile("ts_uid", {"city": "NYC"})
        assert result["updated_at"] != old_ts


# ── CosmosService.upsert_profile ─────────────────────────────────────────────

class TestUpsertProfile:
    def test_creates_when_not_exists(self):
        from azure.cosmos import exceptions as cosmos_exc
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        container.read_item.side_effect = cosmos_exc.CosmosResourceNotFoundError(
            status_code=404, message="Not found"
        )
        mock_db.get_container_client.return_value = container

        result = svc.upsert_profile("brand_new", {"email": "new@example.com"})

        container.upsert_item.assert_called_once()
        assert result["uid"] == "brand_new"
        assert "created_at" in result

    def test_updates_when_exists(self):
        svc, mock_db = _make_cosmos_service()
        existing = _make_item("existing_uid", {"email": "e@example.com"})
        container = MagicMock()
        container.read_item.return_value = existing
        mock_db.get_container_client.return_value = container

        result = svc.upsert_profile("existing_uid", {"bio": "new bio"})

        container.upsert_item.assert_called_once()
        assert result["uid"] == "existing_uid"

    def test_preserves_created_at_on_update(self):
        svc, mock_db = _make_cosmos_service()
        original_ts = "2024-01-01T00:00:00+00:00"
        existing = _make_item("uid_ts", {"created_at": original_ts})
        container = MagicMock()
        container.read_item.return_value = existing
        mock_db.get_container_client.return_value = container

        result = svc.upsert_profile("uid_ts", {"bio": "update"})
        assert result["created_at"] == original_ts


# ── CosmosService.delete_profile ─────────────────────────────────────────────

class TestDeleteProfile:
    def test_calls_delete_and_returns_true(self):
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        mock_db.get_container_client.return_value = container

        result = svc.delete_profile("del_uid")

        container.delete_item.assert_called_once_with(item="del_uid", partition_key="del_uid")
        assert result is True


# ── CosmosService.list_profiles ───────────────────────────────────────────────

class TestListProfiles:
    def test_returns_list(self):
        svc, mock_db = _make_cosmos_service()
        items = [_make_item(f"uid{i}") for i in range(3)]
        container = MagicMock()
        container.query_items.return_value = items
        mock_db.get_container_client.return_value = container

        result = svc.list_profiles(limit=10)
        assert len(result) == 3

    def test_respects_limit_in_query(self):
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        container.query_items.return_value = []
        mock_db.get_container_client.return_value = container

        svc.list_profiles(limit=42)
        # The query string should contain the limit
        call_kwargs = container.query_items.call_args
        query_str = call_kwargs[1].get("query") or call_kwargs[0][0]
        assert "42" in query_str

    def test_empty_when_no_profiles(self):
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        container.query_items.return_value = []
        mock_db.get_container_client.return_value = container

        result = svc.list_profiles()
        assert result == []


# ── CosmosService.get_profile_by_email ───────────────────────────────────────

class TestGetProfileByEmail:
    def test_returns_profile_when_found(self):
        svc, mock_db = _make_cosmos_service()
        found = _make_item("email_uid")
        container = MagicMock()
        container.query_items.return_value = [found]
        mock_db.get_container_client.return_value = container

        result = svc.get_profile_by_email("email_uid@example.com")
        assert result is not None
        assert result["uid"] == "email_uid"

    def test_returns_none_when_not_found(self):
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        container.query_items.return_value = []
        mock_db.get_container_client.return_value = container

        result = svc.get_profile_by_email("nobody@example.com")
        assert result is None

    def test_passes_email_as_param(self):
        svc, mock_db = _make_cosmos_service()
        container = MagicMock()
        container.query_items.return_value = []
        mock_db.get_container_client.return_value = container

        svc.get_profile_by_email("find@example.com")
        call_kwargs = container.query_items.call_args[1]
        params = call_kwargs.get("parameters", [])
        assert any(p["value"] == "find@example.com" for p in params)


# ── Internal helpers ──────────────────────────────────────────────────────────

class TestCleanHelper:
    def test_removes_all_cosmos_metadata_fields(self):
        from app.cosmos_db import _clean
        doc = {
            "id": "x",
            "uid": "x",
            "_rid": "r",
            "_self": "s",
            "_etag": "e",
            "_attachments": "a",
            "_ts": 123,
            "email": "x@example.com",
        }
        result = _clean(doc)
        assert "email" in result
        assert "_rid" not in result
        assert "_self" not in result
        assert "_etag" not in result
        assert "_attachments" not in result
        assert "_ts" not in result

    def test_preserves_non_internal_fields(self):
        from app.cosmos_db import _clean
        doc = {"id": "1", "uid": "1", "bio": "hello", "city": "NYC"}
        result = _clean(doc)
        assert result == doc


# ── Singleton ─────────────────────────────────────────────────────────────────

class TestGetCosmosService:
    def test_returns_same_instance(self):
        import app.cosmos_db as module
        # Reset singleton
        original = module._cosmos_service
        module._cosmos_service = None
        try:
            with patch.object(module.CosmosService, "_init_cosmos"):
                svc1 = module.get_cosmos_service()
                svc2 = module.get_cosmos_service()
                assert svc1 is svc2
        finally:
            module._cosmos_service = original
