# Deployment Guide

## Quick Deploy to Fly.io

### 1. Manual Deploy (Current Changes)

From the `wap-backend` directory, run:

```bash
flyctl deploy
```

This will:
- Build your Docker image remotely on Fly.io
- Deploy the new version to your `swap-backend` app
- Run health checks to ensure it starts properly

**Check status:**
```bash
flyctl status
flyctl logs
```

**Test the live endpoint:**
```bash
curl https://swap-backend.fly.dev/healthz
```

---

## Set Up GitHub Actions CI/CD

### One-Time Setup

**1. Get your Fly.io API Token**

```bash
flyctl auth token
```

This will print your API token. Copy it.

**2. Add token to GitHub Secrets**

- Go to your GitHub repo: https://github.com/otitoudedibor/Panthers
- Navigate to: **Settings** → **Secrets and variables** → **Actions**
- Click **New repository secret**
- Name: `FLY_API_TOKEN`
- Value: Paste the token from step 1
- Click **Add secret**

**3. Push your code**

```bash
cd /Users/otitoudedibor/Documents/GitHub/Panthers/wap-backend
git add .
git commit -m "feat: add semantic search modes and CI/CD"
git push origin main
```

**4. Watch the deployment**

- Go to: https://github.com/otitoudedibor/Panthers/actions
- You'll see a workflow running called "Deploy to Fly.io"
- Click it to watch logs in real-time
- Once it completes (green checkmark), your app is live!

---

## How CI/CD Works

Once set up, **every push to `main`** will:
1. Trigger the GitHub Actions workflow (`.github/workflows/deploy.yml`)
2. Build the Docker image on Fly.io's builders
3. Deploy to your `swap-backend` app
4. Run health checks
5. Notify you if deployment fails

**To disable auto-deploy temporarily:**
- Just comment out the `on: push:` section in `.github/workflows/deploy.yml`

---

## Environment Variables on Fly.io

Your app currently has these set via `fly.toml`:
```toml
[env]
  QDRANT_HOST = 'qdrant.internal'
  QDRANT_PORT = '6333'
```

**To add Firebase credentials:**

```bash
# Set the Firebase credentials JSON as a secret (won't be visible in logs)
flyctl secrets set FIREBASE_CREDENTIALS_JSON="$(cat path/to/serviceAccount.json)"
```

**View current secrets:**
```bash
flyctl secrets list
```

---

## Scaling & Performance

**Current config (fly.toml):**
- Memory: 1GB
- CPU: 1 shared vCPU
- Min machines: 0 (auto-sleep when idle)
- Auto-start: true

**To increase memory if needed:**
```bash
flyctl scale memory 2048  # 2GB
```

**To keep 1 machine always running (no cold starts):**
Edit `fly.toml`:
```toml
min_machines_running = 1
```

Then redeploy:
```bash
flyctl deploy
```

---

## Troubleshooting Deployments

**Deployment fails or times out:**
```bash
# View build logs
flyctl logs

# Check app status
flyctl status

# SSH into the machine
flyctl ssh console

# Restart the app
flyctl apps restart swap-backend
```

**Out of Memory (OOM) errors:**
- Increase VM memory: `flyctl scale memory 2048`
- Or optimize the model loading in `app/main.py`

**Qdrant not working on Fly.io:**
- Verify Qdrant is running: check Fly.io dashboard for both `swap-backend` and `qdrant` apps
- Ensure `QDRANT_HOST=qdrant.internal` in `fly.toml` env section

---

## Rollback

If a deployment breaks production:

```bash
# List recent releases
flyctl releases

# Rollback to previous version
flyctl releases rollback
```

---

## Monitoring

**View real-time logs:**
```bash
flyctl logs -a swap-backend
```

**Check metrics:**
```bash
flyctl dashboard -a swap-backend
```

Or visit: https://fly.io/dashboard

---

## Cost

- **Free tier:** 3 shared-cpu-1x VMs with 256MB RAM
- **Your setup:** 1GB RAM = ~$1.94/month (prorated)
- **No charges when machines are stopped** (auto_stop_machines = true)

Check current usage:
```bash
flyctl info
```

