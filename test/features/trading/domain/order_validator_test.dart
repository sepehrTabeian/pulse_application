import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/services/order_validator.dart';

import '../../../support/fakes.dart';

OrderValidation _v({
  String qty = '10',
  String price = '',
  OrderType type = OrderType.market,
  String tick = '0.01',
  String lot = '1',
  bool tradable = true,
}) => const OrderValidator().validate(
  instrument: testInstrument(tick: tick, lot: lot, tradable: tradable),
  type: type,
  quantityText: qty,
  limitPriceText: price,
);

Map<OrderField, ValidationRule> _errors(OrderValidation v) =>
    (v as InvalidOrder).errors;

void main() {
  test('valid market order', () {
    final v = _v();

    expect(v, isA<ValidOrder>());
    expect((v as ValidOrder).quantity, Decimal.fromInt(10));
    expect(v.limitPrice, isNull);
  });

  test('valid limit order', () {
    final v = _v(type: OrderType.limit, price: '189.25') as ValidOrder;

    expect(v.limitPrice, Decimal.parse('189.25'));
  });

  test('market order ignores whatever is in the limit price field', () {
    expect(_v(price: 'garbage'), isA<ValidOrder>());
  });

  test('empty quantity is required', () {
    expect(_errors(_v(qty: ''))[OrderField.quantity], ValidationRule.required);
  });

  test('syntax problems map to specific rules', () {
    expect(
      _errors(_v(qty: '1,5'))[OrderField.quantity],
      ValidationRule.invalidCharacters,
    );
    expect(
      _errors(_v(qty: 'abc'))[OrderField.quantity],
      ValidationRule.invalidCharacters,
    );
    expect(
      _errors(_v(qty: '1' * 25))[OrderField.quantity],
      ValidationRule.tooLong,
    );
    expect(
      _errors(_v(qty: '0.123456789', lot: '0.00000001'))[OrderField.quantity],
      ValidationRule.tooPrecise,
    );
  });

  test('zero quantity is not positive', () {
    expect(
      _errors(_v(qty: '0'))[OrderField.quantity],
      ValidationRule.notPositive,
    );
    expect(
      _errors(_v(qty: '0.0'))[OrderField.quantity],
      ValidationRule.notPositive,
    );
  });

  test('quantity must be a multiple of the lot size', () {
    expect(
      _errors(_v(qty: '1.5'))[OrderField.quantity],
      ValidationRule.notMultipleOfLot,
    );
    expect(_v(qty: '0.0005', lot: '0.0001'), isA<ValidOrder>());
    expect(
      _errors(_v(qty: '0.00055', lot: '0.0001'))[OrderField.quantity],
      ValidationRule.notMultipleOfLot,
    );
  });

  test('decimal arithmetic is exact where doubles would fail (0.3 vs 0.1)', () {
    expect(_v(qty: '0.3', lot: '0.1'), isA<ValidOrder>());
    expect(_v(qty: '0.7', lot: '0.1'), isA<ValidOrder>());
  });

  test('persian digits are accepted', () {
    expect((_v(qty: '۱۰') as ValidOrder).quantity, Decimal.fromInt(10));
  });

  test('limit order needs a price', () {
    expect(
      _errors(_v(type: OrderType.limit))[OrderField.limitPrice],
      ValidationRule.required,
    );
  });

  test('limit price must be positive and on the tick grid', () {
    expect(
      _errors(_v(type: OrderType.limit, price: '0'))[OrderField.limitPrice],
      ValidationRule.notPositive,
    );
    expect(
      _errors(_v(type: OrderType.limit, price: '1.005'))[OrderField.limitPrice],
      ValidationRule.notMultipleOfTick,
    );
    expect(
      _v(type: OrderType.limit, price: '1.05', tick: '0.05'),
      isA<ValidOrder>(),
    );
    expect(
      _errors(
        _v(type: OrderType.limit, price: '1.07', tick: '0.05'),
      )[OrderField.limitPrice],
      ValidationRule.notMultipleOfTick,
    );
  });

  test('reports quantity and price errors together', () {
    final errors = _errors(_v(qty: '', type: OrderType.limit, price: ''));

    expect(
      errors.keys,
      containsAll([OrderField.quantity, OrderField.limitPrice]),
    );
  });

  test('a halted instrument is never valid, even with perfect input', () {
    final errors = _errors(_v(tradable: false));

    expect(errors[OrderField.instrument], ValidationRule.notTradable);
  });
}
