import 'package:checkout_domain/checkout_domain.dart';
import 'package:firebase_performance/firebase_performance.dart';

final class PerformanceTracingPrescriptionRepository
    implements PrescriptionRepository {
  final PrescriptionRepository _inner;
  final FirebasePerformance _performance;

  const PerformanceTracingPrescriptionRepository({
    required this._inner,
    required this._performance,
  });

  @override
  Future<bool> validate(Prescription prescription) async {
    final trace = _performance.newTrace('prescription_validate');
    await trace.start();

    try {
      return await _inner.validate(prescription);
    } finally {
      await trace.stop();
    }
  }
}
