import 'package:pulse/features/prices/domain/entities/price_message.dart';

/// Latest known quote per symbol. Immutable; [apply] returns the SAME
/// instance when nothing changed so callers can skip rebuilds.
///
/// The stream is at-least-once and unordered: a tick whose `seq` is not newer
/// than the stored one is dropped. A snapshot replaces entries (it resets the
/// baseline after a reconnect).
class PriceBook {
  const PriceBook._(this.quotes);

  static const PriceBook empty = PriceBook._(<String, PriceQuote>{});

  final Map<String, PriceQuote> quotes;

  PriceBook apply(PriceMessage message) {
    return switch (message) {
      PriceTick(:final quote) => _applyTick(quote),
      PriceSnapshot(:final quotes) => _applySnapshot(quotes),
      PriceHeartbeat() || PriceSymbolError() => this,
    };
  }

  /// Drops symbols that are no longer subscribed.
  PriceBook retain(Set<String> symbols) {
    if (quotes.keys.every(symbols.contains)) return this;
    return PriceBook._(
      Map.unmodifiable({
        for (final entry in quotes.entries)
          if (symbols.contains(entry.key)) entry.key: entry.value,
      }),
    );
  }

  PriceBook _applyTick(PriceQuote quote) {
    final current = quotes[quote.symbol];
    if (current != null && quote.seq <= current.seq) return this;
    return PriceBook._(Map.unmodifiable({...quotes, quote.symbol: quote}));
  }

  PriceBook _applySnapshot(List<PriceQuote> snapshot) {
    if (snapshot.isEmpty) return this;
    return PriceBook._(
      Map.unmodifiable({
        ...quotes,
        for (final quote in snapshot) quote.symbol: quote,
      }),
    );
  }
}
