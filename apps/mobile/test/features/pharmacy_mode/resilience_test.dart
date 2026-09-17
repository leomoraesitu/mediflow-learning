import 'package:checkout_domain/checkout_domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_synchronizer.dart';

import '../../config/fake_auth_gateway.dart';
import 'data/remote/resilient_fake_checkout_server.dart';

void main() {
  FakeAuthGateway comUsuario(String uid) =>
      FakeAuthGateway()..currentUserValue = AuthUser(uid: uid, isAnonymous: false);

  test(
    'resumes a checkout after a dropped response and app restart without creating it twice',
    () async {
      final database = CheckoutDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = ResilientFakeCheckoutServer();

      // Primeira execução do aplicativo.
      final primeiraSessao = comUsuario('usuario-a');
      addTearDown(primeiraSessao.dispose);

      final outboxRepo = OutboxCheckoutRepository(
        inner: server,
        database: database,
        authGateway: primeiraSessao,
      );
      final session = CheckoutSession(
        id: 'session-id',
        availableBalanceInCents: 1000,
        prescription: null,
        medications: [],
        status: CheckoutStatus.creatingPayment,
        idempotencyKey: 'key-01',
      );
      server.dropNextResponse = true;

      await expectLater(() => outboxRepo.create(session), throwsA(isA<Exception>()));

      // Segunda execução: o aplicativo reiniciou. O repositório e o
      // sincronizador nascem juntos e compartilham a mesma sessão — três
      // gateways sugeririam três execuções. O único estado que atravessa o
      // reinício é o banco, e é esse o ponto do teste.
      final segundaSessao = comUsuario('usuario-a');
      addTearDown(segundaSessao.dispose);

      final outboxRepoRestarted = OutboxCheckoutRepository(
        inner: server,
        database: database,
        authGateway: segundaSessao,
      );
      final synchronizer = OutboxSynchronizer(
        database: database,
        checkoutRepository: outboxRepoRestarted,
        authGateway: segundaSessao,
      );

      await synchronizer.drain();

      expect(server.creationCount, 1);

      final pendingEvents = await database.readPendingOutboxEvents('usuario-a');
      expect(pendingEvents, isEmpty);
    },
  );
}
