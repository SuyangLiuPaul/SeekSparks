// 2026-08-11 (task #315): a ratchet on how far the reader's Font Size
// actually reaches.
//
// #311 fixed the ARITHMETIC — every stop of the slider now moves
// `WbType`. It did not fix the REACH: 263 `fontSize:` literals were
// still written into widget trees, and a literal is by construction a
// size that never changes, whatever the reader sets. The user's report
// was two photographs of 詞彙表 and 語法分行 at 12 pt with
// 「这些字很难看清楚还有很多界面都是」 — the last four words being the
// whole problem: it was not one screen.
//
// This is a source ratchet, not a behaviour test, and deliberately so.
// The defect is invisible to a widget test: a `TextStyle` assertion
// passes whether the number came from the setting or from thin air, and
// the number IS real — it simply never moves. Only the source can say
// which.
//
// So: the count per file may go DOWN, never UP. A new screen written
// with hardcoded sizes fails here on the day it is written, instead of
// being found in a photograph two months later.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Literal `fontSize:` sites still in the tree, per file, as of #315.
  ///
  /// Everything absent from this map must be at zero. The residue is
  /// the classic reader pages, which #279's chrome pass owns and which
  /// have their own type story; the workbench, the word study in both
  /// its presentations, and the two screens in the photographs are the
  /// slice #315 finished.
  const budget = <String, int>{
    // The verse text here already scales; these 41 are the chrome
    // around it (verse numbers, note markers, the version tag), and
    // #279's pass is mid-file. Splitting the file between two tasks is
    // how a merge conflict becomes a silent style regression.
    'widgets/bible_reading_pane.dart': 41,
    'pages/about_page.dart': 13,
    'pages/family_tree_page.dart': 12,
    'pages/stats_page.dart': 12,
    'widgets/copy_center_sheet.dart': 12,
    // NOT text sizes. These nine are `fontSize:` FIELDS of a style
    // preset — the value handed to `settings.setFontSize()` when the
    // reader picks "Compact" or "Large". Routing them through the
    // scale would make the presets scale themselves, which is a loop.
    // Counted here anyway so the grep stays honest: the number is
    // real, it just is not a defect.
    'models/app_style_preset.dart': 9,
    'pages/bible_trivia_page.dart': 9,
    'widgets/person_detail_sheet.dart': 8,
    'pages/strongs_entry_page.dart': 7,
    'pages/bible_timeline_page.dart': 6,
    'pages/sermon_detail_page.dart': 6,
    'pages/evidence_page.dart': 5,
    'pages/settings_page.dart': 5,
    'widgets/highlights_sheet.dart': 5,
    'widgets/book_chapter_picker.dart': 2,
    'widgets/verse_popup_sheet.dart': 2,
    'widgets/version_picker_sheet.dart': 2,
    'pages/evidence_detail_page.dart': 1,
    'pages/profile_edit_page.dart': 1,
    'utils/floating_toast.dart': 1,
    'widgets/collapsible_english_ref.dart': 1,
    'widgets/note_reference_picker_sheet.dart': 1,
    'widgets/small_screen_advisory.dart': 1,
  };

  /// The surfaces #315 finished. Zero literals, and it stays zero.
  ///
  /// Named separately from the budget because these are a promise, not
  /// a debt: each is a workbench-resident pane or a screen the reader
  /// photographed, and a literal reappearing in one of them is the
  /// original bug, not new debt.
  const finished = <String>[
    'constants/word_study_style.dart',
    'pages/phrasing_page.dart',
    'pages/sermons_page.dart',
    'pages/word_list_page.dart',
    'widgets/analysis_tabs.dart',
    'widgets/command_pane.dart',
    'widgets/context_pane.dart',
    'widgets/originals_sheet.dart',
    'widgets/verse_list_pane.dart',
    'widgets/word_analysis_pane.dart',
    'widgets/word_distribution.dart',
    'widgets/word_distribution_table.dart',
  ];

  final literal = RegExp(r'fontSize:\s*(?:const\s*)?[0-9]+(?:\.[0-9]+)?\b');

  int countIn(File f) {
    var n = 0;
    for (final line in f.readAsLinesSync()) {
      // A comment naming an old literal is documentation of the fix,
      // not the defect. `phrasing_page.dart` says "the words used to be
      // `fontSize: 17`" and that sentence should survive.
      if (line.trimLeft().startsWith('//')) continue;
      n += literal.allMatches(line).length;
    }
    return n;
  }

  final all = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the tree under test is the one we think it is', () {
    expect(all.length, greaterThan(100));
    for (final rel in [...budget.keys, ...finished]) {
      expect(File('lib/$rel').existsSync(), isTrue,
          reason: 'lib/$rel is in the ratchet but not on disk — if it was '
              'renamed or deleted, update this list in the same commit');
    }
  });

  test('no file carries more hardcoded sizes than its budget', () {
    final over = <String>[];
    for (final f in all) {
      final rel = f.path.substring('lib/'.length);
      final n = countIn(f);
      final allowed = budget[rel] ?? 0;
      if (n > allowed) over.add('$rel: $n (budget $allowed)');
    }
    expect(over, isEmpty,
        reason: 'a hardcoded fontSize is a size the reader\'s Font Size '
            'setting cannot move. Route it through WbType — t.scaled() for '
            'reading text, t.scaledChrome() for frame furniture, '
            't.scaledOriginal() for Hebrew and Greek:\n${over.join('\n')}');
  });

  test('the surfaces #315 finished stay finished', () {
    final regressed = <String>[];
    for (final rel in finished) {
      final n = countIn(File('lib/$rel'));
      if (n > 0) regressed.add('$rel: $n');
    }
    expect(regressed, isEmpty,
        reason: 'these panes were routed through WbType by #315; a literal '
            'here is the reported defect coming back:\n'
            '${regressed.join('\n')}');
  });

  test('the budget itself is not stale', () {
    // A budget entry that is already at zero is debt someone paid and
    // forgot to book. Left in place it hides the next regression in
    // that file, because the ratchet would allow it back.
    final paid = <String>[];
    budget.forEach((rel, allowed) {
      final n = countIn(File('lib/$rel'));
      if (n < allowed) paid.add('$rel: $n, budget still says $allowed');
    });
    expect(paid, isEmpty,
        reason: 'lower these budgets to what the files now contain, or move '
            'the file to `finished`:\n${paid.join('\n')}');
  });

  test('the originals floor is single-sourced, not repeated per page', () {
    // Two pages measured the same threshold independently and happened
    // to agree on 15. If a future page picks 14 "because the help says
    // 12–14 pt", the app states a different vowel than the text has in
    // one pane and not another. One constant, referenced.
    final theme = File('lib/constants/workbench_theme.dart').readAsStringSync();
    expect(theme, contains('static const double originalFloor'));
    expect(File('lib/pages/phrasing_page.dart').readAsStringSync(),
        contains('WbMetrics.original'));
  });
}
