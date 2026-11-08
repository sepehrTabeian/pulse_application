import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/trading/domain/services/order_validator.dart';

/// Localized, field-specific validation messages (VAL-03).
abstract final class ValidationMessages {
  static String of(
    ValidationRule rule,
    AppLocalizations l10n,
    Instrument instrument,
  ) {
    return switch (rule) {
      ValidationRule.required => l10n.validationRequired,
      ValidationRule.invalidCharacters => l10n.validationInvalidCharacters,
      ValidationRule.tooLong => l10n.validationTooLong,
      ValidationRule.tooPrecise => l10n.validationTooPrecise,
      ValidationRule.notPositive => l10n.validationNotPositive,
      ValidationRule.notMultipleOfLot => l10n.validationNotMultipleOfLot(
        instrument.lotSize.toString(),
      ),
      ValidationRule.notMultipleOfTick => l10n.validationNotMultipleOfTick(
        instrument.tickSize.toString(),
      ),
      ValidationRule.notTradable => l10n.errorTradingHalted,
    };
  }
}
