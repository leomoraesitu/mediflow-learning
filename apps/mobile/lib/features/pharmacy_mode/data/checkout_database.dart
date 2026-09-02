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

@DriftDatabase(tables: [CheckoutSessionRecords])
final class CheckoutDatabase extends _$CheckoutDatabase {
  CheckoutDatabase(super.executor);

  CheckoutDatabase.defaults() : super(driftDatabase(name: 'mediflow_checkout'));

  @override
  int get schemaVersion => 1;

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
}
