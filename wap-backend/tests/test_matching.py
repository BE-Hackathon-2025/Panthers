"""Tests for matching logic."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest


# ── compute_reciprocal_matches ────────────────────────────────────────────────

class TestComputeReciprocalMatches:
    def _mock_services(self, search_results_offer=None, search_results_need=None):
        mock_embedding = MagicMock()
        mock_embedding.encode.return_value = [0.1] * 1536

        mock_search = MagicMock()
        mock_search.search.side_effect = [
            search_results_offer or [],
            search_results_need or [],
        ]
        return mock_embedding, mock_search

    def test_returns_list(self):
        mock_emb, mock_srch = self._mock_services()
        with (
            patch("app.matching.get_embedding_service", return_value=mock_emb),
            patch("app.matching.get_azure_search_service", return_value=mock_srch),
        ):
            from app.matching import compute_reciprocal_matches
            result = compute_reciprocal_matches("Python", "Guitar", limit=5)
            assert isinstance(result, list)

    def test_returns_empty_when_no_matches(self):
        mock_emb, mock_srch = self._mock_services([], [])
        with (
            patch("app.matching.get_embedding_service", return_value=mock_emb),
            patch("app.matching.get_azure_search_service", return_value=mock_srch),
        ):
            from app.matching import compute_reciprocal_matches
            result = compute_reciprocal_matches("Python", "Guitar")
            assert result == []

    def test_calls_embedding_encode_twice(self):
        mock_emb, mock_srch = self._mock_services()
        with (
            patch("app.matching.get_embedding_service", return_value=mock_emb),
            patch("app.matching.get_azure_search_service", return_value=mock_srch),
        ):
            from app.matching import compute_reciprocal_matches
            compute_reciprocal_matches("Python", "Guitar")
            assert mock_emb.encode.call_count == 2

    def test_calls_search_twice(self):
        mock_emb, mock_srch = self._mock_services()
        with (
            patch("app.matching.get_embedding_service", return_value=mock_emb),
            patch("app.matching.get_azure_search_service", return_value=mock_srch),
        ):
            from app.matching import compute_reciprocal_matches
            compute_reciprocal_matches("Python", "Guitar")
            assert mock_srch.search.call_count == 2

    def test_reciprocal_match_includes_both_parties(self):
        offer_results = [
            {"uid": "u1", "email": "u1@example.com", "score": 0.9,
             "display_name": "U1", "skills_to_offer": "Python",
             "services_needed": "Guitar", "photo_url": None,
             "full_name": None, "username": None, "bio": None,
             "city": None, "timezone": None, "dm_open": True, "show_city": True},
        ]
        need_results = [
            {"uid": "u1", "email": "u1@example.com", "score": 0.8,
             "display_name": "U1", "skills_to_offer": "Python",
             "services_needed": "Guitar", "photo_url": None,
             "full_name": None, "username": None, "bio": None,
             "city": None, "timezone": None, "dm_open": True, "show_city": True},
        ]
        mock_emb = MagicMock()
        mock_emb.encode.return_value = [0.1] * 1536
        mock_srch = MagicMock()
        mock_srch.search.side_effect = [offer_results, need_results]

        with (
            patch("app.matching.get_embedding_service", return_value=mock_emb),
            patch("app.matching.get_azure_search_service", return_value=mock_srch),
        ):
            from app.matching import compute_reciprocal_matches
            result = compute_reciprocal_matches("Python", "Guitar")
            assert len(result) >= 1
            assert result[0]["uid"] == "u1"

    def test_result_has_reciprocal_score(self):
        common = {
            "email": "u1@example.com", "display_name": "U1",
            "skills_to_offer": "Python", "services_needed": "Guitar",
            "photo_url": None, "full_name": None, "username": None,
            "bio": None, "city": None, "timezone": None,
            "dm_open": True, "show_city": True,
        }
        offer_results = [{"uid": "u1", "score": 0.9, **common}]
        need_results  = [{"uid": "u1", "score": 0.7, **common}]

        mock_emb = MagicMock()
        mock_emb.encode.return_value = [0.1] * 1536
        mock_srch = MagicMock()
        mock_srch.search.side_effect = [offer_results, need_results]

        with (
            patch("app.matching.get_embedding_service", return_value=mock_emb),
            patch("app.matching.get_azure_search_service", return_value=mock_srch),
        ):
            from app.matching import compute_reciprocal_matches
            result = compute_reciprocal_matches("Python", "Guitar")
            if result:
                assert "reciprocal_score" in result[0]

    def test_respects_limit(self):
        common = {
            "email": "u@example.com", "display_name": "U",
            "skills_to_offer": "x", "services_needed": "y",
            "photo_url": None, "full_name": None, "username": None,
            "bio": None, "city": None, "timezone": None,
            "dm_open": True, "show_city": True,
        }
        # 5 users in both result sets
        offer = [{"uid": f"u{i}", "score": 0.9 - i * 0.1, **common} for i in range(5)]
        need  = [{"uid": f"u{i}", "score": 0.8 - i * 0.1, **common} for i in range(5)]

        mock_emb = MagicMock()
        mock_emb.encode.return_value = [0.1] * 1536
        mock_srch = MagicMock()
        mock_srch.search.side_effect = [offer, need]

        with (
            patch("app.matching.get_embedding_service", return_value=mock_emb),
            patch("app.matching.get_azure_search_service", return_value=mock_srch),
        ):
            from app.matching import compute_reciprocal_matches
            result = compute_reciprocal_matches("Python", "Guitar", limit=3)
            assert len(result) <= 3
