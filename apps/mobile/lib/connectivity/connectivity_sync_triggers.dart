import 'package:connectivity_plus/connectivity_plus.dart';

/// Traduz mudanças de conectividade em "vale a pena tentar de novo".
///
/// Único arquivo do aplicativo que conhece `connectivity_plus`. O que
/// atravessa esta fronteira é `Stream<void>`, e não `List<ConnectivityResult>`:
/// quem consome não decide nada sobre wi-fi, VPN ou satélite — só precisa
/// saber *quando* tentar, como o `PendingSyncIndicator` só precisa saber *se*
/// há pendência.
///
/// Duas filtragens acontecem aqui, e nenhuma é cosmética.
///
/// A primeira colapsa repetições do **mesmo estado de rede** — a plataforma
/// pode emitir `[wifi]` duas vezes seguidas, e a segunda não traz informação
/// nova. O colapso é pelo conjunto de interfaces, e não por "há rede?": uma
/// troca de wi-fi para dados móveis mantém o booleano em `true`, mas é rota
/// nova e merece uma tentativa. Colapsá-la perderia justamente o gatilho mais
/// valioso — o usuário que abandona um wi-fi quebrado pelo 4G.
///
/// A segunda descarta as quedas: `onConnectivityChanged` emite também quando
/// a conexão some, e tentar reenviar nesse instante é garantia de falha.
///
/// Vale registrar o que este sinal **não** promete: conectividade não é
/// conexão. Um wi-fi com portal cativo reporta `wifi` e não entrega internet
/// alguma. O gatilho é uma dica para tentar, não uma garantia de sucesso —
/// quem lida com a falha continua sendo a retentativa da Aula 39.
final class ConnectivitySyncTriggers {
  final Connectivity _connectivity;

  const ConnectivitySyncTriggers({required this._connectivity});

  ConnectivitySyncTriggers.defaults() : _connectivity = Connectivity();

  Stream<void> get stream => triggersFrom(_connectivity.onConnectivityChanged);

  /// Separado do getter para poder ser exercitado com um stream de mentira:
  /// `Connectivity` é classe concreta do plugin e não tem substituto, mas a
  /// transformação é o que carrega as decisões.
  static Stream<void> triggersFrom(Stream<List<ConnectivityResult>> source) =>
      source.distinct(_sameState).where(_hasNetwork).map((_) {});

  /// Não é `==`: listas em Dart comparam por identidade, então `distinct()`
  /// sem comparador nunca colapsaria nada — emitiria sempre, e o filtro
  /// pareceria existir sem existir.
  static bool _sameState(List<ConnectivityResult> previous, List<ConnectivityResult> current) =>
      previous.toSet().containsAll(current) && current.toSet().containsAll(previous);

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
