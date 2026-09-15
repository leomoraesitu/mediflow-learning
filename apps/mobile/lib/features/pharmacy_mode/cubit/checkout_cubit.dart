// ignore_for_file: prefer_initializing_formals
//
// The public constructor intentionally keeps dependency parameter names public
// while storing the injected implementations in private fields.

import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_storage.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_view_state.dart';

/// O ViewModel do Modo Farmácia.
///
/// Emite `CheckoutViewState`, não `CheckoutSession`: a sessão de domínio é
/// estado interno e nunca atravessa para a View. Isso mantém as regras de
/// apresentação de um lado só da fronteira, e é o que permite à tela não
/// importar `checkout_domain`.
final class CheckoutCubit extends Cubit<CheckoutViewState> {
  final CheckoutStateMachine _stateMachine;
  final PrescriptionRepository _prescriptionRepository;
  final MedicationRepository _medicationRepository;
  final CheckoutRepository _checkoutRepository;
  final CheckoutSessionStorage? _storage;

  /// A sessão de domínio, privada por definição: é dela que todo estado de
  /// visão é derivado, e é ela que vai para o armazenamento.
  CheckoutSession _session;

  static Future<CheckoutCubit> restore({
    required CheckoutSession fallbackSession,
    required CheckoutSessionStorage storage,
    required CheckoutStateMachine stateMachine,
    required PrescriptionRepository prescriptionRepository,
    required MedicationRepository medicationRepository,
    required CheckoutRepository checkoutRepository,
  }) async {
    final snapshot = await storage.load();

    return CheckoutCubit(
      initialSession: snapshot?.toDomain() ?? fallbackSession,
      stateMachine: stateMachine,
      prescriptionRepository: prescriptionRepository,
      medicationRepository: medicationRepository,
      checkoutRepository: checkoutRepository,
      storage: storage,
    );
  }

  CheckoutCubit({
    required CheckoutSession initialSession,
    required CheckoutStateMachine stateMachine,
    required PrescriptionRepository prescriptionRepository,
    required MedicationRepository medicationRepository,
    required CheckoutRepository checkoutRepository,
    CheckoutSessionStorage? storage,
  }) : _stateMachine = stateMachine,
       _prescriptionRepository = prescriptionRepository,
       _medicationRepository = medicationRepository,
       _checkoutRepository = checkoutRepository,
       _storage = storage,
       _session = initialSession,
       super(CheckoutViewState.fromSession(initialSession));

  Future<void> _emitPersisted(CheckoutSession session) async {
    _session = session;
    emit(CheckoutViewState.fromSession(session));

    final storage = _storage;

    if (storage != null) {
      await storage.save(CheckoutSessionSnapshot.fromDomain(session));
    }
  }

  /// Recebe o EAN, não um `Medication`: a View não constrói domínio.
  Future<void> scanMedication(String ean) async {
    final nextSession = _stateMachine.transition(
      session: _session,
      event: MedicationScanned(
        medication: Medication(ean: ean, name: 'Medicamento demonstrativo', unitPriceInCents: 2500),
      ),
    );

    await _emitPersisted(nextSession);
  }

  Future<void> submitPrescription(String reference) async {
    final prescription = Prescription(reference: reference);

    final nextSession = _stateMachine.transition(
      session: _session,
      event: PrescriptionSubmitted(prescription: prescription),
    );

    await _emitPersisted(nextSession);

    final isValid = await _prescriptionRepository.validate(prescription);

    if (isClosed) return;

    if (!isValid) {
      await _emitPersisted(
        _stateMachine.transition(
          session: _session,
          event: const CheckoutFailed(errorMessage: 'Receita inválida.', recoverable: false),
        ),
      );
      return;
    }

    await _emitPersisted(
      _stateMachine.transition(session: _session, event: const PrescriptionValidated()),
    );
  }

  /// Sem parâmetro: quem escolhe o medicamento verificado é o ViewModel, a
  /// partir da própria sessão. Antes essa escolha vivia no `build()` da tela.
  Future<void> checkEligibility() async {
    final medications = _session.medications;

    if (medications.isEmpty) return;

    final isEligible = await _medicationRepository.checkEligibility(medications.first);

    if (isClosed) return;

    if (!isEligible) {
      await _emitPersisted(
        _stateMachine.transition(
          session: _session,
          event: const CheckoutFailed(
            errorMessage: 'Medicamento não elegível.',
            recoverable: false,
          ),
        ),
      );
      return;
    }

    await _emitPersisted(
      _stateMachine.transition(session: _session, event: const EligibilityConfirmed()),
    );
  }

  Future<void> createCheckout() async {
    late final String remoteCheckoutId;

    try {
      remoteCheckoutId = await _checkoutRepository.create(_session);
    } on Exception {
      if (isClosed) return;

      await _emitPersisted(
        _stateMachine.transition(
          session: _session,
          event: const CheckoutFailed(
            errorMessage: 'Falha ao criar o checkout.',
            recoverable: true,
          ),
        ),
      );
      return;
    }

    if (isClosed) return;

    await _emitPersisted(
      _stateMachine.transition(
        session: _session,
        event: PaymentCreated(remoteCheckoutId: remoteCheckoutId),
      ),
    );
  }

  Future<void> confirmPayment() async {
    final remoteCheckoutId = _session.remoteCheckoutId;

    if (remoteCheckoutId == null) return;

    late final CheckoutSession remoteCheckout;

    try {
      remoteCheckout = await _checkoutRepository.getById(remoteCheckoutId);
    } on Exception {
      if (isClosed) return;

      await _emitPersisted(
        _stateMachine.transition(
          session: _session,
          event: const CheckoutFailed(
            errorMessage: 'Falha ao confirmar o checkout.',
            recoverable: true,
          ),
        ),
      );
      return;
    }

    if (isClosed || remoteCheckout.status != CheckoutStatus.paid) return;

    await _emitPersisted(
      _stateMachine.transition(session: _session, event: const PaymentConfirmed()),
    );
  }

  Future<void> retry() async {
    await _emitPersisted(
      _stateMachine.transition(session: _session, event: const RetryRequested()),
    );
  }
}
