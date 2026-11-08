import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/watchlist/domain/services/watchlist_rules.dart';

void main() {
  const rules = WatchlistRules();

  group('add', () {
    test('appends a trimmed symbol and returns a NEW list', () {
      final original = ['A'];

      final result = rules.add(original, ' B ');

      expect(result, ['A', 'B']);
      expect(original, ['A']);
    });

    test('rejects blank and duplicate symbols', () {
      expect(() => rules.add(['A'], '  '), throwsA(isA<ValidationException>()));
      expect(() => rules.add(['A'], 'A'), throwsA(isA<ValidationException>()));
      expect(
        () => rules.add(['A'], ' A '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects the 21st symbol as WATCHLIST_FULL but allows the 20th', () {
      final nineteen = [for (var i = 0; i < 19; i++) 'S$i'];
      final twenty = rules.add(nineteen, 'LAST');

      expect(twenty, hasLength(20));
      expect(
        () => rules.add(twenty, 'ONE_TOO_MANY'),
        throwsA(
          isA<BusinessRuleException>().having(
            (e) => e.code,
            'code',
            'WATCHLIST_FULL',
          ),
        ),
      );
    });

    test('result is unmodifiable', () {
      expect(() => rules.add(['A'], 'B').add('C'), throwsUnsupportedError);
    });
  });

  group('remove', () {
    test('removes the symbol, ignores unknown ones', () {
      expect(rules.remove(['A', 'B'], 'A'), ['B']);
      expect(rules.remove(['A', 'B'], 'Z'), ['A', 'B']);
      expect(rules.remove(<String>[], 'A'), isEmpty);
    });
  });

  group('move', () {
    test('moves forward and backward', () {
      expect(rules.move(['A', 'B', 'C'], 0, 2), ['B', 'C', 'A']);
      expect(rules.move(['A', 'B', 'C'], 2, 0), ['C', 'A', 'B']);
      expect(rules.move(['A', 'B', 'C'], 1, 1), ['A', 'B', 'C']);
    });

    test('rejects out-of-range indices', () {
      for (final args in [(-1, 0), (0, -1), (3, 0), (0, 3)]) {
        expect(
          () => rules.move(['A', 'B', 'C'], args.$1, args.$2),
          throwsA(isA<ValidationException>()),
          reason: '$args',
        );
      }
      expect(
        () => rules.move(<String>[], 0, 0),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
