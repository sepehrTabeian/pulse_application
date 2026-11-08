import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/instruments/data/models/instrument_model.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';

InstrumentModel _model(String json) =>
    InstrumentModel.fromJson(JsonReader.parse(json));

const _full =
    '{"symbol":"BTC-USD","name":"Bitcoin","type":"CRYPTO","exchange":"CRYPTO",'
    '"currency":"USD","tickSize":"0.01","lotSize":"0.0001",'
    '"prevClose":"67250.00","tradable":true}';

void main() {
  test('derives the unit from the type and maps EQUITY to stock', () {
    final crypto = _model(_full).toEntity();
    final equity = _model(
      '{"symbol":"AAPL","type":"EQUITY","tickSize":"0.01","lotSize":"1"}',
    ).toEntity();

    expect(crypto.unit, 'BTC');
    expect(equity.unit, 'share');
    expect(equity.type, InstrumentType.stock);
  });

  test('maps a complete payload to an entity', () {
    final e = _model(_full).toEntity();

    expect(e.symbol, 'BTC-USD');
    expect(e.name, 'Bitcoin');
    expect(e.type, InstrumentType.crypto);
    expect(e.tickSize, Decimal.parse('0.01'));
    expect(e.lotSize, Decimal.parse('0.0001'));
    expect(e.prevClose, Decimal.parse('67250.00'));
    expect(e.tradable, isTrue);
  });

  test('halted instrument keeps tradable=false', () {
    final e = _model(_full.replaceAll('true', 'false')).toEntity();

    expect(e.tradable, isFalse);
  });

  test('missing optional fields get safe defaults', () {
    final e = _model(
      '{"symbol":"X","tickSize":"0.01","lotSize":"1"}',
    ).toEntity();

    expect(e.name, 'X');
    expect(e.currency, 'USD');
    expect(e.exchange, '');
    expect(e.type, InstrumentType.other);
    expect(e.prevClose, isNull);
  });

  test('missing tradable defaults to NOT tradable (safe side)', () {
    final e = _model(
      '{"symbol":"X","tickSize":"0.01","lotSize":"1"}',
    ).toEntity();

    expect(e.tradable, isFalse);
  });

  test('unknown instrument type maps to other', () {
    final e = _model(_full.replaceAll('CRYPTO', 'WARRANT')).toEntity();

    expect(e.type, InstrumentType.other);
  });

  test('accepts numbers and string booleans (type drift)', () {
    final e = _model(
      '{"symbol":"X","tickSize":0.01,"lotSize":1,"prevClose":10,'
      '"tradable":"true"}',
    ).toEntity();

    expect(e.tickSize, Decimal.parse('0.01'));
    expect(e.prevClose, Decimal.fromInt(10));
    expect(e.tradable, isTrue);
  });

  test('null and wrong-typed fields never throw while parsing the model', () {
    expect(
      () => _model('{"symbol":null,"tickSize":[],"lotSize":{},"name":5}'),
      returnsNormally,
    );
  });

  test('required fields missing or invalid fail in toEntity', () {
    for (final json in [
      '{"tickSize":"0.01","lotSize":"1"}',
      '{"symbol":"  ","tickSize":"0.01","lotSize":"1"}',
      '{"symbol":"X","lotSize":"1"}',
      '{"symbol":"X","tickSize":"0.01"}',
      '{"symbol":"X","tickSize":"abc","lotSize":"1"}',
    ]) {
      expect(
        () => _model(json).toEntity(),
        throwsA(isA<ParsingException>()),
        reason: json,
      );
    }
  });

  test('zero or negative tick/lot size is rejected (would divide by zero)', () {
    for (final json in [
      '{"symbol":"X","tickSize":"0","lotSize":"1"}',
      '{"symbol":"X","tickSize":"0.01","lotSize":"0"}',
      '{"symbol":"X","tickSize":"-0.01","lotSize":"1"}',
    ]) {
      expect(
        () => _model(json).toEntity(),
        throwsA(isA<ParsingException>()),
        reason: json,
      );
    }
  });

  test('non-positive prevClose becomes null instead of failing', () {
    final e = _model(
      '{"symbol":"X","tickSize":"0.01","lotSize":"1","prevClose":"-5"}',
    ).toEntity();

    expect(e.prevClose, isNull);
  });
}
