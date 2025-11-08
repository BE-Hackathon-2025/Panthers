"""Pydantic schemas for user profiles."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, EmailStr


class ProfileBase(BaseModel):
    """Base profile fields - matches Flutter AppUser model."""
    
    # Firebase Auth fields
    uid: str = Field(..., description="Firebase Auth UID")
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
                "uid": "firebase_user_123",
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
    score: float = Field(..., description="Similarity score (0-1)")


class ReciprocalMatchResult(ProfileSearchResult):
    """Schema for reciprocal match results."""
    
    reciprocal_score: float = Field(..., description="Harmonic mean of both match directions")
    offer_match_score: float = Field(..., description="How well they offer what you need")
    need_match_score: float = Field(..., description="How well you offer what they need")

