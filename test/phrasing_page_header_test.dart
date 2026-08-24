/// The Phrasing header is a `Column` above an `Expanded` diagram, so
/// every line added to it is taken off the text the reader came for.
///
/// #312 item 7 added a note under the level chips, and #312 item 4 was a
/// complaint about this very header being too tall. The two pull against
/// each other, and the only honest instrument is a pump: the web build is
/// skwasm, where a screenshot cannot report an overflow and the rendered
/// text is not in the DOM.
///
/// 992 is the width the app admits at all — see `SmallScreenGate` — so it
/// is the worst case, not an arbitrary small number.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/phrasing_page.dart';

Future<void> _pump(WidgetTester tester, Size size, {double font = 16}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final settings = AppSettings();
  await settings.setFontSize(font);
  await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
    value: settings,
    child: const MaterialApp(
      // A Strong's-tagged translation is the TALLEST case, not a lesser
      // one: it draws the level note, the gloss legend AND the paragraph
      // explaining that this edition carries no grammatical parse.
      home: PhrasingPage(
        book: 'John',
        chapter: 1,
        verse: 1,
        locale: 'en',
        version: 'kjvs',
      ),
    ),
  ));
  // Not `pumpAndSettle`: the chapter is read off the real asset bundle,
  // which needs wall-clock I/O, and until it lands the page holds a
  // spinner that never settles.
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  // Long enough to also drain AppSettings' 600ms write-back debounce,
  // which otherwise outlives the tree and fails the test on teardown.
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One test, not four: the chapter is served by a process-wide cache
  // that only resolves for whichever test loaded it first, so a second
  // `testWidgets` in this file sits on the spinner forever.
  testWidgets('the diagram keeps a floor at every font and every height',
      (tester) async {
    await _pump(tester, const Size(992, 700));
    // If the note is absent, every height below is measuring the old
    // header and the whole file proves nothing.
    expect(find.textContaining(RegExp(r'lines in verses')), findsOneWidget);

    // The whole matrix, because the failure is a product of the two: the
    // header grows with the font and the room shrinks with the window,
    // and only the corner where both are worst overflowed. Before the
    // header was capped, 24pt in a 480px window overflowed by 68px and
    // left the diagram exactly 0 — the reader's own font setting could
    // push the text off its own page.
    for (final font in [16.0, 20.0, 24.0]) {
      for (final height in [700.0, 560.0, 480.0]) {
        await _pump(tester, Size(992, height), font: font);
        final where = 'font $font in a ${height}px window';
        expect(tester.getSize(find.byType(Scrollable).last).height,
            greaterThan(120),
            reason: where);
        expect(tester.takeException(), isNull, reason: where);
      }
    }

    // The cap is a ceiling, not a height. If `SingleChildScrollView`
    // stopped shrink-wrapping, every reader would lose 45% of the pane
    // to whitespace and nothing above would notice.
    await _pump(tester, const Size(1400, 900));
    expect(tester.getSize(find.byType(Scrollable).last).height,
        greaterThan(900 * 0.45),
        reason: 'the header is short here and must give the slack back');
    expect(tester.takeException(), isNull);
  });
}
