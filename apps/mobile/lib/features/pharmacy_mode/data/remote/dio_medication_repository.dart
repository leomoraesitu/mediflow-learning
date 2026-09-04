import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';

final class DioMedicationRepository implements MedicationRepository {
  final CheckoutApiClient _apiClient;

  const DioMedicationRepository({required this._apiClient});

  @override
  Future<bool> checkEligibility(Medication medication) async {
    final response = await _apiClient.get(
      '/medications/${medication.ean}/eligibility',
    );

    final isEligible = response['isEligible'] as bool?;
    if (isEligible == null) {
      throw Exception('Erro ao validar o medicamento: Resposta inválida');
    }
    return isEligible;
  }
}
