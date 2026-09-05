import 'dart:convert';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';

final class OutboxSynchronizer {
  final CheckoutDatabase _database;
  final CheckoutRepository _checkoutRepository;

  const OutboxSynchronizer({
    required this._database,
    required this._checkoutRepository,
  });

  Future<void> drain() async {
    final pendingEvents = await _database.readPendingOutboxEvents();

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
