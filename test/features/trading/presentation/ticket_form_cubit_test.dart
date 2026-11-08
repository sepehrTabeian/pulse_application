import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/services/order_cost_estimator.dart';
import 'package:pulse/features/trading/domain/services/order_validator.dart';
import 'package:pulse/features/trading/presentation/cubit/ticket_form_cubit.dart';

import '../../../support/fakes.dart';

PriceQuote _quote() => PriceQuote(
  symbol: 'AAPL',
  last: Decimal.fromInt(100),
  seq: 1,
  bid: Decimal.fromInt(99),
  ask: Decimal.fromInt(101),
);

TicketFormCubit _cubit({bool tradable = true, String lot = '1'}) =>
    TicketFormCubit(
      instrument: testInstrument(tradable: tradable, lot: lot),
    );

void main() {
  test('starts empty, not submittable, no visible errors', () {
    final s = _cubit().state;

    expect(s.canSubmit, isFalse);
    expect(s.visibleError(OrderField.quantity), isNull);
    expect(s.side, OrderSide.buy);
    expect(s.type, OrderType.market);
  });

  test('errors appear only after the field was touched', () {
    final c = _cubit()..setQuantity('0');

    expect(
      c.state.visibleError(OrderField.quantity),
      ValidationRule.notPositive,
    );
    expect(c.state.visibleError(OrderField.limitPrice), isNull);
  });

  test('submit attempt reveals every error', () {
    final c = _cubit()..markSubmitAttempted();

    expect(c.state.visibleError(OrderField.quantity), ValidationRule.required);
  });

  test('a valid quantity makes the ticket submittable', () {
    final c = _cubit()
      ..updateMarket(_quote(), FeedStatus.live)
      ..setQuantity('10');

    expect(c.state.canSubmit, isTrue);
    expect(c.state.valid!.quantity, Decimal.fromInt(10));
  });

  test('estimate follows side and live quote', () {
    final c = _cubit()
      ..updateMarket(_quote(), FeedStatus.live)
      ..setQuantity('10');

    expect(c.state.estimate!.amount, Decimal.fromInt(1010));
    expect(c.state.estimate!.basis, CostBasis.ask);

    c.setSide(OrderSide.sell);

    expect(c.state.estimate!.amount, Decimal.fromInt(990));
    expect(c.state.estimate!.basis, CostBasis.bid);
  });

  test('estimate recomputes when the quote ticks', () {
    final c = _cubit()
      ..updateMarket(_quote(), FeedStatus.live)
      ..setQuantity('10');

    c.updateMarket(
      PriceQuote(
        symbol: 'AAPL',
        last: Decimal.fromInt(200),
        seq: 2,
        bid: Decimal.fromInt(199),
        ask: Decimal.fromInt(201),
      ),
      FeedStatus.live,
    );

    expect(c.state.estimate!.amount, Decimal.fromInt(2010));
  });

  test('no estimate without a price or without a valid quantity', () {
    final c = _cubit()..setQuantity('10');
    expect(c.state.estimate, isNull);

    c.updateMarket(_quote(), FeedStatus.live);
    c.setQuantity('abc');
    expect(c.state.estimate, isNull);
  });

  test('LIMIT needs a price; switching back to MARKET ignores it', () {
    final c = _cubit()
      ..updateMarket(_quote(), FeedStatus.live)
      ..setQuantity('10')
      ..setType(OrderType.limit);

    expect(c.state.canSubmit, isFalse);
    expect(c.state.errors[OrderField.limitPrice], ValidationRule.required);

    c.setLimitPrice('95.5');
    expect(c.state.canSubmit, isTrue);
    expect(c.state.estimate!.basis, CostBasis.limit);

    c
      ..setLimitPrice('garbage')
      ..setType(OrderType.market);
    expect(c.state.canSubmit, isTrue);
  });

  test('off-tick limit price is flagged', () {
    final c = _cubit()
      ..setQuantity('1')
      ..setType(OrderType.limit)
      ..setLimitPrice('1.005');

    expect(
      c.state.visibleError(OrderField.limitPrice),
      ValidationRule.notMultipleOfTick,
    );
  });

  test('persian digits work end to end', () {
    final c = _cubit()
      ..updateMarket(_quote(), FeedStatus.live)
      ..setQuantity('۱۰');

    expect(c.state.valid!.quantity, Decimal.fromInt(10));
  });

  test('an offline feed blocks submission even when input is valid', () {
    final c = _cubit()
      ..setQuantity('10')
      ..updateMarket(_quote(), FeedStatus.offline);

    expect(c.state.valid, isNotNull);
    expect(c.state.canSubmit, isFalse);
    expect(c.state.isFeedOffline, isTrue);
  });

  test('a stale feed only warns (still submittable)', () {
    final c = _cubit()
      ..setQuantity('10')
      ..updateMarket(_quote(), FeedStatus.stale);

    expect(c.state.isStale, isTrue);
    expect(c.state.canSubmit, isTrue);
  });

  test('a halted instrument can never be submitted', () {
    final c = _cubit(tradable: false)
      ..updateMarket(null, FeedStatus.live)
      ..setQuantity('10');

    expect(c.state.canSubmit, isFalse);
    expect(c.state.errors[OrderField.instrument], ValidationRule.notTradable);
    expect(
      c.state.visibleError(OrderField.instrument),
      ValidationRule.notTradable,
    );
  });

  test('fractional lot sizes work for crypto', () {
    final c = _cubit(lot: '0.0001')..setQuantity('0.0005');

    expect(c.state.valid!.quantity, Decimal.parse('0.0005'));
  });

  test('state equality allows blocs to skip identical emissions', () {
    final c = _cubit();
    final before = c.state;

    c.updateMarket(null, FeedStatus.connecting);

    expect(c.state, before);
  });
}
