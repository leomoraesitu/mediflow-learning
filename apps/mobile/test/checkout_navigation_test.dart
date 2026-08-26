import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('abre o Modo Farmácia a partir da tela de benefícios', (
    tester,
  ) async {
    final pharmacyModePage = find.byType(PharmacyModePage);
    final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');

    await tester.pumpWidget(const MainApp());

    expect(find.text('MediFlow'), findsOneWidget);
    expect(pharmacyModePage, findsNothing);
    expect(openPharmacyModeButton, findsOneWidget);

    await tester.tap(openPharmacyModeButton);
    await tester.pumpAndSettle();

    expect(pharmacyModePage, findsOneWidget);
    expect(find.byType(CheckoutProgressIndicator), findsOneWidget);
  });

  testWidgets('descarta o contador ao sair e reabrir o Modo Farmácia', (
    tester,
  ) async {
    final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');
    final readingSimulation = find.text('Simular leitura');
    final backButton = find.byType(BackButton);

    await tester.pumpWidget(const MainApp());

    await tester.tap(openPharmacyModeButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'RX-001');
    await tester.enterText(find.byType(TextFormField).at(1), '7891000000011');

    await tester.ensureVisible(readingSimulation);
    await tester.pumpAndSettle();

    await tester.tap(readingSimulation);
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(1), '7891000000011');

    await tester.tap(readingSimulation);
    await tester.pump();

    expect(find.text('2 medicamentos lidos'), findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(BenefitsHomePage), findsOneWidget);
    expect(find.byType(PharmacyModePage), findsNothing);

    await tester.tap(openPharmacyModeButton);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum medicamento lido'), findsOneWidget);
  });
}
