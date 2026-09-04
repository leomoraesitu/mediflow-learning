import 'package:uuid/uuid.dart';

import 'checkout_event.dart';
import 'checkout_session.dart';
import 'checkout_status.dart';

final class CheckoutStateMachine {
  const CheckoutStateMachine();

  CheckoutSession transition({
    required CheckoutSession session,
    required CheckoutEvent event,
  }) {
    if (session.status == CheckoutStatus.collectingMedication &&
        event is MedicationScanned) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: [...session.medications, event.medication],
        status: session.status,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: session.retryTargetStatus,
        statusMessage: session.statusMessage,
        idempotencyKey: session.idempotencyKey,
      );
    }
    if (session.status == CheckoutStatus.collectingMedication &&
        event is PrescriptionSubmitted) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: event.prescription,
        medications: session.medications,
        status: CheckoutStatus.validatingPrescription,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: session.retryTargetStatus,
        statusMessage: session.statusMessage,
        idempotencyKey: session.idempotencyKey,
      );
    }
    if (session.status == CheckoutStatus.validatingPrescription &&
        event is PrescriptionValidated) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: session.medications,
        status: CheckoutStatus.checkingEligibility,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: session.retryTargetStatus,
        statusMessage: session.statusMessage,
        idempotencyKey: session.idempotencyKey,
      );
    }
    if (session.status == CheckoutStatus.checkingEligibility &&
        event is EligibilityConfirmed) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: session.medications,
        status: CheckoutStatus.creatingPayment,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: session.retryTargetStatus,
        statusMessage: session.statusMessage,
        idempotencyKey: const Uuid().v4(),
      );
    }
    if (session.status == CheckoutStatus.creatingPayment &&
        event is PaymentCreated) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: session.medications,
        status: CheckoutStatus.awaitingConfirmation,
        remoteCheckoutId: event.remoteCheckoutId,
        retryTargetStatus: session.retryTargetStatus,
        statusMessage: session.statusMessage,
        idempotencyKey: session.idempotencyKey,
      );
    }
    final canAcceptPaymentConfirmation =
        session.status == CheckoutStatus.awaitingConfirmation ||
        (session.status == CheckoutStatus.recoverableFailure &&
            session.retryTargetStatus == CheckoutStatus.awaitingConfirmation);
    if (event is PaymentConfirmed &&
        session.remoteCheckoutId != null &&
        canAcceptPaymentConfirmation) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: session.medications,
        status: CheckoutStatus.paid,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: null,
        statusMessage: null,
        idempotencyKey: session.idempotencyKey,
      );
    }
    if (!session.status.isTerminal && event is MaintenanceDetected) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: session.medications,
        status: CheckoutStatus.maintenance,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: null,
        statusMessage: event.message,
        idempotencyKey: session.idempotencyKey,
      );
    }
    if (!session.status.isTerminal &&
        session.status != CheckoutStatus.recoverableFailure &&
        event is CheckoutFailed &&
        event.recoverable) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: session.medications,
        status: CheckoutStatus.recoverableFailure,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: session.status,
        statusMessage: event.errorMessage,
        idempotencyKey: session.idempotencyKey,
      );
    }
    final retryTargetStatus = session.retryTargetStatus;
    if (session.status == CheckoutStatus.recoverableFailure &&
        event is RetryRequested &&
        retryTargetStatus != null) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: session.medications,
        status: retryTargetStatus,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: null,
        statusMessage: null,
        idempotencyKey: session.idempotencyKey,
      );
    }
    if (!session.status.isTerminal &&
        event is CheckoutFailed &&
        !event.recoverable) {
      return CheckoutSession(
        id: session.id,
        availableBalanceInCents: session.availableBalanceInCents,
        prescription: session.prescription,
        medications: session.medications,
        status: CheckoutStatus.failed,
        remoteCheckoutId: session.remoteCheckoutId,
        retryTargetStatus: null,
        statusMessage: event.errorMessage,
        idempotencyKey: session.idempotencyKey,
      );
    }

    throw InvalidCheckoutTransitionException(
      currentStatus: session.status,
      event: event,
    );
  }
}

final class InvalidCheckoutTransitionException implements Exception {
  final CheckoutStatus currentStatus;
  final CheckoutEvent event;

  const InvalidCheckoutTransitionException({
    required this.currentStatus,
    required this.event,
  });

  @override
  String toString() {
    return 'InvalidCheckoutTransitionException: '
        'Cannot apply ${event.runtimeType} while checkout is '
        '${currentStatus.name}.';
  }
}
