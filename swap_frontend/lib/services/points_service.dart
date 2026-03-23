import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/points.dart';
import 'b2c_auth_service.dart';

class PointsService {
  final String baseUrl;
  PointsService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  Future<Map<String, String>> _headers() async {
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

  /// Get current points + credits balance.
  Future<PointsBalance> getBalance(String uid) async {
    final uri = Uri.parse('$baseUrl/points/balance?uid=$uid');
    final resp = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception('Failed to get balance: ${resp.statusCode}');
    }
    return PointsBalance.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Get transaction history.
  Future<List<PointsTransaction>> getHistory(String uid,
      {int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/points/history?uid=$uid&limit=$limit');
    final resp = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception('Failed to get history: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as List;
    return data
        .map((e) => PointsTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Complete a swap and earn points/credits.
  Future<PointsBalance> completeSwap({
    required String uid,
    required String requestId,
    required double hours,
    required String skillLevel,
    String? notes,
  }) async {
    final uri = Uri.parse(
        '$baseUrl/points/complete-swap/$requestId?uid=$uid');
    final body = jsonEncode(<String, dynamic>{
      'hours': hours,
      'skill_level': skillLevel,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final resp = await http
        .post(uri, headers: await _headers(), body: body)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to complete swap: ${resp.statusCode} ${resp.body}');
    }
    return PointsBalance.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Spend points on platform features.
  Future<PointsTransaction> spendPoints({
    required String uid,
    required String reason,
    int? durationHours,
  }) async {
    final uri = Uri.parse('$baseUrl/points/spend?uid=$uid');
    final body = jsonEncode(<String, dynamic>{
      'reason': reason,
      if (durationHours != null) 'duration_hours': durationHours,
    });
    final resp = await http
        .post(uri, headers: await _headers(), body: body)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to spend points: ${resp.statusCode} ${resp.body}');
    }
    return PointsTransaction.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }
}
