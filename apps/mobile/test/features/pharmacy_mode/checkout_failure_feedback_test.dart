import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('shows an accessible message and retries a recoverable failure', (
    tester,
  ) async {
    final cubit = CheckoutCubit(
      initialSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 25000,
        prescription: const Prescription(reference: 'RX-001'),
        medications: const [],
        status: CheckoutStatus.recoverableFailure,
        retryTargetStatus: CheckoutStatus.creatingPayment,
        statusMessage: 'Falha ao criar o checkout.',
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
      tester.getSemantics(find.text('Falha ao criar o checkout.')),
      matchesSemantics(label: 'Falha ao criar o checkout.', isLiveRegion: true),
    );

    expect(find.text('Falha ao criar o checkout.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(cubit.state.status, CheckoutStatus.creatingPayment);
    expect(cubit.state.retryTargetStatus, isNull);
    expect(cubit.state.statusMessage, isNull);
  });
  testWidgets('shows a permanent failure without retry action', (tester) async {
    final cubit = CheckoutCubit(
      initialSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: 25000,
        prescription: const Prescription(reference: 'RX-001'),
        medications: const [],
        status: CheckoutStatus.failed,
        statusMessage: 'Não foi possível concluir a compra.',
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

    expect(find.text('Não foi possível concluir a compra.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });
}
