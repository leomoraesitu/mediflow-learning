import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_user.dart';

void main() {
  group('AuthUser', () {
    test('treats two users with the same fields as equal', () {
      const user = AuthUser(uid: 'u1', email: 'alguem@exemplo.test', isAnonymous: false);
      const same = AuthUser(uid: 'u1', email: 'alguem@exemplo.test', isAnonymous: false);

      // As duas direções: `equals` avalia `esperado == real`, então uma
      // asserção só exercitaria o `==` de um dos lados.
      expect(user, same);
      expect(same, user);
    });

    test('agrees on hash code for two users with the same fields', () {
      const user = AuthUser(uid: 'u1', email: 'alguem@exemplo.test', isAnonymous: false);
      const same = AuthUser(uid: 'u1', email: 'alguem@exemplo.test', isAnonymous: false);

      expect(user.hashCode, same.hashCode);
    });

    test('separates users that differ in the uid', () {
      const user = AuthUser(uid: 'u1', email: 'alguem@exemplo.test', isAnonymous: false);
      const other = AuthUser(uid: 'u2', email: 'alguem@exemplo.test', isAnonymous: false);

      expect(user, isNot(other));
      expect(other, isNot(user));
    });

    test('separates an account without email from one that has it', () {
      // O par que aparece na Aula 54, quando um anônimo vira conta: um `==`
      // que esquecesse `email` aceitaria os dois como o mesmo usuário.
      const withoutEmail = AuthUser(uid: 'u1', isAnonymous: true);
      const withEmail = AuthUser(uid: 'u1', email: 'alguem@exemplo.test', isAnonymous: true);

      expect(withoutEmail, isNot(withEmail));
      expect(withEmail, isNot(withoutEmail));
    });

    test('separates an anonymous session from a real account', () {
      const anonymous = AuthUser(uid: 'u1', isAnonymous: true);
      const account = AuthUser(uid: 'u1', isAnonymous: false);

      expect(anonymous, isNot(account));
      expect(account, isNot(anonymous));
    });
  });
}
