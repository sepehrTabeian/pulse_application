import 'package:decimal/decimal.dart';
import 'package:pulse/core/format/number_input.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';

enum OrderField { quantity, limitPrice, instrument }

enum ValidationRule {
  required,
  invalidCharacters,
  tooLong,
  tooPrecise,
  notPositive,
  notMultipleOfLot,
  notMultipleOfTick,
  notTradable,
}

sealed class OrderValidation {
  const OrderValidation();
}

/// Input that satisfies every rule; safe to build an [OrderRequest] from.
class ValidOrder extends OrderValidation {
  const ValidOrder({required this.quantity, this.limitPrice});

  final Decimal quantity;
  final Decimal? limitPrice;
}

class InvalidOrder extends OrderValidation {
  const InvalidOrder(this.errors);

  final Map<OrderField, ValidationRule> errors;
}

/// Pure, exact (Decimal) validation against the instrument's rules (VAL-01,
/// ORD-09). Nothing is sent to the server unless the result is [ValidOrder].
class OrderValidator {
  const OrderValidator();

  OrderValidation validate({
    required Instrument instrument,
    required OrderType type,
    required String quantityText,
    required String limitPriceText,
  }) {
    final errors = <OrderField, ValidationRule>{};

    if (!instrument.tradable) {
      errors[OrderField.instrument] = ValidationRule.notTradable;
    }

    final quantity = _positiveMultiple(
      quantityText,
      step: instrument.lotSize,
      notMultiple: ValidationRule.notMultipleOfLot,
      onError: (rule) => errors[OrderField.quantity] = rule,
    );

    Decimal? limitPrice;
    if (type == OrderType.limit) {
      limitPrice = _positiveMultiple(
        limitPriceText,
        step: instrument.tickSize,
        notMultiple: ValidationRule.notMultipleOfTick,
        onError: (rule) => errors[OrderField.limitPrice] = rule,
      );
    }

    if (errors.isNotEmpty || quantity == null) return InvalidOrder(errors);
    return ValidOrder(quantity: quantity, limitPrice: limitPrice);
  }

  Decimal? _positiveMultiple(
    String text, {
    required Decimal step,
    required ValidationRule notMultiple,
    required void Function(ValidationRule rule) onError,
  }) {
    final parsed = NumberInput.parse(text);
    final issue = parsed.issue;
    if (issue != null) {
      onError(_ruleFor(issue));
      return null;
    }
    final value = parsed.value!;
    if (value <= Decimal.zero) {
      onError(ValidationRule.notPositive);
      return null;
    }
    if (value % step != Decimal.zero) {
      onError(notMultiple);
      return null;
    }
    return value;
  }

  ValidationRule _ruleFor(NumberInputIssue issue) {
    return switch (issue) {
      NumberInputIssue.empty => ValidationRule.required,
      NumberInputIssue.invalidCharacters => ValidationRule.invalidCharacters,
      NumberInputIssue.tooLong => ValidationRule.tooLong,
      NumberInputIssue.tooPrecise => ValidationRule.tooPrecise,
    };
  }
}
