// The update controls read as one block, set in one type.
//
// 2026-09-15, photographed off a tablet with the whole region circled:
// 「这一块字体感觉很不协调」.
//
// Three controls about one subject — check now, check daily, how often
// — in three separate Cards, each with its own left inset (12 px, 4 px,
// and a ListTile's own 16), and the first of them set in the Material
// theme's label type while the two below it followed the reader's Font
// Size setting. Every piece was individually defensible. Together they
// read as three unrelated fragments, one of which belonged to a
// different application.
//
// The assertions are about the RELATIONSHIP, not about a number: the
// check's label must be set in the same type as the switch beside it,
// and the three must share a card. A future control added to the block
// in the theme's own type fails here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/settings_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/update_service.dart';

late AppSettings _settings;

/// The three labels, in whatever locale the page came up in.
String _s(String key, String fallback) =>
    uiStrings[key]?[_settings.locale] ?? fallback;

/// The same harness `settings_font_size_behaviour_test.dart` uses, and
/// for the same reason: this page is the app's biggest, and a surface
/// it was never sized for turns an unrelated dialog into a red band
/// that buries whatever the test was actually looking at.
Future<void> _pumpSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1280, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) {
          _settings = AppSettings();
          return _settings;
        }),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 700));
  expect(tester.takeException(), isNull);

  // The page is a `ListView`, so a card below the fold has not been
  // built yet and no finder can see it. Scroll the block into view
  // before asking anything about it.
  await tester.scrollUntilVisible(
    find.text(_s('settingsUpdateFrequency', 'How often')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

/// The size a `Text` was actually painted at — read off the `RichText`
/// it resolves into, rather than off a `TextStyle` in the source.
double _paintedSize(WidgetTester tester, Finder finder) {
  final rich = tester.widget<RichText>(find.descendant(
    of: finder,
    matching: find.byType(RichText),
  ));
  return (rich.text.style?.fontSize) ?? double.nan;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the check, the switch and the interval share one type',
      (tester) async {
    if (!UpdateService.isSupported) {
      // The block hides itself on the web, where a reload IS the
      // update. Nothing to compare.
      return;
    }
    await _pumpSettings(tester);

    final check = find.text(_s('checkForUpdates', 'Check for updates'));
    final auto = find.text(
        _s('settingsAutoCheckUpdates', 'Check for updates daily'));
    final often = find.text(_s('settingsUpdateFrequency', 'How often'));

    for (final (name, finder) in [
      ('the check', check),
      ('the switch', auto),
      ('the interval', often),
    ]) {
      expect(finder, findsOneWidget, reason: '$name is not on the page');
    }

    final sizes = {
      'the check': _paintedSize(tester, check),
      'the switch': _paintedSize(tester, auto),
      'the interval': _paintedSize(tester, often),
    };
    final distinct = sizes.values.toSet();
    expect(distinct.length, 1,
        reason: 'the three rows of one block are set in '
            '${distinct.length} different sizes: $sizes');
  });

  testWidgets('and they share a card', (tester) async {
    if (!UpdateService.isSupported) return;
    await _pumpSettings(tester);

    final often = find.text(_s('settingsUpdateFrequency', 'How often'));

    // One card holding all three. `findsOneWidget` on the ancestor set
    // is the assertion: three cards would give three different
    // ancestors and the intersection below would be empty.
    Set<Element> cardsAbove(Finder f) => find
        .ancestor(of: f, matching: find.byType(Card))
        .evaluate()
        .toSet();

    final shared = cardsAbove(often)
        .intersection(cardsAbove(
            find.text(_s('checkForUpdates', 'Check for updates'))))
        .intersection(cardsAbove(find.text(
            _s('settingsAutoCheckUpdates', 'Check for updates daily'))));
    expect(shared, isNotEmpty,
        reason: 'the three controls are in different cards, so the '
            'reader has no way to see that they are about one thing');
  });
}
