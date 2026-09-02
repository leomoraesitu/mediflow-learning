// ignore_for_file: prefer_initializing_formals
//
// The public constructor intentionally keeps dependency parameter names public
// while storing the injected implementations in private fields.

import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/checkout_session_storage.dart';
import '../data/checkout_session_snapshot.dart';

final class CheckoutCubit extends Cubit<CheckoutSession> {
  final CheckoutStateMachine _stateMachine;
  final PrescriptionRepository _prescriptionRepository;
  final MedicationRepository _medicationRepository;
  final CheckoutRepository _checkoutRepository;
  final CheckoutSessionStorage? _storage;

  static Future<CheckoutCubit> restore({
    required CheckoutSession fallbackSession,
    required CheckoutSessionStorage storage,
    required CheckoutStateMachine stateMachine,
    required PrescriptionRepository prescriptionRepository,
    required MedicationRepository medicationRepository,
    required CheckoutRepository checkoutRepository,
  }) async {
    final snapshot = await storage.load();

    return CheckoutCubit(
      initialSession: snapshot?.toDomain() ?? fallbackSession,
      stateMachine: stateMachine,
      prescriptionRepository: prescriptionRepository,
      medicationRepository: medicationRepository,
      checkoutRepository: checkoutRepository,
      storage: storage,
    );
  }

  CheckoutCubit({
    required CheckoutSession initialSession,
    required CheckoutStateMachine stateMachine,
    required PrescriptionRepository prescriptionRepository,
    required MedicationRepository medicationRepository,
    required CheckoutRepository checkoutRepository,
    CheckoutSessionStorage? storage,
  }) : _stateMachine = stateMachine,
       _prescriptionRepository = prescriptionRepository,
       _medicationRepository = medicationRepository,
       _checkoutRepository = checkoutRepository,
       _storage = storage,
       super(initialSession);

  Future<void> _emitPersisted(CheckoutSession session) async {
    emit(session);

    final storage = _storage;

    if (storage != null) {
      await storage.save(CheckoutSessionSnapshot.fromDomain(session));
    }
  }

  Future<void> scanMedication(Medication medication) async {
    final nextSession = _stateMachine.transition(
      session: state,
      event: MedicationScanned(medication: medication),
    );

    await _emitPersisted(nextSession);
  }

  Future<void> submitPrescription(Prescription prescription) async {
    final nextSession = _stateMachine.transition(
      session: state,
      event: PrescriptionSubmitted(prescription: prescription),
    );

    await _emitPersisted(nextSession);

    final isValid = await _prescriptionRepository.validate(prescription);

    if (isClosed) return;

    if (!isValid) {
      await _emitPersisted(
        _stateMachine.transition(
          session: state,
          event: const CheckoutFailed(
            errorMessage: 'Receita inválida.',
            recoverable: false,
          ),
        ),
      );
      return;
    }

    await _emitPersisted(
      _stateMachine.transition(
        session: state,
        event: const PrescriptionValidated(),
      ),
    );
  }

  Future<void> checkEligibility(Medication medication) async {
    final isEligible = await _medicationRepository.checkEligibility(medication);

    if (isClosed) return;

    if (!isEligible) {
      await _emitPersisted(
        _stateMachine.transition(
          session: state,
          event: const CheckoutFailed(
            errorMessage: 'Medicamento não elegível.',
            recoverable: false,
          ),
        ),
      );
      return;
    }

    await _emitPersisted(
      _stateMachine.transition(
        session: state,
        event: const EligibilityConfirmed(),
      ),
    );
  }

  Future<void> createCheckout() async {
    late final String remoteCheckoutId;

    try {
      remoteCheckoutId = await _checkoutRepository.create(state);
    } on Exception {
      if (isClosed) return;

      await _emitPersisted(
        _stateMachine.transition(
          session: state,
          event: const CheckoutFailed(
            errorMessage: 'Falha ao criar o checkout.',
            recoverable: true,
          ),
        ),
      );
      return;
    }

    if (isClosed) return;

    await _emitPersisted(
      _stateMachine.transition(
        session: state,
        event: PaymentCreated(remoteCheckoutId: remoteCheckoutId),
      ),
    );
  }

  Future<void> confirmPayment() async {
    final remoteCheckoutId = state.remoteCheckoutId;

    if (remoteCheckoutId == null) return;

    late final CheckoutSession remoteCheckout;

    try {
      remoteCheckout = await _checkoutRepository.getById(remoteCheckoutId);
    } on Exception {
      if (isClosed) return;

      await _emitPersisted(
        _stateMachine.transition(
          session: state,
          event: const CheckoutFailed(
            errorMessage: 'Falha ao confirmar o checkout.',
            recoverable: true,
          ),
        ),
      );
      return;
    }

    if (isClosed || remoteCheckout.status != CheckoutStatus.paid) return;

    await _emitPersisted(
      _stateMachine.transition(session: state, event: const PaymentConfirmed()),
    );
  }

  Future<void> retry() async {
    await _emitPersisted(
      _stateMachine.transition(session: state, event: const RetryRequested()),
    );
  }
}
