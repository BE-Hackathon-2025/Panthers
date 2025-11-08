"""Firebase Firestore setup and service."""

import json
import os
from typing import Optional, Dict, Any, List
from datetime import datetime
from firebase_admin import credentials, firestore, initialize_app
from google.cloud.firestore_v1.base_query import FieldFilter

from app.config import settings


class FirebaseService:
    """Service for Firebase Firestore operations."""
    
    def __init__(self):
        """Initialize Firebase Admin SDK."""
        self._initialized = False
        self._db = None
        self._init_firebase()
    
    def _init_firebase(self):
        """Initialize Firebase with credentials."""
        if self._initialized:
            return
        
        # Initialize Firebase Admin SDK
        if settings.firebase_credentials_path and os.path.exists(settings.firebase_credentials_path):
            # Use service account file
            cred = credentials.Certificate(settings.firebase_credentials_path)
            initialize_app(cred)
        elif settings.firebase_credentials_json:
            # Use JSON string from environment
            cred_dict = json.loads(settings.firebase_credentials_json)
            cred = credentials.Certificate(cred_dict)
            initialize_app(cred)
        else:
            # Use default credentials (for Cloud Run, etc.)
            initialize_app()
        
        self._db = firestore.client()
        self._initialized = True
    
    @property
    def db(self):
        """Get Firestore client."""
        if not self._initialized:
            self._init_firebase()
        return self._db
    
    def get_profiles_collection(self):
        """Get profiles collection reference."""
        return self.db.collection('profiles')
    
    def create_profile(self, uid: str, profile_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a new profile.
        
        Args:
            uid: Firebase Auth UID (document ID)
            profile_data: Profile data dictionary
            
        Returns:
            Created profile data
        """
        # Add timestamps
        now = datetime.utcnow()
        profile_data['created_at'] = now
        profile_data['updated_at'] = now
        
        doc_ref = self.get_profiles_collection().document(uid)
        doc_ref.set(profile_data)
        return {"uid": uid, **profile_data}
    
    def get_profile(self, uid: str) -> Optional[Dict[str, Any]]:
        """
        Get a profile by UID.
        
        Args:
            uid: Firebase Auth UID
            
        Returns:
            Profile data or None if not found
        """
        doc_ref = self.get_profiles_collection().document(uid)
        doc = doc_ref.get()
        
        if doc.exists:
            data = doc.to_dict()
            # Convert Firestore timestamps to ISO strings
            if 'created_at' in data and data['created_at']:
                data['created_at'] = data['created_at'].isoformat() if hasattr(data['created_at'], 'isoformat') else str(data['created_at'])
            if 'updated_at' in data and data['updated_at']:
                data['updated_at'] = data['updated_at'].isoformat() if hasattr(data['updated_at'], 'isoformat') else str(data['updated_at'])
            return {"uid": uid, **data}
        return None
    
    def update_profile(self, uid: str, profile_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update an existing profile.
        
        Args:
            uid: Firebase Auth UID
            profile_data: Updated profile data
            
        Returns:
            Updated profile data
        """
        # Update timestamp
        profile_data['updated_at'] = datetime.utcnow()
        
        doc_ref = self.get_profiles_collection().document(uid)
        doc_ref.update(profile_data)
        
        # Get and return updated document
        return self.get_profile(uid)
    
    def upsert_profile(self, uid: str, profile_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create or update a profile.
        
        Args:
            uid: Firebase Auth UID
            profile_data: Profile data
            
        Returns:
            Profile data
        """
        existing = self.get_profile(uid)
        
        if existing:
            # Update existing
            profile_data['updated_at'] = datetime.utcnow()
            # Keep created_at from existing
            if 'created_at' not in profile_data and 'created_at' in existing:
                profile_data['created_at'] = existing['created_at']
        else:
            # Create new
            now = datetime.utcnow()
            profile_data['created_at'] = now
            profile_data['updated_at'] = now
        
        doc_ref = self.get_profiles_collection().document(uid)
        doc_ref.set(profile_data)
        
        return self.get_profile(uid)
    
    def delete_profile(self, uid: str) -> bool:
        """
        Delete a profile.
        
        Args:
            uid: Firebase Auth UID
            
        Returns:
            True if deleted
        """
        doc_ref = self.get_profiles_collection().document(uid)
        doc_ref.delete()
        return True
    
    def list_profiles(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        List all profiles.
        
        Args:
            limit: Maximum number of profiles to return
            
        Returns:
            List of profiles
        """
        docs = self.get_profiles_collection().limit(limit).stream()
        profiles = []
        
        for doc in docs:
            data = doc.to_dict()
            # Convert timestamps
            if 'created_at' in data and data['created_at']:
                data['created_at'] = data['created_at'].isoformat() if hasattr(data['created_at'], 'isoformat') else str(data['created_at'])
            if 'updated_at' in data and data['updated_at']:
                data['updated_at'] = data['updated_at'].isoformat() if hasattr(data['updated_at'], 'isoformat') else str(data['updated_at'])
            profiles.append({"uid": doc.id, **data})
        
        return profiles
    
    def get_profile_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """
        Get a profile by email.
        
        Args:
            email: User email
            
        Returns:
            Profile data or None if not found
        """
        docs = self.get_profiles_collection().where(
            filter=FieldFilter("email", "==", email)
        ).limit(1).stream()
        
        for doc in docs:
            data = doc.to_dict()
            if 'created_at' in data and data['created_at']:
                data['created_at'] = data['created_at'].isoformat() if hasattr(data['created_at'], 'isoformat') else str(data['created_at'])
            if 'updated_at' in data and data['updated_at']:
                data['updated_at'] = data['updated_at'].isoformat() if hasattr(data['updated_at'], 'isoformat') else str(data['updated_at'])
            return {"uid": doc.id, **data}
        
        return None


# Global instance
_firebase_service = None


def get_firebase_service() -> FirebaseService:
    """Get or create Firebase service singleton."""
    global _firebase_service
    if _firebase_service is None:
        _firebase_service = FirebaseService()
    return _firebase_service


def get_firestore_db():
    """Dependency for getting Firestore client (FastAPI dependency)."""
    service = get_firebase_service()
    return service.db

