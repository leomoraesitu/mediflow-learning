import 'package:checkout_domain/checkout_domain.dart';

final class CheckoutSessionSnapshot {
  final String id;
  final int availableBalanceInCents;
  final Prescription? prescription;
  final List<Medication> medications;
  final CheckoutStatus status;
  final String? remoteCheckoutId;
  final CheckoutStatus? retryTargetStatus;
  final String? statusMessage;
  final String? idempotencyKey;

  CheckoutSessionSnapshot._({
    required this.id,
    required this.availableBalanceInCents,
    required this.prescription,
    required List<Medication> medications,
    required this.status,
    required this.remoteCheckoutId,
    required this.retryTargetStatus,
    required this.statusMessage,
    required this.idempotencyKey,
  }) : medications = List.unmodifiable(medications);

  factory CheckoutSessionSnapshot.fromDomain(CheckoutSession session) {
    return CheckoutSessionSnapshot._(
      id: session.id,
      availableBalanceInCents: session.availableBalanceInCents,
      prescription: session.prescription,
      medications: session.medications,
      status: session.status,
      remoteCheckoutId: session.remoteCheckoutId,
      retryTargetStatus: session.retryTargetStatus,
      statusMessage: session.statusMessage,
      idempotencyKey: session.idempotencyKey,
    );
  }

  factory CheckoutSessionSnapshot.fromMap(Map<String, Object?> map) {
    final prescriptionMap = map['prescription'] as Map<String, Object?>?;

    final medicationMaps = (map['medications'] as List<Object?>)
        .cast<Map<String, Object?>>();

    final retryTargetStatusName = map['retryTargetStatus'] as String?;

    return CheckoutSessionSnapshot._(
      id: map['id'] as String,
      availableBalanceInCents: map['availableBalanceInCents'] as int,
      prescription: prescriptionMap == null
          ? null
          : Prescription(reference: prescriptionMap['reference'] as String),
      medications: [
        for (final medicationMap in medicationMaps)
          Medication(
            ean: medicationMap['ean'] as String,
            name: medicationMap['name'] as String,
            unitPriceInCents: medicationMap['unitPriceInCents'] as int,
          ),
      ],
      status: CheckoutStatus.values.byName(map['status'] as String),
      remoteCheckoutId: map['remoteCheckoutId'] as String?,
      retryTargetStatus: retryTargetStatusName == null
          ? null
          : CheckoutStatus.values.byName(retryTargetStatusName),
      statusMessage: map['statusMessage'] as String?,
      idempotencyKey: map['idempotencyKey'] as String?,
    );
  }

  CheckoutSession toDomain() {
    return CheckoutSession(
      id: id,
      availableBalanceInCents: availableBalanceInCents,
      prescription: prescription,
      medications: medications,
      status: status,
      remoteCheckoutId: remoteCheckoutId,
      retryTargetStatus: retryTargetStatus,
      statusMessage: statusMessage,
      idempotencyKey: idempotencyKey,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'availableBalanceInCents': availableBalanceInCents,
      'prescription': prescription == null
          ? null
          : <String, Object?>{'reference': prescription!.reference},
      'medications': <Object?>[
        for (final medication in medications)
          <String, Object?>{
            'ean': medication.ean,
            'name': medication.name,
            'unitPriceInCents': medication.unitPriceInCents,
          },
      ],
      'status': status.name,
      'remoteCheckoutId': remoteCheckoutId,
      'retryTargetStatus': retryTargetStatus?.name,
      'statusMessage': statusMessage,
      'idempotencyKey': idempotencyKey,
    };
  }
}
