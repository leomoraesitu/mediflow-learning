import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/checkout_api_client.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

import 'fake_http_client_adapter.dart';

void main() {
  late Dio dio;
  late FakeHttpClientAdapter fakeAdapter;

  setUp(() {
    fakeAdapter = FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'))..httpClientAdapter = fakeAdapter;
  });
  tearDown(() {
    dio.close(force: true);
  });

  test('sends the auth token as a Bearer header when one is available', () async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async => 'test-token',
    );

    await apiClient.post('/checkouts', data: const {});

    final capturedHeaders = fakeAdapter.capturedHeaders['/checkouts']?.first;

    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders!['Authorization'], 'Bearer test-token');
  });
  test('sends the request without an Authorization header when there is no token', () async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async => null,
    );

    await apiClient.post('/checkouts', data: const {});

    final capturedHeaders = fakeAdapter.capturedHeaders['/checkouts']?.first;
    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders!['Authorization'], isNull);
  });

  test('retries the request with a renewed token after a 401', ({bool forceRefresh = false}) async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async =>
          forceRefresh ? 'test-token-renewed' : 'test-token',
    );

    final response = await apiClient.post('/checkouts', data: const {});
    expect(response['id'], 'remote-checkout-id');

    final capturedHeaders = fakeAdapter.capturedHeaders['/checkouts'];

    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders, hasLength(2));

    expect(capturedHeaders![0]['Authorization'], 'Bearer test-token');

    expect(capturedHeaders[1]['Authorization'], 'Bearer test-token-renewed');
  });
  test('retries at most once when the renewed token is also rejected', () async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async =>
          forceRefresh ? 'test-token-renewed' : 'test-token',
    );

    await expectLater(
      () => apiClient.post('/checkouts', data: const {}),
      throwsA(isA<PermanentFailure>()),
    );

    final capturedHeaders = fakeAdapter.capturedHeaders['/checkouts'];

    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders, hasLength(2));

    expect(capturedHeaders![0]['Authorization'], 'Bearer test-token');

    expect(capturedHeaders[1]['Authorization'], 'Bearer test-token-renewed');
  });
  test('does not renew the token when the failure is not about identity', () async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async =>
          forceRefresh ? 'test-token-renewed' : 'test-token',
      retryDelays: const [],
    );

    await expectLater(
      () => apiClient.post('/checkouts', data: const {}),
      throwsA(isA<ServerUnavailableFailure>()),
    );

    final capturedHeaders = fakeAdapter.capturedHeaders['/checkouts'];

    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders, hasLength(1));

    expect(capturedHeaders![0]['Authorization'], 'Bearer test-token');
  });
  test('retries a transient failure and succeeds on the next attempt', () async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async => 'test-token',
      retryDelays: const [Duration.zero, Duration.zero],
    );

    final response = await apiClient.post('/checkouts', data: const {});
    expect(response, equals(<String, dynamic>{'id': 'remote-checkout-id'}));

    final capturedHeaders = fakeAdapter.capturedHeaders['/checkouts'];
    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders, hasLength(2));

    expect(capturedHeaders?[0]['Authorization'], 'Bearer test-token');
    expect(capturedHeaders?[1]['Authorization'], 'Bearer test-token');
  });

  test('gives up after the configured number of attempts', () async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async => 'test-token',
      retryDelays: const [Duration.zero, Duration.zero],
    );

    await expectLater(
      () => apiClient.post('/checkouts', data: const {}),
      throwsA(isA<ServerUnavailableFailure>()),
    );

    final capturedHeaders = fakeAdapter.capturedHeaders['/checkouts'];
    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders, hasLength(3));

    expect(capturedHeaders?[0]['Authorization'], 'Bearer test-token');
    expect(capturedHeaders?[1]['Authorization'], 'Bearer test-token');
    expect(capturedHeaders?[2]['Authorization'], 'Bearer test-token');
  });

  test('does not retry a permanent failure', () async {
    fakeAdapter.mockedResponses['/checkouts'] = [
      ResponseBody.fromString(
        '{"id": "remote-checkout-id"}',
        400,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ];

    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async => 'test-token',
      retryDelays: const [Duration.zero, Duration.zero],
    );

    await expectLater(
      () => apiClient.post('/checkouts', data: const {}),
      throwsA(isA<PermanentFailure>()),
    );

    final capturedHeaders = fakeAdapter.capturedHeaders['/checkouts'];
    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders, hasLength(1));

    expect(capturedHeaders?[0]['Authorization'], 'Bearer test-token');
  });
  test('does not retry an unclassified failure', () async {
    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async => 'test-token',
      retryDelays: const [Duration.zero, Duration.zero],
    );

    await expectLater(
      () => apiClient.post('/sem-resposta', data: const {}),
      throwsA(isA<UnknownFailure>()),
    );

    final capturedHeaders = fakeAdapter.capturedHeaders['/sem-resposta'];
    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders, hasLength(1));

    expect(capturedHeaders?[0]['Authorization'], 'Bearer test-token');
  });
  test('reports an unknown failure when the token provider throws', () async {
    final apiClient = CheckoutApiClient.withDio(
      dio,
      tokenProvider: ({bool forceRefresh = false}) async {
        throw Exception('Token provider error');
      },
      retryDelays: const [Duration.zero, Duration.zero],
    );

    await expectLater(
      () => apiClient.post('/checkouts', data: const {}),
      throwsA(isA<UnknownFailure>()),
    );

    // Nenhuma requisição é capturada: a exceção nasce no `onRequest`, antes
    // do envio. É exatamente o que os logs da function mostraram na Aula 40
    // — nada chega ao servidor, e por isso não existe 401 para acionar a
    // renovação de identidade.
    expect(fakeAdapter.capturedHeaders['/checkouts'], isNull);
  });
}
