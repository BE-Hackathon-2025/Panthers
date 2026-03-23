/// Stub implementations for non-web platforms.

void redirectTo(String url) {
  throw UnsupportedError('redirectTo is only supported on web');
}

String? getAuthCode() => null;

void clearUrlParams() {}

void storeVerifier(String verifier) {}

String? readVerifier() => null;

void clearVerifier() {}
