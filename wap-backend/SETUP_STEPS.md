# Quick Setup Steps

## Status Check
- ✅ Python 3.9.6 installed
- ❌ Docker not installed (REQUIRED)
- ❌ Firebase credentials not found (REQUIRED)

## Step 1: Install Docker (5 minutes)

### Option A: Install Docker Desktop (Recommended)
1. Download from: https://www.docker.com/products/docker-desktop
2. Open the .dmg file and drag Docker to Applications
3. Launch Docker Desktop
4. Wait for Docker to start (whale icon in menu bar should be steady)

### Option B: Using Homebrew
```bash
brew install --cask docker
```

After installing, verify:
```bash
docker --version
docker-compose --version
```

## Step 2: Get Firebase Credentials (15 minutes)

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/

2. **Create Project**
   - Click "Add project"
   - Name: `wap-backend` (or your choice)
   - Disable Google Analytics (optional)
   - Click "Create project"

3. **Enable Firestore**
   - In left sidebar → Click "Firestore Database"
   - Click "Create database"
   - Choose "Start in production mode"
   - Select location: `us-central1`
   - Click "Enable"

4. **Set Security Rules**
   - Go to "Rules" tab
   - Replace with:
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
   - Click "Publish"

5. **Download Credentials**
   - Click gear icon (⚙️) → "Project settings"
   - Go to "Service accounts" tab
   - Click "Generate new private key"
   - Click "Generate key"
   - Save the downloaded JSON file as `firebase-credentials.json` in this directory:
     `/Users/otitoudedibor/Documents/GitHub/Panthers/wap-backend/`

## Step 3: Install Python Dependencies (2 minutes)

```bash
cd /Users/otitoudedibor/Documents/GitHub/Panthers/wap-backend
pip3 install -r requirements.txt
```

Or with virtual environment (recommended):
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Step 4: Start the Services (1 minute)

```bash
# Make sure Docker Desktop is running first!
docker-compose up -d
```

## Step 5: Test It Works (1 minute)

```bash
# Health check
curl http://localhost:8000/healthz

# Should return: {"ok":true}
```

```bash
# Visit API docs
open http://localhost:8000/docs
```

## Step 6: Create Test Profile

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

## Troubleshooting

### "Cannot connect to Docker daemon"
- Make sure Docker Desktop is running (whale icon in menu bar)
- Try: `docker ps` to test connection

### "Connection refused" on port 8000
- Wait 30 seconds for services to start
- Check logs: `docker-compose logs -f app`

### "Firebase credentials not found"
- Make sure file is named exactly: `firebase-credentials.json`
- Make sure it's in the project root directory
- Check: `ls -la firebase-credentials.json`

## Next Steps

Once everything is running:
1. ✅ Test the API at http://localhost:8000/docs
2. ✅ Check Firebase Console to see your test profile
3. ✅ Connect your Flutter app!

## Commands Reference

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Restart a service
docker-compose restart app

# Check status
docker-compose ps
```

---

**Ready?** Start with Step 1! 🚀
