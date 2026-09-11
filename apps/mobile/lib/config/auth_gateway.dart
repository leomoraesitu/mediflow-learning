abstract interface class AuthGateway {
  Future<String?> currentUserToken(); // null quando não há usuário
  Future<void> signOut();
  Future<String?> signInAnonymously(); // devolve o token da nova identidade
}

final class AuthGatewayException implements Exception {
  final String code;
  const AuthGatewayException(this.code);
}
