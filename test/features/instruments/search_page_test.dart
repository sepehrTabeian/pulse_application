import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_searcher.dart';
import 'package:pulse/features/instruments/presentation/bloc/search_bloc.dart';
import 'package:pulse/features/instruments/presentation/pages/search_page.dart';
import 'package:pulse/features/watchlist/domain/use_cases/load_watchlist.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';

import '../../support/fakes.dart';
import '../../support/page_harness.dart';

final _l10n = AppLocalizationsFa();

class _Searcher implements InstrumentSearcher {
  Object? error;
  List<Instrument> results = [];
  final List<String> queries = [];

  @override
  Future<List<Instrument>> search(String query) async {
    queries.add(query);
    final e = error;
    if (e != null) throw e;
    return results;
  }
}

Future<(SearchBloc, WatchlistCubit, FakeBackend, _Searcher)> _pump(
  WidgetTester tester,
) async {
  final backend = FakeBackend(watchlist: ['AAPL']);
  final searcher = _Searcher();
  final bloc = SearchBloc(
    searcher: searcher,
    mapper: const PulseApiExceptionMapper(),
  );
  final watchlist = WatchlistCubit(
    loadWatchlist: LoadWatchlist(reader: backend, catalog: backend),
    writer: backend,
    mapper: const PulseApiExceptionMapper(),
  );
  await tester.pumpWidget(
    BlocProvider.value(
      value: watchlist,
      child: PulseApp(
        home: SearchPage(
          searchBloc: bloc,
          resolver: const DefaultErrorMessageResolver(),
        ),
      ),
    ),
  );
  // Fake-async: start loading, then pump until it completes.
  final loading = watchlist.load();
  await tester.pump();
  await loading;
  await tester.pump();
  return (bloc, watchlist, backend, searcher);
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets('starts with a prompt and no request', (tester) async {
    final (bloc, watchlist, _, searcher) = await _pump(tester);

    expect(find.text(_l10n.searchPrompt), findsOneWidget);
    expect(searcher.queries, isEmpty);
    unawaited(bloc.close());
    unawaited(watchlist.close());
  });

  testWidgets('typing searches once (debounced) and lists results', (
    tester,
  ) async {
    final (bloc, watchlist, _, searcher) = await _pump(tester);
    searcher.results = [testInstrument(symbol: 'MSFT')];

    await tester.enterText(find.byType(TextField), 'm');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'ms');
    await tester.pump(const Duration(milliseconds: 100));
    await _search(tester, 'msf');

    expect(searcher.queries, ['msf']);
    expect(find.text('MSFT'), findsOneWidget);
    unawaited(bloc.close());
    unawaited(watchlist.close());
  });

  testWidgets('an empty result explains that nothing was found', (
    tester,
  ) async {
    final (bloc, watchlist, _, _) = await _pump(tester);

    await _search(tester, 'zzz');

    expect(find.text(_l10n.searchNoResults), findsOneWidget);
    unawaited(bloc.close());
    unawaited(watchlist.close());
  });

  testWidgets('adding a result saves it; symbols already present are marked', (
    tester,
  ) async {
    final (bloc, watchlist, backend, searcher) = await _pump(tester);
    searcher.results = [
      testInstrument(symbol: 'AAPL'),
      testInstrument(symbol: 'MSFT'),
    ];

    await _search(tester, 'a');
    expect(find.text(_l10n.searchAlreadyAdded), findsOneWidget);

    await tester.tap(find.byTooltip(_l10n.actionAdd));
    await tester.pump();
    await tester.pump();

    expect(backend.server, ['AAPL', 'MSFT']);
    expect(find.text(_l10n.searchAlreadyAdded), findsNWidgets(2));
    unawaited(bloc.close());
    unawaited(watchlist.close());
  });

  testWidgets('a failure shows the reason and retry searches again', (
    tester,
  ) async {
    final (bloc, watchlist, _, searcher) = await _pump(tester);
    searcher.error = const ServiceUnavailableException();

    await _search(tester, 'x');
    expect(find.text(_l10n.errorServiceUnavailable), findsOneWidget);

    searcher.error = null;
    searcher.results = [testInstrument(symbol: 'XOM')];
    await tester.tap(find.text(_l10n.actionRetry));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('XOM'), findsOneWidget);
    unawaited(bloc.close());
    unawaited(watchlist.close());
  });
}
