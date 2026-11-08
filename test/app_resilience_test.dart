// Demo-critical behaviour, end to end with the real container and the real
// pulse_api simulator: the chaos switch, the price-socket lifecycle (no leak:
// `api.openConnectionCount`) and the release of every resource on teardown.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pulse/app_root.dart';
import 'package:pulse/core/di/app_injection.dart';
import 'package:pulse/core/di/injection.dart';
import 'package:pulse/core/di/trading_injection.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/features/watchlist/presentation/widgets/watchlist_row.dart';
import 'package:pulse_api/pulse_api.dart';

import 'support/in_memory_kv_store.dart';

final _l10n = AppLocalizationsFa();
const _chaosSwitch = ValueKey('chaos-switch');

class _Env {
  _Env(this.api, this.di);

  final FakeTradingApi api;
  final GetIt di;

  static _Env create({ChaosConfig chaos = ChaosConfig.instant, int seed = 7}) {
    final api = FakeTradingApi(
      chaos: chaos,
      seed: seed,
      requestTimeout: const Duration(milliseconds: 20),
    );
    final di = GetIt.asNewInstance();
    configureCoreDependencies(di);
    configureTradingDependencies(di, api: api);
    configureAppDependencies(di, store: InMemoryKeyValueStore());
    return _Env(api, di);
  }

  /// The container owns the api (lazily created), like in production.
  static _Env createOwned() {
    final di = GetIt.asNewInstance();
    configureCoreDependencies(di);
    configureTradingDependencies(di);
    configureAppDependencies(di, store: InMemoryKeyValueStore());
    return _Env(di<FakeTradingApi>(), di);
  }
}

Future<void> _settle(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<_Env> _start(
  WidgetTester tester, {
  _Env? env,
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final e = env ?? _Env.create();
  await tester.pumpWidget(AppRoot(di: e.di));
  await _settle(tester);
  return e;
}

/// Ends the test cleanly: unmounts the app first, then releases the server.
Future<void> _finish(WidgetTester tester, _Env env) async {
  await tester.pumpWidget(const SizedBox());
  await env.di.reset();
  env.api.dispose();
}

/// Pops the top screen like the system back button would.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
}

Future<void> _openWatchlistTab(WidgetTester tester) async {
  await tester.tap(find.text(_l10n.homeTabWatchlist));
  await _settle(tester, 2);
}

Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

bool _hasConnectionWarning() =>
    find.textContaining(_l10n.feedOffline).evaluate().isNotEmpty ||
    find.textContaining(_l10n.feedStale).evaluate().isNotEmpty ||
    find.textContaining(_l10n.feedConnecting).evaluate().isNotEmpty;

void main() {
  group('chaos switch (demo)', () {
    testWidgets('flips the server between realistic and storm at runtime', (
      tester,
    ) async {
      final env = await _start(
        tester,
        env: _Env.create(chaos: ChaosConfig.realistic),
      );
      expect(identical(env.api.chaos, ChaosConfig.realistic), isTrue);

      await tester.tap(find.byKey(_chaosSwitch));
      await tester.pump();
      expect(identical(env.api.chaos, ChaosConfig.storm), isTrue);
      expect(tester.widget<Switch>(find.byKey(_chaosSwitch)).value, isTrue);

      await tester.tap(find.byKey(_chaosSwitch));
      await tester.pump();
      expect(identical(env.api.chaos, ChaosConfig.realistic), isTrue);
      expect(tester.widget<Switch>(find.byKey(_chaosSwitch)).value, isFalse);

      await _finish(tester, env);
    });

    testWidgets(
      'storm: warnings appear, the app survives, one socket, then recovers',
      (tester) async {
        final env = await _start(
          tester,
          env: _Env.create(chaos: ChaosConfig.realistic),
        );
        expect(_hasConnectionWarning(), isFalse, reason: 'calm at the start');

        await tester.tap(find.byKey(_chaosSwitch));
        await tester.pump();

        var warned = false;
        var maxConnections = 0;
        for (var i = 0; i < 240 && !warned; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          warned = _hasConnectionWarning();
          if (env.api.openConnectionCount > maxConnections) {
            maxConnections = env.api.openConnectionCount;
          }
        }
        expect(warned, isTrue, reason: 'a dropped/stale feed is announced');
        expect(tester.takeException(), isNull, reason: 'the app survives');
        expect(maxConnections, lessThanOrEqualTo(2));

        // Back to a healthy network: warnings go away, exactly one socket.
        await tester.tap(find.byKey(_chaosSwitch));
        await tester.pump();
        var recovered = false;
        for (var i = 0; i < 240 && !recovered; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          recovered =
              !_hasConnectionWarning() && env.api.openConnectionCount == 1;
        }
        expect(recovered, isTrue, reason: 'recovers without a restart');
        expect(tester.takeException(), isNull);

        await _finish(tester, env);
      },
    );
  });

  group('price socket lifecycle (no leak)', () {
    testWidgets('start: exactly one connection', (tester) async {
      final env = await _start(tester);

      expect(env.api.openConnectionCount, 1);

      await _finish(tester, env);
      expect(env.api.openConnectionCount, 0);
    });

    testWidgets('switching tabs and opening screens keeps one connection', (
      tester,
    ) async {
      final env = await _start(tester);

      await _openWatchlistTab(tester);
      expect(env.api.openConnectionCount, 1);

      await tester.tap(find.text(_l10n.navOrders));
      await _settle(tester, 2);
      expect(env.api.openConnectionCount, 1);

      await tester.tap(find.text(_l10n.navWatchlist));
      await _settle(tester, 2);
      await tester.tap(find.byType(WatchlistRow).first);
      await _settle(tester, 4);
      expect(find.byType(WatchlistRow), findsNothing, reason: 'ticket is open');
      expect(env.api.openConnectionCount, 1);

      await _back(tester);
      await _settle(tester, 4);
      expect(env.api.openConnectionCount, 1);

      await tester.tap(find.text(_l10n.navSearchAdd));
      await _settle(tester, 4);
      expect(env.api.openConnectionCount, 1);
      await _back(tester);
      await _settle(tester, 4);
      expect(env.api.openConnectionCount, 1);

      await _finish(tester, env);
      expect(env.api.openConnectionCount, 0);
    });

    testWidgets('changing the symbols swaps the socket, never leaks one', (
      tester,
    ) async {
      final env = await _start(tester);
      await _openWatchlistTab(tester);
      expect(env.api.openConnectionCount, 1);

      await tester.drag(find.byType(WatchlistRow).first, const Offset(-800, 0));
      await _settle(tester, 6);

      expect(env.api.openConnectionCount, 1, reason: 'old socket was closed');

      await _finish(tester, env);
      expect(env.api.openConnectionCount, 0);
    });

    testWidgets('after a drop it reconnects and ends with one connection', (
      tester,
    ) async {
      final env = await _start(tester);
      expect(env.api.openConnectionCount, 1);

      // The server keeps dropping the socket for a while...
      env.api.chaos = ChaosConfig.instant.copyWith(
        meanTimeBetweenDisconnects: const Duration(milliseconds: 40),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(env.api.openConnectionCount, lessThanOrEqualTo(2));
      }
      // ...then becomes stable again.
      env.api.chaos = ChaosConfig.instant;
      await tester.pump(const Duration(seconds: 10));
      await _settle(tester);

      expect(env.api.openConnectionCount, 1);
      expect(_hasConnectionWarning(), isFalse);

      await _finish(tester, env);
      expect(env.api.openConnectionCount, 0);
    });

    testWidgets('background closes the socket, foreground reopens one', (
      tester,
    ) async {
      final env = await _start(tester);
      expect(env.api.openConnectionCount, 1);

      await _lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await _settle(tester, 2);
      expect(env.api.openConnectionCount, 0);

      await _lifecycle(tester, [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await _settle(tester);
      expect(env.api.openConnectionCount, 1);

      await _finish(tester, env);
      expect(env.api.openConnectionCount, 0);
    });
  });

  group('teardown releases everything', () {
    testWidgets('closing the app disposes the api: no socket, no timer', (
      tester,
    ) async {
      final env = await _start(tester, env: _Env.createOwned());
      expect(env.api.openConnectionCount, 1);

      await _lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]);
      await _settle(tester, 2);

      expect(env.api.openConnectionCount, 0);
      await expectLater(env.api.getInstruments(), throwsA(anything));
      // flutter_test fails the test on any timer still pending below.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('unmounting the app leaves no open connection', (tester) async {
      final env = await _start(tester);

      await tester.pumpWidget(const SizedBox());

      expect(env.api.openConnectionCount, 0);
      await env.di.reset();
      env.api.dispose();
    });
  });
}
