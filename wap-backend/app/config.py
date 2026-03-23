"""Configuration management."""

from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings."""

    # ── Microsoft Entra External ID (CIAM) ───────────────────────────────────
    azure_entra_tenant_name: str = "swapauth"
    azure_entra_tenant_id: Optional[str] = None
    azure_entra_client_id: Optional[str] = None
    azure_entra_audience: str = "api://swap-api/access_as_user"

    # ── Azure Cosmos DB (new) ─────────────────────────────────────────────────
    cosmos_connection_string: Optional[str] = None
    cosmos_database_name: str = "swap-db"

    # ── Azure OpenAI (for embeddings) ─────────────────────────────────────────
    azure_openai_endpoint: Optional[str] = None
    azure_openai_api_key: Optional[str] = None
    azure_openai_api_version: str = "2024-02-01"
    azure_embedding_deployment: str = "text-embedding-3-large"
    vector_dim: int = 1536

    # ── Azure AI Search (for vector storage and search) ───────────────────────
    azure_search_endpoint: Optional[str] = None
    azure_search_api_key: Optional[str] = None
    azure_search_index: str = "swap-users"
    azure_search_skills_index: str = "swap-skills"

    # ── Redis Cache ───────────────────────────────────────────────────────────
    redis_enabled: bool = True
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_ttl: int = 3600
    redis_url: Optional[str] = None  # Full URL for Azure Cache for Redis

    # ── Application Insights (new) ────────────────────────────────────────────
    applicationinsights_connection_string: Optional[str] = None

    # ── Email (Azure Communication Services) ──────────────────────────────────
    azure_comm_connection_string: Optional[str] = None
    email_from: str = "DoNotReply@<your-domain>.azurecomm.net"
    email_enabled: bool = True
    app_url: str = "http://localhost:3000"

    # ── App ───────────────────────────────────────────────────────────────────
    app_name: str = "$wap"
    debug: bool = False

    class Config:
        env_file = ".env"
        case_sensitive = False
        extra = "ignore"  # Silently drop unknown env vars (e.g., legacy fields in .env)


settings = Settings()

