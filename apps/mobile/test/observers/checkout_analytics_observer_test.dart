import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/observability/analytics_sink.dart';
import 'package:mediflow_mobile/observability/crash_reporter.dart';
import 'package:mediflow_mobile/observers/checkout_analytics_observer.dart';

/// O observador nunca teve teste porque `Bloc.observer` é global e só era
/// atribuído no `main.dart`. Foi assim que um `as CheckoutSession` sobreviveu
/// à troca de tipo de estado da Aula 51 e quebrou o fluxo principal do
/// aplicativo por sete aulas, com 203 testes verdes.
void main() {
  late _FakeAnalyticsSink analytics;
  late _FakeCrashReporter crashes;

  setUp(() {
    analytics = _FakeAnalyticsSink();
    crashes = _FakeCrashReporter();
    Bloc.observer = CheckoutAnalyticsObserver(analytics: analytics, crashReporter: crashes);
  });

  // `Bloc.observer` é estático: sem isto ele vaza para os outros arquivos da
  // suíte e os contamina na ordem em que rodarem.
  tearDown(() => Bloc.observer = _SemObservador());

  CheckoutCubit buildCubit({int medicationCount = 1, required CheckoutStatus status}) {
    final cubit = CheckoutCubit(
      initialSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 25000,
        prescription: const Prescription(reference: 'RX-001'),
        medications: List.generate(
          medicationCount,
          (i) => Medication(ean: '789100000001$i', name: 'Demo', unitPriceInCents: 2500),
        ),
        status: status,
      ),
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: const _AlwaysValidPrescriptions(),
      medicationRepository: const _AlwaysEligibleMedications(),
      checkoutRepository: const _CheckoutThatNeverAnswers(),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('logs a checkout step event when the step changes', () async {
    final cubit = buildCubit(status: CheckoutStatus.checkingEligibility);

    // Etapa 2 -> 3.
    await cubit.checkEligibility();

    // Nome e parâmetros conferidos à parte: um registro tem igualdade
    // estrutural, mas só se os campos tiverem — e `Map` não tem. Comparar a
    // lista inteira falharia com "esperado e obtido idênticos", que foi
    // exatamente o que aconteceu ao escrever este teste.
    expect(analytics.eventos, hasLength(1));
    expect(analytics.eventos.single.$1, 'checkout_step');
    expect(analytics.eventos.single.$2, {'step': 3});
  });

  test('does not log when the step stays the same', () async {
    final cubit = buildCubit(status: CheckoutStatus.collectingMedication);

    // Ler outro medicamento mantém a etapa 1.
    await cubit.scanMedication('7891000000012');

    expect(analytics.eventos, isEmpty);
  });

  test('does not throw when the state is not a checkout view state', () async {
    // Um cubit de outro tipo passando pelo mesmo observador global. Antes da
    // correção, o `as` aqui derrubava o `emit` de quem estivesse emitindo.
    final outro = _CounterCubit();
    addTearDown(outro.close);

    expect(outro.increment, returnsNormally);
    expect(analytics.eventos, isEmpty);
  });
}

final class _SemObservador extends BlocObserver {}

final class _FakeAnalyticsSink implements AnalyticsSink {
  final List<(String, Map<String, Object>)> eventos = [];

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    eventos.add((name, parameters));
  }
}

final class _FakeCrashReporter implements CrashReporter {
  final List<Object> erros = [];

  @override
  void recordError(Object error, StackTrace stackTrace) => erros.add(error);
}

final class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

final class _AlwaysValidPrescriptions implements PrescriptionRepository {
  const _AlwaysValidPrescriptions();
  @override
  Future<bool> validate(Prescription prescription) async => true;
}

final class _AlwaysEligibleMedications implements MedicationRepository {
  const _AlwaysEligibleMedications();
  @override
  Future<bool> checkEligibility(Medication medication) async => true;
}

final class _CheckoutThatNeverAnswers implements CheckoutRepository {
  const _CheckoutThatNeverAnswers();
  @override
  Future<String> create(CheckoutSession session) async => throw UnimplementedError();
  @override
  Future<CheckoutSession> getById(String id) async => throw UnimplementedError();
}
