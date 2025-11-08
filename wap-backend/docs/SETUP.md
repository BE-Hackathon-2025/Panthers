# Setup Guide

Complete guide to get $wap backend running locally.

## Prerequisites

- Docker & Docker Compose
- Python 3.11+
- Firebase account

## Step 1: Firebase Setup (15 min)

### Create Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name: `wap-backend`
4. Disable Google Analytics (optional)

### Enable Firestore

1. In sidebar → **Firestore Database**
2. Click "Create database"
3. Choose "Start in production mode"
4. Select location: `us-central1` (or closest to you)

### Configure Security Rules

1. Go to Firestore → **Rules** tab
2. Replace with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /profiles/{uid} {
      allow read, write: if true;
    }
  }
}
```

3. Click "Publish"

### Download Credentials

1. Go to **Project Settings** (gear icon) → **Service Accounts**
2. Click "Generate new private key"
3. Save as `firebase-credentials.json` in project root
4. **Important**: This file should already be in `.gitignore`

## Step 2: Local Setup (5 min)

### Install Dependencies

```bash
# Create virtual environment (optional)
python3.11 -m venv venv
source venv/bin/activate

# Install
pip install -r requirements.txt
```

### Start Services

```bash
# Start Qdrant and app
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f app
```

## Step 3: Test (2 min)

### Health Check

```bash
curl http://localhost:8000/healthz
# Should return: {"ok": true}
```

### Create Test Profile

```bash
curl -X POST http://localhost:8000/profiles/upsert \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "test_user_123",
    "email": "test@example.com",
    "display_name": "Test User",
    "skills_to_offer": "Python programming",
    "services_needed": "Guitar lessons"
  }'
```

### Verify in Firebase Console

1. Go to Firestore Database → Data
2. You should see `profiles` collection
3. Document `test_user_123` with your data

### Test Search

```bash
curl -X POST http://localhost:8000/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "guitar lessons",
    "limit": 5
  }'
```

## Services

Once running, you have:

| Service | URL | Purpose |
|---------|-----|---------|
| API | http://localhost:8000 | Backend API |
| API Docs | http://localhost:8000/docs | Interactive docs |
| Qdrant | http://localhost:6333 | Vector database |
| Qdrant UI | http://localhost:6333/dashboard | Vector DB UI |

## Troubleshooting

### "Could not load credentials"

```bash
# Check file exists
ls -la firebase-credentials.json

# Should see the file, not an error
```

### "Connection refused" for Qdrant

```bash
# Wait for Qdrant to start
docker-compose logs qdrant

# Should see "Qdrant HTTP listening on 6333"
```

### Port already in use

```bash
# Stop existing containers
docker-compose down

# Or change port in docker-compose.yml
```

## Environment Variables

Optional `.env` file (defaults work for local):

```bash
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_COLLECTION=swap_users
EMBEDDING_MODEL=sentence-transformers/bert-base-nli-mean-tokens
VECTOR_DIM=768
```

## Next Steps

- ✅ **Test the API** - Visit http://localhost:8000/docs
- ✅ **Connect Flutter** - Use the API in your app
- ✅ **Deploy** - See [DEPLOY.md](DEPLOY.md)

