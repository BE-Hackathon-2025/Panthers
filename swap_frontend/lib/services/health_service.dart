import 'package:http/http.dart' as http;

import '../config.dart';

class HealthService {
  final String baseUrl;
  HealthService({String? baseUrl})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  Future<String> ping() async {
    final resp = await http
        .get(Uri.parse('$baseUrl/healthz'))
        .timeout(const Duration(seconds: 8));
    return 'status=${resp.statusCode}, body=${resp.body}';
  }
}
