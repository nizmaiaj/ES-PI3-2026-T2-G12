import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_session.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    _saveSession(data);
  }

  Future<void> register({
    required String nomeCompleto,
    required String email,
    required String cpf,
    required String telefone,
    required String password,
  }) async {
    final data = await _post('/auth/register', {
      'nomeCompleto': nomeCompleto,
      'email': email,
      'cpf': cpf,
      'telefone': telefone,
      'password': password,
    });

    _saveSession(data);
  }

  Future<String> forgotPassword({required String email}) async {
    final data = await _post('/auth/forgot-password', {'email': email});
    return data['message']?.toString() ??
        'O link de recuperacao de senha foi enviado para o seu e-mail';
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final client = _client ?? http.Client();

    try {
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final responseBody = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          responseBody['error']?.toString() ??
              'Nao foi possivel concluir a operacao',
        );
      }

      return responseBody;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(
        'Nao foi possivel conectar ao servidor. Verifique se o backend esta em execucao.',
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  void _saveSession(Map<String, dynamic> data) {
    final uid = data['uid']?.toString();
    final email = data['email']?.toString();
    final token = data['token']?.toString();

    if (uid == null || email == null || token == null) {
      throw AuthException('Resposta de autenticacao invalida');
    }

    AuthSession.save(
      uid: uid,
      email: email,
      token: token,
      refreshToken: data['refreshToken']?.toString(),
    );
  }
}
