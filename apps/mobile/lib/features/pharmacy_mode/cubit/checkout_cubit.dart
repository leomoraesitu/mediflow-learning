import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class CheckoutCubit extends Cubit<CheckoutSession> {
  final CheckoutStateMachine _stateMachine;
  final PrescriptionRepository _prescriptionRepository;
  final MedicationRepository _medicationRepository;
  final CheckoutRepository _checkoutRepository;

  CheckoutCubit({
    required CheckoutSession initialSession,
    required CheckoutStateMachine stateMachine,
    required PrescriptionRepository prescriptionRepository,
    required MedicationRepository medicationRepository,
    required CheckoutRepository checkoutRepository,
  }) : _stateMachine = stateMachine,
       _prescriptionRepository = prescriptionRepository,
       _medicationRepository = medicationRepository,
       _checkoutRepository = checkoutRepository,
       super(initialSession);

  Future<void> submitPrescription(Prescription prescription) async {
    emit(
      _stateMachine.transition(
        session: state,
        event: PrescriptionSubmitted(prescription: prescription),
      ),
    );

    final isValid = await _prescriptionRepository.validate(prescription);

    if (isClosed) return;

    if (!isValid) {
      emit(
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

    emit(
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
      emit(
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

    emit(
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

      emit(
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

    emit(
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

      emit(
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

    emit(
      _stateMachine.transition(session: state, event: const PaymentConfirmed()),
    );
  }

  void retry() {
    emit(
      _stateMachine.transition(session: state, event: const RetryRequested()),
    );
  }
}
