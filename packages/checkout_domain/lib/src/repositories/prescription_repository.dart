import '../prescription.dart';

abstract interface class PrescriptionRepository {
  Future<bool> validate(Prescription prescription);
}
