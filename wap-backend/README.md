# $wap Backend

Skill-for-skill exchange platform with semantic matching using Firebase, Qdrant, and BERT.

## 🚀 Quick Start

### 1. Setup Firebase (5 min)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create project → Enable Firestore
3. Download service account JSON → save as `firebase-credentials.json` in root

### 2. Install & Run (2 min)

```bash
# Install dependencies
pip install -r requirements.txt

# Start services
docker-compose up -d

# Test
curl http://localhost:8000/healthz
```

### 3. Test API

```bash
curl -X POST http://localhost:8000/profiles/upsert \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "test_user",
    "email": "test@example.com",
    "display_name": "Test User",
    "skills_to_offer": "Python programming",
    "services_needed": "Guitar lessons"
  }'
```

## 📚 Documentation

- **[Setup Guide](docs/SETUP.md)** - Complete setup instructions
- **[Deployment](docs/DEPLOY.md)** - Deploy to Fly.io
- **[API Reference](docs/API.md)** - API endpoints & examples

## 🎯 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/profiles/upsert` | POST | Create/update profile |
| `/profiles/{uid}` | GET | Get profile by UID |
| `/search` | POST | Semantic search |
| `/match/reciprocal` | POST | Find mutual matches |
| `/healthz` | GET | Health check |

## 🔑 Profile Schema

```json
{
  "uid": "firebase_user_123",
  "email": "alice@example.com",
  "display_name": "Alice Smith",
  "photo_url": "https://...",
  "full_name": "Alice Marie Smith",
  "username": "alice_codes",
  "bio": "Software engineer...",
  "city": "New York",
  "timezone": "America/New_York",
  "skills_to_offer": "Python, FastAPI",
  "services_needed": "Guitar, music theory",
  "dm_open": true,
  "email_updates": true,
  "show_city": true
}
```

## 🛠️ Tech Stack

- **Python 3.11** + **FastAPI**
- **Firebase Firestore** (database)
- **Qdrant** (vector search)
- **BERT** (embeddings)
- **Docker** + **Fly.io**

## 📱 Flutter Integration

```dart
final user = FirebaseAuth.instance.currentUser;

await http.post(
  Uri.parse('$apiUrl/profiles/upsert'),
  body: jsonEncode({
    'uid': user!.uid,
    'email': user.email!,
    'display_name': user.displayName,
    'photo_url': user.photoURL,
    'skills_to_offer': 'Python programming',
    'services_needed': 'Guitar lessons',
  }),
);
```

## 🔗 Links

- **API Docs**: http://localhost:8000/docs
- **Qdrant Dashboard**: http://localhost:6333/dashboard

## 📄 License

MIT
