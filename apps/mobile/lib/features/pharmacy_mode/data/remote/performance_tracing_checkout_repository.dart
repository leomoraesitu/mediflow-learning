import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/observability/performance_tracer.dart';

final class PerformanceTracingCheckoutRepository implements CheckoutRepository {
  final CheckoutRepository _inner;
  final PerformanceTracer _tracer;

  const PerformanceTracingCheckoutRepository({required this._inner, required this._tracer});

  @override
  Future<String> create(CheckoutSession session) async {
    return _tracer.trace('checkout_create', () => _inner.create(session));
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) {
    return _inner.getById(remoteCheckoutId);
  }
}
