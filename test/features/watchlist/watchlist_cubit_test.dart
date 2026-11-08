import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_reader.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_writer.dart';
import 'package:pulse/features/watchlist/domain/use_cases/load_watchlist.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';

import '../../support/fakes.dart';

class _FakeBackend
    implements WatchlistReader, WatchlistWriter, InstrumentCatalog {
  List<String> server = ['A', 'B', 'C'];
  Object? loadError;
  final List<List<String>> puts = [];
  Future<List<String>> Function(List<String> symbols)? onPut;

  @override
  Future<List<String>> getSymbols() async {
    final e = loadError;
    if (e != null) throw e;
    return server;
  }

  @override
  Future<List<Instrument>> getInstruments() async => [
    for (final s in ['A', 'B', 'C', 'D', 'E']) testInstrument(symbol: s),
  ];

  @override
  Future<List<String>> replaceSymbols(List<String> symbols) async {
    puts.add(List.of(symbols));
    final handler = onPut;
    if (handler != null) return handler(symbols);
    server = List.of(symbols);
    return server;
  }
}

WatchlistCubit _cubit(_FakeBackend b) => WatchlistCubit(
  loadWatchlist: LoadWatchlist(reader: b, catalog: b),
  writer: b,
  mapper: const PulseApiExceptionMapper(),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeBackend backend;
  late WatchlistCubit cubit;

  setUp(() {
    backend = _FakeBackend();
    cubit = _cubit(backend);
  });
  tearDown(() => cubit.close());

  group('load', () {
    test('starts loading, then ready with items in server order', () async {
      expect(cubit.state.status, WatchlistStatus.loading);

      await cubit.load();

      expect(cubit.state.status, WatchlistStatus.ready);
      expect(cubit.state.symbols, ['A', 'B', 'C']);
      expect(cubit.state.items.map((i) => i.symbol), ['A', 'B', 'C']);
    });

    test('an empty watchlist is the empty state, not an error', () async {
      backend.server = [];

      await cubit.load();

      expect(cubit.state.isEmpty, isTrue);
    });

    test(
      'a failing load becomes a failure state with an AppException',
      () async {
        backend.loadError = const ServiceUnavailableException();

        await cubit.load();

        expect(cubit.state.status, WatchlistStatus.failure);
        expect(cubit.state.error, isA<ServiceUnavailableException>());
      },
    );

    test('an unknown error is wrapped, never leaked raw', () async {
      backend.loadError = StateError('boom');

      await cubit.load();

      expect(cubit.state.error, isA<UnexpectedException>());
    });

    test('retrying after a failure can succeed', () async {
      backend.loadError = const ServiceUnavailableException();
      await cubit.load();
      backend.loadError = null;

      await cubit.load();

      expect(cubit.state.status, WatchlistStatus.ready);
    });

    test(
      'symbols without instrument data are kept but not displayed',
      () async {
        backend.server = ['A', 'ZZZ'];

        await cubit.load();

        expect(cubit.state.symbols, ['A', 'ZZZ']);
        expect(cubit.state.items.map((i) => i.symbol), ['A']);
      },
    );
  });

  group('editing', () {
    setUp(() async => cubit.load());

    test('add is optimistic: shown immediately, saved after', () async {
      final future = cubit.add(testInstrument(symbol: 'D'));

      expect(cubit.state.symbols, ['A', 'B', 'C', 'D']);
      expect(cubit.state.isSaving, isTrue);
      await future;

      expect(backend.puts.last, ['A', 'B', 'C', 'D']);
      expect(cubit.state.isSaving, isFalse);
      expect(cubit.state.saveError, isNull);
    });

    test('remove and reorder are saved', () async {
      await cubit.remove('B');
      await cubit.reorder(0, 2);

      expect(backend.server, ['C', 'A']);
      expect(cubit.state.symbols, ['C', 'A']);
    });

    test('reorder uses the ReorderableListView convention', () async {
      await cubit.reorder(0, 3);

      expect(cubit.state.symbols, ['B', 'C', 'A']);

      await cubit.reorder(2, 0);

      expect(cubit.state.symbols, ['A', 'B', 'C']);
    });

    test('a failed save rolls back to the server-confirmed list', () async {
      backend.onPut = (_) async => throw const ServiceUnavailableException();

      await cubit.add(testInstrument(symbol: 'D'));

      expect(cubit.state.symbols, ['A', 'B', 'C']);
      expect(cubit.state.saveError, isA<ServiceUnavailableException>());
      expect(cubit.state.isSaving, isFalse);
    });

    test('after a rollback the next edit works normally', () async {
      backend.onPut = (_) async => throw const ServiceUnavailableException();
      await cubit.remove('A');
      backend.onPut = null;

      await cubit.remove('B');

      expect(cubit.state.symbols, ['A', 'C']);
      expect(cubit.state.saveError, isNull);
    });

    test('duplicates are rejected locally without a request', () async {
      await cubit.add(testInstrument(symbol: 'A'));

      expect(backend.puts, isEmpty);
      expect(cubit.state.saveError, isA<ValidationException>());
      expect(cubit.state.symbols, ['A', 'B', 'C']);
    });

    test('the 21st symbol is rejected locally as WATCHLIST_FULL', () async {
      backend.server = [for (var i = 0; i < 20; i++) 'S$i'];
      await cubit.load();

      await cubit.add(testInstrument(symbol: 'D'));

      expect(backend.puts, isEmpty);
      expect(
        (cubit.state.saveError as BusinessRuleException).code,
        'WATCHLIST_FULL',
      );
    });

    test(
      'rapid edits are serialised and coalesced into the final list',
      () async {
        final gate = Completer<void>();
        backend.onPut = (symbols) async {
          if (backend.puts.length == 1) await gate.future;
          backend.server = List.of(symbols);
          return backend.server;
        };

        final f1 = cubit.remove('A');
        final f2 = cubit.remove('B');
        final f3 = cubit.add(testInstrument(symbol: 'D'));
        await _settle();
        expect(backend.puts, hasLength(1), reason: 'only one save in flight');
        gate.complete();
        await Future.wait([f1, f2, f3]);

        expect(backend.puts.last, ['C', 'D']);
        expect(cubit.state.symbols, ['C', 'D']);
        expect(backend.puts.length, lessThanOrEqualTo(2));
      },
    );

    test('a failure mid-burst rolls back everything to confirmed', () async {
      backend.onPut = (_) async => throw const ServiceUnavailableException();

      await Future.wait([cubit.remove('A'), cubit.remove('B')]);

      expect(cubit.state.symbols, ['A', 'B', 'C']);
    });

    test('the server list wins if it differs from what we sent', () async {
      backend.onPut = (_) async => ['C', 'B', 'A'];

      await cubit.remove('B');

      expect(cubit.state.symbols, ['C', 'B', 'A']);
    });

    test('edits before the list is loaded are ignored', () async {
      final fresh = _cubit(backend);

      await fresh.remove('A');

      expect(backend.puts, isEmpty);
      await fresh.close();
    });

    test('clearSaveError removes the message', () async {
      await cubit.add(testInstrument(symbol: 'A'));
      expect(cubit.state.saveError, isNotNull);

      cubit.clearSaveError();

      expect(cubit.state.saveError, isNull);
    });

    test('closing during a save does not throw', () async {
      final gate = Completer<void>();
      backend.onPut = (symbols) async {
        await gate.future;
        return symbols;
      };
      final f = cubit.remove('A');
      await _settle();

      await cubit.close();
      gate.complete();

      await expectLater(f, completes);
    });
  });
}
