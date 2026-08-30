import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('valid scan updates the checkout session used by the screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());

    await tester.tap(find.text('Iniciar Modo Farmácia'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'RX-001');
    await tester.tap(find.text('Usar EAN de demonstração'));
    await tester.pump();

    final readingSimulation = find.text('Simular leitura');

    await tester.ensureVisible(readingSimulation);
    await tester.pumpAndSettle();

    await tester.tap(readingSimulation);
    await tester.pump();

    final contentContext = tester.element(
      find.byType(MedicationCounterContent),
    );
    final checkoutCubit = contentContext.read<CheckoutCubit>();

    expect(checkoutCubit.state.medications, hasLength(1));
    expect(checkoutCubit.state.medications.single.ean, '7891000000011');
    expect(find.text('1 medicamento lido'), findsOneWidget);
  });
}
