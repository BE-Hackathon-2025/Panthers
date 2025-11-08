"""Qdrant vector database client."""

from typing import List, Dict, Any
import uuid
from qdrant_client import QdrantClient as QdrantClientBase
from qdrant_client.models import (
    Distance,
    VectorParams,
    PointStruct,
    NamedVector,
    SearchRequest,
    Filter,
    FieldCondition,
    MatchValue,
    Range,
    Batch,
)

from app.config import settings


class QdrantService:
    """Service for managing Qdrant vector operations."""
    
    def __init__(self):
        """Initialize Qdrant client and ensure collection exists."""
        # Support both local and Qdrant Cloud
        if settings.qdrant_url and settings.qdrant_api_key:
            # Qdrant Cloud with full URL and API key
            self.client = QdrantClientBase(
                url=settings.qdrant_url,
                api_key=settings.qdrant_api_key,
            )
        else:
            # Local Qdrant (for development)
            self.client = QdrantClientBase(
                host=settings.qdrant_host,
                port=settings.qdrant_port,
            )
        self.collection_name = settings.qdrant_collection
        self._ensure_collection()
    
    def _ensure_collection(self):
        """Create collection if it doesn't exist."""
        collections = self.client.get_collections().collections
        collection_names = [c.name for c in collections]
        
        if self.collection_name not in collection_names:
            self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config={
                    "offer_vec": VectorParams(
                        size=settings.vector_dim,
                        distance=Distance.COSINE,
                    ),
                    "need_vec": VectorParams(
                        size=settings.vector_dim,
                        distance=Distance.COSINE,
                    ),
                },
            )
    
    def upsert_profile(
        self,
        username: str,
        offer_vec: List[float],
        need_vec: List[float],
        payload: Dict[str, Any],
    ):
        """
        Upsert a profile vector to Qdrant.
        
        Args:
            username: Unique identifier (used as point ID)
            offer_vec: Embedding of can_offer
            need_vec: Embedding of wants_learn
            payload: Profile metadata
        """
        # Ensure point id is a UUID (Qdrant supports integer or UUID ids)
        point_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, username))

        point = PointStruct(
            id=point_id,
            vector={
                "offer_vec": offer_vec,
                "need_vec": need_vec,
            },
            payload=payload,
        )
        
        self.client.upsert(
            collection_name=self.collection_name,
            points=[point],
        )
    
    def search_offers(
        self,
        query_vec: List[float],
        limit: int = 10,
        score_threshold: float = 0.3,
    ) -> List[Dict[str, Any]]:
        """
        Search profiles by their offer vector.
        
        Args:
            query_vec: Query embedding
            limit: Max results
            score_threshold: Minimum similarity score
            
        Returns:
            List of matching profiles with scores
        """
        results = self.client.search(
            collection_name=self.collection_name,
            query_vector=("offer_vec", query_vec),
            limit=limit,
            score_threshold=score_threshold,
        )
        
        return [
            {
                "username": hit.id,
                "score": hit.score,
                **hit.payload,
            }
            for hit in results
        ]
    
    def search_needs(
        self,
        query_vec: List[float],
        limit: int = 10,
        score_threshold: float = 0.3,
    ) -> List[Dict[str, Any]]:
        """
        Search profiles by their need vector.
        
        Args:
            query_vec: Query embedding
            limit: Max results
            score_threshold: Minimum similarity score
            
        Returns:
            List of matching profiles with scores
        """
        results = self.client.search(
            collection_name=self.collection_name,
            query_vector=("need_vec", query_vec),
            limit=limit,
            score_threshold=score_threshold,
        )
        
        return [
            {
                "username": hit.id,
                "score": hit.score,
                **hit.payload,
            }
            for hit in results
        ]
    
    def delete_profile(self, username: str):
        """Delete a profile from Qdrant."""
        self.client.delete(
            collection_name=self.collection_name,
            points_selector=[username],
        )


# Global instance
_qdrant_service = None


def get_qdrant_service() -> QdrantService:
    """Get or create Qdrant service singleton."""
    global _qdrant_service
    if _qdrant_service is None:
        _qdrant_service = QdrantService()
    return _qdrant_service

