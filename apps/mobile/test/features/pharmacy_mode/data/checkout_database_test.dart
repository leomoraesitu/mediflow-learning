import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';

void main() {
  test('starts with no stored checkout session', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final entry = await database.readCheckoutSession();

    expect(entry, isNull);
  });

  test('stores and reads the checkout session payload', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    const payload = '{"status":"collectingMedication"}';

    await database.writeCheckoutSession(payload);

    final entry = await database.readCheckoutSession();

    expect(entry?.id, 1);
    expect(entry?.payload, payload);
  });
  test('clears the stored checkout session', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.writeCheckoutSession('{"status":"collectingMedication"}');

    await database.clearCheckoutSession();

    final entry = await database.readCheckoutSession();

    expect(entry, isNull);
  });
  test('starts with no pending outbox events', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final entries = await database.readPendingOutboxEvents();

    expect(entries, isEmpty);
  });
  test('enqueues and reads a pending outbox event', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"id":"session-01"}',
    );

    final entries = await database.readPendingOutboxEvents();

    expect(entries.length, 1);
    expect(entries.single.idempotencyKey, 'key-01');
    expect(entries.single.operationType, 'createCheckout');
    expect(entries.single.payload, '{"id":"session-01"}');
  });
  test(
    'updates an outbox event enqueued twice with the same idempotency key',
    () async {
      final database = CheckoutDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.enqueueOutboxEvent(
        idempotencyKey: 'key-01',
        operationType: 'createCheckout',
        payload: '{"attempt":1}',
      );

      await database.enqueueOutboxEvent(
        idempotencyKey: 'key-01',
        operationType: 'createCheckout',
        payload: '{"attempt":2}',
      );

      final entries = await database.readPendingOutboxEvents();

      expect(entries.length, 1);
      expect(entries.single.payload, '{"attempt":2}');
    },
  );
  test('removes an outbox event after confirmation', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"attempt":1}',
    );

    final entries = await database.readPendingOutboxEvents();

    expect(entries.length, 1);

    await database.removeOutboxEvent(entries.single.idempotencyKey);

    final entriesRemoved = await database.readPendingOutboxEvents();

    expect(entriesRemoved.length, 0);
  });
}
