import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_progress_selector.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('shows eligibility validation as checkout step 2', (
    tester,
  ) async {
    // Arrange: CheckoutCubit iniciado em checkingEligibility.ß
    const prescription = Prescription(reference: 'Teste Prescription');

    const medication = Medication(
      ean: '7891000000011',
      name: 'Medicamento demonstrativo',
      unitPriceInCents: 2500,
    );

    final cubit = CheckoutCubit(
      initialSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 25000,
        prescription: prescription,
        medications: [medication],
        status: CheckoutStatus.checkingEligibility,
      ),
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: DemoPrescriptionRepository(),
      medicationRepository: DemoMedicationRepository(),
      checkoutRepository: DemoCheckoutRepository(),
    );

    addTearDown(cubit.close);

    // Act: renderizar PharmacyModePage com BlocProvider.value.
    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CheckoutCubit>.value(
          value: cubit,
          child: const PharmacyModePage(),
        ),
      ),
    );

    // Assert:
    expect(find.text('Etapa 2 de 4: Validação da compra'), findsOneWidget);
  });

  test('maps checkout creation to step 3', () {
    final session = CheckoutSession(
      id: 'session-001',
      availableBalanceInCents: 25000,
      prescription: const Prescription(reference: 'RX-001'),
      medications: const [
        Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ],
      status: CheckoutStatus.creatingPayment,
    );

    expect(selectCheckoutProgress(session), (
      currentStep: 3,
      label: 'Criação do pagamento',
    ));
  });

  test('maps payment confirmation to step 4', () {
    final session = CheckoutSession(
      id: 'session-001',
      availableBalanceInCents: 25000,
      prescription: const Prescription(reference: 'RX-001'),
      medications: const [
        Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ],
      status: CheckoutStatus.awaitingConfirmation,
      remoteCheckoutId: 'remote-checkout-001',
    );

    expect(selectCheckoutProgress(session), (
      currentStep: 4,
      label: 'Confirmação do pagamento',
    ));
  });
  test('maps checkout recoverable failure to step 3', () {
    final session = CheckoutSession(
      id: 'session-001',
      availableBalanceInCents: 25000,
      prescription: const Prescription(reference: 'RX-001'),
      medications: const [
        Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ],
      status: CheckoutStatus.recoverableFailure,
      retryTargetStatus: CheckoutStatus.creatingPayment,
    );

    expect(selectCheckoutProgress(session), (
      currentStep: 3,
      label: 'Criação do pagamento',
    ));
  });
  test('maps payment confirmation paid to step 4', () {
    final session = CheckoutSession(
      id: 'session-001',
      availableBalanceInCents: 25000,
      prescription: const Prescription(reference: 'RX-001'),
      medications: const [
        Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ],
      status: CheckoutStatus.paid,
      remoteCheckoutId: 'remote-checkout-001',
    );

    expect(selectCheckoutProgress(session), (
      currentStep: 4,
      label: 'Confirmação do pagamento',
    ));
  });
}
