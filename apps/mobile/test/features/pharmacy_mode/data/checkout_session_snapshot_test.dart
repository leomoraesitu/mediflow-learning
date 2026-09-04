import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';

import 'dart:convert';

void main() {
  test('serializes a checkout session with recovery context', () {
    final session = CheckoutSession(
      id: 'session-01',
      availableBalanceInCents: 25000,
      prescription: const Prescription(reference: 'RX-001'),
      medications: const [
        Medication(
          ean: '7891000000011',
          name: 'Medicamento demonstrativo',
          unitPriceInCents: 2500,
        ),
      ],
      status: CheckoutStatus.recoverableFailure,
      remoteCheckoutId: 'remote-01',
      retryTargetStatus: CheckoutStatus.awaitingConfirmation,
      statusMessage: 'Falha ao confirmar o checkout.',
      idempotencyKey: null,
    );

    final map = CheckoutSessionSnapshot.fromDomain(session).toMap();

    expect(map, <String, Object?>{
      'id': 'session-01',
      'availableBalanceInCents': 25000,
      'prescription': <String, Object?>{'reference': 'RX-001'},
      'medications': <Object?>[
        <String, Object?>{
          'ean': '7891000000011',
          'name': 'Medicamento demonstrativo',
          'unitPriceInCents': 2500,
        },
      ],
      'status': 'recoverableFailure',
      'remoteCheckoutId': 'remote-01',
      'retryTargetStatus': 'awaitingConfirmation',
      'statusMessage': 'Falha ao confirmar o checkout.',
      'idempotencyKey': null,
    });
  });

  test('restores a checkout session from serialized data', () {
    final snapshot = CheckoutSessionSnapshot.fromMap(<String, Object?>{
      'id': 'session-01',
      'availableBalanceInCents': 25000,
      'prescription': <String, Object?>{'reference': 'RX-001'},
      'medications': <Object?>[
        <String, Object?>{
          'ean': '7891000000011',
          'name': 'Medicamento demonstrativo',
          'unitPriceInCents': 2500,
        },
      ],
      'status': 'recoverableFailure',
      'remoteCheckoutId': 'remote-01',
      'retryTargetStatus': 'awaitingConfirmation',
      'statusMessage': 'Falha ao confirmar o checkout.',
      'idempotencyKey': null,
    });

    final session = snapshot.toDomain();

    expect(session.id, 'session-01');
    expect(session.availableBalanceInCents, 25000);
    expect(session.prescription?.reference, 'RX-001');
    expect(session.medications, hasLength(1));
    expect(session.medications.single.ean, '7891000000011');
    expect(session.medications.single.name, 'Medicamento demonstrativo');
    expect(session.medications.single.unitPriceInCents, 2500);
    expect(session.status, CheckoutStatus.recoverableFailure);
    expect(session.remoteCheckoutId, 'remote-01');
    expect(session.retryTargetStatus, CheckoutStatus.awaitingConfirmation);
    expect(session.statusMessage, 'Falha ao confirmar o checkout.');
  });

  test('preserves the complete session through a JSON round trip', () {
    final originalSession = CheckoutSession(
      id: 'session-02',
      availableBalanceInCents: 18000,
      prescription: const Prescription(reference: 'RX-002'),
      medications: const [
        Medication(
          ean: '7891000000028',
          name: 'Medicamento persistido',
          unitPriceInCents: 3200,
        ),
      ],
      status: CheckoutStatus.awaitingConfirmation,
      remoteCheckoutId: 'remote-02',
      idempotencyKey: null,
    );

    final encoded = jsonEncode(
      CheckoutSessionSnapshot.fromDomain(originalSession).toMap(),
    );

    final decoded = jsonDecode(encoded) as Map<String, Object?>;

    final restoredSession = CheckoutSessionSnapshot.fromMap(decoded).toDomain();

    expect(restoredSession.id, originalSession.id);
    expect(
      restoredSession.availableBalanceInCents,
      originalSession.availableBalanceInCents,
    );
    expect(
      restoredSession.prescription?.reference,
      originalSession.prescription?.reference,
    );
    expect(restoredSession.medications, hasLength(1));
    expect(
      restoredSession.medications.single.ean,
      originalSession.medications.single.ean,
    );
    expect(
      restoredSession.medications.single.name,
      originalSession.medications.single.name,
    );
    expect(
      restoredSession.medications.single.unitPriceInCents,
      originalSession.medications.single.unitPriceInCents,
    );
    expect(restoredSession.status, originalSession.status);
    expect(restoredSession.remoteCheckoutId, originalSession.remoteCheckoutId);
    expect(restoredSession.retryTargetStatus, isNull);
    expect(restoredSession.statusMessage, isNull);
  });
}
