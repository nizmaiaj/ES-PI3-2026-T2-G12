// Reautentica operações sensíveis, como confirmação de compras.
import 'package:firebase_auth/firebase_auth.dart';

/// Confirma a identidade do usuário atual usando novamente sua senha.
Future<void> reauthenticateCurrentUserWithPassword(String password) async {
  final user = FirebaseAuth.instance.currentUser;
  final email = user?.email;

  if (user == null || email == null || email.isEmpty) {
    throw Exception('Faça login novamente para confirmar sua identidade.');
  }

  final credential = EmailAuthProvider.credential(
    email: email,
    password: password,
  );
  await user.reauthenticateWithCredential(credential);
}
