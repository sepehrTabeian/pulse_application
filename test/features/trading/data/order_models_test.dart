import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/trading/data/models/order_model.dart';
import 'package:pulse/features/trading/data/models/order_request_model.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';

OrderModel _model(String json) => OrderModel.fromJson(JsonReader.parse(json));

const _filled =
    '{"orderId":"ord_000001","clientOrderId":"c1","symbol":"AAPL",'
    '"side":"BUY","type":"MARKET","quantity":"10","status":"FILLED",'
    '"filledQuantity":"10","averagePrice":"228.52",'
    '"createdAt":"2026-11-02T13:00:00.000Z"}';

void main() {
  group('OrderModel', () {
    test('maps a filled order', () {
      final o = _model(_filled).toEntity();

      expect(o.orderId, 'ord_000001');
      expect(o.clientOrderId, 'c1');
      expect(o.side, OrderSide.buy);
      expect(o.type, OrderType.market);
      expect(o.status, OrderStatus.filled);
      expect(o.quantity, Decimal.fromInt(10));
      expect(o.filledQuantity, Decimal.fromInt(10));
      expect(o.averagePrice, Decimal.parse('228.52'));
      expect(o.createdAt, DateTime.utc(2026, 11, 2, 13));
    });

    test('maps a working limit order without fills', () {
      final o = _model(
        '{"orderId":"o2","clientOrderId":"c2","symbol":"AAPL","side":"SELL",'
        '"type":"LIMIT","quantity":"5","status":"WORKING"}',
      ).toEntity();

      expect(o.status, OrderStatus.working);
      expect(o.side, OrderSide.sell);
      expect(o.filledQuantity, Decimal.zero);
      expect(o.averagePrice, isNull);
    });

    test('unknown or missing status is OrderStatus.unknown, never guessed', () {
      for (final status in ['"BOGUS"', 'null', '5', '""']) {
        final o = _model(
          _filled.replaceAll('"status":"FILLED"', '"status":$status'),
        ).toEntity();

        expect(o.status, OrderStatus.unknown, reason: status);
      }
      final noStatus = _model(
        _filled.replaceAll('"status":"FILLED",', ''),
      ).toEntity();
      expect(noStatus.status, OrderStatus.unknown);
    });

    test('CANCELLED, REJECTED and PENDING are known statuses', () {
      for (final (raw, expected) in [
        ('CANCELLED', OrderStatus.cancelled),
        ('REJECTED', OrderStatus.rejected),
        ('PENDING', OrderStatus.pending),
      ]) {
        final o = _model(
          _filled.replaceAll('"status":"FILLED"', '"status":"$raw"'),
        ).toEntity();

        expect(o.status, expected);
      }
    });

    test('side/type are case-insensitive', () {
      final o = _model(
        _filled.replaceAll('"BUY"', '"buy"').replaceAll('"MARKET"', '"Market"'),
      ).toEntity();

      expect(o.side, OrderSide.buy);
      expect(o.type, OrderType.market);
    });

    test('unrecognised side or type throws (cannot be guessed)', () {
      expect(
        () => _model(_filled.replaceAll('"BUY"', '"HOLD"')).toEntity(),
        throwsA(isA<ParsingException>()),
      );
      expect(
        () => _model(_filled.replaceAll('"MARKET"', '"STOP"')).toEntity(),
        throwsA(isA<ParsingException>()),
      );
    });

    test('missing clientOrderId, symbol or quantity throws', () {
      for (final removal in [
        '"clientOrderId":"c1",',
        '"symbol":"AAPL",',
        '"quantity":"10",',
      ]) {
        expect(
          () => _model(_filled.replaceAll(removal, '')).toEntity(),
          throwsA(isA<ParsingException>()),
          reason: removal,
        );
      }
    });

    test('numbers instead of strings and null optionals are tolerated', () {
      final o = _model(
        '{"clientOrderId":"c","symbol":"A","side":"BUY","type":"MARKET",'
        '"quantity":10,"status":"FILLED","filledQuantity":null,'
        '"averagePrice":228.52,"orderId":null,"createdAt":"garbage"}',
      ).toEntity();

      expect(o.quantity, Decimal.fromInt(10));
      expect(o.filledQuantity, Decimal.zero);
      expect(o.averagePrice, Decimal.parse('228.52'));
      expect(o.orderId, '');
      expect(o.createdAt, isNull);
    });
  });

  group('OrderRequestModel', () {
    test('encodes a market order with decimal strings and no limitPrice', () {
      final json =
          jsonDecode(
                OrderRequestModel.fromEntity(
                  OrderRequest(
                    clientOrderId: 'c1',
                    symbol: 'AAPL',
                    side: OrderSide.buy,
                    type: OrderType.market,
                    quantity: Decimal.fromInt(10),
                  ),
                ).toJsonString(),
              )
              as Map<String, Object?>;

      expect(json, {
        'clientOrderId': 'c1',
        'symbol': 'AAPL',
        'side': 'BUY',
        'type': 'MARKET',
        'quantity': '10',
      });
    });

    test('encodes a limit order keeping fractional precision exactly', () {
      final json =
          jsonDecode(
                OrderRequestModel.fromEntity(
                  OrderRequest(
                    clientOrderId: 'c2',
                    symbol: 'BTC-USD',
                    side: OrderSide.sell,
                    type: OrderType.limit,
                    quantity: Decimal.parse('0.0005'),
                    limitPrice: Decimal.parse('67250.01'),
                  ),
                ).toJsonString(),
              )
              as Map<String, Object?>;

      expect(json['quantity'], '0.0005');
      expect(json['limitPrice'], '67250.01');
      expect(json['side'], 'SELL');
      expect(json['type'], 'LIMIT');
    });

    test('never uses scientific notation for tiny or huge values', () {
      final encoded = OrderRequestModel.fromEntity(
        OrderRequest(
          clientOrderId: 'c',
          symbol: 'X',
          side: OrderSide.buy,
          type: OrderType.market,
          quantity: Decimal.parse('0.00000001'),
        ),
      ).toJsonString();

      expect(encoded, isNot(contains('e-')));
      expect(encoded, contains('0.00000001'));
    });
  });
}
