import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('checks medication eligibility from the current checkout step', (
    tester,
  ) async {
    const medication = Medication(
      ean: '7891000000011',
      name: 'Medicamento demonstrativo',
      unitPriceInCents: 2500,
    );

    final cubit = CheckoutCubit(
      initialSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 25000,
        prescription: const Prescription(reference: 'RX-001'),
        medications: const [medication],
        status: CheckoutStatus.checkingEligibility,
      ),
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: const DemoPrescriptionRepository(),
      medicationRepository: const DemoMedicationRepository(),
      checkoutRepository: DemoCheckoutRepository(),
    );

    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CheckoutCubit>.value(
          value: cubit,
          child: const PharmacyModePage(),
        ),
      ),
    );

    expect(find.text('Verificar elegibilidade'), findsOneWidget);

    await tester.ensureVisible(find.text('Verificar elegibilidade'));
    await tester.tap(find.text('Verificar elegibilidade'));
    await tester.pumpAndSettle();

    expect(cubit.state.status, CheckoutStatus.creatingPayment);
    expect(find.text('Etapa 3 de 4: Criação do pagamento'), findsOneWidget);
  });
  testWidgets('creates the remote checkout from the payment step', (
    tester,
  ) async {
    const medication = Medication(
      ean: '7891000000011',
      name: 'Medicamento demonstrativo',
      unitPriceInCents: 2500,
    );

    final cubit = CheckoutCubit(
      initialSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 25000,
        prescription: const Prescription(reference: 'RX-001'),
        medications: const [medication],
        status: CheckoutStatus.creatingPayment,
      ),
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: const DemoPrescriptionRepository(),
      medicationRepository: const DemoMedicationRepository(),
      checkoutRepository: DemoCheckoutRepository(),
    );

    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CheckoutCubit>.value(
          value: cubit,
          child: const PharmacyModePage(),
        ),
      ),
    );

    expect(find.text('Criar pagamento'), findsOneWidget);

    await tester.ensureVisible(find.text('Criar pagamento'));
    await tester.tap(find.text('Criar pagamento'));
    await tester.pumpAndSettle();

    expect(cubit.state.status, CheckoutStatus.awaitingConfirmation);
    expect(cubit.state.remoteCheckoutId, 'demo-checkout-001');
    expect(find.text('Etapa 4 de 4: Confirmação do pagamento'), findsOneWidget);
  });
  testWidgets(
    'confirms the remote checkout from the awaiting confirmation step',
    (tester) async {
      const medication = Medication(
        ean: '7891000000011',
        name: 'Medicamento demonstrativo',
        unitPriceInCents: 2500,
      );
      final checkoutRepository = DemoCheckoutRepository();

      final cubit = CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: const Prescription(reference: 'RX-001'),
          medications: const [medication],
          status: CheckoutStatus.creatingPayment,
          remoteCheckoutId: 'demo-checkout-001',
        ),
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const DemoPrescriptionRepository(),
        medicationRepository: const DemoMedicationRepository(),
        checkoutRepository: checkoutRepository,
      );

      await cubit.createCheckout();

      expect(cubit.state.status, CheckoutStatus.awaitingConfirmation);
      expect(cubit.state.remoteCheckoutId, 'demo-checkout-001');

      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<CheckoutCubit>.value(
            value: cubit,
            child: const PharmacyModePage(),
          ),
        ),
      );

      expect(find.text('Confirmar pagamento'), findsOneWidget);

      await tester.ensureVisible(find.text('Confirmar pagamento'));
      await tester.tap(find.text('Confirmar pagamento'));
      await tester.pumpAndSettle();

      expect(cubit.state.status, CheckoutStatus.paid);
      expect(cubit.state.remoteCheckoutId, 'demo-checkout-001');
      expect(
        find.text('Etapa 4 de 4: Confirmação do pagamento'),
        findsOneWidget,
      );
    },
  );
}
