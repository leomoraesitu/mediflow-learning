import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:bloc_test/bloc_test.dart';

void main() {
  group('CheckoutCubit', () {
    test('starts with the provided checkout session', () {
      final initialSession = CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 25000,
        prescription: null,
        medications: [],
        status: CheckoutStatus.collectingMedication,
      );

      final cubit = CheckoutCubit(
        initialSession: initialSession,
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      );

      addTearDown(cubit.close);

      expect(cubit.state, same(initialSession));
    });

    blocTest<CheckoutCubit, CheckoutSession>(
  'adds a scanned medication to the checkout session',
  build: () => CheckoutCubit(
    initialSession: CheckoutSession(
      id: 'session-001',
      availableBalanceInCents: 25000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.collectingMedication,
    ),
    stateMachine: const CheckoutStateMachine(),
    prescriptionRepository: const _FakePrescriptionRepository(
      validationResult: true,
    ),
    medicationRepository: const _FakeMedicationRepository(
      eligibilityResult: true,
    ),
    checkoutRepository: const _FakeCheckoutRepository(
      createdCheckoutId: 'remote-checkout-001',
    ),
  ),
  act: (cubit) => cubit.scanMedication(
    const Medication(
      ean: '7891000000011',
      name: 'Medicamento demonstrativo',
      unitPriceInCents: 2500,
    ),
  ),
  expect: () => [
    isA<CheckoutSession>()
        .having(
          (session) => session.status,
          'status',
          CheckoutStatus.collectingMedication,
        )
        .having(
          (session) => session.medications.length,
          'medications length',
          1,
        )
        .having(
          (session) => session.medications.single.ean,
          'medication EAN',
          '7891000000011',
        ),
  ],
);

    blocTest<CheckoutCubit, CheckoutSession>(
      'submitPrescription',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: null,
          medications: [],
          status: CheckoutStatus.collectingMedication,
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      ),

      act: (cubit) =>
          cubit.submitPrescription(const Prescription(reference: 'RX-001')),
      expect: () => [
        isA<CheckoutSession>().having(
          (session) => session.status,
          'status',
          CheckoutStatus.validatingPrescription,
        ),
        isA<CheckoutSession>().having(
          (session) => session.status,
          'status',
          CheckoutStatus.checkingEligibility,
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutSession>(
      'emits failed when prescription is rejected',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: null,
          medications: [],
          status: CheckoutStatus.collectingMedication,
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: _FakePrescriptionRepository(
          validationResult: false,
        ),
        medicationRepository: _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      ),

      act: (cubit) =>
          cubit.submitPrescription(const Prescription(reference: 'RX-001')),
      expect: () => [
        isA<CheckoutSession>().having(
          (session) => session.status,
          'status',
          CheckoutStatus.validatingPrescription,
        ),
        isA<CheckoutSession>()
            .having(
              (session) => session.status,
              'status',
              CheckoutStatus.failed,
            )
            .having(
              (session) => session.statusMessage,
              'statusMessage',
              'Receita inválida.',
            ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutSession>(
      'emits creatingPayment when medication is eligible',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [
            Medication(
              ean: '7891000000011',
              name: 'Medicamento demonstrativo',
              unitPriceInCents: 2500,
            ),
          ],
          status: CheckoutStatus.checkingEligibility,
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: const _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      ),
      act: (cubit) => cubit.checkEligibility(
        const Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ),
      expect: () => [
        isA<CheckoutSession>().having(
          (session) => session.status,
          'status',
          CheckoutStatus.creatingPayment,
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutSession>(
      'emits failed when medication is not eligible',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [
            Medication(
              ean: '7891000000011',
              name: 'Medicamento demonstrativo',
              unitPriceInCents: 2500,
            ),
          ],
          status: CheckoutStatus.checkingEligibility,
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: false,
        ),
        checkoutRepository: const _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      ),
      act: (cubit) => cubit.checkEligibility(
        const Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ),
      expect: () => [
        isA<CheckoutSession>()
            .having(
              (session) => session.status,
              'status',
              CheckoutStatus.failed,
            )
            .having(
              (session) => session.statusMessage,
              'statusMessage',
              'Medicamento não elegível.',
            ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutSession>(
      'emits awaitingConfirmation with remote id when checkout is created',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [
            Medication(
              ean: '7891000000011',
              name: 'Medicamento demonstrativo',
              unitPriceInCents: 2500,
            ),
          ],
          status: CheckoutStatus.creatingPayment,
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: const _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      ),
      act: (cubit) => cubit.createCheckout(),
      expect: () => [
        isA<CheckoutSession>()
            .having(
              (session) => session.status,
              'status',
              CheckoutStatus.awaitingConfirmation,
            )
            .having(
              (session) => session.remoteCheckoutId,
              'remoteCheckoutId',
              'remote-checkout-001',
            ),
      ],
    );
    blocTest<CheckoutCubit, CheckoutSession>(
      'emits recoverableFailure when checkout creation fails',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [
            Medication(
              ean: '7891000000011',
              name: 'Medicamento demonstrativo',
              unitPriceInCents: 2500,
            ),
          ],
          status: CheckoutStatus.creatingPayment,
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
          createError: Exception('timeout'),
        ),
      ),
      act: (cubit) => cubit.createCheckout(),
      expect: () => [
        isA<CheckoutSession>()
            .having(
              (session) => session.status,
              'status',
              CheckoutStatus.recoverableFailure,
            )
            .having(
              (session) => session.retryTargetStatus,
              'retryTargetStatus',
              CheckoutStatus.creatingPayment,
            )
            .having(
              (session) => session.statusMessage,
              'statusMessage',
              'Falha ao criar o checkout.',
            ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutSession>(
      'emits paid when remote checkout is confirmed',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [],
          status: CheckoutStatus.awaitingConfirmation,
          remoteCheckoutId: 'remote-checkout-001',
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
          checkoutById: CheckoutSession(
            id: 'session-001',
            availableBalanceInCents: 25000,
            prescription: const Prescription(reference: 'RX-001'),
            medications: const [],
            status: CheckoutStatus.paid,
            remoteCheckoutId: 'remote-checkout-001',
          ),
        ),
      ),
      act: (cubit) => cubit.confirmPayment(),
      expect: () => [
        isA<CheckoutSession>()
            .having((session) => session.status, 'status', CheckoutStatus.paid)
            .having(
              (session) => session.remoteCheckoutId,
              'remoteCheckoutId',
              'remote-checkout-001',
            ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutSession>(
      'restores interrupted status when retry is requested',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [],
          status: CheckoutStatus.recoverableFailure,
          retryTargetStatus: CheckoutStatus.creatingPayment,
          statusMessage: 'Falha ao criar o checkout.',
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: const _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        isA<CheckoutSession>()
            .having(
              (session) => session.status,
              'status',
              CheckoutStatus.creatingPayment,
            )
            .having(
              (session) => session.retryTargetStatus,
              'retryTargetStatus',
              isNull,
            )
            .having(
              (session) => session.statusMessage,
              'statusMessage',
              isNull,
            ),
      ],
    );
    blocTest<CheckoutCubit, CheckoutSession>(
      'restores interrupted status when retry is requested',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [],
          status: CheckoutStatus.recoverableFailure,
          retryTargetStatus: CheckoutStatus.creatingPayment,
          statusMessage: 'Falha ao criar o checkout.',
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: const _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        isA<CheckoutSession>()
            .having(
              (session) => session.status,
              'status',
              CheckoutStatus.creatingPayment,
            )
            .having(
              (session) => session.retryTargetStatus,
              'retryTargetStatus',
              isNull,
            )
            .having(
              (session) => session.statusMessage,
              'statusMessage',
              isNull,
            ),
      ],
    );
    blocTest<CheckoutCubit, CheckoutSession>(
      'restores interrupted status when retry is requested',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [],
          status: CheckoutStatus.recoverableFailure,
          retryTargetStatus: CheckoutStatus.creatingPayment,
          statusMessage: 'Falha ao criar o checkout.',
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: const _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
        ),
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        isA<CheckoutSession>()
            .having(
              (session) => session.status,
              'status',
              CheckoutStatus.creatingPayment,
            )
            .having(
              (session) => session.retryTargetStatus,
              'retryTargetStatus',
              isNull,
            )
            .having(
              (session) => session.statusMessage,
              'statusMessage',
              isNull,
            ),
      ],
    );
    blocTest<CheckoutCubit, CheckoutSession>(
      'restores interrupted by timeout when confirm payment',
      build: () => CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [],
          status: CheckoutStatus.awaitingConfirmation,
          remoteCheckoutId: 'remote-checkout-001',
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-001',
          getByIdError: Exception('timeout'),
        ),
      ),
      act: (cubit) => cubit.confirmPayment(),
      expect: () => [
        isA<CheckoutSession>()
            .having(
              (session) => session.status,
              'status',
              CheckoutStatus.recoverableFailure,
            )
            .having(
              (session) => session.retryTargetStatus,
              'retryTargetStatus',
              CheckoutStatus.awaitingConfirmation,
            )
            .having(
              (session) => session.remoteCheckoutId,
              'remoteCheckoutId',
              'remote-checkout-001',
            )
            .having(
              (session) => session.statusMessage,
              'statusMessage',
              'Falha ao confirmar o checkout.',
            ),
      ],
    );
  });
}

final class _FakePrescriptionRepository implements PrescriptionRepository {
  final bool validationResult;

  const _FakePrescriptionRepository({required this.validationResult});

  @override
  Future<bool> validate(Prescription prescription) async {
    return validationResult;
  }
}

final class _FakeMedicationRepository implements MedicationRepository {
  final bool eligibilityResult;

  const _FakeMedicationRepository({required this.eligibilityResult});

  @override
  Future<bool> checkEligibility(Medication medication) async {
    return eligibilityResult;
  }
}

final class _FakeCheckoutRepository implements CheckoutRepository {
  final String createdCheckoutId;
  final CheckoutSession? checkoutById;
  final Object? createError;
  final Object? getByIdError;

  const _FakeCheckoutRepository({
    required this.createdCheckoutId,
    this.checkoutById,
    this.createError,
    this.getByIdError,
  });

  @override
  Future<String> create(CheckoutSession session) async {
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
