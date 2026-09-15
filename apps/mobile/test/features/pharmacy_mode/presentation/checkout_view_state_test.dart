import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_progress_selector.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_view_state.dart';

void main() {
  group('medicationLabel', () {
    test('reads no medication as a message instead of zero', () {
      final session = _session(medicationCount: 0);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.medicationLabel, 'Nenhum medicamento lido');
    });

    test('reads a single medication in the singular', () {
      final session = _session(medicationCount: 1);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.medicationLabel, '1 medicamento lido');
    });

    test('reads multiple medications in the plural', () {
      final session = _session(medicationCount: 3);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.medicationLabel, '3 medicamentos lidos');
    });
  });
  group('action availability', () {
    test('allows submitting only while collecting medication with at least one item', () {
      final session = _session(status: CheckoutStatus.collectingMedication, medicationCount: 1);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canSubmit, isTrue);
    });

    test('blocks submitting when no medication was scanned', () {
      final session = _session(status: CheckoutStatus.collectingMedication, medicationCount: 0);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canSubmit, isFalse);
    });

    test('blocks submitting once the prescription is already being validated', () {
      final session = _session(status: CheckoutStatus.validatingPrescription, medicationCount: 1);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canSubmit, isFalse);
    });
    test('allows checking eligibility only while checking eligibility with at least one item', () {
      final session = _session(status: CheckoutStatus.checkingEligibility, medicationCount: 1);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canCheckEligibility, isTrue);
    });

    test('blocks checking eligibility while still collecting medication', () {
      final session = _session(status: CheckoutStatus.collectingMedication, medicationCount: 1);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canCheckEligibility, isFalse);
    });
    test('allows creating payment only while creating payment', () {
      final session = _session(status: CheckoutStatus.creatingPayment, medicationCount: 1);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canCreatePayment, isTrue);
    });

    test('blocks creating payment before eligibility is confirmed', () {
      final session = _session(status: CheckoutStatus.checkingEligibility, medicationCount: 1);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canCreatePayment, isFalse);
    });
    test('allows confirming payment only while awaiting confirmation', () {
      final session = _session(
        status: CheckoutStatus.awaitingConfirmation,
        medicationCount: 1,
        remoteCheckoutId: 'remote-001',
      );
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canConfirmPayment, isTrue);
    });
    test('blocks confirming payment when the remote checkout id is missing', () {
      final session = _session(status: CheckoutStatus.awaitingConfirmation, remoteCheckoutId: null);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.canConfirmPayment, isFalse);
    });
  });
  group('feedback', () {
    test('reports success with the remote checkout id when the checkout is paid', () {
      final session = _session(status: CheckoutStatus.paid, remoteCheckoutId: 'remote-001');
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.feedback, isA<SuccessFeedback>());
      expect((viewState.feedback as SuccessFeedback).checkoutId, 'remote-001');
    });

    test('reports no feedback when there is no status message', () {
      final session = _session(statusMessage: null);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.feedback, isA<NoFeedback>());
    });

    test('reports a recoverable failure while the failure can be retried', () {
      final session = _session(
        status: CheckoutStatus.recoverableFailure,
        statusMessage: 'Retryable error',
      );
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.feedback, isA<RecoverableFailure>());
      expect((viewState.feedback as RecoverableFailure).message, 'Retryable error');
    });
    test('reports a permanent failure for a message on a terminal status', () {
      final session = _session(status: CheckoutStatus.failed, statusMessage: 'Terminal error');
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.feedback, isA<PermanentFailure>());
      expect((viewState.feedback as PermanentFailure).message, 'Terminal error');
    });

    test('reports no success when the checkout is paid without a remote checkout id', () {
      final session = _session(status: CheckoutStatus.paid, remoteCheckoutId: null);
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.feedback, isA<NoFeedback>());
    });
  });
  group('progress', () {
    test('carries the step and label produced by the progress selector', () {
      final session = _session();
      final viewState = CheckoutViewState.fromSession(session);

      expect(viewState.currentStep, selectCheckoutProgress(session).currentStep);
      expect(viewState.stepLabel, selectCheckoutProgress(session).label);
    });
  });
  group('equality', () {
    test('treats two states built from the same session as equal', () {
      final session = _session();
      final viewState1 = CheckoutViewState.fromSession(session);
      final viewState2 = CheckoutViewState.fromSession(session);

      expect(viewState1, equals(viewState2));
    });

    test('agrees on hash code for two states built from the same session', () {
      final session = _session();
      final viewState1 = CheckoutViewState.fromSession(session);
      final viewState2 = CheckoutViewState.fromSession(session);

      expect(viewState1.hashCode, equals(viewState2.hashCode));
    });

    test('separates states that differ in a single field', () {
      final session1 = _session(status: CheckoutStatus.collectingMedication);
      final session2 = _session(status: CheckoutStatus.paid);
      final viewState1 = CheckoutViewState.fromSession(session1);
      final viewState2 = CheckoutViewState.fromSession(session2);

      expect(viewState1, isNot(equals(viewState2)));
    });
    test('separates recoverable and permanent failures carrying the same message', () {
      const message = 'Falha ao criar o checkout.';
      const recoverableFailure = RecoverableFailure(message);
      const permanentFailure = PermanentFailure(message);

      // As duas direções, e isso não é redundância. O matcher `equals` avalia
      // `esperado == real`, então uma asserção só exercita o `==` de um dos
      // lados: quebrar o `==` de `RecoverableFailure` mantinha este teste
      // verde. `==` não é simétrico por construção, e é preciso dizer isso.
      expect(recoverableFailure, isNot(permanentFailure));
      expect(permanentFailure, isNot(recoverableFailure));
    });
  });
}

CheckoutSession _session({
  CheckoutStatus status = CheckoutStatus.collectingMedication,
  int medicationCount = 0,
  String? remoteCheckoutId,
  String? statusMessage,
  CheckoutStatus? retryTargetStatus,
}) {
  return CheckoutSession(
    id: 'session-001',
    availableBalanceInCents: 25000,
    prescription: const Prescription(reference: 'RX-001'),
    medications: List.generate(
      medicationCount,
      (index) => Medication(
        ean: '789100000001$index',
        name: 'Medicamento demonstrativo',
        unitPriceInCents: 2500,
      ),
    ),
    status: status,
    remoteCheckoutId: remoteCheckoutId,
    statusMessage: statusMessage,
    retryTargetStatus: retryTargetStatus,
  );
}
