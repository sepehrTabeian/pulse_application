import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/watchlist/data/models/watchlist_model.dart';

WatchlistModel _model(String json) =>
    WatchlistModel.fromJson(JsonReader.parse(json));

void main() {
  test('keeps server order', () {
    expect(_model('{"symbols":["B","A","C"]}').toSymbols(), ['B', 'A', 'C']);
  });

  test('empty list is a valid empty watchlist', () {
    expect(_model('{"symbols":[]}').toSymbols(), isEmpty);
  });

  test('missing, null or non-list symbols throw (never "empty")', () {
    for (final json in ['{}', '{"symbols":null}', '{"symbols":"AAPL"}']) {
      expect(
        () => _model(json).toSymbols(),
        throwsA(isA<ParsingException>()),
        reason: json,
      );
    }
  });

  test('drops non-strings and blanks, trims and removes duplicates', () {
    final symbols = _model(
      '{"symbols":["AAPL"," MSFT ","",5,null,"AAPL","  "]}',
    ).toSymbols();

    expect(symbols, ['AAPL', 'MSFT']);
  });
}
