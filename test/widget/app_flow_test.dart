import 'package:bmtc_predictor/app.dart';
import 'package:bmtc_predictor/core/services/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Thursday 5 Nov 2026, 8:30 am IST: morning peak.
final _now = DateTime.utc(2026, 11, 5, 8, 30);

Widget _app() => ProviderScope(
      overrides: [clockProvider.overrideWithValue(() => _now)],
      child: const App(),
    );

/// Lets real async work (asset loading) and fake timers run until loading is done.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 200));
    if (i >= 2 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rootBundle.clear();
  });

  testWidgets('search -> stop -> buses -> report arrival -> reports', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await _settle(tester);
    expect(find.text('BMTC Delay Predictor'), findsOneWidget);
    expect(find.text('Rain mode'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('stop-search')), 'Central Silk Board');
    await tester.pump();
    final firstStop = find.byWidgetPredicate((w) {
      final k = w.key;
      return w is ListTile && k is ValueKey && '${k.value}'.startsWith('stop-');
    }).first;
    await tester.tap(firstStop);
    await _settle(tester);

    expect(find.textContaining('Now · 8:30 am'), findsOneWidget);
    expect(find.textContaining('Expected '), findsWidgets);
    expect(find.textContaining('90% by'), findsWidgets);

    // Report the first bus that can be reported.
    final arrived = find.text('Arrived').first;
    await tester.tap(arrived);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-arrived')));
    await _settle(tester);
    expect(find.textContaining('Thanks!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // Rain mode from the app bar changes predictions without crashing.
    await tester.tap(find.byTooltip('Rain mode off'));
    await _settle(tester);
    expect(find.text('Rain mode'), findsWidgets);

    await tester.pageBack();
    await _settle(tester);
    await tester.tap(find.byTooltip('Your reports'));
    await _settle(tester);
    expect(find.text('Your reports'), findsOneWidget);
    expect(find.byKey(const Key('export-csv')), findsOneWidget);
    expect(find.textContaining('Model 20'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // 1 report
  });

  testWidgets('Kannada toggle switches stop names', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await tester.tap(find.byKey(const Key('lang-toggle')));
    await _settle(tester);
    expect(find.text('EN'), findsOneWidget);
  });
}
