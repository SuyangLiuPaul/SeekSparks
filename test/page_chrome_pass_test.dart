// 2026-08-08 (task #279): a ratchet for the thirteen-page chrome pass.
//
// #279 is not one change, it is thirteen — and the failure mode of a
// long pass is not that a page is missed, it is that a page already
// done quietly grows a rounded card back a week later. No widget test
// catches that: a `BorderRadius.circular(10)` renders perfectly, passes
// every assertion about behaviour, and is wrong only against a rule
// that lives in prose (`workbench_theme.dart`: *square corners and 1px
// hairline borders, no shadows, no cards*).
//
// So the rule is asserted about the SOURCE, the same species of
// invariant as `page_reachability_test.dart`. [_passed] is the pass's
// progress bar: a page joins it in the iteration that converts it, and
// can never silently leave.
//
// What this deliberately does NOT check is density. Padding, type size
// and line height are out of scope for #279 by the brief's own words —
// a page that wants to be read is allowed to breathe. Only the chrome
// (corners, borders, shadows) must match.
//
// Nor does it catch round chrome that no source line asks for. Material
// gives `IconButton.filled`/`filledTonal` a CircleBorder by default, so
// the A-/A+ buttons in the font-size sheet are circles with nothing to
// grep for. Squaring those is one line in an `iconButtonTheme`, not a
// per-file edit, and it would land on every surface at once — so it is
// a separate iteration, not smuggled into a pane conversion.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files that have been through the chrome pass. Add, never remove.
const List<String> _passed = <String>[
  'lib/pages/stats_page.dart',
  'lib/pages/settings_page.dart',
  'lib/pages/evidence_page.dart',
  'lib/pages/evidence_detail_page.dart',
  'lib/pages/family_tree_page.dart',
  'lib/widgets/wb_surfaces.dart',
  // The family tree is not one file. `person_detail_sheet` is where the
  // tree round-trips to a verse, and `floating_toast` is the feedback it
  // shows on the way — a converted page behind an unconverted sheet is a
  // page that still has a rounded card in it.
  'lib/widgets/person_detail_sheet.dart',
  'lib/utils/floating_toast.dart',
  // The trivia page carries its own reader-side sheet
  // (`showBibleTriviaSheet`) and book-filter sheet in the same file, so
  // one entry covers all three surfaces.
  'lib/pages/bible_trivia_page.dart',
  // The Atlas is one page over three surfaces: the index column, the map
  // canvas it drives, and the place detail — which is a column above
  // 1180 px and a sheet below it. All three are listed, because the
  // sheet is the one a rounded corner would creep back into.
  'lib/pages/atlas_page.dart',
  'lib/widgets/place_map.dart',
  'lib/widgets/places_pane.dart',
  // 2026-08-09: the heaviest offender in the app was never on the
  // thirteen-PAGE list, because it is not a page — it is the workbench's
  // own centre pane, and by the governing principle the workbench is the
  // app. One file, but three surfaces a reader sees without opening
  // anything (the chapter text, the auto-hide header, the auto-hide
  // bottom bar) plus every sheet the reader can open from them.
  'lib/widgets/bible_reading_pane.dart',
];

/// Files that still carry unconverted chrome, and how much. This is the
/// pass's remaining work, ordered by weight — start at the top.
///
/// Two entries are here because the surface may genuinely argue for what
/// it has, and the pass should decide rather than flatten:
///   * `workbench_theme.dart` — a 2px radius on an inline word HIGHLIGHT.
///     That is a text mark, not chrome; but it sits in the file that
///     states the rule, so leaving it undecided makes the rule look
///     unenforced.
///   * `browse_window.dart` — the shadow under the word tooltip. A
///     tooltip floats over arbitrary content and has only its hairline
///     to separate it; bwh11 describes a bordered popup, not a shadowed
///     one, so the hairline is probably enough.
const Map<String, int> _remaining = <String, int>{
  'lib/widgets/book_chapter_picker.dart': 18,
  'lib/widgets/analysis_tabs.dart': 11,
  'lib/widgets/related_verses_pane.dart': 8,
  'lib/pages/map_viewer_page.dart': 7,
  'lib/widgets/phrase_match_pane.dart': 7,
  'lib/widgets/vocabulary_pane.dart': 6,
  'lib/pages/bible_timeline_page.dart': 5,
  'lib/main.dart': 4,
  'lib/pages/highlights_page.dart': 4,
  'lib/pages/sermons_page.dart': 4,
  'lib/pages/strongs_entry_page.dart': 4,
  'lib/widgets/morph_search_pane.dart': 4,
  'lib/pages/loading_page.dart': 3,
  'lib/pages/phrasing_page.dart': 3,
  'lib/widgets/highlights_sheet.dart': 3,
  'lib/widgets/verse_list_pane.dart': 3,
  'lib/widgets/word_distribution.dart': 3,
  'lib/pages/home_page.dart': 2,
  'lib/pages/sermon_detail_page.dart': 2,
  'lib/widgets/kwic_pane.dart': 2,
  'lib/widgets/onboarding_dialog.dart': 2,
  'lib/widgets/search_stats_strip.dart': 2,
  'lib/widgets/small_screen_advisory.dart': 2,
  'lib/widgets/verse_popup_sheet.dart': 2,
  'lib/widgets/version_picker_sheet.dart': 2,
  'lib/constants/word_study_style.dart': 1,
  'lib/constants/workbench_theme.dart': 1,
  'lib/pages/library_page.dart': 1,
  'lib/pages/word_list_page.dart': 1,
  'lib/utils/build_verse_content_spans.dart': 1,
  'lib/utils/clipboard_helper.dart': 1,
  'lib/widgets/browse_nav_strip.dart': 1,
  'lib/widgets/browse_window.dart': 1,
  'lib/widgets/confidence_badge.dart': 1,
  'lib/widgets/contact_line.dart': 1,
  'lib/widgets/context_pane.dart': 1,
  'lib/widgets/copy_center_sheet.dart': 1,
  'lib/widgets/docked_panel.dart': 1,
  'lib/widgets/note_reference_picker_sheet.dart': 1,
  'lib/widgets/originals_sheet.dart': 1,
  'lib/widgets/workbench_chrome.dart': 1,
};

/// Counts rule violations in already-comment-stripped source.
int _countOffences(String stripped) {
  var n = 0;
  for (final line in stripped.split('\n')) {
    if (line.contains('BorderRadius.circular(')) n++;
    if (line.contains('BoxShadow(')) n++;
    // `elevation: 0` is the rule being stated, not broken.
    final elev = RegExp(r'elevation:\s*([0-9.]+)').firstMatch(line);
    if (elev != null && double.parse(elev.group(1)!) > 0) n++;
  }
  return n;
}

/// Strips `//` and `/* */` comments so prose about the rule — including
/// this file's own vocabulary — cannot fail the check it describes.
String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlock
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        // Leave anything inside a string literal alone; a URL is the
        // realistic case ('https://…'), and a false strip there could
        // mask a real offender on the same line.
        if (i < 0) return line;
        final before = line.substring(0, i);
        final quotes = "'".allMatches(before).length +
            '"'.allMatches(before).length;
        return quotes.isEven ? before : line;
      })
      .join('\n');
}

void main() {
  group('#279 chrome pass', () {
    test('every page listed as passed still is', () {
      final offences = <String>[];

      for (final path in _passed) {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: '$path is on the passed list but does not exist. '
                'If it was deleted, remove it from _passed.');
        final src = _stripComments(file.readAsStringSync());
        final lines = src.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final where = '$path:${i + 1}';
          if (line.contains('BorderRadius.circular(')) {
            offences.add('$where — rounded corner');
          }
          if (line.contains('BoxShadow(')) {
            offences.add('$where — shadow');
          }
          // `elevation: 0` is the rule being stated, not broken.
          final elev = RegExp(r'elevation:\s*([0-9.]+)').firstMatch(line);
          if (elev != null && double.parse(elev.group(1)!) > 0) {
            offences.add('$where — elevation ${elev.group(1)}');
          }
        }
      }

      expect(
        offences,
        isEmpty,
        reason: 'workbench_theme.dart: "Square corners and 1px hairline '
            'borders. No shadows, no cards." These pages have already '
            'been converted:\n  ${offences.join('\n  ')}',
      );
    });

    test('the list is a ratchet, not a snapshot', () {
      // Guards against the cheapest way to make the test above pass:
      // emptying the list. If a page is genuinely deleted, the sibling
      // test's existsSync assertion says so by name.
      expect(_passed.length, greaterThanOrEqualTo(3));
      expect(_passed.toSet().length, _passed.length,
          reason: 'duplicate entries');
    });

    // 2026-08-09: [_passed] alone cannot say how much is LEFT, and that
    // turned out to matter. The brief sized #279 as "13 of 25 pages in
    // lib/pages/, 67 sites" — but the heaviest single offender in the
    // app was `lib/widgets/bible_reading_pane.dart`, which is not a page
    // and so was never counted. Scoping the pass to `lib/pages/`
    // measured the wrong population: the workbench is built of widgets.
    //
    // So the other half of the ratchet is an inventory of what has NOT
    // been converted, with a per-file CEILING. It fails three ways:
    //   * a clean file grows its first rounded corner (undeclared);
    //   * a dirty file grows more of them (over its ceiling);
    //   * a file reaches zero and is not moved to [_passed].
    // Numbers may only go down. Lower one and the test tells you to
    // write the new number, which keeps the figure honest instead of
    // letting it rot the way the brief's "67 sites" did.
    test('what is left is declared, and may only shrink', () {
      final actual = <String, int>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final n = _countOffences(_stripComments(entity.readAsStringSync()));
        if (n > 0) actual[entity.path] = n;
      }

      final undeclared = actual.keys
          .where((p) => !_remaining.containsKey(p))
          .map((p) => '$p (${actual[p]})')
          .toList()
        ..sort();
      expect(undeclared, isEmpty,
          reason: 'New rounded corners, shadows or elevation in a file '
              'the pass had left clean. Square them, or — if the surface '
              'genuinely argues for them — add the file to _remaining '
              'with a note saying why.');

      final grown = <String>[];
      final finished = <String>[];
      for (final entry in _remaining.entries) {
        final now = actual[entry.key] ?? 0;
        if (now > entry.value) {
          grown.add('${entry.key}: ${entry.value} -> $now');
        } else if (now == 0) {
          finished.add(entry.key);
        }
      }
      expect(grown, isEmpty,
          reason: 'These files got MORE unconverted chrome, not less.');
      expect(finished, isEmpty,
          reason: 'These files are clean now — move them from _remaining '
              'to _passed so they can never regress.');
    });

    test('the pass is not finished, and says so', () {
      // A guard against the inventory being quietly emptied to declare
      // victory. When #279 is genuinely done this test is the one that
      // has to be deleted, deliberately, by whoever finishes it.
      expect(_remaining, isNotEmpty);
    });
  });
}
