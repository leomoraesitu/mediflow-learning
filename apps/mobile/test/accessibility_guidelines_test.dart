import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/main.dart';

import 'config/fake_auth_gateway.dart';

/// As diretrizes de acessibilidade, nas duas telas e nos dois temas.
///
/// O eixo do brilho existe porque o tema escuro não é o claro invertido: cada
/// papel do `ColorScheme` é rederivado da semente, e um par que contrasta num
/// não contrasta necessariamente no outro.
///
/// Uma medição que vale guardar, para não se esperar do eixo escuro mais do
/// que ele dá: o defeito de `AppBarTheme.titleTextStyle` — que é aplicado por
/// substituição, e preenchê-lo apaga a cor que o `AppBar` forneceria — é
/// **defeito só no tema claro**. O título sem cor renderiza claro, o que
/// contrasta sobre superfície escura e não contrasta sobre a clara. Reintroduzir
/// o defeito deixa vermelhas as duas telas no claro e nenhuma no escuro.
///
/// `textContrastGuideline` lê a cor **computada** a partir da semântica, então
/// ele é categórico: uma violação vale independentemente de quantos pixels
/// ocupa. É a diferença para o golden de `sign_in_dark_golden_test.dart`, que
/// compara imagens sob tolerância de 3% e por isso não enxerga texto fino nem
/// borda de 1px. Os dois instrumentos cobrem coisas diferentes de propósito.
///
/// O que **nenhum** dos dois cobre: contraste do que não é texto — a borda de
/// um `TextFormField`, o traço de um indicador de progresso. Essa lacuna é
/// conhecida e continua aberta.
void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required Brightness brightness,
    required bool authenticated,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final database = CheckoutDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final authGateway = authenticated ? _autenticado() : FakeAuthGateway();
    addTearDown(authGateway.dispose);

    await tester.pumpWidget(
      MainApp(
        hasPendingSync: (_) => const Stream<bool>.empty(),
        authGateway: authGateway,
        database: database,
        checkoutRepository: OutboxCheckoutRepository(
          authGateway: authGateway,
          inner: DemoCheckoutRepository(),
          database: database,
        ),
        prescriptionRepository: const DemoPrescriptionRepository(),
        medicationRepository: const DemoMedicationRepository(),
        settings: StaticOperationalSettings(),
      ),
    );

    if (!authenticated) {
      // O evento explícito de "ninguém autenticado". Sem ele o portão fica em
      // `ConnectionState.waiting` com dado nulo — um `CircularProgressIndicator`
      // permanente, e `pumpAndSettle` esperando uma animação que nunca termina.
      await authGateway.signOut();
    }

    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('the benefits screen meets Android guidelines in the $theme theme', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      try {
        await pumpApp(tester, brightness: brightness, authenticated: true);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('the sign in screen meets Android guidelines in the $theme theme', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      try {
        // Sem sessão, o portão abre a tela de entrada. É a tela com mais
        // elementos que só quebram no escuro, e até aqui nenhuma diretriz a
        // percorria em tema nenhum.
        await pumpApp(tester, brightness: brightness, authenticated: false);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semanticsHandle.dispose();
      }
    });
  }
}

/// Um gateway já autenticado: estes testes verificam telas que ficam depois do
/// portão, e não o portão em si. Sem uma sessão, todos veriam a tela de
/// entrada.
FakeAuthGateway _autenticado() {
  return FakeAuthGateway()
    ..currentUserValue = const AuthUser(uid: 'usuario-de-teste', isAnonymous: false);
}
