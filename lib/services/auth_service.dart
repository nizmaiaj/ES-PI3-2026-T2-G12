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
      throw AuthException('Nao foi possivel fazer login. Tente novamente.');
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
        throw AuthException('Nao foi possivel criar a conta.');
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
        'saldoReais': 1000.0,
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
      throw AuthException('Nao foi possivel criar a conta. Tente novamente.');
    }
  }

  Future<String> forgotPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return 'O link de recuperacao de senha foi enviado para o seu e-mail';
    } on FirebaseAuthException catch (error) {
      throw AuthException(_authErrorMessage(error));
    } catch (_) {
      throw AuthException('Nao foi possivel enviar o e-mail de recuperacao.');
    }
  }

  Future<void> _saveSession(User? user) async {
    if (user == null || user.email == null) {
      throw AuthException('Resposta de autenticacao invalida');
    }

    final token = await user.getIdToken();

    if (token == null) {
      throw AuthException('Resposta de autenticacao invalida');
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
        return 'Este e-mail ja esta cadastrado';
      case 'invalid-email':
        return 'Formato de e-mail invalido';
      case 'operation-not-allowed':
        return 'Login por e-mail e senha nao esta habilitado no Firebase';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres';
      case 'user-disabled':
        return 'Esta conta foi desativada';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha invalidos';
      case 'network-request-failed':
        return 'Nao foi possivel conectar ao Firebase. Verifique sua internet.';
      default:
        return error.message ?? 'Nao foi possivel concluir a operacao';
    }
  }

  String _firestoreErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Sem permissao para salvar os dados no Firestore. Verifique as regras do Firebase.';
      case 'unavailable':
        return 'Firestore indisponivel no momento. Tente novamente.';
      default:
        return error.message ??
            'Nao foi possivel salvar os dados do usuario no Firestore.';
    }
  }
}
