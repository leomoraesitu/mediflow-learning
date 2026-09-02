import 'package:checkout_domain/checkout_domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_storage.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/drift_checkout_session_storage.dart';

void main() {
  late CheckoutDatabase database;
  late CheckoutSessionStorage storage;

  setUp(() {
    database = CheckoutDatabase(NativeDatabase.memory());
    storage = DriftCheckoutSessionStorage(database);
  });

  tearDown(() => database.close());

  test('returns null when Drift has no stored session', () async {
    expect(await storage.load(), isNull);
  });

  test('saves and restores the latest snapshot with Drift', () async {
    final first = _snapshot('session-01', 25000);
    final latest = _snapshot('session-02', 18000);

    await storage.save(first);
    await storage.save(latest);

    final restored = await storage.load();

    expect(restored, isNotNull);
    expect(restored!.toMap(), latest.toMap());
  });

  test('clears the snapshot stored with Drift', () async {
    await storage.save(_snapshot('session-03', 12000));

    await storage.clear();

    expect(await storage.load(), isNull);
  });
}

CheckoutSessionSnapshot _snapshot(String id, int balanceInCents) {
  return CheckoutSessionSnapshot.fromDomain(
    CheckoutSession(
      id: id,
      availableBalanceInCents: balanceInCents,
      prescription: null,
      medications: const [],
      status: CheckoutStatus.collectingMedication,
    ),
  );
}
