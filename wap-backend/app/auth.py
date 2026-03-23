"""Microsoft Entra External ID (CIAM) JWT validation middleware.

Validates Bearer tokens issued by the Entra External ID tenant.
JWKS keys are fetched once and cached; they auto-refresh on key-ID mismatch.

Usage in a FastAPI route:
    from app.auth import get_current_user

    @router.get("/me")
    def me(user: dict = Depends(get_current_user)):
        return user
"""

from __future__ import annotations

import time
from typing import Any, Dict, Optional

import httpx
from fastapi import Depends, Header, HTTPException, status
from jose import JWTError, jwk, jwt
from jose.utils import base64url_decode

from app.config import settings

# ── Entra External ID discovery / JWKS ────────────────────────────────────────

def _jwks_url() -> str:
    return (
        f"https://{settings.azure_entra_tenant_name}.ciamlogin.com"
        f"/{settings.azure_entra_tenant_id}"
        f"/discovery/v2.0/keys"
    )


_jwks_cache: Dict[str, Any] = {}
_jwks_fetched_at: float = 0.0
_JWKS_TTL = 3600  # seconds


def _get_jwks() -> Dict[str, Any]:
    global _jwks_cache, _jwks_fetched_at
    if time.time() - _jwks_fetched_at > _JWKS_TTL:
        resp = httpx.get(_jwks_url(), timeout=10)
        resp.raise_for_status()
        _jwks_cache = {k["kid"]: k for k in resp.json().get("keys", [])}
        _jwks_fetched_at = time.time()
    return _jwks_cache


def _get_public_key(kid: str):
    keys = _get_jwks()
    if kid not in keys:
        # Force refresh — new signing key
        global _jwks_fetched_at
        _jwks_fetched_at = 0.0
        keys = _get_jwks()
    if kid not in keys:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Unknown signing key id: {kid}",
        )
    return jwk.construct(keys[kid])


# ── Token validation ──────────────────────────────────────────────────────────

def decode_token(token: str) -> Dict[str, Any]:
    """Decode and validate an Entra External ID JWT. Raises HTTPException on failure."""
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token header: {exc}",
        )

    kid = header.get("kid")
    if not kid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token header missing 'kid'",
        )

    public_key = _get_public_key(kid)

    try:
        payload = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=settings.azure_entra_audience,
            options={"verify_exp": True},
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token validation failed: {exc}",
        )

    return payload


# ── FastAPI dependency ────────────────────────────────────────────────────────

async def get_current_user(
    authorization: Optional[str] = Header(default=None),
) -> Dict[str, Any]:
    """FastAPI dependency that extracts and validates the Bearer token.

    Returns the decoded JWT payload (includes 'sub' / 'oid', 'email', etc.).
    Raises HTTP 401 if the header is missing or the token is invalid.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header must be 'Bearer <token>'",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return decode_token(token)


async def get_current_user_optional(
    authorization: Optional[str] = Header(default=None),
) -> Optional[Dict[str, Any]]:
    """Same as get_current_user but returns None instead of raising 401.

    Use for endpoints that work with or without authentication.
    """
    if not authorization:
        return None
    try:
        return await get_current_user(authorization)
    except HTTPException:
        return None
