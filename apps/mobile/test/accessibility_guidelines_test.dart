import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/main.dart';

import 'config/fake_auth_gateway.dart';

import 'package:mediflow_mobile/config/auth_user.dart';

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
          authGateway: _autenticado(),
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

/// Um gateway já autenticado: estes testes verificam telas que ficam depois do
/// portão, e não o portão em si. Sem uma sessão, todos veriam a tela de
/// entrada.
FakeAuthGateway _autenticado() {
  return FakeAuthGateway()
    ..currentUserValue = const AuthUser(uid: 'usuario-de-teste', isAnonymous: false);
}
