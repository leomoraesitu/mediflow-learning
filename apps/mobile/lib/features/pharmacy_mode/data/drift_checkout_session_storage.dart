import 'dart:convert';

import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_storage.dart';

final class DriftCheckoutSessionStorage implements CheckoutSessionStorage {
  final CheckoutDatabase _database;

  DriftCheckoutSessionStorage(this._database);

  @override
  Future<void> save(CheckoutSessionSnapshot snapshot) {
    return _database.writeCheckoutSession(jsonEncode(snapshot.toMap()));
  }

  @override
  Future<CheckoutSessionSnapshot?> load() async {
    final record = await _database.readCheckoutSession();

    if (record == null) {
      return null;
    }

    final storedMap = jsonDecode(record.payload) as Map<String, Object?>;

    return CheckoutSessionSnapshot.fromMap(storedMap);
  }

  @override
  Future<void> clear() {
    return _database.clearCheckoutSession();
  }
}
