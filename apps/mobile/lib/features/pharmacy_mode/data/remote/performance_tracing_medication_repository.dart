import 'package:checkout_domain/checkout_domain.dart';
import 'package:firebase_performance/firebase_performance.dart';

final class PerformanceTracingMedicationRepository implements MedicationRepository {
  final MedicationRepository _inner;
  final FirebasePerformance _performance;

  const PerformanceTracingMedicationRepository({required this._inner, required this._performance});

  @override
  Future<bool> checkEligibility(Medication medication) async {
    final trace = _performance.newTrace('medication_check_eligibility');
    await trace.start();

    try {
      return await _inner.checkEligibility(medication);
    } finally {
      await trace.stop();
    }
  }
}
