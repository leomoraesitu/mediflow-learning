import 'package:firebase_auth/firebase_auth.dart';

final class FirebaseAuthTokenProvider {
  final FirebaseAuth _auth;

  const FirebaseAuthTokenProvider(this._auth);

  Future<String?> token({bool forceRefresh = false}) async {
    // `forceRefresh` chega quando o backend recusou a credencial atual com
    // 401. Aqui não se tenta distinguir "token expirado" de "identidade
    // inválida": o SDK renova tokens sozinho antes de expirarem, então um
    // 401 que chega até este ponto significa, na prática, identidade morta.
    // Tentar `getIdToken(true)` primeiro foi descartado na Aula 36 — ele
    // devolveu token sem erro para um usuário que já não existia.
    if (forceRefresh) {
      try {
        // O signOut é obrigatório, não defensivo: `signInAnonymously`
        // devolve o usuário anônimo já autenticado em vez de criar outro,
        // então, sem descartar a sessão inválida antes, a renovação
        // retornaria exatamente a credencial que o backend acabou de
        // recusar — e o evento do outbox ficaria preso para sempre.
        await _auth.signOut();
        final credential = await _auth.signInAnonymously();
        return await credential.user?.getIdToken();
      } on FirebaseAuthException {
        return null;
      }
    }

    final user = _auth.currentUser;
    return user == null ? null : await user.getIdToken();
  }
}
