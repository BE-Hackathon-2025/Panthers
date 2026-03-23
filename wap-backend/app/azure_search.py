"""Azure AI Search client for vector operations."""

from typing import List, Dict, Any
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
    SearchableField,
    SimpleField,
)
from azure.search.documents.models import VectorizedQuery

from app.config import settings


class AzureSearchService:
    """Service for managing Azure AI Search vector operations."""

    def __init__(self):
        """Initialize Azure AI Search client and ensure index exists."""
        credential = AzureKeyCredential(settings.azure_search_api_key)

        # Index client for schema management
        self.index_client = SearchIndexClient(
            endpoint=settings.azure_search_endpoint,
            credential=credential,
        )

        # Search client for document operations
        self.search_client = SearchClient(
            endpoint=settings.azure_search_endpoint,
            index_name=settings.azure_search_index,
            credential=credential,
        )

        self.index_name = settings.azure_search_index
        self._ensure_index()

    def _ensure_index(self):
        """Create or update the index to ensure all fields exist."""
        self._create_or_update_index()

    def _create_or_update_index(self):
        """Create or update the search index with all fields."""
        fields = [
            SimpleField(name="id", type=SearchFieldDataType.String, key=True),
            SimpleField(name="uid", type=SearchFieldDataType.String, filterable=True),
            SearchableField(name="email", type=SearchFieldDataType.String),
            SearchableField(name="display_name", type=SearchFieldDataType.String),
            SimpleField(name="photo_url", type=SearchFieldDataType.String),
            SearchableField(name="full_name", type=SearchFieldDataType.String),
            SearchableField(name="username", type=SearchFieldDataType.String),
            SearchableField(name="bio", type=SearchFieldDataType.String),
            SearchableField(name="city", type=SearchFieldDataType.String, filterable=True),
            SimpleField(name="timezone", type=SearchFieldDataType.String),
            SearchableField(name="skills_to_offer", type=SearchFieldDataType.String),
            SearchableField(name="services_needed", type=SearchFieldDataType.String),
            SimpleField(name="dm_open", type=SearchFieldDataType.Boolean, filterable=True),
            SimpleField(name="show_city", type=SearchFieldDataType.Boolean, filterable=True),
            SimpleField(name="swap_credits", type=SearchFieldDataType.Int32, filterable=True, sortable=True),
            SimpleField(name="swaps_completed", type=SearchFieldDataType.Int32, filterable=True, sortable=True),
            # Vector fields
            SearchField(
                name="offer_vec",
                type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                searchable=True,
                vector_search_dimensions=settings.vector_dim,
                vector_search_profile_name="vector-profile",
            ),
            SearchField(
                name="need_vec",
                type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                searchable=True,
                vector_search_dimensions=settings.vector_dim,
                vector_search_profile_name="vector-profile",
            ),
        ]

        vector_search = VectorSearch(
            algorithms=[
                HnswAlgorithmConfiguration(name="hnsw-config"),
            ],
            profiles=[
                VectorSearchProfile(
                    name="vector-profile",
                    algorithm_configuration_name="hnsw-config",
                ),
            ],
        )

        index = SearchIndex(
            name=self.index_name,
            fields=fields,
            vector_search=vector_search,
        )

        self.index_client.create_or_update_index(index)

    def upsert_profile(
        self,
        username: str,
        offer_vec: List[float],
        need_vec: List[float],
        payload: Dict[str, Any],
    ):
        """
        Upsert a profile to Azure AI Search.

        Args:
            username: Unique identifier (used as document ID)
            offer_vec: Embedding of skills_to_offer
            need_vec: Embedding of services_needed
            payload: Profile metadata
        """
        document = {
            "id": username,
            "uid": payload.get("uid", username),
            "email": payload.get("email", ""),
            "display_name": payload.get("display_name", ""),
            "photo_url": payload.get("photo_url", ""),
            "full_name": payload.get("full_name", ""),
            "username": payload.get("username", ""),
            "bio": payload.get("bio", ""),
            "city": payload.get("city", ""),
            "timezone": payload.get("timezone", ""),
            "skills_to_offer": payload.get("skills_to_offer", ""),
            "services_needed": payload.get("services_needed", ""),
            "dm_open": payload.get("dm_open", True),
            "show_city": payload.get("show_city", True),
            "swap_credits": payload.get("swap_credits", 0) or 0,
            "swaps_completed": payload.get("swaps_completed", 0) or 0,
            "offer_vec": offer_vec,
            "need_vec": need_vec,
        }

        self.search_client.merge_or_upload_documents([document])

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
        vector_query = VectorizedQuery(
            vector=query_vec,
            k_nearest_neighbors=limit,
            fields="offer_vec",
        )

        results = self.search_client.search(
            search_text=None,
            vector_queries=[vector_query],
            top=limit,
        )

        matches = []
        for result in results:
            score = result.get("@search.score", 0)
            # Azure AI Search returns scores differently, normalize if needed
            # HNSW with cosine returns scores where higher is better
            if score >= score_threshold:
                matches.append({
                    "username": result.get("id"),
                    "score": score,
                    "uid": result.get("uid"),
                    "email": result.get("email"),
                    "display_name": result.get("display_name"),
                    "photo_url": result.get("photo_url"),
                    "full_name": result.get("full_name"),
                    "bio": result.get("bio"),
                    "city": result.get("city"),
                    "timezone": result.get("timezone"),
                    "skills_to_offer": result.get("skills_to_offer"),
                    "services_needed": result.get("services_needed"),
                    "dm_open": result.get("dm_open"),
                    "show_city": result.get("show_city"),
                    "swap_credits": result.get("swap_credits", 0),
                    "swaps_completed": result.get("swaps_completed", 0),
                })

        return matches

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
        vector_query = VectorizedQuery(
            vector=query_vec,
            k_nearest_neighbors=limit,
            fields="need_vec",
        )

        results = self.search_client.search(
            search_text=None,
            vector_queries=[vector_query],
            top=limit,
        )

        matches = []
        for result in results:
            score = result.get("@search.score", 0)
            if score >= score_threshold:
                matches.append({
                    "username": result.get("id"),
                    "score": score,
                    "uid": result.get("uid"),
                    "email": result.get("email"),
                    "display_name": result.get("display_name"),
                    "photo_url": result.get("photo_url"),
                    "full_name": result.get("full_name"),
                    "bio": result.get("bio"),
                    "city": result.get("city"),
                    "timezone": result.get("timezone"),
                    "skills_to_offer": result.get("skills_to_offer"),
                    "services_needed": result.get("services_needed"),
                    "dm_open": result.get("dm_open"),
                    "show_city": result.get("show_city"),
                    "swap_credits": result.get("swap_credits", 0),
                    "swaps_completed": result.get("swaps_completed", 0),
                })

        return matches

    def delete_profile(self, username: str):
        """Delete a profile from Azure AI Search."""
        self.search_client.delete_documents([{"id": username}])


class SkillsSearchService:
    """Service for managing skill search in Azure AI Search."""

    def __init__(self):
        credential = AzureKeyCredential(settings.azure_search_api_key)
        self.index_client = SearchIndexClient(
            endpoint=settings.azure_search_endpoint,
            credential=credential,
        )
        self.search_client = SearchClient(
            endpoint=settings.azure_search_endpoint,
            index_name=settings.azure_search_skills_index,
            credential=credential,
        )
        self.index_name = settings.azure_search_skills_index
        self._ensure_index()

    def _ensure_index(self):
        fields = [
            SimpleField(name="id", type=SearchFieldDataType.String, key=True),
            SimpleField(name="skill_id", type=SearchFieldDataType.String, filterable=True),
            SimpleField(name="posted_by", type=SearchFieldDataType.String, filterable=True),
            SearchableField(name="title", type=SearchFieldDataType.String),
            SearchableField(name="description", type=SearchFieldDataType.String),
            SearchableField(name="category", type=SearchFieldDataType.String, filterable=True),
            SimpleField(name="difficulty", type=SearchFieldDataType.String, filterable=True),
            SimpleField(name="estimated_hours", type=SearchFieldDataType.Double),
            SimpleField(name="delivery", type=SearchFieldDataType.String, filterable=True),
            SearchableField(
                name="tags",
                type=SearchFieldDataType.Collection(SearchFieldDataType.String),
                filterable=True,
            ),
            SimpleField(name="poster_name", type=SearchFieldDataType.String),
            SimpleField(name="poster_city", type=SearchFieldDataType.String, filterable=True),
            SimpleField(name="poster_swap_credits", type=SearchFieldDataType.Int32, sortable=True),
            SearchField(
                name="skill_vec",
                type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                searchable=True,
                vector_search_dimensions=settings.vector_dim,
                vector_search_profile_name="vector-profile",
            ),
        ]

        vector_search = VectorSearch(
            algorithms=[HnswAlgorithmConfiguration(name="hnsw-config")],
            profiles=[
                VectorSearchProfile(
                    name="vector-profile",
                    algorithm_configuration_name="hnsw-config",
                ),
            ],
        )

        index = SearchIndex(
            name=self.index_name,
            fields=fields,
            vector_search=vector_search,
        )
        self.index_client.create_or_update_index(index)

    def upsert_skill(self, skill_id: str, skill_vec: List[float], payload: Dict[str, Any]):
        """Upsert a skill document to the search index."""
        tags = payload.get("tags", [])
        if not isinstance(tags, list):
            tags = []
        document = {
            "id": skill_id,
            "skill_id": skill_id,
            "posted_by": payload.get("posted_by", ""),
            "title": payload.get("title", ""),
            "description": payload.get("description", ""),
            "category": payload.get("category", ""),
            "difficulty": payload.get("difficulty", ""),
            "estimated_hours": payload.get("estimated_hours", 1),
            "delivery": payload.get("delivery", "Remote Only"),
            "tags": tags,
            "poster_name": payload.get("poster_name", ""),
            "poster_city": payload.get("poster_city", ""),
            "poster_swap_credits": payload.get("poster_swap_credits", 0) or 0,
            "skill_vec": skill_vec,
        }
        self.search_client.merge_or_upload_documents([document])

    def search_skills(
        self,
        query_vec: List[float],
        limit: int = 10,
        category_filter: str | None = None,
        score_threshold: float = 0.3,
    ) -> List[Dict[str, Any]]:
        """Search skills by vector similarity with optional category filter."""
        vector_query = VectorizedQuery(
            vector=query_vec,
            k_nearest_neighbors=limit,
            fields="skill_vec",
        )

        filter_expr = None
        if category_filter:
            filter_expr = f"category eq '{category_filter}'"

        results = self.search_client.search(
            search_text=None,
            vector_queries=[vector_query],
            filter=filter_expr,
            top=limit,
        )

        matches = []
        for result in results:
            score = result.get("@search.score", 0)
            if score >= score_threshold:
                tags = result.get("tags", [])
                if not isinstance(tags, list):
                    tags = []
                matches.append({
                    "id": result.get("id"),
                    "skill_id": result.get("skill_id"),
                    "posted_by": result.get("posted_by"),
                    "title": result.get("title"),
                    "description": result.get("description"),
                    "category": result.get("category"),
                    "difficulty": result.get("difficulty"),
                    "estimated_hours": result.get("estimated_hours", 1),
                    "delivery": result.get("delivery", "Remote Only"),
                    "tags": tags,
                    "deliverables": [],
                    "poster_name": result.get("poster_name", ""),
                    "poster_city": result.get("poster_city", ""),
                    "poster_swap_credits": result.get("poster_swap_credits", 0),
                    "score": score,
                })

        return matches

    def delete_skill(self, skill_id: str):
        """Delete a skill from the search index."""
        self.search_client.delete_documents([{"id": skill_id}])


# Global instances
_azure_search_service = None
_skills_search_service = None


def get_azure_search_service() -> AzureSearchService:
    """Get or create Azure Search service singleton."""
    global _azure_search_service
    if _azure_search_service is None:
        _azure_search_service = AzureSearchService()
    return _azure_search_service


def get_skills_search_service() -> SkillsSearchService:
    """Get or create Skills Search service singleton."""
    global _skills_search_service
    if _skills_search_service is None:
        _skills_search_service = SkillsSearchService()
    return _skills_search_service
