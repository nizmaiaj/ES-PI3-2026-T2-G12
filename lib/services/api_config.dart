class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5001/bd-pi3-1808d/us-central1',
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
