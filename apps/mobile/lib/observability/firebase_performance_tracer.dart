import 'package:firebase_performance/firebase_performance.dart';
import 'package:mediflow_mobile/observability/performance_tracer.dart';

final class FirebasePerformanceTracer implements PerformanceTracer {
  final FirebasePerformance _performance;

  const FirebasePerformanceTracer({required this._performance});

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) async {
    final trace = _performance.newTrace(name);
    await trace.start();

    try {
      return await action();
    } finally {
      await trace.stop();
    }
  }
}
