"""FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import profiles, search, swaps, swap_requests, messages, moderation, points, skills

logger = logging.getLogger(__name__)

# ── Application Insights telemetry (no-op if connection string absent) ────────
def _setup_telemetry() -> None:
    if not settings.applicationinsights_connection_string:
        return
    try:
        from opencensus.ext.azure.log_exporter import AzureLogHandler
        from opencensus.ext.azure.trace_exporter import AzureExporter
        from opencensus.trace.samplers import ProbabilitySampler
        from opencensus.trace import config_integration

        config_integration.trace_integrations(["logging"])

        logging.getLogger().addHandler(
            AzureLogHandler(
                connection_string=settings.applicationinsights_connection_string
            )
        )
        logger.info("Application Insights telemetry initialised")
    except Exception as exc:  # pragma: no cover
        logger.warning("Application Insights setup failed (non-fatal): %s", exc)


# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle hooks: startup and shutdown."""
    _setup_telemetry()

    # Cosmos DB
    try:
        from app.cosmos_db import get_cosmos_service
        get_cosmos_service()
        logger.info("Cosmos DB connected")
    except Exception as exc:
        logger.warning("Cosmos DB not configured (non-fatal): %s", exc)

    # Embedding model warm-up
    try:
        from app.embeddings import get_embedding_service
        get_embedding_service().encode("warmup")
        logger.info("Embedding model ready")
    except Exception as exc:
        logger.warning("Embedding service unavailable (non-fatal): %s", exc)

    yield
    # Shutdown — nothing to clean up for now


# ── App ───────────────────────────────────────────────────────────────────────

app = FastAPI(
    title=settings.app_name,
    description="Skill-for-skill exchange platform — Azure PaaS",
    version="0.4.0",
    lifespan=lifespan,
)

# CORS — restrict to known origins in production
_CORS_ORIGINS = [
    "https://red-sea-09c59bb10.2.azurestaticapps.net",
    "https://stwa-swap-dev.azurestaticapps.net",
    "http://localhost:3000",
    "http://localhost:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(profiles.router)
app.include_router(search.router)
app.include_router(swaps.router)
app.include_router(swap_requests.router)
app.include_router(messages.router)
app.include_router(moderation.router)
app.include_router(points.router)
app.include_router(skills.router)


# ── Health check ──────────────────────────────────────────────────────────────

@app.get("/healthz", tags=["ops"])
def health_check():
    """Health check endpoint with service status."""
    from app.cache import get_cache_service

    cache = get_cache_service()

    cosmos_status = "not configured"
    try:
        from app.cosmos_db import get_cosmos_service
        get_cosmos_service()
        cosmos_status = "connected"
    except Exception:
        pass

    return {
        "status": "healthy",
        "version": "0.4.0",
        "services": {
            "cosmos_db": cosmos_status,
            "azure_search": "configured" if settings.azure_search_endpoint else "not configured",
            "azure_openai": "configured" if settings.azure_openai_endpoint else "not configured",
            "redis": "connected" if cache.enabled else "disabled",
            "app_insights": "configured" if settings.applicationinsights_connection_string else "not configured",
        },
    }


@app.get("/", tags=["ops"])
def root():
    """Root endpoint."""
    return {
        "message": "Welcome to $wap — Skill-for-skill exchange platform",
        "version": "0.4.0",
        "database": "Azure Cosmos DB",
        "vector_db": "Azure AI Search",
        "embeddings": "Azure OpenAI",
        "auth": "Azure AD B2C",
        "docs": "/docs",
        "health": "/healthz",
    }
