/// Microsoft Entra External ID authentication service.
///
/// On web: uses browser redirect-based PKCE authorization code flow.
/// On mobile: not yet supported (flutter_appauth can be added later).
///
/// Token storage uses flutter_secure_storage.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

// Conditional import for web platform
import 'auth_stub.dart'
    if (dart.library.html) 'auth_web.dart' as platform_auth;

// ── Storage keys ──────────────────────────────────────────────────────────────
const _kAccessToken = 'entra_access_token';
const _kIdToken = 'entra_id_token';
const _kRefreshToken = 'entra_refresh_token';
const _kTokenExpiry = 'entra_token_expiry';
const _kCodeVerifier = 'entra_code_verifier';

/// Minimal representation of the signed-in user derived from the ID token.
class B2CUser {
  final String uid;
  final String? email;
  final String? displayName;

  const B2CUser({required this.uid, this.email, this.displayName});

  factory B2CUser.fromIdToken(String idToken) {
    final parts = idToken.split('.');
    if (parts.length < 2) return B2CUser(uid: '');
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final claims = jsonDecode(payload) as Map<String, dynamic>;
    return B2CUser(
      uid: (claims['oid'] ?? claims['sub'] ?? '') as String,
      email: (claims['emails'] is List && (claims['emails'] as List).isNotEmpty)
          ? (claims['emails'] as List).first as String
          : claims['email'] as String?,
      displayName: (claims['name'] ??
              claims['given_name'] ??
              claims['displayName']) as String?,
    );
  }
}

/// Singleton auth service.
class B2CAuthService {
  B2CAuthService._();
  static final instance = B2CAuthService._();

  final _storage = const FlutterSecureStorage();

  B2CUser? _currentUser;
  B2CUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Debug info from the last restoreSession / redirect attempt.
  String? lastAuthError;

  // ── PKCE helpers ──────────────────────────────────────────────────────────

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  // ── Restore session ─────────────────────────────────────────────────────

  /// Call once at app startup. On web, also handles the auth redirect callback.
  Future<void> restoreSession() async {
    if (kIsWeb) {
      await _handleWebRedirect();
    }

    final idToken = await _storage.read(key: _kIdToken);
    if (idToken == null) return;

    final expiryStr = await _storage.read(key: _kTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _tryRefresh();
        return;
      }
    }

    _currentUser = B2CUser.fromIdToken(idToken);
    debugPrint('[Auth] Session restored for ${_currentUser?.uid}');
  }

  // ── Sign-in (web PKCE redirect) ───────────────────────────────────────────

  Future<B2CUser> signIn() async {
    String step = 'init';
    try {
      step = 'generateVerifier';
      final verifier = _generateCodeVerifier();

      step = 'generateChallenge';
      final challenge = _generateCodeChallenge(verifier);

      step = 'storeVerifier';
      platform_auth.storeVerifier(verifier);

      step = 'buildUrl';
      final scopes = AppConfig.entraScopes.join(' ');
      final authUrl = 'https://${AppConfig.entraTenantName}.ciamlogin.com'
          '/${AppConfig.entraTenantId}/oauth2/v2.0/authorize'
          '?client_id=${AppConfig.entraClientId}'
          '&response_type=code'
          '&redirect_uri=${Uri.encodeComponent(AppConfig.entraRedirectUri)}'
          '&scope=${Uri.encodeComponent(scopes)}'
          '&response_mode=query'
          '&code_challenge=$challenge'
          '&code_challenge_method=S256';

      step = 'redirect';
      debugPrint('[Auth] Redirecting to: $authUrl');
      platform_auth.redirectTo(authUrl);

      await Future.delayed(const Duration(seconds: 10));
      throw Exception('Redirect did not complete');
    } catch (e) {
      throw Exception('signIn failed at step=$step: $e');
    }
  }

  // ── Handle auth redirect callback ─────────────────────────────────────────

  Future<void> _handleWebRedirect() async {
    try {
      final code = platform_auth.getAuthCode();
      if (code == null) {
        // No code in URL — not a redirect callback, normal app load
        return;
      }

      debugPrint('[Auth] Got auth code: ${code.substring(0, 10)}...');
      platform_auth.clearUrlParams();

      final verifier = platform_auth.readVerifier();
      platform_auth.clearVerifier();
      if (verifier == null) {
        lastAuthError = 'CALLBACK FAILED: code_verifier not found in localStorage. '
            'It may have been lost during the redirect.';
        debugPrint('[Auth] $lastAuthError');
        return;
      }

      debugPrint('[Auth] Got verifier: ${verifier.substring(0, 10)}...');

      final tokenUrl = 'https://${AppConfig.entraTenantName}.ciamlogin.com'
          '/${AppConfig.entraTenantId}/oauth2/v2.0/token';

      debugPrint('[Auth] Exchanging code at: $tokenUrl');

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': AppConfig.entraClientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': AppConfig.entraRedirectUri,
          'code_verifier': verifier,
          'scope': AppConfig.entraScopes.join(' '),
        },
      );

      await _storage.delete(key: _kCodeVerifier);

      if (response.statusCode != 200) {
        lastAuthError = 'TOKEN EXCHANGE FAILED (${response.statusCode}): ${response.body}';
        debugPrint('[Auth] $lastAuthError');
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final expiresIn = body['expires_in'] as int? ?? 3600;

      await _persistTokens(
        accessToken: body['access_token'] as String?,
        idToken: body['id_token'] as String?,
        refreshToken: body['refresh_token'] as String?,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );

      if (body['id_token'] != null) {
        _currentUser = B2CUser.fromIdToken(body['id_token'] as String);
        debugPrint('[Auth] Web sign-in complete for ${_currentUser?.uid}');
      } else {
        lastAuthError = 'TOKEN EXCHANGE: no id_token in response. Keys: ${body.keys.toList()}';
        debugPrint('[Auth] $lastAuthError');
      }
    } catch (e, st) {
      lastAuthError = 'REDIRECT HANDLER EXCEPTION: $e\n$st';
      debugPrint('[Auth] $lastAuthError');
    }
  }

  // ── Sign-out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _storage.deleteAll();
    _currentUser = null;
    debugPrint('[Auth] Signed out');

    if (kIsWeb) {
      final logoutUrl = 'https://${AppConfig.entraTenantName}.ciamlogin.com'
          '/${AppConfig.entraTenantId}/oauth2/v2.0/logout'
          '?post_logout_redirect_uri=${Uri.encodeComponent(AppConfig.entraRedirectUri)}';
      platform_auth.redirectTo(logoutUrl);
    }
  }

  // ── Token access ──────────────────────────────────────────────────────────

  Future<String?> getAccessToken() async {
    final expiryStr = await _storage.read(key: _kTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _tryRefresh();
      }
    }
    return _storage.read(key: _kAccessToken);
  }

  Future<String?> getIdToken() async {
    await getAccessToken();
    return _storage.read(key: _kIdToken);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _tryRefresh() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return;

    try {
      final tokenUrl = 'https://${AppConfig.entraTenantName}.ciamlogin.com'
          '/${AppConfig.entraTenantId}/oauth2/v2.0/token';

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': AppConfig.entraClientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'scope': AppConfig.entraScopes.join(' '),
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final expiresIn = body['expires_in'] as int? ?? 3600;
        await _persistTokens(
          accessToken: body['access_token'] as String?,
          idToken: body['id_token'] as String?,
          refreshToken: body['refresh_token'] as String?,
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        );
        if (body['id_token'] != null) {
          _currentUser = B2CUser.fromIdToken(body['id_token'] as String);
        }
        debugPrint('[Auth] Token refresh succeeded');
      } else {
        throw Exception('Refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[Auth] Token refresh failed: $e');
      await _storage.deleteAll();
      _currentUser = null;
    }
  }

  Future<void> _persistTokens({
    String? accessToken,
    String? idToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    if (accessToken != null) {
      await _storage.write(key: _kAccessToken, value: accessToken);
    }
    if (idToken != null) {
      await _storage.write(key: _kIdToken, value: idToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
    final expiry = expiresAt ?? DateTime.now().add(const Duration(hours: 1));
    await _storage.write(key: _kTokenExpiry, value: expiry.toIso8601String());
  }
}
