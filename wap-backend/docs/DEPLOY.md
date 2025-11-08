# Deployment Guide

Deploy $wap backend to Fly.io.

## Prerequisites

- Fly.io account ([sign up](https://fly.io/))
- Fly CLI installed
- Firebase credentials JSON

## Install Fly CLI

### macOS
```bash
brew install flyctl
```

### Linux
```bash
curl -L https://fly.io/install.sh | sh
```

### Windows
```powershell
iwr https://fly.io/install.ps1 -useb | iex
```

## Deploy Steps

### 1. Login

```bash
fly auth login
```

### 2. Launch App

```bash
# This creates the app
fly launch --no-deploy

# Answer prompts:
# - App name: wap-backend (or your choice)
# - Region: Choose closest to your users
# - Setup PostgreSQL? → No (we use Firestore)
# - Setup Redis? → No
```

### 3. Set Firebase Credentials

```bash
# Set as secret (minified JSON)
fly secrets set FIREBASE_CREDENTIALS_JSON="$(cat firebase-credentials.json | jq -c .)"

# Or if you don't have jq:
cat firebase-credentials.json | tr -d '\n' | pbcopy
fly secrets set FIREBASE_CREDENTIALS_JSON="<paste>"
```

### 4. Deploy

```bash
fly deploy
```

### 5. Verify

```bash
# Check status
fly status

# View logs
fly logs

# Test health
curl https://your-app.fly.dev/healthz
```

## Optional: Setup Qdrant on Fly.io

If you want Qdrant on Fly.io instead of external:

```bash
# Create Qdrant app
fly apps create wap-qdrant

# Deploy Qdrant
fly deploy --app wap-qdrant --image qdrant/qdrant:v1.7.0

# Update main app to use internal Qdrant
fly secrets set QDRANT_HOST="wap-qdrant.internal"
```

Or use **Qdrant Cloud** (recommended):
1. Sign up at [cloud.qdrant.io](https://cloud.qdrant.io)
2. Create cluster (free tier available)
3. Set secrets:

```bash
fly secrets set QDRANT_HOST="your-cluster.cloud.qdrant.io"
fly secrets set QDRANT_PORT="6333"
```

## Scaling

### Increase Memory

```bash
fly scale memory 1024
```

### Add Instances

```bash
fly scale count 2
```

## Monitoring

### View Logs

```bash
# Real-time
fly logs

# Historical
fly logs --history
```

### SSH Access

```bash
fly ssh console

# Inside: reindex Qdrant
python scripts/reindex.py
```

## CI/CD with GitHub Actions

### 1. Get API Token

```bash
fly auth token
```

### 2. Add to GitHub Secrets

1. Go to repo → Settings → Secrets → Actions
2. New secret: `FLY_API_TOKEN`
3. Paste token

### 3. Auto-Deploy

The workflow in `.github/workflows/cd.yml` will auto-deploy on push to `main`.

## Custom Domain (Optional)

```bash
# Add domain
fly certs add yourdomain.com

# Follow DNS instructions
fly certs show yourdomain.com
```

## Update Fly Config

Edit `fly.toml` if needed:

```toml
app = "wap-backend"
primary_region = "iad"

[env]
  QDRANT_HOST = "qdrant.internal"
  QDRANT_PORT = "6333"

[http_service]
  internal_port = 8000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0

[[http_service.checks]]
  interval = "10s"
  timeout = "2s"
  grace_period = "5s"
  method = "GET"
  path = "/healthz"
```

## Costs

**Free Tier:**
- 3 shared-cpu-1x VMs
- 160GB storage

**Estimated Monthly (beyond free):**
- App (1GB RAM): ~$5-10
- Qdrant Cloud (1GB): ~$30-50

For MVP, free tier should be sufficient!

## Troubleshooting

### App won't start

```bash
fly logs
```

Common issues:
- Missing `FIREBASE_CREDENTIALS_JSON` secret
- Incorrect Qdrant connection

### Need more memory

```bash
fly scale memory 2048
```

## Resources

- [Fly.io Docs](https://fly.io/docs)
- [Fly.io Community](https://community.fly.io)

