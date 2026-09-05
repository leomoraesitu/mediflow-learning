import 'package:checkout_domain/checkout_domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';

void main() {
  test('removes the event after a successful creation', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = _FakeCheckoutRepository(createdCheckoutId: 'remote-01');

    final outbox = OutboxCheckoutRepository(
      inner: repository,
      database: database,
    );

    final session = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.paid,
      idempotencyKey: 'key-01',
    );

    await outbox.create(session);

    final entries = await database.readPendingOutboxEvents();

    expect(entries, isEmpty);
  });
  test('keeps the event in the outbox when creation fails', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = _FakeCheckoutRepository(
      createdCheckoutId: 'remote-01',
      createError: Exception('Falha de rede'),
    );

    final outbox = OutboxCheckoutRepository(
      inner: repository,
      database: database,
    );

    final session = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.paid,
      idempotencyKey: 'key-01',
    );

    await expectLater(() => outbox.create(session), throwsA(isA<Exception>()));

    final entries = await database.readPendingOutboxEvents();

    expect(entries.length, 1);
    expect(entries.single.idempotencyKey, 'key-01');
  });

  test('throws when the session has no idempotency key', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = _FakeCheckoutRepository(createdCheckoutId: 'remote-01');

    final outbox = OutboxCheckoutRepository(
      inner: repository,
      database: database,
    );

    final session = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.paid,
    );

    expect(outbox.create(session), throwsA(isA<StateError>()));
  });
}

final class _FakeCheckoutRepository implements CheckoutRepository {
  final String? createdCheckoutId;
  final Object? createError;

  const _FakeCheckoutRepository({this.createdCheckoutId, this.createError});

  @override
  Future<String> create(CheckoutSession session) async {
    final error = createError;
    if (error != null) throw error;
    return createdCheckoutId!;
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) {
    throw UnimplementedError();
  }
}
