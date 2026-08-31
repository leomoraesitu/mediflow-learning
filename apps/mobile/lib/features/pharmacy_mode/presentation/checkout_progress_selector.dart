import 'package:checkout_domain/checkout_domain.dart';

typedef CheckoutProgressData = ({int currentStep, String label});

CheckoutProgressData selectCheckoutProgress(CheckoutSession session) {
  final progressStatus = session.status == CheckoutStatus.recoverableFailure
      ? session.retryTargetStatus
      : session.status;

  return switch (progressStatus) {
    CheckoutStatus.validatingPrescription ||
    CheckoutStatus.checkingEligibility => (
      currentStep: 2,
      label: 'Validação da compra',
    ),
    CheckoutStatus.creatingPayment => (
      currentStep: 3,
      label: 'Criação do pagamento',
    ),
    CheckoutStatus.awaitingConfirmation ||
    CheckoutStatus.paid => (currentStep: 4, label: 'Confirmação do pagamento'),
    _ => (currentStep: 1, label: 'Leitura do medicamento'),
  };
}
