import 'checkout_status.dart';
import 'medication.dart';
import 'prescription.dart';

final class CheckoutSession {
  final String id;
  final int availableBalanceInCents;
  final Prescription? prescription;
  final List<Medication> medications;
  final CheckoutStatus status;

  CheckoutSession({
    required this.id,
    required this.availableBalanceInCents,
    required this.prescription,
    required List<Medication> medications,
    required this.status,
  }) : medications = List.unmodifiable(medications);
}
