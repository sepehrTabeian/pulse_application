import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

Widget _host(
  Widget child, {
  TextDirection dir = TextDirection.ltr,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? PulseTheme.light(),
    home: Directionality(
      textDirection: dir,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('PulsePriceChange', () {
    testWidgets('up shows an up arrow, the sign text and a spoken label', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          const PulsePriceChange(
            direction: PulseDirection.up,
            text: '+1.50 (+0.66%)',
            semanticsLabel: 'Up 1.50',
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text('+1.50 (+0.66%)'), findsOneWidget);
      expect(find.bySemanticsLabel('Up 1.50'), findsOneWidget);
    });

    testWidgets(
      'direction is never colour-only: each direction has its own icon',
      (t) async {
        for (final entry in {
          PulseDirection.up: Icons.arrow_upward,
          PulseDirection.down: Icons.arrow_downward,
          PulseDirection.flat: Icons.remove,
        }.entries) {
          await t.pumpWidget(
            _host(
              PulsePriceChange(
                direction: entry.key,
                text: 'x',
                semanticsLabel: 'l',
              ),
            ),
          );

          expect(
            find.byIcon(entry.value),
            findsOneWidget,
            reason: '${entry.key}',
          );
        }
      },
    );

    testWidgets('dimmed lowers the opacity (stale)', (t) async {
      await t.pumpWidget(
        _host(
          const PulsePriceChange(
            direction: PulseDirection.flat,
            text: '0',
            semanticsLabel: 'l',
            dimmed: true,
          ),
        ),
      );

      final opacity = t.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, lessThan(1));
    });

    testWidgets('numbers stay left-to-right inside an RTL layout', (t) async {
      await t.pumpWidget(
        _host(
          const PulsePriceChange(
            direction: PulseDirection.up,
            text: '+1.50',
            semanticsLabel: 'l',
          ),
          dir: TextDirection.rtl,
        ),
      );

      final context = t.element(find.text('+1.50'));
      expect(Directionality.of(context), TextDirection.ltr);
    });

    testWidgets('works in dark theme too', (t) async {
      await t.pumpWidget(
        _host(
          const PulsePriceChange(
            direction: PulseDirection.down,
            text: '-1',
            semanticsLabel: 'l',
          ),
          theme: PulseTheme.dark(),
        ),
      );

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });
  });

  group('PulseStatusBanner', () {
    testWidgets('shows message and an info button that fires', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(
          PulseStatusBanner(
            message: 'Prices may be old',
            kind: PulseBannerKind.warning,
            infoLabel: 'More info',
            onInfo: () => taps++,
          ),
        ),
      );

      expect(find.text('Prices may be old'), findsOneWidget);
      await t.tap(find.byTooltip('More info'));
      expect(taps, 1);
    });

    testWidgets('info button is absent without a callback', (t) async {
      await t.pumpWidget(
        _host(
          const PulseStatusBanner(message: 'm', kind: PulseBannerKind.info),
        ),
      );

      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('info button meets the 48dp touch target', (t) async {
      await t.pumpWidget(
        _host(
          PulseStatusBanner(
            message: 'm',
            kind: PulseBannerKind.error,
            infoLabel: 'i',
            onInfo: () {},
          ),
        ),
      );

      final size = t.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('PulsePrimaryButton', () {
    testWidgets('fires when enabled', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(PulsePrimaryButton(label: 'Send', onPressed: () => taps++)),
      );

      await t.tap(find.text('Send'));

      expect(taps, 1);
    });

    testWidgets('is inert and shows progress while pending', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(
          PulsePrimaryButton(
            label: 'Send',
            onPressed: () => taps++,
            isPending: true,
            pendingLabel: 'Sending…',
          ),
        ),
      );

      await t.tap(find.byType(FilledButton), warnIfMissed: false);

      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sending…'), findsOneWidget);
      expect(find.text('Send'), findsNothing);
    });

    testWidgets('is disabled without a callback', (t) async {
      await t.pumpWidget(
        _host(const PulsePrimaryButton(label: 'Send', onPressed: null)),
      );

      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('is at least 48dp tall', (t) async {
      await t.pumpWidget(
        _host(PulsePrimaryButton(label: 'Send', onPressed: () {})),
      );

      expect(
        t.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('state views', () {
    testWidgets('message view renders title, body and a working action', (
      t,
    ) async {
      var taps = 0;
      await t.pumpWidget(
        _host(
          PulseMessageView(
            icon: Icons.error_outline,
            title: 'Oops',
            body: 'Something failed',
            actionLabel: 'Retry',
            onAction: () => taps++,
          ),
        ),
      );

      expect(find.text('Oops'), findsOneWidget);
      expect(find.text('Something failed'), findsOneWidget);
      await t.tap(find.text('Retry'));
      expect(taps, 1);
    });

    testWidgets('message view hides the action when none is given', (t) async {
      await t.pumpWidget(
        _host(const PulseMessageView(icon: Icons.inbox, title: 'Empty')),
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('loading view exposes a semantic label', (t) async {
      await t.pumpWidget(_host(const PulseLoadingView(label: 'Loading')));

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });

  testWidgets('info sheet shows text and closes', (t) async {
    await t.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPulseInfoSheet(
              context,
              title: 'Title',
              body: 'Body text',
              closeLabel: 'Close',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Body text'), findsOneWidget);

    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(find.text('Body text'), findsNothing);
  });
}
