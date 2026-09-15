/// Quem está autenticado, na língua do aplicativo.
///
/// O `User` do `firebase_auth` não atravessa esta fronteira: o app lê três
/// campos, e o adaptador é o único arquivo que conhece o pacote.
///
/// `isAnonymous` é carregado explicitamente em vez de derivado de
/// `email == null` — autenticação por telefone produz conta real sem e-mail,
/// e é esta flag que decide a política de recuperação de identidade.
final class AuthUser {
  final String uid;
  final String? email;
  final bool isAnonymous;

  const AuthUser({required this.uid, this.email, required this.isAnonymous});

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.email == email &&
      other.isAnonymous == isAnonymous;

  @override
  int get hashCode => Object.hash(uid, email, isAnonymous);
}
