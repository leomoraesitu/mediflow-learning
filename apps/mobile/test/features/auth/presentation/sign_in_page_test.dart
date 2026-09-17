import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:mediflow_mobile/features/auth/presentation/sign_in_page.dart';

import '../../../config/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway fakeAuthGateway;
  late AuthCubit cubit;

  setUp(() {
    fakeAuthGateway = FakeAuthGateway();
    cubit = AuthCubit(authGateway: fakeAuthGateway);
  });

  tearDown(() async {
    await cubit.close();
    await fakeAuthGateway.dispose();
  });

  Future<void> pumpSignIn(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthCubit>.value(
          value: cubit,
          child: SignInPage(onRegisterRequested: () {}),
        ),
      ),
    );
  }

  Future<void> fillValidCredentials(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'alguem@exemplo.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'senha-secreta');
  }

  // Parece trivial e não é: a primeira versão desta tela lançava
  // `ProviderNotFoundException` ao construir, e o analisador não pegava.
  testWidgets('builds without a provider lookup failure', (tester) async {
    await pumpSignIn(tester);

    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('shows a validation message when the email is empty', (tester) async {
    await pumpSignIn(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(fakeAuthGateway.signInWithEmailCalls, 0);
  });

  testWidgets('disables the submit button while the attempt is running', (tester) async {
    // O fake segura a operação: sem isso ela resolveria no mesmo microtask e
    // o que o teste observaria seria o estado *depois* do sucesso, em que
    // `isBusy` fica preso em `true` porque o sucesso não emite.
    fakeAuthGateway.holdEmailOperations();

    await pumpSignIn(tester);
    await fillValidCredentials(tester);

    // Localizado por tipo, e não por texto: enquanto ocupado o rótulo
    // 'Entrar' é substituído pelo indicador — um `widgetWithText` deixaria de
    // encontrar o botão exatamente na condição que este teste verifica.
    final submitButton = find.byType(ElevatedButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(tester.widget<ElevatedButton>(submitButton).enabled, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // `pump`, e não `pumpAndSettle`: o sucesso não emite, então `isBusy`
    // permanece `true` e o indicador gira para sempre — `pumpAndSettle`
    // esperaria uma animação que nunca termina. No aplicativo isso não
    // aparece porque o portão troca a tela; aqui não há portão.
    fakeAuthGateway.releaseEmailOperations();
    await tester.pump();
  });

  testWidgets('shows the failure message returned by the cubit', (tester) async {
    fakeAuthGateway.signInWithEmailError = const AuthGatewayException('invalid-credential');

    await pumpSignIn(tester);
    await fillValidCredentials(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pumpAndSettle();

    // A mensagem que a tabela do Cubit realmente produz, e a mesma para
    // conta inexistente e senha errada — é a proteção contra enumeração.
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });
}
