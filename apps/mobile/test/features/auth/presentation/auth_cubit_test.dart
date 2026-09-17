import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_view_state.dart';

import '../../../config/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway fakeAuthGateway;

  // O `setUp` só constrói o fake. Armar um erro aqui faria toda entrada
  // falhar, e um teste chamado "successful sign in" nunca teria sucesso.
  setUp(() {
    fakeAuthGateway = FakeAuthGateway();
  });

  AuthCubit buildCubit() {
    final cubit = AuthCubit(authGateway: fakeAuthGateway);
    addTearDown(cubit.close);
    return cubit;
  }

  group('AuthCubit', () {
    test('reports an invalid credential without revealing whether the account exists', () async {
      // Os três códigos precisam colapsar numa mensagem só. Distinguir
      // "conta não existe" de "senha errada" deixaria qualquer pessoa
      // descobrir quais e-mails têm cadastro — é a mesma decisão do `404`
      // em vez de `403` nas functions.
      const codigos = ['invalid-credential', 'user-not-found', 'wrong-password'];
      const esperado = AuthViewState(
        isBusy: false,
        feedback: AuthFailure('E-mail ou senha incorretos.'),
      );

      for (final codigo in codigos) {
        fakeAuthGateway.signInWithEmailError = AuthGatewayException(codigo);
        final cubit = buildCubit();

        await cubit.signIn(email: 'alguem@exemplo.test', password: 'senha-secreta');

        expect(cubit.state, esperado, reason: 'código $codigo');
      }
    });

    test('reports a weak password when registering', () async {
      fakeAuthGateway.registerWithEmailError = const AuthGatewayException('weak-password');
      final cubit = buildCubit();

      await cubit.register(email: 'alguem@exemplo.test', password: '123');

      expect(
        cubit.state,
        const AuthViewState(
          isBusy: false,
          feedback: AuthFailure('A senha precisa ter pelo menos seis caracteres.'),
        ),
      );
    });

    test('reports an unmapped code with a generic message', () async {
      fakeAuthGateway.signInWithEmailError = const AuthGatewayException('codigo-inexistente');
      final cubit = buildCubit();

      await cubit.signIn(email: 'alguem@exemplo.test', password: 'senha-secreta');

      expect(
        cubit.state,
        const AuthViewState(
          isBusy: false,
          feedback: AuthFailure('Não foi possível concluir. Tente novamente.'),
        ),
      );
    });

    test('clears the previous failure when a new attempt starts', () async {
      fakeAuthGateway.signInWithEmailError = const AuthGatewayException('invalid-credential');
      final cubit = buildCubit();

      await cubit.signIn(email: 'alguem@exemplo.test', password: 'errada');
      expect(cubit.state.feedback, isA<AuthFailure>());

      fakeAuthGateway.signInWithEmailError = null;

      await cubit.signIn(email: 'alguem@exemplo.test', password: 'certa');

      // `isBusy` fica `true` porque o sucesso não emite: quem troca a tela é
      // o portão, e ele descarta este cubit. O que importa aqui é o feedback
      // ter sido limpo antes da tentativa nova.
      expect(cubit.state, const AuthViewState(isBusy: true, feedback: NoAuthFeedback()));
    });

    test('ignores a second attempt while the first is still running', () async {
      fakeAuthGateway.signInWithEmailError = const AuthGatewayException('invalid-credential');
      final cubit = buildCubit();

      // Sem `await` entre as duas: a segunda encontra `isBusy: true`.
      final primeira = cubit.signIn(email: 'alguem@exemplo.test', password: 'senha-secreta');
      final segunda = cubit.signIn(email: 'alguem@exemplo.test', password: 'senha-secreta');

      await primeira;
      await segunda;

      // A asserção que separa "ignorou a segunda" de "atendeu as duas".
      // Sem ela, um toque duplo criaria duas tentativas de entrada.
      expect(fakeAuthGateway.signInWithEmailCalls, 1);
    });

    test('does not emit after a successful sign in', () async {
      final cubit = buildCubit();
      final emitidos = <AuthViewState>[];
      final assinatura = cubit.stream.listen(emitidos.add);
      addTearDown(assinatura.cancel);

      await cubit.signIn(email: 'alguem@exemplo.test', password: 'senha-secreta');

      // Uma emissão só: a de "ocupado". Emitir depois do sucesso lançaria
      // `StateError`, porque o portão já teria descartado o cubit.
      expect(emitidos, [const AuthViewState(isBusy: true, feedback: NoAuthFeedback())]);
    });
  });
}
