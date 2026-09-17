/// Validadores compartilhados pelas telas de entrada e de cadastro.
///
/// Vivem num arquivo próprio porque privacidade em Dart é por biblioteca, e
/// cada arquivo é uma biblioteca: mantidos privados em cada tela, eles seriam
/// copiados — e já foram. As duas cópias divergiram em um ciclo de edição,
/// uma exigindo seis caracteres e a outra oito.
///
/// A regra precisa ser a mesma nos dois lados. Se o cadastro aceitar uma senha
/// que a entrada recusa, a pessoa cria uma conta em que não consegue entrar.
library;

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';

  if (email.isEmpty) {
    return 'Informe o e-mail.';
  }

  if (!email.contains('@') || !email.contains('.')) {
    return 'Informe um e-mail válido.';
  }

  return null;
}

/// O mínimo de oito caracteres é mais estrito que o do Firebase, que exige
/// seis. Verificar aqui mostra a mensagem antes de uma ida ao servidor, e
/// `weak-password` continua mapeado no Cubit para o caso de a regra deles
/// mudar.
String? validatePassword(String? value) {
  final password = value ?? '';

  if (password.isEmpty) {
    return 'Informe a senha.';
  }

  if (password.length < 8) {
    return 'A senha precisa ter pelo menos oito caracteres.';
  }

  return null;
}
