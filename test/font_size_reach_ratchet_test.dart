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
// A literal is invisible to a widget test: a `TextStyle` assertion
// passes whether the number came from the setting or from thin air, and
// the number IS real — it simply never moves. Only the source can say
// which.
//
// 2026-08-24 (#315): that paragraph used to end "the defect is invisible
// to a widget test", and the fourth mechanism found that day was the
// exact converse — `workbenchTheme` sizing every Material role from
// constants, which no source rule at a call site could see and which a
// widget test found in one pump. Neither instrument dominates the
// other; `test/theme_font_size_behaviour_test.dart` is the other half.
//
// 2026-08-24 (#315), and a third instrument. The FIFTH mechanism is
// invisible to both of the first two: `book_chapter_picker.dart` wrote
// `fontSize: settings.fontSize * 1.15`, which is the correct shape and
// moves at every stop, inside a `FittedBox` inside a grid cell sized
// from the MENU scale. The declared size travelled the whole slider
// and the painted glyph was `cellWidth / labelEmWidth`, a constant —
// `Jonah` measured 44.0 px wide at 20 pt and 44.0 px at 40 pt. A
// source rule sees nothing wrong, and a widget test that reads
// `RichText.text.style.fontSize` reads the DECLARED size and agrees
// with the lie. Only the PAINTED rect separates them, because
// `tester.getRect` resolves through `localToGlobal` and so through the
// fit's transform where `tester.getSize` does not.
// `test/fitted_label_reach_test.dart` is that third instrument.
//
// So: the count per file may go DOWN, never UP. A new screen written
// with hardcoded sizes fails here on the day it is written, instead of
// being found in a photograph two months later.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/app_settings.dart'
    show kFontSizeDefault, kFontSizeMax;

void main() {
  /// Literal `fontSize:` sites still in the tree, per file, as of #315.
  ///
  /// Everything absent from this map must be at zero. What is left is
  /// the classic reader pages, which #279's chrome pass owns and which
  /// have their own type story, plus a tail of small screens that each
  /// still scale their main text and write literals only around it.
  const budget = <String, int>{
    'pages/stats_page.dart': 12,
    // NOT text sizes. These nine are `fontSize:` FIELDS of a style
    // preset — the value handed to `settings.setFontSize()` when the
    // reader picks "Compact" or "Large". Routing them through the
    // scale would make the presets scale themselves, which is a loop.
    // Counted here anyway so the grep stays honest: the number is
    // real, it just is not a defect.
    'models/app_style_preset.dart': 9,
    'pages/bible_trivia_page.dart': 9,
    'pages/evidence_page.dart': 5,
    'widgets/book_chapter_picker.dart': 2,
    'widgets/version_picker_sheet.dart': 2,
    'pages/evidence_detail_page.dart': 1,
    'pages/profile_edit_page.dart': 1,
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
    // 2026-08-17 (#316). Paid off while fixing the rotate advisory, and
    // it belongs on THIS list rather than in the budget: the reader
    // photographed it, and it is the one screen whose only control is
    // the language switch — the literal that lived here sized the three
    // labels a reader stopped by a hard gate has to be able to read.
    'widgets/small_screen_advisory.dart',
    'widgets/verse_list_pane.dart',
    'widgets/word_analysis_pane.dart',
    'widgets/word_distribution.dart',
    'widgets/word_distribution_table.dart',
    // 2026-08-17 (#315). The eight surfaces where the Font Size slider
    // moved NOTHING AT ALL — not the body text, not the labels. Every
    // other entry in the budget above scales its main text and writes
    // literals only around it; on these the setting was inert end to
    // end, which is a different and worse thing, and it is what the
    // reader meant by 「还有很多界面都是」.
    //
    // They are a promise rather than a debt: all but one are reachable
    // in a tap or two from a menu or the workbench toolbar, and the
    // About page additionally carries the MorphGNT / OSHB / Eagle's
    // View attributions, where legibility is a licence obligation and
    // not a comfort.
    'pages/about_page.dart',
    'pages/bible_timeline_page.dart',
    'pages/family_tree_page.dart',
    'utils/floating_toast.dart',
    'widgets/collapsible_english_ref.dart',
    'widgets/copy_center_sheet.dart',
    // The exception, said out loud rather than implied: the modal
    // sheet's only caller is `_showHighlightsSheet`, which carries
    // `// ignore: unused_element` — the floating header opens
    // `HighlightsPage` instead. Converted anyway because the file is
    // still compiled and still on the list of things a reader could be
    // shown; NOT screenshot-verified, because there is no way in.
    'widgets/highlights_sheet.dart',
    'widgets/person_detail_sheet.dart',
    // 2026-08-24 (#315, third mechanism). The reader itself — the
    // surface the app is for. 41 literals and 10 saturating ceilings
    // (plus one clamped line height, which no test below polices),
    // routed through `_ReaderTypeScale`, which is also where the
    // text-vs-chrome decision for this file is written down.
    'widgets/bible_reading_pane.dart',
    // 2026-08-24 (#315). The page the slider itself lives on. Its five
    // literals were the export and import dialogs — the JSON viewer,
    // the size label, the parse error and the "found N highlights"
    // summary — which is the one flow in the app that moves a reader's
    // own work between devices, and the last place to set 11 px and
    // hope.
    'pages/settings_page.dart',
    // 2026-08-24 (#315). The four surfaces that mix a SCALED body with
    // frozen furniture, which is the ticket's defect in its sharpest
    // form: a literal beside a scaled size does not merely fail to
    // grow, it changes RANK. `sermon_detail_page.dart` carried the only
    // outright inversion in the app — the sermon's own title was the
    // literal 22 over a body of `settings.fontSize`, so it led the page
    // at the default and was SMALLER than the sermon from 23 pt on,
    // stop 12 of the slider's 29. Proven by measurement, not by source:
    // `sermon_font_size_behaviour_test.dart` fails at exactly 24 pt
    // against the commit before the fix.
    //
    // `strongs_entry_page.dart` is on this list for a second reason.
    // Its `_RelatedChip` sets a LEMMA — accented Greek, pointed Hebrew
    // — at 13 px, two under [WbMetrics.originalFloor], at the DEFAULT
    // setting. That is not a reach defect at all; it is the app
    // printing diacritics below the size it decided they survive at,
    // and no amount of scaling would have found it.
    'pages/sermon_detail_page.dart',
    'pages/strongs_entry_page.dart',
    'widgets/note_reference_picker_sheet.dart',
    'widgets/verse_popup_sheet.dart',
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

  // 2026-08-24 (#315, second mechanism) — RETIRED the same day, by
  // fixing what it was working around.
  //
  // A test called 'no Material role is used at its fixed size' stood
  // here. It forbade `theme.textTheme.bodySmall` and the twelve roles
  // like it, on the grounds that `main.dart` rewired only three roles
  // from `settings.fontSize` and every other role was a fixed number
  // wearing a name. That was true, and it caught seven real sites in
  // `small_screen_advisory.dart` and `analysis_tabs.dart`.
  //
  // It was also a rule against a symptom. The roles were fixed because
  // `workbenchTheme` — the app's ONLY theme — sized them from constants
  // and threw the caller's `textTheme` away; the three "rewired" roles
  // were overwritten one line after they were set, so in truth all
  // fifteen were deaf, not twelve. `workbenchTheme` now takes the
  // reader's scale and puts every role on it, which makes a bare
  // `theme.textTheme.bodySmall` the CORRECT thing to write and this
  // test a rule against correct code. Its escape hatch, `scaleRole`, is
  // gone for the same reason: it would now square the scale.
  //
  // What replaces it is below, and it guards the one seam the root fix
  // opened: `textScale` defaults to 1.0, so a call site that forgets to
  // pass it re-creates the whole defect silently and locally.
  test('every workbenchTheme call passes the reader\'s scale', () {
    final deaf = <String>[];
    for (final f in all) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (!lines[i].contains('workbenchTheme(')) continue;
        // The declaration itself, not a call.
        if (lines[i].contains('ThemeData workbenchTheme(')) continue;
        final window =
            lines.sublist(i, (i + 4).clamp(0, lines.length)).join(' ');
        if (window.contains('textScale:')) continue;
        deaf.add('${f.path}:${i + 1}');
      }
    }
    expect(deaf, isEmpty,
        reason: 'workbenchTheme(textScale:) defaults to 1.0, which pins '
            'every Material text size in that subtree to its design value '
            'and makes the Font Size slider do nothing there. Pass '
            'WbType.of(context).textScale, or WbType.scaleFor(fontSize) '
            'where there is no WbType above you:\n${deaf.join('\n')}');
  });

  // 2026-08-24 (#315, third mechanism). A CLAMP is the third way to
  // write a size the slider cannot move, and the most deceptive of the
  // three: `fontSize: (settings.fontSize - 2).clamp(11.0, 14.0)` reads
  // as wired, compiles as wired, and reviews as wired. It is deaf from
  // 16 pt upward, which is BELOW the app's own default of 20 — so the
  // reader's entire upper range, 21 of the slider's 29 stops, moves it
  // nothing. Neither of the two tests above can see it: there is no
  // literal and no Material role.
  //
  // Measured by THIS detector at the commit before the repair: 80
  // ceilings fed by the reader's font size, of which 73 were already
  // saturated at the default. (An earlier three-line-window heuristic
  // said 73/59; it could not see a clamp that wrapped across lines, so
  // those were its reach, not the defect's size.) That is the general
  // case behind 「还有很多界面都是」.
  //
  // Only TEXT is policed. An icon or a box fed through the same clamp
  // is the same shape of bug, but a reader cannot fail to read an icon
  // that stopped growing, and raising a box changes layout rather than
  // legibility. Named here so the omission is a decision, not an
  // oversight.
  test('no text size saturates inside the slider\'s own range', () {
    // `(fontSize ± k).clamp(lo, hi)` and the bare `fontSize.clamp(…)`.
    final ceiling = RegExp(
        r'\(\s*(?:widget\.)?(?:settings\.)?(?:fontSize|(?<![A-Za-z_])fs)\s*'
        r'(?:([-+*])\s*([0-9.]+)\s*)?\)\s*\.clamp\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)');
    final bare = RegExp(
        r'(?:widget\.)?(?:settings\.)?(?:fontSize|(?<![A-Za-z_])fs)'
        r'\.clamp\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)');

    /// The value the site renders at a given setting.
    double at(double fontSize, String? op, double? k, double lo, double hi) {
      var v = fontSize;
      if (op == '-') v = fontSize - k!;
      if (op == '+') v = fontSize + k!;
      if (op == '*') v = fontSize * k!;
      return v.clamp(lo, hi).toDouble();
    }

    final saturated = <String, List<String>>{};
    for (final f in all) {
      final text = f.readAsStringSync();
      // A local `fs` only counts where the file actually assigns it
      // from the setting; plenty of other things are called fs.
      if (!text.contains('fontSize')) continue;
      // Newline → space preserves every offset, so a match found in the
      // flattened text still points at the right line.
      final flat = text.replaceAll('\n', ' ');
      final lines = text.split('\n');
      for (final m in [...ceiling.allMatches(flat), ...bare.allMatches(flat)]) {
        final line = '\n'.allMatches(text.substring(0, m.start)).length;
        if (lines[line].trimLeft().startsWith('//')) continue;
        // Text only: the assignment or the argument must name a font
        // size within reach of the match.
        final before = flat.substring((m.start - 60).clamp(0, flat.length), m.start);
        if (!before.contains('fontSize')) continue;
        final g = m.groupCount == 4
            ? [m.group(1), m.group(2), m.group(3)!, m.group(4)!]
            : [null, null, m.group(1)!, m.group(2)!];
        final op = g[0];
        final k = g[1] == null ? null : double.parse(g[1]!);
        final lo = double.parse(g[2]!);
        final hi = double.parse(g[3]!);
        if (at(kFontSizeDefault, op, k, lo, hi) !=
            at(kFontSizeMax, op, k, lo, hi)) {
          continue; // still travelling somewhere above the default
        }
        (saturated[f.path.substring('lib/'.length)] ??= [])
            .add('${line + 1}: ${m.group(0)}');
      }
    }

    /// What was saturated when the detector was written, per file.
    ///
    /// Every one of these is the reported defect at a different
    /// address. They are budgeted rather than fixed in one pass
    /// because raising a size that has been frozen for years changes
    /// what fits on the row beneath it, and that has to be looked at
    /// screen by screen. The number may go DOWN.
    ///
    /// 2026-08-24: `settings_page.dart` left this list, and it was 28
    /// of the 73 — the largest entry, on the page where the reader can
    /// see the slider and its effect at the same time. Its repair
    /// answered a question this budget does not ask: a clamp has TWO
    /// bounds, and the FLOOR was doing real work. Removing it would put
    /// a hint at 7.8 px for a reader who set 12 pt. The other entries
    /// should take the same route — [WbType.scaledSmall], which keeps
    /// the floor as one shared number and drops only the ceiling.
    ///
    /// 2026-08-24: three more went that way. `sidebar_panel.dart` and
    /// `version_picker_sheet.dart` are gone from the list entirely, and
    /// `loading_page.dart` dropped one. The two that emptied were the
    /// widest-saturating of the set — `.clamp(12, 15)` answered 26 of
    /// the slider's 29 stops with the same number.
    const known = <String, int>{
      'pages/bible_trivia_page.dart': 5,
      'pages/evidence_detail_page.dart': 3,
      'pages/evidence_page.dart': 8,
      'pages/highlights_page.dart': 1,
      'pages/library_page.dart': 2,
      'pages/loading_page.dart': 3,
      'pages/profile_edit_page.dart': 1,
      'pages/profiles_page.dart': 1,
      'pages/stats_page.dart': 1,
      'widgets/book_chapter_picker.dart': 2,
      'widgets/gemini_key_card.dart': 4,
      'widgets/onboarding_dialog.dart': 1,
    };

    final over = <String>[];
    saturated.forEach((rel, sites) {
      final allowed = known[rel] ?? 0;
      if (sites.length > allowed) {
        over.add('$rel: ${sites.length} (budget $allowed)\n    '
            '${sites.join('\n    ')}');
      }
    });
    expect(over, isEmpty,
        reason: 'a ceiling below the slider\'s reach is a size the reader '
            'cannot change. Take the value the site has at the default '
            '(${kFontSizeDefault.toStringAsFixed(0)} pt) and put it on the '
            'scale — WbType.scaledSmall() keeps the clamp\'s floor and '
            'drops its ceiling, scaled() for text the reader reads, '
            'scaledChrome() for furniture with its own slider:\n'
            '${over.join('\n')}');

    final paid = <String>[];
    known.forEach((rel, allowed) {
      final n = saturated[rel]?.length ?? 0;
      if (n < allowed) paid.add('$rel: $n, budget still says $allowed');
    });
    expect(paid, isEmpty,
        reason: 'lower these budgets to what the files now contain:\n'
            '${paid.join('\n')}');
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
