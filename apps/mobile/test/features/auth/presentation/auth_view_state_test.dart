import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_view_state.dart';

// Os estados são declarados com `final`, e não com `const`, de propósito.
//
// Duas expressões `const` idênticas são canonicalizadas para o *mesmo* objeto.
// Num arquivo cujo propósito é verificar igualdade de valor, isso esconde
// justamente o que se quer verificar: com `const`, apagar o `==` de
// `AuthViewState` deixa estes testes verdes; com `final`, deixa vermelhos.
void main() {
  group('AuthViewState', () {
    test('treats two states with the same fields as equal', () {
      final state = AuthViewState(isBusy: false, feedback: const NoAuthFeedback());
      final same = AuthViewState(isBusy: false, feedback: const NoAuthFeedback());

      expect(state, same);
      expect(same, state);
    });

    test('agrees on hash code for two states with the same fields', () {
      final state = AuthViewState(isBusy: false, feedback: const NoAuthFeedback());
      final same = AuthViewState(isBusy: false, feedback: const NoAuthFeedback());

      expect(state.hashCode, same.hashCode);
    });

    test('starts idle', () {
      const idle = AuthViewState.idle();

      expect(idle.isBusy, isFalse);
      expect(idle.feedback, const NoAuthFeedback());
    });

    test('separates a busy state from an idle one', () {
      final busy = AuthViewState(isBusy: true, feedback: const NoAuthFeedback());
      final idle = AuthViewState(isBusy: false, feedback: const NoAuthFeedback());

      expect(busy, isNot(idle));
      expect(idle, isNot(busy));
    });

    test('separates a failure from an idle state', () {
      final idle = AuthViewState(isBusy: false, feedback: const NoAuthFeedback());
      final failed = AuthViewState(isBusy: false, feedback: const AuthFailure('Senha incorreta.'));

      // As duas direções: `equals` avalia `esperado == real`, então uma
      // asserção só exercita o `==` de um dos lados da comparação.
      expect(idle, isNot(failed));
      expect(failed, isNot(idle));
    });

    test('separates two failures carrying different messages', () {
      // Se `AuthFailure` comparasse só o tipo, trocar uma mensagem por outra
      // produziria estados iguais, o Cubit suprimiria a segunda emissão, e a
      // tela continuaria mostrando o erro anterior.
      final wrongPassword = AuthViewState(
        isBusy: false,
        feedback: const AuthFailure('Senha incorreta.'),
      );
      final emailInUse = AuthViewState(
        isBusy: false,
        feedback: const AuthFailure('Este e-mail já está cadastrado.'),
      );

      expect(wrongPassword, isNot(emailInUse));
      expect(emailInUse, isNot(wrongPassword));
    });
  });
}
