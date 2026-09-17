import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_gate.dart';
import 'package:mediflow_mobile/features/auth/presentation/register_page.dart';
import 'package:mediflow_mobile/features/auth/presentation/sign_in_page.dart';

import '../../../config/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway fakeAuthGateway;

  setUp(() {
    fakeAuthGateway = FakeAuthGateway();
  });

  tearDown(() async {
    await fakeAuthGateway.dispose();
  });

  // `Placeholder` como casa autenticada é o que torna este arquivo um teste do
  // portão, e não da tela de benefícios.
  Future<void> pumpGate(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: AuthGate(authGateway: fakeAuthGateway, authenticatedHome: const Placeholder()),
      ),
    );
  }

  testWidgets('shows a waiting screen before the first auth event', (tester) async {
    // Nenhuma emissão: `connectionState` fica em `waiting`.
    //
    // Sem `pumpAndSettle` — o indicador anima para sempre e ele esperaria uma
    // animação que nunca termina.
    await pumpGate(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
  });

  testWidgets('shows the sign in page when nobody is authenticated', (tester) async {
    await pumpGate(tester);

    // O evento explícito de "ninguém autenticado". É aqui que `connectionState`
    // e `hasData` discordam: o fluxo está ativo, e o dado é nulo. Trocar o
    // discriminador do portão por `!snapshot.hasData` derruba este teste, e
    // só ele.
    await fakeAuthGateway.signOut();
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows the authenticated home when a user is signed in', (tester) async {
    // Arranjado antes de bombar, para exercitar o caminho do `initialData`.
    fakeAuthGateway.currentUserValue = const AuthUser(uid: 'u1', isAnonymous: false);

    await pumpGate(tester);

    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
    // Prova que o `initialData` evitou o quadro de espera: sem ele o spinner
    // apareceria antes da casa, e o teste não perceberia.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('swaps to the authenticated home when the user signs in', (tester) async {
    await pumpGate(tester);
    await fakeAuthGateway.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(SignInPage), findsOneWidget);

    // A transição, que é o trabalho do portão: sem ela, ele poderia estar
    // apenas lendo o `initialData` uma vez e nunca mais ouvindo o fluxo.
    await fakeAuthGateway.signInWithEmail(email: 'alguem@exemplo.test', password: '12345678');
    await tester.pumpAndSettle();

    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
  });

  testWidgets('opens the register screen from the sign in page', (tester) async {
    await pumpGate(tester);
    await fakeAuthGateway.signOut();
    await tester.pumpAndSettle();

    // `TextButton`: na tela de entrada, "Criar conta" é o link secundário.
    await tester.tap(find.widgetWithText(TextButton, 'Criar conta'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });
}
