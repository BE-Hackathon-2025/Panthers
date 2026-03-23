"""Tests for app configuration / settings."""
import os
from unittest.mock import patch


def test_default_entra_audience():
    from app.config import settings
    assert settings.azure_entra_audience == "api://swap-api/access_as_user"


def test_default_cosmos_database_name():
    from app.config import settings
    assert settings.cosmos_database_name == "swap-db"


def test_default_embedding_deployment():
    from app.config import settings
    assert settings.azure_embedding_deployment == "text-embedding-3-large"


def test_vector_dim():
    from app.config import settings
    assert settings.vector_dim == 1536


def test_redis_defaults():
    from app.config import settings
    assert settings.redis_ttl == 3600
    assert settings.redis_port == 6379


def test_app_name():
    from app.config import settings
    assert settings.app_name == "$wap"


def test_email_enabled_default():
    from app.config import settings
    # In tests EMAIL_ENABLED=false so this is False
    assert settings.email_enabled is False


def test_redis_disabled_in_tests():
    from app.config import settings
    assert settings.redis_enabled is False


def test_entra_settings_from_env():
    from app.config import settings
    assert settings.azure_entra_tenant_name == "testciam"
    assert settings.azure_entra_tenant_id == "test-tenant-id"
    assert settings.azure_entra_client_id == "test-client-id"


def test_cosmos_connection_string_from_env():
    from app.config import settings
    assert settings.cosmos_connection_string is not None
    assert "documents.azure.com" in settings.cosmos_connection_string


def test_debug_true_in_tests():
    from app.config import settings
    assert settings.debug is True


def test_azure_search_settings():
    from app.config import settings
    assert settings.azure_search_endpoint == "https://test.search.windows.net"
    assert settings.azure_search_index == "swap-users"


def test_azure_openai_settings():
    from app.config import settings
    assert settings.azure_openai_endpoint == "https://test.openai.azure.com/"
    assert settings.azure_openai_api_version == "2024-02-01"


def test_app_url_default():
    from app.config import settings
    # Default or overridden; just confirm it's a string
    assert isinstance(settings.app_url, str)


def test_app_insights_not_configured_by_default():
    """App Insights connection string absent unless explicitly set."""
    # We did not set APPLICATIONINSIGHTS_CONNECTION_STRING in test env
    from app.config import settings
    assert settings.applicationinsights_connection_string is None
