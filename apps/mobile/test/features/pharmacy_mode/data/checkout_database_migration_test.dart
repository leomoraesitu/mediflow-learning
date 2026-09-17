import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';

/// Testes da migração de schema.
///
/// Ficam num arquivo próprio porque o arranjo é diferente do resto: em vez de
/// abrir um banco vazio na versão atual, cada teste monta um banco no formato
/// *antigo*, por SQL direto, e deixa o `MigrationStrategy` agir.
///
/// A migração é o único código deste projeto que roda uma vez só, no aparelho
/// de alguém, sobre dados que não podem ser recriados. Um erro aqui não
/// aparece em nenhuma outra suíte.
void main() {
  /// Abre um banco já no formato antigo, e deixa o `MigrationStrategy` agir.
  ///
  /// O `setup:` do `NativeDatabase` é o único ponto que roda **antes** de o
  /// Drift consultar `user_version` e decidir entre `onCreate` e `onUpgrade`.
  /// Montar o schema antigo com `customStatement` depois de abrir não
  /// funciona: a essa altura o Drift já executou `onCreate` e criou as
  /// tabelas na versão atual.
  CheckoutDatabase abrirNaVersao(int versao, {required List<String> comandos}) {
    return CheckoutDatabase(
      NativeDatabase.memory(
        setup: (bancoCru) {
          for (final comando in comandos) {
            bancoCru.execute(comando);
          }
          bancoCru.execute('PRAGMA user_version = $versao');
        },
      ),
    );
  }

  test('creates the outbox table when migrating from version 1', () async {
    // A v1 tinha só a tabela de sessão, com `id` como chave.
    final database = abrirNaVersao(
      1,
      comandos: [
        'CREATE TABLE checkout_session_records ('
            'id INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY (id))',
      ],
    );
    addTearDown(database.close);

    // Força a migração e confirma que as duas tabelas existem no formato
    // novo. Este é o teste que distingue `from < n` de `from == n`: com `==`,
    // um aparelho na v1 ganharia o outbox e ficaria sem `userId` na sessão.
    await database.writeCheckoutSession(userId: 'usuario-a', payload: '{"depois":"da migração"}');
    await database.enqueueOutboxEvent(
      userId: 'usuario-a',
      idempotencyKey: 'key-01',
      operationType: 'createCheckout',
      payload: '{}',
    );

    expect((await database.readCheckoutSession('usuario-a'))?.payload, '{"depois":"da migração"}');
    expect(await database.readPendingOutboxEvents('usuario-a'), hasLength(1));
  });

  test('drops ownerless rows when migrating from version 2', () async {
    // A v2 tinha as duas tabelas, ambas sem `userId`.
    final database = abrirNaVersao(
      2,
      comandos: [
        'CREATE TABLE checkout_session_records ('
            'id INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY (id))',
        'CREATE TABLE outbox_events ('
            'idempotency_key TEXT NOT NULL, operation_type TEXT NOT NULL, '
            'payload TEXT NOT NULL, created_at INTEGER NOT NULL, '
            'PRIMARY KEY (idempotency_key))',
        "INSERT INTO checkout_session_records (id, payload) VALUES (1, '{\"sem\":\"dono\"}')",
        'INSERT INTO outbox_events (idempotency_key, operation_type, payload, created_at) '
            "VALUES ('key-antiga', 'createCheckout', '{}', 0)",
      ],
    );
    addTearDown(database.close);

    // As linhas antigas não têm dono possível: entregá-las a quem entrar
    // primeiro no aparelho seria pior do que perdê-las. A migração descarta.
    expect(await database.readCheckoutSession('usuario-a'), isNull);
    expect(await database.readPendingOutboxEvents('usuario-a'), isEmpty);

    // E o banco fica utilizável na v3.
    await database.writeCheckoutSession(userId: 'usuario-a', payload: '{"novo":true}');
    expect((await database.readCheckoutSession('usuario-a'))?.payload, '{"novo":true}');
  });
}
