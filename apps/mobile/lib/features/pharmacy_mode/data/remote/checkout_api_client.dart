import 'package:dio/dio.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/network_failure.dart';

final class CheckoutApiClient {
  final Dio _dio;

  CheckoutApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://mediflow.example',
              connectTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);

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
