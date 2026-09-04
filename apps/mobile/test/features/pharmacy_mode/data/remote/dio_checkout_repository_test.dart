import 'package:checkout_domain/checkout_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/dio_checkout_repository.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

import 'fake_http_client_adapter.dart';

void main() {
  late Dio dio;
  late FakeHttpClientAdapter fakeAdapter;
  late CheckoutApiClient apiClient;
  late DioCheckoutRepository repository;
  late CheckoutSession session;

  setUp(() {
    fakeAdapter = FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = fakeAdapter;

    apiClient = CheckoutApiClient(dio: dio);
    repository = DioCheckoutRepository(apiClient: apiClient);
    session = CheckoutSession(
      id: 'session-id',
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
      status: CheckoutStatus.paid,
    );
  });

  test(
    'returns the remote checkout id when the API confirms creation',
    () async {
      fakeAdapter.mockedResponses['/checkouts'] = ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      final remoteCheckoutId = await repository.create(session);
      expect(remoteCheckoutId, 'remote-checkout-id');
    },
  );
  test(
    'throws an exception when the API responds with a server error',
    () async {
      fakeAdapter.mockedResponses['/checkouts'] = ResponseBody.fromString(
        'Internal Server Error',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.textPlainContentType],
        },
      );

      expect(
        () async => await repository.create(session),
        throwsA(isA<ServerUnavailableFailure>()),
      );
    },
  );
  test(
    'throws an exception when the response body is missing the id',
    () async {
      fakeAdapter.mockedResponses['/checkouts'] = ResponseBody.fromString(
        '{"name": "Test Checkout"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      expect(
        () async => await repository.create(session),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'returns the checkout session when the API responds with valid data',
    () async {
      fakeAdapter.mockedResponses['/checkouts/remote-checkout-id'] =
          ResponseBody.fromString(
            '{"id": "remote-checkout-id", "availableBalanceInCents": 1000, "status": "paid", "medications": []}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      final checkoutSession = await repository.getById('remote-checkout-id');
      expect(checkoutSession.id, 'remote-checkout-id');
      expect(checkoutSession.availableBalanceInCents, 1000);
      expect(checkoutSession.status, CheckoutStatus.paid);
    },
  );
  test(
    'throws an exception when the API responds with a server error for getById',
    () async {
      fakeAdapter.mockedResponses['/checkouts/remote-checkout-id'] =
          ResponseBody.fromString(
            'Internal Server Error',
            500,
            headers: {
              Headers.contentTypeHeader: [Headers.textPlainContentType],
            },
          );

      expect(
        () async => await repository.getById('remote-checkout-id'),
        throwsA(isA<ServerUnavailableFailure>()),
      );
    },
  );
  test(
    'throws an exception when the response body has an invalid status',
    () async {
      fakeAdapter.mockedResponses['/checkouts/remote-checkout-id'] =
          ResponseBody.fromString(
            '{"id": "remote-checkout-id", "availableBalanceInCents": 1000, "status": "invalid", "medications": []}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      expect(
        () async => await repository.getById('remote-checkout-id'),
        throwsA(isA<Exception>()),
      );
    },
  );
  test('throws an exception when the response body is a client error', () {
    fakeAdapter.mockedResponses['/checkouts/remote-checkout-id'] =
        ResponseBody.fromString(
          '{"id": "remote-checkout-id", "availableBalanceInCents": 1000, "status": "invalid", "medications": []}',
          400,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    expect(
      () async => await repository.getById('remote-checkout-id'),
      throwsA(isA<PermanentFailure>()),
    );
  });
  test(
    'sends the session idempotency key as a header when creating a checkout',
    () async {
      fakeAdapter.mockedResponses['/checkouts'] = ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      final sessionWithIdempotencyKey = CheckoutSession(
        id: 'session-id',
        availableBalanceInCents: 1000,
        prescription: null,
        medications: [],
        status: CheckoutStatus.paid,
        idempotencyKey: 'unique-key',
      );

      await repository.create(sessionWithIdempotencyKey);

      final requestOptions = fakeAdapter.capturedHeaders['/checkouts'];
      expect(requestOptions, isNotNull);
      expect(requestOptions!['Idempotency-Key'], 'unique-key');
    },
  );
}
