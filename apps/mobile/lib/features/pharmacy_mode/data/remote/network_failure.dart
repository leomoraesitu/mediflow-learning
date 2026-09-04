import 'package:dio/dio.dart';

sealed class NetworkFailure implements Exception {
  @override
  String toString() => message;
  final String message;
  const NetworkFailure(this.message);

  factory NetworkFailure.fromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure.defaultMessage();
      case DioExceptionType.connectionError:
        return const ConnectivityFailure.defaultMessage();
      case DioExceptionType.badResponse:
        final statusCode = exception.response?.statusCode;
        if (statusCode != null && statusCode >= 500) {
          return const ServerUnavailableFailure.defaultMessage();
        }
        if (statusCode != null) {
          return PermanentFailure.defaultMessage(statusCode);
        }
        return const UnknownFailure.defaultMessage();
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const UnknownFailure.defaultMessage();
    }
  }
}

final class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure(super.message);

  const TimeoutFailure.defaultMessage()
    : super('A requisição excedeu o tempo limite. Por favor, tente novamente.');
}

final class ServerUnavailableFailure extends NetworkFailure {
  const ServerUnavailableFailure(super.message);

  const ServerUnavailableFailure.defaultMessage()
    : super(
        'O servidor está indisponível no momento. Por favor, tente novamente mais tarde.',
      );
}

final class ConnectivityFailure extends NetworkFailure {
  const ConnectivityFailure(super.message);
  const ConnectivityFailure.defaultMessage()
    : super(
        'Não foi possível estabelecer uma conexão com a internet. Por favor, verifique sua conexão e tente novamente.',
      );
}

final class PermanentFailure extends NetworkFailure {
  final int statusCode;

  const PermanentFailure(this.statusCode, String message) : super(message);

  const PermanentFailure.defaultMessage(this.statusCode)
    : super(
        'Ocorreu um erro permanente (código de status: $statusCode). Por favor, entre em contato com o suporte.',
      );
}

final class UnknownFailure extends NetworkFailure {
  const UnknownFailure(super.message);
  const UnknownFailure.defaultMessage()
    : super('Ocorreu um erro desconhecido. Por favor, tente novamente.');
}
