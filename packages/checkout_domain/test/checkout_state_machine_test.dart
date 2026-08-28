import 'package:checkout_domain/checkout_domain.dart';
import 'package:test/test.dart';

void main() {
  group('CheckoutStateMachine', () {
    test('adds medication while remaining in collectingMedication', () {
      final session = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 10000,
        prescription: null,
        medications: [],
        status: CheckoutStatus.collectingMedication,
      );
      const medication = Medication(
        ean: 'EAN-999',
        name: 'Medication 999',
        unitPriceInCents: 99,
      );

      final result = const CheckoutStateMachine().transition(
        session: session,
        event: const MedicationScanned(medication: medication),
      );

      expect(result, isNot(same(session)));
      expect(result.status, CheckoutStatus.collectingMedication);
      expect(session.medications, isEmpty);
      expect(result.medications, [medication]);
    });

    test(
      'completes the happy path from prescription submission to payment',
      () {
        const prescription = Prescription(reference: 'Prescription example');
        const medication = Medication(
          ean: 'EAN-999',
          name: 'Medication 999',
          unitPriceInCents: 99,
        );

        const machine = CheckoutStateMachine();

        final session = CheckoutSession(
          id: 'session-01',
          availableBalanceInCents: 10000,
          prescription: null,
          medications: [medication],
          status: CheckoutStatus.collectingMedication,
        );

        final validatingPrescription = machine.transition(
          session: session,
          event: const PrescriptionSubmitted(prescription: prescription),
        );
        final checkingEligibility = machine.transition(
          session: validatingPrescription,
          event: const PrescriptionValidated(),
        );
        final creatingPayment = machine.transition(
          session: checkingEligibility,
          event: const EligibilityConfirmed(),
        );
        final awaitingConfirmation = machine.transition(
          session: creatingPayment,
          event: const PaymentCreated(remoteCheckoutId: 'CheckoutId-01'),
        );
        final paid = machine.transition(
          session: awaitingConfirmation,
          event: const PaymentConfirmed(),
        );

        expect(
          validatingPrescription.status,
          CheckoutStatus.validatingPrescription,
        );
        expect(checkingEligibility.status, CheckoutStatus.checkingEligibility);
        expect(creatingPayment.status, CheckoutStatus.creatingPayment);
        expect(
          awaitingConfirmation.status,
          CheckoutStatus.awaitingConfirmation,
        );
        expect(paid.status, CheckoutStatus.paid);
        expect(validatingPrescription.prescription, same(prescription));
        expect(awaitingConfirmation.remoteCheckoutId, 'CheckoutId-01');
        expect(paid.remoteCheckoutId, 'CheckoutId-01');
        expect(paid.id, session.id);
        expect(paid.availableBalanceInCents, session.availableBalanceInCents);
        expect(paid.medications, [medication]);
      },
    );
    test('rejects an invalid event for the current status', () {
      const medication = Medication(
        ean: 'EAN-999',
        name: 'Medication 999',
        unitPriceInCents: 99,
      );

      const machine = CheckoutStateMachine();

      final session = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 10000,
        prescription: null,
        medications: [medication],
        status: CheckoutStatus.collectingMedication,
      );

      expect(
        () => machine.transition(
          session: session,
          event: const PaymentConfirmed(),
        ),
        throwsA(
          isA<InvalidCheckoutTransitionException>()
              .having(
                (error) => error.currentStatus,
                'currentStatus',
                CheckoutStatus.collectingMedication,
              )
              .having((error) => error.event, 'event', isA<PaymentConfirmed>()),
        ),
      );
    });

    test('moves an active checkout to maintenance with a message', () {
      const medication = Medication(
        ean: 'EAN-999',
        name: 'Medication 999',
        unitPriceInCents: 99,
      );

      const prescription = Prescription(reference: 'Teste');

      final session = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 10000,
        prescription: prescription,
        medications: [medication],
        status: CheckoutStatus.checkingEligibility,
      );

      final result = const CheckoutStateMachine().transition(
        session: session,
        event: const MaintenanceDetected(
          message: 'Serviço temporariamente indisponível.',
        ),
      );

      expect(result, isNot(same(session)));
      expect(result.status, CheckoutStatus.maintenance);
      expect(result.statusMessage, 'Serviço temporariamente indisponível.');
      expect(result.status.isTerminal, isTrue);

      expect(result.id, session.id);
      expect(result.availableBalanceInCents, session.availableBalanceInCents);
      expect(result.prescription, same(prescription));
      expect(result.medications, [medication]);

      expect(session.status, CheckoutStatus.checkingEligibility);
    });

    test(
      'moves timeout to recoverable failure and remembers interrupted status',
      () {
        const medication = Medication(
          ean: 'EAN-999',
          name: 'Medication 999',
          unitPriceInCents: 99,
        );

        const prescription = Prescription(reference: 'Teste');

        final session = CheckoutSession(
          id: 'session-01',
          availableBalanceInCents: 10000,
          prescription: prescription,
          medications: [medication],
          status: CheckoutStatus.creatingPayment,
        );

        final result = const CheckoutStateMachine().transition(
          session: session,
          event: const CheckoutFailed(
            errorMessage: 'Tempo limite ao criar pagamento.',
            recoverable: true,
          ),
        );

        expect(result, isNot(same(session)));
        expect(result.status, CheckoutStatus.recoverableFailure);
        expect(result.status.isTerminal, isFalse);
        expect(result.retryTargetStatus, CheckoutStatus.creatingPayment);
        expect(result.statusMessage, 'Tempo limite ao criar pagamento.');

        expect(result.id, session.id);
        expect(result.availableBalanceInCents, session.availableBalanceInCents);
        expect(result.prescription, same(prescription));
        expect(result.medications, [medication]);

        expect(session.status, CheckoutStatus.creatingPayment);
        expect(session.retryTargetStatus, isNull);
        expect(session.statusMessage, isNull);
      },
    );
    test('retries the interrupted status and clears failure context', () {
      const medication = Medication(
        ean: 'EAN-999',
        name: 'Medication 999',
        unitPriceInCents: 99,
      );

      const prescription = Prescription(reference: 'Teste');

      final session = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 10000,
        prescription: prescription,
        medications: [medication],
        status: CheckoutStatus.recoverableFailure,
        retryTargetStatus: CheckoutStatus.awaitingConfirmation,
        remoteCheckoutId: 'CheckoutId-01',
        statusMessage: 'Conexão perdida durante a confirmação.',
      );
      final result = const CheckoutStateMachine().transition(
        session: session,
        event: const RetryRequested(),
      );
      expect(result, isNot(same(session)));
      expect(result.status, CheckoutStatus.awaitingConfirmation);
      expect(result.remoteCheckoutId, 'CheckoutId-01');
      expect(result.retryTargetStatus, isNull);
      expect(result.statusMessage, isNull);

      expect(result.id, session.id);
      expect(result.availableBalanceInCents, session.availableBalanceInCents);
      expect(result.prescription, same(prescription));
      expect(result.medications, [medication]);

      expect(session.status, CheckoutStatus.recoverableFailure);
      expect(session.retryTargetStatus, CheckoutStatus.awaitingConfirmation);
      expect(session.statusMessage, 'Conexão perdida durante a confirmação.');
    });
    test('moves permanent failure to terminal failed status', () {
      const medication = Medication(
        ean: 'EAN-999',
        name: 'Medication 999',
        unitPriceInCents: 99,
      );

      const prescription = Prescription(reference: 'Teste');

      final session = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 10000,
        prescription: prescription,
        medications: [medication],
        status: CheckoutStatus.awaitingConfirmation,
        remoteCheckoutId: 'CheckoutId-01',
      );
      final result = const CheckoutStateMachine().transition(
        session: session,
        event: const CheckoutFailed(
          errorMessage: 'Pagamento recusado definitivamente.',
          recoverable: false,
        ),
      );
      expect(result, isNot(same(session)));
      expect(result.status, CheckoutStatus.failed);
      expect(result.status.isTerminal, isTrue);
      expect(result.remoteCheckoutId, 'CheckoutId-01');
      expect(result.retryTargetStatus, isNull);
      expect(result.statusMessage, 'Pagamento recusado definitivamente.');

      expect(result.id, session.id);
      expect(result.availableBalanceInCents, session.availableBalanceInCents);
      expect(result.prescription, same(prescription));
      expect(result.medications, [medication]);

      expect(session.status, CheckoutStatus.awaitingConfirmation);
      expect(session.statusMessage, isNull);
    });
    test('accepts asynchronous confirmation after recoverable failure', () {
      const medication = Medication(
        ean: 'EAN-999',
        name: 'Medication 999',
        unitPriceInCents: 99,
      );

      const prescription = Prescription(reference: 'Teste');

      final session = CheckoutSession(
        id: 'session-01',
        availableBalanceInCents: 10000,
        prescription: prescription,
        medications: [medication],
        status: CheckoutStatus.recoverableFailure,
        remoteCheckoutId: 'CheckoutId-01',
        retryTargetStatus: CheckoutStatus.awaitingConfirmation,
        statusMessage: 'Conexão perdida durante a confirmação.',
      );
      final result = const CheckoutStateMachine().transition(
        session: session,
        event: const PaymentConfirmed(),
      );
      expect(result, isNot(same(session)));
      expect(result.status, CheckoutStatus.paid);
      expect(result.status.isTerminal, isTrue);
      expect(result.remoteCheckoutId, 'CheckoutId-01');
      expect(result.retryTargetStatus, isNull);
      expect(result.statusMessage, isNull);

      expect(result.id, session.id);
      expect(result.availableBalanceInCents, session.availableBalanceInCents);
      expect(result.prescription, same(prescription));
      expect(result.medications, [medication]);

      expect(session.status, CheckoutStatus.recoverableFailure);
      expect(session.retryTargetStatus, CheckoutStatus.awaitingConfirmation);
      expect(session.statusMessage, 'Conexão perdida durante a confirmação.');
    });
  });
}
