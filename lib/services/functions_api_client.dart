import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_session.dart';

class FunctionsApiException implements Exception {
  const FunctionsApiException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class FunctionsApiClient {
  FunctionsApiClient({http.Client? client}) : _client = client ?? http.Client();

  static final instance = FunctionsApiClient();

  final http.Client _client;

  Future<dynamic> post(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) {
    return _request(
      'POST',
      functionName,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> patch(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) {
    return _request(
      'PATCH',
      functionName,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> delete(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) {
    return _request(
      'DELETE',
      functionName,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> _request(
    String method,
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken() ?? AuthSession.token;

    if (token == null || token.isEmpty) {
      throw const FunctionsApiException(
        'Faça login novamente para concluir esta operação.',
        statusCode: 401,
      );
    }

    final request = http.Request(
      method,
      ApiConfig.endpoint(functionName, queryParameters: queryParameters),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error']?.toString()
          : null;

      throw FunctionsApiException(
        message ?? 'Não foi possível concluir a operação.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }
}
