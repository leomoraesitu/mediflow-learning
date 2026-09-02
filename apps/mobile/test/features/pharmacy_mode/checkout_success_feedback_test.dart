import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('shows success feedback when checkout is paid', (tester) async {
    final cubit = CheckoutCubit(
      initialSession: CheckoutSession(
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
        remoteCheckoutId: 'demo-checkout-001',
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

    expect(
      tester.getSemantics(find.text('Pagamento confirmado')),
      matchesSemantics(label: 'Pagamento confirmado', isLiveRegion: true),
    );

    expect(find.text('Pagamento confirmado'), findsOneWidget);
    expect(find.text('Checkout demo-checkout-001 concluído.'), findsOneWidget);
    expect(find.text('Confirmar pagamento'), findsNothing);
  });
}
