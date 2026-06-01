/// Centraliza a URL das Cloud Functions e permite sobrescrevê-la com
/// `--dart-define=API_BASE_URL=...` durante desenvolvimento ou testes.
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://us-central1-bd-pi3-1808d.cloudfunctions.net',
  );

  /// Monta a URI de uma Function e inclui parâmetros opcionais de query string.
  static Uri endpoint(
    String functionName, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse(
      '$baseUrl/$functionName',
    ).replace(queryParameters: queryParameters);
  }
}
