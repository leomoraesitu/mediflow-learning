import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_view_state.dart';
import 'package:mediflow_mobile/observability/analytics_sink.dart';
import 'package:mediflow_mobile/observability/crash_reporter.dart';

/// Registra o avanço do checkout e as falhas do Cubit.
///
/// Recebe as duas costuras por construtor. Até a Aula 57 ele recebia
/// `FirebaseAnalytics` e alcançava `FirebaseCrashlytics.instance` sozinho, o
/// que o tornava impossível de instanciar num teste — e foi assim que um
/// `as CheckoutSession` sobreviveu à troca de tipo de estado da Aula 51.
final class CheckoutAnalyticsObserver extends BlocObserver {
  final AnalyticsSink _analytics;
  final CrashReporter _crashReporter;

  const CheckoutAnalyticsObserver({required this._analytics, required this._crashReporter});

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);

    if (bloc is! CheckoutCubit) return;

    // Destrutura tipado, e não `as`: se o tipo do estado mudar de novo, o
    // observador para de registrar em vez de derrubar quem observa.
    //
    // `onChange` roda dentro do `emit`. Uma exceção aqui sobe antes de a
    // interface receber o estado novo — foi por isso que o botão de leitura
    // deixou de responder, sem nada na tela. Telemetria quebrada tem de virar
    // telemetria ausente.
    if (change.currentState case final CheckoutViewState anterior) {
      if (change.nextState case final CheckoutViewState proximo) {
        if (anterior.currentStep == proximo.currentStep) return;

        // A etapa da tela, e não o status do domínio.
        //
        // `CheckoutViewState` não expõe status de propósito, e o rótulo é
        // texto de interface — mudaria com a redação e viria localizado para
        // o painel. O custo é conhecido: `validatingPrescription` e
        // `checkingEligibility` são ambos a etapa 2, então o evento deixa de
        // distinguir essas duas transições. Para funil de conversão isso
        // basta; para depurar onde a validação trava, não.
        _analytics.logEvent('checkout_step', {'step': proximo.currentStep});
      }
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);

    if (bloc is! CheckoutCubit) return;

    _crashReporter.recordError(error, stackTrace);
  }
}
