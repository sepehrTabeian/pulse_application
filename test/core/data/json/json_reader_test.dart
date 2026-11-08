import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/errors/app_exception.dart';

JsonReader _r(String json) => JsonReader.parse(json);

void main() {
  group('parse', () {
    test('reads a JSON object', () {
      expect(_r('{"a":"x"}').string('a'), 'x');
    });

    test('invalid JSON throws ParsingException', () {
      expect(() => _r('{oops'), throwsA(isA<ParsingException>()));
      expect(() => _r(''), throwsA(isA<ParsingException>()));
    });

    test('non-object roots throw ParsingException with actual type', () {
      for (final body in ['[]', 'null', '1', '"s"', 'true']) {
        expect(() => _r(body), throwsA(isA<ParsingException>()), reason: body);
      }
    });
  });

  group('string', () {
    test('returns strings, stringifies numbers, null otherwise', () {
      final r = _r('{"s":"a","i":5,"d":1.5,"n":null,"b":true,"l":[1]}');

      expect(r.string('s'), 'a');
      expect(r.string('i'), '5');
      expect(r.string('d'), '1.5');
      expect(r.string('n'), isNull);
      expect(r.string('b'), isNull);
      expect(r.string('l'), isNull);
      expect(r.string('missing'), isNull);
    });

    test('requireString rejects blank, null and wrong types', () {
      final r = _r('{"a":"  ","b":null,"c":{}, "d":" ok "}');

      expect(() => r.requireString('a'), throwsA(isA<ParsingException>()));
      expect(() => r.requireString('b'), throwsA(isA<ParsingException>()));
      expect(() => r.requireString('c'), throwsA(isA<ParsingException>()));
      expect(() => r.requireString('zzz'), throwsA(isA<ParsingException>()));
      expect(r.requireString('d'), 'ok');
    });

    test('ParsingException names the field path and actual type', () {
      final e = _catch(() => _r('{"a":[]}').requireString('a'));

      expect(e.field, r'$.a');
      expect(e.expectedType, 'string');
      expect(e.actualType, contains('List'));
    });
  });

  group('decimal', () {
    test('parses decimal strings exactly', () {
      final r = _r('{"a":"189.25","b":"0.0005","c":" 10 ","d":"-3.5"}');

      expect(r.decimal('a'), Decimal.parse('189.25'));
      expect(r.decimal('b'), Decimal.parse('0.0005'));
      expect(r.decimal('c'), Decimal.fromInt(10));
      expect(r.decimal('d'), Decimal.parse('-3.5'));
    });

    test('accepts numbers sent instead of strings (type drift)', () {
      final r = _r('{"i":10,"d":189.25}');

      expect(r.decimal('i'), Decimal.fromInt(10));
      expect(r.decimal('d'), Decimal.parse('189.25'));
    });

    test('returns null for garbage', () {
      final r = _r(
        '{"a":"NaN","b":"","c":"-","d":"abc","e":null,"f":true,"g":[],'
        '"h":"1e999999999","i":"Infinity","j":"1.2.3"}',
      );

      for (final key in 'abcdefghij'.split('')) {
        expect(r.decimal(key), isNull, reason: key);
      }
    });

    test('rejects absurdly long decimal text', () {
      final r = _r('{"a":"${'9' * 500}"}');

      expect(r.decimal('a'), isNull);
    });

    test('requireDecimal throws when invalid', () {
      expect(
        () => _r('{"a":"x"}').requireDecimal('a'),
        throwsA(isA<ParsingException>()),
      );
    });

    test('keeps precision that doubles would lose', () {
      expect(
        _r('{"a":"67250.1234"}').requireDecimal('a').toString(),
        '67250.1234',
      );
    });
  });

  group('integer', () {
    test('reads ints, integral doubles and numeric strings', () {
      final r = _r('{"a":42,"b":42.0,"c":" 42 ","d":"7"}');

      expect(r.integer('a'), 42);
      expect(r.integer('b'), 42);
      expect(r.integer('c'), 42);
      expect(r.integer('d'), 7);
    });

    test('returns null for fractions, garbage and wrong types', () {
      final r = _r('{"a":42.5,"b":"x","c":null,"d":true,"e":"4.2"}');

      for (final key in 'abcde'.split('')) {
        expect(r.integer(key), isNull, reason: key);
      }
    });

    test('requireInteger throws when invalid', () {
      expect(
        () => _r('{"a":"x"}').requireInteger('a'),
        throwsA(isA<ParsingException>()),
      );
    });
  });

  group('boolean', () {
    test('reads bool, string and 0/1 variants', () {
      final r = _r(
        '{"a":true,"b":"false","c":"TRUE","d":1,"e":0,"f":2,"g":"yes","h":null}',
      );

      expect(r.boolean('a'), isTrue);
      expect(r.boolean('b'), isFalse);
      expect(r.boolean('c'), isTrue);
      expect(r.boolean('d'), isTrue);
      expect(r.boolean('e'), isFalse);
      expect(r.boolean('f'), isNull);
      expect(r.boolean('g'), isNull);
      expect(r.boolean('h'), isNull);
    });
  });

  group('dateTime', () {
    test('parses ISO strings and ignores garbage', () {
      final r = _r('{"a":"2026-11-02T13:00:00.000Z","b":"nope","c":5}');

      expect(r.dateTime('a'), DateTime.utc(2026, 11, 2, 13));
      expect(r.dateTime('b'), isNull);
      expect(r.dateTime('c'), isNull);
    });
  });

  group('lists', () {
    test('objects keeps object items and drops others', () {
      final r = _r('{"l":[{"a":1},null,5,"x",[],{"a":2}]}');

      final items = r.objects('l')!;

      expect(items.map((e) => e.integer('a')), [1, 2]);
    });

    test('objects is null when key missing or not a list', () {
      final r = _r('{"l":{"a":1},"n":null}');

      expect(r.objects('l'), isNull);
      expect(r.objects('n'), isNull);
      expect(r.objects('missing'), isNull);
    });

    test('strings keeps only string items', () {
      final r = _r('{"l":["A",1,null,"B",{}]}');

      expect(r.strings('l'), ['A', 'B']);
    });

    test('returned lists are unmodifiable', () {
      final r = _r('{"l":["A"]}');

      expect(() => r.strings('l')!.add('B'), throwsUnsupportedError);
    });

    test('empty list yields empty result, not null', () {
      expect(_r('{"l":[]}').objects('l'), isEmpty);
      expect(_r('{"l":[]}').strings('l'), isEmpty);
    });
  });

  group('mapLenient / requireValue', () {
    test('skips failing items and reports them', () {
      final skipped = <ParsingException>[];

      final result = mapLenient<int, int>(
        [1, 2, 3],
        (i) => i == 2 ? throw const ParsingException(field: 'x') : i * 10,
        onSkipped: skipped.add,
      );

      expect(result, [10, 30]);
      expect(skipped, hasLength(1));
    });

    test('does not swallow non-parsing errors', () {
      expect(
        () => mapLenient<int, int>([1], (i) => throw StateError('bug')),
        throwsStateError,
      );
    });

    test('requireValue returns value or throws naming the field', () {
      expect(requireValue<String>('a', 'f', 'string'), 'a');
      expect(
        () => requireValue<String>(null, 'f', 'string'),
        throwsA(isA<ParsingException>().having((e) => e.field, 'field', 'f')),
      );
    });
  });
}

ParsingException _catch(void Function() body) {
  try {
    body();
  } on ParsingException catch (e) {
    return e;
  }
  throw StateError('expected ParsingException');
}
