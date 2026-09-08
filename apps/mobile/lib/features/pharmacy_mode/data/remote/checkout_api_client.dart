import 'package:dio/dio.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

final class CheckoutApiClient {
  final Dio _dio;

  CheckoutApiClient({required String baseUrl, required Duration timeout})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: timeout,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );

  CheckoutApiClient.withDio(Dio dio) : _dio = dio;

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
