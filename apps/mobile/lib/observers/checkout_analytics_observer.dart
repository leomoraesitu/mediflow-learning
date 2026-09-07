import 'package:checkout_domain/checkout_domain.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';

final class CheckoutAnalyticsObserver extends BlocObserver {
  final FirebaseAnalytics _analytics;

  const CheckoutAnalyticsObserver(this._analytics);

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);

    if (bloc is! CheckoutCubit) return;

    final previousStatus = (change.currentState as CheckoutSession).status;
    final newStatus = (change.nextState as CheckoutSession).status;

    if (previousStatus == newStatus) return;

    _analytics.logEvent(
      name: 'checkout_step',
      parameters: {'step': newStatus.name},
    );
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);

    if (bloc is! CheckoutCubit) return;

    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false);
  }
}
