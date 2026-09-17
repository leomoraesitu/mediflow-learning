import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'checkout_database.g.dart';

/// A sessão em andamento, uma por usuário.
///
/// Deixou de ser tabela de registro único (`id = 1`) na Aula 55: o dono é a
/// identidade da linha, e não uma constante.
@DataClassName('CheckoutSessionRecord')
class CheckoutSessionRecords extends Table {
  TextColumn get userId => text()();

  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

@DataClassName('OutboxEvent')
class OutboxEvents extends Table {
  TextColumn get userId => text()();

  TextColumn get idempotencyKey => text()();

  TextColumn get operationType => text()();

  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// A chave continua sendo a de idempotência, e não o dono.
  ///
  /// O outbox é uma fila: um usuário tem várias compras pendentes. Com
  /// `userId` como chave, `insertOnConflictUpdate` sobrescreveria — enfileirar
  /// o segundo evento apagaria o primeiro, e a garantia de que nenhuma
  /// intenção de compra se perde deixaria de valer. O `userId` é coluna de
  /// filtro; a identidade é a chave uuid v4, única globalmente.
  @override
  Set<Column<Object>> get primaryKey => {idempotencyKey};
}

@DriftDatabase(tables: [CheckoutSessionRecords, OutboxEvents])
final class CheckoutDatabase extends _$CheckoutDatabase {
  CheckoutDatabase(super.executor);

  CheckoutDatabase.defaults() : super(driftDatabase(name: 'mediflow_checkout'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      // Degraus cumulativos (`from < n`), e não `from == n`: um aparelho na
      // v1 indo para a v3 precisa passar pelos dois. Com `==`, ele ganharia a
      // tabela de outbox e ficaria sem o `userId` na de sessão.
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(outboxEvents);
        }

        if (from < 3) {
          // As linhas existentes foram gravadas quando não havia usuário, e
          // não há a quem atribuí-las: seriam entregues a quem entrasse
          // primeiro no aparelho. São descartadas, e por isso as tabelas
          // podem ser recriadas já com a coluna obrigatória — `addColumn` de
          // coluna `NOT NULL` sem padrão seria recusado pelo SQLite numa
          // tabela com dados.
          //
          // O custo é uma compra pendente perdida na atualização. O
          // alternativo é entregá-la ao usuário errado.
          await m.deleteTable(checkoutSessionRecords.actualTableName);
          await m.deleteTable(outboxEvents.actualTableName);
          await m.createTable(checkoutSessionRecords);
          await m.createTable(outboxEvents);
        }
      },
    );
  }

  Future<CheckoutSessionRecord?> readCheckoutSession(String userId) {
    return (select(
      checkoutSessionRecords,
    )..where((record) => record.userId.equals(userId))).getSingleOrNull();
  }

  Future<void> writeCheckoutSession({required String userId, required String payload}) async {
    await into(checkoutSessionRecords).insertOnConflictUpdate(
      CheckoutSessionRecordsCompanion.insert(userId: userId, payload: payload),
    );
  }

  Future<void> clearCheckoutSession(String userId) async {
    await (delete(checkoutSessionRecords)..where((record) => record.userId.equals(userId))).go();
  }

  Future<void> enqueueOutboxEvent({
    required String userId,
    required String idempotencyKey,
    required String operationType,
    required String payload,
  }) async {
    await into(outboxEvents).insertOnConflictUpdate(
      OutboxEventsCompanion.insert(
        userId: userId,
        idempotencyKey: idempotencyKey,
        operationType: operationType,
        payload: payload,
      ),
    );
  }

  Future<List<OutboxEvent>> readPendingOutboxEvents(String userId) {
    return (select(outboxEvents)
          ..where((record) => record.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();
  }

  Stream<List<OutboxEvent>> watchPendingOutboxEvents(String userId) {
    return (select(outboxEvents)
          ..where((record) => record.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .watch();
  }

  /// Emite se existe alguma compra registrada no outbox e ainda não
  /// confirmada pelo servidor.
  ///
  /// O `distinct` não é cosmético: `watchPendingOutboxEvents` reemite a cada
  /// mudança na tabela, e várias dessas mudanças produzem o mesmo booleano —
  /// dois eventos enfileirados em sequência dariam `true` duas vezes, e cada
  /// emissão reconstruiria a interface sem nada ter mudado para ela.
  Stream<bool> watchHasPendingSync(String userId) {
    return watchPendingOutboxEvents(userId).map((events) => events.isNotEmpty).distinct();
  }

  Future<void> removeOutboxEvent({required String userId, required String idempotencyKey}) async {
    await (delete(outboxEvents)..where(
          (record) => record.idempotencyKey.equals(idempotencyKey) & record.userId.equals(userId),
        ))
        .go();
  }
}
