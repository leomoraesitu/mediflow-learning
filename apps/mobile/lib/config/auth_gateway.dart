import 'package:mediflow_mobile/config/auth_user.dart';

/// A costura de autenticação: o que o aplicativo precisa saber, sem dizer
/// quem responde. Este arquivo não importa nenhum pacote de plataforma.
///
/// Todo método aqui sinaliza falha com [AuthGatewayException], e o `code`
/// dela é parte do contrato, não detalhe do adaptador: a tela de login
/// escolhe a mensagem a partir dele. Por isso a tradução para texto de
/// usuário acontece na apresentação, e não aqui nem no adaptador.
abstract interface class AuthGateway {
  Future<String?> currentUserToken(); // null quando não há usuário
  Future<void> signOut();
  Future<String?> signInAnonymously(); // devolve o token da nova identidade

  /// Síncrono de propósito: a política de recuperação de identidade precisa
  /// saber quem era o usuário *antes* de encerrar a sessão, e uma leitura
  /// assíncrona abriria janela para o estado mudar entre decidir e agir.
  AuthUser? get currentUser;

  Stream<AuthUser?> authStateChanges();
  Future<AuthUser> signInWithEmail({required String email, required String password});
  Future<AuthUser> registerWithEmail({required String email, required String password});
}

final class AuthGatewayException implements Exception {
  final String code;
  const AuthGatewayException(this.code);
}
