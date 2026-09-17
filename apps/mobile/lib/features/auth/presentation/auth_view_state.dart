/// O que a tela de autenticação mostra sobre a última tentativa.
///
/// Os nomes são prefixados de propósito: `checkout_view_state.dart` já declara
/// `NoFeedback`, e Dart não tem espaço de nomes por arquivo — um arquivo que
/// importasse os dois precisaria de `import ... as`.
///
/// Não existe variante de sucesso. Quando a entrada dá certo, o portão troca a
/// tela inteira a partir de `authStateChanges`; uma variante de sucesso ficaria
/// sem ninguém para renderizá-la.
sealed class AuthFeedback {
  const AuthFeedback();
}

final class NoAuthFeedback extends AuthFeedback {
  const NoAuthFeedback();

  @override
  bool operator ==(Object other) => other is NoAuthFeedback;

  @override
  int get hashCode => (NoAuthFeedback).hashCode;
}

final class AuthFailure extends AuthFeedback {
  final String message;

  const AuthFailure(this.message);

  @override
  bool operator ==(Object other) => other is AuthFailure && other.message == message;

  @override
  int get hashCode => Object.hash(AuthFailure, message);
}

/// O estado do formulário de autenticação.
///
/// Dois campos só. `canSubmit` não entra: quem decide isso é o `validator` do
/// `Form`, e duplicar a regra é o defeito que a Aula 52 corrigiu em
/// `_submitPrescription`.
///
/// `isBusy` é a razão de este ViewModel existir — é ele que impede o duplo
/// toque criar duas contas.
final class AuthViewState {
  final bool isBusy;
  final AuthFeedback feedback;

  const AuthViewState({required this.isBusy, required this.feedback});

  const AuthViewState.idle() : isBusy = false, feedback = const NoAuthFeedback();

  @override
  bool operator ==(Object other) =>
      other is AuthViewState && other.isBusy == isBusy && other.feedback == feedback;

  @override
  int get hashCode => Object.hash(isBusy, feedback);
}
