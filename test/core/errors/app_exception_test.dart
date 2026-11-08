import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/error_codes.dart';

void main() {
  group('server exceptions', () {
    test('ServiceUnavailableException is retryable with status 503', () {
      const e = ServiceUnavailableException();

      expect(e, isA<ServerException>());
      expect(e, isA<AppException>());
      expect(e, isA<Exception>());
      expect(e.isRetryable, isTrue);
      expect(e.statusCode, 503);
      expect(e.code, ErrorCodes.serviceUnavailable);
    });

    test('all other server exceptions are not retryable', () {
      final others = <ServerException>[
        const InvalidRequestException(code: ErrorCodes.invalidQuantity),
        const NotFoundException(code: ErrorCodes.orderNotFound),
        const IdempotencyConflictException(),
        const BusinessRuleException(code: ErrorCodes.insufficientFunds),
        const UnknownServerException(code: 'X', statusCode: 500),
      ];

      for (final e in others) {
        expect(e.isRetryable, isFalse, reason: '${e.runtimeType}');
      }
    });

    test('status codes match the contract', () {
      expect(const InvalidRequestException(code: 'A').statusCode, 400);
      expect(const NotFoundException(code: 'A').statusCode, 404);
      expect(const IdempotencyConflictException().statusCode, 409);
      expect(const BusinessRuleException(code: 'A').statusCode, 422);
      expect(
        const UnknownServerException(code: 'A', statusCode: 500).statusCode,
        500,
      );
    });

    test('keeps cause, stack trace and raw server message for logs', () {
      final st = StackTrace.current;
      final e = BusinessRuleException(
        code: 'X',
        serverMessage: 'raw',
        cause: 'c',
        stackTrace: st,
      );

      expect(e.serverMessage, 'raw');
      expect(e.cause, 'c');
      expect(e.stackTrace, st);
    });

    test('toString contains runtime type and code but not the raw message', () {
      const e = BusinessRuleException(code: 'X', serverMessage: 'secret');

      expect(
        e.toString(),
        allOf(contains('BusinessRuleException'), contains('X')),
      );
      expect(e.toString(), isNot(contains('secret')));
    });
  });

  group('client exceptions', () {
    test('are ClientException/AppException and not server exceptions', () {
      final list = <ClientException>[
        const ValidationException(field: 'quantity', rule: 'lot_size'),
        const ParsingException(field: 'symbol'),
        const RequestTimeoutException(),
        const StreamDisconnectedException(),
        const StorageException(),
        const UnexpectedException(cause: Object()),
      ];

      for (final e in list) {
        expect(e, isA<AppException>());
        expect(e, isNot(isA<ServerException>()), reason: '${e.runtimeType}');
      }
    });

    test('only stream disconnection is retryable', () {
      expect(const StreamDisconnectedException().isRetryable, isTrue);
      expect(const RequestTimeoutException().isRetryable, isFalse);
      expect(
        const ValidationException(field: 'f', rule: 'r').isRetryable,
        isFalse,
      );
      expect(const ParsingException(field: 'f').isRetryable, isFalse);
      expect(const StorageException().isRetryable, isFalse);
      expect(const UnexpectedException(cause: 1).isRetryable, isFalse);
    });

    test('ValidationException exposes field and rule', () {
      const e = ValidationException(field: 'limitPrice', rule: 'tick_size');

      expect(e.field, 'limitPrice');
      expect(e.rule, 'tick_size');
      expect(e.code, ErrorCodes.validation);
    });

    test('ParsingException exposes field and types', () {
      const e = ParsingException(
        field: 'seq',
        expectedType: 'int',
        actualType: 'String',
      );

      expect(e.field, 'seq');
      expect(e.expectedType, 'int');
      expect(e.actualType, 'String');
      expect(e.code, ErrorCodes.parsing);
    });
  });
}
