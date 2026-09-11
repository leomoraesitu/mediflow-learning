import 'package:mediflow_mobile/config/auth_gateway.dart';

final class FirebaseAuthTokenProvider {
  final AuthGateway _gateway;

  const FirebaseAuthTokenProvider(this._gateway);

  Future<String?> token({bool forceRefresh = false}) async {
    // Dois gatilhos levam à mesma recuperação, e isso é deliberado.
    //
    // O primeiro é `forceRefresh`, que chega quando o backend recusou a
    // credencial atual com 401. Aqui não se tenta distinguir "token
    // expirado" de "identidade inválida": o SDK renova tokens sozinho antes
    // de expirarem, então um 401 que chega até este ponto significa, na
    // prática, identidade morta. Tentar `getIdToken(true)` primeiro foi
    // descartado na Aula 36 — ele devolveu token sem erro para um usuário
    // que já não existia.
    //
    // O segundo é a falha ao *obter* o token, tratada no `catch` abaixo.
    // Ela não produz 401 nenhum, porque a requisição sequer chega a ser
    // enviada — foi assim que uma credencial do emulador, usada contra o
    // Firebase real, paralisou o checkout em silêncio na Aula 40. A
    // recuperação por 401 era cega para esse caso.
    if (forceRefresh) {
      return await _recoverIdentity();
    }

    try {
      return await _gateway.currentUserToken();
    } on AuthGatewayException {
      return await _recoverIdentity();
    }
  }

  Future<String?> _recoverIdentity() async {
    try {
      // O signOut é obrigatório, não defensivo: `signInAnonymously`
      // devolve o usuário anônimo já autenticado em vez de criar outro,
      // então, sem descartar a sessão inválida antes, a renovação
      // retornaria exatamente a credencial que o backend acabou de
      // recusar — e o evento do outbox ficaria preso para sempre.
      await _gateway.signOut();
      return await _gateway.signInAnonymously();
    } on AuthGatewayException {
      return null;
    }
  }
}
