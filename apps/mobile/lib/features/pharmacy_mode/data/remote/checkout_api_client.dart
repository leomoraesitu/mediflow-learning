import 'package:dio/dio.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

typedef AuthTokenProvider = Future<String?> Function({bool forceRefresh});

final class CheckoutApiClient {
  final Dio _dio;
  final List<Duration> _retryDelays;
  static const List<Duration> defaultRetryDelays = [
    Duration(milliseconds: 200),
    Duration(milliseconds: 400),
  ];

  CheckoutApiClient({
    required String baseUrl,
    required Duration timeout,
    required AuthTokenProvider tokenProvider,
    this._retryDelays = defaultRetryDelays,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: timeout,
           sendTimeout: timeout,
           receiveTimeout: timeout,
         ),
       ) {
    _addAuthInterceptor(tokenProvider);
    _addRetryInterceptor();
  }

  CheckoutApiClient.withDio(
    Dio dio, {
    required AuthTokenProvider tokenProvider,
    this._retryDelays = defaultRetryDelays,
  }) : _dio = dio {
    _addAuthInterceptor(tokenProvider);
    _addRetryInterceptor();
  }

  static bool _isTransient(NetworkFailure failure) => switch (failure) {
    TimeoutFailure() || ServerUnavailableFailure() || ConnectivityFailure() => true,
    PermanentFailure() || UnknownFailure() => false,
  };

  void _addRetryInterceptor() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) async {
          final options = e.requestOptions;
          final attempt = (options.extra['retryCount'] as int?) ?? 0;

          if (attempt >= _retryDelays.length) {
            return handler.next(e);
          }

          if (!_isTransient(NetworkFailure.fromDioException(e))) {
            return handler.next(e);
          }

          await Future<void>.delayed(_retryDelays[attempt]);
          options.extra['retryCount'] = attempt + 1;

          try {
            handler.resolve(await _dio.fetch<dynamic>(options));
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  void _addAuthInterceptor(AuthTokenProvider tokenProvider) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['authRetried'] == true) {
            return handler.next(options);
          }

          final token = await tokenProvider();

          // Sem credencial, a requisição não sai. Sem `Authorization` o
          // backend responde 401 com certeza, e com os três gatilhos do
          // outbox isso vira laço: cada gatilho gasta uma ida à rede para
          // descobrir algo que já se sabia antes de sair.
          //
          // `cancel` descreve o que aconteceu — cancelada antes de partir — e
          // o classificador a mapeia para `UnknownFailure`, que não é
          // transitória. Duas barreiras independentes impedem a retentativa:
          // essa classificação, e o fato de `reject` não chamar os
          // interceptores de erro seguintes por padrão.
          //
          // Sem `error:`: quem decide o tipo entregue ao chamador é
          // `NetworkFailure.fromDioException`, que olha só o `type`.
          if (token == null) {
            return handler.reject(
              DioException(requestOptions: options, type: DioExceptionType.cancel),
            );
          }

          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },

        onError: (DioException e, handler) async {
          final options = e.requestOptions;
          final triedTwice = options.extra['authRetried'] == true;

          if (e.response?.statusCode != 401 || triedTwice) {
            return handler.next(e);
          }

          final token = await tokenProvider(forceRefresh: true);
          if (token == null) {
            return handler.next(e);
          }

          options.headers['Authorization'] = 'Bearer $token';
          options.extra['authRetried'] = true;

          try {
            final response = await _dio.fetch<dynamic>(options);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> data,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(headers: headers),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkFailure.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get(path);

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkFailure.fromDioException(e);
    }
  }
}
