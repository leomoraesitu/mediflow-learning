import 'checkout_status.dart';
import 'medication.dart';
import 'prescription.dart';

final class CheckoutSession {
  final String id;
  final int availableBalanceInCents;
  final Prescription? prescription;
  final List<Medication> medications;
  final CheckoutStatus status;
  final String? remoteCheckoutId;
  final CheckoutStatus? retryTargetStatus;
  final String? statusMessage;

  CheckoutSession({
    required this.id,
    required this.availableBalanceInCents,
    required this.prescription,
    required List<Medication> medications,
    required this.status,
    this.remoteCheckoutId,
    this.retryTargetStatus,
    this.statusMessage,
  }) : medications = List.unmodifiable(medications);
}
