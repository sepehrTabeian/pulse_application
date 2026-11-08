import 'package:decimal/decimal.dart';

enum NumberInputIssue { empty, invalidCharacters, tooLong, tooPrecise }

class NumberParseResult {
  const NumberParseResult.value(Decimal this.value) : issue = null;
  const NumberParseResult.issue(NumberInputIssue this.issue) : value = null;

  final Decimal? value;
  final NumberInputIssue? issue;
}

/// Turns user text into a [Decimal] safely (VAL-02, Q11). Latin output only.
///
/// Accepts Persian/Arabic-Indic digits and the Arabic decimal separator.
/// A comma is REJECTED: "1,5" could mean 15 or 1.5 and money must not guess.
abstract final class NumberInput {
  static const int maxLength = 20;
  static const int maxScale = 8;

  static final RegExp _shape = RegExp(r'^(\d+(\.\d+)?|\.\d+)$');
  static const Set<int> _invisibleUnits = {
    0x200c, 0x200d, 0x200e, 0x200f, // zero-width and bidi marks
    0x202a, 0x202b, 0x202c, 0x202d, 0x202e,
    0x2066, 0x2067, 0x2068, 0x2069,
  };

  /// Maps non-Latin digits to Latin and the Arabic separator to '.'.
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final unit in raw.trim().runes) {
      if (_invisibleUnits.contains(unit)) continue;
      if (unit >= 0x06F0 && unit <= 0x06F9) {
        buffer.writeCharCode(unit - 0x06F0 + 0x30);
      } else if (unit >= 0x0660 && unit <= 0x0669) {
        buffer.writeCharCode(unit - 0x0660 + 0x30);
      } else if (unit == 0x066B) {
        buffer.write('.');
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  static NumberParseResult parse(String raw) {
    final text = normalize(raw);
    if (text.isEmpty) {
      return const NumberParseResult.issue(NumberInputIssue.empty);
    }
    if (text.length > maxLength) {
      return const NumberParseResult.issue(NumberInputIssue.tooLong);
    }
    if (!_shape.hasMatch(text)) {
      return const NumberParseResult.issue(NumberInputIssue.invalidCharacters);
    }
    final value = Decimal.tryParse(text.startsWith('.') ? '0$text' : text);
    if (value == null) {
      return const NumberParseResult.issue(NumberInputIssue.invalidCharacters);
    }
    if (value.scale > maxScale) {
      return const NumberParseResult.issue(NumberInputIssue.tooPrecise);
    }
    return NumberParseResult.value(value);
  }
}
