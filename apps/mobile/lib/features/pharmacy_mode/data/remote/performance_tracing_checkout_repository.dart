import 'package:checkout_domain/checkout_domain.dart';
import 'package:firebase_performance/firebase_performance.dart';

final class PerformanceTracingCheckoutRepository implements CheckoutRepository {
  final CheckoutRepository _inner;
  final FirebasePerformance _performance;

  const PerformanceTracingCheckoutRepository({
    required this._inner,
    required this._performance,
  });

  @override
  Future<String> create(CheckoutSession session) async {
    final trace = _performance.newTrace('checkout_create');
    await trace.start();

    try {
      return await _inner.create(session);
    } finally {
      await trace.stop();
    }
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) {
    return _inner.getById(remoteCheckoutId);
  }
}
