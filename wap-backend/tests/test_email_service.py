"""Unit tests for EmailService (Azure Communication Services mocked)."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest


def _make_email_service(enabled: bool = True, conn_string: str = "endpoint=https://test.communication.azure.com/;accesskey=dGVzdA=="):
    """Create an EmailService with ACS mocked."""
    import app.email_service as module
    module._email_service = None

    with patch("app.email_service.settings") as mock_settings:
        mock_settings.azure_comm_connection_string = conn_string if enabled else None
        mock_settings.email_enabled = enabled
        mock_settings.email_from = "noreply@example.com"
        mock_settings.app_url = "https://example.com"

        mock_client = MagicMock()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "test-email-id"}
        mock_client.begin_send.return_value = mock_poller

        if enabled:
            with patch("azure.communication.email.EmailClient") as mock_cls:
                mock_cls.from_connection_string.return_value = mock_client
                from app.email_service import EmailService
                svc = EmailService()
                return svc, mock_client
        else:
            from app.email_service import EmailService
            svc = EmailService()
            return svc, mock_client


# ── Initialization ─────────────────────────────────────────────────────────────

class TestEmailServiceInit:
    def test_enabled_when_connection_string_present(self):
        svc, _ = _make_email_service(enabled=True)
        assert svc.enabled is True

    def test_disabled_when_no_connection_string(self):
        svc, _ = _make_email_service(enabled=False)
        assert svc.enabled is False

    def test_from_email_set(self):
        svc, _ = _make_email_service()
        assert svc.from_email == "noreply@example.com"


# ── _send (internal) ─────────────────────────────────────────────────────────

class TestSend:
    def test_sends_when_enabled(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "abc"}
        mock_client.begin_send.return_value = mock_poller

        result = svc._send("user@example.com", {
            "subject": "Test",
            "html": "<p>Hello</p>",
            "text": "Hello",
        })

        assert result is True
        mock_client.begin_send.assert_called_once()

    def test_returns_false_when_disabled(self):
        svc, mock_client = _make_email_service(enabled=False)
        result = svc._send("user@example.com", {
            "subject": "Test", "html": "<p>Hi</p>", "text": "Hi",
        })
        assert result is False
        mock_client.begin_send.assert_not_called()

    def test_returns_false_on_exception(self):
        svc, mock_client = _make_email_service()
        mock_client.begin_send.side_effect = Exception("ACS API error")

        result = svc._send("user@example.com", {
            "subject": "Test", "html": "<p>Hi</p>", "text": "Hi",
        })
        assert result is False

    def test_sends_to_correct_recipient(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "x"}
        mock_client.begin_send.return_value = mock_poller

        svc._send("specific@example.com", {
            "subject": "Sub", "html": "<p>H</p>", "text": "H",
        })

        message = mock_client.begin_send.call_args[0][0]
        assert message["recipients"]["to"][0]["address"] == "specific@example.com"
        assert message["senderAddress"] == "noreply@example.com"


# ── send_welcome ──────────────────────────────────────────────────────────────

class TestSendWelcome:
    def test_sends_welcome_email(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "w1"}
        mock_client.begin_send.return_value = mock_poller

        result = svc.send_welcome(
            to_email="new@example.com",
            user_name="Alice",
            skills_to_offer="Python",
            services_needed="Guitar",
        )
        assert result is True
        mock_client.begin_send.assert_called_once()

    def test_handles_none_user_name(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "w2"}
        mock_client.begin_send.return_value = mock_poller

        result = svc.send_welcome(to_email="new@example.com")
        assert result is True


# ── send_swap_request_notification ───────────────────────────────────────────

class TestSendSwapRequestNotification:
    def test_sends_notification(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "sr1"}
        mock_client.begin_send.return_value = mock_poller

        result = svc.send_swap_request_notification(
            to_email="recipient@example.com",
            recipient_name="Bob",
            requester_name="Alice",
            requester_offers="Python tuition",
            requester_needs="Guitar lessons",
            message="Let's swap!",
            request_id="req123",
        )
        assert result is True

    def test_handles_none_message(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "sr2"}
        mock_client.begin_send.return_value = mock_poller

        result = svc.send_swap_request_notification(
            to_email="r@example.com",
            recipient_name="Bob",
            requester_name="Alice",
            requester_offers="Python",
            requester_needs="Guitar",
            message=None,
            request_id="req456",
        )
        assert result is True


# ── send_swap_response_notification ──────────────────────────────────────────

class TestSendSwapResponseNotification:
    def test_sends_accepted_notification(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "acc1"}
        mock_client.begin_send.return_value = mock_poller

        result = svc.send_swap_response_notification(
            to_email="requester@example.com",
            requester_name="Alice",
            recipient_name="Bob",
            accepted=True,
            conversation_id="conv123",
        )
        assert result is True

    def test_sends_declined_notification(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "dec1"}
        mock_client.begin_send.return_value = mock_poller

        result = svc.send_swap_response_notification(
            to_email="requester@example.com",
            requester_name="Alice",
            recipient_name="Bob",
            accepted=False,
        )
        assert result is True


# ── send_new_message_notification (with debouncing) ───────────────────────────

class TestSendNewMessageNotification:
    def test_sends_on_first_message(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "msg1"}
        mock_client.begin_send.return_value = mock_poller

        # Mock a disabled (no-op) cache
        mock_cache = MagicMock()
        mock_cache.get.return_value = None  # No debounce key

        with patch("app.email_service.get_cache_service", return_value=mock_cache):
            result = svc.send_new_message_notification(
                to_email="r@example.com",
                recipient_uid="uid_r",
                recipient_name="Bob",
                sender_name="Alice",
                message_preview="Hey there!",
                conversation_id="conv1",
            )

        assert result is True

    def test_debounced_when_recently_sent(self):
        svc, mock_client = _make_email_service()
        mock_cache = MagicMock()
        mock_cache.get.return_value = "1"  # Debounce key exists

        with patch("app.email_service.get_cache_service", return_value=mock_cache):
            result = svc.send_new_message_notification(
                to_email="r@example.com",
                recipient_uid="uid_r",
                recipient_name="Bob",
                sender_name="Alice",
                message_preview="Another message",
                conversation_id="conv1",
            )

        assert result is False
        mock_client.begin_send.assert_not_called()

    def test_sets_debounce_key_after_successful_send(self):
        svc, mock_client = _make_email_service()
        mock_poller = MagicMock()
        mock_poller.result.return_value = {"id": "msg2"}
        mock_client.begin_send.return_value = mock_poller
        mock_cache = MagicMock()
        mock_cache.get.return_value = None

        with patch("app.email_service.get_cache_service", return_value=mock_cache):
            svc.send_new_message_notification(
                to_email="r@example.com",
                recipient_uid="uid_r",
                recipient_name="Bob",
                sender_name="Alice",
                message_preview="Hi",
                conversation_id="conv2",
            )

        # Should have set the debounce key with 15-minute TTL
        mock_cache.set.assert_called_once()
        call_kwargs = mock_cache.set.call_args
        assert call_kwargs[1].get("ttl") == 900


# ── Singleton ─────────────────────────────────────────────────────────────────

class TestGetEmailService:
    def test_returns_same_instance(self):
        import app.email_service as module
        original = module._email_service
        module._email_service = None
        try:
            with patch("app.email_service.settings") as s:
                s.azure_comm_connection_string = None
                s.email_enabled = False
                s.email_from = "x@x.com"
                svc1 = module.get_email_service()
                svc2 = module.get_email_service()
                assert svc1 is svc2
        finally:
            module._email_service = original
