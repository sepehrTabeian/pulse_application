import 'package:decimal/decimal.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';

/// Wire shape of a price (used for ticks and snapshot items).
class PriceQuoteModel {
  const PriceQuoteModel({
    this.symbol,
    this.bid,
    this.ask,
    this.last,
    this.seq,
    this.timestamp,
  });

  factory PriceQuoteModel.fromJson(JsonReader json) {
    return PriceQuoteModel(
      symbol: json.string('symbol'),
      bid: json.decimal('bid'),
      ask: json.decimal('ask'),
      last: json.decimal('last'),
      seq: json.integer('seq'),
      timestamp: json.dateTime('ts'),
    );
  }

  final String? symbol;
  final Decimal? bid;
  final Decimal? ask;
  final Decimal? last;
  final int? seq;
  final DateTime? timestamp;

  /// A quote without symbol, positive `last` and non-negative `seq` is not
  /// usable. Unusable bid/ask only become `null`.
  PriceQuote toEntity() {
    final cleanSymbol = symbol?.trim();
    if (cleanSymbol == null || cleanSymbol.isEmpty) {
      throw const ParsingException(field: 'symbol', expectedType: 'string');
    }
    final lastPrice = requireValue<Decimal>(last, 'last', 'decimal');
    if (lastPrice <= Decimal.zero) {
      throw ParsingException(
        field: 'last',
        expectedType: 'positive decimal',
        actualType: lastPrice.toString(),
      );
    }
    final sequence = requireValue<int>(seq, 'seq', 'integer');
    if (sequence < 0) {
      throw ParsingException(
        field: 'seq',
        expectedType: 'non-negative integer',
        actualType: sequence.toString(),
      );
    }
    return PriceQuote(
      symbol: cleanSymbol,
      last: lastPrice,
      seq: sequence,
      bid: _positiveOrNull(bid),
      ask: _positiveOrNull(ask),
      timestamp: timestamp,
    );
  }

  static Decimal? _positiveOrNull(Decimal? value) =>
      value != null && value > Decimal.zero ? value : null;
}
