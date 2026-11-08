import 'package:pulse/core/errors/error_codes.dart';

/// Contract every app error fulfils (ERR-02). Upper layers depend on this
/// interface, never on pulse_api exception types.
abstract interface class AppException implements Exception {
  /// Stable machine code, see [ErrorCodes].
  String get code;

  /// Original error, kept for logs only.
  Object? get cause;

  StackTrace? get stackTrace;

  /// True when repeating the same request is safe.
  bool get isRetryable;
}

String _describe(String type, String code, int? status) => status == null
    ? '$type(code: $code)'
    : '$type(code: $code, status: $status)';

/// Errors that came from the backend.
abstract class ServerException implements AppException {
  const ServerException({
    required this.code,
    required this.statusCode,
    this.serverMessage,
    this.cause,
    this.stackTrace,
  });

  @override
  final String code;
  final int statusCode;

  /// Raw server text. For logs only - never shown to the user.
  final String? serverMessage;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  @override
  bool get isRetryable => false;

  @override
  String toString() => _describe(runtimeType.toString(), code, statusCode);
}

class InvalidRequestException extends ServerException {
  const InvalidRequestException({
    required super.code,
    super.serverMessage,
    super.cause,
    super.stackTrace,
  }) : super(statusCode: 400);
}

class NotFoundException extends ServerException {
  const NotFoundException({
    required super.code,
    super.serverMessage,
    super.cause,
    super.stackTrace,
  }) : super(statusCode: 404);
}

class IdempotencyConflictException extends ServerException {
  const IdempotencyConflictException({
    super.serverMessage,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCodes.idempotencyConflict, statusCode: 409);
}

/// 422 business rules (insufficient funds, halted, watchlist full, ...).
class BusinessRuleException extends ServerException {
  const BusinessRuleException({
    required super.code,
    super.serverMessage,
    super.cause,
    super.stackTrace,
  }) : super(statusCode: 422);
}

class ServiceUnavailableException extends ServerException {
  const ServiceUnavailableException({
    super.serverMessage,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCodes.serviceUnavailable, statusCode: 503);

  @override
  bool get isRetryable => true;
}

class UnknownServerException extends ServerException {
  const UnknownServerException({
    required super.code,
    required super.statusCode,
    super.serverMessage,
    super.cause,
    super.stackTrace,
  });
}

/// Errors produced on the device.
abstract class ClientException implements AppException {
  const ClientException({required this.code, this.cause, this.stackTrace});

  @override
  final String code;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  @override
  bool get isRetryable => false;

  @override
  String toString() => _describe(runtimeType.toString(), code, null);
}

class ValidationException extends ClientException {
  const ValidationException({
    required this.field,
    required this.rule,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCodes.validation);

  final String field;
  final String rule;
}

/// Payload missing/mis-typed. Never a raw `TypeError` (PARSE-03).
class ParsingException extends ClientException {
  const ParsingException({
    required this.field,
    this.expectedType,
    this.actualType,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCodes.parsing);

  final String field;
  final String? expectedType;
  final String? actualType;
}

/// The request outcome is UNKNOWN (not "failed") - see ORD-04.
class RequestTimeoutException extends ClientException {
  const RequestTimeoutException({super.cause, super.stackTrace})
    : super(code: ErrorCodes.requestTimeout);
}

class StreamDisconnectedException extends ClientException {
  const StreamDisconnectedException({super.cause, super.stackTrace})
    : super(code: ErrorCodes.streamDisconnected);

  @override
  bool get isRetryable => true;
}

class StorageException extends ClientException {
  const StorageException({super.cause, super.stackTrace})
    : super(code: ErrorCodes.storage);
}

/// Last resort wrapper for unknown errors.
class UnexpectedException extends ClientException {
  const UnexpectedException({required Object super.cause, super.stackTrace})
    : super(code: ErrorCodes.unexpected);
}
