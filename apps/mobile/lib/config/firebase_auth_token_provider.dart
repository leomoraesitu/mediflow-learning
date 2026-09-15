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

  /// A recuperação depende de *quem* era o usuário, e é por isso que a
  /// identidade precisou atravessar a costura na Aula 53.
  ///
  /// Para uma sessão anônima, criar outra é a resposta certa: não há nada a
  /// perder, e o app volta a funcionar sozinho. Para uma conta, é a resposta
  /// errada — trocaria o usuário em silêncio, e os eventos pendentes no
  /// outbox de quem estava logado passariam a ser enviados sob uma
  /// identidade nova, que o backend aceitaria como dona deles.
  Future<String?> _recoverIdentity() async {
    // Lido antes do `signOut`, e não por estilo: depois dele `currentUser` é
    // sempre `null`, o que cairia no ramo anônimo. A política inteira
    // voltaria a ser a anterior sem nada quebrar na compilação.
    final user = _gateway.currentUser;

    try {
      // O signOut serve a dois propósitos, um por ramo.
      //
      // No anônimo ele é obrigatório, não defensivo: `signInAnonymously`
      // devolve o usuário anônimo já autenticado em vez de criar outro,
      // então, sem descartar a sessão inválida antes, a renovação
      // retornaria exatamente a credencial que o backend acabou de
      // recusar — e o evento do outbox ficaria preso para sempre.
      //
      // Na conta ele é o próprio desfecho: não há entrada depois dele.
      await _gateway.signOut();

      if (user == null || user.isAnonymous) {
        return await _gateway.signInAnonymously();
      }

      // Conta real sem credencial válida: sessão encerrada, e cabe a quem
      // está de fora pedir que o usuário entre de novo.
      //
      // Devolver `null` tem uma consequência que esta aula não resolve: o
      // interceptor deixa a requisição sair *sem* cabeçalho `Authorization`
      // (`checkout_api_client.dart:81-86`), o que garante 401 — e, com os
      // gatilhos do outbox, um laço. É o assunto da Aula 56.
      return null;
    } on AuthGatewayException {
      // Inclui o caso em que o próprio `signOut` falhou. Para o chamador o
      // resultado é o mesmo `null`, mas a sessão local pode continuar de pé:
      // mais um caminho que desemboca no laço descrito acima.
      return null;
    }
  }
}
