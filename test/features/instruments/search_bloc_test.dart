import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_searcher.dart';
import 'package:pulse/features/instruments/presentation/bloc/search_bloc.dart';

import '../../support/fakes.dart';

class _FakeSearcher implements InstrumentSearcher {
  final List<String> queries = [];
  Future<List<Instrument>> Function(String q) handler = (q) async => [
    testInstrument(symbol: q.toUpperCase()),
  ];

  @override
  Future<List<Instrument>> search(String query) {
    queries.add(query);
    return handler(query);
  }
}

void _run(
  void Function(
    SearchBloc bloc,
    _FakeSearcher s,
    FakeAsync a,
    List<SearchState> states,
  )
  body,
) {
  fakeAsync((async) {
    final searcher = _FakeSearcher();
    final bloc = SearchBloc(
      searcher: searcher,
      mapper: const PulseApiExceptionMapper(),
    );
    final states = <SearchState>[];
    bloc.stream.listen(states.add);
    body(bloc, searcher, async, states);
    bloc.close();
    async.flushMicrotasks();
  });
}

void main() {
  test('typing quickly searches only once, for the last query', () {
    _run((bloc, searcher, async, states) {
      bloc.add(const SearchQueryChanged('a'));
      async.elapse(const Duration(milliseconds: 100));
      bloc.add(const SearchQueryChanged('ap'));
      async.elapse(const Duration(milliseconds: 100));
      bloc.add(const SearchQueryChanged('app'));
      async.elapse(const Duration(seconds: 1));

      expect(searcher.queries, ['app']);
      expect(states.last.status, SearchStatus.results);
      expect(states.last.results.single.symbol, 'APP');
    });
  });

  test('shows loading while the request is in flight', () {
    _run((bloc, searcher, async, states) {
      final gate = Completer<List<Instrument>>();
      searcher.handler = (_) => gate.future;

      bloc.add(const SearchQueryChanged('x'));
      async.elapse(const Duration(milliseconds: 400));

      expect(states.last.status, SearchStatus.loading);
      gate.complete(const []);
      async.flushMicrotasks();
      expect(states.last.status, SearchStatus.results);
      expect(states.last.results, isEmpty);
    });
  });

  test('blank input resets to idle without calling the server', () {
    _run((bloc, searcher, async, states) {
      bloc.add(const SearchQueryChanged('app'));
      async.elapse(const Duration(seconds: 1));

      bloc.add(const SearchQueryChanged('   '));
      async.elapse(const Duration(seconds: 1));

      expect(searcher.queries, ['app']);
      expect(states.last.status, SearchStatus.idle);
    });
  });

  test('an older slow response never overwrites a newer query', () {
    _run((bloc, searcher, async, states) {
      final slow = Completer<List<Instrument>>();
      searcher.handler = (q) => q == 'old'
          ? slow.future
          : Future.value([testInstrument(symbol: 'NEW')]);

      bloc.add(const SearchQueryChanged('old'));
      async.elapse(const Duration(milliseconds: 400));
      bloc.add(const SearchQueryChanged('new'));
      async.elapse(const Duration(milliseconds: 400));
      slow.complete([testInstrument(symbol: 'OLD')]);
      async.flushMicrotasks();

      expect(states.last.results.single.symbol, 'NEW');
      expect(
        states.expand((s) => s.results).map((i) => i.symbol),
        isNot(contains('OLD')),
      );
    });
  });

  test('server errors become a failure state with an AppException', () {
    _run((bloc, searcher, async, states) {
      searcher.handler = (_) async => throw const ServiceUnavailableException();

      bloc.add(const SearchQueryChanged('x'));
      async.elapse(const Duration(seconds: 1));

      expect(states.last.status, SearchStatus.failure);
      expect(states.last.error, isA<ServiceUnavailableException>());
    });
  });

  test('searching again after a failure works', () {
    _run((bloc, searcher, async, states) {
      var fail = true;
      searcher.handler = (q) async {
        if (fail) throw const ServiceUnavailableException();
        return [testInstrument(symbol: 'OK')];
      };
      bloc.add(const SearchQueryChanged('x'));
      async.elapse(const Duration(seconds: 1));
      fail = false;

      bloc.add(const SearchQueryChanged('xy'));
      async.elapse(const Duration(seconds: 1));

      expect(states.last.status, SearchStatus.results);
    });
  });

  test('queries are trimmed before searching', () {
    _run((bloc, searcher, async, states) {
      bloc.add(const SearchQueryChanged('  btc  '));
      async.elapse(const Duration(seconds: 1));

      expect(searcher.queries, ['btc']);
    });
  });

  test('persian and unusual input is passed through untouched', () {
    _run((bloc, searcher, async, states) {
      bloc.add(const SearchQueryChanged('اپل'));
      async.elapse(const Duration(seconds: 1));

      expect(searcher.queries, ['اپل']);
    });
  });
}
