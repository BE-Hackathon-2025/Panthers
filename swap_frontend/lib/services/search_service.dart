import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Model for a single search hit returned by the backend /search endpoint.
class SearchResult {
  final String uid;
  final String displayName;
  final String email;
  final String skillsToOffer;
  final String servicesNeeded;
  final String bio;
  final String city;
  final double score;

  SearchResult({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.skillsToOffer,
    required this.servicesNeeded,
    required this.bio,
    required this.city,
    required this.score,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
    uid: j['uid'] as String? ?? '',
    displayName:
        j['display_name'] as String? ?? j['displayName'] as String? ?? '',
    email: j['email'] as String? ?? '',
    skillsToOffer:
        j['skills_to_offer'] as String? ??
        j['skills_to_offer'] as String? ??
        j['skillsToOffer'] as String? ??
        '',
    servicesNeeded:
        j['services_needed'] as String? ?? j['servicesNeeded'] as String? ?? '',
    bio: j['bio'] as String? ?? '',
    city: j['city'] as String? ?? '',
    score: (j['score'] is num)
        ? (j['score'] as num).toDouble()
        : double.tryParse('${j['score']}') ?? 0.0,
  );
}

/// A small client for the backend semantic search API.
class SearchService {
  /// Base URL of the backend. Use the production URL by default but allow
  /// overriding for local development.
  final String baseUrl;

  SearchService({String? baseUrl})
    : baseUrl = baseUrl ?? 'https://swap-backend.fly.dev';

  /// Perform a semantic search.
  ///
  /// query: natural-language query like "learn guitar"
  /// mode: one of 'offers', 'needs', 'both'
  /// limit: maximum number of results
  Future<List<SearchResult>> search(
    String query, {
    String mode = 'offers',
    int limit = 10,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl/search');
    final body = jsonEncode({'query': query, 'mode': mode, 'limit': limit});

    // If the user is signed in, include an ID token in Authorization header.
    String? idToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) idToken = await user.getIdToken();
    } catch (_) {
      // ignore token errors; the endpoint may allow unauthenticated requests
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    // Avoid CORS preflight on web by omitting Authorization there.
    if (!kIsWeb && idToken != null)
      headers['Authorization'] = 'Bearer $idToken';

    debugPrint(
      'SearchService: POST $uri q="$query" mode=$mode limit=$limit (timeout=${timeout ?? const Duration(seconds: 12)})',
    );

    final resp = await http
        .post(uri, headers: headers, body: body)
        .timeout(timeout ?? const Duration(seconds: 12));

    if (resp.statusCode != 200) {
      throw Exception('Search failed: ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final data = jsonDecode(resp.body);
    if (data is List) {
      final results = data
          .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
      // helpful debug when testing from the app
      try {
        // ignore: avoid_print
        debugPrint('SearchService: query="$query" -> ${results.length} hits');
        if (results.isNotEmpty) {
          // ignore: avoid_print
          debugPrint(
            'SearchService: first=${results.first.email} score=${results.first.score}',
          );
        }
      } catch (_) {}
      return results;
    }

    throw Exception('Unexpected search response format');
  }
}
