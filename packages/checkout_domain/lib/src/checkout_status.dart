/// Enum representing the different statuses of the checkout process.
enum CheckoutStatus {
  collectingMedication,
  validatingPrescription,
  checkingEligibility,
  creatingPayment,
  awaitingConfirmation,
  recoverableFailure,
  maintenance,
  paid,
}
