import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';

final class DioCheckoutRepository implements CheckoutRepository {
  final CheckoutApiClient _apiClient;

  const DioCheckoutRepository({required this._apiClient});

  @override
  Future<String> create(CheckoutSession session) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/checkouts',
        data: {
          'id': session.id,
          'availableBalanceInCents': session.availableBalanceInCents,
          'prescription': session.prescription == null
              ? null
              : {'reference': session.prescription!.reference},
          'medications': [
            for (final medication in session.medications)
              {
                'ean': medication.ean,
                'name': medication.name,
                'unitPriceInCents': medication.unitPriceInCents,
              },
          ],
        },
      );
    } on Exception catch (e) {
      throw Exception('Erro ao criar o checkout: $e');
    }

    final remoteCheckoutId = response['id'] as String?;
    if (remoteCheckoutId == null) {
      throw Exception('Erro ao criar o checkout: Resposta inválida');
    }
    return remoteCheckoutId;
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.get('/checkouts/$remoteCheckoutId');
    } on Exception catch (e) {
      throw Exception('Erro ao obter o checkout: $e');
    }

    return _parseCheckoutSession(response);
  }
}

Future<CheckoutSession> _parseCheckoutSession(
  Map<String, dynamic> response,
) async {
  final id = response['id'] as String?;
  final availableBalanceInCents = response['availableBalanceInCents'] as int?;
  final prescriptionMap = response['prescription'] as Map<String, dynamic>?;
  final medicationsList = response['medications'] as List<dynamic>?;

  if (id == null ||
      availableBalanceInCents == null ||
      medicationsList == null ||
      response['status'] == null ||
      response['status'] is! String ||
      !CheckoutStatus.values.any((s) => s.name == response['status'])) {
    throw Exception('Erro ao obter o checkout: Resposta inválida');
  }

  final prescription = prescriptionMap == null
      ? null
      : Prescription(reference: prescriptionMap['reference'] as String);

  final medications = medicationsList.map((medicationMap) {
    final map = medicationMap as Map<String, dynamic>;
    return Medication(
      ean: map['ean'] as String,
      name: map['name'] as String,
      unitPriceInCents: map['unitPriceInCents'] as int,
    );
  }).toList();

  return CheckoutSession(
    id: id,
    availableBalanceInCents: availableBalanceInCents,
    prescription: prescription,
    medications: medications,
    status: CheckoutStatus.values.byName(response['status'] as String),
  );
}
