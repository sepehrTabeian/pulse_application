import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/trading/domain/services/max_order_quantity.dart';

Decimal _d(String s) => Decimal.parse(s);

void main() {
  group('forBuy', () {
    test('rounds down to whole lots the cash can pay for', () {
      final max = MaxOrderQuantity.forBuy(
        cash: _d('1000'),
        price: _d('101.00'),
        lotSize: _d('1'),
      );

      expect(max, _d('9'));
    });

    test('works with fractional lots (crypto)', () {
      final max = MaxOrderQuantity.forBuy(
        cash: _d('1000'),
        price: _d('30000'),
        lotSize: _d('0.0001'),
      );

      expect(max, _d('0.0333'));
    });

    test('is zero when one lot is too expensive or cash is empty', () {
      expect(
        MaxOrderQuantity.forBuy(
          cash: _d('50'),
          price: _d('101'),
          lotSize: _d('1'),
        ),
        Decimal.zero,
      );
      expect(
        MaxOrderQuantity.forBuy(
          cash: Decimal.zero,
          price: _d('101'),
          lotSize: _d('1'),
        ),
        Decimal.zero,
      );
    });

    test('is null without a usable price', () {
      expect(
        MaxOrderQuantity.forBuy(
          cash: _d('1000'),
          price: null,
          lotSize: _d('1'),
        ),
        isNull,
      );
      expect(
        MaxOrderQuantity.forBuy(
          cash: _d('1000'),
          price: Decimal.zero,
          lotSize: _d('1'),
        ),
        isNull,
      );
    });
  });

  group('forSell', () {
    test('is what is held, rounded down to a lot', () {
      expect(
        MaxOrderQuantity.forSell(held: _d('10'), lotSize: _d('1')),
        _d('10'),
      );
      expect(
        MaxOrderQuantity.forSell(held: _d('0.05009'), lotSize: _d('0.0001')),
        _d('0.0500'),
      );
    });

    test('is zero when nothing is held', () {
      expect(
        MaxOrderQuantity.forSell(held: Decimal.zero, lotSize: _d('1')),
        Decimal.zero,
      );
    });
  });
}
