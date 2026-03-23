import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

import '../config.dart';
import 'b2c_auth_service.dart';

class ProfileService {
  final String baseUrl;
  ProfileService({String? baseUrl})
    : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final uri = Uri.parse('$baseUrl/profiles/$uid');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 404) return null;
      if (resp.statusCode != 200) throw Exception('${resp.statusCode}');
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ProfileService] getProfile error: $e');
      return null;
    }
  }

  Future<void> upsertProfile({
    required String uid,
    required String email,
    required String displayName,
    required String skillsToOffer,
    String servicesNeeded = '',
    String bio = '',
    String city = '',
    String fullName = '',
    String username = '',
    String timezone = '',
    bool? dmOpen,
    bool? emailUpdates,
    bool? showCity,
    Duration? timeout,
  }) async {
    // Allow empty skillsToOffer — the backend handles it as Optional.

    final uri = Uri.parse('$baseUrl/profiles/upsert');

    // On web, omit Authorization to avoid CORS preflight failures.
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!kIsWeb) {
      try {
        final token = await B2CAuthService.instance.getAccessToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
      } catch (_) {}
    }

    final bodyMap = <String, dynamic>{
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'skills_to_offer': skillsToOffer,
      'services_needed': servicesNeeded,
      'bio': bio,
      'city': city,
    };
    if (fullName.isNotEmpty) bodyMap['full_name'] = fullName;
    if (username.isNotEmpty) bodyMap['username'] = username;
    if (timezone.isNotEmpty) bodyMap['timezone'] = timezone;
    if (dmOpen != null) bodyMap['dm_open'] = dmOpen;
    if (emailUpdates != null) bodyMap['email_updates'] = emailUpdates;
    if (showCity != null) bodyMap['show_city'] = showCity;
    final body = jsonEncode(bodyMap);

    debugPrint('[ProfileService] POST $uri headers=$headers body=$bodyMap');
    http.Response resp;

    try {
      resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(timeout ?? const Duration(seconds: 8));
    } catch (e) {
      // If we're not on web, or we already removed Authorization, rethrow.
      if (!kIsWeb || headers['Authorization'] == null) rethrow;

      // (Defensive) retry once without Authorization if some future change adds it.
      final h2 = <String, String>{'Content-Type': 'application/json'};
      debugPrint('[ProfileService] retry without Authorization due to: $e');
      resp = await http
          .post(uri, headers: h2, body: body)
          .timeout(timeout ?? const Duration(seconds: 8));
    }

    debugPrint('[ProfileService] resp ${resp.statusCode} ${resp.body}');
    if (resp.statusCode != 200) {
      throw Exception(
        'Upsert failed: ${resp.statusCode} ${resp.reasonPhrase} ${resp.body}',
      );
    }
  }
}
