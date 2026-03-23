"""Tests for /conversations router."""
from __future__ import annotations

import pytest


# ── GET /conversations ────────────────────────────────────────────────────────

class TestListConversations:
    def test_returns_conversation_list_response(self, client):
        resp = client.get("/conversations", params={"uid": "some_uid"})
        assert resp.status_code == 200
        data = resp.json()
        assert "conversations" in data
        assert "total" in data
        assert "has_more" in data

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/conversations")
        assert resp.status_code == 422

    def test_returns_empty_list_by_default(self, client):
        resp = client.get("/conversations", params={"uid": "uid_no_convs"})
        assert resp.status_code == 200
        assert resp.json()["conversations"] == []

    def test_pagination_params_accepted(self, client):
        resp = client.get(
            "/conversations",
            params={"uid": "uid_pag", "limit": 5, "offset": 10},
        )
        assert resp.status_code == 200

    def test_limit_below_minimum_returns_422(self, client):
        resp = client.get(
            "/conversations",
            params={"uid": "u", "limit": 0},
        )
        assert resp.status_code == 422

    def test_limit_above_maximum_returns_422(self, client):
        resp = client.get(
            "/conversations",
            params={"uid": "u", "limit": 51},
        )
        assert resp.status_code == 422

    def test_negative_offset_returns_422(self, client):
        resp = client.get(
            "/conversations",
            params={"uid": "u", "offset": -1},
        )
        assert resp.status_code == 422


# ── GET /conversations/unread-count ──────────────────────────────────────────

class TestGetUnreadCount:
    def test_returns_total_unread(self, client):
        resp = client.get("/conversations/unread-count", params={"uid": "uid_unread"})
        assert resp.status_code == 200
        assert "total_unread" in resp.json()

    def test_total_unread_is_integer(self, client):
        resp = client.get("/conversations/unread-count", params={"uid": "uid_int"})
        assert isinstance(resp.json()["total_unread"], int)

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/conversations/unread-count")
        assert resp.status_code == 422


# ── GET /conversations/{id} ───────────────────────────────────────────────────

class TestGetConversation:
    def test_not_found_returns_404(self, client):
        resp = client.get(
            "/conversations/nonexistent_conv_id",
            params={"uid": "some_uid"},
        )
        assert resp.status_code == 404

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/conversations/some_conv_id")
        assert resp.status_code == 422


# ── GET /conversations/{id}/messages ─────────────────────────────────────────

class TestGetMessages:
    def test_not_found_returns_404(self, client):
        resp = client.get(
            "/conversations/nonexistent_conv/messages",
            params={"uid": "some_uid"},
        )
        assert resp.status_code == 404

    def test_missing_uid_returns_422(self, client):
        resp = client.get("/conversations/conv_id/messages")
        assert resp.status_code == 422

    def test_limit_above_maximum_returns_422(self, client):
        resp = client.get(
            "/conversations/conv_id/messages",
            params={"uid": "u", "limit": 101},
        )
        assert resp.status_code == 422

    def test_limit_below_minimum_returns_422(self, client):
        resp = client.get(
            "/conversations/conv_id/messages",
            params={"uid": "u", "limit": 0},
        )
        assert resp.status_code == 422


# ── POST /conversations/{id}/messages ────────────────────────────────────────

class TestSendMessage:
    def test_not_found_returns_404(self, client):
        resp = client.post(
            "/conversations/nonexistent_conv/messages",
            params={"uid": "sender_uid"},
            json={"content": "Hello!"},
        )
        assert resp.status_code == 404

    def test_missing_uid_returns_422(self, client):
        resp = client.post(
            "/conversations/conv_id/messages",
            json={"content": "Hello!"},
        )
        assert resp.status_code == 422

    def test_empty_content_returns_422(self, client):
        resp = client.post(
            "/conversations/conv_id/messages",
            params={"uid": "sender"},
            json={"content": ""},
        )
        assert resp.status_code == 422

    def test_content_too_long_returns_422(self, client):
        resp = client.post(
            "/conversations/conv_id/messages",
            params={"uid": "sender"},
            json={"content": "x" * 5001},
        )
        assert resp.status_code == 422

    def test_missing_content_returns_422(self, client):
        resp = client.post(
            "/conversations/conv_id/messages",
            params={"uid": "sender"},
            json={},
        )
        assert resp.status_code == 422


# ── POST /conversations/{id}/mark-read ───────────────────────────────────────

class TestMarkConversationRead:
    def test_not_found_returns_404(self, client):
        resp = client.post(
            "/conversations/nonexistent_conv/mark-read",
            params={"uid": "some_uid"},
        )
        assert resp.status_code == 404

    def test_missing_uid_returns_422(self, client):
        resp = client.post("/conversations/conv_id/mark-read")
        assert resp.status_code == 422
