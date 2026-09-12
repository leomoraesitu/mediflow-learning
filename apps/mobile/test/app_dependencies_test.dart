import 'dart:async';
import 'dart:convert';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/app_dependencies.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/observability/performance_tracer.dart';

import 'features/pharmacy_mode/data/remote/fake_http_client_adapter.dart';

void main() {
  late CheckoutDatabase database;
  late FakeHttpClientAdapter fakeAdapter;
  late AppDependencies dependencies;
  late StreamController<void> syncTriggers;

  setUp(() {
    database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    syncTriggers = StreamController<void>.broadcast();
    addTearDown(syncTriggers.close);

    fakeAdapter = FakeHttpClientAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))..httpClientAdapter = fakeAdapter;
    addTearDown(() => dio.close(force: true));

    dependencies = composeDependencies(
      database: database,
      apiClient: CheckoutApiClient.withDio(
        dio,
        tokenProvider: ({bool forceRefresh = false}) async => 'test-token',
        retryDelays: const [],
      ),
      settings: const StaticOperationalSettings(),
      tracer: _FakePerformanceTracer(),
      syncTriggers: syncTriggers.stream,
    );
  });

  /// Enfileira um evento cuja linha e cujo payload carregam a **mesma** chave.
  ///
  /// O `drain` recria a sessão a partir do JSON e remove pela chave dela, não
  /// pela da linha. Divergir deixa a linha órfã na fila, e o teste falha com
  /// "fila não esvaziou" sem dizer nada sobre a causa.
  Future<void> enqueue(String key) => database.enqueueOutboxEvent(
    idempotencyKey: key,
    operationType: 'createCheckout',
    payload: jsonEncode(
      CheckoutSessionSnapshot.fromDomain(
        CheckoutSession(
          id: 'session-id',
          availableBalanceInCents: 1000,
          prescription: null,
          medications: const [],
          status: CheckoutStatus.creatingPayment,
          idempotencyKey: key,
        ),
      ).toMap(),
    ),
  );

  CheckoutSession session() => CheckoutSession(
    id: 'session-id',
    availableBalanceInCents: 1000,
    prescription: null,
    medications: const [],
    status: CheckoutStatus.creatingPayment,
    idempotencyKey: 'key-01',
  );

  test('routes checkout creation through the outbox', () async {
    // A resposta é um erro de propósito. Numa criação bem-sucedida o outbox
    // enfileira e remove o evento, e a tabela termina vazia — indistinguível
    // de uma cadeia montada *sem* o outbox. Falhando, o evento permanece na
    // fila, e só há evento se o outbox estiver no caminho.
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString('Internal Server Error', 500),
    ];

    await expectLater(
      () => dependencies.checkoutRepository.create(session()),
      throwsA(isA<Exception>()),
    );

    final pendingEvents = await database.readPendingOutboxEvents();

    expect(pendingEvents, hasLength(1));
    expect(pendingEvents.single.idempotencyKey, 'key-01');
  });

  test('derives the pending sync stream from the given database', () async {
    final expectation = expectLater(dependencies.hasPendingSync, emitsInOrder([false, true]));

    await pumpEventQueue();
    await database.enqueueOutboxEvent(
      idempotencyKey: 'key-02',
      operationType: 'createCheckout',
      payload: '{}',
    );

    await expectation;
  });

  test('gives the synchronizer the repository without the performance decorator', () async {
    // O sincronizador reenvia o outbox, que não é ação do usuário: medi-lo
    // junto das criações reais misturaria duas populações no mesmo trace. O
    // tracer falso conta quantas vezes foi acionado, e a expectativa é zero.
    final tracer = _FakePerformanceTracer();
    final localDatabase = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(localDatabase.close);

    final localAdapter = FakeHttpClientAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))..httpClientAdapter = localAdapter;
    addTearDown(() => dio.close(force: true));

    final localDependencies = composeDependencies(
      database: localDatabase,
      apiClient: CheckoutApiClient.withDio(
        dio,
        tokenProvider: ({bool forceRefresh = false}) async => 'test-token',
        retryDelays: const [],
      ),
      settings: const StaticOperationalSettings(),
      tracer: tracer,
      syncTriggers: StreamController<void>().stream,
    );

    localAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    await localDatabase.enqueueOutboxEvent(
      idempotencyKey: 'key-03',
      operationType: 'createCheckout',
      payload:
          '{"id":"session-id","availableBalanceInCents":1000,"prescription":null,'
          '"medications":[],"status":"creatingPayment","remoteCheckoutId":null,'
          '"retryTargetStatus":null,"statusMessage":null,"idempotencyKey":"key-03"}',
    );

    await localDependencies.synchronizer.drain();

    expect(await localDatabase.readPendingOutboxEvents(), isEmpty);
    expect(tracer.calls, isEmpty);
  });
  test('wires the scheduler to the given triggers', () async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    await enqueue('key-01');

    dependencies.scheduler.start();
    addTearDown(dependencies.scheduler.dispose);

    syncTriggers.add(null);
    await pumpEventQueue();

    // A fila esvaziar prova a corrente inteira: o gatilho chegou ao agendador,
    // que chamou o sincronizador, que usou o repositório com o outbox, que
    // falou com o cliente HTTP. Sem o gatilho ligado, ninguém drena — então
    // aqui a fila vazia é uma asserção com significado.
    expect(await database.readPendingOutboxEvents(), isEmpty);
  });
  test('sends each event once when a trigger overlaps the startup drain', () async {
    // Uma resposta só, de propósito: com dois sincronizadores independentes
    // sairiam duas requisições, e a segunda ainda estouraria no adapter por
    // falta de resposta mockada.
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    await enqueue('key-01');

    dependencies.scheduler.start();
    addTearDown(dependencies.scheduler.dispose);

    // Sem `await`: é a sobreposição que o `main()` produz de verdade — ele
    // dispara `unawaited(drain())` e logo em seguida `scheduler.start()`, e um
    // evento de conectividade nos primeiros milissegundos cai bem aqui.
    final inicial = dependencies.synchronizer.drain();
    syncTriggers.add(null);
    await pumpEventQueue();
    await inicial;

    // A fila vazia não distingue um envio de dois — remover a mesma chave
    // duas vezes não falha. O que distingue é a contagem de requisições, e é
    // ela que prova que o grafo monta **um** sincronizador: com dois, os dois
    // laços leem a mesma fila e ambos enviam.
    expect(fakeAdapter.capturedHeaders['/checkouts'], hasLength(1));
    expect(await database.readPendingOutboxEvents(), isEmpty);
  });
}

final class _FakePerformanceTracer implements PerformanceTracer {
  final List<String> calls = [];

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) {
    calls.add(name);
    return action();
  }
}
