import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/prices/data/models/price_message_parser.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';

PriceMessage? _parse(String raw) => PriceMessageParser.tryParse(raw);

const _tick =
    '{"type":"tick","symbol":"AAPL","bid":"228.50","ask":"228.54",'
    '"last":"228.52","seq":42,"ts":"2026-11-02T13:00:00.000Z"}';

void main() {
  test('parses a tick', () {
    final m = _parse(_tick);

    expect(m, isA<PriceTick>());
    final q = (m! as PriceTick).quote;
    expect(q.symbol, 'AAPL');
    expect(q.last, Decimal.parse('228.52'));
    expect(q.bid, Decimal.parse('228.50'));
    expect(q.ask, Decimal.parse('228.54'));
    expect(q.seq, 42);
    expect(q.timestamp, DateTime.utc(2026, 11, 2, 13));
  });

  test('parses a snapshot and drops its invalid items', () {
    final m = _parse(
      '{"type":"snapshot","prices":['
      '{"symbol":"AAPL","bid":"1","ask":"2","last":"1.5","seq":1},'
      '{"symbol":null,"last":"1","seq":1},'
      '{"symbol":"MSFT","last":"-","seq":1},'
      '5]}',
    );

    final quotes = (m! as PriceSnapshot).quotes;
    expect(quotes.map((q) => q.symbol), ['AAPL']);
  });

  test('snapshot without a prices list is dropped', () {
    expect(_parse('{"type":"snapshot"}'), isNull);
    expect(_parse('{"type":"snapshot","prices":"x"}'), isNull);
  });

  test('parses a heartbeat even without ts', () {
    expect(_parse('{"type":"heartbeat"}'), isA<PriceHeartbeat>());
    final m = _parse('{"type":"heartbeat","ts":"2026-11-02T13:00:00Z"}');
    expect((m! as PriceHeartbeat).timestamp, DateTime.utc(2026, 11, 2, 13));
  });

  test('parses a per-symbol error message', () {
    final m = _parse('{"type":"error","code":"UNKNOWN_SYMBOL","symbol":"XYZ"}');

    expect(m, const PriceSymbolError(code: 'UNKNOWN_SYMBOL', symbol: 'XYZ'));
  });

  test('error message without code still parses with a fallback code', () {
    final m = _parse('{"type":"error"}');

    expect((m! as PriceSymbolError).code, isNotEmpty);
  });

  test('simulator malformed samples are dropped, never thrown', () {
    for (final raw in [
      '{"type":"tick","symbol":null,"bid":"1.00","ask":"1.01","last":"1.00",'
          '"seq":1}',
      '{"type":"tick","symbol":"MSFT","bid":"NaN","ask":"","last":"-",'
          '"seq":"x"}',
      'not json at all',
      '',
      '[]',
      'null',
      '{"type":"tick"}',
    ]) {
      expect(_parse(raw), isNull, reason: raw);
    }
  });

  test('unknown message types are ignored (forward compatible)', () {
    expect(_parse('{"type":"future_thing","x":1}'), isNull);
    expect(_parse('{"type":null}'), isNull);
    expect(_parse('{"nope":1}'), isNull);
  });

  test('seq may arrive as numeric string or integral double', () {
    final a = _parse(_tick.replaceAll('"seq":42', '"seq":"42"'));
    final b = _parse(_tick.replaceAll('"seq":42', '"seq":42.0'));

    expect((a! as PriceTick).quote.seq, 42);
    expect((b! as PriceTick).quote.seq, 42);
  });

  test('negative seq, non-positive or missing last are rejected', () {
    expect(_parse(_tick.replaceAll('"seq":42', '"seq":-1')), isNull);
    expect(_parse(_tick.replaceAll('"last":"228.52"', '"last":"0"')), isNull);
    expect(_parse(_tick.replaceAll('"last":"228.52",', '')), isNull);
  });

  test('unusable bid/ask become null but the tick survives', () {
    final m = _parse(
      _tick
          .replaceAll('"bid":"228.50"', '"bid":"NaN"')
          .replaceAll('"ask":"228.54"', '"ask":"-1"'),
    );

    final q = (m! as PriceTick).quote;
    expect(q.bid, isNull);
    expect(q.ask, isNull);
    expect(q.last, Decimal.parse('228.52'));
  });

  test('extra unknown fields are ignored', () {
    expect(_parse(_tick.replaceAll('{', '{"extra":[1,2],')), isA<PriceTick>());
  });
}
