"""Unit tests for CacheService (Redis mocked)."""
from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

import pytest


def _make_cache_service(redis_enabled: bool = True):
    """Return a CacheService with a mocked Redis client."""
    import app.cache as cache_module
    # Reset singleton
    cache_module._cache_service = None

    mock_redis = MagicMock()
    mock_redis.ping.return_value = True

    with patch("app.cache.settings") as mock_settings:
        mock_settings.redis_enabled = redis_enabled
        mock_settings.redis_host = "localhost"
        mock_settings.redis_port = 6379
        mock_settings.redis_ttl = 3600
        with patch("app.cache.redis.Redis", return_value=mock_redis):
            from app.cache import CacheService
            svc = CacheService()

    return svc, mock_redis


# ── Disabled cache ─────────────────────────────────────────────────────────────

class TestCacheDisabled:
    def test_enabled_is_false_when_disabled(self):
        svc, _ = _make_cache_service(redis_enabled=False)
        assert svc.enabled is False

    def test_get_returns_none_when_disabled(self):
        svc, _ = _make_cache_service(redis_enabled=False)
        assert svc.get("any_key") is None

    def test_set_returns_false_when_disabled(self):
        svc, _ = _make_cache_service(redis_enabled=False)
        assert svc.set("k", "v") is False

    def test_delete_returns_false_when_disabled(self):
        svc, _ = _make_cache_service(redis_enabled=False)
        assert svc.delete("k") is False

    def test_clear_pattern_returns_zero_when_disabled(self):
        svc, _ = _make_cache_service(redis_enabled=False)
        assert svc.clear_pattern("*") == 0

    def test_get_stats_returns_enabled_false(self):
        svc, _ = _make_cache_service(redis_enabled=False)
        stats = svc.get_stats()
        assert stats["enabled"] is False


# ── Enabled cache — get ────────────────────────────────────────────────────────

class TestCacheGet:
    def test_returns_deserialized_value_on_hit(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.get.return_value = json.dumps({"result": [1, 2, 3]})

        result = svc.get("search:abc123")
        assert result == {"result": [1, 2, 3]}

    def test_returns_none_on_miss(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.get.return_value = None

        assert svc.get("missing_key") is None

    def test_returns_none_on_redis_error(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.get.side_effect = Exception("Redis error")

        assert svc.get("error_key") is None

    def test_calls_redis_get_with_key(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.get.return_value = None

        svc.get("my_key")
        mock_redis.get.assert_called_once_with("my_key")


# ── Enabled cache — set ────────────────────────────────────────────────────────

class TestCacheSet:
    def test_returns_true_on_success(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.setex.return_value = True

        result = svc.set("k", {"data": 42})
        assert result is True

    def test_uses_default_ttl_when_not_specified(self):
        svc, mock_redis = _make_cache_service()
        svc.set("k", "v")

        args = mock_redis.setex.call_args[0]
        assert args[1] == 3600  # default TTL

    def test_uses_custom_ttl_when_specified(self):
        svc, mock_redis = _make_cache_service()
        svc.set("k", "v", ttl=120)

        args = mock_redis.setex.call_args[0]
        assert args[1] == 120

    def test_serializes_value_to_json(self):
        svc, mock_redis = _make_cache_service()
        svc.set("k", {"hello": "world"})

        args = mock_redis.setex.call_args[0]
        assert json.loads(args[2]) == {"hello": "world"}

    def test_returns_false_on_redis_error(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.setex.side_effect = Exception("Redis down")

        assert svc.set("k", "v") is False


# ── Enabled cache — delete ─────────────────────────────────────────────────────

class TestCacheDelete:
    def test_returns_true_on_success(self):
        svc, mock_redis = _make_cache_service()
        result = svc.delete("del_key")
        assert result is True
        mock_redis.delete.assert_called_once_with("del_key")

    def test_returns_false_on_error(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.delete.side_effect = Exception("Redis error")
        assert svc.delete("k") is False


# ── clear_pattern ──────────────────────────────────────────────────────────────

class TestClearPattern:
    def test_deletes_matching_keys(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.keys.return_value = ["search:a", "search:b"]
        mock_redis.delete.return_value = 2

        count = svc.clear_pattern("search:*")
        assert count == 2
        mock_redis.keys.assert_called_once_with("search:*")

    def test_returns_zero_when_no_matches(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.keys.return_value = []

        count = svc.clear_pattern("search:*")
        assert count == 0
        mock_redis.delete.assert_not_called()

    def test_returns_zero_on_error(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.keys.side_effect = Exception("Redis error")

        count = svc.clear_pattern("*")
        assert count == 0


# ── _generate_key ──────────────────────────────────────────────────────────────

class TestGenerateKey:
    def test_same_data_produces_same_key(self):
        svc, _ = _make_cache_service()
        key1 = svc._generate_key("search", {"query": "python", "limit": 10})
        key2 = svc._generate_key("search", {"query": "python", "limit": 10})
        assert key1 == key2

    def test_different_data_produces_different_key(self):
        svc, _ = _make_cache_service()
        key1 = svc._generate_key("search", {"query": "python"})
        key2 = svc._generate_key("search", {"query": "guitar"})
        assert key1 != key2

    def test_key_includes_prefix(self):
        svc, _ = _make_cache_service()
        key = svc._generate_key("myprefix", {"a": 1})
        assert key.startswith("myprefix:")

    def test_order_insensitive(self):
        svc, _ = _make_cache_service()
        key1 = svc._generate_key("p", {"b": 2, "a": 1})
        key2 = svc._generate_key("p", {"a": 1, "b": 2})
        assert key1 == key2


# ── get_stats ──────────────────────────────────────────────────────────────────

class TestGetStats:
    def test_returns_enabled_true_when_connected(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.info.return_value = {
            "total_commands_processed": 100,
            "keyspace_hits": 80,
            "keyspace_misses": 20,
        }

        stats = svc.get_stats()
        assert stats["enabled"] is True
        assert stats["keyspace_hits"] == 80
        assert stats["keyspace_misses"] == 20

    def test_returns_stats_unavailable_on_error(self):
        svc, mock_redis = _make_cache_service()
        mock_redis.info.side_effect = Exception("Redis error")

        stats = svc.get_stats()
        assert stats.get("stats_unavailable") is True


# ── Singleton ──────────────────────────────────────────────────────────────────

class TestGetCacheService:
    def test_returns_same_instance(self):
        import app.cache as cache_module
        original = cache_module._cache_service
        cache_module._cache_service = None
        try:
            with patch("app.cache.settings") as mock_settings:
                mock_settings.redis_enabled = False
                svc1 = cache_module.get_cache_service()
                svc2 = cache_module.get_cache_service()
                assert svc1 is svc2
        finally:
            cache_module._cache_service = original
