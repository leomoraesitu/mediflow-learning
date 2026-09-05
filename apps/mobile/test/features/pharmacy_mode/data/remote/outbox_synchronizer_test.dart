import 'dart:convert';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_synchronizer.dart';

void main() {
  test('skips events with an unknown operation type', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final session = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: 'key-01',
    );

    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-01',
      operationType: 'unknownOperation',
      payload: jsonEncode(CheckoutSessionSnapshot.fromDomain(session).toMap()),
    );

    final repository = _FakeCheckoutRepository(createdCheckoutId: 'remote-01');

    final outboxRepo = OutboxCheckoutRepository(
      inner: repository,
      database: database,
    );

    final synchronizer = OutboxSynchronizer(
      database: database,
      checkoutRepository: outboxRepo,
    );

    await synchronizer.drain();

    final pendingEvents = await database.readPendingOutboxEvents();

    expect(pendingEvents.length, 1);
  });

  test('resends a pending event and removes it on success', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final session = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: 'key-01',
    );

    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: jsonEncode(CheckoutSessionSnapshot.fromDomain(session).toMap()),
    );

    final repository = _FakeCheckoutRepository(createdCheckoutId: 'remote-01');

    final outboxRepo = OutboxCheckoutRepository(
      inner: repository,
      database: database,
    );

    final synchronizer = OutboxSynchronizer(
      database: database,
      checkoutRepository: outboxRepo,
    );

    await synchronizer.drain();

    final pendingEvents = await database.readPendingOutboxEvents();

    expect(pendingEvents, isEmpty);
  });
  test('keeps a pending event in the outbox when resending fails', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final session = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: 'key-01',
    );

    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: jsonEncode(CheckoutSessionSnapshot.fromDomain(session).toMap()),
    );

    final repository = _FakeCheckoutRepository(
      createdCheckoutId: 'remote-01',
      failingIdempotencyKeys: {'key-01'},
    );

    final outboxRepo = OutboxCheckoutRepository(
      inner: repository,
      database: database,
    );

    final synchronizer = OutboxSynchronizer(
      database: database,
      checkoutRepository: outboxRepo,
    );

    await synchronizer.drain();

    final pendingEvents = await database.readPendingOutboxEvents();

    expect(pendingEvents.length, 1);
    expect(pendingEvents.single.idempotencyKey, 'key-01');
  });
  test('continues processing remaining events after one fails', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final failingSession = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: 'key-fail',
    );

    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-fail',
      operationType: 'createCheckout',
      payload: jsonEncode(
        CheckoutSessionSnapshot.fromDomain(failingSession).toMap(),
      ),
    );
    final succeedingSession = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: 'key-ok',
    );

    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-ok',
      operationType: 'createCheckout',
      payload: jsonEncode(
        CheckoutSessionSnapshot.fromDomain(succeedingSession).toMap(),
      ),
    );

    final repository = _FakeCheckoutRepository(
      createdCheckoutId: 'remote-01',
      failingIdempotencyKeys: {'key-fail'},
    );

    final outboxRepo = OutboxCheckoutRepository(
      inner: repository,
      database: database,
    );

    final synchronizer = OutboxSynchronizer(
      database: database,
      checkoutRepository: outboxRepo,
    );

    await synchronizer.drain();

    final pendingEvents = await database.readPendingOutboxEvents();

    expect(pendingEvents.length, 1);
    expect(pendingEvents.single.idempotencyKey, 'key-fail');
  });
}

final class _FakeCheckoutRepository implements CheckoutRepository {
  final String createdCheckoutId;
  final Set<String> failingIdempotencyKeys;

  const _FakeCheckoutRepository({
    required this.createdCheckoutId,
    this.failingIdempotencyKeys = const {},
  });

  @override
  Future<String> create(CheckoutSession session) async {
    if (failingIdempotencyKeys.contains(session.idempotencyKey)) {
      throw Exception('Falha de conexão');
    }
    return createdCheckoutId;
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) {
    throw UnimplementedError();
  }
}
