"""Test API endpoints."""
import pytest


class TestProfileEndpoints:
    """Test profile CRUD operations."""
    
    def test_upsert_profile_minimal(self, client):
        """Test creating a profile with minimal required fields."""
        payload = {
            "uid": "test_user_001",
            "email": "test@example.com",
            "display_name": "Test User",
        }
        response = client.post("/profiles/upsert", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["uid"] == "test_user_001"
        assert data["email"] == "test@example.com"
        assert data["display_name"] == "Test User"
    
    def test_upsert_profile_with_skills(self, client):
        """Test creating a profile with skills."""
        payload = {
            "uid": "test_user_002",
            "email": "dev@example.com",
            "display_name": "Dev Person",
            "skills_to_offer": "Python, JavaScript",
            "services_needed": "Guitar lessons",
        }
        response = client.post("/profiles/upsert", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["skills_to_offer"] == "Python, JavaScript"
        assert data["services_needed"] == "Guitar lessons"
    
    def test_get_profile_by_uid(self, client):
        """Test getting a profile by UID."""
        # First create a profile
        payload = {
            "uid": "test_user_003",
            "email": "get@example.com",
            "display_name": "Get Test",
        }
        client.post("/profiles/upsert", json=payload)
        
        # Then retrieve it
        response = client.get("/profiles/test_user_003")
        assert response.status_code == 200
        data = response.json()
        assert data["uid"] == "test_user_003"
    
    def test_get_profile_not_found(self, client):
        """Test getting a non-existent profile returns 404."""
        response = client.get("/profiles/nonexistent_user")
        assert response.status_code == 404
    
    def test_get_profile_by_email(self, client):
        """Test getting a profile by email."""
        # First create a profile
        payload = {
            "uid": "test_user_004",
            "email": "email@example.com",
            "display_name": "Email Test",
        }
        client.post("/profiles/upsert", json=payload)
        
        # Then retrieve by email
        response = client.get("/profiles/email/email@example.com")
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == "email@example.com"
    
    def test_patch_profile(self, client):
        """Test partially updating a profile."""
        # First create a profile
        payload = {
            "uid": "test_user_005",
            "email": "patch@example.com",
            "display_name": "Patch Test",
            "bio": "Original bio",
        }
        client.post("/profiles/upsert", json=payload)
        
        # Then patch it
        update = {"bio": "Updated bio", "city": "San Francisco"}
        response = client.patch("/profiles/test_user_005", json=update)
        assert response.status_code == 200
        data = response.json()
        assert data["bio"] == "Updated bio"
        assert data["city"] == "San Francisco"
        assert data["display_name"] == "Patch Test"  # Unchanged
    
    def test_delete_profile(self, client):
        """Test deleting a profile."""
        # First create a profile
        payload = {
            "uid": "test_user_006",
            "email": "delete@example.com",
            "display_name": "Delete Test",
        }
        client.post("/profiles/upsert", json=payload)
        
        # Then delete it
        response = client.delete("/profiles/test_user_006")
        assert response.status_code == 204
        
        # Verify it's gone
        response = client.get("/profiles/test_user_006")
        assert response.status_code == 404


class TestSearchEndpoints:
    """Test search and matching endpoints."""
    
    def test_search_offers_mode(self, client):
        """Test semantic search in offers mode."""
        payload = {
            "query": "python programming",
            "limit": 5,
            "mode": "offers"
        }
        response = client.post("/search", json=payload)
        assert response.status_code == 200
        assert isinstance(response.json(), list)
    
    def test_search_needs_mode(self, client):
        """Test semantic search in needs mode."""
        payload = {
            "query": "guitar lessons",
            "limit": 5,
            "mode": "needs"
        }
        response = client.post("/search", json=payload)
        assert response.status_code == 200
        assert isinstance(response.json(), list)
    
    def test_search_both_mode(self, client):
        """Test semantic search in both mode."""
        payload = {
            "query": "teach me coding",
            "limit": 5,
            "mode": "both"
        }
        response = client.post("/search", json=payload)
        assert response.status_code == 200
        assert isinstance(response.json(), list)
    
    def test_search_invalid_mode(self, client):
        """Test search with invalid mode returns 422."""
        payload = {
            "query": "test",
            "mode": "invalid_mode"
        }
        response = client.post("/search", json=payload)
        assert response.status_code == 422
    
    def test_reciprocal_match(self, client):
        """Test reciprocal matching endpoint."""
        payload = {
            "my_offer_text": "Python programming",
            "my_need_text": "Guitar lessons",
            "limit": 10
        }
        response = client.post("/match/reciprocal", json=payload)
        assert response.status_code == 200
        assert isinstance(response.json(), list)
    
    def test_reciprocal_match_missing_fields(self, client):
        """Test reciprocal match with missing required fields."""
        payload = {
            "my_offer_text": "Python programming",
            # Missing my_need_text
        }
        response = client.post("/match/reciprocal", json=payload)
        assert response.status_code == 422


class TestValidation:
    """Test input validation."""
    
    def test_upsert_missing_required_fields(self, client):
        """Test upsert with missing required fields."""
        payload = {
            "uid": "test_user",
            # Missing email
        }
        response = client.post("/profiles/upsert", json=payload)
        assert response.status_code == 422
    
    def test_upsert_invalid_email(self, client):
        """Test upsert with invalid email format."""
        payload = {
            "uid": "test_user",
            "email": "not-an-email",
            "display_name": "Test",
        }
        response = client.post("/profiles/upsert", json=payload)
        assert response.status_code == 422
    
    def test_search_negative_limit(self, client):
        """Test search with negative limit."""
        payload = {
            "query": "test",
            "limit": -1
        }
        response = client.post("/search", json=payload)
        assert response.status_code == 422
