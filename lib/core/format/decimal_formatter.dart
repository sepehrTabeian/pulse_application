import 'package:decimal/decimal.dart';

/// Latin-digit formatting for money/price/quantity (ADR-0009). Never goes
/// through `double`. Grouping uses ',' and the decimal point is '.'.
abstract final class DecimalFormatter {
  static const String _minus = '-';

  static String format(Decimal value, {int fractionDigits = 2}) {
    final fixed = value.toStringAsFixed(fractionDigits);
    final negative = fixed.startsWith(_minus);
    final unsigned = negative ? fixed.substring(1) : fixed;
    final parts = unsigned.split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final body = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
    return negative && !_isAllZero(body) ? '$_minus$body' : body;
  }

  /// Explicit sign for changes: "+1.50", "-1.50", "0.00".
  static String formatSigned(Decimal value, {int fractionDigits = 2}) {
    final text = format(value, fractionDigits: fractionDigits);
    if (value.sign > 0 && !_isAllZero(text)) return '+$text';
    return text;
  }

  static String formatPercent(Decimal value, {int fractionDigits = 2}) {
    return '${formatSigned(value, fractionDigits: fractionDigits)}%';
  }

  static bool _isAllZero(String text) => !RegExp('[1-9]').hasMatch(text);
}
