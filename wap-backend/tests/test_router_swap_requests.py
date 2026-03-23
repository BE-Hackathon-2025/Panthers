"""Tests for /swap-requests router (Cosmos mocked via conftest InMemoryStore)."""
from __future__ import annotations

from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest


def _create_profile(client, uid: str, email: str = None):
    client.post("/profiles/upsert", json={
        "uid": uid,
        "email": email or f"{uid}@example.com",
        "display_name": uid.capitalize(),
    })


# ── POST /swap-requests ────────────────────────────────────────────────────────

class TestCreateSwapRequest:
    def test_cannot_request_yourself(self, client):
        _create_profile(client, "self_uid")
        resp = client.post(
            "/swap-requests",
            params={"requester_uid": "self_uid"},
            json={
                "recipient_uid": "self_uid",
                "requester_offer": "Python",
                "requester_need": "Guitar",
            },
        )
        assert resp.status_code == 400
        assert "yourself" in resp.json()["detail"].lower()

    def test_recipient_not_found_returns_404(self, client):
        _create_profile(client, "req_uid1")
        resp = client.post(
            "/swap-requests",
            params={"requester_uid": "req_uid1"},
            json={
                "recipient_uid": "nonexistent_recipient",
                "requester_offer": "Python",
                "requester_need": "Guitar",
            },
        )
        assert resp.status_code == 404

    def test_missing_requester_uid_param_returns_422(self, client):
        resp = client.post(
            "/swap-requests",
            json={
                "recipient_uid": "r1",
                "requester_offer": "Python",
                "requester_need": "Guitar",
            },
        )
        assert resp.status_code == 422

    def test_missing_offer_returns_422(self, client):
        resp = client.post(
            "/swap-requests",
            params={"requester_uid": "u1"},
            json={"recipient_uid": "u2", "requester_need": "Guitar"},
        )
        assert resp.status_code == 422

    def test_missing_need_returns_422(self, client):
        resp = client.post(
            "/swap-requests",
            params={"requester_uid": "u1"},
            json={"recipient_uid": "u2", "requester_offer": "Python"},
        )
        assert resp.status_code == 422


# ── GET /swap-requests/incoming ───────────────────────────────────────────────

class TestGetIncomingRequests:
    def test_returns_list(self, client):
        resp = client.get("/swap-requests/incoming", params={"uid": "some_uid"})
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/swap-requests/incoming")
        assert resp.status_code == 422

    def test_accepts_status_filter(self, client):
        resp = client.get(
            "/swap-requests/incoming",
            params={"uid": "some_uid", "status": "pending"},
        )
        assert resp.status_code == 200

    def test_invalid_status_returns_422(self, client):
        resp = client.get(
            "/swap-requests/incoming",
            params={"uid": "some_uid", "status": "not_a_status"},
        )
        assert resp.status_code == 422


# ── GET /swap-requests/outgoing ───────────────────────────────────────────────

class TestGetOutgoingRequests:
    def test_returns_list(self, client):
        resp = client.get("/swap-requests/outgoing", params={"uid": "some_uid"})
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/swap-requests/outgoing")
        assert resp.status_code == 422

    def test_accepts_accepted_status_filter(self, client):
        resp = client.get(
            "/swap-requests/outgoing",
            params={"uid": "some_uid", "status": "accepted"},
        )
        assert resp.status_code == 200


# ── POST /swap-requests/{id}/respond ─────────────────────────────────────────

class TestRespondToRequest:
    def test_not_found_returns_404(self, client):
        resp = client.post(
            "/swap-requests/nonexistent_id/respond",
            params={"uid": "some_uid"},
            json={"action": "accept"},
        )
        assert resp.status_code == 404

    def test_invalid_action_returns_422(self, client):
        resp = client.post(
            "/swap-requests/some_id/respond",
            params={"uid": "uid"},
            json={"action": "maybe"},
        )
        assert resp.status_code == 422

    def test_missing_uid_returns_422(self, client):
        resp = client.post(
            "/swap-requests/some_id/respond",
            json={"action": "accept"},
        )
        assert resp.status_code == 422


# ── DELETE /swap-requests/{id} ────────────────────────────────────────────────

class TestCancelRequest:
    def test_not_found_returns_404(self, client):
        resp = client.delete(
            "/swap-requests/nonexistent_id",
            params={"uid": "some_uid"},
        )
        assert resp.status_code == 404

    def test_missing_uid_returns_422(self, client):
        resp = client.delete("/swap-requests/some_id")
        assert resp.status_code == 422


# ── GET /swap-requests/{id} ───────────────────────────────────────────────────

class TestGetSwapRequest:
    def test_not_found_returns_404(self, client):
        resp = client.get(
            "/swap-requests/nonexistent_id",
            params={"uid": "some_uid"},
        )
        assert resp.status_code == 404

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/swap-requests/some_id")
        assert resp.status_code == 422
