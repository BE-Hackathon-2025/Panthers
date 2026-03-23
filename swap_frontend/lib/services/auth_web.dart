/// Web-specific auth helpers using dart:html.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void redirectTo(String url) {
  html.window.location.assign(url);
}

String? getAuthCode() {
  final uri = Uri.parse(html.window.location.href);
  return uri.queryParameters['code'];
}

void clearUrlParams() {
  final base = html.window.location.origin! + html.window.location.pathname!;
  html.window.history.replaceState(null, '', base);
}

void storeVerifier(String verifier) {
  html.window.localStorage['entra_code_verifier'] = verifier;
}

String? readVerifier() {
  return html.window.localStorage['entra_code_verifier'];
}

void clearVerifier() {
  html.window.localStorage.remove('entra_code_verifier');
}
