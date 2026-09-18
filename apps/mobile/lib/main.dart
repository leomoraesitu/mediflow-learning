import 'dart:async';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/app_dependencies.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/config/firebase_auth_gateway.dart';
import 'package:mediflow_mobile/config/firebase_auth_token_provider.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/config/remote_config_operational_settings.dart';
import 'package:mediflow_mobile/connectivity/connectivity_sync_triggers.dart';
import 'package:mediflow_mobile/design_system/app_theme.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_gate.dart';
import 'package:mediflow_mobile/features/benefits/presentation/benefits_home_page.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/firebase_options.dart';
import 'package:mediflow_mobile/lifecycle/lifecycle_sync_triggers.dart';
import 'package:mediflow_mobile/observability/firebase_performance_tracer.dart';
import 'package:mediflow_mobile/observers/checkout_analytics_observer.dart';

const checkoutApiBaseUrl = String.fromEnvironment('CHECKOUT_API_BASE_URL');

Future<void> main() async {
  if (checkoutApiBaseUrl.isEmpty) {
    throw StateError(
      'CHECKOUT_API_BASE_URL não foi informado. Execute com: '
      'flutter run --dart-define=CHECKOUT_API_BASE_URL='
      'http://10.0.2.2:5001/mediflow-learning/us-central1/api',
    );
  }

  const useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (useFirebaseEmulators) {
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  }

  final settings = await RemoteConfigOperationalSettings.load(FirebaseRemoteConfig.instance);

  // Uma instância só, e isso é requisito: o provedor de token e o portão
  // observam o mesmo SDK. Construída aqui porque `composeDependencies` é pura
  // — ela recebe as peças de plataforma, não as alcança.
  final authGateway = FirebaseAuthGateway(firebaseAuth: FirebaseAuth.instance);

  // Daqui para baixo nada mais depende de plataforma: a montagem do grafo é
  // uma função pura sobre estas quatro peças, e é isso que a torna testável.
  final dependencies = composeDependencies(
    database: CheckoutDatabase.defaults(),
    apiClient: CheckoutApiClient(
      baseUrl: checkoutApiBaseUrl,
      timeout: settings.checkoutTimeout,
      tokenProvider: FirebaseAuthTokenProvider(authGateway).token,
    ),
    settings: settings,
    tracer: FirebasePerformanceTracer(performance: FirebasePerformance.instance),
    // Duas fontes, fundidas pela composição. Nenhuma delas é guardada para
    // descarte, e isso é deliberado: as duas vivem o processo inteiro, como o
    // agendador que elas alimentam. Os `dispose()` existem para os testes.
    //
    // Elas se complementam. A conectividade cobre a rede que volta com o
    // aplicativo em uso; a retomada cobre o caso em que a mudança acontece
    // com o processo em segundo plano, onde o Android não promete entregar o
    // aviso — restrições de background e Doze podem engoli-lo.
    syncTriggers: [ConnectivitySyncTriggers.defaults().stream, LifecycleSyncTriggers().stream],
    authGateway: authGateway,
  );

  // As duas ações que a composição deliberadamente não faz.
  //
  // Sem `await`: a primeira tela aparece a partir do estado local, e o
  // reenvio do outbox acontece em segundo plano. O `unawaited` declara que o
  // descarte é deliberado, e `drain()` é total — nada escapa dele para virar
  // erro assíncrono não tratado com a interface já em uso.
  //
  // O que torna isto seguro não é o descarte em si, e sim a idempotência
  // construída na Aula 33. Como a interface sobe antes de o reenvio terminar,
  // o usuário pode criar um pagamento enquanto o mesmo evento pendente é
  // reenviado, e as duas requisições saem com a mesma `Idempotency-Key`. O
  // backend usa essa chave como identificador do documento no Firestore, então
  // a segunda encontra o existente e devolve o mesmo `id` em vez de cobrar de
  // novo. Sem essa garantia no servidor, remover o `await` trocaria uma splash
  // lenta por cobrança duplicada.
  unawaited(dependencies.synchronizer.drain());
  dependencies.scheduler.start();
  Bloc.observer = CheckoutAnalyticsObserver(FirebaseAnalytics.instance);

  runApp(
    MainApp(
      database: dependencies.database,
      checkoutRepository: dependencies.checkoutRepository,
      prescriptionRepository: dependencies.prescriptionRepository,
      medicationRepository: dependencies.medicationRepository,
      settings: dependencies.settings,
      hasPendingSync: (_) => const Stream<bool>.empty(),
      authGateway: dependencies.authGateway,
    ),
  );
}

class MainApp extends StatelessWidget {
  final CheckoutDatabase database;
  final CheckoutRepository checkoutRepository;
  final PrescriptionRepository prescriptionRepository;
  final MedicationRepository medicationRepository;
  final OperationalSettings settings;
  final Stream<bool> Function(String userId) hasPendingSync;
  final AuthGateway authGateway;

  const MainApp({
    super.key,
    required this.database,
    required this.checkoutRepository,
    required this.prescriptionRepository,
    required this.medicationRepository,
    required this.settings,
    required this.authGateway,
    required this.hasPendingSync,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGate(
        authGateway: authGateway,
        authenticatedHome: (user) => BenefitsHomePage(
          userId: user.uid,
          availableBalance: 250.0,
          database: database,
          settings: settings,
          checkoutRepository: checkoutRepository,
          prescriptionRepository: prescriptionRepository,
          medicationRepository: medicationRepository,
          hasPendingSync: hasPendingSync,
          authGateway: authGateway,
        ),
      ),
      theme: AppTheme.light,
    );
  }
}
