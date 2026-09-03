import 'dart:typed_data';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/dio_prescription_repository.dart';

void main() {
  late Dio dio;
  late _FakeHttpClientAdapter fakeAdapter;
  late CheckoutApiClient apiClient;
  late DioPrescriptionRepository repository;
  late Prescription prescription;

  setUp(() {
    fakeAdapter = _FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = fakeAdapter;

    // Inicialização das dependências no setUp
    apiClient = CheckoutApiClient(dio: dio);
    repository = DioPrescriptionRepository(apiClient: apiClient);
    prescription = Prescription(reference: 'some-prescription');
  });

  test(
    'returns true when the API confirms the prescription is valid',
    () async {
      fakeAdapter._mockedResponses['/prescriptions/validate'] =
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
      fakeAdapter._mockedResponses['/prescriptions/validate'] =
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
      fakeAdapter._mockedResponses['/prescriptions/validate'] =
          ResponseBody.fromString(
            'Internal Server Error',
            500,
            headers: {
              Headers.contentTypeHeader: [Headers.textPlainContentType],
            },
          );

      expect(
        () async => repository.validate(prescription),
        throwsA(isA<Exception>()),
      );
    },
  );
  test(
    'throws an exception when the response body is missing isValid',
    () async {
      fakeAdapter._mockedResponses['/prescriptions/validate'] =
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

final class _FakeHttpClientAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody> _mockedResponses = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = _mockedResponses[options.path];
    if (response != null) {
      return response;
    }
    throw Exception('No mocked response found for path: ${options.path}');
  }

  @override
  void close({bool force = false}) {}
}
