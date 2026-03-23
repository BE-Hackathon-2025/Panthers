"""Embedding generation using Azure OpenAI."""

from typing import List
from openai import AzureOpenAI

from app.config import settings


class EmbeddingService:
    """Service for generating embeddings using Azure OpenAI."""

    def __init__(self):
        """Initialize the Azure OpenAI client."""
        self.client = AzureOpenAI(
            api_key=settings.azure_openai_api_key,
            api_version=settings.azure_openai_api_version,
            azure_endpoint=settings.azure_openai_endpoint,
        )
        self.deployment = settings.azure_embedding_deployment
        self.dimension = settings.vector_dim

    def encode(self, text: str) -> List[float]:
        """
        Generate embedding for text using Azure OpenAI.

        Args:
            text: Input text to encode

        Returns:
            1536-dimensional vector
        """
        response = self.client.embeddings.create(
            input=text,
            model=self.deployment,
            dimensions=self.dimension,
        )
        return response.data[0].embedding

    def encode_batch(self, texts: List[str]) -> List[List[float]]:
        """
        Generate embeddings for multiple texts.

        Args:
            texts: List of texts to encode

        Returns:
            List of vectors
        """
        response = self.client.embeddings.create(
            input=texts,
            model=self.deployment,
            dimensions=self.dimension,
        )
        return [item.embedding for item in response.data]


# Global instance
_embedding_service = None


def get_embedding_service() -> EmbeddingService:
    """Get or create embedding service singleton."""
    global _embedding_service
    if _embedding_service is None:
        _embedding_service = EmbeddingService()
    return _embedding_service
