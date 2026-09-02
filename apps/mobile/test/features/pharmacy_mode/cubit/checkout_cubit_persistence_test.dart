import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_storage.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/demo_checkout_repositories.dart';

void main() {
  test('restores a persisted checkout session', () async {
    final persistedSession = CheckoutSession(
      id: 'persisted-session',
      availableBalanceInCents: 18000,
      prescription: const Prescription(reference: 'RX-001'),
      medications: const [
        Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ],
      status: CheckoutStatus.creatingPayment,
    );

    final fallbackSession = CheckoutSession(
      id: 'new-session',
      availableBalanceInCents: 25000,
      prescription: null,
      medications: const [],
      status: CheckoutStatus.collectingMedication,
    );

    final storage = InMemoryCheckoutSessionStorage();

    await storage.save(CheckoutSessionSnapshot.fromDomain(persistedSession));

    final cubit = await CheckoutCubit.restore(
      fallbackSession: fallbackSession,
      storage: storage,
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: const DemoPrescriptionRepository(),
      medicationRepository: const DemoMedicationRepository(),
      checkoutRepository: DemoCheckoutRepository(),
    );

    addTearDown(cubit.close);

    expect(cubit.state.id, 'persisted-session');
    expect(cubit.state.status, CheckoutStatus.creatingPayment);
    expect(cubit.state.medications, hasLength(1));
  });
  test('persists a new checkout snapshot after scanning medication', () async {
    final storage = InMemoryCheckoutSessionStorage();

    final fallbackSession = CheckoutSession(
      id: 'new-session',
      availableBalanceInCents: 25000,
      prescription: null,
      medications: const [],
      status: CheckoutStatus.collectingMedication,
    );

    final cubit = await CheckoutCubit.restore(
      fallbackSession: fallbackSession,
      storage: storage,
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: const DemoPrescriptionRepository(),
      medicationRepository: const DemoMedicationRepository(),
      checkoutRepository: DemoCheckoutRepository(),
    );

    addTearDown(cubit.close);

    await cubit.scanMedication(
      const Medication(
        ean: '7891000000011',
        name: 'Medicamento demonstrativo',
        unitPriceInCents: 2500,
      ),
    );

    final persistedSnapshot = await storage.load();

    expect(persistedSnapshot, isNotNull);
    expect(persistedSnapshot!.toDomain().medications, hasLength(1));
  });
  test('persists the latest state after prescription validation', () async {
    final storage = InMemoryCheckoutSessionStorage();

    final fallbackSession = CheckoutSession(
      id: 'new-session',
      availableBalanceInCents: 25000,
      prescription: null,
      medications: const [
        Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ],
      status: CheckoutStatus.collectingMedication,
    );

    final cubit = await CheckoutCubit.restore(
      fallbackSession: fallbackSession,
      storage: storage,
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: const DemoPrescriptionRepository(),
      medicationRepository: const DemoMedicationRepository(),
      checkoutRepository: DemoCheckoutRepository(),
    );

    addTearDown(cubit.close);

    await cubit.submitPrescription(const Prescription(reference: 'RX-001'));

    final persistedSnapshot = await storage.load();

    expect(persistedSnapshot, isNotNull);
    expect(
      persistedSnapshot!.toDomain().status,
      CheckoutStatus.checkingEligibility,
    );
    expect(persistedSnapshot.toDomain().prescription?.reference, 'RX-001');
  });

  test(
    'persists the checkout status after a retry from a recoverable failure',
    () async {
      final storage = InMemoryCheckoutSessionStorage();

      final fallbackSession = CheckoutSession(
        id: 'new-session',
        availableBalanceInCents: 25000,
        prescription: null,
        medications: const [
          Medication(
            ean: '7891000000011',
            name: 'Medicamento demonstrativo',
            unitPriceInCents: 2500,
          ),
        ],
        status: CheckoutStatus.creatingPayment,
      );

      final cubit = await CheckoutCubit.restore(
        fallbackSession: fallbackSession,
        storage: storage,
        stateMachine: const CheckoutStateMachine(),
        prescriptionRepository: const _FakePrescriptionRepository(
          validationResult: true,
        ),
        medicationRepository: const _FakeMedicationRepository(
          eligibilityResult: true,
        ),
        checkoutRepository: _FakeCheckoutRepository(
          createdCheckoutId: 'remote-checkout-id',
          createError: Exception('Falha de rede simulada'),
          getByIdError: Exception('Falha de rede simulada'),
          checkoutById: CheckoutSession(
            id: 'remote-checkout-id',
            availableBalanceInCents: 25000,
            prescription: const Prescription(reference: 'RX-001'),
            medications: const [
              Medication(
                ean: '7891000000011',
                name: 'Medicamento demonstrativo',
                unitPriceInCents: 2500,
              ),
            ],
            status: CheckoutStatus.paid,
          ),
        ),
      );

      addTearDown(cubit.close);

      await cubit.createCheckout();

      cubit.retry();

      final persistedSnapshot = await storage.load();

      expect(persistedSnapshot, isNotNull);
      expect(
        persistedSnapshot!.toDomain().status,
        CheckoutStatus.creatingPayment,
      );
      expect(persistedSnapshot.toDomain().status, cubit.state.status);
    },
  );
}

final class _FakePrescriptionRepository implements PrescriptionRepository {
  final bool validationResult;

  const _FakePrescriptionRepository({required this.validationResult});

  @override
  Future<bool> validate(Prescription prescription) async {
    return validationResult;
  }
}

final class _FakeMedicationRepository implements MedicationRepository {
  final bool eligibilityResult;

  const _FakeMedicationRepository({required this.eligibilityResult});

  @override
  Future<bool> checkEligibility(Medication medication) async {
    return eligibilityResult;
  }
}

final class _FakeCheckoutRepository implements CheckoutRepository {
  final String createdCheckoutId;
  final CheckoutSession? checkoutById;
  final Object? createError;
  final Object? getByIdError;

  const _FakeCheckoutRepository({
    required this.createdCheckoutId,
    this.checkoutById,
    this.createError,
    this.getByIdError,
  });

  @override
  Future<String> create(CheckoutSession session) async {
    final error = createError;

    if (error != null) throw error;

    return createdCheckoutId;
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) async {
    final error = getByIdError;

    if (error != null) throw error;

    final checkout = checkoutById;

    if (checkout == null) {
      throw UnimplementedError('getById não foi configurado neste teste');
    }

    return checkout;
  }
}
