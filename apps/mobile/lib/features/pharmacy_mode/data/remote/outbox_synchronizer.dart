import 'dart:convert';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';

final class OutboxSynchronizer {
  final CheckoutDatabase _database;
  final CheckoutRepository _checkoutRepository;

  /// Há uma drenagem em andamento.
  bool _draining = false;

  /// Alguém pediu uma drenagem enquanto outra corria.
  bool _requestedAgain = false;

  // Sem `const`: guardar estado custa o construtor constante. A proteção só
  // vale para chamadas na *mesma instância* — duas instâncias teriam sinais
  // independentes, e é por isso que o grafo monta uma só, em
  // `composeDependencies`.
  /// Como no repositório: o dono é lido a cada drenagem. Os gatilhos de
  /// conectividade e retomada disparam independentemente de haver sessão.
  final AuthGateway _authGateway;

  OutboxSynchronizer({
    required this._database,
    required this._checkoutRepository,
    required this._authGateway,
  });

  /// Reenvia o outbox, garantindo que apenas uma drenagem corra por vez.
  ///
  /// Até a Aula 44 havia um único gatilho — a inicialização —, e a
  /// reentrância era impossível por construção. Com conectividade e ciclo de
  /// vida, dois gatilhos podem chegar com milissegundos de diferença: as duas
  /// drenagens leem a mesma fila e reenviam os mesmos eventos. O servidor
  /// sobrevive graças à idempotência da Aula 33, mas o aparelho gasta o dobro
  /// de requisições.
  ///
  /// Um pedido que chega durante uma drenagem não é descartado: ele é
  /// **marcado**, e uma passada nova acontece ao final. Descartar seria
  /// perder justamente o sinal mais valioso — a rede que volta no meio de uma
  /// drenagem travada em timeout é a que teria sucesso.
  Future<void> drain() async {
    if (_draining) {
      _requestedAgain = true;
      return;
    }

    _draining = true;
    try {
      do {
        // Zerado antes da passada: pedidos que chegarem durante *esta*
        // execução precisam provocar a próxima, e não serem consumidos por
        // ela.
        _requestedAgain = false;
        await _drainOnce();
      } while (_requestedAgain);
    } finally {
      // Obrigatório: sem ele, uma exceção que escapasse deixaria o sinal
      // preso em `true` e o sincronizador nunca mais drenaria. `_drainOnce`
      // é total hoje, mas "não deveria lançar" já caiu como premissa neste
      // projeto antes.
      _draining = false;
    }
  }

  Future<void> _drainOnce() async {
    final userId = _authGateway.currentUser?.uid;

    // Sem ninguém autenticado não há fila a drenar. Os gatilhos disparam de
    // qualquer jeito — o que fazer com eles nesse caso é a Aula 56.
    if (userId == null) {
      return;
    }

    late final List<OutboxEvent> pendingEvents;
    try {
      pendingEvents = await _database.readPendingOutboxEvents(userId);
    } catch (_) {
      // Sem fila, não há trabalho: o método retorna. Este `catch` não existe
      // pelo mesmo motivo que o do laço abaixo — ele está aqui para tornar
      // `drain()` total, porque `main()` o executa sem `await`. Num future
      // descartado, o que escapa não derruba o aplicativo de forma visível:
      // vira erro assíncrono não tratado com a interface já em uso.
      //
      // A captura é larga de propósito, e inclui `Error`. O Drift lança
      // `StateError` quando o banco está em estado inválido, e `on Exception`
      // não o pegaria. Capturar largo numa fronteira é diferente de capturar
      // largo no meio do código; aqui a alternativa é o erro não tratado.
      //
      // O preço, aceito conscientemente: um defeito de programação dentro
      // deste bloco desaparece em silêncio. Registrá-lo no Crashlytics, já
      // presente no projeto desde a Aula 30, fecharia essa lacuna e ficou
      // fora do escopo desta aula.
      return;
    }

    for (final event in pendingEvents) {
      if (event.operationType != 'createCheckout') {
        continue;
      }
      try {
        final map = jsonDecode(event.payload) as Map<String, Object?>;
        final session = CheckoutSessionSnapshot.fromMap(map).toDomain();
        await _checkoutRepository.create(session);
      } catch (_) {
        // qualquer falha (rede ou dado corrompido) não deve impedir os outros eventos
      }
    }
  }
}
