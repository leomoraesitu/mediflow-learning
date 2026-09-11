import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/config/firebase_auth_token_provider.dart';

import 'fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway fake;
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
}
