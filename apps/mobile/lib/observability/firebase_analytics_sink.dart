import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:mediflow_mobile/observability/analytics_sink.dart';

final class FirebaseAnalyticsSink implements AnalyticsSink {
  final FirebaseAnalytics _analytics;

  const FirebaseAnalyticsSink({required this._analytics});

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    // Sem `await` e sem `unawaited`: o observador é síncrono por contrato do
    // `BlocObserver`, e telemetria não deve fazer o `emit` esperar.
    _analytics.logEvent(name: name, parameters: parameters);
  }
}
