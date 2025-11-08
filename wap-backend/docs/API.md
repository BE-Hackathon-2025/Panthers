# API Reference

Complete API documentation for $wap backend.

## Base URL

- Local: `http://localhost:8000`
- Production: `https://your-app.fly.dev`

## Authentication

**None** - This is a no-auth MVP.

## Endpoints

### Health Check

**GET** `/healthz`

```bash
curl http://localhost:8000/healthz
```

Response:
```json
{"ok": true}
```

---

### Create/Update Profile

**POST** `/profiles/upsert`

Creates or updates a user profile in Firestore and Qdrant.

**Request:**
```json
{
  "uid": "firebase_user_123",
  "email": "alice@example.com",
  "display_name": "Alice Smith",
  "photo_url": "https://example.com/photo.jpg",
  "full_name": "Alice Marie Smith",
  "username": "alice_codes",
  "bio": "Software engineer passionate about music",
  "city": "New York",
  "timezone": "America/New_York",
  "skills_to_offer": "Python, FastAPI, web development",
  "services_needed": "Guitar, music theory",
  "dm_open": true,
  "email_updates": true,
  "show_city": true
}
```

**Required fields:**
- `uid`
- `email`

**Response:** Same as request + timestamps

```bash
curl -X POST http://localhost:8000/profiles/upsert \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "test123",
    "email": "test@example.com",
    "display_name": "Test User",
    "skills_to_offer": "Python",
    "services_needed": "Guitar"
  }'
```

---

### Get Profile by UID

**GET** `/profiles/{uid}`

```bash
curl http://localhost:8000/profiles/firebase_user_123
```

---

### Get Profile by Email

**GET** `/profiles/email/{email}`

```bash
curl http://localhost:8000/profiles/email/alice@example.com
```

---

### Update Profile (Partial)

**PATCH** `/profiles/{uid}`

Update only specific fields.

```bash
curl -X PATCH http://localhost:8000/profiles/test123 \
  -H "Content-Type: application/json" \
  -d '{
    "bio": "Updated bio",
    "city": "San Francisco"
  }'
```

---

### Delete Profile

**DELETE** `/profiles/{uid}`

```bash
curl -X DELETE http://localhost:8000/profiles/test123
```

Response:
```json
{
  "message": "Profile deleted successfully",
  "uid": "test123"
}
```

---

### Semantic Search (Natural Language)

**POST** `/search`

Search profiles semantically by what they offer or need.

**Request:**
```json
{
  "query": "teach me guitar and music theory",
  "limit": 10,
  "score_threshold": 0.3,
  "mode": "offers"  // "offers" | "needs" | "both" (default: "offers")
}
```

**Response:**
```json
[
  {
    "uid": "user_xyz",
    "email": "bob@example.com",
    "display_name": "Bob",
    "skills_to_offer": "Guitar, music theory, jazz",
    "services_needed": "Python programming",
    "score": 0.92
  }
]
```

Examples:
```bash
# Search people who can teach guitar (offer_vec)
curl -X POST http://localhost:8000/search \
  -H "Content-Type: application/json" \
  -d '{"query":"teach me guitar and music","limit":5,"mode":"offers"}'

# Search people who need Python help (need_vec)
curl -X POST http://localhost:8000/search \
  -H "Content-Type: application/json" \
  -d '{"query":"i need python help","limit":5,"mode":"needs"}'

# Search both, return best per user (max score of offers/needs)
curl -X POST http://localhost:8000/search \
  -H "Content-Type: application/json" \
  -d '{"query":"guitar and python","limit":10,"mode":"both"}'
```

---

### Reciprocal Matching

**POST** `/match/reciprocal`

Find mutual skill swap matches using harmonic mean.

**Request:**
```json
{
  "my_offer_text": "Python programming and web development",
  "my_need_text": "Guitar lessons and music theory",
  "limit": 10
}
```

**Response:**
```json
[
  {
    "uid": "user_xyz",
    "email": "bob@example.com",
    "display_name": "Bob",
    "skills_to_offer": "Guitar, music theory",
    "services_needed": "Python, web development",
    "reciprocal_score": 0.89,
    "offer_match_score": 0.92,
    "need_match_score": 0.87,
    "score": 0.89,
    ...
  }
]
```

**Score meanings:**
- `reciprocal_score`: Overall match quality (harmonic mean)
- `offer_match_score`: How well they offer what you need
- `need_match_score`: How well you offer what they need

```bash
curl -X POST http://localhost:8000/match/reciprocal \
  -H "Content-Type: application/json" \
  -d '{
    "my_offer_text": "Python programming",
    "my_need_text": "Guitar lessons",
    "limit": 10
  }'
```

---

## Flutter Integration

### Complete Example

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class SwapApiService {
  final String baseUrl = 'https://your-app.fly.dev';
  
  Future<Map<String, dynamic>> createProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    final response = await http.post(
      Uri.parse('$baseUrl/profiles/upsert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': user.uid,
        'email': user.email!,
        'display_name': user.displayName,
        'photo_url': user.photoURL,
        'skills_to_offer': 'Python programming',
        'services_needed': 'Guitar lessons',
      }),
    );
    
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> findMatches({
    required String myOffer,
    required String myNeed,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/match/reciprocal'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'my_offer_text': myOffer,
        'my_need_text': myNeed,
        'limit': 10,
      }),
    );
    
    return jsonDecode(response.body);
  }
}
```

---

## Interactive Docs

Visit `/docs` for Swagger UI with try-it-out functionality:

**http://localhost:8000/docs**

---

## Error Responses

### 404 Not Found
```json
{
  "detail": "Profile not found"
}
```

### 422 Validation Error
```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "value is not a valid email address",
      "type": "value_error.email"
    }
  ]
}
```

---

## Rate Limits

None for MVP. Add later if needed.

