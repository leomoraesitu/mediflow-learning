import 'dart:convert';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';

final class OutboxCheckoutRepository implements CheckoutRepository {
  final CheckoutRepository _inner;
  final CheckoutDatabase _database;

  const OutboxCheckoutRepository({
    required this._inner,
    required this._database,
  });

  @override
  Future<String> create(CheckoutSession session) async {
    final idempotencyKey = session.idempotencyKey;

    if (idempotencyKey == null) {
      throw StateError(
        'CheckoutSession must have an idempotencyKey before create().',
      );
    }

    final snapshot = CheckoutSessionSnapshot.fromDomain(session);

    final payload = jsonEncode(snapshot.toMap());

    await _database.enqueueOutboxEvent(
      idempotencyKey: idempotencyKey,
      operationType: 'createCheckout',
      payload: payload,
    );

    try {
      final remoteCheckoutId = await _inner.create(session);

      await _database.removeOutboxEvent(idempotencyKey);

      return remoteCheckoutId;
    } catch (_) {
      // Mantém o evento no outbox para retry posterior.
      rethrow;
    }
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) {
    return _inner.getById(remoteCheckoutId);
  }
}
