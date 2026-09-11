import 'dart:convert';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';

final class OutboxSynchronizer {
  final CheckoutDatabase _database;
  final CheckoutRepository _checkoutRepository;

  const OutboxSynchronizer({required this._database, required this._checkoutRepository});

  Future<void> drain() async {
    late final List<OutboxEvent> pendingEvents;
    try {
      pendingEvents = await _database.readPendingOutboxEvents();
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
