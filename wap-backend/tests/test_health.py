"""Test health check endpoint."""
import pytest


def test_health_check(client):
    """Test the health check endpoint returns 200 and correct status."""
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_health_check_method_not_allowed(client):
    """Test that POST to health check is not allowed."""
    response = client.post("/healthz")
    assert response.status_code == 405

