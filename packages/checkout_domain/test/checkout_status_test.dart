import 'package:checkout_domain/checkout_domain.dart';
import 'package:test/test.dart';

void main() {
  test('identifies terminal statuses', () {
    final terminalStatuses = [
      CheckoutStatus.maintenance,
      CheckoutStatus.failed,
      CheckoutStatus.paid,
    ];
    for (final status in terminalStatuses) {
      expect(status.isTerminal, isTrue);
    }
  });

  test('identifies non-terminal statuses', () {
    final nonTerminalStatuses = [
      CheckoutStatus.collectingMedication,
      CheckoutStatus.validatingPrescription,
      CheckoutStatus.checkingEligibility,
      CheckoutStatus.creatingPayment,
      CheckoutStatus.awaitingConfirmation,
      CheckoutStatus.recoverableFailure,
    ];
    for (final status in nonTerminalStatuses) {
      expect(status.isTerminal, isFalse);
    }
  });
}
