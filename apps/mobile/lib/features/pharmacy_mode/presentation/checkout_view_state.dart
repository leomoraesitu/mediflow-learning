import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_progress_selector.dart';

/// O que a tela mostra sobre o resultado da última transição.
///
/// É `sealed` para que o `switch` que a renderiza seja exaustivo: acrescentar
/// uma variante nova quebra a compilação em vez de cair num caso silencioso.
sealed class CheckoutFeedback {
  const CheckoutFeedback();
}

final class NoFeedback extends CheckoutFeedback {
  const NoFeedback();

  @override
  bool operator ==(Object other) => other is NoFeedback;

  @override
  int get hashCode => (NoFeedback).hashCode;
}

final class SuccessFeedback extends CheckoutFeedback {
  final String checkoutId;

  const SuccessFeedback(this.checkoutId);

  @override
  bool operator ==(Object other) => other is SuccessFeedback && other.checkoutId == checkoutId;

  @override
  int get hashCode => Object.hash(SuccessFeedback, checkoutId);
}

final class RecoverableFailure extends CheckoutFeedback {
  final String message;

  const RecoverableFailure(this.message);

  @override
  bool operator ==(Object other) => other is RecoverableFailure && other.message == message;

  @override
  int get hashCode => Object.hash(RecoverableFailure, message);
}

final class PermanentFailure extends CheckoutFeedback {
  final String message;

  const PermanentFailure(this.message);

  @override
  bool operator ==(Object other) => other is PermanentFailure && other.message == message;

  @override
  int get hashCode => Object.hash(PermanentFailure, message);
}

/// Tudo o que a tela do Modo Farmácia precisa saber, já decidido.
///
/// A View não recebe `CheckoutSession` e não importa o pacote de domínio: ela
/// recebe `canConfirmPayment`, não `status`. Isso mantém a regra de
/// apresentação de um lado só da fronteira.
///
/// A igualdade é de valor, e isso não é estilo. O `Cubit` suprime `emit` de
/// estado repetido comparando com `==`; como `CheckoutSession` não declara
/// igualdade, essa supressão nunca atuou até aqui.
final class CheckoutViewState {
  final int currentStep;
  final int totalSteps;
  final String stepLabel;
  final String medicationLabel;
  final int medicationCount;
  final bool canScan;
  final bool canSubmit;
  final bool canCheckEligibility;
  final bool canCreatePayment;
  final bool canConfirmPayment;
  final CheckoutFeedback feedback;
  final bool isBusy;

  const CheckoutViewState({
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabel,
    required this.medicationLabel,
    required this.medicationCount,
    required this.canScan,
    required this.canSubmit,
    required this.canCheckEligibility,
    required this.canCreatePayment,
    required this.canConfirmPayment,
    required this.feedback,
    this.isBusy = false,
  });

  /// O único ponto do arquivo que conhece o domínio.
  ///
  /// Lê apenas os campos da sessão e decide aqui. Nenhuma pergunta de
  /// apresentação é delegada ao domínio: se `CheckoutSession` ganhasse um
  /// `canConfirmPayment`, o pacote puro passaria a saber que existe um botão.
  factory CheckoutViewState.fromSession(CheckoutSession session) {
    final progress = selectCheckoutProgress(session);
    final medicationCount = session.medications.length;

    return CheckoutViewState(
      currentStep: progress.currentStep,
      totalSteps: 4,
      stepLabel: progress.label,
      medicationLabel: _medicationLabelFor(medicationCount),
      medicationCount: medicationCount,
      // `MedicationScanned` só tem transição a partir de
      // `collectingMedication`; habilitar a leitura fora dela levaria a
      // `InvalidCheckoutTransitionException`.
      canScan: session.status == CheckoutStatus.collectingMedication,
      canSubmit: session.status == CheckoutStatus.collectingMedication && medicationCount > 0,
      canCheckEligibility:
          session.status == CheckoutStatus.checkingEligibility && medicationCount > 0,
      canCreatePayment: session.status == CheckoutStatus.creatingPayment,
      canConfirmPayment:
          session.status == CheckoutStatus.awaitingConfirmation && session.remoteCheckoutId != null,
      feedback: _feedbackFor(session),
    );
  }

  static String _medicationLabelFor(int count) {
    return switch (count) {
      0 => 'Nenhum medicamento lido',
      1 => '1 medicamento lido',
      _ => '$count medicamentos lidos',
    };
  }

  static CheckoutFeedback _feedbackFor(CheckoutSession session) {
    final remoteCheckoutId = session.remoteCheckoutId;

    if (session.status == CheckoutStatus.paid && remoteCheckoutId != null) {
      return SuccessFeedback(remoteCheckoutId);
    }

    final message = session.statusMessage;

    if (message == null) {
      return const NoFeedback();
    }

    if (session.status == CheckoutStatus.recoverableFailure) {
      return RecoverableFailure(message);
    }

    return PermanentFailure(message);
  }

  @override
  bool operator ==(Object other) {
    return other is CheckoutViewState &&
        other.currentStep == currentStep &&
        other.totalSteps == totalSteps &&
        other.stepLabel == stepLabel &&
        other.medicationLabel == medicationLabel &&
        other.medicationCount == medicationCount &&
        other.canScan == canScan &&
        other.canSubmit == canSubmit &&
        other.canCheckEligibility == canCheckEligibility &&
        other.canCreatePayment == canCreatePayment &&
        other.canConfirmPayment == canConfirmPayment &&
        other.feedback == feedback &&
        other.isBusy == isBusy;
  }

  // Lê exatamente a mesma lista de campos do `==`. Se as duas listas
  // divergirem, o defeito só aparece dentro de um `Set` ou de um `Map`.
  @override
  int get hashCode => Object.hash(
    currentStep,
    totalSteps,
    stepLabel,
    medicationLabel,
    medicationCount,
    canScan,
    canSubmit,
    canCheckEligibility,
    canCreatePayment,
    canConfirmPayment,
    feedback,
    isBusy,
  );
}
