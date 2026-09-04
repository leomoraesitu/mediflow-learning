import 'package:checkout_domain/checkout_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/dio_prescription_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

import 'fake_http_client_adapter.dart';

void main() {
  late Dio dio;
  late FakeHttpClientAdapter fakeAdapter;
  late CheckoutApiClient apiClient;
  late DioPrescriptionRepository repository;
  late Prescription prescription;

  setUp(() {
    fakeAdapter = FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = fakeAdapter;

    apiClient = CheckoutApiClient(dio: dio);
    repository = DioPrescriptionRepository(apiClient: apiClient);
    prescription = Prescription(reference: 'some-prescription');
  });

  test(
    'returns true when the API confirms the prescription is valid',
    () async {
      fakeAdapter.mockedResponses['/prescriptions/validate'] =
          ResponseBody.fromString(
            '{"isValid": true}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      expect(await repository.validate(prescription), isTrue);
    },
  );

  test(
    'returns false when the API confirms the prescription is invalid',
    () async {
      fakeAdapter.mockedResponses['/prescriptions/validate'] =
          ResponseBody.fromString(
            '{"isValid": false}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      expect(await repository.validate(prescription), isFalse);
    },
  );
  test(
    'throws an exception when the API responds with a server error',
    () async {
      fakeAdapter.mockedResponses['/prescriptions/validate'] =
          ResponseBody.fromString(
            'Internal Server Error',
            500,
            headers: {
              Headers.contentTypeHeader: [Headers.textPlainContentType],
            },
          );

      expect(
        () async => repository.validate(prescription),
        throwsA(isA<ServerUnavailableFailure>()),
      );
    },
  );
  test(
    'throws an exception when the response body is missing isValid',
    () async {
      fakeAdapter.mockedResponses['/prescriptions/validate'] =
          ResponseBody.fromString(
            '{"someOtherField": true}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      expect(
        () async => repository.validate(prescription),
        throwsA(isA<Exception>()),
      );
    },
  );
}
