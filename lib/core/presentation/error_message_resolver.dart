import 'package:pulse/core/constants/limits.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/error_codes.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';

/// Turns an [AppException] into a localized, user-friendly message (ERR-05).
abstract interface class ErrorMessageResolver {
  String resolve(AppException exception, AppLocalizations l10n);
}

class DefaultErrorMessageResolver implements ErrorMessageResolver {
  const DefaultErrorMessageResolver();

  @override
  String resolve(AppException exception, AppLocalizations l10n) {
    if (exception is ValidationException && exception.rule == 'duplicate') {
      return l10n.errorDuplicateSymbol;
    }
    final byCode = _byCode(exception.code, l10n);
    if (byCode != null) return byCode;
    if (exception is ServerException) return l10n.errorUnknownServer;
    return l10n.errorUnexpected;
  }

  String? _byCode(String code, AppLocalizations l10n) {
    return switch (code) {
      ErrorCodes.invalidQuantity => l10n.errorInvalidQuantity,
      ErrorCodes.invalidPrice => l10n.errorInvalidPrice,
      ErrorCodes.invalidRequest ||
      ErrorCodes.duplicateSymbol ||
      ErrorCodes.invalidRange => l10n.errorInvalidRequest,
      ErrorCodes.unknownSymbol => l10n.errorUnknownSymbol,
      ErrorCodes.orderNotFound => l10n.errorNotFound,
      ErrorCodes.idempotencyConflict => l10n.errorIdempotencyConflict,
      ErrorCodes.insufficientFunds => l10n.errorInsufficientFunds,
      ErrorCodes.insufficientPosition => l10n.errorInsufficientPosition,
      ErrorCodes.tradingHalted => l10n.errorTradingHalted,
      ErrorCodes.watchlistFull => l10n.errorWatchlistFull(
        AppLimits.watchlistMaxSymbols.toString(),
      ),
      ErrorCodes.serviceUnavailable => l10n.errorServiceUnavailable,
      ErrorCodes.requestTimeout => l10n.errorTimeout,
      ErrorCodes.streamDisconnected => l10n.errorConnectionLost,
      ErrorCodes.parsing => l10n.errorParsing,
      ErrorCodes.storage => l10n.errorStorage,
      ErrorCodes.validation => l10n.errorValidation,
      ErrorCodes.unexpected => l10n.errorUnexpected,
      _ => null,
    };
  }
}
