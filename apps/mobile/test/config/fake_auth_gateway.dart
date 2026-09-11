import 'package:mediflow_mobile/config/auth_gateway.dart';

final class FakeAuthGateway implements AuthGateway {
  String? currentUserTokenValue;
  AuthGatewayException? currentUserTokenError;

  String? signInToken;
  AuthGatewayException? signInError;

  AuthGatewayException? signOutError;

  int signOutCalls = 0;
  int signInCalls = 0;

  @override
  Future<String?> currentUserToken() async {
    if (currentUserTokenError != null) {
      throw currentUserTokenError!;
    }
    return currentUserTokenValue;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) {
      throw signOutError!;
    }
  }

  @override
  Future<String?> signInAnonymously() async {
    signInCalls++;
    if (signInError != null) {
      throw signInError!;
    }
    return signInToken;
  }
}
