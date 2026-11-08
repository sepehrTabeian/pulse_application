import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/error_codes.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse_api/pulse_api.dart';

void main() {
  late ExceptionMapper mapper;

  setUp(() => mapper = const PulseApiExceptionMapper());

  group('ApiException mapping', () {
    test('503 maps to retryable ServiceUnavailableException', () {
      final e = mapper.map(ApiException(503, 'SERVICE_UNAVAILABLE', 'x'));

      expect(e, isA<ServiceUnavailableException>());
      expect(e.isRetryable, isTrue);
    });

    test('503 with an unexpected code is still service unavailable', () {
      final e = mapper.map(ApiException(503, 'SOMETHING_ELSE', 'x'));

      expect(e, isA<ServiceUnavailableException>());
    });

    test('400 maps to InvalidRequestException keeping the server code', () {
      final e = mapper.map(ApiException(400, 'INVALID_QUANTITY', 'bad'));

      expect(e, isA<InvalidRequestException>());
      expect(e.code, 'INVALID_QUANTITY');
      expect((e as ServerException).serverMessage, 'bad');
    });

    test('404 maps to NotFoundException', () {
      final e = mapper.map(ApiException(404, 'ORDER_NOT_FOUND', 'x'));

      expect(e, isA<NotFoundException>());
      expect(e.code, ErrorCodes.orderNotFound);
    });

    test('409 maps to IdempotencyConflictException', () {
      final e = mapper.map(ApiException(409, 'IDEMPOTENCY_CONFLICT', 'x'));

      expect(e, isA<IdempotencyConflictException>());
    });

    test('422 maps to BusinessRuleException for every documented code', () {
      for (final code in [
        'INSUFFICIENT_FUNDS',
        'INSUFFICIENT_POSITION',
        'TRADING_HALTED',
        'WATCHLIST_FULL',
      ]) {
        final e = mapper.map(ApiException(422, code, 'x'));

        expect(e, isA<BusinessRuleException>(), reason: code);
        expect(e.code, code);
        expect(e.isRetryable, isFalse);
      }
    });

    test('422 with an unknown code is still a BusinessRuleException', () {
      expect(
        mapper.map(ApiException(422, 'NEW_RULE', 'x')),
        isA<BusinessRuleException>(),
      );
    });

    test('unmapped status becomes UnknownServerException, not retryable', () {
      final e = mapper.map(ApiException(500, 'BOOM', 'x'));

      expect(e, isA<UnknownServerException>());
      expect(e.isRetryable, isFalse);
      expect((e as ServerException).statusCode, 500);
    });

    test('empty code is replaced by a stable fallback', () {
      final e = mapper.map(ApiException(418, '', ''));

      expect(e.code, isNotEmpty);
    });

    test('keeps original error and stack trace', () {
      final original = ApiException(503, 'SERVICE_UNAVAILABLE', 'x');
      final st = StackTrace.current;

      final e = mapper.map(original, st);

      expect(e.cause, same(original));
      expect(e.stackTrace, st);
    });
  });

  group('non-API errors', () {
    test(
      'TimeoutException maps to RequestTimeoutException (unknown outcome)',
      () {
        final e = mapper.map(TimeoutException('t'));

        expect(e, isA<RequestTimeoutException>());
        expect(e, isA<ClientException>());
      },
    );

    test('ConnectionLostException maps to StreamDisconnectedException', () {
      final e = mapper.map(ConnectionLostException());

      expect(e, isA<StreamDisconnectedException>());
      expect(e.isRetryable, isTrue);
    });

    test('FormatException maps to ParsingException', () {
      final e = mapper.map(const FormatException('bad json'));

      expect(e, isA<ParsingException>());
    });

    test('an AppException passes through unchanged', () {
      const original = StorageException();

      expect(mapper.map(original), same(original));
    });

    test('unknown objects are wrapped in UnexpectedException', () {
      for (final input in <Object>[Object(), 'str', 42, StateError('x')]) {
        final e = mapper.map(input);

        expect(e, isA<UnexpectedException>(), reason: '$input');
        expect(e.cause, same(input));
      }
    });

    test('TypeError (programming bug) is wrapped, not hidden', () {
      Object? caught;
      try {
        // ignore: unnecessary_cast
        (1 as Object) as String;
        // ignore: avoid_catching_errors - test must capture a real TypeError
      } on TypeError catch (e) {
        caught = e;
      }

      expect(mapper.map(caught!), isA<UnexpectedException>());
    });
  });
}
