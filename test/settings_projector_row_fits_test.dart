// A Projector settings row must fit its own column.
//
// 2026-09-15. Settings → Projector laid every row out as
// `Expanded(label), SizedBox(12), control`: the label flexed, the
// control took its natural width. A DropdownButton's natural width is
// the width of its WIDEST item, and the companion-edition dropdown
// lists every English edition this build ships — 「American Standard
// Version (Yahweh)」 and friends — which wanted 709 px. In the 552 px
// column a 1280 px desktop gives the Settings page, that left the
// label's Expanded with nothing: it was handed 0 px, wrapped to 232 px
// of stacked fragments, and the row overflowed by 169 px. The
// exception was being drained by
// `settings_update_block_is_one_thing_test.dart`, which builds this
// card in its ListView cache extent on the way past.
//
// Same disease as `settings_title_not_squeezed_test.dart`, one card
// over: a control that asks for more width than the row has takes it,
// and the label pays. This test is deliberately not about the shape of
// the fix — it measures BOXES on the real Settings page. Any future
// control parked in a Projector row that wants more than its share
// fails here, whether or not it is a dropdown.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/settings_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/responsive.dart';

/// Every width this app claims to render: the narrowest phone it
/// supports, two current phones, a small tablet, an iPad, and the
/// desktop / TV columns. `settingsMaxWidth` caps the column from
/// `tablet` up, so the last four exercise 560 / 640 / 720 as well.
const _widths = <double>[320, 375, 390, 600, 768, 1024, 1280, 1920];

/// The two locales whose labels differ most in length. The bug bit in
/// English, where both the row's label and the dropdown's items are
/// several times longer than their Chinese equivalents.
const _locales = <String>['zh-Hans', 'en'];

late AppSettings _settings;

String _s(String key, String fallback) =>
    uiStrings[key]?[_settings.locale] ?? fallback;

/// Brings the Projector card up at [width] in [locale] and leaves it
/// on screen. Throws if the page came up with an exception, so an
/// overflow anywhere on the way here is this test's business too.
Future<void> _openProjector(
    WidgetTester tester, double width, String locale) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
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
  await _settings.setLocale(locale);
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text(_s('projectorSettings', 'Projector')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull,
      reason: 'the Settings page did not come up clean at '
          '${width.toInt()} px in $locale');
}

/// The card the Projector title sits in.
Finder _projectorCard() => find
    .ancestor(
      of: find.text(_s('projectorSettings', 'Projector')),
      matching: find.byType(Card),
    )
    .first;

/// Every horizontal flex inside the Projector card, laid out.
Iterable<RenderFlex> _rows(WidgetTester tester) => find
    .descendant(of: _projectorCard(), matching: find.byType(Row))
    .evaluate()
    .map((e) => e.renderObject)
    .whereType<RenderFlex>()
    .where((f) => f.hasSize && f.direction == Axis.horizontal);

/// What a flex's children add up to. More than the flex's own width is
/// exactly what "A RenderFlex overflowed by N pixels" means.
double _childrenWidth(RenderFlex flex) {
  var total = 0.0;
  var child = flex.firstChild;
  while (child != null) {
    total += child.size.width;
    child = flex.childAfter(child);
  }
  return total;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in _locales) {
    group('in $locale', () {
      for (final w in _widths) {
        testWidgets('at ${w.toInt()} px no Projector row spills its column',
            (tester) async {
          await _openProjector(tester, w, locale);

          final rows = _rows(tester).toList();
          expect(rows, isNotEmpty,
              reason: 'the Projector card has no rows to measure — either '
                  'it stopped rendering or the card finder is wrong');

          for (final flex in rows) {
            final want = _childrenWidth(flex);
            // Half a pixel of slack for the sub-pixel widths a flex
            // hands out; the failure this guards against was 169.
            expect(want, lessThanOrEqualTo(flex.size.width + 0.5),
                reason: 'a Projector row is ${flex.size.width.toStringAsFixed(0)} px '
                    'wide and its children want ${want.toStringAsFixed(0)} px — '
                    'it overflows by ${(want - flex.size.width).toStringAsFixed(0)}. '
                    'Something in this row is sizing to its own content '
                    'instead of to the share of the row it was given.');
          }
        });

        testWidgets('at ${w.toInt()} px the companion label keeps its share',
            (tester) async {
          await _openProjector(tester, w, locale);

          // The row that broke: its control is the dropdown over every
          // English edition, the longest list the card has.
          final label = find.descendant(
            of: _projectorCard(),
            matching: find.text(
                _s('projectorCompanionForZh', 'Beside a Chinese passage, show')),
          );
          expect(label, findsOneWidget);

          final row = tester.renderObject<RenderFlex>(
              find.ancestor(of: label, matching: find.byType(Row)).first);
          final got = tester.getSize(label).width;

          // A third of the row is a floor, not a target. The broken
          // layout gave this label exactly 0.0 px.
          expect(got, greaterThan(row.size.width / 3),
              reason: 'the label got ${got.toStringAsFixed(0)} px of a '
                  '${row.size.width.toStringAsFixed(0)} px row — the control '
                  'beside it is taking the width the label needs');
        });
      }
    });
  }

  testWidgets('the label is a line or two, not a column of fragments',
      (tester) async {
    // The symptom as the operator met it: 232 px of stacked pieces
    // where a label belonged. One line's height is measured on the
    // SAME label in the SAME card at the widest column the app has,
    // rather than reconstructed from a TextStyle by hand.
    await _openProjector(tester, 1920, 'en');
    final label = find.descendant(
      of: _projectorCard(),
      matching:
          find.text(_s('projectorCompanionForZh', 'Beside a Chinese passage, show')),
    );
    final oneLine = tester.getSize(label).height;

    for (final w in _widths) {
      await _openProjector(tester, w, 'en');
      final got = tester.getSize(find.descendant(
        of: _projectorCard(),
        matching: find.text(
            _s('projectorCompanionForZh', 'Beside a Chinese passage, show')),
      )).height;
      expect(got, lessThanOrEqualTo(oneLine * 3),
          reason: 'at ${w.toInt()} px the label is '
              '${(got / oneLine).round()} lines tall');
    }
  });

  testWidgets('the reason the rule exists: this dropdown wants more width '
      'than the settings column it lives in', (tester) async {
    // The guard for the guards above. They measure the FIXED layout, so
    // if the English edition list ever got short they would pass no
    // matter what anyone parked in a Projector row, and the rule would
    // be enforced by nothing. This measures the cause directly: an
    // unconstrained DropdownButton takes the width of its WIDEST item.
    // The column the overflow was photographed in: a desktop window,
    // where the Settings page caps itself at 640 and the card inside it
    // gets 552.
    final column = ResponsiveBreakpoints.settingsMaxWidth(DeviceClass.desktop);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: DropdownButton<String>(
            value: versionsForLanguage('en').first.value,
            onChanged: (_) {},
            items: [
              for (final v in versionsForLanguage('en'))
                DropdownMenuItem(
                    value: v.value,
                    child: Text(v.menuLabel,
                        style: const TextStyle(fontSize: kFontSizeDefault))),
            ],
          ),
        ),
      ),
    ));
    final wants = tester.getSize(find.byType(DropdownButton<String>)).width;
    expect(wants, greaterThan(column),
        reason: 'this dropdown wants only ${wants.toStringAsFixed(0)} px, '
            'which fits the ${column.toStringAsFixed(0)} px column — either '
            'the edition names got much shorter or Flutter stopped sizing '
            'to the widest item, and this whole rule can be re-examined');
  });
}
