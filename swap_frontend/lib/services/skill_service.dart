import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

import '../config.dart';
import 'b2c_auth_service.dart';

/// Model for a skill document returned by the backend.
class Skill {
  final String id;
  final String postedBy;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final double estimatedHours;
  final String delivery;
  final List<String> tags;
  final List<String> deliverables;
  final DateTime createdAt;
  final DateTime updatedAt;

  Skill({
    required this.id,
    required this.postedBy,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedHours,
    required this.delivery,
    required this.tags,
    required this.deliverables,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Skill.fromJson(Map<String, dynamic> j) => Skill(
        id: j['id'] as String? ?? '',
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
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : DateTime.now(),
        updatedAt: j['updated_at'] != null
            ? DateTime.parse(j['updated_at'] as String)
            : DateTime.now(),
      );
}

/// Service for skill CRUD operations.
class SkillService {
  final String baseUrl;

  SkillService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  Future<Map<String, String>> _getHeaders() async {
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
    return headers;
  }

  /// Create a new skill.
  Future<Skill> createSkill(String uid, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/skills').replace(
      queryParameters: {'uid': uid},
    );

    debugPrint('SkillService: POST $uri');

    final headers = await _getHeaders();
    final resp = await http
        .post(uri, headers: headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('Failed to create skill: ${resp.statusCode} ${resp.body}');
    }

    return Skill.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Get all skills by a user.
  Future<List<Skill>> getSkillsByUser(String uid) async {
    final uri = Uri.parse('$baseUrl/skills/user/$uid');

    debugPrint('SkillService: GET $uri');

    final headers = await _getHeaders();
    final resp = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to get skills: ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final data = jsonDecode(resp.body) as List<dynamic>;
    return data
        .map((e) => Skill.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get a single skill.
  Future<Skill> getSkill(String skillId, String uid) async {
    final uri = Uri.parse('$baseUrl/skills/$skillId').replace(
      queryParameters: {'uid': uid},
    );

    debugPrint('SkillService: GET $uri');

    final headers = await _getHeaders();
    final resp = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to get skill: ${resp.statusCode} ${resp.reasonPhrase}');
    }

    return Skill.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Delete a skill.
  Future<void> deleteSkill(String skillId, String uid) async {
    final uri = Uri.parse('$baseUrl/skills/$skillId').replace(
      queryParameters: {'uid': uid},
    );

    debugPrint('SkillService: DELETE $uri');

    final headers = await _getHeaders();
    final resp = await http
        .delete(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to delete skill: ${resp.statusCode} ${resp.reasonPhrase}');
    }
  }
}
