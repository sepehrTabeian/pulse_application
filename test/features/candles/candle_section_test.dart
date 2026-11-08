import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';
import 'package:pulse/features/candles/presentation/cubit/candles_cubit.dart';
import 'package:pulse/features/candles/presentation/widgets/candle_section.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

import '../../support/candle_fakes.dart';
import '../../support/fakes.dart';

final _l10n = AppLocalizationsFa();

Future<(CandlesCubit, FakeCandleReader)> _pump(
  WidgetTester tester, {
  FakeCandleReader? reader,
  bool load = true,
}) async {
  final fake = reader ?? FakeCandleReader();
  final cubit = CandlesCubit(
    symbol: 'AAPL',
    reader: fake,
    mapper: const PulseApiExceptionMapper(),
  );
  await tester.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: PulseApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CandleSection(
              instrument: testInstrument(),
              resolver: const DefaultErrorMessageResolver(),
            ),
          ),
        ),
      ),
    ),
  );
  if (load) {
    final loading = cubit.load();
    await tester.pump();
    await loading;
    await tester.pump();
  }
  return (cubit, fake);
}

void main() {
  testWidgets('loading shows progress, then the chart with a legend', (
    tester,
  ) async {
    final (cubit, _) = await _pump(tester, load: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final loading = cubit.load();
    await tester.pump();
    await loading;
    await tester.pump();

    expect(find.byType(PulseCandleChart), findsOneWidget);
    expect(find.text(_l10n.chartLegend), findsOneWidget);
    unawaited(cubit.close());
  });

  testWidgets('the chart has a spoken summary with symbol and count', (
    tester,
  ) async {
    final (cubit, _) = await _pump(tester);

    expect(find.bySemanticsLabel(RegExp('AAPL')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('10')), findsWidgets);
    unawaited(cubit.close());
  });

  testWidgets('selecting a bar shows its exact OHLC values', (tester) async {
    final (cubit, _) = await _pump(tester);
    final box = tester.getRect(find.byType(PulseCandleChart));

    await tester.tapAt(Offset(box.left + 2, box.center.dy));
    await tester.pump();

    expect(find.textContaining('100.00'), findsWidgets);
    unawaited(cubit.close());
  });

  testWidgets('switching the range requests that range', (tester) async {
    final (cubit, reader) = await _pump(tester);

    await tester.tap(find.text(_l10n.rangeWeek));
    await tester.pump();
    await tester.pump();

    expect(reader.requests.last.$2, CandleRange.week);
    await tester.tap(find.text(_l10n.rangeMonth));
    await tester.pump();
    await tester.pump();
    expect(reader.requests.last.$2, CandleRange.month);
    unawaited(cubit.close());
  });

  testWidgets('a failure shows the reason and retry reloads', (tester) async {
    final reader = FakeCandleReader()
      ..error = const ServiceUnavailableException();
    final (cubit, _) = await _pump(tester, reader: reader);

    expect(find.text(_l10n.errorServiceUnavailable), findsOneWidget);

    reader.error = null;
    await tester.tap(find.text(_l10n.actionRetry));
    await tester.pump();
    await tester.pump();

    expect(find.byType(PulseCandleChart), findsOneWidget);
    unawaited(cubit.close());
  });

  testWidgets('no bars shows the empty message', (tester) async {
    final reader = FakeCandleReader()..candles = const <Candle>[];
    final (cubit, _) = await _pump(tester, reader: reader);

    expect(find.text(_l10n.chartEmpty), findsOneWidget);
    expect(find.byType(PulseCandleChart), findsNothing);
    unawaited(cubit.close());
  });

  testWidgets('a single bar and a flat market still render', (tester) async {
    final reader = FakeCandleReader()..candles = testCandles(count: 1);
    final (cubit, _) = await _pump(tester, reader: reader);

    expect(find.byType(PulseCandleChart), findsOneWidget);
    expect(tester.takeException(), isNull);
    unawaited(cubit.close());
  });

  testWidgets('hundreds of bars render without errors', (tester) async {
    final reader = FakeCandleReader()..candles = testCandles(count: 600);
    final (cubit, _) = await _pump(tester, reader: reader);

    expect(find.byType(PulseCandleChart), findsOneWidget);
    expect(tester.takeException(), isNull);
    unawaited(cubit.close());
  });

  testWidgets('changing the range clears the old selection', (tester) async {
    final (cubit, _) = await _pump(tester);
    final box = tester.getRect(find.byType(PulseCandleChart));
    await tester.tapAt(Offset(box.left + 2, box.center.dy));
    await tester.pump();
    expect(find.textContaining('·'), findsWidgets);

    await tester.tap(find.text(_l10n.rangeWeek));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('·'), findsNothing);
    unawaited(cubit.close());
  });
}
