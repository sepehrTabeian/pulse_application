import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/domain/services/portfolio_valuation.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';

import '../../support/fakes.dart';

Decimal _d(String s) => Decimal.parse(s);

Account _account(List<Position> positions, {String cash = '1000'}) =>
    Account(currency: 'USD', cash: _d(cash), positions: positions);

Position _pos(String symbol, String qty) =>
    Position(symbol: symbol, quantity: _d(qty));

PriceQuote _q(String symbol, {String last = '100', String? bid = '99'}) =>
    PriceQuote(
      symbol: symbol,
      last: _d(last),
      seq: 1,
      bid: bid == null ? null : _d(bid),
    );

void main() {
  test('values positions by last and by bid (ADR-0008)', () {
    final v = PortfolioValuation.compute(
      account: _account([_pos('A', '10')]),
      quotes: {'A': _q('A')},
      instruments: const {},
    );

    expect(v.marketValueLast, _d('1000'));
    expect(v.sellNowValue, _d('990'));
    expect(v.totalAtLast, _d('2000'));
    expect(v.totalSellNow, _d('1990'));
    expect(v.hasApproximation, isFalse);
  });

  test('no positions means only cash', () {
    final v = PortfolioValuation.compute(
      account: _account([]),
      quotes: const {},
      instruments: const {},
    );

    expect(v.totalAtLast, _d('1000'));
    expect(v.positions, isEmpty);
    expect(v.hasMissingPrice, isFalse);
  });

  test('missing bid falls back to last and is flagged approximate', () {
    final v = PortfolioValuation.compute(
      account: _account([_pos('A', '2')]),
      quotes: {'A': _q('A', bid: null)},
      instruments: const {},
    );

    expect(v.sellNowValue, _d('200'));
    expect(v.hasApproximation, isTrue);
  });

  test('halted position (no quote) uses prevClose and is flagged', () {
    final v = PortfolioValuation.compute(
      account: _account([_pos('HALT', '5')]),
      quotes: const {},
      instruments: {
        'HALT': testInstrument(
          symbol: 'HALT',
          tradable: false,
          prevClose: '40',
        ),
      },
    );

    expect(v.marketValueLast, _d('200'));
    expect(v.positions.single.isApproximate, isTrue);
    expect(v.positions.single.hasPrice, isTrue);
  });

  test('a position with no price at all counts as zero and is flagged', () {
    final v = PortfolioValuation.compute(
      account: _account([_pos('X', '5')]),
      quotes: const {},
      instruments: const {},
    );

    expect(v.marketValueLast, Decimal.zero);
    expect(v.hasMissingPrice, isTrue);
  });

  test('fractional crypto quantities are exact (no float drift)', () {
    final v = PortfolioValuation.compute(
      account: _account([_pos('BTC', '0.0005')], cash: '0'),
      quotes: {'BTC': _q('BTC', last: '67250.10', bid: '67250.00')},
      instruments: const {},
    );

    expect(v.marketValueLast, _d('33.625050'));
    expect(v.sellNowValue, _d('33.625000'));
  });

  test('sums several positions', () {
    final v = PortfolioValuation.compute(
      account: _account([_pos('A', '1'), _pos('B', '2')]),
      quotes: {
        'A': _q('A'),
        'B': _q('B', last: '10', bid: '9'),
      },
      instruments: const {},
    );

    expect(v.marketValueLast, _d('120'));
    expect(v.sellNowValue, _d('117'));
  });

  test('zero quantity position contributes nothing', () {
    final v = PortfolioValuation.compute(
      account: _account([_pos('A', '0')]),
      quotes: {'A': _q('A')},
      instruments: const {},
    );

    expect(v.marketValueLast, Decimal.zero);
  });
}
