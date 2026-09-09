import 'package:dio/dio.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

typedef AuthTokenProvider = Future<String?> Function({bool forceRefresh});

final class CheckoutApiClient {
  final Dio _dio;

  CheckoutApiClient({
    required String baseUrl,
    required Duration timeout,
    required AuthTokenProvider tokenProvider,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: timeout,
           sendTimeout: timeout,
           receiveTimeout: timeout,
         ),
       ) {
    _addAuthInterceptor(tokenProvider);
  }

  CheckoutApiClient.withDio(Dio dio, {required AuthTokenProvider tokenProvider}) : _dio = dio {
    _addAuthInterceptor(tokenProvider);
  }

  void _addAuthInterceptor(AuthTokenProvider tokenProvider) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Numa retentativa, o header já foi definido pelo onError com a
          // credencial renovada. Reescrevê-lo aqui desfaria a renovação.
          if (options.extra['authRetried'] == true) {
            return handler.next(options);
          }

          final token = await tokenProvider();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
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
