import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_storage.dart';
import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';

void main() {
  test('returns null when no checkout session has been saved', () async {
    final CheckoutSessionStorage storage = InMemoryCheckoutSessionStorage();

    final snapshot = await storage.load();

    expect(snapshot, isNull);
  });
  test('saves and restores a checkout session snapshot', () async {
    final CheckoutSessionStorage storage = InMemoryCheckoutSessionStorage();

    final original = CheckoutSessionSnapshot.fromDomain(
      CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 25000,
        status: CheckoutStatus.collectingMedication,
        prescription: null,
        medications: const [],
      ),
    );

    await storage.save(original);

    final restored = await storage.load();

    expect(restored, isNotNull);
    expect(restored!.toMap(), original.toMap());
  });
  test('clears a saved checkout session', () async {
    final CheckoutSessionStorage storage = InMemoryCheckoutSessionStorage();

    final snapshot = CheckoutSessionSnapshot.fromDomain(
      CheckoutSession(
        id: 'session-02',
        availableBalanceInCents: 18000,
        prescription: null,
        medications: const [],
        status: CheckoutStatus.collectingMedication,
      ),
    );

    await storage.save(snapshot);
    await storage.clear();

    expect(await storage.load(), isNull);
  });
}
