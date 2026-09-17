import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/main.dart';

import 'config/fake_auth_gateway.dart';

import 'package:mediflow_mobile/config/auth_user.dart';

/// Goldens da tela de benefícios.
///
/// Cobrem a única categoria de defeito que os outros testes não enxergam:
/// posição e distribuição de espaço. Na Aula 43, envolver o cartão numa
/// `Column` fez o `Center` perder o espaço para centralizar e o cartão subiu
/// 82 px — com 101 testes verdes, porque todos verificam presença.
///
/// A tela foi escolhida por ser estável: ela não muda há dez aulas. Um golden
/// do `PharmacyModePage`, que ganhou botão novo em quatro das últimas dez,
/// precisaria ser regravado toda aula — e regravar vira reflexo, que é como um
/// golden deixa de testar qualquer coisa.
void main() {
  // A superfície é fixada de propósito. O padrão do `flutter test` é 800x600,
  // e depender dele faria todos os goldens falharem de uma vez no dia em que
  // esse padrão mudasse — por um motivo que não estaria em commit nenhum.
  // 390x844 é uma proporção de telefone, o que mantém a imagem inspecionável
  // por olho humano: metade do valor de um golden é alguém conseguir abrir o
  // arquivo e ver o que ele mostra.
  const surface = Size(390, 844);

  Future<void> pumpBenefitsHome(WidgetTester tester, {required bool pending}) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      MainApp(
        authGateway: _autenticado(),
        database: database,
        checkoutRepository: OutboxCheckoutRepository(
          inner: DemoCheckoutRepository(),
          database: database,
        ),
        prescriptionRepository: const DemoPrescriptionRepository(),
        medicationRepository: const DemoMedicationRepository(),
        settings: const StaticOperationalSettings(),
        hasPendingSync: Stream<bool>.value(pending),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('benefits home without pending sync', (tester) async {
    await pumpBenefitsHome(tester, pending: false);

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/benefits_home.png'));
  });

  testWidgets('benefits home with pending sync', (tester) async {
    await pumpBenefitsHome(tester, pending: true);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/benefits_home_pending_sync.png'),
    );
  });
}

/// Um gateway já autenticado: estes testes verificam telas que ficam depois do
/// portão, e não o portão em si. Sem uma sessão, todos veriam a tela de
/// entrada.
FakeAuthGateway _autenticado() {
  return FakeAuthGateway()
    ..currentUserValue = const AuthUser(uid: 'usuario-de-teste', isAnonymous: false);
}
