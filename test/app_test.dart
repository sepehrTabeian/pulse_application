import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

class _TitlePage extends StatelessWidget {
  const _TitlePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Text(AppLocalizations.of(context).appTitle));
  }
}

void main() {
  testWidgets('app renders Persian title in RTL with Pulse theme', (
    tester,
  ) async {
    await tester.pumpWidget(const PulseApp(home: _TitlePage()));
    await tester.pumpAndSettle();

    expect(find.text('پالس'), findsOneWidget);
    final context = tester.element(find.text('پالس'));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Theme.of(context).extension<PulseSemanticColors>(), isNotNull);
  });

  testWidgets('dark mode uses the dark semantic colors', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const PulseApp(home: _TitlePage()));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('پالس'));
    expect(
      Theme.of(context).extension<PulseSemanticColors>(),
      PulseSemanticColors.dark,
    );
  });
}
