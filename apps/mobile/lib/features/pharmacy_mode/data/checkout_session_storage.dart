import 'checkout_session_snapshot.dart';

abstract interface class CheckoutSessionStorage {
  Future<void> save(CheckoutSessionSnapshot snapshot);

  Future<CheckoutSessionSnapshot?> load();

  Future<void> clear();
}

final class InMemoryCheckoutSessionStorage implements CheckoutSessionStorage {
  Map<String, Object?>? _storedMap;

  @override
  Future<void> save(CheckoutSessionSnapshot snapshot) async {
    _storedMap = snapshot.toMap();
  }

  @override
  Future<CheckoutSessionSnapshot?> load() async {
    final storedMap = _storedMap;

    if (storedMap == null) {
      return null;
    }

    return CheckoutSessionSnapshot.fromMap(storedMap);
  }

  @override
  Future<void> clear() async {
    _storedMap = null;
  }
}
