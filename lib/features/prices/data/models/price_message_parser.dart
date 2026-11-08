import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/error_codes.dart';
import 'package:pulse/features/prices/data/models/price_quote_model.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';

/// Parses one raw stream message. Never throws: malformed or unknown
/// messages yield `null` so they are dropped (PARSE-04, PARSE-05).
abstract final class PriceMessageParser {
  static PriceMessage? tryParse(String raw) {
    final JsonReader json;
    try {
      json = JsonReader.parse(raw);
    } on ParsingException {
      return null;
    }
    return switch (json.string('type')) {
      'snapshot' => _snapshot(json),
      'tick' => _tick(json),
      'heartbeat' => PriceHeartbeat(json.dateTime('ts')),
      'error' => PriceSymbolError(
        code: json.string('code') ?? ErrorCodes.unknown,
        symbol: json.string('symbol'),
      ),
      _ => null,
    };
  }

  static PriceMessage? _snapshot(JsonReader json) {
    final items = json.objects('prices');
    if (items == null) return null;
    final quotes = mapLenient<JsonReader, PriceQuote>(
      items,
      (item) => PriceQuoteModel.fromJson(item).toEntity(),
    );
    return PriceSnapshot(quotes);
  }

  static PriceMessage? _tick(JsonReader json) {
    try {
      return PriceTick(PriceQuoteModel.fromJson(json).toEntity());
    } on ParsingException {
      return null;
    }
  }
}
