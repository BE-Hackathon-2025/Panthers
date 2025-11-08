import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ProfileService {
  final String baseUrl;
  ProfileService({String? baseUrl})
    : baseUrl = baseUrl ?? 'https://swap-backend.fly.dev';

  Future<void> upsertProfile({
    required String uid,
    required String email,
    required String displayName,
    required String skillsToOffer,
    String servicesNeeded = '',
    String bio = '',
    String city = '',
  }) async {
    if (skillsToOffer.trim().isEmpty) {
      debugPrint(
        '[ProfileService] WARN: skillsToOffer is empty. Upsert skipped.',
      );
      return;
    }

    final uri = Uri.parse('$baseUrl/profiles/upsert');

    String? idToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) idToken = await user.getIdToken();
    } catch (_) {}

    // On web, **omit Authorization** to avoid CORS preflight failures.
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!kIsWeb && idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    final bodyMap = {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'skills_to_offer': skillsToOffer,
      'services_needed': servicesNeeded,
      'bio': bio,
      'city': city,
    };
    final body = jsonEncode(bodyMap);

    debugPrint('[ProfileService] POST $uri headers=$headers body=$bodyMap');
    http.Response resp;

    try {
      resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      // If we’re not on web, or we already removed Authorization, rethrow.
      if (!kIsWeb || headers['Authorization'] == null) rethrow;

      // (Defensive) retry once without Authorization if some future change adds it.
      final h2 = <String, String>{'Content-Type': 'application/json'};
      debugPrint('[ProfileService] retry without Authorization due to: $e');
      resp = await http
          .post(uri, headers: h2, body: body)
          .timeout(const Duration(seconds: 12));
    }

    debugPrint('[ProfileService] resp ${resp.statusCode} ${resp.body}');
    if (resp.statusCode != 200) {
      throw Exception(
        'Upsert failed: ${resp.statusCode} ${resp.reasonPhrase} ${resp.body}',
      );
    }
  }
}
