import 'dart:typed_data';

import 'package:dio/dio.dart';

final class FakeHttpClientAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody> mockedResponses = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = mockedResponses[options.path];
    if (response != null) {
      return response;
    }
    throw Exception('No mocked response found for path: ${options.path}');
  }

  @override
  void close({bool force = false}) {}
}
