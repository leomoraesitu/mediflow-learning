import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/observability/performance_tracer.dart';

final class PerformanceTracingMedicationRepository implements MedicationRepository {
  final MedicationRepository _inner;
  final PerformanceTracer _tracer;

  const PerformanceTracingMedicationRepository({required this._inner, required this._tracer});

  @override
  Future<bool> checkEligibility(Medication medication) async {
    return _tracer.trace('medication_check_eligibility', () => _inner.checkEligibility(medication));
  }
}
