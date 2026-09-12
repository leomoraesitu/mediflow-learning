import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/dio_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/dio_medication_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/dio_prescription_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_synchronizer.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/performance_tracing_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/performance_tracing_medication_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/performance_tracing_prescription_repository.dart';
import 'package:mediflow_mobile/observability/performance_tracer.dart';

/// O grafo de dependências que o aplicativo consome, já montado.
///
/// Os campos são declarados pelos tipos de domínio, e não pelos decorators
/// concretos: assim a forma da cadeia — quem envolve quem — é assunto dos
/// testes de composição, e não do sistema de tipos. Trocar a ordem dos
/// decorators deve quebrar um teste com uma mensagem explicável, não a
/// compilação de quem apenas consome o grafo.
final class AppDependencies {
  final CheckoutDatabase database;
  final CheckoutRepository checkoutRepository;
  final PrescriptionRepository prescriptionRepository;
  final MedicationRepository medicationRepository;
  final OutboxSynchronizer synchronizer;
  final OperationalSettings settings;
  final Stream<bool> hasPendingSync;

  const AppDependencies({
    required this.database,
    required this.checkoutRepository,
    required this.prescriptionRepository,
    required this.medicationRepository,
    required this.synchronizer,
    required this.settings,
    required this.hasPendingSync,
  });
}

/// Monta o grafo e **não age**: não abre rede, não escreve em nada, não muta
/// estado global. Quem dispara o `drain()` e instala o `BlocObserver` é o
/// `main()`, depois desta chamada.
///
/// Tudo que depende de plataforma chega por parâmetro. É isso, e não o
/// arquivo em que a função mora, que a torna testável: o `main()` passa o
/// banco real e um `CheckoutApiClient` com rede; um teste passa um banco em
/// memória e um cliente construído com `CheckoutApiClient.withDio` sobre um
/// adapter falso.
AppDependencies composeDependencies({
  required CheckoutDatabase database,
  required CheckoutApiClient apiClient,
  required OperationalSettings settings,
  required PerformanceTracer tracer,
}) {
  final outboxCheckoutRepository = OutboxCheckoutRepository(
    inner: DioCheckoutRepository(apiClient: apiClient),
    database: database,
  );

  return AppDependencies(
    database: database,
    checkoutRepository: PerformanceTracingCheckoutRepository(
      inner: outboxCheckoutRepository,
      tracer: tracer,
    ),
    prescriptionRepository: PerformanceTracingPrescriptionRepository(
      inner: DioPrescriptionRepository(apiClient: apiClient),
      tracer: tracer,
    ),
    medicationRepository: PerformanceTracingMedicationRepository(
      inner: DioMedicationRepository(apiClient: apiClient),
      tracer: tracer,
    ),
    // O sincronizador recebe o repositório **sem** o decorator de
    // performance: o reenvio do outbox não é uma ação do usuário, e medi-lo
    // junto das criações reais misturaria duas populações no mesmo trace.
    synchronizer: OutboxSynchronizer(
      database: database,
      checkoutRepository: outboxCheckoutRepository,
    ),
    settings: settings,
    hasPendingSync: database.watchHasPendingSync(),
  );
}
