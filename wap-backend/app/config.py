"""Configuration management."""

from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings."""
    
    # Firebase (replaces PostgreSQL)
    firebase_credentials_path: Optional[str] = None  # Path to service account JSON
    firebase_credentials_json: Optional[str] = None  # JSON string from env var
    
    # Qdrant
    qdrant_host: str = "localhost"
    qdrant_port: int = 6333
    qdrant_url: Optional[str] = None  # Full URL for Qdrant Cloud
    qdrant_api_key: Optional[str] = None  # API key for Qdrant Cloud
    qdrant_collection: str = "swap_users"
    
    # Embeddings (using smaller, faster model)
    embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    vector_dim: int = 384  # MiniLM uses 384 dimensions (vs 768 for BERT)
    
    # App
    app_name: str = "$wap"
    debug: bool = False
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()

