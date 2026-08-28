import '../medication.dart';

abstract interface class MedicationRepository {
  Future<bool> checkEligibility(Medication medication);
}
