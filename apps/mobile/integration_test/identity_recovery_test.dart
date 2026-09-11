import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediflow_mobile/config/firebase_auth_gateway.dart';
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
      final auth = FirebaseAuthGateway(firebaseAuth: FirebaseAuth.instance);

      await auth.signOut();

      final tokenBeforeInvalidation = await auth.signInAnonymously();

      expect(tokenBeforeInvalidation, isNotNull);

      // Este UID é o oráculo: após invalidarmos a conta no emulador, o
      // provedor precisa recuperar a sessão criando uma identidade nova.
      // Lido direto de `currentUser`, e não das claims do token: elas não
      // têm chave `uid` — o identificador vem em `user_id`/`sub` —, então
      // um oráculo tirado dali seria `null` e a comparação final passaria
      // mesmo sem recuperação nenhuma.
      final uidBeforeInvalidation = FirebaseAuth.instance.currentUser!.uid;

      final projectId = Firebase.app().options.projectId;

      final dio = Dio(baseOptions);

      final clearResponse = await dio.delete<void>('/emulator/v1/projects/$projectId/accounts');

      expect(clearResponse.statusCode, inInclusiveRange(200, 299));

      final provider = FirebaseAuthTokenProvider(auth);

      final token = await provider.token(forceRefresh: true);

      expect(token, isNotNull);

      final userAfterInvalidation = FirebaseAuth.instance.currentUser;

      expect(userAfterInvalidation, isNotNull);
      expect(userAfterInvalidation!.uid, isNot(uidBeforeInvalidation));

      dio.close();
    });
  });
}
