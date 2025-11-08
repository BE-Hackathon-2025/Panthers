"""Pytest configuration and fixtures."""
import os
import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="session", autouse=True)
def setup_test_env():
    """Set up test environment variables."""
    os.environ["FIREBASE_CREDENTIALS_JSON"] = '{"type":"service_account","project_id":"test"}'
    os.environ["QDRANT_HOST"] = "localhost"
    os.environ["QDRANT_PORT"] = "6333"
    os.environ["DEBUG"] = "true"


@pytest.fixture
def client():
    """Create a test client for the FastAPI app."""
    from app.main import app
    return TestClient(app)

