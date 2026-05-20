import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_session.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef SmsCodeResolver =
    Future<String?> Function(String verificationId, int? resendToken);

class AuthMfaRequiredException extends AuthException {
  AuthMfaRequiredException({required this.challenge})
    : super('Confirme o código enviado por SMS para concluir o login.');

  final AuthMfaChallenge challenge;
}

class AuthMfaChallenge {
  const AuthMfaChallenge({required this.resolver, required this.hint});

  final MultiFactorResolver resolver;
  final PhoneMultiFactorInfo hint;

  String get phoneNumber => hint.phoneNumber;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(createdUser.uid);
      final walletRef = _firestore.collection('wallets').doc(createdUser.uid);

      batch.set(userRef, {
        'uid': createdUser.uid,
        'nomeCompleto': nomeCompleto,
        'email': email,
        'cpf': cpf,
        'telefone': telefone,
        'mfaHabilitado': false,
        'mfaSecret': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(walletRef, {
        'userId': createdUser.uid,
        'saldoReais': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _saveSession(createdUser);
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    } on FirebaseException catch (error) {
      await createdUser?.delete().catchError((_) {});
      throw AuthException(_firestoreErrorMessage(error));
    } catch (_) {
      await createdUser?.delete().catchError((_) {});
      throw AuthException('Não foi possível criar a conta. Tente novamente.');
    }
  }

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

  Future<void> logout() async {
    await _auth.signOut();
    AuthSession.clear();
  }

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

  AuthMfaChallenge? _phoneChallenge(MultiFactorResolver resolver) {
    for (final hint in resolver.hints) {
      if (hint is PhoneMultiFactorInfo) {
        return AuthMfaChallenge(resolver: resolver, hint: hint);
      }
    }
    return null;
  }

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

  Future<void> _sendEmailVerificationIfPossible(User user) async {
    try {
      await user.sendEmailVerification();
    } catch (_) {}
  }

  AuthException _asAuthException(Object error) {
    if (error is AuthException) return error;
    if (error is FirebaseAuthException) {
      return AuthException(_authErrorMessage(error));
    }
    return AuthException('Não foi possível concluir a verificação.');
  }

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

  String _firestoreErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Sem permissão para salvar os dados no Firestore. Verifique as regras do Firebase.';
      case 'unavailable':
        return 'Firestore indisponível no momento. Tente novamente.';
      default:
        return error.message ??
            'Não foi possível salvar os dados do usuário no Firestore.';
    }
  }
}
