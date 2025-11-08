"""Embedding generation using SentenceTransformers."""

from typing import List
import numpy as np
from sentence_transformers import SentenceTransformer

from app.config import settings


class EmbeddingService:
    """Service for generating normalized BERT embeddings."""
    
    def __init__(self):
        """Initialize the embedding model."""
        self.model = SentenceTransformer(settings.embedding_model)
        self.dimension = settings.vector_dim
    
    def encode(self, text: str) -> List[float]:
        """
        Generate normalized embedding for text.
        
        Args:
            text: Input text to encode
            
        Returns:
            Normalized 768-dimensional vector
        """
        embedding = self.model.encode(text, normalize_embeddings=True)
        return embedding.tolist()
    
    def encode_batch(self, texts: List[str]) -> List[List[float]]:
        """
        Generate normalized embeddings for multiple texts.
        
        Args:
            texts: List of texts to encode
            
        Returns:
            List of normalized vectors
        """
        embeddings = self.model.encode(texts, normalize_embeddings=True)
        return embeddings.tolist()


# Global instance
_embedding_service = None


def get_embedding_service() -> EmbeddingService:
    """Get or create embedding service singleton."""
    global _embedding_service
    if _embedding_service is None:
        _embedding_service = EmbeddingService()
    return _embedding_service

