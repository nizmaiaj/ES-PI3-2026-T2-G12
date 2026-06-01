/// Fallback em memória para dados da sessão autenticada.
///
/// O Firebase Auth continua sendo a fonte principal. Esta classe atende fluxos
/// em que uma tela precisa acessar rapidamente o UID ou o token já obtido.
class AuthSession {
  AuthSession._();

  static String? uid;
  static String? email;
  static String? token;
  static String? refreshToken;

  static bool get isAuthenticated => token != null;

  /// Atualiza todos os campos mantidos durante a sessão atual.
  static void save({
    required String uid,
    required String email,
    required String token,
    String? refreshToken,
  }) {
    AuthSession.uid = uid;
    AuthSession.email = email;
    AuthSession.token = token;
    AuthSession.refreshToken = refreshToken;
  }

  /// Remove credenciais locais ao sair da conta.
  static void clear() {
    uid = null;
    email = null;
    token = null;
    refreshToken = null;
  }
}
