import 'package:checkout_domain/checkout_domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_synchronizer.dart';

import 'data/remote/resilient_fake_checkout_server.dart';

void main() {
  test('resumes a checkout after a dropped response and app restart without creating it twice', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    final server = ResilientFakeCheckoutServer();
    final outboxRepo = OutboxCheckoutRepository(
      inner: server,
      database: database,
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

    await expectLater(
      () => outboxRepo.create(session),
      throwsA(isA<Exception>()),
    );

    final outboxRepoRestarted = OutboxCheckoutRepository(
      inner: server,
      database: database,
    );
    final synchronizer = OutboxSynchronizer(
      database: database,
      checkoutRepository: outboxRepoRestarted,
    );

    await synchronizer.drain();

    expect(server.creationCount, 1);

    final pendingEvents = await database.readPendingOutboxEvents();
    expect(pendingEvents, isEmpty);
  });
}
