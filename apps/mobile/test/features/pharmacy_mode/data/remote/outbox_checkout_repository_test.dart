import 'package:checkout_domain/checkout_domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';

import '../../../../config/fake_auth_gateway.dart';

void main() {
  FakeAuthGateway comUsuario(String uid) =>
      FakeAuthGateway()..currentUserValue = AuthUser(uid: uid, isAnonymous: false);
  test('removes the event after a successful creation', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = _FakeCheckoutRepository(createdCheckoutId: 'remote-01');

    final outbox = OutboxCheckoutRepository(
      inner: repository,
      database: database,
      authGateway: comUsuario('usuario-a'),
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

    final entries = await database.readPendingOutboxEvents('usuario-a');

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
      authGateway: comUsuario('usuario-a'),
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

    final entries = await database.readPendingOutboxEvents('usuario-a');

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
      authGateway: comUsuario('usuario-a'),
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
  test('enqueues under the user signed in at the time of the call', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    // O repositório falha de propósito: em caso de sucesso o evento é
    // removido logo em seguida, e não haveria o que inspecionar.
    final repository = _FakeCheckoutRepository(createError: Exception('sem rede'));

    final gateway = comUsuario('usuario-a');
    addTearDown(gateway.dispose);

    // Uma instância só, atravessando a troca de usuário — que é o cenário
    // real: este objeto é montado na composição e vive o processo inteiro.
    final outbox = OutboxCheckoutRepository(
      inner: repository,
      database: database,
      authGateway: gateway,
    );

    CheckoutSession sessaoCom(String chave) => CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.creatingPayment,
      idempotencyKey: chave,
    );

    await expectLater(outbox.create(sessaoCom('key-a')), throwsA(isA<Exception>()));

    gateway.currentUserValue = const AuthUser(uid: 'usuario-b', isAnonymous: false);

    await expectLater(outbox.create(sessaoCom('key-b')), throwsA(isA<Exception>()));

    // Guardar o `uid` no construtor mandaria os dois eventos para o mesmo
    // dono, e este teste é o único que veria a diferença.
    expect((await database.readPendingOutboxEvents('usuario-a')).map((e) => e.idempotencyKey), [
      'key-a',
    ]);
    expect((await database.readPendingOutboxEvents('usuario-b')).map((e) => e.idempotencyKey), [
      'key-b',
    ]);
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
