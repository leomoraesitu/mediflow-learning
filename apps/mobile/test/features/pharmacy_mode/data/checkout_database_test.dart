import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';

void main() {
  test('starts with no stored checkout session', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final entry = await database.readCheckoutSession();

    expect(entry, isNull);
  });

  test('stores and reads the checkout session payload', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    const payload = '{"status":"collectingMedication"}';

    await database.writeCheckoutSession(payload);

    final entry = await database.readCheckoutSession();

    expect(entry?.id, 1);
    expect(entry?.payload, payload);
  });
  test('clears the stored checkout session', () async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.writeCheckoutSession('{"status":"collectingMedication"}');

    await database.clearCheckoutSession();

    final entry = await database.readCheckoutSession();

    expect(entry, isNull);
  });
}
