# $wap — Azure Architecture Diagram

Paste the Mermaid code below into [mermaid.live](https://mermaid.live) to render the diagram.

```mermaid
graph TB
    subgraph Users["Users"]
        User["User (Browser)"]
    end

    subgraph Frontend["Frontend — Azure Static Web Apps"]
        SWA["stwa-swap-dev<br/><b>Flutter Web App</b>"]
    end

    subgraph Auth["Authentication"]
        B2C["Azure AD B2C<br/><b>swapb2c.onmicrosoft.com</b><br/>Sign-up / Sign-in"]
    end

    subgraph Backend["Backend — Azure App Service"]
        ASP["plan-swap-dev<br/><i>App Service Plan (B2)</i>"]
        APP["app-swap-dev<br/><b>FastAPI (Docker)</b>"]
        ASP --- APP
    end

    subgraph Data["Data Layer"]
        COSMOS["cosmos-swap-dev<br/><b>Azure Cosmos DB</b><br/>(NoSQL, Serverless)<br/>profiles | conversations | messages<br/>swap_requests | blocks | reports"]
        REDIS["redis-swap-dev<br/><b>Azure Cache for Redis</b><br/>(Basic C1)<br/>Caching & Debouncing"]
    end

    subgraph AI["AI Services"]
        SEARCH["swap-ai-search<br/><b>Azure AI Search</b><br/>Vector index: swap-users"]
        OPENAI["swap-chat-psu<br/><b>Azure OpenAI</b><br/>text-embedding-3-large"]
    end

    subgraph Comms["Communication"]
        ACS["acs-swap-dev<br/><b>Azure Communication Services</b><br/>Email Notifications"]
    end

    subgraph Security["Secrets & Identity"]
        KV["kv-swap-dev<br/><b>Azure Key Vault</b><br/>Connection strings & API keys"]
        MI["Managed Identity<br/><i>App Service → Key Vault</i><br/><i>App Service → ACR</i>"]
    end

    subgraph DevOps["CI/CD & Container"]
        ACR["crswapdev<br/><b>Container Registry</b><br/>swap-backend:latest"]
        GHA["GitHub Actions<br/><b>CI/CD Pipelines</b>"]
    end

    subgraph Monitoring["Observability"]
        APPI["appi-swapai-dev<br/><b>Application Insights</b>"]
        LAW["log-swap-dev<br/><b>Log Analytics Workspace</b>"]
        APPI --> LAW
    end

    %% User flows
    User -->|"HTTPS"| SWA
    User -->|"OAuth2 / OIDC"| B2C
    B2C -->|"JWT Token"| SWA
    SWA -->|"REST API + Bearer Token"| APP

    %% Backend connections
    APP -->|"CRUD operations"| COSMOS
    APP -->|"Cache / Debounce"| REDIS
    APP -->|"Vector search<br/>(skill matching)"| SEARCH
    APP -->|"Generate embeddings"| OPENAI
    APP -->|"Send emails"| ACS
    APP -.->|"Read secrets<br/>(Managed Identity)"| KV

    %% DevOps flows
    GHA -->|"Build & Push"| ACR
    ACR -->|"Pull image"| APP
    APP -.->|"Telemetry"| APPI

    %% Styling
    classDef azure fill:#0078D4,stroke:#005A9E,color:#fff
    classDef data fill:#00BCF2,stroke:#0078D4,color:#fff
    classDef ai fill:#6B2D8B,stroke:#4B1D6B,color:#fff
    classDef security fill:#107C10,stroke:#0B5E0B,color:#fff
    classDef user fill:#FFB900,stroke:#E6A700,color:#000
    classDef devops fill:#F25022,stroke:#D13F1C,color:#fff
    classDef monitoring fill:#7FBA00,stroke:#5E8A00,color:#fff

    class SWA,APP,ASP azure
    class COSMOS,REDIS data
    class SEARCH,OPENAI ai
    class KV,MI,B2C security
    class User user
    class ACR,GHA devops
    class APPI,LAW monitoring
    class ACS azure
```

## Resource Group: otito (Azure Subscription 1, centralus)

| Service | Resource Name | Purpose |
|---------|--------------|---------|
| Static Web Apps | `stwa-swap-dev` | Flutter web frontend hosting |
| Azure AD B2C | `swapb2c.onmicrosoft.com` | User authentication (OAuth2/OIDC) |
| App Service | `app-swap-dev` | FastAPI backend (Docker container) |
| App Service Plan | `plan-swap-dev` | Compute for backend (Linux B2) |
| Cosmos DB | `cosmos-swap-dev` | Primary database (6 containers) |
| Redis Cache | `redis-swap-dev` | Caching & email debouncing |
| AI Search | `swap-ai-search` | Vector search for skill matching |
| Azure OpenAI | `swap-chat-psu` | Embedding generation (text-embedding-3-large) |
| Communication Services | `acs-swap-dev` | Transactional email notifications |
| Key Vault | `kv-swap-dev` | Secrets management (connection strings, API keys) |
| Container Registry | `crswapdev` | Docker image storage for backend |
| Application Insights | `appi-swapai-dev` | Application monitoring & telemetry |
| Log Analytics | `log-swap-dev` | Centralized logging |

## Data Flow

1. **User** opens the Flutter web app hosted on **Static Web Apps**
2. **Azure AD B2C** handles sign-up/sign-in and issues a **JWT token**
3. Frontend calls the **FastAPI backend** on App Service with the Bearer token
4. Backend validates the JWT against B2C's JWKS endpoint
5. Profile/swap/message data is stored in **Cosmos DB**
6. When a profile is created/updated, **Azure OpenAI** generates embeddings
7. Embeddings are indexed in **Azure AI Search** for skill matching
8. **Redis** caches frequently accessed data and debounces email notifications
9. **Azure Communication Services** sends transactional emails (welcome, match, swap request)
10. All secrets are stored in **Key Vault**, accessed via **Managed Identity**
11. **Application Insights** collects telemetry, piped to **Log Analytics**
12. **GitHub Actions** builds Docker images, pushes to **Container Registry**, and deploys
