import 'package:bloc_test/bloc_test.dart';
import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_view_state.dart';

void main() {
  group('CheckoutCubit', () {
    test('starts on the first step with nothing scanned', () {
      final cubit = _cubit(session: _session());

      addTearDown(cubit.close);

      expect(cubit.state.currentStep, 1);
      expect(cubit.state.medicationCount, 0);
      expect(cubit.state.canSubmit, isFalse);
      expect(cubit.state.feedback, const NoFeedback());
    });

    blocTest<CheckoutCubit, CheckoutViewState>(
      'counts a scanned medication and allows submitting',
      build: () => _cubit(session: _session()),
      act: (cubit) => cubit.scanMedication('7891000000011'),
      expect: () => [
        isA<CheckoutViewState>()
            .having((state) => state.medicationCount, 'medicationCount', 1)
            .having((state) => state.medicationLabel, 'medicationLabel', '1 medicamento lido')
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'builds the scanned medication from the informed ean',
      build: () => _cubit(session: _session()),
      act: (cubit) async {
        // A View passa uma `String`; quem constrói o `Medication` é o Cubit.
        await cubit.scanMedication('7891000000011');
        await cubit.submitPrescription('RX-001');
        await cubit.checkEligibility();
      },
      verify: (cubit) {
        // O EAN não aparece no estado de visão, então o oráculo é o que
        // atravessou a fronteira: o medicamento que chegou ao repositório.
        expect(_medicationRepository.checked?.ean, '7891000000011');
        expect(_medicationRepository.checked?.unitPriceInCents, 2500);
      },
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'advances to validation and then to eligibility',
      build: () => _cubit(session: _session(medicationCount: 1)),
      act: (cubit) => cubit.submitPrescription('RX-001'),
      expect: () => [
        isA<CheckoutViewState>()
            .having((state) => state.currentStep, 'currentStep', 2)
            .having((state) => state.canCheckEligibility, 'canCheckEligibility', isFalse),
        isA<CheckoutViewState>()
            .having((state) => state.currentStep, 'currentStep', 2)
            .having((state) => state.canCheckEligibility, 'canCheckEligibility', isTrue),
      ],
      verify: (cubit) {
        expect(_prescriptionRepository.validated?.reference, 'RX-001');
      },
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'does not emit again when a transition produces an identical view state',
      // Sem medicamentos, `validatingPrescription` e `checkingEligibility`
      // produzem o mesmo estado de visão: a etapa e o rótulo coincidem, e
      // `canCheckEligibility` exige pelo menos um item. Duas transições de
      // domínio, uma emissão — e é isso que a igualdade de valor compra.
      build: () => _cubit(session: _session()),
      act: (cubit) => cubit.submitPrescription('RX-001'),
      expect: () => [
        isA<CheckoutViewState>()
            .having((state) => state.currentStep, 'currentStep', 2)
            .having((state) => state.canCheckEligibility, 'canCheckEligibility', isFalse),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'reports a permanent failure when the prescription is rejected',
      build: () => _cubit(session: _session(medicationCount: 1), prescriptionIsValid: false),
      act: (cubit) => cubit.submitPrescription('RX-001'),
      expect: () => [
        isA<CheckoutViewState>().having((state) => state.feedback, 'feedback', const NoFeedback()),
        isA<CheckoutViewState>().having(
          (state) => state.feedback,
          'feedback',
          const PermanentFailure('Receita inválida.'),
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'enables creating payment once eligibility is confirmed',
      build: () =>
          _cubit(session: _session(status: CheckoutStatus.checkingEligibility, medicationCount: 1)),
      act: (cubit) => cubit.checkEligibility(),
      expect: () => [
        isA<CheckoutViewState>()
            .having((state) => state.canCreatePayment, 'canCreatePayment', isTrue)
            .having((state) => state.currentStep, 'currentStep', 3),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'checks eligibility of the first scanned medication',
      build: () =>
          _cubit(session: _session(status: CheckoutStatus.checkingEligibility, medicationCount: 2)),
      act: (cubit) => cubit.checkEligibility(),
      verify: (cubit) {
        // A escolha era da View (`session.medications.first`) e mudou de dono.
        expect(_medicationRepository.checked?.ean, '7891000000010');
      },
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'reports a permanent failure when the medication is not eligible',
      build: () => _cubit(
        session: _session(status: CheckoutStatus.checkingEligibility, medicationCount: 1),
        medicationIsEligible: false,
      ),
      act: (cubit) => cubit.checkEligibility(),
      expect: () => [
        isA<CheckoutViewState>().having(
          (state) => state.feedback,
          'feedback',
          const PermanentFailure('Medicamento não elegível.'),
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'enables confirming payment once the checkout is created',
      build: () =>
          _cubit(session: _session(status: CheckoutStatus.creatingPayment, medicationCount: 1)),
      act: (cubit) => cubit.createCheckout(),
      expect: () => [
        isA<CheckoutViewState>()
            .having((state) => state.canConfirmPayment, 'canConfirmPayment', isTrue)
            .having((state) => state.currentStep, 'currentStep', 4),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'reports a recoverable failure when checkout creation fails',
      build: () => _cubit(
        session: _session(status: CheckoutStatus.creatingPayment, medicationCount: 1),
        createError: Exception('timeout'),
      ),
      act: (cubit) => cubit.createCheckout(),
      expect: () => [
        isA<CheckoutViewState>().having(
          (state) => state.feedback,
          'feedback',
          const RecoverableFailure('Falha ao criar o checkout.'),
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'reports success with the remote checkout id when payment is confirmed',
      build: () => _cubit(
        session: _session(
          status: CheckoutStatus.awaitingConfirmation,
          remoteCheckoutId: 'remote-checkout-001',
        ),
        paidCheckout: _session(
          status: CheckoutStatus.paid,
          remoteCheckoutId: 'remote-checkout-001',
        ),
      ),
      act: (cubit) => cubit.confirmPayment(),
      expect: () => [
        isA<CheckoutViewState>().having(
          (state) => state.feedback,
          'feedback',
          const SuccessFeedback('remote-checkout-001'),
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'reports a recoverable failure when confirmation times out',
      build: () => _cubit(
        session: _session(
          status: CheckoutStatus.awaitingConfirmation,
          remoteCheckoutId: 'remote-checkout-001',
        ),
        getByIdError: Exception('timeout'),
      ),
      act: (cubit) => cubit.confirmPayment(),
      expect: () => [
        isA<CheckoutViewState>().having(
          (state) => state.feedback,
          'feedback',
          const RecoverableFailure('Falha ao confirmar o checkout.'),
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutViewState>(
      'clears the failure when retry is requested',
      build: () => _cubit(
        session: _session(
          status: CheckoutStatus.recoverableFailure,
          retryTargetStatus: CheckoutStatus.creatingPayment,
          statusMessage: 'Falha ao criar o checkout.',
        ),
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        isA<CheckoutViewState>()
            .having((state) => state.feedback, 'feedback', const NoFeedback())
            .having((state) => state.canCreatePayment, 'canCreatePayment', isTrue),
      ],
    );
  });
}

late _RecordingPrescriptionRepository _prescriptionRepository;
late _RecordingMedicationRepository _medicationRepository;
late _RecordingCheckoutRepository _checkoutRepository;

CheckoutCubit _cubit({
  required CheckoutSession session,
  bool prescriptionIsValid = true,
  bool medicationIsEligible = true,
  CheckoutSession? paidCheckout,
  Object? createError,
  Object? getByIdError,
}) {
  _prescriptionRepository = _RecordingPrescriptionRepository(validationResult: prescriptionIsValid);
  _medicationRepository = _RecordingMedicationRepository(eligibilityResult: medicationIsEligible);
  _checkoutRepository = _RecordingCheckoutRepository(
    createdCheckoutId: 'remote-checkout-001',
    checkoutById: paidCheckout,
    createError: createError,
    getByIdError: getByIdError,
  );

  return CheckoutCubit(
    initialSession: session,
    stateMachine: const CheckoutStateMachine(),
    prescriptionRepository: _prescriptionRepository,
    medicationRepository: _medicationRepository,
    checkoutRepository: _checkoutRepository,
  );
}

CheckoutSession _session({
  CheckoutStatus status = CheckoutStatus.collectingMedication,
  int medicationCount = 0,
  String? remoteCheckoutId,
  String? statusMessage,
  CheckoutStatus? retryTargetStatus,
}) {
  return CheckoutSession(
    id: 'session-001',
    availableBalanceInCents: 25000,
    prescription: const Prescription(reference: 'RX-001'),
    medications: List.generate(
      medicationCount,
      (index) => Medication(
        ean: '789100000001$index',
        name: 'Medicamento demonstrativo',
        unitPriceInCents: 2500,
      ),
    ),
    status: status,
    remoteCheckoutId: remoteCheckoutId,
    statusMessage: statusMessage,
    retryTargetStatus: retryTargetStatus,
  );
}

/// Fakes que registram o que receberam.
///
/// Com a sessão de domínio privada no Cubit, o oráculo deixa de ser espiar
/// estado interno e passa a ser observar o que atravessou a fronteira.
final class _RecordingPrescriptionRepository implements PrescriptionRepository {
  final bool validationResult;
  Prescription? validated;

  _RecordingPrescriptionRepository({required this.validationResult});

  @override
  Future<bool> validate(Prescription prescription) async {
    validated = prescription;
    return validationResult;
  }
}

final class _RecordingMedicationRepository implements MedicationRepository {
  final bool eligibilityResult;
  Medication? checked;

  _RecordingMedicationRepository({required this.eligibilityResult});

  @override
  Future<bool> checkEligibility(Medication medication) async {
    checked = medication;
    return eligibilityResult;
  }
}

final class _RecordingCheckoutRepository implements CheckoutRepository {
  final String createdCheckoutId;
  final CheckoutSession? checkoutById;
  final Object? createError;
  final Object? getByIdError;
  CheckoutSession? createdSession;

  _RecordingCheckoutRepository({
    required this.createdCheckoutId,
    this.checkoutById,
    this.createError,
    this.getByIdError,
  });

  @override
  Future<String> create(CheckoutSession session) async {
    createdSession = session;

    final error = createError;
    if (error != null) throw error;

    return createdCheckoutId;
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) async {
    final error = getByIdError;
    if (error != null) throw error;

    final checkout = checkoutById;
    if (checkout == null) {
      throw UnimplementedError('getById não foi configurado neste teste');
    }

    return checkout;
  }
}
