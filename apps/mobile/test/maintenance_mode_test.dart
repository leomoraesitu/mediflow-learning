import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets(
    'maintenanceMode true deve exibir mensagem e impedir acesso ao Modo Farmácia',
    (tester) async {
      final pharmacyModePage = find.byType(PharmacyModePage);
      final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');
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
          settings: const StaticOperationalSettings(
            maintenanceMode: true,
            maintenanceMessage: 'Manutenção programada até 12h.',
          ),
        ),
      );

      expect(find.text('MediFlow'), findsOneWidget);
      expect(pharmacyModePage, findsNothing);
      expect(openPharmacyModeButton, findsOneWidget);

      expect(find.text('Manutenção programada até 12h.'), findsOneWidget);

      await tester.tap(openPharmacyModeButton);
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Iniciar Modo Farmácia'),
      );
      expect(button.enabled, isFalse);

      expect(pharmacyModePage, findsNothing);
      expect(find.byType(CheckoutProgressIndicator), findsNothing);
    },
  );
  testWidgets(
    'StaticOperationalSettings padrão deve ocultar a mensagem e habilitar o botão do Modo Farmácia',
    (tester) async {
      final pharmacyModePage = find.byType(PharmacyModePage);
      final openPharmacyModeButton = find.text('Iniciar Modo Farmácia');
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
          settings: const StaticOperationalSettings(),
        ),
      );

      expect(find.text('MediFlow'), findsOneWidget);
      expect(pharmacyModePage, findsNothing);
      expect(openPharmacyModeButton, findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Iniciar Modo Farmácia'),
      );
      expect(button.enabled, isTrue);

      await tester.tap(openPharmacyModeButton);
      await tester.pumpAndSettle();

      expect(find.text('Manutenção programada até 12h.'), findsNothing);

      expect(pharmacyModePage, findsOneWidget);
      expect(find.byType(CheckoutProgressIndicator), findsOneWidget);
    },
  );
}
