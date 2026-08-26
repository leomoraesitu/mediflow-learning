import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('exibe erros e não adiciona medicamento com formulário vazio', (
    tester,
  ) async {
    final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');
    final readingSimulation = find.text('Simular leitura');

    await tester.pumpWidget(const MainApp());

    expect(openPharmacyModeButton, findsOneWidget);
    await tester.tap(openPharmacyModeButton);
    await tester.pumpAndSettle();

    expect(readingSimulation, findsOneWidget);
    await tester.ensureVisible(readingSimulation);
    await tester.pumpAndSettle();

    await tester.tap(readingSimulation);
    await tester.pump();

    expect(find.text('Informe a referência da receita.'), findsOneWidget);
    expect(find.text('Informe o EAN do medicamento.'), findsOneWidget);
    expect(find.text('Nenhum medicamento lido'), findsOneWidget);

    expect(find.text('Medicamento adicionado à compra.'), findsNothing);
  });

  testWidgets('exibe erro quando o EAN não possui 13 dígitos', (tester) async {
    final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');
    final readingSimulation = find.text('Simular leitura');

    await tester.pumpWidget(const MainApp());

    expect(openPharmacyModeButton, findsOneWidget);
    await tester.tap(openPharmacyModeButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'RX-001');
    await tester.enterText(find.byType(TextFormField).at(1), '7891000');

    expect(readingSimulation, findsOneWidget);
    await tester.ensureVisible(readingSimulation);
    await tester.pumpAndSettle();

    await tester.tap(readingSimulation);
    await tester.pump();

    expect(find.text('O EAN deve conter 13 dígitos.'), findsOneWidget);
    expect(find.text('Nenhum medicamento lido'), findsOneWidget);

    expect(find.text('Medicamento adicionado à compra.'), findsNothing);
    expect(find.text('Informe o EAN do medicamento.'), findsNothing);
    expect(find.text('Informe a referência da receita.'), findsNothing);
  });

  testWidgets('preenche o EAN demonstrativo e confirma uma leitura válida', (
    tester,
  ) async {
    final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');
    final readingSimulation = find.text('Simular leitura');

    await tester.pumpWidget(const MainApp());

    expect(openPharmacyModeButton, findsOneWidget);
    await tester.tap(openPharmacyModeButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'RX-001');

    expect(find.text('Usar EAN de demonstração'), findsOneWidget);
    await tester.tap(find.text('Usar EAN de demonstração'));
    await tester.pump();

    final eanField = find.byType(TextFormField).at(1);
    final eanWidget = tester.widget<TextFormField>(eanField);

    expect(eanWidget.controller?.text, '7891000000011');

    expect(readingSimulation, findsOneWidget);
    await tester.ensureVisible(readingSimulation);
    await tester.pumpAndSettle();

    await tester.tap(readingSimulation);
    await tester.pump();

    expect(find.text('1 medicamento lido'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Medicamento adicionado à compra.'), findsOneWidget);

    expect(eanWidget.controller?.text, isEmpty);

    expect(find.text('Informe a referência da receita.'), findsNothing);
    expect(find.text('Informe o EAN do medicamento.'), findsNothing);
    expect(find.text('O EAN deve conter 13 dígitos.'), findsNothing);
  });
}
