import 'package:checkout_domain/checkout_domain.dart';
import 'package:test/test.dart';

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
  final CheckoutSession checkoutResult;

  const _FakeCheckoutRepository({
    required this.createdCheckoutId,
    required this.checkoutResult,
  });

  @override
  Future<String> create(CheckoutSession session) async {
    return createdCheckoutId;
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) async {
    return checkoutResult;
  }
}

final class _RepositoryConsumer {
  final PrescriptionRepository _prescriptionRepository;
  final MedicationRepository _medicationRepository;
  final CheckoutRepository _checkoutRepository;

  const _RepositoryConsumer(
    this._prescriptionRepository,
    this._medicationRepository,
    this._checkoutRepository,
  );

  Future<bool> validatePrescription(Prescription prescription) {
    return _prescriptionRepository.validate(prescription);
  }

  Future<bool> checkMedicationEligibility(Medication medication) {
    return _medicationRepository.checkEligibility(medication);
  }

  Future<String> createCheckout(CheckoutSession session) {
    return _checkoutRepository.create(session);
  }
}

void main() {
  group('repository contracts', () {
    test('PrescriptionRepository can be replaced by a fake', () async {
      // Arrange
      const repository = _FakePrescriptionRepository(validationResult: true);
      const prescription = Prescription(reference: 'RX-001');

      // Act
      final result = await repository.validate(prescription);

      // Assert
      expect(result, isTrue);
    });

    test('MedicationRepository can be replaced by a fake', () async {
      // Arrange
      const repository = _FakeMedicationRepository(eligibilityResult: false);
      const medication = Medication(
        ean: '7891000000011',
        name: 'Medicamento de demonstração',
        unitPriceInCents: 1890,
      );

      // Act
      final result = await repository.checkEligibility(medication);

      // Assert
      expect(result, isFalse);
    });

    test('CheckoutRepository can create and recover a checkout', () async {
      // Arrange
      final localSession = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 25000,
        prescription: null,
        medications: [],
        status: CheckoutStatus.collectingMedication,
      );

      final remoteSession = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 25000,
        prescription: null,
        medications: [],
        status: CheckoutStatus.awaitingConfirmation,
        remoteCheckoutId: 'checkout-remote-01',
      );

      final repository = _FakeCheckoutRepository(
        createdCheckoutId: 'checkout-remote-01',
        checkoutResult: remoteSession,
      );

      // Act
      final createdId = await repository.create(localSession);
      final recoveredSession = await repository.getById(createdId);

      // Assert
      expect(createdId, 'checkout-remote-01');
      expect(recoveredSession, same(remoteSession));
    });

    test('consumer uses repositories received by constructor', () async {
      // Arrange
      const prescription = Prescription(reference: 'RX-001');

      const medication = Medication(
        ean: '7891000000011',
        name: 'Medicamento de demonstração',
        unitPriceInCents: 1890,
      );

      final session = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 25000,
        prescription: prescription,
        medications: [medication],
        status: CheckoutStatus.collectingMedication,
      );

      const prescriptionRepository = _FakePrescriptionRepository(
        validationResult: true,
      );

      const medicationRepository = _FakeMedicationRepository(
        eligibilityResult: true,
      );

      final checkoutRepository = _FakeCheckoutRepository(
        createdCheckoutId: 'checkout-remote-01',
        checkoutResult: session,
      );

      final consumer = _RepositoryConsumer(
        prescriptionRepository,
        medicationRepository,
        checkoutRepository,
      );

      // Act
      final prescriptionIsValid = await consumer.validatePrescription(
        prescription,
      );
      final medicationIsEligible = await consumer.checkMedicationEligibility(
        medication,
      );
      final checkoutId = await consumer.createCheckout(session);

      // Assert
      expect(prescriptionIsValid, isTrue);
      expect(medicationIsEligible, isTrue);
      expect(checkoutId, 'checkout-remote-01');
    });
  });
}
