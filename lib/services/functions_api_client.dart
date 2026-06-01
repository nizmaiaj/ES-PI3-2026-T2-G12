// Cliente HTTP compartilhado para invocar as Cloud Functions autenticadas.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_session.dart';

/// Erro de comunicação com a API que preserva a mensagem e o status HTTP.
class FunctionsApiException implements Exception {
  const FunctionsApiException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Envia requisições autenticadas às Functions e normaliza respostas de erro.
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

  /// Executa a requisição comum a POST, PATCH e DELETE.
  Future<dynamic> _request(
    String method,
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    // Prefere um token atualizado do Firebase Auth e usa a sessão local apenas
    // como fallback para fluxos legados.
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

    late final http.Response response;

    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw const FunctionsApiException(
        'Não foi possível conectar ao backend. Verifique sua conexão e tente novamente.',
        statusCode: 0,
      );
    }

    // Nem toda falha de infraestrutura devolve JSON válido.
    dynamic decoded;

    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error']?.toString()
          : null;

      throw FunctionsApiException(
        message ??
            (response.statusCode == 403
                ? 'O backend recusou esta operação. Tente novamente após atualizar o aplicativo.'
                : 'Não foi possível concluir a operação.'),
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }
}
