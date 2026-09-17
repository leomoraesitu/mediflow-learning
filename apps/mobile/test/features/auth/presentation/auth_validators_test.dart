import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_validators.dart';

void main() {
  group('validateEmail', () {
    test('rejects an empty email', () {
      expect(validateEmail(''), 'Informe o e-mail.');
      expect(validateEmail(null), 'Informe o e-mail.');
      expect(validateEmail('   '), 'Informe o e-mail.');
    });

    test('rejects an email without a domain', () {
      expect(validateEmail('alguem'), 'Informe um e-mail válido.');
      expect(validateEmail('alguem@exemplo'), 'Informe um e-mail válido.');
    });

    test('accepts a well formed email', () {
      expect(validateEmail('alguem@exemplo.test'), isNull);
    });
  });

  group('validatePassword', () {
    test('rejects an empty password', () {
      expect(validatePassword(''), 'Informe a senha.');
      expect(validatePassword(null), 'Informe a senha.');
    });

    test('rejects a password shorter than the minimum', () {
      expect(validatePassword('1234567'), 'A senha precisa ter pelo menos oito caracteres.');
    });

    // A fronteira, e não só o lado que recusa: um teste com sete caracteres
    // sozinho não distingue `length < 8` de `length <= 8`.
    test('accepts a password at the minimum length', () {
      expect(validatePassword('12345678'), isNull);
    });
  });
}
