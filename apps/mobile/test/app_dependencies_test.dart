import 'package:checkout_domain/checkout_domain.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/app_dependencies.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/observability/performance_tracer.dart';

import 'features/pharmacy_mode/data/remote/fake_http_client_adapter.dart';

void main() {
  late CheckoutDatabase database;
  late FakeHttpClientAdapter fakeAdapter;
  late AppDependencies dependencies;

  setUp(() {
    database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

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
    );
  });

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
}

final class _FakePerformanceTracer implements PerformanceTracer {
  final List<String> calls = [];

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) {
    calls.add(name);
    return action();
  }
}
