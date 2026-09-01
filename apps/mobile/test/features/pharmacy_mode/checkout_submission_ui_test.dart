import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  const medication = Medication(
    ean: '7891000000011',
    name: 'Medicamento demonstrativo',
    unitPriceInCents: 2500,
  );
  testWidgets(
    'submits the prescription and advances checkout to validation step',
    (tester) async {
      final cubit = CheckoutCubit(
        initialSession: CheckoutSession(
          id: 'session-001',
          availableBalanceInCents: 25000,
          prescription: null,
          medications: const [medication],
          status: CheckoutStatus.collectingMedication,
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

      await tester.enterText(find.byType(TextFormField).first, 'RX-001');

      expect(find.text('Validar compra'), findsOneWidget);

      await tester.ensureVisible(find.text('Validar compra'));
      await tester.tap(find.text('Validar compra'));
      await tester.pumpAndSettle();

      expect(cubit.state.prescription?.reference, 'RX-001');
      expect(cubit.state.status, CheckoutStatus.checkingEligibility);
      expect(find.text('Etapa 2 de 4: Validação da compra'), findsOneWidget);
    },
  );
  testWidgets('keeps checkout submission disabled without medications', (
    tester,
  ) async {
    final cubit = CheckoutCubit(
      initialSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 25000,
        prescription: null,
        medications: const [],
        status: CheckoutStatus.collectingMedication,
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

    await tester.enterText(find.byType(TextFormField).first, 'RX-001');

    expect(find.text('Validar compra'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Validar compra'),
    );

    expect(button.onPressed, isNull);
  });
}
