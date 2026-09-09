import 'dart:typed_data';

import 'package:dio/dio.dart';

final class FakeHttpClientAdapter implements HttpClientAdapter {
  final Map<String, List<ResponseBody>> mockedResponses = {};
  final Map<String, List<Map<String, dynamic>>> capturedHeaders = {};
  final Map<String, int> _callCounts = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedHeaders
        .putIfAbsent(options.path, () => [])
        .add(Map<String, dynamic>.from(options.headers));

    final responses = mockedResponses[options.path];

    if (responses == null || responses.isEmpty) {
      throw StateError('No mocked response configured for path: ${options.path}');
    }

    final callCount = _callCounts.putIfAbsent(options.path, () => 0);

    if (callCount >= responses.length) {
      throw StateError(
        'Mocked response queue exhausted for path: ${options.path}. '
        'Configured responses: ${responses.length}. '
        'Attempted request: ${callCount + 1}.',
      );
    }

    final response = responses[callCount];
    _callCounts[options.path] = callCount + 1;

    return response;
  }

  @override
  void close({bool force = false}) {
    capturedHeaders.clear();
    _callCounts.clear();
    mockedResponses.clear();
  }
}
