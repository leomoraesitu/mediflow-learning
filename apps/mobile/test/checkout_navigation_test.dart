import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/medication_counter_content.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/benefits/presentation/benefits_home_page.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_progress_indicator.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/pharmacy_mode_page.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('abre o Modo Farmácia a partir da tela de benefícios', (tester) async {
    final pharmacyModePage = find.byType(PharmacyModePage);
    final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');
    final database = CheckoutDatabase(NativeDatabase.memory());
    final checkoutRepository = OutboxCheckoutRepository(
      inner: DemoCheckoutRepository(),
      database: database,
    );
    final settings = StaticOperationalSettings();

    await tester.pumpWidget(
      MainApp(
        database: database,
        checkoutRepository: checkoutRepository,
        prescriptionRepository: const DemoPrescriptionRepository(),
        medicationRepository: const DemoMedicationRepository(),
        settings: settings,
      ),
    );

    expect(find.text('MediFlow'), findsOneWidget);
    expect(pharmacyModePage, findsNothing);
    expect(openPharmacyModeButton, findsOneWidget);

    await tester.tap(openPharmacyModeButton);
    await tester.pumpAndSettle();

    expect(pharmacyModePage, findsOneWidget);
    expect(find.byType(CheckoutProgressIndicator), findsOneWidget);
  });

  testWidgets('fecha o CheckoutCubit ao sair do Modo Farmácia', (tester) async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    final checkoutRepository = OutboxCheckoutRepository(
      inner: DemoCheckoutRepository(),
      database: database,
    );

    await tester.pumpWidget(
      MainApp(
        database: database,
        checkoutRepository: checkoutRepository,
        prescriptionRepository: const DemoPrescriptionRepository(),
        medicationRepository: const DemoMedicationRepository(),
        settings: StaticOperationalSettings(),
      ),
    );

    await tester.tap(find.text('Iniciar Modo Farmácia'));
    await tester.pumpAndSettle();

    // O cubit nasce dentro de `_openPharmacyMode`, privado. A referência só
    // pode ser obtida pela árvore, enquanto a rota ainda existe.
    final cubit = tester.element(find.byType(MedicationCounterContent)).read<CheckoutCubit>();

    expect(cubit.isClosed, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // `BlocProvider.value` não fecha o que recebe: quem cria é quem fecha.
    expect(cubit.isClosed, isTrue);
  });

  testWidgets('mantém o contador ao sair e reabrir o Modo Farmácia', (tester) async {
    final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');
    final readingSimulation = find.text('Simular leitura');
    final backButton = find.byType(BackButton);

    final database = CheckoutDatabase(NativeDatabase.memory());
    final checkoutRepository = OutboxCheckoutRepository(
      inner: DemoCheckoutRepository(),
      database: database,
    );
    final settings = StaticOperationalSettings();

    await tester.pumpWidget(
      MainApp(
        database: database,
        checkoutRepository: checkoutRepository,
        prescriptionRepository: const DemoPrescriptionRepository(),
        medicationRepository: const DemoMedicationRepository(),
        settings: settings,
      ),
    );

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
    expect(find.text('2 medicamentos lidos'), findsOneWidget);
  });
}
