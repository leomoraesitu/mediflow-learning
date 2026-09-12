import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/observability/performance_tracer.dart';

final class PerformanceTracingPrescriptionRepository implements PrescriptionRepository {
  final PrescriptionRepository _inner;
  final PerformanceTracer _tracer;

  const PerformanceTracingPrescriptionRepository({required this._inner, required this._tracer});

  @override
  Future<bool> validate(Prescription prescription) async {
    return _tracer.trace('prescription_validate', () => _inner.validate(prescription));
  }
}
