import 'package:dio/dio.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

typedef AuthTokenProvider = Future<String?> Function();

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
          final token = await tokenProvider();

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
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
