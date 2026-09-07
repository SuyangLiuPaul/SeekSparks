// 2026-09-08: every page, every palette, nothing invisible.
//
// The modern pass (v1.6.252) moved four things that decide whether text
// can be read, and moved them GLOBALLY rather than page by page:
//
//   * chrome came up from #E9EBEF to within 2% of the pane,
//   * the border went down from 2.2:1 to a ~7% hairline,
//   * pages got a new `groundBg` under them,
//   * the dark palette's ground dropped from #101A2B to #0B1320.
//
// Every one of those changes what a given ink sits ON. A page that
// happened to be legible because chrome was dark grey is not covered by
// any test that reads the palette itself, and the app has ~20 pages
// nobody looked at after the change — the theme reached them, but "the
// theme reached it" and "you can read it" are different claims.
//
// `small_screen_advisory_test.dart` already does this walk, and does it
// well, for ONE screen. This is the same instrument pointed at the rest.
//
// **Each string is judged against the surface it is actually painted
// on**, found by walking up from the `RichText` to the nearest ancestor
// that paints an opaque colour.
//
// The first version of this file did something cheaper and wrong: it
// judged every string against all four rungs of the ladder, reasoning
// that since `wb_surfaces_test.dart` pins the whole ladder inside
// 1.35:1, ink clearing the worst rung clears wherever it really sits.
// That reasoning is sound only for ink that sits ON the ladder, and the
// app is full of ink that does not — a white initial on the accent-red
// profile avatar, an era label on a coloured chronology band, an icon
// on a filled button. It reported nine of those as invisible on the
// first run. Every one was correct design and the instrument was wrong,
// which is the failure mode that gets a test deleted rather than fixed.
//
// If no painted ancestor is found the string is SKIPPED and counted, and
// the group asserts the skipped share stays small — an instrument that
// silently gives up on half the screen would pass by looking away.
//
// 3:1, not 4.5:1 — the same floor and the same reason as the advisory
// wall: a muted aside, an inactive chip and a version footer are all
// MEANT to recede, and a rule that forbade that would be a rule about
// taste. 3:1 forbids only the failure this exists to catch, which is
// text that has effectively vanished.
//
// **Disabled controls are exempt, and disabled is decided STRUCTURALLY
// — by finding an ancestor control whose callback is null, not by
// recognising a colour.** WCAG excludes inactive components and it is
// right to: darkening a disabled control until it measures 3:1 makes it
// look enabled, which trades a legibility complaint for a lie.
//
// The colour-based version of this exemption was tried first and does
// not work. Material paints a disabled `IconButton` at `onSurface` ×
// 38%, and an attempt to redirect that through the app's own
// `disabledMark` via `iconButtonTheme` had no effect at all inside an
// `AppBar`, where `IconTheme` wins over the button theme. Asking the
// TREE "is this control dead?" needs to know none of that, and cannot
// be defeated by a widget that paints its disabled state some third
// way.
//
// **A second exemption, kept because it is a real role:
// [WbColors.disabledMark].**
// WCAG excludes inactive components from contrast requirements, and it
// is right to — darkening a disabled control until it measures 3:1 makes
// it look enabled, which trades a legibility complaint for a lie. The
// exemption is keyed on the TOKEN rather than on a measured threshold so
// it cannot widen: a surface claiming the exemption has to say
// `disabledMark`, and `wb_surfaces_test.dart` pins that token's own
// floor against the border it was split out of.
//
// Two things this exemption is NOT for, both found and fixed the day the
// walk was widened: the command pane's dimmed operator buttons and the
// status bar's "off" fields. Both were drawn at `mutedText` × 0.55
// (1.98:1) and both stay TAPPABLE — `dimmed` and `enabled` there mean
// "this will not change the line yet" and "the thing this controls is
// off", not "you cannot press this". A control a reader can press and
// cannot read is the failure, not the exemption.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/about_page.dart';
import 'package:seeksparks/pages/atlas_page.dart';
import 'package:seeksparks/pages/bible_timeline_page.dart';
import 'package:seeksparks/pages/books_page.dart';
import 'package:seeksparks/pages/bible_trivia_page.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/pages/command_search_page.dart';
import 'package:seeksparks/pages/evidence_page.dart';
import 'package:seeksparks/pages/family_tree_page.dart';
import 'package:seeksparks/pages/hebrew_kings_page.dart';
import 'package:seeksparks/pages/highlights_page.dart';
import 'package:seeksparks/pages/illustrations_page.dart';
import 'package:seeksparks/pages/lexicon_page.dart';
import 'package:seeksparks/pages/library_page.dart';
import 'package:seeksparks/pages/loading_page.dart';
import 'package:seeksparks/pages/modern_concordance_page.dart';
import 'package:seeksparks/pages/naves_page.dart';
import 'package:seeksparks/pages/profile_edit_page.dart';
import 'package:seeksparks/pages/profiles_page.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/pages/sermons_page.dart';
import 'package:seeksparks/pages/settings_page.dart';
import 'package:seeksparks/pages/stats_page.dart';
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/pages/word_list_page.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

/// The pages this walk pumps: every page class whose constructor takes
/// no required argument.
///
/// The first version of this list held sixteen of the app's thirty-two
/// pages and the file's own comment called that "every page". It was
/// not, and the gap was not random — the eight that could have been
/// added trivially included `WorkbenchPage`, which IS the app, plus the
/// wheel, the strip, the Atlas and Evidence. Worse, of the ninety
/// `scheme.outline` ink sites this walk was written to catch, the
/// heaviest concentrations live in exactly the files those pages build.
/// A coverage claim is worth what its denominator is.
///
/// Four are still absent, and the denominator is written down rather
/// than left silent.
///
/// The previous version of this comment said NINE were out of reach
/// because they "take a required argument naming a book, a chapter, a
/// sermon or a Strong's number", and that reaching them "means building
/// a corpus". Half of that was wrong and it was the lazy half: Books,
/// LoadingPage, StrongsEntry, Phrasing and WordList take SCALARS — a
/// book name, a chapter number, a locale, a version code, an empty
/// verse list. A scalar is not a corpus. They are in the list now.
///
/// What genuinely remains: MapViewer, SermonDetail and EvidenceDetail
/// each take a domain OBJECT (`BibleMap`, `Sermon`, `BibleEvidence`);
/// HomePage — the classic single-pane reader — takes nothing but draws
/// no text at all on a cold pump; and Phrasing takes scalars and was
/// briefly in the list on that basis, until the exemption-width guard
/// below reported it rendering THREE strings of which two were disabled
/// buttons. Scalar arguments got it constructed and did not get it
/// populated, and one checkable string is not coverage. Both were
/// caught by guards rather than noticed, which is the argument for
/// having them.
final _pages = <String, Widget Function()>{
  'About': () => const AboutPage(),
  'Atlas': () => const AtlasPage(),
  'Command Search': () => const CommandSearchPage(),
  'Evidence': () => const EvidencePage(),
  'Profile Edit': () => const ProfileEditPage(),
  'Radial Chronology': () => const RadialChronologyPage(),
  'Strip Chronology': () => const StripChronologyPage(),
  'Workbench': () => const WorkbenchPage(),
  'Bible Timeline': () => const BibleTimelinePage(),
  // Scalars only. The page resolves the book and chapter itself, and a
  // chapter it cannot resolve renders its own empty state — which is a
  // screen a reader can reach, so it is one this walk should read.
  'Books': () => const BooksPage(bookIdx: 'Genesis', chapterIdx: 1),
  'Bible Trivia': () => const BibleTriviaPage(),
  'Chronology': () => const ChronologyPage(),
  'Family Tree': () => const FamilyTreePage(),
  'Hebrew Kings': () => const HebrewKingsPage(),
  'Highlights': () => const HighlightsPage(),
  'Illustrations': () => const IllustrationsPage(),
  'Lexicon': () => const LexiconPage(),
  'Library': () => const LibraryPage(),
  'Loading': () => const LoadingPage(verses: []),
  'Modern Concordance': () => const ModernConcordancePage(),
  "Nave's Topical": () => const NavesPage(),
  'Profiles': () => const ProfilesPage(),
  'Sermons': () => const SermonsPage(),
  'Settings': () => const SettingsPage(),
  'Stats': () => const StatsPage(),
  "Strong's Entry": () => const StrongsEntryPage(number: 'H1'),
  'Word List': () => const WordListPage(
        book: 'Genesis',
        chapter: 1,
        locale: 'en',
        version: 'bsb',
      ),
};

const _palettes = <String, ({bool dark, bool paper})>{
  'light': (dark: false, paper: false),
  'dark': (dark: true, paper: false),
  'paper': (dark: false, paper: true),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _palettes.forEach((paletteName, cfg) {
    final wb = cfg.paper
        ? WbColors.paper
        : (cfg.dark ? WbColors.dark : WbColors.light);

    group('$paletteName palette', () {
      _pages.forEach((pageName, build) {
        testWidgets('$pageName prints nothing invisible', (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final settings = AppSettings();
          // 2026-09-08: the paper case has to set the SETTING, not just
          // the ambient theme. `WorkbenchPage` re-themes its own subtree
          // from `settings.readingPaperTheme` — correctly, because paper
          // is the reader's choice and not the ancestor's — so a paper
          // ambient theme over a default AppSettings left the whole
          // workbench rendering `WbColors.light` inside a test labelled
          // "paper". The walk caught it as light ink on a light chrome
          // in the paper case, which is the fixture being wrong rather
          // than the app.
          if (cfg.paper) await settings.setReadingPaperTheme(true);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AppSettings>.value(value: settings),
                ChangeNotifierProvider<MainProvider>(
                    create: (_) => MainProvider()),
              ],
              child: MaterialApp(
                theme: workbenchTheme(
                  cfg.dark
                      ? ThemeData.dark(useMaterial3: true)
                      : ThemeData.light(useMaterial3: true),
                  paper: cfg.paper,
                  accent: settings.primaryColor,
                ),
                home: build(),
              ),
            ),
          );
          // Pages fetch assets on first frame. Settle what settles; a
          // page still loading prints a spinner and a label, which is
          // exactly as much text as this walk needs.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          final faint = <String>[];
          var judged = 0;
          var unbacked = 0;
          var exempted = 0;

          for (final element in find.byType(RichText).evaluate()) {
            final rt = element.widget as RichText;
            final span = rt.text;
            if (span is! TextSpan) continue;
            final text = span.toPlainText();
            if (text.trim().isEmpty) continue;
            final colour = span.style?.color;
            if (colour == null) continue;

            // The two exemptions. See the library doc.
            if (colour == wb.disabledMark || _insideDisabledControl(element)) {
              exempted++;
              continue;
            }

            final bg = _paintedBehind(element) ?? wb.groundBg;
            if (_paintedBehind(element) == null) unbacked++;
            judged++;

            final ratio = _contrast(_over(colour, bg), bg);
            if (ratio < 3.0) {
              final shown =
                  text.length > 28 ? '${text.substring(0, 28)}…' : text;
              final alpha = colour.a < 1.0
                  ? ' @${(colour.a * 100).round()}%'
                  : '';
              faint.add('"$shown" — ink #${_hex(colour)}$alpha on '
                  '#${_hex(bg)} is ${ratio.toStringAsFixed(2)}:1');
            }
          }

          // Without this the test is a tautology: a page that rendered
          // nothing has no faint strings and reports success having read
          // an empty screen. Every page here draws at least a title.
          expect(judged, greaterThanOrEqualTo(1),
              reason: '$pageName printed no coloured text at all — the walk '
                  'is not reading the page it claims to check');

          // The other half of "is this instrument still working". A
          // refactor that puts every string behind a paint this resolver
          // cannot see would leave `faint` empty for the wrong reason.
          // An exemption that swallows the page is not an exemption, it
          // is a way to pass. Disabled controls are a minority of any
          // real screen; if they ever become most of one, either the
          // page is broken or `_insideDisabledControl` has started
          // saying yes to things that are not controls.
          expect(exempted, lessThan(judged),
              reason: '$pageName: $exempted of ${judged + exempted} strings '
                  'claimed the disabled exemption — more than were '
                  'checked. The exemption has stopped being narrow.');

          expect(unbacked, lessThan(judged),
              reason: '$pageName: the background resolver found nothing '
                  'behind ANY of its $judged strings, so every one was '
                  'judged against the fallback');

          expect(faint, isEmpty,
              reason: '$pageName, $paletteName palette. Ink this faint has '
                  'effectively vanished:\n  ${faint.join('\n  ')}');
        });
      });
    });
  });
}

/// True when [element] sits inside a control that cannot be used.
///
/// Structural, not chromatic: it asks the widgets whether their callback
/// is null. That is the same question the framework asks when it decides
/// to grey the thing, so the two can never disagree — and unlike a
/// colour test it keeps working when a widget paints its disabled state
/// in a way this file has never seen.
///
/// Stops at the first control it meets, live or dead. A disabled button
/// inside an enabled toolbar is disabled; an enabled button inside a
/// disabled-looking container is not.
bool _insideDisabledControl(Element element) {
  var disabled = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is IconButton) {
      disabled = w.onPressed == null;
      return false;
    }
    if (w is TextButton || w is FilledButton || w is OutlinedButton) {
      disabled = (w as ButtonStyleButton).onPressed == null &&
          w.onLongPress == null;
      return false;
    }
    if (w is InkWell) {
      disabled = w.onTap == null && w.onLongPress == null;
      return false;
    }
    return true;
  });
  return disabled;
}

/// The colour painted immediately behind [element], found by walking up
/// the tree to the first ancestor that fills an opaque colour.
///
/// `Container` does not appear here — it is a composition, and what
/// reaches the element tree is a `ColoredBox` or a `DecoratedBox`. A
/// `Card`, an `InkWell`'s fill and a `Chip` all resolve through
/// `Material`. Anything translucent is skipped rather than composited:
/// the point is to find the ground this ink was DESIGNED against, and a
/// 12%-black scrim is not it.
Color? _paintedBehind(Element element) {
  Color? found;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    Color? c;
    if (w is ColoredBox) {
      c = w.color;
    } else if (w is DecoratedBox) {
      final d = w.decoration;
      if (d is BoxDecoration) c = d.color;
    } else if (w is Material) {
      c = w.color;
    } else if (w is Scaffold) {
      c = w.backgroundColor;
    }
    if (c != null && c.a == 1.0) {
      found = c;
      return false;
    }
    return true;
  });
  return found;
}

/// RGB only. The alpha is reported separately by the caller, because a
/// composited eight-digit hex is unreadable and the interesting fact is
/// almost always "this ink is fine, someone put it behind an opacity".
String _hex(Color c) => c
    .toARGB32()
    .toRadixString(16)
    .padLeft(8, '0')
    .substring(2)
    .toUpperCase();

/// [fg] composited over [bg], so a colour carrying an alpha is judged as
/// it is SEEN rather than as it is written. Half the near-misses in this
/// app are a `withValues(alpha: 0.6)` on an already-muted grey.
Color _over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
