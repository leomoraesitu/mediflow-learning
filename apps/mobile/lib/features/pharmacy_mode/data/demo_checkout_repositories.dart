import 'package:checkout_domain/checkout_domain.dart';

final class DemoPrescriptionRepository implements PrescriptionRepository {
  const DemoPrescriptionRepository();

  @override
  Future<bool> validate(Prescription prescription) async {
    return true;
  }
}

final class DemoMedicationRepository implements MedicationRepository {
  const DemoMedicationRepository();

  @override
  Future<bool> checkEligibility(Medication medication) async {
    return true;
  }
}

final class DemoCheckoutRepository implements CheckoutRepository {
  CheckoutSession? _checkout;

  @override
  Future<String> create(CheckoutSession session) async {
    const remoteCheckoutId = 'demo-checkout-001';

    _checkout = CheckoutSession(
      id: session.id,
      availableBalanceInCents: session.availableBalanceInCents,
      prescription: session.prescription,
      medications: session.medications,
      status: CheckoutStatus.awaitingConfirmation,
      remoteCheckoutId: remoteCheckoutId,
    );

    return remoteCheckoutId;
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) async {
    final checkout = _checkout;

    if (checkout == null || checkout.remoteCheckoutId != remoteCheckoutId) {
      throw StateError('Checkout demonstrativo não encontrado.');
    }

    return CheckoutSession(
      id: checkout.id,
      availableBalanceInCents: checkout.availableBalanceInCents,
      prescription: checkout.prescription,
      medications: checkout.medications,
      status: CheckoutStatus.paid,
      remoteCheckoutId: remoteCheckoutId,
    );
  }
}
