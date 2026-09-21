import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/design_system/app_theme.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:mediflow_mobile/features/auth/presentation/sign_in_page.dart';

import 'config/fake_auth_gateway.dart';

/// Golden da tela de entrada no tema escuro.
///
/// O tema escuro existe desde a Aula 59 e, até este arquivo, **nada o
/// renderizava**: a suíte inteira roda com `platformBrightness` claro, e o
/// único teste que o tocava lia cores do `ThemeData` sem desenhar nada.
///
/// A tela de entrada foi escolhida em vez da de benefícios porque é onde moram
/// os dois defeitos de contraste que esta aula produziu, e ambos são
/// invisíveis no tema claro:
///
/// - as bordas de `TextFormField`. Preencher `enabledBorder`/`focusedBorder`
///   em `InputDecorationTheme` curto-circuita a resolução por estado do
///   `InputDecorator` e fixa o traço padrão do `OutlineInputBorder` — preto,
///   1px. No claro isso passa por decisão de estilo; no escuro a borda some.
/// - o `CircularProgressIndicator` dentro do botão de "Entrar", cuja cor
///   padrão no Material 3 é `colorScheme.primary`, que é o fundo do
///   `FilledButton`.
///
/// Ela também é estável: não muda desde a Aula 54. É a mesma razão que fez o
/// golden da tela de benefícios ser dela e não do Modo Farmácia.
void main() {
  const surface = Size(390, 844);

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

  testWidgets('sign in screen in the dark theme', (tester) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // O valor é global ao dispatcher do teste e vazaria para os arquivos
    // seguintes sem a limpeza — a mesma classe de fuga do `Bloc.observer` na
    // Aula 57.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      // A configuração é a mesma de `MainApp`, e de propósito: passar
      // `theme: AppTheme.dark` direto renderizaria o tema escuro sem provar
      // que `ThemeMode.system` chega nele. Assim o golden também guarda essa
      // ligação.
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: BlocProvider<AuthCubit>.value(
          value: cubit,
          child: SignInPage(onRegisterRequested: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/sign_in_dark.png'));
  });
}
