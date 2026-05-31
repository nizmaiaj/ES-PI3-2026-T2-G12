class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://us-central1-bd-pi3-1808d.cloudfunctions.net',
  );

  static Uri endpoint(
    String functionName, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse(
      '$baseUrl/$functionName',
    ).replace(queryParameters: queryParameters);
  }
}
