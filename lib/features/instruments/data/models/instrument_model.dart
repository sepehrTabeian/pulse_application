import 'package:decimal/decimal.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';

/// Wire shape of an instrument. Parsing never throws; business validity is
/// decided in [toEntity].
class InstrumentModel {
  const InstrumentModel({
    this.symbol,
    this.name,
    this.type,
    this.exchange,
    this.currency,
    this.tickSize,
    this.lotSize,
    this.prevClose,
    this.tradable,
    this.unit,
  });

  factory InstrumentModel.fromJson(JsonReader json) {
    return InstrumentModel(
      symbol: json.string('symbol'),
      name: json.string('name'),
      type: json.string('type'),
      exchange: json.string('exchange'),
      currency: json.string('currency'),
      tickSize: json.decimal('tickSize'),
      lotSize: json.decimal('lotSize'),
      prevClose: json.decimal('prevClose'),
      tradable: json.boolean('tradable'),
      unit: json.string('unit'),
    );
  }

  static const String _defaultCurrency = 'USD';

  final String? symbol;
  final String? name;
  final String? type;
  final String? exchange;
  final String? currency;
  final Decimal? tickSize;
  final Decimal? lotSize;
  final Decimal? prevClose;
  final bool? tradable;
  final String? unit;

  /// Throws [ParsingException] when a required field is unusable.
  Instrument toEntity() {
    final cleanSymbol = requireValue<String>(
      symbol?.trim(),
      'symbol',
      'string',
    );
    if (cleanSymbol.isEmpty) {
      throw const ParsingException(field: 'symbol', expectedType: 'string');
    }
    final prevCloseValue = prevClose;
    return Instrument(
      symbol: cleanSymbol,
      name: _nonBlank(name) ?? cleanSymbol,
      type: _typeFrom(type),
      exchange: _nonBlank(exchange) ?? '',
      currency: _nonBlank(currency) ?? _defaultCurrency,
      tickSize: _positive(tickSize, 'tickSize'),
      lotSize: _positive(lotSize, 'lotSize'),
      prevClose: prevCloseValue != null && prevCloseValue > Decimal.zero
          ? prevCloseValue
          : null,
      // Safe side: an instrument is tradable only when the server says so.
      tradable: tradable ?? false,
      unit: _nonBlank(unit) ?? _defaultUnit(cleanSymbol, _typeFrom(type)),
    );
  }

  static Decimal _positive(Decimal? value, String field) {
    final v = requireValue<Decimal>(value, field, 'decimal');
    if (v <= Decimal.zero) {
      throw ParsingException(
        field: field,
        expectedType: 'positive decimal',
        actualType: v.toString(),
      );
    }
    return v;
  }

  /// The server sends no unit: stocks and ETFs trade in shares, a coin in
  /// its own ticker (`BTC-USD` -> `BTC`).
  static String _defaultUnit(String symbol, InstrumentType type) =>
      type == InstrumentType.crypto ? symbol.split('-').first : 'share';

  static String? _nonBlank(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  static InstrumentType _typeFrom(String? raw) {
    return switch (raw?.trim().toUpperCase()) {
      'STOCK' || 'EQUITY' => InstrumentType.stock,
      'ETF' => InstrumentType.etf,
      'CRYPTO' => InstrumentType.crypto,
      _ => InstrumentType.other,
    };
  }
}
