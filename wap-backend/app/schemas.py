"""Pydantic schemas for user profiles and messaging."""

from datetime import datetime
from enum import Enum
from typing import Optional, List, Literal
from pydantic import BaseModel, Field, EmailStr


class ProfileBase(BaseModel):
    """Base profile fields - matches Flutter AppUser model."""
    
    # Auth fields
    uid: str = Field(..., description="User UID (Azure AD B2C object ID)")
    email: EmailStr = Field(..., description="User email")
    display_name: Optional[str] = Field(None, description="Display name")
    photo_url: Optional[str] = Field(None, description="Profile photo URL")
    
    # User profile fields
    full_name: Optional[str] = Field(None, description="Full name")
    username: Optional[str] = Field(None, description="Username")
    bio: Optional[str] = Field(None, description="User bio")
    city: Optional[str] = Field(None, description="City")
    timezone: Optional[str] = Field(None, description="Timezone")
    
    # Skill-swap fields
    skills_to_offer: Optional[str] = Field(None, description="Skills user can teach")
    services_needed: Optional[str] = Field(None, description="Services/skills user wants to learn")
    
    # Settings/preferences
    dm_open: Optional[bool] = Field(True, description="Direct messages open")
    email_updates: Optional[bool] = Field(True, description="Email updates enabled")
    show_city: Optional[bool] = Field(True, description="Show city publicly")


class ProfileCreate(ProfileBase):
    """Schema for creating a new profile."""
    
    created_at: Optional[datetime] = Field(default_factory=datetime.utcnow)


class ProfileUpdate(BaseModel):
    """Schema for updating an existing profile (all fields optional)."""
    
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None
    photo_url: Optional[str] = None
    full_name: Optional[str] = None
    username: Optional[str] = None
    bio: Optional[str] = None
    city: Optional[str] = None
    timezone: Optional[str] = None
    skills_to_offer: Optional[str] = None
    services_needed: Optional[str] = None
    dm_open: Optional[bool] = None
    email_updates: Optional[bool] = None
    show_city: Optional[bool] = None


class ProfileResponse(ProfileBase):
    """Schema for profile responses."""
    
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "uid": "b2c_user_abc123",
                "email": "alice@example.com",
                "display_name": "Alice Smith",
                "photo_url": "https://example.com/photo.jpg",
                "full_name": "Alice Marie Smith",
                "username": "alice_codes",
                "bio": "Software engineer passionate about music",
                "city": "New York",
                "timezone": "America/New_York",
                "skills_to_offer": "Python programming, web development, FastAPI",
                "services_needed": "Guitar lessons, music theory",
                "dm_open": True,
                "email_updates": True,
                "show_city": True,
                "created_at": "2025-01-15T10:30:00Z",
                "updated_at": "2025-01-20T15:45:00Z"
            }
        }


class ProfileSearchResult(BaseModel):
    """Schema for search results."""
    
    uid: str
    email: str
    display_name: Optional[str]
    photo_url: Optional[str]
    full_name: Optional[str]
    username: Optional[str]
    bio: Optional[str]
    city: Optional[str]
    timezone: Optional[str]
    skills_to_offer: Optional[str]
    services_needed: Optional[str]
    dm_open: Optional[bool]
    show_city: Optional[bool]
    swap_credits: int = Field(0, description="Total swap credits earned (trust indicator)")
    swaps_completed: int = Field(0, description="Number of completed swaps")
    score: float = Field(..., description="Similarity score (0-1)")


class ReciprocalMatchResult(ProfileSearchResult):
    """Schema for reciprocal match results."""

    reciprocal_score: float = Field(..., description="Harmonic mean of both match directions")
    offer_match_score: float = Field(..., description="How well they offer what you need")
    need_match_score: float = Field(..., description="How well you offer what they need")


# =============================================================================
# Skill Schemas
# =============================================================================

class SkillCreate(BaseModel):
    """Schema for creating a skill."""
    title: str = Field(..., min_length=1, max_length=200, description="Skill title")
    description: str = Field(..., min_length=1, max_length=2000, description="Skill description")
    category: str = Field(..., description="Skill category")
    difficulty: str = Field(..., description="Skill difficulty level")
    estimated_hours: float = Field(1, gt=0, le=100, description="Estimated hours")
    delivery: str = Field("Remote Only", description="Delivery method")
    tags: List[str] = Field(default_factory=list, description="Tags")
    deliverables: List[str] = Field(default_factory=list, description="Deliverables")


class SkillResponse(BaseModel):
    """Schema for skill responses."""
    id: str
    posted_by: str
    title: str
    description: str
    category: str
    difficulty: str
    estimated_hours: float = 1
    delivery: str = "Remote Only"
    tags: List[str] = Field(default_factory=list)
    deliverables: List[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class SkillSearchResult(BaseModel):
    """Schema for skill search results."""
    id: str
    skill_id: str
    posted_by: str
    title: str
    description: str = ""
    category: str = ""
    difficulty: str = ""
    estimated_hours: float = 1
    delivery: str = "Remote Only"
    tags: List[str] = Field(default_factory=list)
    deliverables: List[str] = Field(default_factory=list)
    poster_name: str = ""
    poster_city: str = ""
    poster_swap_credits: int = 0
    score: float = 0.0


# =============================================================================
# Swap Request Schemas
# =============================================================================

class SwapRequestStatus(str, Enum):
    """Status of a swap request."""
    pending = "pending"
    accepted = "accepted"
    declined = "declined"
    cancelled = "cancelled"
    completed = "completed"


class SwapRequestCreate(BaseModel):
    """Schema for creating a swap request."""

    recipient_uid: str = Field(..., description="UID of person to swap with")
    requester_offer: str = Field(..., description="What you're offering in the swap")
    requester_need: str = Field(..., description="What you need from them")
    message: Optional[str] = Field(None, max_length=500, description="Optional intro message")
    requester_offer_skill_id: Optional[str] = Field(None, description="ID of the skill being offered")
    requester_need_skill_id: Optional[str] = Field(None, description="ID of the skill being requested")


class SwapRequestAction(BaseModel):
    """Schema for responding to a swap request."""

    action: Literal["accept", "decline"] = Field(..., description="Accept or decline the request")


class SwapParticipant(BaseModel):
    """Minimal profile info for swap request participants."""

    uid: str
    display_name: Optional[str] = None
    photo_url: Optional[str] = None
    email: Optional[str] = None
    skills_to_offer: Optional[str] = None
    services_needed: Optional[str] = None


class SwapRequestResponse(BaseModel):
    """Schema for swap request responses."""

    id: str
    requester_uid: str
    recipient_uid: str
    status: SwapRequestStatus
    requester_offer: str
    requester_need: str
    message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    responded_at: Optional[datetime] = None
    conversation_id: Optional[str] = None
    requester_profile: Optional[SwapParticipant] = None
    recipient_profile: Optional[SwapParticipant] = None
    requester_confirmed: bool = False
    recipient_confirmed: bool = False
    requester_offer_skill_id: Optional[str] = None
    requester_need_skill_id: Optional[str] = None


# =============================================================================
# Messaging Schemas
# =============================================================================

class MessageType(str, Enum):
    """Type of message."""
    text = "text"
    system = "system"


class ConversationStatus(str, Enum):
    """Status of a conversation."""
    active = "active"
    blocked = "blocked"
    archived = "archived"


class MessageCreate(BaseModel):
    """Schema for sending a message."""

    content: str = Field(..., min_length=1, max_length=5000, description="Message content")


class MessageResponse(BaseModel):
    """Schema for message responses."""

    id: str
    conversation_id: str
    sender_uid: str
    content: str
    sent_at: datetime
    read_at: Optional[datetime] = None
    read_by: List[str] = Field(default_factory=list)
    type: MessageType = MessageType.text


class LastMessage(BaseModel):
    """Embedded last message preview for conversation list."""

    content: str
    sender_uid: str
    sent_at: datetime


class OtherParticipant(BaseModel):
    """Other participant info for conversation display."""

    uid: str
    display_name: Optional[str] = None
    photo_url: Optional[str] = None
    skills_to_offer: Optional[str] = None


class ConversationResponse(BaseModel):
    """Schema for conversation responses."""

    id: str
    participant_uids: List[str]
    swap_request_id: str
    created_at: datetime
    updated_at: datetime
    last_message: Optional[LastMessage] = None
    unread_count: int = 0
    status: ConversationStatus = ConversationStatus.active
    other_participant: Optional[OtherParticipant] = None


class ConversationListResponse(BaseModel):
    """Paginated conversation list response."""

    conversations: List[ConversationResponse]
    total: int
    has_more: bool


# =============================================================================
# Moderation Schemas
# =============================================================================

class BlockCreate(BaseModel):
    """Schema for blocking a user."""

    blocked_uid: str = Field(..., description="UID of user to block")
    reason: Optional[str] = Field(None, max_length=500, description="Optional reason for blocking")


class BlockResponse(BaseModel):
    """Schema for block responses."""

    id: str
    blocker_uid: str
    blocked_uid: str
    created_at: datetime
    reason: Optional[str] = None


class ReportReason(str, Enum):
    """Reason for reporting a user."""
    spam = "spam"
    harassment = "harassment"
    inappropriate_content = "inappropriate_content"
    scam = "scam"
    other = "other"


class ReportCreate(BaseModel):
    """Schema for reporting a user or message."""

    reported_uid: str = Field(..., description="UID of user being reported")
    conversation_id: Optional[str] = Field(None, description="Related conversation ID")
    message_id: Optional[str] = Field(None, description="Related message ID")
    reason: ReportReason = Field(..., description="Reason for report")
    details: str = Field(..., min_length=10, max_length=2000, description="Details of the report")


class ReportResponse(BaseModel):
    """Schema for report confirmation."""

    id: str
    status: str = "pending"
    message: str = "Report submitted. We'll review it within 24-48 hours."


# =============================================================================
# Points & Credits Schemas
# =============================================================================

class PointsTransactionType(str, Enum):
    """Type of points transaction."""
    earned = "earned"
    spent = "spent"


class PointsTransactionReason(str, Enum):
    """Reason for points transaction."""
    swap_completed = "swap_completed"
    priority_boost = "priority_boost"
    request_without_reciprocity = "request_without_reciprocity"
    bonus = "bonus"


class SkillLevel(str, Enum):
    """Skill difficulty level."""
    beginner = "beginner"
    intermediate = "intermediate"
    advanced = "advanced"


class SwapCompletionRequest(BaseModel):
    """Schema for marking a swap as completed."""
    hours: float = Field(..., gt=0, le=100, description="Hours spent on the swap")
    skill_level: SkillLevel = Field(..., description="Difficulty level of the skill exchanged")
    notes: Optional[str] = Field(None, max_length=500, description="Optional notes about the swap")


class SwapConfirmRequest(BaseModel):
    """Schema for confirming swap completion (mutual confirmation)."""
    hours: float = Field(..., gt=0, le=100, description="Hours spent on the swap")
    skill_level: SkillLevel = Field(..., description="Difficulty level of the skill exchanged")
    notes: Optional[str] = Field(None, max_length=500, description="Optional notes about the swap")


class PointsTransactionResponse(BaseModel):
    """Schema for a points transaction record."""
    id: str
    uid: str
    type: PointsTransactionType
    reason: PointsTransactionReason
    points: int = 0
    credits: int = 0
    description: str = ""
    swap_request_id: Optional[str] = None
    created_at: datetime


class PointsBalanceResponse(BaseModel):
    """Schema for user's current balance."""
    uid: str
    points: int = 0
    credits: int = 0
    total_swaps_completed: int = 0


class PointsSpendRequest(BaseModel):
    """Schema for spending points."""
    reason: PointsTransactionReason
    duration_hours: Optional[int] = Field(None, ge=1, le=168, description="Duration for priority boost")

