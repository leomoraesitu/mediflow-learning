import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_view_state.dart';

final class AuthCubit extends Cubit<AuthViewState> {
  final AuthGateway _authGateway;

  AuthCubit({required this._authGateway}) : super(const AuthViewState.idle());

  Future<void> signIn({required String email, required String password}) async {
    // Recusar a segunda chamada é o objetivo, e isso é o oposto do que o
    // `OutboxSynchronizer.drain()` faz com um pedido concorrente — lá ele é
    // marcado e reexecutado, porque descartá-lo perderia o sinal da rede que
    // voltou. Aqui a segunda chamada é o mesmo toque duplicado, e atendê-la
    // dispara uma segunda tentativa de entrada.
    if (state.isBusy) return;

    // Limpar o feedback ao começar: sem isso a mensagem do erro anterior fica
    // na tela durante a tentativa nova, e o usuário lê um erro que não é o
    // dele.
    emit(const AuthViewState(isBusy: true, feedback: NoAuthFeedback()));

    try {
      await _authGateway.signInWithEmail(email: email, password: password);
      // Sem `emit` no sucesso, e isso é deliberado: `authStateChanges` dispara,
      // o portão troca a tela, e o `BlocProvider` da tela de login descarta
      // este cubit. Um `emit` depois disso lançaria `StateError`.
    } on AuthGatewayException catch (e) {
      emit(AuthViewState(isBusy: false, feedback: AuthFailure(_messageFor(e.code))));
    }
  }

  Future<void> register({required String email, required String password}) async {
    if (state.isBusy) return;

    emit(const AuthViewState(isBusy: true, feedback: NoAuthFeedback()));

    try {
      await _authGateway.registerWithEmail(email: email, password: password);
      // Como em `signIn`: quem troca a tela é o portão.
    } on AuthGatewayException catch (e) {
      emit(AuthViewState(isBusy: false, feedback: AuthFailure(_messageFor(e.code))));
    }
  }
}

/// Traduz o código do gateway para o texto que a pessoa lê.
///
/// A tabela vive na apresentação, e não no adaptador, porque é aqui que a
/// língua do aplicativo existe — se o adaptador devolvesse frases prontas, o
/// `FakeAuthGateway` precisaria imitar português para os testes funcionarem.
String _messageFor(String code) {
  return switch (code) {
    // O caso comum nos projetos novos. Com a proteção contra enumeração de
    // e-mails ligada, o Firebase devolve o mesmo código para conta inexistente
    // e para senha errada — de propósito, para ninguém descobrir quais
    // e-mails têm cadastro. A mensagem precisa respeitar isso: é a mesma
    // decisão do `404` em vez de `403` nas functions.
    'invalid-credential' || 'user-not-found' || 'wrong-password' => 'E-mail ou senha incorretos.',

    'invalid-email' => 'Informe um e-mail válido.',
    'user-disabled' => 'Esta conta está desativada.',
    'email-already-in-use' => 'Este e-mail já está cadastrado.',
    'weak-password' => 'A senha precisa ter pelo menos seis caracteres.',

    // Ninguém habilitou e-mail e senha no console do Firebase. É o primeiro
    // erro que aparece ao testar contra o projeto real pela primeira vez.
    'operation-not-allowed' => 'Este método de entrada não está disponível.',

    'network-request-failed' => 'Sem conexão. Verifique a rede e tente de novo.',
    'too-many-requests' => 'Muitas tentativas. Aguarde um instante.',

    // Nosso, de `FirebaseAuthGateway._requireUser`.
    'missing-user' => 'Não foi possível concluir. Tente novamente.',

    _ => _unmapped(code),
  };
}

/// O código cru não vai para a tela — vazaria implementação e não significa
/// nada para quem lê. Mas some do diagnóstico se ninguém o registrar.
String _unmapped(String code) {
  debugPrint('Código de autenticação não mapeado: $code');
  return 'Não foi possível concluir. Tente novamente.';
}
