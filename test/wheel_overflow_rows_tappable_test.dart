// Every row in the wheel's overflow sheet does something when pressed.
//
// 2026-09-15, reported from a phone with both offending rows circled:
// 「按了没反应」. The sheet's last two entries — Interface Language and
// Home — had no `onTap` at all. They held a `LanguageSwitcherButton`
// and a `HomeIconButton` in the `leading` slot, on the reasoning that
// each widget already knows what it does and should not be
// reimplemented.
//
// That reasoning is right about the widgets and wrong about the slot. In
// an AppBar the button IS the row, so putting the real button there is
// exactly correct. In a `ListTile` it is a 24 px icon at the left end of
// a 300 px row, and the title — the words the reader actually aims at —
// is inert. Three rows above it behaved normally, which is what makes it
// read as a broken app rather than as a small target.
//
// The assertion is deliberately about the SHAPE, not about these two
// rows: any future row that carries a title and no tap fails here,
// whether or not it happens to contain a button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/wheel_chrome_bar.dart';

Widget _host({required VoidCallback onFind}) => ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        theme: ThemeData(extensions: const [WbColors.light]),
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              actions: wheelChromeActions(
                context: context,
                locale: 'en',
                paneWidth: 360,
                s: (k, fallback) => fallback,
                onFind: onFind,
                onFilter: () {},
                onAbout: () {},
                onHelp: () {},
                viewSwitch: const SizedBox.shrink(),
              ),
            ),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

Future<void> _openOverflow(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no row in the sheet has a title and no tap', (tester) async {
    await tester.pumpWidget(_host(onFind: () {}));
    await _openOverflow(tester);

    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(rows, isNotEmpty, reason: 'the sheet did not open');

    final inert = <String>[];
    for (final row in rows) {
      final title = row.title;
      final label = title is Text ? (title.data ?? '') : '<not a Text>';
      if (row.onTap == null && row.onLongPress == null) inert.add(label);
    }
    expect(inert, isEmpty,
        reason: 'these rows print words and answer to nothing: '
            '${inert.join(', ')}. A control inside `leading` is a 24 px '
            'target at the end of a full-width row; the row is what the '
            'reader presses.');
  });

  testWidgets('the rows that were reported dead are alive', (tester) async {
    await tester.pumpWidget(_host(onFind: () {}));
    await _openOverflow(tester);

    // Interface Language opens a picker of the three the app ships.
    await tester.tap(find.text('Interface Language'));
    await tester.pumpAndSettle();
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('picking a language actually sets it', (tester) async {
    // The chrome is asked for English labels so the finders can name
    // them; what is being tested is the SETTING the picker writes, and
    // that is read off the provider rather than off the screen.
    late AppSettings settings;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        theme: ThemeData(extensions: const [WbColors.light]),
        home: Builder(builder: (context) {
          settings = context.read<AppSettings>();
          return Scaffold(
            appBar: AppBar(
              actions: wheelChromeActions(
                context: context,
                locale: 'en',
                paneWidth: 360,
                s: (k, fallback) => fallback,
                onFind: () {},
                onFilter: () {},
                onAbout: () {},
                onHelp: () {},
                viewSwitch: const SizedBox.shrink(),
              ),
            ),
            body: const SizedBox.expand(),
          );
        }),
      ),
    ));
    await _openOverflow(tester);
    await tester.tap(find.text('Interface Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文'));
    await tester.pumpAndSettle();
    // `AppSettings.notifyListeners` arms a 600 ms debounce that writes
    // the userPrefs blob. It schedules no frame, so `pumpAndSettle`
    // returns with it still armed and teardown fails on `!timersPending`
    // — which is the pending-timer nuisance two other test files work
    // around by never calling `setLocale`. This one has to call it, so
    // it waits the debounce out instead.
    await tester.pump(const Duration(milliseconds: 700));

    expect(settings.locale, 'zh-Hant',
        reason: 'the picker opened and chose nothing — which is the same '
            'defect one layer down');
  });

  testWidgets('Home is absent rather than dead when there is nowhere to go',
      (tester) async {
    // The old `HomeIconButton` hid itself via `SizedBox.shrink` when the
    // navigator could not pop, which left a row with a title, an empty
    // leading slot and no behaviour — a third way to print words that do
    // nothing. The row itself is now the thing that is absent.
    await tester.pumpWidget(_host(onFind: () {}));
    await _openOverflow(tester);
    expect(find.text('Home'), findsNothing,
        reason: 'this page IS the root, so there is no Home to go to and '
            'the row should not be offered');
  });

  testWidgets('the rows that always worked still work', (tester) async {
    var found = false;
    await tester.pumpWidget(_host(onFind: () => found = true));
    await _openOverflow(tester);
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    expect(found, isTrue);
  });
}
