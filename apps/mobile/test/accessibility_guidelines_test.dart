import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('meets Android accessibility guidelines', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final database = CheckoutDatabase(NativeDatabase.memory());
    final checkoutRepository = OutboxCheckoutRepository(
      inner: DemoCheckoutRepository(),
      database: database,
    );
    final settings = StaticOperationalSettings();

    try {
      await tester.pumpWidget(
        MainApp(
          database: database,
          checkoutRepository: checkoutRepository,
          prescriptionRepository: const DemoPrescriptionRepository(),
          medicationRepository: const DemoMedicationRepository(),
          settings: settings,
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semanticsHandle.dispose();
    }
  });
}
