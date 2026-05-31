class AuthSession {
  AuthSession._();

  static String? uid;
  static String? email;
  static String? token;
  static String? refreshToken;

  static bool get isAuthenticated => token != null;

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

  static void clear() {
    uid = null;
    email = null;
    token = null;
    refreshToken = null;
  }
}
