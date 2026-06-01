// Encapsula autenticação Firebase e os fluxos de segundo fator por SMS.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_session.dart';
import 'functions_api_client.dart';

/// Erro amigável que pode ser exibido diretamente pelas telas de autenticação.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Callback usado quando o Firebase envia um código e a UI precisa solicitá-lo.
typedef SmsCodeResolver =
    Future<String?> Function(String verificationId, int? resendToken);

/// Sinaliza ao login que ainda falta concluir o desafio MFA recebido.
class AuthMfaRequiredException extends AuthException {
  AuthMfaRequiredException({required this.challenge})
    : super('Confirme o código enviado por SMS para concluir o login.');

  final AuthMfaChallenge challenge;
}

/// Dados necessários para concluir um login protegido por telefone.
class AuthMfaChallenge {
  const AuthMfaChallenge({required this.resolver, required this.hint});

  final MultiFactorResolver resolver;
  final PhoneMultiFactorInfo hint;

  String get phoneNumber => hint.phoneNumber;
}

/// Serviço central de cadastro, login, logout, recuperação de senha e MFA.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Autentica por e-mail e senha e converte um eventual MFA em desafio para a UI.
  Future<void> login({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _saveSession(credential.user);
    } on FirebaseAuthMultiFactorException catch (error) {
      final challenge = _phoneChallenge(error.resolver);
      if (challenge == null) {
        throw AuthException(
          'Esta conta exige uma verificação em duas etapas não suportada pelo app.',
        );
      }
      throw AuthMfaRequiredException(challenge: challenge);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    } catch (_) {
      throw AuthException('Não foi possível fazer login. Tente novamente.');
    }
  }

  /// Cria a conta no Auth, inicializa seu perfil pelo backend e salva a sessão.
  Future<void> register({
    required String nomeCompleto,
    required String email,
    required String cpf,
    required String telefone,
    required String password,
  }) async {
    User? createdUser;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = credential.user;

      if (createdUser == null) {
        throw AuthException('Não foi possível criar a conta.');
      }

      await createdUser.updateDisplayName(nomeCompleto);

      // O perfil e a carteira dependem de regras transacionais implementadas
      // pelo backend, por isso não são escritos diretamente pelo aplicativo.
      await FunctionsApiClient.instance.post(
        'usersInitializeProfile',
        body: {
          'nomeCompleto': nomeCompleto,
          'email': email,
          'cpf': cpf,
          'telefone': telefone,
        },
      );
      await _saveSession(createdUser);
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    } on FunctionsApiException catch (error) {
      await createdUser?.delete().catchError((_) {});
      throw AuthException(error.message);
    } catch (_) {
      await createdUser?.delete().catchError((_) {});
      throw AuthException('Não foi possível criar a conta. Tente novamente.');
    }
  }

  /// Solicita o envio do link padrão de recuperação do Firebase Auth.
  Future<String> forgotPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return 'O link de recuperação de senha foi enviado para o seu e-mail';
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    } catch (_) {
      throw AuthException('Não foi possível enviar o e-mail de recuperação.');
    }
  }

  /// Encerra a sessão no Firebase e limpa o fallback local.
  Future<void> logout() async {
    await _auth.signOut();
    AuthSession.clear();
  }

  /// Conclui o login depois que o usuário informa o código do segundo fator.
  Future<void> resolveSmsMfaSignIn({
    required AuthMfaChallenge challenge,
    required SmsCodeResolver smsCodeResolver,
  }) async {
    final credential = await _verifyPhoneNumberForCredential(
      phoneNumber: challenge.phoneNumber,
      smsCodeResolver: smsCodeResolver,
      cancelledMessage: 'Verificação em duas etapas cancelada.',
      startVerification:
          ({
            required verificationCompleted,
            required verificationFailed,
            required codeSent,
            required codeAutoRetrievalTimeout,
          }) {
            return _auth.verifyPhoneNumber(
              multiFactorSession: challenge.resolver.session,
              multiFactorInfo: challenge.hint,
              verificationCompleted: verificationCompleted,
              verificationFailed: verificationFailed,
              codeSent: codeSent,
              codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
            );
          },
    );

    try {
      final userCredential = await challenge.resolver.resolveSignIn(
        PhoneMultiFactorGenerator.getAssertion(credential),
      );
      await _saveSession(userCredential.user);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    } catch (_) {
      throw AuthException('Não foi possível concluir a verificação.');
    }
  }

  /// Cadastra o telefone como segundo fator da conta atual.
  Future<void> enrollSmsMfa({
    required String phoneNumber,
    required SmsCodeResolver smsCodeResolver,
  }) async {
    final user = await _currentUserForMfa();

    if (!user.emailVerified) {
      await _sendEmailVerificationIfPossible(user);
      throw AuthException(
        'Antes de ativar o 2FA, confirme seu e-mail. Enviamos um link de verificação para sua caixa de entrada.',
      );
    }

    final normalizedPhoneNumber = normalizePhoneNumberForSmsMfa(phoneNumber);
    final existingPhoneFactor = await _firstEnrolledPhoneFactor(user);

    if (existingPhoneFactor != null) {
      return;
    }

    final session = await user.multiFactor.getSession();
    final credential = await _verifyPhoneNumberForCredential(
      phoneNumber: normalizedPhoneNumber,
      smsCodeResolver: smsCodeResolver,
      cancelledMessage: 'Ativação da verificação em duas etapas cancelada.',
      startVerification:
          ({
            required verificationCompleted,
            required verificationFailed,
            required codeSent,
            required codeAutoRetrievalTimeout,
          }) {
            return _auth.verifyPhoneNumber(
              phoneNumber: normalizedPhoneNumber,
              multiFactorSession: session,
              verificationCompleted: verificationCompleted,
              verificationFailed: verificationFailed,
              codeSent: codeSent,
              codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
            );
          },
    );

    try {
      await user.multiFactor.enroll(
        PhoneMultiFactorGenerator.getAssertion(credential),
        displayName: 'Telefone',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    } catch (_) {
      throw AuthException(
        'Não foi possível ativar a verificação em duas etapas.',
      );
    }
  }

  /// Remove todos os fatores de telefone cadastrados na conta atual.
  Future<void> unenrollSmsMfa() async {
    final user = await _currentUserForMfa();
    final factors = await user.multiFactor.getEnrolledFactors();
    final phoneFactors = factors.whereType<PhoneMultiFactorInfo>().toList();

    for (final factor in phoneFactors) {
      try {
        await user.multiFactor.unenroll(multiFactorInfo: factor);
      } on FirebaseAuthException catch (error) {
        throw AuthException(_authErrorMessage(error));
      } catch (_) {
        throw AuthException(
          'Não foi possível desativar a verificação em duas etapas.',
        );
      }
    }
  }

  /// Espelha no perfil do Firestore o estado configurado no Firebase Auth.
  Future<void> updateMfaMetadata({
    required bool enabled,
    String? phoneNumber,
  }) async {
    try {
      await FunctionsApiClient.instance.patch(
        'usersUpdateMfaMetadata',
        body: {'habilitado': enabled, 'telefone': phoneNumber},
      );
    } on FunctionsApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  /// Normaliza números brasileiros para o formato E.164 exigido pelo Firebase.
  static String normalizePhoneNumberForSmsMfa(String value) {
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      throw AuthException('Cadastre um telefone antes de ativar o 2FA.');
    }

    if (trimmed.startsWith('+')) {
      if (digits.length < 10 || digits.length > 15) {
        throw AuthException('Telefone inválido para envio de SMS.');
      }
      return '+$digits';
    }

    if (digits.startsWith('55') &&
        (digits.length == 12 || digits.length == 13)) {
      return '+$digits';
    }

    if (digits.length == 10 || digits.length == 11) {
      return '+55$digits';
    }

    throw AuthException(
      'Telefone inválido. Informe DDD e número para ativar o 2FA.',
    );
  }

  /// Mantém um fallback em memória do usuário autenticado.
  Future<void> _saveSession(User? user) async {
    if (user == null || user.email == null) {
      throw AuthException('Resposta de autenticação inválida');
    }

    final token = await user.getIdToken();

    if (token == null) {
      throw AuthException('Resposta de autenticação inválida');
    }

    AuthSession.save(
      uid: user.uid,
      email: user.email!,
      token: token,
      refreshToken: user.refreshToken,
    );
  }

  /// Seleciona o primeiro fator de telefone oferecido pelo Firebase no login.
  AuthMfaChallenge? _phoneChallenge(MultiFactorResolver resolver) {
    for (final hint in resolver.hints) {
      if (hint is PhoneMultiFactorInfo) {
        return AuthMfaChallenge(resolver: resolver, hint: hint);
      }
    }
    return null;
  }

  /// Recarrega o usuário antes de alterar MFA para evitar estado desatualizado.
  Future<User> _currentUserForMfa() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw AuthException('Faça login novamente para alterar o 2FA.');
    }

    try {
      await user.reload();
      return _auth.currentUser ?? user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    }
  }

  /// Evita cadastrar um telefone adicional quando a conta já possui um.
  Future<PhoneMultiFactorInfo?> _firstEnrolledPhoneFactor(User user) async {
    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      for (final factor in factors) {
        if (factor is PhoneMultiFactorInfo) {
          return factor;
        }
      }
      return null;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    }
  }

  /// Converte a API de callbacks do Firebase em um `Future` de credencial.
  ///
  /// O callback recebido abre o diálogo da UI quando o preenchimento automático
  /// do SMS não estiver disponível.
  Future<PhoneAuthCredential> _verifyPhoneNumberForCredential({
    required String phoneNumber,
    required SmsCodeResolver smsCodeResolver,
    required String cancelledMessage,
    required Future<void> Function({
      required PhoneVerificationCompleted verificationCompleted,
      required PhoneVerificationFailed verificationFailed,
      required PhoneCodeSent codeSent,
      required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    })
    startVerification,
  }) async {
    final completer = Completer<PhoneAuthCredential>();

    void completeError(Object error, [StackTrace? stackTrace]) {
      if (completer.isCompleted) return;
      completer.completeError(_asAuthException(error), stackTrace);
    }

    void completeCredential(PhoneAuthCredential credential) {
      if (completer.isCompleted) return;
      completer.complete(credential);
    }

    try {
      await startVerification(
        verificationCompleted: completeCredential,
        verificationFailed: (error) => completeError(error),
        codeSent: (verificationId, resendToken) async {
          try {
            final smsCode = await smsCodeResolver(verificationId, resendToken);

            if (smsCode == null || smsCode.trim().isEmpty) {
              throw AuthException(cancelledMessage);
            }

            completeCredential(
              PhoneAuthProvider.credential(
                verificationId: verificationId,
                smsCode: smsCode.trim(),
              ),
            );
          } catch (error, stackTrace) {
            completeError(error, stackTrace);
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (error, stackTrace) {
      completeError(error, stackTrace);
    }

    return completer.future;
  }

  /// Tenta disparar a verificação sem mascarar o erro principal do fluxo de MFA.
  Future<void> _sendEmailVerificationIfPossible(User user) async {
    try {
      await user.sendEmailVerification();
    } catch (_) {}
  }

  /// Uniformiza exceções internas para mensagens compreensíveis pelas telas.
  AuthException _asAuthException(Object error) {
    if (error is AuthException) return error;
    if (error is FirebaseAuthException) {
      return AuthException(_authErrorMessage(error));
    }
    return AuthException('Não foi possível concluir a verificação.');
  }

  /// Traduz códigos técnicos do Firebase em mensagens de interface.
  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado';
      case 'invalid-email':
        return 'Formato de e-mail inválido';
      case 'operation-not-allowed':
        return 'Login por e-mail e senha não está habilitado no Firebase';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres';
      case 'user-disabled':
        return 'Esta conta foi desativada';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha inválidos';
      case 'network-request-failed':
        return 'Não foi possível conectar ao Firebase. Verifique sua internet.';
      case 'invalid-phone-number':
        return 'Telefone inválido para envio de SMS.';
      case 'invalid-verification-code':
        return 'Código de verificação inválido.';
      case 'invalid-verification-id':
        return 'Sessão de verificação inválida. Tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas em pouco tempo. Tente novamente mais tarde.';
      case 'quota-exceeded':
        return 'Limite de envio de SMS excedido no Firebase.';
      case 'requires-recent-login':
        return 'Por segurança, saia e entre novamente antes de alterar o 2FA.';
      case 'second-factor-already-in-use':
        return 'Este telefone já está cadastrado como segundo fator.';
      case 'maximum-second-factor-count-exceeded':
        return 'Esta conta já atingiu o limite de fatores cadastrados.';
      case 'unsupported-first-factor':
        return 'Este tipo de login não permite verificação em duas etapas por SMS.';
      case 'missing-multi-factor-session':
        return 'Sessão de verificação expirada. Tente novamente.';
      default:
        return error.message ?? 'Não foi possível concluir a operação';
    }
  }
}
