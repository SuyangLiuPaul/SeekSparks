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
import 'package:seeksparks/constants/workbench_theme.dart' show WbMetrics;
import 'package:seeksparks/models/app_settings.dart'
    show kFontSizeDefault, kFontSizeMax;

void main() {
  /// Literal `fontSize:` sites still in the tree, per file, as of #315.
  ///
  /// Everything absent from this map must be at zero. What is left is
  /// the classic reader pages, which #279's chrome pass owns and which
  /// have their own type story, plus a tail of small screens that each
  /// still scale their main text and write literals only around it.
  /// 2026-08-25 (#315, TWELFTH and final pass). What is left here is two
  /// entries, and NEITHER is a size the slider ought to reach. The
  /// ticket closes on documented non-defects rather than on zero,
  /// because a rule with no exceptions written down grows them silently.
  const budget = <String, int>{
    // NOT text sizes. These nine are `fontSize:` FIELDS of a style
    // preset — the value handed to `settings.setFontSize()` when the
    // reader picks "Compact" or "Large". Routing them through the
    // scale would make the presets scale themselves, which is a loop.
    // Counted here anyway so the grep stays honest: the number is
    // real, it just is not a defect.
    'models/app_style_preset.dart': 9,
    // NOT text the reader reads. The single literal is `fontSize: 36`
    // on the one-letter monogram inside a `CircleAvatar(radius: 48)` —
    // a 96 px circle that does not move with the setting, so a scaled
    // glyph would grow straight through its own disc and clip. It is
    // sized BY its container, in the same way an icon is, and it
    // carries no information the reader could not get from the account
    // name printed beside it in full.
    //
    // The honest alternative was to scale the circle too. That is a
    // layout change to a screen this ticket was not asked about, on the
    // strength of a rule about legibility that a single initial does
    // not engage. Left alone, and said out loud here so the next pass
    // does not re-derive it.
    'pages/profile_edit_page.dart': 1,
  };

  /// The surfaces #315 finished. Zero literals, and it stays zero.
  ///
  /// Named separately from the budget because these are a promise, not
  /// a debt: each is a workbench-resident pane or a screen the reader
  /// photographed, and a literal reappearing in one of them is the
  /// original bug, not new debt.
  ///
  /// **"Zero literals" is not "nothing under the floor", 2026-08-31.**
  /// `constants/word_study_style.dart` sat first on this list while
  /// resolving `translit` and `micro` to 9.0px — the smallest type in
  /// the app — because it writes its sizes as named-argument
  /// initialisers (`translit: type.chrome - 2`), read six files away as
  /// `fontSize: _st.translit`. Neither detector in this file can see
  /// that shape: one reads the argument at a `fontSize:` colon, the
  /// other a local name used at one. A style OBJECT's fields are a
  /// fourth shape and the instrument for it is a value test, not a
  /// regex — see `test/word_study_style_test.dart`, group
  /// "no field in the docked column is designed under the floor".
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
    // 2026-08-25 (#315, EIGHTH pass). The Bible Evidence resource, and
    // the pass that withdraws the claim written four lines above: that
    // `sermon_detail_page.dart` carried "the only outright inversion in
    // the app". That was measured with the LITERAL detector, so it only
    // ever looked at one of the two shapes that can invert.
    //
    // `evidence_detail_page.dart` set the artefact's own name to
    // `(fs + 6).clamp(20.0, 32.0)` above a summary, description and
    // correlation of a bare `fs`. It is the CORRECT shape — wired to
    // the setting, travelling for most of the slider — and it saturates
    // at 26 pt, after which the body walks past it: equal at 32 pt,
    // inverted at 33, and 0.80x by 40. Nine of the slider's 29 stops
    // render the name of the artefact at or below the paragraph
    // describing it. A ceiling and a literal are not two severities of
    // one bug; both freeze, and either can reverse rank.
    //
    // `evidence_page.dart` carried a second inversion with no clamp of
    // its own on the losing side. Its `ConfidenceBadge` was repaired in
    // an earlier pass of this ticket and now runs to 32 px, while the
    // card title beside it stayed frozen at 18 — so at 40 pt the word
    // "Definitive" was DOUBLE the size of the artefact it described. A
    // repair can invert a neighbour it never touched, which no
    // per-file count here can see.
    //
    // Both are measured in `evidence_font_size_behaviour_test.dart`,
    // which fails on five assertions against the commit before this one.
    'pages/evidence_detail_page.dart',
    'pages/evidence_page.dart',
    // 2026-08-25 (#315, NINTH pass). 冷知识 — the largest single item
    // left on this ticket, and the only file that appeared in all THREE
    // budgets here at once: 9 literals, 9 `WbMetrics` constants and 5
    // saturating ceilings, 23 sites in one page.
    //
    // It was budgeted on the note that it is "a game rather than a study
    // surface". That was wrong, and the note is deleted below. The page
    // renders pointed Hebrew (בְּרֵאשִׁית, אֱלֹהִים), the 22-letter
    // alphabet with romanised names, Genesis 1:1 word by word with
    // transliteration and gloss, and acrostic verse-count charts. It is
    // a study surface reached from the workbench, and every one of those
    // sizes was frozen.
    //
    // All five clamps saturated at or BELOW the app's own default of
    // 20 pt, so between 20 and 40 — half the slider's travel — nothing
    // the page sized for itself changed. (Not "nothing on the page": the
    // eleven `Text()`s here that carry no style at all did travel, off
    // the theme's scaled typography. A probe that pumps `MaterialApp`
    // without the app's own theme cannot tell the two apart.) The worst
    // of it is the pointed Hebrew:
    // frozen at 16 px, one pixel above [WbMetrics.originalFloor], whose
    // comment records that below it qamats/patach and tsere/segol are a
    // single grey smudge. A reader who dragged the slider to 40 BECAUSE
    // of the vowels got 16 px.
    //
    // The only three fontSize literals below 11 anywhere in `lib/` were
    // here — 8.0 and both instances of 10.0 — and all three are raised to
    // the floor, which is the one place this pass changes what a reader
    // at the default setting sees. They are not the smallest sizes the
    // app RENDERS: `radial_chronology_page.dart` and `originals_sheet`
    // reach 7.5 and 8 px at the default through `t.scaled(...)`, which
    // carries no floor. Those move with the slider, so this ticket's
    // detectors are right to ignore them, but they are the same
    // legibility question and are the obvious next thing to look at.
    //
    // Measured in `bible_trivia_font_size_behaviour_test.dart`, which
    // fails four of its seven tests against the commit before this one.
    // The other three pass there, and say so honestly: they guard what
    // the repair could BREAK — rank between the title, body and
    // reference, the vowel floor, and the four fixed-size containers the
    // type now outgrows. A frozen page cannot overflow.
    'pages/bible_trivia_page.dart',
    // 2026-08-25 (#315, TWELFTH pass — the residue, and the close).
    // Nine files, 32 sites, and after them both detectors read zero
    // everywhere except the two documented non-defects in the budget
    // above.
    //
    // `stats_page.dart` was the largest, 13 sites, and the one where
    // the ticket's defect had the widest blast radius: Search
    // Statistics is where a reader goes AFTER a search, so every label
    // frozen here was frozen at the moment the app was answering a
    // question. Its distribution hint carried
    // `(settings.fontSize - 3).clamp(11.0, 14.0)` — the additive-then-
    // clamped shape this ticket has now removed from the tree
    // entirely, and which cannot hold a hierarchy: 3 pt of separation
    // is a ratio of 1.27 at 11 pt and 1.08 at 40.
    //
    // `book_chapter_picker.dart` is the app's primary navigation
    // surface and the reason this pass needed more than a substitution.
    // Its verse grid had TWO `fontSize: 13` literals on `_NumberTile`
    // and hard-coded column breakpoints. Unfreezing the size alone
    // would have made it worse: unlike the book grid above it,
    // `_NumberTile` has no `FittedBox`, so an oversized label CLIPS
    // rather than shrinks — and a clipped verse number is not an ugly
    // verse number, it is a PLAUSIBLE WRONG ONE. "176" clipped reads as
    // "17". So the column count is now solved against the measured
    // widest label (`columnsThatFit`), and falls as the font rises.
    // Measured in `book_chapter_picker_font_size_behaviour_test.dart`.
    //
    // The remaining seven were saturating ceilings only, each on a
    // screen a reader meets once or rarely — first run, key entry,
    // profile switch, library, loading. They are on this list rather
    // than budgeted because "rarely" is not "never", and the onboarding
    // dialog in particular is the FIRST type the app shows a reader who
    // may have come to the settings screen looking for the slider.
    'pages/stats_page.dart',
    'widgets/book_chapter_picker.dart',
    'widgets/version_picker_sheet.dart',
    'pages/highlights_page.dart',
    'pages/library_page.dart',
    'pages/loading_page.dart',
    'pages/profiles_page.dart',
    'widgets/gemini_key_card.dart',
    'widgets/onboarding_dialog.dart',
  ];

  // 2026-08-24 (#315, SEVENTH mechanism, and a hole in this very test).
  // The detector used to be `RegExp(r'fontSize:\s*(?:const\s*)?[0-9]+')`
  // — anchored, so it only saw a number written IMMEDIATELY after the
  // colon. `fontSize: _st.dense ? _st.body : 13` is the same frozen 13
  // one token further along, and the regex was blind to it. Four such
  // sites sat inside `originals_sheet.dart` and one inside
  // `word_distribution_table.dart`, both of which this file lists as
  // FINISHED — so the ratchet was actively certifying them clean.
  //
  // The replacement reads the whole `fontSize:` expression, flattened
  // across lines and balanced to its own top-level comma, and asks
  // whether any bare number SURVIVES two removals:
  //
  //   1. the argument of a size helper — `t.scaled(13)`,
  //      `settings.smallPrint(13)`, `context.textSize(12)` and the
  //      rest all mean "13 px AT THE DEFAULT", which is the fix, not
  //      the defect;
  //   2. an arithmetic offset or factor — `settings.fontSize * 0.65`
  //      and `labelSize - 1` travel with the setting.
  //
  // What is left is a number that answers every stop of the slider with
  // itself, wherever in the expression it was hiding.
  final helperCall = RegExp(r'\b(?:scaled|scaledSmall|scaledChrome|'
      r'scaledOriginal|smallPrint|textSize|chromeSize|clamp|max|min)\s*\(');
  final offsetOrFactor = RegExp(r'[-+*/]\s*[0-9]+(?:\.[0-9]+)?');
  final bareNumber = RegExp(r'(?<![A-Za-z0-9_.])[0-9]+(?:\.[0-9]+)?');

  /// The `fontSize:` expressions in [source], as (1-based line, text).
  List<(int, String)> fontSizeExpressions(String source) {
    final lines = source.split('\n');
    final flat = source.replaceAll('\n', ' ');
    final out = <(int, String)>[];
    for (final m in RegExp(r'fontSize:\s*').allMatches(flat)) {
      final line = '\n'.allMatches(source.substring(0, m.start)).length;
      // A comment naming an old literal is documentation of the fix,
      // not the defect. `phrasing_page.dart` says "the words used to be
      // `fontSize: 17`" and that sentence should survive.
      if (lines[line].trimLeft().startsWith('//')) continue;
      var depth = 0;
      var j = m.end;
      while (j < flat.length) {
        final c = flat[j];
        if (c == '(' || c == '[' || c == '{') {
          depth++;
        } else if (c == ')' || c == ']' || c == '}') {
          if (depth == 0) break;
          depth--;
        } else if (c == ',' && depth == 0) {
          break;
        }
        j++;
      }
      out.add((line + 1, flat.substring(m.end, j).trim()));
    }
    return out;
  }

  /// [expr] with every size-helper call's arguments removed.
  String stripHelperCalls(String expr) {
    final out = StringBuffer();
    var i = 0;
    while (i < expr.length) {
      final m = helperCall.matchAsPrefix(expr, i);
      if (m != null) {
        var depth = 1;
        var j = m.end;
        while (j < expr.length && depth > 0) {
          if (expr[j] == '(') depth++;
          if (expr[j] == ')') depth--;
          j++;
        }
        out.write('SCALED');
        i = j;
        continue;
      }
      out.write(expr[i]);
      i++;
    }
    return out.toString();
  }

  bool isFrozen(String expr) =>
      bareNumber.hasMatch(stripHelperCalls(expr).replaceAll(offsetOrFactor, ''));

  List<String> frozenIn(File f) => [
        for (final (line, expr) in fontSizeExpressions(f.readAsStringSync()))
          if (isFrozen(expr)) '$line: $expr',
      ];

  int countIn(File f) => frozenIn(f).length;

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

  // 2026-08-24 (#315, SIXTH mechanism). A design constant wearing a
  // principled name. `fontSize: WbMetrics.text` looks like the fix —
  // it names the app's own type scale instead of inventing a number —
  // and it is exactly as deaf as `fontSize: 12`, because `WbMetrics` is
  // where the sizes AT THE DEFAULT are written down and `WbType` is the
  // only thing that multiplies them by the reader's setting.
  //
  // Fourteen sites. Five were the workbench's own empty states, and one
  // of those five is `_analysisHint` — the placeholder for ELEVEN
  // analysis tabs, called from thirteen places. A reader who moved the
  // slider to 40 pt because they cannot see small text was told what to
  // do next at 12 px, in every tab, before any word study existed to
  // read. That is 「还有很多界面都是」 at its most literal.
  test('no text size comes straight off WbMetrics', () {
    // Empty since 2026-08-25. The last entry was `bible_trivia_page.dart`
    // at 9, budgeted on the claim that it is "a game rather than a study
    // surface" — see the ninth-pass note in `finished` for why that was
    // wrong. `WbMetrics.chrome` is still legitimate as the ARGUMENT to
    // `t.scaledSmall(...)`, which is what those nine became; what this
    // detector forbids is the constant reaching `fontSize:` unmultiplied.
    const budget = <String, int>{};
    final metric = RegExp(r'fontSize:\s*WbMetrics\.[A-Za-z]');
    final counts = <String, int>{};
    for (final f in all) {
      final n = metric.allMatches(f.readAsStringSync()).length;
      if (n > 0) counts[f.path.substring('lib/'.length)] = n;
    }
    final over = <String>[];
    counts.forEach((rel, n) {
      if (n > (budget[rel] ?? 0)) over.add('$rel: $n (budget ${budget[rel] ?? 0})');
    });
    expect(over, isEmpty,
        reason: 'WbMetrics holds the size AT THE DEFAULT setting; only '
            'WbType multiplies it by what the reader chose. Write '
            't.text / t.chrome / t.original, or t.scaled(...) for a size '
            'this surface owns:\n${over.join('\n')}');

    final paid = <String>[];
    budget.forEach((rel, allowed) {
      final n = counts[rel] ?? 0;
      if (n < allowed) paid.add('$rel: $n, budget still says $allowed');
    });
    expect(paid, isEmpty,
        reason: 'lower these budgets:\n${paid.join('\n')}');
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
    //
    // 2026-08-24 (#315): `k` used to have to be a bare number, which
    // let a ceiling hide behind a ternary offset —
    // `(settings.fontSize - (compact ? 4 : 2)).clamp(11, 15)` in
    // `contact_line.dart` and `(… - (prominent ? 1 : 3)).clamp(10, 16)`
    // in `confidence_badge.dart` were both pinned at their own ceiling
    // at the DEFAULT setting, on both branches, and neither this
    // detector nor the literal one above could see either. The offset
    // may now be a parenthesised expression, and EVERY number in it is
    // tried: a branch that saturates is a screen where the slider is
    // dead, whatever the other branch does.
    final ceiling = RegExp(
        r'\(\s*(?:widget\.)?(?:settings\.)?(?:fontSize|(?<![A-Za-z_])fs)\s*'
        r'(?:([-+*])\s*(?:([0-9.]+)|\(([^()]*)\))\s*)?\)'
        r'\s*\.clamp\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)');
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
        //
        // 2026-08-24 (#315): "within reach" used to mean the 60
        // characters immediately before, which required the clamp to
        // sit at a `fontSize:` itself. `confidence_badge.dart` wrote
        // `final fs = (settings.fontSize - …).clamp(10, 16);` on one
        // line and `fontSize: fs` fifteen lines later, and was invisible
        // for that reason alone. A clamp bound to a local now counts if
        // that local is used as a fontSize anywhere in the same file.
        final before =
            flat.substring((m.start - 60).clamp(0, flat.length), m.start);
        // 2026-08-25 (#315, twelfth pass): the binding is asked about
        // FIRST, and a bare assignment counts as one. It used to be a
        // fallback behind `before.contains('fontSize')`, and that order
        // made the window's own contents decide. `verse_widget.dart`
        // wrote two statements in a row —
        //   `topGap = … settings.fontSize * 0.4 : 0;`
        //   `vertPadding = (settings.fontSize * 0.4).clamp(6.0, 12.0);`
        // — and the second was counted as text because the FIRST one
        // mentioned `fontSize` within 60 characters. It is padding. The
        // detector's own doc says only text is policed, so a padding
        // scored here is a false positive that would have to be bought
        // off with a budget line, which is how a real defect gets
        // filed next to a non-defect and stops being read.
        final bind = RegExp(r'(?:(?:final|var|double)\s+)?([A-Za-z_]\w*)'
                r'\s*=\s*$')
            .firstMatch(before);
        final isTextSize = bind != null
            ? RegExp('fontSize:\\s*${bind.group(1)}\\b').hasMatch(flat)
            : before.contains('fontSize');
        if (!isTextSize) continue;
        final String? op;
        final List<double?> ks;
        final double lo, hi;
        if (m.groupCount == 5) {
          op = m.group(1);
          // A parenthesised offset can hold more than one constant —
          // one per branch of a ternary. Each is a real rendering.
          ks = m.group(3) != null
              ? [
                  for (final n
                      in RegExp(r'[0-9]+(?:\.[0-9]+)?').allMatches(m.group(3)!))
                    double.parse(n.group(0)!)
                ]
              : [m.group(2) == null ? null : double.parse(m.group(2)!)];
          lo = double.parse(m.group(4)!);
          hi = double.parse(m.group(5)!);
        } else {
          op = null;
          ks = [null];
          lo = double.parse(m.group(1)!);
          hi = double.parse(m.group(2)!);
        }
        // An offset the detector cannot read any number out of tells us
        // nothing; do not guess.
        if (op != null && ks.isEmpty) continue;
        // 2026-08-25 (#315, TENTH mechanism, and a second hole in this
        // test). This used to ask `at(default) == at(max)`, which is
        // not what the test is named for. A clamp that clears the
        // default by a pixel and freezes one stop later passed:
        // `(settings.fontSize - 2).clamp(12.0, 20.0)` renders 18 at the
        // default and 20 at the max, so it "travels" — and is IDENTICAL
        // at 19 of the slider's 29 stops, everything from 22 pt up. The
        // reader who drags to 40 to read a label gets the same label a
        // reader at 22 gets.
        //
        // The question the name asks is whether the size saturates
        // ANYWHERE inside the range, and the cheapest exact form of it
        // is the top two stops: a monotonic clamp that has stopped by
        // 40 has stopped by 39. Strictly stronger than the old test —
        // if a size is equal at the default and the max it is equal at
        // every stop between — so nothing already paid for comes back.
        final dead = ks.any((k) =>
            at(kFontSizeMax - 1, op, k, lo, hi) ==
            at(kFontSizeMax, op, k, lo, hi));
        if (!dead) continue; // still travelling at the top of the slider
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
    ///
    /// 2026-08-25: the two evidence pages left, taking 11 of the
    /// remaining ceilings — the largest entry left on this list, and
    /// the pass that showed a ceiling can INVERT and not merely freeze.
    /// See the note beside them in `finished` above.
    /// 2026-08-25: `bible_trivia_page.dart` left with 5 — every one of
    /// them saturated at or below the default 20 pt, which is the worst
    /// version of this defect: the ceiling is not a limit the reader can
    /// reach, it is one they START at.
    /// 2026-08-25: the last nine went, and this map is EMPTY. From 73
    /// saturating ceilings to zero, and the detector now has no
    /// exceptions at all — any clamp whose value at 20 pt equals its
    /// value at 40 pt fails here on the day it is written.
    ///
    /// The empty map is deliberately left in place rather than deleted
    /// along with the two tests that read it. A detector with nothing
    /// left to find is exactly when it is most worth keeping.
    const known = <String, int>{};

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

  // 2026-08-25 (#315, the NINTH SHAPE — and the first one that freezes
  // nothing at all).
  //
  // Every detector above asks the same question: is there a number the
  // slider cannot move? These sites answer no. `fontSize: t.scaled(7.5)`
  // is the correct shape, wired to the setting, and it travels all 29
  // stops. What is wrong with it is the 7.5.
  //
  // [WbMetrics.smallPrintFloor] is the app's own answer to "the
  // smallest text we are willing to set", and its comment says small
  // print "may reach it and stop; it may not go under it". Thirty-six
  // sites STARTED under it — at the default setting, before the reader
  // touches anything: 7.5 px for the World History Wheel's own hint,
  // 8 px for the `Ketiv` / `Qere` and `Aramaic` badges in 原文逐字 (a
  // Ketiv/Qere badge is not decoration — it is the app saying the
  // written form and the read form differ), 10 px for the line that
  // tells a reader their AI explanation is machine-generated, 10.5 px
  // for the book-distribution chips in the Analysis pane.
  //
  // The sibling helper [WbType.scaledSmall] asserts on exactly this
  // ('raise the design size rather than relying on the floor'), so the
  // app already knew. All thirty-six routed around the assert by
  // picking the unfloored helper — which is legitimate for a SizedBox
  // and a padding, and is why `scaled()` cannot carry the assert itself.
  //
  // Two shapes, because the second hid from the first: the argument
  // written at the `fontSize:` itself, and a size bound to a name.
  // `double _axisFont(WbType t) => t.scaledChrome(10);` in
  // `chronology_page.dart` is used at two `fontSize:` sites twenty and
  // five hundred lines away, and no rule that reads the expression at
  // the colon can see the 10.
  //
  // A third shape hid from both, found 2026-08-31: an arithmetic offset
  // off a resolved `WbType` FIELD. `fontSize: t.chrome - 1` is 10 px at
  // the default Menu Size — `resolve` sets `chrome: WbMetrics.chrome *
  // chromeScale`, so the field IS the floor and anything subtracted from
  // it is under it. Fifty-two such sites were live across fifteen files
  // and this detector could not see one of them, because it reads the
  // argument of a helper call and there was no call. They are now
  // `t.chrome`, and the sibling test below forbids the notation outright.
  test('no text is designed below the app\'s own small-print floor', () {
    const floor = WbMetrics.smallPrintFloor;
    final sized = RegExp(r'\.scaled(?:Chrome|Small|Original)?\(\s*'
        r'([0-9]+(?:\.[0-9]+)?)\s*\)');
    // `double _axisFont(WbType t) => t.scaledChrome(10);` and
    // `final s = t.scaled(9.5);` — a size wearing a name.
    final bound = RegExp(r'(?:final|var|double)\s+(_?\w+)\s*'
        r'(?:\([^)]*\))?\s*(?:=>|=)\s*([^;]*)');

    final under = <String>[];
    for (final f in all) {
      final text = f.readAsStringSync();
      final rel = f.path.substring('lib/'.length);
      final lines = text.split('\n');

      void report(int line, double px, String what) => under.add(
          '$rel:$line — $what designed at ${px}px, floor is $floor');

      for (final (line, expr) in fontSizeExpressions(text)) {
        for (final m in sized.allMatches(expr)) {
          final px = double.parse(m.group(1)!);
          if (px < floor) report(line, px, expr.trim());
        }
      }
      for (final m in bound.allMatches(text)) {
        final name = m.group(1)!;
        final body = m.group(2)!;
        final line = '\n'.allMatches(text.substring(0, m.start)).length;
        if (lines[line].trimLeft().startsWith('//')) continue;
        // Only a name the file actually uses as a font size. Everything
        // else called `.scaled(4)` is a gap, an inset or a box.
        if (!RegExp('fontSize:\\s*$name\\b').hasMatch(text)) continue;
        for (final s in sized.allMatches(body)) {
          final px = double.parse(s.group(1)!);
          if (px < floor) report(line + 1, px, '$name = ${body.trim()}');
        }
      }
    }

    expect(under, isEmpty,
        reason: 'a size below WbMetrics.smallPrintFloor ($floor px) is '
            'text the app has decided it will not print, printed anyway. '
            'It is not a reach defect — it moves with the slider — so no '
            'other test here can see it. Raise the design size to the '
            'floor; the site keeps whichever scale it already used, '
            'because introducing a floored helper into a stack whose '
            'siblings are unfloored inverts their rank at the bottom of '
            'the slider:\n${under.join('\n')}');
  });

  test('no font size is written as an offset off a resolved WbType field',
      () {
    const base = {'text': 12.0, 'chrome': 11.0, 'original': 15.0};
    const floor = WbMetrics.smallPrintFloor;
    final offset =
        RegExp(r'\.(text|chrome|original)\s*([-+])\s*([0-9]+(?:\.[0-9]+)?)');

    // Additive offsets that are AT or ABOVE the floor. These are a
    // separate, weaker defect — the #315 proportion argument
    // (`WbType.scaledSmall`'s doc comment) says an additive offset does
    // not hold a type hierarchy across the slider, because `t.text + 1`
    // is a ratio of 1.08 at the default and 1.03 at 40 pt. They are NOT
    // under-floor and nothing is illegible today, so converting them to
    // `scaled(13)` is deferred rather than bundled into a floor repair.
    // Two of them (`stats_page.dart`'s `t.original + 5` / `+ 2`) are not
    // a mechanical conversion at all: `t.original` is itself FLOORED at
    // `WbMetrics.originalFloor` (workbench_theme.dart:1233-1237), so
    // `t.original + 5` and `t.scaledOriginal(20)` agree at the default
    // and diverge at the bottom of the slider. That needs its own look.
    const aboveFloorOffsets = <String, int>{
      'pages/atlas_page.dart': 2, // t.text + 3, t.text + 2
      'pages/hebrew_kings_page.dart': 1, // type.text + 5
      'pages/lexicon_page.dart': 1, // t.text + 1
      'pages/map_viewer_page.dart': 1, // t.text + 1
      'pages/naves_page.dart': 1, // t.text + 1
      'pages/stats_page.dart': 7, // 4×t.text+1/+2, 2×t.original+N
      'widgets/command_pane.dart': 1, // t.text - 1  == 11.0, at floor
      'widgets/phrase_match_pane.dart': 1, // t.text - 1  == 11.0, at floor
      'widgets/related_verses_pane.dart': 1, // t.text - 1 == 11.0, at floor
      'widgets/wb_surfaces.dart': 1, // t.text + 1
      'widgets/word_forms_section.dart': 1, // t.text + 1
    };
    expect(aboveFloorOffsets.values.fold<int>(0, (a, b) => a + b), 18,
        reason: 'the allowlist total is asserted so a future edit cannot '
            'quietly grow one entry while shrinking another');

    final chromeMinus = <String>[];
    final underFloor = <String>[];
    final surviving = <String, int>{};

    for (final f in all) {
      final rel = f.path.substring('lib/'.length);
      final text = f.readAsStringSync();
      for (final (line, expr) in fontSizeExpressions(text)) {
        for (final m in offset.allMatches(expr)) {
          final b = base[m.group(1)!]!;
          final sign = m.group(2)!;
          final n = double.parse(m.group(3)!);
          final v = sign == '-' ? b - n : b + n;
          final where = '$rel:$line — $expr (=$v px)';
          if (m.group(1) == 'chrome' && sign == '-') {
            chromeMinus.add(where);
          }
          if (v < floor) {
            underFloor.add(where);
          } else {
            surviving[rel] = (surviving[rel] ?? 0) + 1;
          }
        }
      }
    }

    expect(chromeMinus, isEmpty,
        reason: 'a size subtracted from t.chrome is a size subtracted from '
            'the floor itself — WbMetrics.smallPrintFloor IS '
            'WbMetrics.chrome, so this notation can never produce a value '
            'at or above the floor. Write `t.chrome` (or the resolved '
            'field the site already uses) with no offset:\n'
            '${chromeMinus.join('\n')}');

    expect(underFloor, isEmpty,
        reason: 'a font size written as an offset off a resolved WbType '
            'field landed below WbMetrics.smallPrintFloor ($floor px). '
            'Raise the design size to the floor, the same remedy as the '
            'sibling test above:\n${underFloor.join('\n')}');

    expect(surviving, equals(aboveFloorOffsets),
        reason: 'the surviving additive offsets (at or above the floor) '
            'no longer match the written allowlist. If you added a new '
            'one deliberately, add it to aboveFloorOffsets in this test '
            'with a comment saying why; if one disappeared, remove it '
            'from the allowlist rather than leaving debt that is already '
            'paid:\nfound: $surviving\nallowed: $aboveFloorOffsets');
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
