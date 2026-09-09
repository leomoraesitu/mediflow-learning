import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediflow_mobile/config/firebase_auth_token_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const authEmulatorHost = '10.0.2.2';
  const authEmulatorPort = 9099;
  setUpAll(() async {
    await Firebase.initializeApp();
    await FirebaseAuth.instance.useAuthEmulator(authEmulatorHost, authEmulatorPort);
  });

  final baseOptions = BaseOptions(baseUrl: 'http://$authEmulatorHost:$authEmulatorPort');

  group('FirebaseAuthTokenProvider', () {
    testWidgets('recovers with a new identity when the account no longer exists', (tester) async {
      final auth = FirebaseAuth.instance;

      await auth.signOut();

      final credentialBeforeSignIn = await auth.signInAnonymously();

      // Este UID é o oráculo: após invalidarmos a conta no emulator,
      // o provider precisa recuperar a sessão criando uma nova identidade.
      final uidBeforeInvalidation = credentialBeforeSignIn.user!.uid;

      final projectId = Firebase.app().options.projectId;

      final dio = Dio(baseOptions);

      final clearResponse = await dio.delete<void>('/emulator/v1/projects/$projectId/accounts');

      expect(clearResponse.statusCode, inInclusiveRange(200, 299));

      final provider = FirebaseAuthTokenProvider(auth);

      final token = await provider.token(forceRefresh: true);

      expect(token, isNotNull);

      final userAfterInvalidation = auth.currentUser;

      expect(userAfterInvalidation, isNotNull);
      expect(userAfterInvalidation!.uid, isNot(uidBeforeInvalidation));
    });
  });
}
