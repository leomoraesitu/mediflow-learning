import 'package:checkout_domain/checkout_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/dio_medication_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

import 'fake_http_client_adapter.dart';

void main() {
  late Dio dio;
  late FakeHttpClientAdapter fakeAdapter;
  late CheckoutApiClient apiClient;
  late DioMedicationRepository repository;
  late Medication medication;

  setUp(() {
    fakeAdapter = FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = fakeAdapter;

    apiClient = CheckoutApiClient(dio: dio);
    repository = DioMedicationRepository(apiClient: apiClient);
    medication = Medication(
      ean: '1234567890123',
      name: 'Some Medication',
      unitPriceInCents: 10,
    );
  });

  test(
    'returns true when the API confirms the medication is eligible',
    () async {
      fakeAdapter
              .mockedResponses['/medications/${medication.ean}/eligibility'] =
          ResponseBody.fromString(
            '{"isEligible": true}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      expect(await repository.checkEligibility(medication), isTrue);
    },
  );
  test(
    'returns false when the API confirms the medication is not eligible',
    () async {
      fakeAdapter
              .mockedResponses['/medications/${medication.ean}/eligibility'] =
          ResponseBody.fromString(
            '{"isEligible": false}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      expect(await repository.checkEligibility(medication), isFalse);
    },
  );
  test(
    'throws an exception when the API responds with a server error',
    () async {
      fakeAdapter
              .mockedResponses['/medications/${medication.ean}/eligibility'] =
          ResponseBody.fromString(
            'Internal Server Error',
            500,
            headers: {
              Headers.contentTypeHeader: [Headers.textPlainContentType],
            },
          );

      expect(
        () async => await repository.checkEligibility(medication),
        throwsA(isA<ServerUnavailableFailure>()),
      );
    },
  );
  test('throws an exception when the response body is missing the eligibility field', () {
    fakeAdapter.mockedResponses['/medications/${medication.ean}/eligibility'] =
        ResponseBody.fromString(
          '{"someOtherField": true}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    expect(
      () async => await repository.checkEligibility(medication),
      throwsA(isA<Exception>()),
    );
  });
}
