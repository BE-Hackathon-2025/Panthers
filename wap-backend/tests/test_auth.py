"""Unit tests for Entra External ID JWT validation (app/auth.py).

All HTTP calls to the CIAM JWKS endpoint are mocked so these run offline.
"""
from __future__ import annotations

import json
import time
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_fake_jwks():
    """Return a minimal fake JWKS dict keyed by kid."""
    return {
        "kid1": {
            "kty": "RSA",
            "kid": "kid1",
            "use": "sig",
            "n": "somerandomvalue",
            "e": "AQAB",
        }
    }


def _patch_jwks(fake_keys: dict | None = None):
    """Context manager: patches _get_jwks to return fake keys."""
    keys = fake_keys or _make_fake_jwks()
    return patch("app.auth._get_jwks", return_value=keys)


# ── _jwks_url ────────────────────────────────────────────────────────────────

class TestJwksUrl:
    def test_contains_tenant_name(self):
        from app.auth import _jwks_url
        url = _jwks_url()
        assert "testciam" in url

    def test_contains_tenant_id(self):
        from app.auth import _jwks_url
        url = _jwks_url()
        assert "test-tenant-id" in url

    def test_contains_keys_endpoint(self):
        from app.auth import _jwks_url
        url = _jwks_url()
        assert "/keys" in url

    def test_uses_ciamlogin_domain(self):
        from app.auth import _jwks_url
        url = _jwks_url()
        assert "ciamlogin.com" in url


# ── _get_jwks ─────────────────────────────────────────────────────────────────

class TestGetJwks:
    def test_fetches_from_jwks_url(self):
        import app.auth as auth_module
        # Reset cache
        auth_module._jwks_fetched_at = 0.0
        auth_module._jwks_cache = {}

        mock_response = MagicMock()
        mock_response.json.return_value = {
            "keys": [{"kid": "k1", "kty": "RSA"}]
        }
        with patch("app.auth.httpx.get", return_value=mock_response) as mock_get:
            result = auth_module._get_jwks()
            mock_get.assert_called_once()
            assert "k1" in result

    def test_uses_cache_within_ttl(self):
        import app.auth as auth_module
        auth_module._jwks_cache = {"k_cached": {"kid": "k_cached"}}
        auth_module._jwks_fetched_at = time.time()  # fresh

        with patch("app.auth.httpx.get") as mock_get:
            result = auth_module._get_jwks()
            mock_get.assert_not_called()
            assert "k_cached" in result

    def test_refreshes_after_ttl(self):
        import app.auth as auth_module
        auth_module._jwks_fetched_at = 0.0  # expired

        mock_response = MagicMock()
        mock_response.json.return_value = {"keys": [{"kid": "refreshed"}]}
        with patch("app.auth.httpx.get", return_value=mock_response):
            result = auth_module._get_jwks()
            assert "refreshed" in result


# ── _get_public_key ───────────────────────────────────────────────────────────

class TestGetPublicKey:
    def test_raises_401_for_unknown_kid(self):
        with _patch_jwks({}):
            import app.auth as auth_module
            auth_module._jwks_fetched_at = time.time()  # don't refresh
            with pytest.raises(HTTPException) as exc_info:
                auth_module._get_public_key("unknown_kid")
            assert exc_info.value.status_code == 401

    def test_returns_key_for_known_kid(self):
        fake_key = {"kid": "kid1", "kty": "RSA", "n": "abc", "e": "AQAB"}
        with patch("app.auth._get_jwks", return_value={"kid1": fake_key}):
            with patch("app.auth.jwk.construct", return_value=MagicMock()) as mock_construct:
                import app.auth as auth_module
                auth_module._jwks_fetched_at = time.time()
                result = auth_module._get_public_key("kid1")
                mock_construct.assert_called_once_with(fake_key)
                assert result is not None


# ── decode_token ──────────────────────────────────────────────────────────────

class TestDecodeToken:
    def test_raises_401_for_malformed_token(self):
        from app.auth import decode_token
        with pytest.raises(HTTPException) as exc_info:
            decode_token("not.a.jwt")
        assert exc_info.value.status_code == 401

    def test_raises_401_when_token_missing_kid(self):
        from app.auth import decode_token
        with patch("app.auth.jwt.get_unverified_header", return_value={"alg": "RS256"}):
            with pytest.raises(HTTPException) as exc_info:
                decode_token("header.payload.sig")
            assert exc_info.value.status_code == 401
            assert "kid" in exc_info.value.detail

    def test_raises_401_for_invalid_signature(self):
        from app.auth import decode_token
        from jose import JWTError
        with patch("app.auth.jwt.get_unverified_header", return_value={"kid": "kid1", "alg": "RS256"}):
            with patch("app.auth._get_public_key", return_value=MagicMock()):
                with patch("app.auth.jwt.decode", side_effect=JWTError("bad sig")):
                    with pytest.raises(HTTPException) as exc_info:
                        decode_token("some.token.here")
                    assert exc_info.value.status_code == 401

    def test_returns_payload_for_valid_token(self):
        from app.auth import decode_token
        expected_payload = {"sub": "user123", "email": "user@example.com", "oid": "user123"}
        with patch("app.auth.jwt.get_unverified_header", return_value={"kid": "kid1", "alg": "RS256"}):
            with patch("app.auth._get_public_key", return_value=MagicMock()):
                with patch("app.auth.jwt.decode", return_value=expected_payload):
                    result = decode_token("valid.token.here")
                    assert result["sub"] == "user123"
                    assert result["email"] == "user@example.com"


# ── get_current_user dependency ───────────────────────────────────────────────

class TestGetCurrentUser:
    @pytest.mark.asyncio
    async def test_raises_401_when_no_header(self):
        from app.auth import get_current_user
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(authorization=None)
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_raises_401_for_non_bearer_scheme(self):
        from app.auth import get_current_user
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(authorization="Basic dXNlcjpwYXNz")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_raises_401_for_empty_token(self):
        from app.auth import get_current_user
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(authorization="Bearer ")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_returns_payload_for_valid_bearer(self):
        from app.auth import get_current_user
        payload = {"oid": "uid123", "email": "user@test.com"}
        with patch("app.auth.decode_token", return_value=payload):
            result = await get_current_user(authorization="Bearer sometoken")
            assert result["oid"] == "uid123"

    @pytest.mark.asyncio
    async def test_strips_bearer_prefix(self):
        from app.auth import get_current_user
        with patch("app.auth.decode_token", return_value={"oid": "x"}) as mock_decode:
            await get_current_user(authorization="Bearer mytoken123")
            mock_decode.assert_called_once_with("mytoken123")


# ── get_current_user_optional ─────────────────────────────────────────────────

class TestGetCurrentUserOptional:
    @pytest.mark.asyncio
    async def test_returns_none_when_no_header(self):
        from app.auth import get_current_user_optional
        result = await get_current_user_optional(authorization=None)
        assert result is None

    @pytest.mark.asyncio
    async def test_returns_none_on_invalid_token(self):
        from app.auth import get_current_user_optional
        with patch("app.auth.decode_token", side_effect=HTTPException(status_code=401, detail="bad")):
            result = await get_current_user_optional(authorization="Bearer badtoken")
            assert result is None

    @pytest.mark.asyncio
    async def test_returns_payload_for_valid_token(self):
        from app.auth import get_current_user_optional
        payload = {"oid": "u1", "email": "u@test.com"}
        with patch("app.auth.decode_token", return_value=payload):
            result = await get_current_user_optional(authorization="Bearer goodtoken")
            assert result is not None
            assert result["oid"] == "u1"
