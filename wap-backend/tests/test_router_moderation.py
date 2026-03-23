"""Tests for /moderation router (Cosmos mocked via conftest InMemoryStore)."""
from __future__ import annotations

import pytest


def _create_profile(client, uid: str):
    client.post("/profiles/upsert", json={
        "uid": uid,
        "email": f"{uid}@example.com",
        "display_name": uid.capitalize(),
    })


# ── POST /moderation/block ────────────────────────────────────────────────────

class TestBlockUser:
    def test_cannot_block_yourself(self, client):
        resp = client.post(
            "/moderation/block",
            params={"uid": "self_uid"},
            json={"blocked_uid": "self_uid"},
        )
        assert resp.status_code == 400
        assert "yourself" in resp.json()["detail"].lower()

    def test_missing_uid_returns_422(self, client):
        resp = client.post(
            "/moderation/block",
            json={"blocked_uid": "other"},
        )
        assert resp.status_code == 422

    def test_missing_blocked_uid_returns_422(self, client):
        resp = client.post(
            "/moderation/block",
            params={"uid": "blocker"},
            json={},
        )
        assert resp.status_code == 422

    def test_successful_block_returns_200(self, client):
        resp = client.post(
            "/moderation/block",
            params={"uid": "blocker_uid"},
            json={"blocked_uid": "target_uid"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["blocker_uid"] == "blocker_uid"
        assert data["blocked_uid"] == "target_uid"

    def test_block_response_has_id(self, client):
        resp = client.post(
            "/moderation/block",
            params={"uid": "b1"},
            json={"blocked_uid": "b2"},
        )
        assert resp.status_code == 200
        assert "id" in resp.json()

    def test_block_response_has_created_at(self, client):
        resp = client.post(
            "/moderation/block",
            params={"uid": "b3"},
            json={"blocked_uid": "b4"},
        )
        assert "created_at" in resp.json()

    def test_block_with_reason(self, client):
        resp = client.post(
            "/moderation/block",
            params={"uid": "b5"},
            json={"blocked_uid": "b6", "reason": "Harassment"},
        )
        assert resp.status_code == 200
        assert resp.json()["reason"] == "Harassment"


# ── DELETE /moderation/block/{blocked_uid} ────────────────────────────────────

class TestUnblockUser:
    def test_unblock_nonexistent_returns_404(self, client):
        resp = client.delete(
            "/moderation/block/never_blocked",
            params={"uid": "some_uid"},
        )
        assert resp.status_code == 404

    def test_missing_uid_returns_422(self, client):
        resp = client.delete("/moderation/block/target")
        assert resp.status_code == 422


# ── GET /moderation/blocked ───────────────────────────────────────────────────

class TestListBlockedUsers:
    def test_returns_list(self, client):
        resp = client.get("/moderation/blocked", params={"uid": "some_uid"})
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/moderation/blocked")
        assert resp.status_code == 422


# ── POST /moderation/report ───────────────────────────────────────────────────

class TestReportUser:
    def test_cannot_report_yourself(self, client):
        resp = client.post(
            "/moderation/report",
            params={"uid": "self_uid"},
            json={
                "reported_uid": "self_uid",
                "reason": "spam",
                "details": "Reporting myself by mistake.",
            },
        )
        assert resp.status_code == 400
        assert "yourself" in resp.json()["detail"].lower()

    def test_valid_report_returns_200(self, client):
        resp = client.post(
            "/moderation/report",
            params={"uid": "reporter_uid"},
            json={
                "reported_uid": "bad_actor_uid",
                "reason": "spam",
                "details": "This user keeps spamming me with unsolicited messages.",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "pending"
        assert "id" in data

    def test_report_has_message(self, client):
        resp = client.post(
            "/moderation/report",
            params={"uid": "r1"},
            json={
                "reported_uid": "r2",
                "reason": "harassment",
                "details": "Harassing me repeatedly in messages.",
            },
        )
        assert "message" in resp.json()

    def test_invalid_reason_returns_422(self, client):
        resp = client.post(
            "/moderation/report",
            params={"uid": "r1"},
            json={
                "reported_uid": "r2",
                "reason": "not_a_real_reason",
                "details": "Some details here.",
            },
        )
        assert resp.status_code == 422

    def test_details_too_short_returns_422(self, client):
        resp = client.post(
            "/moderation/report",
            params={"uid": "r1"},
            json={
                "reported_uid": "r2",
                "reason": "spam",
                "details": "short",
            },
        )
        assert resp.status_code == 422

    def test_missing_uid_returns_422(self, client):
        resp = client.post(
            "/moderation/report",
            json={
                "reported_uid": "r2",
                "reason": "spam",
                "details": "Some details here that are long enough.",
            },
        )
        assert resp.status_code == 422

    def test_all_valid_reasons(self, client):
        for reason in ["spam", "harassment", "inappropriate_content", "scam", "other"]:
            resp = client.post(
                "/moderation/report",
                params={"uid": f"reporter_{reason}"},
                json={
                    "reported_uid": "bad_uid",
                    "reason": reason,
                    "details": "Details that are long enough to pass validation.",
                },
            )
            assert resp.status_code == 200, f"Failed for reason: {reason}"


# ── GET /moderation/reports ───────────────────────────────────────────────────

class TestListMyReports:
    def test_returns_list(self, client):
        resp = client.get("/moderation/reports", params={"uid": "some_uid"})
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/moderation/reports")
        assert resp.status_code == 422
