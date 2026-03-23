"""Integration tests for /profiles router (all external services mocked)."""
from __future__ import annotations

import pytest


# ── POST /profiles/upsert ─────────────────────────────────────────────────────

class TestUpsertProfile:
    def test_creates_minimal_profile(self, client):
        resp = client.post("/profiles/upsert", json={
            "uid": "uid_minimal",
            "email": "minimal@example.com",
            "display_name": "Minimal User",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["uid"] == "uid_minimal"
        assert data["email"] == "minimal@example.com"

    def test_creates_full_profile(self, client):
        resp = client.post("/profiles/upsert", json={
            "uid": "uid_full",
            "email": "full@example.com",
            "display_name": "Full User",
            "skills_to_offer": "Python, FastAPI",
            "services_needed": "Guitar lessons",
            "bio": "Loves coding",
            "city": "London",
            "dm_open": True,
            "show_city": True,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["skills_to_offer"] == "Python, FastAPI"
        assert data["city"] == "London"

    def test_missing_uid_returns_422(self, client):
        resp = client.post("/profiles/upsert", json={"email": "a@example.com"})
        assert resp.status_code == 422

    def test_missing_email_returns_422(self, client):
        resp = client.post("/profiles/upsert", json={"uid": "u1"})
        assert resp.status_code == 422

    def test_invalid_email_returns_422(self, client):
        resp = client.post("/profiles/upsert", json={
            "uid": "u1", "email": "not-an-email",
        })
        assert resp.status_code == 422

    def test_upsert_updates_existing_profile(self, client):
        # Create
        client.post("/profiles/upsert", json={
            "uid": "uid_up",
            "email": "up@example.com",
            "display_name": "Original",
        })
        # Update
        resp = client.post("/profiles/upsert", json={
            "uid": "uid_up",
            "email": "up@example.com",
            "display_name": "Updated",
        })
        assert resp.status_code == 200
        assert resp.json()["display_name"] == "Updated"

    def test_profile_has_created_at(self, client):
        resp = client.post("/profiles/upsert", json={
            "uid": "uid_ts", "email": "ts@example.com",
        })
        assert resp.status_code == 200
        assert "created_at" in resp.json()

    def test_upsert_triggers_search_indexing_when_skills_present(
        self, client, mock_search_service, mock_embedding_service
    ):
        client.post("/profiles/upsert", json={
            "uid": "uid_idx",
            "email": "idx@example.com",
            "display_name": "Indexer",
            "skills_to_offer": "Python",
            "services_needed": "Guitar",
        })
        mock_embedding_service.encode.assert_called()
        mock_search_service.upsert_profile.assert_called()

    def test_upsert_skips_indexing_when_no_skills(
        self, client, mock_search_service, mock_embedding_service
    ):
        mock_embedding_service.encode.reset_mock()
        mock_search_service.upsert_profile.reset_mock()

        client.post("/profiles/upsert", json={
            "uid": "uid_noskills",
            "email": "noskills@example.com",
        })
        mock_embedding_service.encode.assert_not_called()
        mock_search_service.upsert_profile.assert_not_called()


# ── GET /profiles/{uid} ───────────────────────────────────────────────────────

class TestGetProfile:
    def test_returns_profile_when_found(self, client):
        client.post("/profiles/upsert", json={
            "uid": "uid_get", "email": "get@example.com", "display_name": "Getter",
        })
        resp = client.get("/profiles/uid_get")
        assert resp.status_code == 200
        assert resp.json()["uid"] == "uid_get"

    def test_returns_404_when_not_found(self, client):
        resp = client.get("/profiles/nonexistent_uid_xyz")
        assert resp.status_code == 404

    def test_returns_all_profile_fields(self, client):
        client.post("/profiles/upsert", json={
            "uid": "uid_fields",
            "email": "fields@example.com",
            "display_name": "Fields",
            "bio": "Bio here",
            "city": "Berlin",
        })
        resp = client.get("/profiles/uid_fields")
        data = resp.json()
        assert data["bio"] == "Bio here"
        assert data["city"] == "Berlin"

    def test_404_detail_message(self, client):
        resp = client.get("/profiles/ghost_user")
        assert "not found" in resp.json()["detail"].lower()


# ── GET /profiles/email/{email} ───────────────────────────────────────────────

class TestGetProfileByEmail:
    def test_returns_profile_by_email(self, client):
        client.post("/profiles/upsert", json={
            "uid": "uid_email", "email": "by_email@example.com",
        })
        resp = client.get("/profiles/email/by_email@example.com")
        assert resp.status_code == 200
        assert resp.json()["email"] == "by_email@example.com"

    def test_returns_404_for_unknown_email(self, client):
        resp = client.get("/profiles/email/nobody@nowhere.com")
        assert resp.status_code == 404


# ── PATCH /profiles/{uid} ─────────────────────────────────────────────────────

class TestPatchProfile:
    def test_updates_bio(self, client):
        client.post("/profiles/upsert", json={
            "uid": "uid_patch", "email": "patch@example.com", "bio": "old bio",
        })
        resp = client.patch("/profiles/uid_patch", json={"bio": "new bio"})
        assert resp.status_code == 200
        assert resp.json()["bio"] == "new bio"

    def test_updates_city(self, client):
        client.post("/profiles/upsert", json={
            "uid": "uid_city", "email": "city@example.com",
        })
        resp = client.patch("/profiles/uid_city", json={"city": "Paris"})
        assert resp.status_code == 200
        assert resp.json()["city"] == "Paris"

    def test_does_not_change_unspecified_fields(self, client):
        client.post("/profiles/upsert", json={
            "uid": "uid_nochange",
            "email": "nochange@example.com",
            "display_name": "Original Name",
        })
        client.patch("/profiles/uid_nochange", json={"city": "Tokyo"})
        resp = client.get("/profiles/uid_nochange")
        assert resp.json()["display_name"] == "Original Name"

    def test_returns_404_for_nonexistent_profile(self, client):
        resp = client.patch("/profiles/ghost_uid", json={"bio": "hi"})
        assert resp.status_code == 404

    def test_patch_updates_search_index_when_skills_change(
        self, client, mock_search_service, mock_embedding_service
    ):
        client.post("/profiles/upsert", json={
            "uid": "uid_skills_patch",
            "email": "sp@example.com",
            "skills_to_offer": "Python",
            "services_needed": "Guitar",
        })
        mock_embedding_service.encode.reset_mock()
        mock_search_service.upsert_profile.reset_mock()

        client.patch("/profiles/uid_skills_patch", json={"skills_to_offer": "Go, Rust"})
        mock_embedding_service.encode.assert_called()


# ── DELETE /profiles/{uid} ────────────────────────────────────────────────────

class TestDeleteProfile:
    def test_deletes_existing_profile(self, client):
        client.post("/profiles/upsert", json={
            "uid": "uid_del", "email": "del@example.com",
        })
        resp = client.delete("/profiles/uid_del")
        assert resp.status_code == 200

    def test_deleted_profile_not_found_afterwards(self, client):
        client.post("/profiles/upsert", json={
            "uid": "uid_del2", "email": "del2@example.com",
        })
        client.delete("/profiles/uid_del2")
        resp = client.get("/profiles/uid_del2")
        assert resp.status_code == 404

    def test_delete_returns_404_for_nonexistent(self, client):
        resp = client.delete("/profiles/no_such_uid")
        assert resp.status_code == 404

    def test_delete_removes_from_search_index(self, client, mock_search_service):
        client.post("/profiles/upsert", json={
            "uid": "uid_del_idx", "email": "delidx@example.com",
        })
        mock_search_service.delete_profile.reset_mock()
        client.delete("/profiles/uid_del_idx")
        mock_search_service.delete_profile.assert_called_once_with("uid_del_idx")
