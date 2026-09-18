import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:mediflow_mobile/observability/crash_reporter.dart';

final class FirebaseCrashReporter implements CrashReporter {
  final FirebaseCrashlytics _crashlytics;

  const FirebaseCrashReporter({required this._crashlytics});

  @override
  void recordError(Object error, StackTrace stackTrace) {
    _crashlytics.recordError(error, stackTrace, fatal: false);
  }
}
