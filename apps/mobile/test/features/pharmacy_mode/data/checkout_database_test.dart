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
  test('updates an outbox event enqueued twice with the same idempotency key', () async {
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
  });
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
  test('collapses repeated pending states into a single emission', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final expectation = expectLater(
      database.watchHasPendingSync(),
      emitsInOrder([false, true, false]),
    );

    await pumpEventQueue();
    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"attempt":1}',
    );
    await pumpEventQueue();

    // O segundo evento mantém a fila não vazia: o booleano não muda, e o
    // `distinct` precisa suprimir a emissão. Sem ele, a sequência esperada
    // teria um `true` a mais e este teste falharia.
    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-02',
      operationType: 'createCheckout',
      payload: '{"attempt":1}',
    );
    await pumpEventQueue();

    await database.removeOutboxEvent('key-01');
    await pumpEventQueue();
    await database.removeOutboxEvent('key-02');

    await expectation;
  });

  test('emits the pending outbox events whenever the queue changes', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final stream = database.watchPendingOutboxEvents();

    final expectation = expectLater(stream, emitsInOrder([isEmpty, hasLength(1), isEmpty]));

    // Os `pumpEventQueue` não são supérfluos: o stream do Drift dispara a
    // consulta ao ser assinado, mas o resultado chega de forma assíncrona.
    // Sem ceder o controle entre as mutações, a primeira emissão já vem com o
    // evento inserido e o estado vazio inicial nunca é observado — que é
    // justamente a condição de partida da interface, "nada pendente".
    //
    // `pumpEventQueue` drena a fila até o repouso, em vez de apostar num
    // intervalo de relógio como `Future.delayed` faria.
    await pumpEventQueue();
    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"attempt":1}',
    );
    await pumpEventQueue();
    await database.removeOutboxEvent('key-01');

    await expectation;
  });
}
