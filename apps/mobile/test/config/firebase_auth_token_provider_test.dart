import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/config/firebase_auth_token_provider.dart';

import 'fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway fake;

  // `currentUserValue` nasce `null`, e é por isso que os três primeiros
  // testes exercitam o ramo anônimo da recuperação. Quem mudar esse padrão
  // no fake muda o ramo que eles cobrem, sem que o nome deles mude.
  setUp(() {
    fake = FakeAuthGateway();
  });

  test('recovers a new identity when the current token cannot be obtained', () async {
    fake.currentUserTokenError = const AuthGatewayException('user-token-revoked');
    fake.signInToken = 'token-novo';

    final token = await FirebaseAuthTokenProvider(fake).token();

    expect(token, 'token-novo');
  });
  test('returns null when the recovery also fails', () async {
    fake.currentUserTokenError = const AuthGatewayException('user-token-revoked');
    fake.signInError = const AuthGatewayException('sign-in-failed');

    final token = await FirebaseAuthTokenProvider(fake).token();

    expect(token, isNull);
  });
  test('does not recover when the current token is obtained successfully', () async {
    fake.currentUserTokenValue = 'token-atual';

    final token = await FirebaseAuthTokenProvider(fake).token();

    expect(token, 'token-atual');
    expect(fake.signOutCalls, 0);
    expect(fake.signInCalls, 0);
  });
  test('ends the session without a new identity when a real account is rejected', () async {
    fake.currentUserValue = const AuthUser(
      uid: 'u1',
      email: 'alguem@exemplo.test',
      isAnonymous: false,
    );

    fake.currentUserTokenError = const AuthGatewayException('user-token-revoked');

    final token = await FirebaseAuthTokenProvider(fake).token();

    expect(token, isNull);
    expect(fake.signOutCalls, 1);
    // A asserção decisiva: `null` também é o que sai quando a recuperação
    // falha. Só a contagem separa "encerrou a sessão de propósito" de
    // "tentou criar identidade nova e não conseguiu".
    expect(fake.signInCalls, 0);
  });
  test('signs in anonymously again when an anonymous session is rejected', () async {
    fake.currentUserValue = const AuthUser(uid: 'anon', isAnonymous: true);
    fake.currentUserTokenError = const AuthGatewayException('user-token-revoked');
    fake.signInToken = 'token-novo';

    final token = await FirebaseAuthTokenProvider(fake).token();

    expect(token, 'token-novo');
    expect(fake.signOutCalls, 1);
    expect(fake.signInCalls, 1);
  });
}
