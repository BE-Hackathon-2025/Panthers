"""Email service using Azure Communication Services."""

import logging
from typing import Any, Dict, Optional

from app.config import settings
from app.email_templates import (
    welcome_email,
    match_notification_email,
    swap_request_email,
    swap_accepted_email,
    swap_declined_email,
    new_message_email,
)
from app.cache import get_cache_service

logger = logging.getLogger(__name__)


class EmailService:
    """Service for sending emails via Azure Communication Services."""

    def __init__(self):
        """Initialize the ACS email client."""
        self._client = None
        self.from_email = settings.email_from
        self.enabled = settings.email_enabled and bool(settings.azure_comm_connection_string)

        if self.enabled:
            from azure.communication.email import EmailClient
            self._client = EmailClient.from_connection_string(settings.azure_comm_connection_string)
        else:
            logger.warning("Email service disabled: missing AZURE_COMM_CONNECTION_STRING or EMAIL_ENABLED=false")

    def _send(self, to_email: str, content: Dict[str, str]) -> bool:
        """
        Send an email via Azure Communication Services.

        Args:
            to_email: Recipient email address
            content: Dict with 'subject', 'html', and 'text' keys

        Returns:
            True if sent successfully, False otherwise
        """
        if not self.enabled:
            logger.info(f"Email disabled, would send to {to_email}: {content['subject']}")
            return False

        try:
            message = {
                "senderAddress": self.from_email,
                "recipients": {
                    "to": [{"address": to_email}],
                },
                "content": {
                    "subject": content["subject"],
                    "html": content["html"],
                    "plainText": content["text"],
                },
            }

            poller = self._client.begin_send(message)
            result = poller.result()
            logger.info(f"Email sent to {to_email}: {content['subject']} (id: {result['id']})")
            return True

        except Exception as e:
            logger.error(f"Failed to send email to {to_email}: {e}")
            return False

    def send_welcome(
        self,
        to_email: str,
        user_name: Optional[str] = None,
        skills_to_offer: Optional[str] = None,
        services_needed: Optional[str] = None,
    ) -> bool:
        """
        Send welcome email to new user.

        Args:
            to_email: User's email address
            user_name: User's display name
            skills_to_offer: User's skills to offer
            services_needed: User's services needed

        Returns:
            True if sent successfully
        """
        content = welcome_email(
            user_name=user_name or "",
            skills_to_offer=skills_to_offer or "",
            services_needed=services_needed or "",
        )
        return self._send(to_email, content)

    def send_match_notification(
        self,
        to_email: str,
        user_name: str,
        match: Dict[str, Any],
    ) -> bool:
        """
        Send match notification email.

        Args:
            to_email: Recipient's email address
            user_name: Recipient's display name
            match: Match data with display_name, skills_to_offer, services_needed, reciprocal_score, uid

        Returns:
            True if sent successfully
        """
        content = match_notification_email(
            user_name=user_name,
            match_name=match.get("display_name") or match.get("username") or "Someone",
            match_offers=match.get("skills_to_offer", ""),
            match_needs=match.get("services_needed", ""),
            score=match.get("reciprocal_score", match.get("score", 0)),
            match_uid=match.get("uid", ""),
        )
        return self._send(to_email, content)

    def send_swap_request_notification(
        self,
        to_email: str,
        recipient_name: str,
        requester_name: str,
        requester_offers: str,
        requester_needs: str,
        message: Optional[str],
        request_id: str,
    ) -> bool:
        """
        Send swap request notification email.

        Args:
            to_email: Recipient's email address
            recipient_name: Recipient's display name
            requester_name: Requester's display name
            requester_offers: What the requester is offering
            requester_needs: What the requester needs
            message: Optional intro message
            request_id: The swap request ID

        Returns:
            True if sent successfully
        """
        content = swap_request_email(
            recipient_name=recipient_name,
            requester_name=requester_name,
            requester_offers=requester_offers,
            requester_needs=requester_needs,
            message=message or "",
            request_id=request_id,
        )
        return self._send(to_email, content)

    def send_swap_response_notification(
        self,
        to_email: str,
        requester_name: str,
        recipient_name: str,
        accepted: bool,
        conversation_id: Optional[str] = None,
    ) -> bool:
        """
        Send swap response notification email.

        Args:
            to_email: Requester's email address
            requester_name: Requester's display name
            recipient_name: Recipient's display name (who responded)
            accepted: Whether the swap was accepted
            conversation_id: The conversation ID (if accepted)

        Returns:
            True if sent successfully
        """
        if accepted:
            content = swap_accepted_email(
                requester_name=requester_name,
                recipient_name=recipient_name,
                conversation_id=conversation_id or "",
            )
        else:
            content = swap_declined_email(
                requester_name=requester_name,
                recipient_name=recipient_name,
            )
        return self._send(to_email, content)

    def send_new_message_notification(
        self,
        to_email: str,
        recipient_uid: str,
        recipient_name: str,
        sender_name: str,
        message_preview: str,
        conversation_id: str,
    ) -> bool:
        """
        Send new message notification email with debouncing.

        Uses Redis to debounce notifications - max 1 email per conversation
        per 15 minutes to avoid spamming users with rapid messages.

        Args:
            to_email: Recipient's email address
            recipient_uid: Recipient's UID (for debounce key)
            recipient_name: Recipient's display name
            sender_name: Sender's display name
            message_preview: Preview of the message content
            conversation_id: The conversation ID

        Returns:
            True if sent successfully, False if debounced or failed
        """
        # Check debounce using Redis
        cache = get_cache_service()
        debounce_key = f"msg_notify:{recipient_uid}:{conversation_id}"

        # Check if we recently sent a notification for this conversation
        if cache.get(debounce_key):
            logger.info(f"Debounced message notification for {to_email} (conversation: {conversation_id})")
            return False

        content = new_message_email(
            recipient_name=recipient_name,
            sender_name=sender_name,
            message_preview=message_preview,
            conversation_id=conversation_id,
        )

        success = self._send(to_email, content)

        if success:
            # Set debounce key with 15 minute TTL
            cache.set(debounce_key, "1", ttl=900)

        return success


# Global instance
_email_service: Optional[EmailService] = None


def get_email_service() -> EmailService:
    """Get or create email service singleton."""
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service
