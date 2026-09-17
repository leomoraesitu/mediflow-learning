import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/pending_sync_indicator.dart';
import 'package:mediflow_mobile/main.dart';

import 'config/fake_auth_gateway.dart';

void main() {
  testWidgets('shows the pending sync indicator on the benefits screen', (tester) async {
    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final gateway = _autenticado();
    addTearDown(gateway.dispose);

    // Um esboço, e não o fluxo do Drift: `testWidgets` roda num relógio falso,
    // e as consultas reativas do Drift dependem de assincronia real que o
    // `pump` não avança — o teste trava. O escopo por usuário no banco tem
    // cobertura própria em `checkout_database_test.dart`; aqui o que importa é
    // que a tela pergunte pelo usuário certo, e uma vez só.
    String? uidPedido;
    var vezesPedido = 0;

    MainApp construirApp({Color? semente}) => MainApp(
      authGateway: gateway,
      database: database,
      checkoutRepository: OutboxCheckoutRepository(
        inner: DemoCheckoutRepository(),
        database: database,
        authGateway: gateway,
      ),
      prescriptionRepository: const DemoPrescriptionRepository(),
      medicationRepository: const DemoMedicationRepository(),
      settings: const StaticOperationalSettings(maintenanceMode: false),
      hasPendingSync: (uid) {
        uidPedido = uid;
        vezesPedido++;
        return Stream<bool>.value(true);
      },
    );

    await tester.pumpWidget(construirApp());
    await tester.pump();

    expect(find.byType(PendingSyncIndicator), findsOneWidget);
    expect(find.text(PendingSyncIndicator.message), findsOneWidget);

    // O `uid` vem do portão, não de um literal dentro da tela.
    expect(uidPedido, 'usuario-de-teste');

    // Reconstruir o *pai*, e não só bombar: o `StreamBuilder` do indicador
    // reconstrói a si mesmo, então o `build` da tela não roda de novo sozinho.
    // Com o fluxo criado dentro do `build`, esta reconstrução produziria um
    // fluxo novo, o `StreamBuilder` reassinaria, e cada volta vazaria uma
    // consulta de banco.
    await tester.pumpWidget(construirApp());
    await tester.pump();

    expect(vezesPedido, 1);
  });
}

/// Um gateway já autenticado: este teste verifica uma tela que fica depois do
/// portão, e não o portão em si. Sem uma sessão, ele veria a tela de entrada.
FakeAuthGateway _autenticado() {
  return FakeAuthGateway()
    ..currentUserValue = const AuthUser(uid: 'usuario-de-teste', isAnonymous: false);
}
