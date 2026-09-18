import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/main.dart';

import '../../../config/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway fakeAuthGateway;
  setUp(() {
    fakeAuthGateway = FakeAuthGateway()
      ..currentUserValue = const AuthUser(uid: 'usuario-de-teste', isAnonymous: false);
  });
  tearDown(() async => await fakeAuthGateway.dispose());

  Future<void> pumpBenefitsHome(WidgetTester tester) async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      MainApp(
        authGateway: fakeAuthGateway,
        database: database,
        checkoutRepository: OutboxCheckoutRepository(
          authGateway: fakeAuthGateway,
          inner: DemoCheckoutRepository(),
          database: database,
        ),
        prescriptionRepository: const DemoPrescriptionRepository(),
        medicationRepository: const DemoMedicationRepository(),
        settings: const StaticOperationalSettings(),
        hasPendingSync: (_) => Stream<bool>.value(false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signs out from the benefits screen', (tester) async {
    await pumpBenefitsHome(tester);

    await tester.tap(find.byIcon(Icons.logout));

    await tester.pumpAndSettle();

    expect(fakeAuthGateway.signOutCalls, 1);
  });

  testWidgets('shows a message when signing out fails', (tester) async {
    fakeAuthGateway.signOutError = const AuthGatewayException('network-request-failed');
    await pumpBenefitsHome(tester);

    await tester.tap(find.byIcon(Icons.logout));

    await tester.pumpAndSettle();

    expect(find.text('Não foi possível sair. Tente novamente.'), findsOneWidget);
  });
}
