/// App-wide configuration — values injected at build time via --dart-define.
///
/// Production build:
///   flutter build web --release \
///     --dart-define=API_BASE_URL=https://app-swap-dev.azurewebsites.net \
///     --dart-define=ENTRA_CLIENT_ID=<frontend-app-registration-client-id> \
///     --dart-define=ENTRA_TENANT_ID=<tenant-id>
///
/// Local development: falls back to the defaultValue for each constant.
class AppConfig {
  AppConfig._();

  // ── Backend API ─────────────────────────────────────────────────────────────
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  // ── Microsoft Entra External ID (CIAM) ─────────────────────────────────────
  static const String entraTenantName = String.fromEnvironment(
    'ENTRA_TENANT_NAME',
    defaultValue: 'swapauth',
  );

  static const String entraTenantId = String.fromEnvironment(
    'ENTRA_TENANT_ID',
    defaultValue: '', // Required — must be passed at build time
  );

  static const String entraClientId = String.fromEnvironment(
    'ENTRA_CLIENT_ID',
    defaultValue: '', // Required — must be passed at build time
  );

  static const String entraRedirectUri = String.fromEnvironment(
    'ENTRA_REDIRECT_URI',
    defaultValue: 'http://localhost:3000/',
  );

  // Derived — Entra External ID uses ciamlogin.com
  static String get entraDiscoveryUrl =>
      'https://$entraTenantName.ciamlogin.com'
      '/$entraTenantId'
      '/v2.0/.well-known/openid-configuration';

  static const List<String> entraScopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}
