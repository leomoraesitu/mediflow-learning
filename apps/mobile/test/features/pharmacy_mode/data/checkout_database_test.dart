import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';

void main() {
  test('starts with no stored checkout session', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final entry = await database.readCheckoutSession('usuario-a');

    expect(entry, isNull);
  });

  test('stores and reads the checkout session payload', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    const payload = '{"status":"collectingMedication"}';

    await database.writeCheckoutSession(userId: 'usuario-a', payload: payload);

    final entry = await database.readCheckoutSession('usuario-a');

    expect(entry?.userId, 'usuario-a');
    expect(entry?.payload, payload);
  });
  test('clears the stored checkout session', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.writeCheckoutSession(
      userId: 'usuario-a',
      payload: '{"status":"collectingMedication"}',
    );

    await database.clearCheckoutSession('usuario-a');

    final entry = await database.readCheckoutSession('usuario-a');

    expect(entry, isNull);
  });
  test('starts with no pending outbox events', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final entries = await database.readPendingOutboxEvents('usuario-a');

    expect(entries, isEmpty);
  });
  test('enqueues and reads a pending outbox event', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.enqueueOutboxEvent(
      userId: 'usuario-a',
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"id":"session-01"}',
    );

    final entries = await database.readPendingOutboxEvents('usuario-a');

    expect(entries.length, 1);
    expect(entries.single.idempotencyKey, 'key-01');
    expect(entries.single.operationType, 'createCheckout');
    expect(entries.single.payload, '{"id":"session-01"}');
  });
  test('updates an outbox event enqueued twice with the same idempotency key', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.enqueueOutboxEvent(
      userId: 'usuario-a',
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"attempt":1}',
    );

    await database.enqueueOutboxEvent(
      userId: 'usuario-a',
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"attempt":2}',
    );

    final entries = await database.readPendingOutboxEvents('usuario-a');

    expect(entries.length, 1);
    expect(entries.single.payload, '{"attempt":2}');
  });
  test('removes an outbox event after confirmation', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.enqueueOutboxEvent(
      userId: 'usuario-a',
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"attempt":1}',
    );

    final entries = await database.readPendingOutboxEvents('usuario-a');

    expect(entries.length, 1);

    await database.removeOutboxEvent(
      userId: 'usuario-a',
      idempotencyKey: entries.single.idempotencyKey,
    );

    final entriesRemoved = await database.readPendingOutboxEvents('usuario-a');

    expect(entriesRemoved.length, 0);
  });
  test('collapses repeated pending states into a single emission', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final expectation = expectLater(
      database.watchHasPendingSync('usuario-a'),
      emitsInOrder([false, true, false]),
    );

    await pumpEventQueue();
    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{"attempt":1}',
      userId: 'usuario-a',
    );
    await pumpEventQueue();

    // O segundo evento é de *outro* usuário, e mesmo assim provoca uma
    // reexecução: o `watch()` do Drift reemite quando a tabela é escrita,
    // independentemente do `where`. A consulta de `usuario-a` devolve o mesmo
    // resultado, e é o `distinct` que impede a emissão duplicada. Sem ele, a
    // sequência esperada teria um `true` a mais.
    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-02',
      operationType: 'createCheckout',
      payload: '{"attempt":1}',
      userId: 'usuario-b',
    );
    await pumpEventQueue();

    await database.removeOutboxEvent(userId: 'usuario-a', idempotencyKey: 'key-01');
    await pumpEventQueue();
    await database.removeOutboxEvent(userId: 'usuario-b', idempotencyKey: 'key-02');

    await expectation;
  });

  test('emits the pending outbox events whenever the queue changes', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final stream = database.watchPendingOutboxEvents('usuario-a');

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
      userId: 'usuario-a',
    );
    await pumpEventQueue();
    await database.removeOutboxEvent(userId: 'usuario-a', idempotencyKey: 'key-01');

    await expectation;
  });

  group('isolamento entre usuários', () {
    test('keeps one checkout session per user', () async {
      final database = CheckoutDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.writeCheckoutSession(userId: 'usuario-a', payload: '{"dono":"a"}');
      await database.writeCheckoutSession(userId: 'usuario-b', payload: '{"dono":"b"}');

      // A sessão deixou de ser linha única: gravar a de B não sobrescreve a
      // de A, como acontecia quando a chave era `id = 1`.
      expect((await database.readCheckoutSession('usuario-a'))?.payload, '{"dono":"a"}');
      expect((await database.readCheckoutSession('usuario-b'))?.payload, '{"dono":"b"}');
    });

    test("does not return another user's pending events", () async {
      final database = CheckoutDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.enqueueOutboxEvent(
        userId: 'usuario-a',
        idempotencyKey: 'key-a',
        operationType: 'createCheckout',
        payload: '{"dono":"a"}',
      );
      await database.enqueueOutboxEvent(
        userId: 'usuario-b',
        idempotencyKey: 'key-b',
        operationType: 'createCheckout',
        payload: '{"dono":"b"}',
      );

      final deA = await database.readPendingOutboxEvents('usuario-a');

      // Sem este teste, o drenador de B reenviaria a compra de A com o token
      // de B — e o backend a aceitaria, porque o dono vem do token.
      expect(deA.map((e) => e.idempotencyKey), ['key-a']);
    });

    test('removing an event of one user leaves the other untouched', () async {
      final database = CheckoutDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      // A mesma chave para os dois donos. Parece impossível — a chave é um
      // uuid v4 —, e é justamente por isso que o filtro por dono em
      // `removeOutboxEvent` parece redundante. Ele não é: sem ele, conhecer a
      // chave basta para apagar o evento alheio.
      await database.enqueueOutboxEvent(
        userId: 'usuario-a',
        idempotencyKey: 'key-a',
        operationType: 'createCheckout',
        payload: '{"dono":"a"}',
      );
      await database.enqueueOutboxEvent(
        userId: 'usuario-b',
        idempotencyKey: 'key-b',
        operationType: 'createCheckout',
        payload: '{"dono":"b"}',
      );

      await database.removeOutboxEvent(userId: 'usuario-a', idempotencyKey: 'key-b');

      expect(await database.readPendingOutboxEvents('usuario-b'), hasLength(1));
      expect(await database.readPendingOutboxEvents('usuario-a'), hasLength(1));
    });

    test('reports pending sync only for the owner', () async {
      final database = CheckoutDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.enqueueOutboxEvent(
        userId: 'usuario-b',
        idempotencyKey: 'key-b',
        operationType: 'createCheckout',
        payload: '{"dono":"b"}',
      );

      await expectLater(database.watchHasPendingSync('usuario-a').first, completion(isFalse));
      await expectLater(database.watchHasPendingSync('usuario-b').first, completion(isTrue));
    });
  });
}
