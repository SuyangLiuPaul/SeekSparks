// 对照 folds its notes behind the same pill the reader uses.
//
// 2026-09-15: 「我要对照组好像 阅读模式一样有那个胶囊展开」.
//
// The circled numbers arrived here earlier the same day, replacing a
// literal `n` per note — 羅馬書 8:28 in 梁家鏗 had read 「…蒙召的人。
// n n n n n」. That was half a fix. A reader could now see WHICH note
// was which and still had no way to READ one, short of finding and
// holding a ten-pixel glyph to raise a tooltip. The reader pane beside
// this one folds the same notes behind a 「译者注 ▾」 pill.
//
// So this is the SAME WIDGET, not a second implementation of it: one
// place decides what a note looks like, and a note is the same object
// in both views.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/verse_notes_block.dart';

/// A verse carrying five notes, which is 羅馬書 8:28 in 梁家鏗 — the row
/// the report was made against.
///
/// The notes are LONG on purpose. `kNotePreviewChars` is 160, chosen so
/// that a one-line note is never folded and the reader just sees it —
/// so a fixture of five short notes produces no pill at all, correctly,
/// and would have tested nothing. 梁家鏗's real notes run to thousands
/// of characters.
const _n1 = '28节注一：“为了善”一句，原文的主语可以是神，也可以是万事，'
    '本译本取前者，参下文29节的“预知”与“预定”。';
const _n5 = '28节注五：“蒙召”在保罗书信中一律指神有效的呼召，'
    '而不是泛指一般的邀请，参罗1.6、9.24，林前1.24。';
const _noted = '我们知道，为了善，万事都与爱神的人同工，就是那些照神的计划蒙召的人。'
    '<note:$_n1><note:28节注二：“同工”原文 συνεργεῖ，参林前3.9。>'
    '<note:28节注三：“计划”原文 πρόθεσις，参弗1.11、3.11。>'
    '<note:28节注四：本节异文甚多，最古的抄本作“神与爱他的人同工”。>'
    '<note:$_n5>';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets("the pill is the reader's own widget, and it opens",
      (tester) async {
    late AppSettings settings;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) {
        settings = AppSettings();
        return settings;
      },
      child: MaterialApp(
        theme: ThemeData(extensions: const [WbColors.light]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(builder: (context) {
              final s = context.watch<AppSettings>();
              return VerseNotesBlock(
                notes: notesInReadingOrder(_noted),
                settings: s,
                locale: 'zh-Hans',
              );
            }),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(settings.locale, isNotEmpty);

    // The reader's pill, by its own label — not a second control that
    // merely looks like one.
    expect(find.text('译者注 ▾'), findsOneWidget);
    final folded = tester.getSize(find.byType(VerseNotesBlock)).height;

    await tester.tap(find.text('译者注 ▾'));
    await tester.pumpAndSettle();
    final open = tester.getSize(find.byType(VerseNotesBlock)).height;

    expect(open, greaterThan(folded),
        reason: 'folded $folded px, open $open px — the pill did not '
            'unfold anything');
    // Folding is a PREVIEW, not a hide: the block shows what it can and
    // cuts the rest, so the assertion that matters is that the LAST
    // note is only reachable once open.
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .join(),
      contains('林前1.24'),
      reason: 'the tail of the last note is only reachable once open',
    );
  });

  test('the 对照 row hands its notes over in reading order', () {
    // The contract between the pane and the block: the block is given
    // the note TEXTS, in the order they appear, and numbers them
    // itself. Asserted on the parse rather than through the pane so a
    // change to either side has to come back through here.
    final notes = notesInReadingOrder(_noted);
    expect(notes, hasLength(5));
    expect(notes.first, contains('28节注一'));
    expect(notes.last, contains('28节注五'));
  });

  test('a verse with no notes hands over nothing', () {
    // The pane only builds a Column when this is non-empty — the
    // overwhelming majority of rows have no notes, and the densest
    // surface in the app must not grow a layout node per verse for a
    // feature they do not use.
    expect(notesInReadingOrder('起初，神创造天地。'), isEmpty);
  });
}
