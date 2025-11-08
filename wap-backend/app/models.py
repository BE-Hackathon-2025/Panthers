"""SQLAlchemy models."""

from sqlalchemy import Column, String, Float, Integer, ARRAY
from sqlalchemy.dialects.postgresql import JSONB

from app.db import Base


class Profile(Base):
    """User profile model."""
    
    __tablename__ = "profiles"
    
    username = Column(String, primary_key=True, index=True)
    bio = Column(String, nullable=True)
    can_offer = Column(String, nullable=False)
    wants_learn = Column(String, nullable=False)
    availability = Column(ARRAY(String), default=list)
    lat = Column(Float, nullable=True)
    lon = Column(Float, nullable=True)
    rating = Column(Float, default=0.0)
    completed_swaps = Column(Integer, default=0)
    
    def to_dict(self):
        """Convert to dictionary."""
        return {
            "username": self.username,
            "bio": self.bio,
            "can_offer": self.can_offer,
            "wants_learn": self.wants_learn,
            "availability": self.availability or [],
            "lat": self.lat,
            "lon": self.lon,
            "rating": self.rating,
            "completed_swaps": self.completed_swaps,
        }

