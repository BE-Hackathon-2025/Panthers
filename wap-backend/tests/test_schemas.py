"""Unit tests for Pydantic schemas (no I/O needed — pure validation)."""
from __future__ import annotations

from datetime import datetime

import pytest
from pydantic import ValidationError

from app.schemas import (
    BlockCreate,
    ConversationStatus,
    MessageCreate,
    MessageType,
    ProfileCreate,
    ProfileUpdate,
    ReportCreate,
    ReportReason,
    SwapRequestAction,
    SwapRequestCreate,
    SwapRequestStatus,
)


# ── ProfileCreate ─────────────────────────────────────────────────────────────

class TestProfileCreate:
    def test_valid_minimal(self):
        p = ProfileCreate(uid="u1", email="a@example.com", display_name="Alice")
        assert p.uid == "u1"
        assert p.email == "a@example.com"

    def test_valid_full(self):
        p = ProfileCreate(
            uid="u1",
            email="a@example.com",
            display_name="Alice",
            photo_url="https://example.com/photo.jpg",
            full_name="Alice Smith",
            username="alice",
            bio="I love coding",
            city="NYC",
            timezone="America/New_York",
            skills_to_offer="Python, FastAPI",
            services_needed="Guitar lessons",
            dm_open=True,
            email_updates=False,
            show_city=True,
        )
        assert p.username == "alice"
        assert p.skills_to_offer == "Python, FastAPI"

    def test_missing_uid_raises(self):
        with pytest.raises(ValidationError):
            ProfileCreate(email="a@example.com")

    def test_missing_email_raises(self):
        with pytest.raises(ValidationError):
            ProfileCreate(uid="u1")

    def test_invalid_email_raises(self):
        with pytest.raises(ValidationError):
            ProfileCreate(uid="u1", email="not-an-email")

    def test_optional_fields_default_to_none(self):
        p = ProfileCreate(uid="u1", email="a@example.com")
        assert p.bio is None
        assert p.city is None
        assert p.photo_url is None

    def test_dm_open_defaults_to_true(self):
        p = ProfileCreate(uid="u1", email="a@example.com")
        assert p.dm_open is True

    def test_show_city_defaults_to_true(self):
        p = ProfileCreate(uid="u1", email="a@example.com")
        assert p.show_city is True


# ── ProfileUpdate ─────────────────────────────────────────────────────────────

class TestProfileUpdate:
    def test_all_fields_optional(self):
        p = ProfileUpdate()
        assert p.model_dump(exclude_unset=True) == {}

    def test_partial_update(self):
        p = ProfileUpdate(bio="new bio", city="SF")
        d = p.model_dump(exclude_unset=True)
        assert d == {"bio": "new bio", "city": "SF"}

    def test_invalid_email_raises(self):
        with pytest.raises(ValidationError):
            ProfileUpdate(email="bad-email")

    def test_valid_email_update(self):
        p = ProfileUpdate(email="new@example.com")
        assert p.email == "new@example.com"


# ── SwapRequestCreate ─────────────────────────────────────────────────────────

class TestSwapRequestCreate:
    def test_valid(self):
        r = SwapRequestCreate(
            recipient_uid="r1",
            requester_offer="Python tuition",
            requester_need="Guitar lessons",
        )
        assert r.recipient_uid == "r1"
        assert r.message is None

    def test_missing_recipient_raises(self):
        with pytest.raises(ValidationError):
            SwapRequestCreate(requester_offer="x", requester_need="y")

    def test_missing_offer_raises(self):
        with pytest.raises(ValidationError):
            SwapRequestCreate(recipient_uid="r1", requester_need="y")

    def test_message_too_long_raises(self):
        with pytest.raises(ValidationError):
            SwapRequestCreate(
                recipient_uid="r1",
                requester_offer="x",
                requester_need="y",
                message="a" * 501,
            )

    def test_message_at_max_length_ok(self):
        r = SwapRequestCreate(
            recipient_uid="r1",
            requester_offer="x",
            requester_need="y",
            message="a" * 500,
        )
        assert len(r.message) == 500

    def test_optional_message(self):
        r = SwapRequestCreate(recipient_uid="r1", requester_offer="x", requester_need="y")
        assert r.message is None


# ── SwapRequestAction ─────────────────────────────────────────────────────────

class TestSwapRequestAction:
    def test_accept_action(self):
        a = SwapRequestAction(action="accept")
        assert a.action == "accept"

    def test_decline_action(self):
        a = SwapRequestAction(action="decline")
        assert a.action == "decline"

    def test_invalid_action_raises(self):
        with pytest.raises(ValidationError):
            SwapRequestAction(action="ignore")

    def test_missing_action_raises(self):
        with pytest.raises(ValidationError):
            SwapRequestAction()


# ── SwapRequestStatus ─────────────────────────────────────────────────────────

class TestSwapRequestStatus:
    def test_all_statuses_exist(self):
        assert SwapRequestStatus.pending == "pending"
        assert SwapRequestStatus.accepted == "accepted"
        assert SwapRequestStatus.declined == "declined"
        assert SwapRequestStatus.cancelled == "cancelled"


# ── MessageCreate ─────────────────────────────────────────────────────────────

class TestMessageCreate:
    def test_valid_content(self):
        m = MessageCreate(content="Hello!")
        assert m.content == "Hello!"

    def test_empty_content_raises(self):
        with pytest.raises(ValidationError):
            MessageCreate(content="")

    def test_content_too_long_raises(self):
        with pytest.raises(ValidationError):
            MessageCreate(content="x" * 5001)

    def test_max_length_ok(self):
        m = MessageCreate(content="x" * 5000)
        assert len(m.content) == 5000

    def test_missing_content_raises(self):
        with pytest.raises(ValidationError):
            MessageCreate()


# ── MessageType ───────────────────────────────────────────────────────────────

class TestMessageType:
    def test_text_type(self):
        assert MessageType.text == "text"

    def test_system_type(self):
        assert MessageType.system == "system"


# ── ConversationStatus ────────────────────────────────────────────────────────

class TestConversationStatus:
    def test_all_statuses(self):
        assert ConversationStatus.active == "active"
        assert ConversationStatus.blocked == "blocked"
        assert ConversationStatus.archived == "archived"


# ── BlockCreate ───────────────────────────────────────────────────────────────

class TestBlockCreate:
    def test_valid(self):
        b = BlockCreate(blocked_uid="target_uid")
        assert b.blocked_uid == "target_uid"
        assert b.reason is None

    def test_with_reason(self):
        b = BlockCreate(blocked_uid="x", reason="Harassment")
        assert b.reason == "Harassment"

    def test_missing_blocked_uid_raises(self):
        with pytest.raises(ValidationError):
            BlockCreate()

    def test_reason_too_long_raises(self):
        with pytest.raises(ValidationError):
            BlockCreate(blocked_uid="x", reason="r" * 501)


# ── ReportCreate ──────────────────────────────────────────────────────────────

class TestReportCreate:
    def test_valid_minimal(self):
        r = ReportCreate(
            reported_uid="bad_user",
            reason=ReportReason.spam,
            details="This user is spamming me with unsolicited messages.",
        )
        assert r.reason == ReportReason.spam

    def test_details_too_short_raises(self):
        with pytest.raises(ValidationError):
            ReportCreate(
                reported_uid="x",
                reason=ReportReason.spam,
                details="short",  # less than 10 chars
            )

    def test_details_too_long_raises(self):
        with pytest.raises(ValidationError):
            ReportCreate(
                reported_uid="x",
                reason=ReportReason.spam,
                details="d" * 2001,
            )

    def test_invalid_reason_raises(self):
        with pytest.raises(ValidationError):
            ReportCreate(
                reported_uid="x",
                reason="bad_reason",
                details="Some details here.",
            )

    def test_all_reasons_valid(self):
        for reason in ReportReason:
            r = ReportCreate(
                reported_uid="x",
                reason=reason,
                details="Enough details here.",
            )
            assert r.reason == reason

    def test_optional_conversation_id(self):
        r = ReportCreate(
            reported_uid="x",
            reason=ReportReason.harassment,
            details="Harassing me repeatedly.",
            conversation_id="conv123",
        )
        assert r.conversation_id == "conv123"


# ── ReportReason ──────────────────────────────────────────────────────────────

class TestReportReason:
    def test_all_reasons_exist(self):
        reasons = {r.value for r in ReportReason}
        assert "spam" in reasons
        assert "harassment" in reasons
        assert "inappropriate_content" in reasons
        assert "scam" in reasons
        assert "other" in reasons
