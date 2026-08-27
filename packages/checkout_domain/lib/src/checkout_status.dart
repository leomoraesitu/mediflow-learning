/// Enum representing the different statuses of the checkout process.
enum CheckoutStatus {
  collectingMedication,
  validatingPrescription,
  checkingEligibility,
  creatingPayment,
  awaitingConfirmation,
  recoverableFailure,
  maintenance,
  failed,
  paid,
}

extension CheckoutStatusProperties on CheckoutStatus {
  bool get isTerminal {
    return switch (this) {
      CheckoutStatus.collectingMedication ||
      CheckoutStatus.validatingPrescription ||
      CheckoutStatus.checkingEligibility ||
      CheckoutStatus.creatingPayment ||
      CheckoutStatus.awaitingConfirmation ||
      CheckoutStatus.recoverableFailure => false,
      CheckoutStatus.maintenance ||
      CheckoutStatus.failed ||
      CheckoutStatus.paid => true,
    };
  }
}
