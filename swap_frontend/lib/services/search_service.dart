import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

import '../config.dart';
import 'b2c_auth_service.dart';

/// Model for a single search hit returned by the backend /search endpoint.
class SearchResult {
  final String uid;
  final String displayName;
  final String email;
  final String skillsToOffer;
  final String servicesNeeded;
  final String bio;
  final String city;
  final int swapCredits;
  final int swapsCompleted;
  final double score;

  SearchResult({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.skillsToOffer,
    required this.servicesNeeded,
    required this.bio,
    required this.city,
    required this.swapCredits,
    required this.swapsCompleted,
    required this.score,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
    uid: j['uid'] as String? ?? '',
    displayName:
        j['display_name'] as String? ?? j['displayName'] as String? ?? '',
    email: j['email'] as String? ?? '',
    skillsToOffer:
        j['skills_to_offer'] as String? ??
        j['skillsToOffer'] as String? ??
        '',
    servicesNeeded:
        j['services_needed'] as String? ?? j['servicesNeeded'] as String? ?? '',
    bio: j['bio'] as String? ?? '',
    city: j['city'] as String? ?? '',
    swapCredits: (j['swap_credits'] as num?)?.toInt() ?? 0,
    swapsCompleted: (j['swaps_completed'] as num?)?.toInt() ?? 0,
    score: (j['score'] is num)
        ? (j['score'] as num).toDouble()
        : double.tryParse('${j['score']}') ?? 0.0,
  );
}

/// Model for a skill-centric search hit.
class SkillSearchResult {
  final String id;
  final String skillId;
  final String postedBy;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final double estimatedHours;
  final String delivery;
  final List<String> tags;
  final List<String> deliverables;
  final String posterName;
  final String posterCity;
  final int posterSwapCredits;
  final double score;

  SkillSearchResult({
    required this.id,
    required this.skillId,
    required this.postedBy,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedHours,
    required this.delivery,
    required this.tags,
    required this.deliverables,
    required this.posterName,
    required this.posterCity,
    required this.posterSwapCredits,
    required this.score,
  });

  factory SkillSearchResult.fromJson(Map<String, dynamic> j) =>
      SkillSearchResult(
        id: j['id'] as String? ?? '',
        skillId: j['skill_id'] as String? ?? j['id'] as String? ?? '',
        postedBy: j['posted_by'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        category: j['category'] as String? ?? '',
        difficulty: j['difficulty'] as String? ?? '',
        estimatedHours: (j['estimated_hours'] as num?)?.toDouble() ?? 1,
        delivery: j['delivery'] as String? ?? 'Remote Only',
        tags: (j['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        deliverables: (j['deliverables'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        posterName: j['poster_name'] as String? ?? '',
        posterCity: j['poster_city'] as String? ?? '',
        posterSwapCredits: (j['poster_swap_credits'] as num?)?.toInt() ?? 0,
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
    : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

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

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    // Avoid CORS preflight on web by omitting Authorization there.
    if (!kIsWeb) {
      try {
        final token = await B2CAuthService.instance.getAccessToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
      } catch (_) {
        // ignore token errors; the endpoint may allow unauthenticated requests
      }
    }

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

  /// Perform a skill-centric search.
  Future<List<SkillSearchResult>> searchSkills(
    String query, {
    String? category,
    int limit = 10,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl/search/skills');
    final bodyMap = <String, dynamic>{
      'query': query,
      'limit': limit,
    };
    if (category != null && category.isNotEmpty) {
      bodyMap['category'] = category;
    }
    final body = jsonEncode(bodyMap);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (!kIsWeb) {
      try {
        final token = await B2CAuthService.instance.getAccessToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
      } catch (_) {}
    }

    debugPrint(
      'SearchService: POST $uri q="$query" category=$category limit=$limit',
    );

    final resp = await http
        .post(uri, headers: headers, body: body)
        .timeout(timeout ?? const Duration(seconds: 12));

    if (resp.statusCode != 200) {
      throw Exception(
          'Skill search failed: ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final data = jsonDecode(resp.body);
    if (data is List) {
      return data
          .map((e) => SkillSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Unexpected skill search response format');
  }
}
