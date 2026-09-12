import 'dart:async';
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

    final outboxRepo = OutboxCheckoutRepository(inner: repository, database: database);

    final synchronizer = OutboxSynchronizer(database: database, checkoutRepository: outboxRepo);

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

    final outboxRepo = OutboxCheckoutRepository(inner: repository, database: database);

    final synchronizer = OutboxSynchronizer(database: database, checkoutRepository: outboxRepo);

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

    final outboxRepo = OutboxCheckoutRepository(inner: repository, database: database);

    final synchronizer = OutboxSynchronizer(database: database, checkoutRepository: outboxRepo);

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
      payload: jsonEncode(CheckoutSessionSnapshot.fromDomain(failingSession).toMap()),
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
      payload: jsonEncode(CheckoutSessionSnapshot.fromDomain(succeedingSession).toMap()),
    );

    final repository = _FakeCheckoutRepository(
      createdCheckoutId: 'remote-01',
      failingIdempotencyKeys: {'key-fail'},
    );

    final outboxRepo = OutboxCheckoutRepository(inner: repository, database: database);

    final synchronizer = OutboxSynchronizer(database: database, checkoutRepository: outboxRepo);

    await synchronizer.drain();

    final pendingEvents = await database.readPendingOutboxEvents();

    expect(pendingEvents.length, 1);
    expect(pendingEvents.single.idempotencyKey, 'key-fail');
  });
  test('completes without throwing when reading the outbox fails', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final pendingSession = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: 'key-pending',
    );

    // Este evento nunca chega a ser processado — a leitura da fila falha
    // antes. Ele está aqui por dois motivos: descreve o cenário real (há uma
    // compra pendente que o aplicativo sequer consegue enxergar) e, sobretudo,
    // é o que abre a conexão do Drift. O banco abre preguiçosamente, então
    // `close()` num banco nunca usado não fecha nada — a consulta seguinte
    // reabriria e o teste passaria sem exercitar falha alguma.
    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-pending',
      operationType: 'createCheckout',
      payload: jsonEncode(CheckoutSessionSnapshot.fromDomain(pendingSession).toMap()),
    );

    final repository = _FakeCheckoutRepository(createdCheckoutId: 'remote-01');

    final outboxRepo = OutboxCheckoutRepository(inner: repository, database: database);

    final synchronizer = OutboxSynchronizer(database: database, checkoutRepository: outboxRepo);

    await database.close();

    await expectLater(synchronizer.drain(), completes);
  });
  test('drains again when a request arrives while draining', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    CheckoutSession sessionFor(String key) => CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: key,
    );

    Future<void> enqueue(String key) => database.enqueueOutboxEvent(
      idempotencyKey: key,
      operationType: 'createCheckout',
      payload: jsonEncode(CheckoutSessionSnapshot.fromDomain(sessionFor(key)).toMap()),
    );

    await enqueue('key-01');

    // Segura a criação para manter a primeira drenagem em andamento — é a
    // janela em que a rede volta no meio de um envio travado em timeout.
    final liberar = Completer<void>();
    final repository = _FakeCheckoutRepository(
      createdCheckoutId: 'remote-01',
      holdUntil: liberar.future,
    );

    final outboxRepo = OutboxCheckoutRepository(inner: repository, database: database);
    final synchronizer = OutboxSynchronizer(database: database, checkoutRepository: outboxRepo);

    final primeira = synchronizer.drain();
    await pumpEventQueue();

    // Um evento novo entra na fila *depois* que a primeira drenagem já leu a
    // lista: ela não o verá. É esse evento que torna a segunda passada
    // observável — sem ele, a passada extra acontece e não deixa rastro.
    await enqueue('key-02');
    final segunda = synchronizer.drain();
    await pumpEventQueue();

    liberar.complete();
    await Future.wait([primeira, segunda]);

    // Os dois foram enviados, cada um uma vez. Com a estratégia de "ignorar",
    // o segundo pedido seria descartado, `key-02` nunca sairia e continuaria
    // na fila — exatamente o sinal perdido que motivou a escolha.
    expect(
      repository.createdSessions.map((s) => s.idempotencyKey),
      containsAll(<String>['key-01', 'key-02']),
    );
    expect(repository.createdSessions, hasLength(2));
    expect(await database.readPendingOutboxEvents(), isEmpty);
  });

  test('drains again after a previous drain finished', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    Future<void> enqueue(String key) => database.enqueueOutboxEvent(
      idempotencyKey: key,
      operationType: 'createCheckout',
      payload: jsonEncode(
        CheckoutSessionSnapshot.fromDomain(
          CheckoutSession(
            id: 'session-id',
            availableBalanceInCents: 1000,
            prescription: null,
            medications: [],
            status: CheckoutStatus.creatingPayment,
            idempotencyKey: key,
          ),
        ).toMap(),
      ),
    );

    final repository = _FakeCheckoutRepository(createdCheckoutId: 'remote-01');
    final outboxRepo = OutboxCheckoutRepository(inner: repository, database: database);
    final synchronizer = OutboxSynchronizer(database: database, checkoutRepository: outboxRepo);

    await enqueue('key-01');
    await synchronizer.drain();

    // A segunda drenagem é uma execução nova, muito depois da primeira: é o
    // caso comum de dois gatilhos separados no tempo. Ela só funciona se o
    // sinal de "em andamento" tiver sido liberado ao final da anterior — e é
    // este caso que guarda o `finally`, não os testes de concorrência.
    await enqueue('key-02');
    await synchronizer.drain();

    expect(
      repository.createdSessions.map((s) => s.idempotencyKey),
      containsAll(<String>['key-01', 'key-02']),
    );
    expect(await database.readPendingOutboxEvents(), isEmpty);
  });

  test('resends each event once when drained concurrently', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final pendingSession = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: 'key-pending',
    );

    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-pending',
      operationType: 'createCheckout',
      payload: jsonEncode(CheckoutSessionSnapshot.fromDomain(pendingSession).toMap()),
    );

    final repository = _FakeCheckoutRepository(createdCheckoutId: 'remote-01');

    final outboxRepo = OutboxCheckoutRepository(inner: repository, database: database);

    final synchronizer = OutboxSynchronizer(database: database, checkoutRepository: outboxRepo);

    // Sem `await` entre as duas: é isso que simula os gatilhos chegando
    // juntos — conectividade e retomada do aplicativo, por exemplo.
    await Future.wait([synchronizer.drain(), synchronizer.drain()]);

    // A fila vazia não prova nada sozinha: ficaria vazia com um reenvio ou
    // com dois, porque remover a mesma chave duas vezes não falha. O que
    // distingue é quantas vezes o repositório foi acionado.
    expect(repository.createdSessions, hasLength(1));
    expect(await database.readPendingOutboxEvents(), isEmpty);
  });
}

final class _FakeCheckoutRepository implements CheckoutRepository {
  final String createdCheckoutId;
  final Set<String> failingIdempotencyKeys;

  /// Quando informado, `create` só responde depois que este future completa —
  /// mantendo uma drenagem em andamento pelo tempo que o teste quiser.
  final Future<void>? holdUntil;

  /// Registra o que chegou, e não apenas quantas vezes: o estado final do
  /// outbox é idempotente por construção, então só o caminho percorrido
  /// distingue um reenvio de dois.
  ///
  /// O registro acontece antes da checagem de falha porque a pergunta é "o
  /// repositório foi acionado?", e uma tentativa que falhou também gastou
  /// uma requisição.
  final List<CheckoutSession> createdSessions = [];

  _FakeCheckoutRepository({
    required this.createdCheckoutId,
    this.failingIdempotencyKeys = const {},
    this.holdUntil,
  });

  @override
  Future<String> create(CheckoutSession session) async {
    createdSessions.add(session);

    if (holdUntil != null) {
      await holdUntil;
    }

    if (failingIdempotencyKeys.contains(session.idempotencyKey)) {
      throw Exception('Falha de conexão');
    }
    return createdCheckoutId;
  }

  // Nenhum teste deste arquivo lê um checkout: `drain` só chama `create`.
  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) {
    throw UnimplementedError();
  }
}
