import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/format/decimal_formatter.dart';
import 'package:pulse/core/format/number_input.dart';
import 'package:pulse/features/prices/domain/entities/price_change.dart';

Decimal _d(String s) => Decimal.parse(s);

void main() {
  group('NumberInput.parse', () {
    test('parses Latin, Persian and Arabic-Indic digits identically', () {
      expect(NumberInput.parse('123.5').value, _d('123.5'));
      expect(NumberInput.parse('۱۲۳٫۵').value, _d('123.5'));
      expect(NumberInput.parse('١٢٣.٥').value, _d('123.5'));
      expect(NumberInput.parse('۱۲۳.۵').value, _d('123.5'));
    });

    test('accepts a leading dot and surrounding spaces', () {
      expect(NumberInput.parse(' .5 ').value, _d('0.5'));
      expect(NumberInput.parse('٫۵').value, _d('0.5'));
    });

    test('ignores invisible bidi/zero-width marks', () {
      expect(NumberInput.parse('‏12‌.5‎').value, _d('12.5'));
    });

    test('rejects empty input', () {
      expect(NumberInput.parse('').issue, NumberInputIssue.empty);
      expect(NumberInput.parse('   ').issue, NumberInputIssue.empty);
    });

    test('rejects commas because they are ambiguous for money', () {
      expect(
        NumberInput.parse('1,5').issue,
        NumberInputIssue.invalidCharacters,
      );
      expect(
        NumberInput.parse('1٬000').issue,
        NumberInputIssue.invalidCharacters,
      );
    });

    test('rejects signs, exponents, letters and malformed numbers', () {
      for (final bad in [
        '-5',
        '+5',
        '1e5',
        'abc',
        '1.2.3',
        '1.',
        '..',
        '1 2',
      ]) {
        expect(
          NumberInput.parse(bad).issue,
          NumberInputIssue.invalidCharacters,
          reason: bad,
        );
      }
    });

    test('rejects too long and too precise input', () {
      expect(NumberInput.parse('1' * 21).issue, NumberInputIssue.tooLong);
      expect(
        NumberInput.parse('0.123456789').issue,
        NumberInputIssue.tooPrecise,
      );
      expect(NumberInput.parse('0.12345678').value, _d('0.12345678'));
    });

    test('keeps zero as a value (positivity is a business rule)', () {
      expect(NumberInput.parse('0').value, Decimal.zero);
    });
  });

  group('DecimalFormatter', () {
    test('groups thousands and pads fraction digits', () {
      expect(DecimalFormatter.format(_d('1234567.5')), '1,234,567.50');
      expect(DecimalFormatter.format(_d('999')), '999.00');
    });

    test('uses Latin digits and keeps tiny values exact', () {
      expect(
        DecimalFormatter.format(_d('0.0005'), fractionDigits: 4),
        '0.0005',
      );
      expect(DecimalFormatter.format(_d('67250'), fractionDigits: 0), '67,250');
    });

    test('rounds half up at the requested scale', () {
      expect(DecimalFormatter.format(_d('0.005')), '0.01');
      expect(DecimalFormatter.format(_d('2.004')), '2.00');
    });

    test('handles negatives and never prints negative zero', () {
      expect(DecimalFormatter.format(_d('-1234.5')), '-1,234.50');
      expect(DecimalFormatter.format(_d('-0.001')), '0.00');
    });

    test('signed and percent formats', () {
      expect(DecimalFormatter.formatSigned(_d('1.5')), '+1.50');
      expect(DecimalFormatter.formatSigned(_d('-1.5')), '-1.50');
      expect(DecimalFormatter.formatSigned(Decimal.zero), '0.00');
      expect(DecimalFormatter.formatPercent(_d('0.456')), '+0.46%');
    });
  });

  group('PriceChange.compute', () {
    test('up, down and flat', () {
      final up = PriceChange.compute(last: _d('110'), prevClose: _d('100'))!;
      final down = PriceChange.compute(last: _d('90'), prevClose: _d('100'))!;
      final flat = PriceChange.compute(last: _d('100'), prevClose: _d('100'))!;

      expect(up.direction, PriceDirection.up);
      expect(up.absolute, _d('10'));
      expect(up.percent, _d('10'));
      expect(down.direction, PriceDirection.down);
      expect(down.percent, _d('-10'));
      expect(flat.direction, PriceDirection.flat);
    });

    test('is null without a usable previous close', () {
      expect(PriceChange.compute(last: _d('1'), prevClose: null), isNull);
      expect(
        PriceChange.compute(last: _d('1'), prevClose: Decimal.zero),
        isNull,
      );
      expect(PriceChange.compute(last: _d('1'), prevClose: _d('-5')), isNull);
    });

    test('non-terminating percentages are bounded, not infinite', () {
      final c = PriceChange.compute(last: _d('101'), prevClose: _d('3'))!;

      expect(c.percent.scale, lessThanOrEqualTo(6));
    });
  });
}
