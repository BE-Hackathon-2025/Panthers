"""General API integration tests — smoke tests covering all routers."""
import pytest


class TestProfileEndpoints:
    def test_upsert_profile_minimal(self, client):
        resp = client.post("/profiles/upsert", json={
            "uid": "t001", "email": "t001@example.com", "display_name": "T001",
        })
        assert resp.status_code == 200
        assert resp.json()["uid"] == "t001"

    def test_upsert_profile_with_skills(self, client):
        resp = client.post("/profiles/upsert", json={
            "uid": "t002",
            "email": "t002@example.com",
            "display_name": "T002",
            "skills_to_offer": "Python, JS",
            "services_needed": "Guitar",
        })
        assert resp.status_code == 200
        assert resp.json()["skills_to_offer"] == "Python, JS"

    def test_get_profile_by_uid(self, client):
        client.post("/profiles/upsert", json={
            "uid": "t003", "email": "t003@example.com",
        })
        resp = client.get("/profiles/t003")
        assert resp.status_code == 200
        assert resp.json()["uid"] == "t003"

    def test_get_profile_not_found(self, client):
        assert client.get("/profiles/nonexistent_xyz_123").status_code == 404

    def test_get_profile_by_email(self, client):
        client.post("/profiles/upsert", json={
            "uid": "t004", "email": "t004@example.com",
        })
        resp = client.get("/profiles/email/t004@example.com")
        assert resp.status_code == 200
        assert resp.json()["email"] == "t004@example.com"

    def test_patch_profile(self, client):
        client.post("/profiles/upsert", json={
            "uid": "t005", "email": "t005@example.com", "bio": "old",
        })
        resp = client.patch("/profiles/t005", json={"bio": "new", "city": "NYC"})
        assert resp.status_code == 200
        assert resp.json()["bio"] == "new"
        assert resp.json()["city"] == "NYC"

    def test_delete_profile(self, client):
        client.post("/profiles/upsert", json={
            "uid": "t006", "email": "t006@example.com",
        })
        assert client.delete("/profiles/t006").status_code == 200
        assert client.get("/profiles/t006").status_code == 404


class TestSearchEndpoints:
    def test_search_offers_mode(self, client):
        resp = client.post("/search", json={"query": "python", "limit": 5, "mode": "offers"})
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_search_needs_mode(self, client):
        resp = client.post("/search", json={"query": "guitar", "limit": 5, "mode": "needs"})
        assert resp.status_code == 200

    def test_search_both_mode(self, client):
        resp = client.post("/search", json={"query": "coding", "limit": 5, "mode": "both"})
        assert resp.status_code == 200

    def test_search_invalid_mode_returns_422(self, client):
        resp = client.post("/search", json={"query": "test", "mode": "invalid"})
        assert resp.status_code == 422


class TestValidation:
    def test_upsert_missing_email_returns_422(self, client):
        assert client.post("/profiles/upsert", json={"uid": "u"}).status_code == 422

    def test_upsert_invalid_email_returns_422(self, client):
        assert client.post("/profiles/upsert", json={
            "uid": "u", "email": "bad",
        }).status_code == 422

    def test_search_missing_query_returns_422(self, client):
        assert client.post("/search", json={}).status_code == 422

    def test_block_yourself_returns_400(self, client):
        resp = client.post(
            "/moderation/block",
            params={"uid": "me"},
            json={"blocked_uid": "me"},
        )
        assert resp.status_code == 400

    def test_report_yourself_returns_400(self, client):
        resp = client.post(
            "/moderation/report",
            params={"uid": "me"},
            json={"reported_uid": "me", "reason": "spam", "details": "Reporting myself."},
        )
        assert resp.status_code == 400
