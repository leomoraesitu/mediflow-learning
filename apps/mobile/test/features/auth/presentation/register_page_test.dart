import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:mediflow_mobile/features/auth/presentation/register_page.dart';

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

  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BlocProvider<AuthCubit>.value(value: cubit, child: const RegisterPage()),
                    ),
                  );
                },
                child: const Text('Abrir cadastro'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Abrir cadastro'));

    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  }

  Future<void> fillValidCredentials(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'alguem@exemplo.test');

    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'senha-secreta');
  }

  testWidgets('pops the register screen after a successful registration', (tester) async {
    await pumpRegister(tester);
    await fillValidCredentials(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));

    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsNothing);
  });

  testWidgets('keeps the register screen open when registration fails', (tester) async {
    fakeAuthGateway.registerWithEmailError = const AuthGatewayException('email-already-in-use');

    await pumpRegister(tester);
    await fillValidCredentials(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));

    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);

    expect(find.text('Este e-mail já está cadastrado.'), findsOneWidget);
  });
}
