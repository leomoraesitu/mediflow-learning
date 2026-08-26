import 'package:checkout_domain/checkout_domain.dart';
import 'package:test/test.dart';

void main() {
  group('simple domain models', () {
    test('Medication preserves its values', () {
      const medication = Medication(
        ean: '1234567890123',
        name: 'Medication A',
        unitPriceInCents: 1000,
      );

      expect(medication.ean, '1234567890123');
      expect(medication.name, 'Medication A');
      expect(medication.unitPriceInCents, 1000);
    });
    test('Prescription preserves its reference', () {
      const prescription = Prescription(reference: 'RX-001');

      expect(prescription.reference, 'RX-001');
    });
    test('RemoteFlags preserves its configuration', () {
      const remoteFlags = RemoteFlags(
        checkoutTimeout: Duration(seconds: 30),
        maintenanceEnabled: false,
        maintenanceMessage: 'Maintenance in progress',
        fallbackEnabled: true,
      );

      expect(remoteFlags.checkoutTimeout, Duration(seconds: 30));
      expect(remoteFlags.maintenanceEnabled, false);
      expect(remoteFlags.maintenanceMessage, 'Maintenance in progress');
      expect(remoteFlags.fallbackEnabled, true);
    });
  });

  group('CheckoutSession', () {
    List<Medication> createMedications(int count) {
      return List.generate(
        count,
        (index) => Medication(
          ean: 'EAN-$index',
          name: 'Medication $index',
          unitPriceInCents: 1000 + index * 100,
        ),
      );
    }

    test('creates a defensive copy of medications', () {
      final originalMedications = createMedications(3);

      final session = CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 5000,
        prescription: null,
        medications: originalMedications,
        status: CheckoutStatus.collectingMedication,
      );

      originalMedications.clear();

      expect(originalMedications, isEmpty);
      expect(session.medications, hasLength(3));
    });

    test('does not allow medications to be modified', () {
      final originalMedications = createMedications(3);
      final session = CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 5000,
        prescription: null,
        medications: originalMedications,
        status: CheckoutStatus.collectingMedication,
      );
      expect(
        () => session.medications.add(
          Medication(
            ean: 'EAN-999',
            name: 'Medication 999',
            unitPriceInCents: 9999,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('CheckoutEvent', () {
    test('events with data preserve their values', () {
      final medication = Medication(
        ean: '1234567890123',
        name: 'Medication A',
        unitPriceInCents: 1000,
      );
      final prescription = Prescription(reference: 'RX-001');

      final MedicationScanned event = MedicationScanned(medication: medication);
      final PrescriptionSubmitted event2 = PrescriptionSubmitted(
        prescription: prescription,
      );
      final PaymentCreated event3 = PaymentCreated(
        remoteCheckoutId: 'checkout-001',
      );
      final CheckoutFailed event4 = CheckoutFailed(
        errorMessage: 'Network error',
        recoverable: true,
      );
      final MaintenanceDetected event5 = MaintenanceDetected(
        message: 'Maintenance in progress',
      );

      expect(event.medication, medication);
      expect(event2.prescription, prescription);
      expect(event3.remoteCheckoutId, 'checkout-001');
      expect(event4.errorMessage, 'Network error');
      expect(event4.recoverable, true);
      expect(event5.message, 'Maintenance in progress');
    });

    test('events without data belong to the CheckoutEvent hierarchy', () {
      final events = <CheckoutEvent>[
        const PrescriptionValidated(),
        const EligibilityConfirmed(),
        const PaymentConfirmed(),
        const RetryRequested(),
      ];

      expect(events, everyElement(isA<CheckoutEvent>()));
    });
  });
}
