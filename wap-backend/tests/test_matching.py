"""Test matching logic."""

import pytest
from app.matching import haversine_distance, filter_by_geo, filter_by_availability


def test_haversine_distance():
    """Test distance calculation between coordinates."""
    # NYC to Philadelphia (approximately 130 km)
    nyc_lat, nyc_lon = 40.7128, -74.0060
    philly_lat, philly_lon = 39.9526, -75.1652
    
    distance = haversine_distance(nyc_lat, nyc_lon, philly_lat, philly_lon)
    
    # Should be around 130 km
    assert 120 < distance < 140


def test_haversine_same_location():
    """Test distance between same location is zero."""
    lat, lon = 40.7128, -74.0060
    
    distance = haversine_distance(lat, lon, lat, lon)
    
    assert distance == 0.0


def test_filter_by_geo():
    """Test geographic filtering."""
    results = [
        {"username": "alice", "lat": 40.7128, "lon": -74.0060},
        {"username": "bob", "lat": 39.9526, "lon": -75.1652},  # ~130km away
        {"username": "charlie", "lat": 34.0522, "lon": -118.2437},  # LA, very far
    ]
    
    user_lat, user_lon = 40.7128, -74.0060
    max_distance = 150  # 150 km
    
    filtered = filter_by_geo(results, user_lat, user_lon, max_distance)
    
    # Should only include alice and bob
    assert len(filtered) == 2
    usernames = [r["username"] for r in filtered]
    assert "alice" in usernames
    assert "bob" in usernames
    assert "charlie" not in usernames


def test_filter_by_geo_no_coordinates():
    """Test that profiles without coordinates are filtered out."""
    results = [
        {"username": "alice", "lat": 40.7128, "lon": -74.0060},
        {"username": "bob", "lat": None, "lon": None},
    ]
    
    filtered = filter_by_geo(results, 40.7128, -74.0060, 100)
    
    assert len(filtered) == 1
    assert filtered[0]["username"] == "alice"


def test_filter_by_availability():
    """Test availability filtering."""
    results = [
        {"username": "alice", "availability": ["monday", "tuesday", "wednesday"]},
        {"username": "bob", "availability": ["thursday", "friday"]},
        {"username": "charlie", "availability": ["monday", "friday"]},
    ]
    
    required = ["monday", "saturday"]
    
    filtered = filter_by_availability(results, required)
    
    # Should include alice and charlie (both have monday)
    assert len(filtered) == 2
    usernames = [r["username"] for r in filtered]
    assert "alice" in usernames
    assert "charlie" in usernames
    assert "bob" not in usernames


def test_filter_by_availability_no_requirement():
    """Test that no filtering occurs when no availability is required."""
    results = [
        {"username": "alice", "availability": ["monday"]},
        {"username": "bob", "availability": ["tuesday"]},
    ]
    
    filtered = filter_by_availability(results, None)
    
    assert len(filtered) == 2

