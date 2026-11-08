import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/portfolio/data/models/account_model.dart';

AccountModel _model(String json) =>
    AccountModel.fromJson(JsonReader.parse(json));

void main() {
  test('maps cash and positions', () {
    final a = _model(
      '{"currency":"USD","cash":"25000.00","positions":['
      '{"symbol":"AAPL","quantity":"10","averageCost":"200.5"},'
      '{"symbol":"BTC-USD","quantity":"0.0005","averageCost":"60000"}]}',
    ).toEntity();

    expect(a.currency, 'USD');
    expect(a.cash, Decimal.parse('25000.00'));
    expect(a.positions, hasLength(2));
    expect(a.positions.last.quantity, Decimal.parse('0.0005'));
  });

  test('missing positions means no positions', () {
    final a = _model('{"cash":"10"}').toEntity();

    expect(a.positions, isEmpty);
    expect(a.currency, 'USD');
  });

  test('missing or invalid cash throws (never shown as zero)', () {
    for (final json in ['{}', '{"cash":null}', '{"cash":"abc"}']) {
      expect(
        () => _model(json).toEntity(),
        throwsA(isA<ParsingException>()),
        reason: json,
      );
    }
  });

  test('invalid positions are skipped and reported', () {
    final skipped = <ParsingException>[];

    final a = _model(
      '{"cash":"1","positions":['
      '{"symbol":"AAPL","quantity":"10"},'
      '{"symbol":null,"quantity":"1"},'
      '{"symbol":"X","quantity":"oops"},'
      '7]}',
    ).toEntity(onSkipped: skipped.add);

    expect(a.positions.map((p) => p.symbol), ['AAPL']);
    expect(skipped, hasLength(2));
  });

  test('optional averageCost may be missing', () {
    final a = _model(
      '{"cash":"1","positions":[{"symbol":"A","quantity":"1"}]}',
    ).toEntity();

    expect(a.positions.single.averageCost, isNull);
  });
}
