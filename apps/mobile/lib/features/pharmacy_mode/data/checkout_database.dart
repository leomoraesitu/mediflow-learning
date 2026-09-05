import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'checkout_database.g.dart';

@DataClassName('CheckoutSessionRecord')
class CheckoutSessionRecords extends Table {
  IntColumn get id => integer()();

  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('OutboxEvent')
class OutboxEvents extends Table {
  TextColumn get idempotencyKey => text()();

  TextColumn get operationType => text()();

  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {idempotencyKey};
}

@DriftDatabase(tables: [CheckoutSessionRecords, OutboxEvents])
final class CheckoutDatabase extends _$CheckoutDatabase {
  CheckoutDatabase(super.executor);

  CheckoutDatabase.defaults() : super(driftDatabase(name: 'mediflow_checkout'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from == 1) {
          await m.createTable(outboxEvents);
        }
      },
    );
  }

  Future<CheckoutSessionRecord?> readCheckoutSession() {
    return (select(
      checkoutSessionRecords,
    )..where((record) => record.id.equals(1))).getSingleOrNull();
  }

  Future<void> writeCheckoutSession(String payload) async {
    await into(checkoutSessionRecords).insertOnConflictUpdate(
      CheckoutSessionRecordsCompanion.insert(
        id: const Value(1),
        payload: payload,
      ),
    );
  }

  Future<void> clearCheckoutSession() async {
    await (delete(
      checkoutSessionRecords,
    )..where((record) => record.id.equals(1))).go();
  }

  Future<void> enqueueOutboxEvent({
    required String idempotencyKey,
    required String operationType,
    required String payload,
  }) async {
    await into(outboxEvents).insertOnConflictUpdate(
      OutboxEventsCompanion.insert(
        idempotencyKey: idempotencyKey,
        operationType: operationType,
        payload: payload,
      ),
    );
  }

  Future<List<OutboxEvent>> readPendingOutboxEvents() {
    return (select(outboxEvents)..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
        ]))
        .get();
  }

  Future<void> removeOutboxEvent(String idempotencyKey) async {
    await (delete(
      outboxEvents,
    )..where((record) => record.idempotencyKey.equals(idempotencyKey))).go();
  }
}
