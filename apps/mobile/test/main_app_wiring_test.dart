import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/app_dependencies.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/main.dart';
import 'package:mediflow_mobile/observability/performance_tracer.dart';

import 'config/fake_auth_gateway.dart';

/// Cobre a cópia do grafo para a árvore de widgets.
///
/// Existe por causa de um defeito real: durante a Aula 55, o `runApp` passou a
/// receber `hasPendingSync: (_) => const Stream<bool>.empty()` no lugar de
/// `dependencies.hasPendingSync`. O indicador de compra pendente deixou de
/// funcionar no aplicativo, e **nenhum dos 206 testes viu** — todos constroem
/// `MainApp` com os próprios esboços, então a fiação do `main()` nunca era
/// exercitada.
///
/// `MainApp.from` reduz essa cópia a um lugar só. Este arquivo verifica que ela
/// entrega o que recebeu.
void main() {
  late CheckoutDatabase database;
  late FakeAuthGateway gateway;
  late AppDependencies dependencies;

  setUp(() {
    database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    gateway = FakeAuthGateway()
      ..currentUserValue = const AuthUser(uid: 'usuario-a', isAnonymous: false);
    addTearDown(gateway.dispose);

    final dio = Dio(BaseOptions(baseUrl: 'https://exemplo.test'));
    addTearDown(() => dio.close(force: true));

    dependencies = composeDependencies(
      database: database,
      apiClient: CheckoutApiClient.withDio(
        dio,
        tokenProvider: ({bool forceRefresh = false}) async => 'token',
        retryDelays: const [],
      ),
      settings: const StaticOperationalSettings(),
      tracer: _NoopTracer(),
      syncTriggers: const [],
      authGateway: gateway,
    );
    addTearDown(dependencies.scheduler.dispose);
  });

  test('carries every dependency from the graph into the widget', () {
    final app = MainApp.from(dependencies);

    // `same`, e não `equals`: o que se quer provar é que a instância do grafo
    // chegou à árvore, e não que algo equivalente foi construído no caminho.
    expect(app.database, same(dependencies.database));
    expect(app.checkoutRepository, same(dependencies.checkoutRepository));
    expect(app.prescriptionRepository, same(dependencies.prescriptionRepository));
    expect(app.medicationRepository, same(dependencies.medicationRepository));
    expect(app.settings, same(dependencies.settings));
    expect(app.authGateway, same(dependencies.authGateway));

    // O campo que o defeito trocou por um fluxo vazio.
    expect(app.hasPendingSync, same(dependencies.hasPendingSync));
  });

  test('exposes the pending sync stream of the database, scoped by user', () async {
    final app = MainApp.from(dependencies);

    await expectLater(app.hasPendingSync('usuario-a').first, completion(isFalse));

    await database.enqueueOutboxEvent(
      userId: 'usuario-a',
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{}',
    );

    // Um fluxo vazio nunca emitiria: este `true` é a prova de que a função
    // ligada é a do banco, e não um substituto.
    await expectLater(app.hasPendingSync('usuario-a').first, completion(isTrue));
    await expectLater(app.hasPendingSync('usuario-b').first, completion(isFalse));
  });
}

final class _NoopTracer implements PerformanceTracer {
  @override
  Future<T> trace<T>(String name, Future<T> Function() action) => action();
}
