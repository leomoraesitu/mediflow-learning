import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';

final class DioPrescriptionRepository implements PrescriptionRepository {
  final CheckoutApiClient _apiClient;

  const DioPrescriptionRepository({required this._apiClient});

  @override
  Future<bool> validate(Prescription prescription) async {
    final response = await _apiClient.post(
      '/prescriptions/validate',
      data: {'reference': prescription.reference},
    );

    final isValid = response['isValid'] as bool?;
    if (isValid == null) {
      throw Exception('Erro ao validar a prescrição: Resposta inválida');
    }
    return isValid;
  }
}
