import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/pending_sync_indicator.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('shows the pending sync indicator on the benefits screen', (tester) async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final hasPendingSync = Stream<bool>.value(true);

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
        settings: const StaticOperationalSettings(maintenanceMode: false),
        hasPendingSync: hasPendingSync,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PendingSyncIndicator), findsOneWidget);
    expect(find.text(PendingSyncIndicator.message), findsOneWidget);
  });
}
