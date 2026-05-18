import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_session.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
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
