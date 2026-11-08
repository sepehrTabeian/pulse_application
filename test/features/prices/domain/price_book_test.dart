import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/prices/domain/entities/price_book.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';

PriceQuote _q(String symbol, int seq, [String last = '1']) =>
    PriceQuote(symbol: symbol, last: Decimal.parse(last), seq: seq);

void main() {
  test('a newer tick replaces the stored quote', () {
    final book = PriceBook.empty
        .apply(PriceTick(_q('A', 1)))
        .apply(PriceTick(_q('A', 2, '5')));

    expect(book.quotes['A']!.last, Decimal.parse('5'));
  });

  test(
    'duplicate and older ticks are ignored and return the same instance',
    () {
      final book = PriceBook.empty.apply(PriceTick(_q('A', 5, '9')));

      expect(book.apply(PriceTick(_q('A', 5, '1'))), same(book));
      expect(book.apply(PriceTick(_q('A', 4, '1'))), same(book));
      expect(book.quotes['A']!.last, Decimal.parse('9'));
    },
  );

  test('symbols are independent', () {
    final book = PriceBook.empty
        .apply(PriceTick(_q('A', 10)))
        .apply(PriceTick(_q('B', 1)));

    expect(book.quotes.keys, containsAll(['A', 'B']));
  });

  test('a snapshot replaces entries even with a lower seq (reconnect)', () {
    final book = PriceBook.empty
        .apply(PriceTick(_q('A', 100, '9')))
        .apply(PriceSnapshot([_q('A', 3, '7')]));

    expect(book.quotes['A']!.seq, 3);
    expect(book.quotes['A']!.last, Decimal.parse('7'));
  });

  test('empty snapshot, heartbeat and symbol error change nothing', () {
    final book = PriceBook.empty.apply(PriceTick(_q('A', 1)));

    expect(book.apply(const PriceSnapshot([])), same(book));
    expect(book.apply(const PriceHeartbeat()), same(book));
    expect(
      book.apply(const PriceSymbolError(code: 'UNKNOWN_SYMBOL', symbol: 'Z')),
      same(book),
    );
  });

  test(
    'retain drops unsubscribed symbols and keeps instance when unchanged',
    () {
      final book = PriceBook.empty
          .apply(PriceTick(_q('A', 1)))
          .apply(PriceTick(_q('B', 1)));

      expect(book.retain({'A', 'B', 'C'}), same(book));
      expect(book.retain({'A'}).quotes.keys, ['A']);
      expect(book.retain(<String>{}).quotes, isEmpty);
    },
  );

  test('stored quotes cannot be mutated from outside', () {
    final book = PriceBook.empty.apply(PriceTick(_q('A', 1)));

    expect(() => book.quotes['X'] = _q('X', 1), throwsUnsupportedError);
  });
}
