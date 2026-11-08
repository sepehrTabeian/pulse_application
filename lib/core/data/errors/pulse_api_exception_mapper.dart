import 'dart:async';

import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/error_codes.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse_api/pulse_api.dart';

/// The only place that knows pulse_api exception types (ARCH-02, ERR-01).
class PulseApiExceptionMapper implements ExceptionMapper {
  const PulseApiExceptionMapper();

  @override
  AppException map(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) return error;
    if (error is ApiException) return _fromApi(error, stackTrace);
    if (error is TimeoutException) {
      return RequestTimeoutException(cause: error, stackTrace: stackTrace);
    }
    if (error is ConnectionLostException) {
      return StreamDisconnectedException(cause: error, stackTrace: stackTrace);
    }
    if (error is FormatException) {
      return ParsingException(
        field: 'body',
        expectedType: 'json',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedException(cause: error, stackTrace: stackTrace);
  }

  AppException _fromApi(ApiException e, StackTrace? st) {
    final code = e.code.isEmpty ? ErrorCodes.unknown : e.code;
    final message = e.message.isEmpty ? null : e.message;
    return switch (e.statusCode) {
      503 => ServiceUnavailableException(
        serverMessage: message,
        cause: e,
        stackTrace: st,
      ),
      400 => InvalidRequestException(
        code: code,
        serverMessage: message,
        cause: e,
        stackTrace: st,
      ),
      404 => NotFoundException(
        code: code,
        serverMessage: message,
        cause: e,
        stackTrace: st,
      ),
      409 => IdempotencyConflictException(
        serverMessage: message,
        cause: e,
        stackTrace: st,
      ),
      422 => BusinessRuleException(
        code: code,
        serverMessage: message,
        cause: e,
        stackTrace: st,
      ),
      _ => UnknownServerException(
        code: code,
        statusCode: e.statusCode,
        serverMessage: message,
        cause: e,
        stackTrace: st,
      ),
    };
  }
}
