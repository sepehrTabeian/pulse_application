import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';

class _ForeignException implements AppException {
  @override
  String get code => 'FOREIGN';
  @override
  Object? get cause => null;
  @override
  StackTrace? get stackTrace => null;
  @override
  bool get isRetryable => false;
}

void main() {
  final l10n = AppLocalizationsFa();
  const resolver = DefaultErrorMessageResolver();

  group('server codes', () {
    final cases = <String, ServerException Function(String)>{
      'INVALID_QUANTITY': (c) => InvalidRequestException(code: c),
      'INVALID_PRICE': (c) => InvalidRequestException(code: c),
      'INVALID_REQUEST': (c) => InvalidRequestException(code: c),
      'DUPLICATE_SYMBOL': (c) => InvalidRequestException(code: c),
      'INVALID_RANGE': (c) => InvalidRequestException(code: c),
      'UNKNOWN_SYMBOL': (c) => NotFoundException(code: c),
      'ORDER_NOT_FOUND': (c) => NotFoundException(code: c),
      'INSUFFICIENT_FUNDS': (c) => BusinessRuleException(code: c),
      'INSUFFICIENT_POSITION': (c) => BusinessRuleException(code: c),
      'TRADING_HALTED': (c) => BusinessRuleException(code: c),
      'WATCHLIST_FULL': (c) => BusinessRuleException(code: c),
    };

    test('every documented server code resolves to a non-empty message', () {
      cases.forEach((code, build) {
        expect(resolver.resolve(build(code), l10n), isNotEmpty, reason: code);
      });
    });

    test('specific codes map to specific localized messages', () {
      expect(
        resolver.resolve(
          const InvalidRequestException(code: 'INVALID_QUANTITY'),
          l10n,
        ),
        l10n.errorInvalidQuantity,
      );
      expect(
        resolver.resolve(
          const InvalidRequestException(code: 'INVALID_PRICE'),
          l10n,
        ),
        l10n.errorInvalidPrice,
      );
      expect(
        resolver.resolve(
          const BusinessRuleException(code: 'INSUFFICIENT_FUNDS'),
          l10n,
        ),
        l10n.errorInsufficientFunds,
      );
      expect(
        resolver.resolve(
          const BusinessRuleException(code: 'TRADING_HALTED'),
          l10n,
        ),
        l10n.errorTradingHalted,
      );
      expect(
        resolver.resolve(const IdempotencyConflictException(), l10n),
        l10n.errorIdempotencyConflict,
      );
      expect(
        resolver.resolve(const ServiceUnavailableException(), l10n),
        l10n.errorServiceUnavailable,
      );
    });

    test('watchlist full message shows the limit with Latin digits', () {
      final message = resolver.resolve(
        const BusinessRuleException(code: 'WATCHLIST_FULL'),
        l10n,
      );

      expect(message, contains('20'));
    });

    test('unknown server code falls back to a generic localized message', () {
      expect(
        resolver.resolve(const BusinessRuleException(code: 'NEW_RULE'), l10n),
        l10n.errorUnknownServer,
      );
      expect(
        resolver.resolve(
          const UnknownServerException(code: 'X', statusCode: 500),
          l10n,
        ),
        l10n.errorUnknownServer,
      );
    });

    test('raw server message is never shown to the user', () {
      final message = resolver.resolve(
        const BusinessRuleException(
          code: 'NEW_RULE',
          serverMessage: 'SECRET RAW',
        ),
        l10n,
      );

      expect(message, isNot(contains('SECRET')));
    });
  });

  group('client exceptions', () {
    test('each client exception maps to its localized message', () {
      expect(
        resolver.resolve(const RequestTimeoutException(), l10n),
        l10n.errorTimeout,
      );
      expect(
        resolver.resolve(const StreamDisconnectedException(), l10n),
        l10n.errorConnectionLost,
      );
      expect(
        resolver.resolve(const ParsingException(field: 'f'), l10n),
        l10n.errorParsing,
      );
      expect(
        resolver.resolve(const StorageException(), l10n),
        l10n.errorStorage,
      );
      expect(
        resolver.resolve(
          const ValidationException(field: 'f', rule: 'r'),
          l10n,
        ),
        l10n.errorValidation,
      );
      expect(
        resolver.resolve(const UnexpectedException(cause: 1), l10n),
        l10n.errorUnexpected,
      );
    });
  });

  test('a foreign AppException implementation falls back safely (DIP)', () {
    expect(resolver.resolve(_ForeignException(), l10n), l10n.errorUnexpected);
  });
}
