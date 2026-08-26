import 'medication.dart';
import 'prescription.dart';

sealed class CheckoutEvent {
  const CheckoutEvent();
}

final class MedicationScanned extends CheckoutEvent {
  final Medication medication;
  const MedicationScanned({required this.medication});
}

final class PrescriptionSubmitted extends CheckoutEvent {
  final Prescription prescription;
  const PrescriptionSubmitted({required this.prescription});
}

final class PrescriptionValidated extends CheckoutEvent {
  const PrescriptionValidated();
}

final class EligibilityConfirmed extends CheckoutEvent {
  const EligibilityConfirmed();
}

final class PaymentCreated extends CheckoutEvent {
  final String remoteCheckoutId;
  const PaymentCreated({required this.remoteCheckoutId});
}

final class PaymentConfirmed extends CheckoutEvent {
  const PaymentConfirmed();
}

final class CheckoutFailed extends CheckoutEvent {
  final String errorMessage;
  final bool recoverable;
  const CheckoutFailed({required this.errorMessage, required this.recoverable});
}

final class RetryRequested extends CheckoutEvent {
  const RetryRequested();
}

final class MaintenanceDetected extends CheckoutEvent {
  final String message;
  const MaintenanceDetected({required this.message});
}
