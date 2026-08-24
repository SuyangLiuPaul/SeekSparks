/// 2026-08 (SeekSparks): the Workbench's own dense desktop theme.
///
/// The rest of SeekSparks is a touch-first reading app — rounded cards,
/// generous padding, a purple Material 3 palette. That is right for a
/// phone and wrong for this workspace: BibleWorks is a *dense, flat,
/// neutral, keyboard-driven desktop tool*, and putting its three windows
/// inside Material 3 chrome produced something that read as "a mobile
/// app in three columns" rather than as BibleWorks.
///
/// So the Workbench gets its own [ThemeData], applied to that subtree
/// only. Nothing here leaks into the phone reader.
///
/// The rules this encodes, taken from BibleWorks 10:
///   * ~12px body text on a ~1.3 line height — roughly half the vertical
///     space per line that the reading app uses.
///   * Square corners and 1px hairline borders. No shadows, no cards.
///   * A neutral ground. The ONLY saturated colour in the whole window
///     is the per-version tag and the blue of a clickable reference —
///     which is exactly why those read as information rather than
///     decoration.
///   * Chrome (menu bar, pane titles, status bar) one step smaller
///     again, at 11px.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/analysis_focus.dart';
import 'package:seeksparks/utils/scripture_markup.dart' show ScriptureSpan;

/// Metrics shared by every Workbench surface. Numbers, not opinions —
/// they exist so panes stay on the same rhythm instead of each picking
/// its own padding.
abstract final class WbMetrics {
  /// Body text in the Browse and Search windows.
  static const double text = 12.0;

  /// Menu bar, pane titles, status bar, version tags.
  static const double chrome = 11.0;

  /// Original-language text needs a little more size to stay legible
  /// with pointing/accents, even in a dense layout.
  static const double original = 15.0;

  /// The size below which pointed Hebrew and accented Greek stop being
  /// readable — MEASURED, not chosen.
  ///
  /// Rendered the app's own bundled NotoSansHebrew at 1 device pixel per
  /// logical pixel (the worst case, and real on a 1× display) and looked
  /// for two contrasts that change the word: qamats (ָ) vs patach (ַ),
  /// and tsere (two dots) vs segol (three dots). Below 12 px both pairs
  /// are a single grey smudge. At 12 px only the first pair separates.
  /// At 13 px the second is marginal. **At 14 px two dots and three dots
  /// become countable**, and 15 px is the first comfortable size.
  /// BibleWorks recommends 12–14 pt for its Unicode Hebrew fonts — about
  /// 16–18 px at 96 dpi — which points the same way.
  ///
  /// The floor is [original] (15) rather than the bare 14 px threshold
  /// because [PhrasingPage] had already adopted that number for exactly
  /// this reason, and one shared floor is worth more than a pixel of
  /// density.
  ///
  /// Latin gets no floor and should not: a diacritic is not decoration.
  /// English at 8 px is unpleasant but still the same word; a qamats at
  /// 8 px is *absent*, and the app is then showing a vowel it is not
  /// showing. Under-dense is recoverable by the reader; a vowel they
  /// cannot see is not.
  static const double originalFloor = original;

  /// The size below which the app stops printing its small type at all.
  ///
  /// Every ceiling #315 removed came out of a `.clamp(lo, hi)`, and a
  /// clamp has TWO bounds of which only one was the bug. The ceiling
  /// froze the site from somewhere below the default 20 pt upward,
  /// which is the reported defect. The FLOOR was doing real work: a
  /// reader who drags Font Size down to 12 is asking for dense
  /// *scripture*, and a proportional caption at 0.6× would put a hint
  /// under a settings row at 7.8 px — smaller than anything the app
  /// prints anywhere. Deleting both bounds fixes the complaint and
  /// invents a new one at the other end.
  ///
  /// So the floor survives, once, as a number instead of thirty
  /// slightly different ones (10, 11, 12 and 13 were all in use). It is
  /// [chrome] because that is already the app's answer to "the
  /// smallest text we are willing to set" — menu bars, pane titles,
  /// status bars. Small print may reach it and stop; it may not go
  /// under it.
  ///
  /// Unlike [originalFloor] this is a comfort bound, not a correctness
  /// one. A 9 px hint is unpleasant and still says what it says; a 9 px
  /// qamats is a vowel the reader is not being shown.
  static const double smallPrintFloor = chrome;

  static const double lineHeight = 1.32;

  /// Height of the menu bar, the toolbar and the status bar.
  static const double menuBarHeight = 22.0;
  static const double toolbarHeight = 26.0;
  static const double statusBarHeight = 20.0;

  /// Height of a pane's title strip.
  static const double paneTitleHeight = 21.0;

  /// One row in a verse list.
  static const double rowPadV = 1.5;
  static const double rowPadH = 6.0;

  /// Hairline. BibleWorks separates everything with a single pixel.
  static const double hairline = 1.0;
}

/// The Workbench palette. Kept separate from `ColorScheme` because most
/// of these have no Material equivalent — "the colour of a pane's title
/// strip" is not a Material role.
@immutable
class WbColors extends ThemeExtension<WbColors> {
  const WbColors({
    required this.paneBg,
    required this.paneAltBg,
    required this.chromeBg,
    required this.border,
    required this.text,
    required this.mutedText,
    required this.link,
    required this.selectionBg,
    required this.hoverBg,
    required this.strongsLexical,
    required this.strongsGrammar,
    required this.pinMark,
    required this.siblingBg,
    required this.diffMark,
  });

  /// Background of a content pane (Browse, Search list, Analysis).
  final Color paneBg;

  /// Zebra/alternate row background — BibleWorks alternates version
  /// blocks so the eye can find the version boundary at a glance.
  final Color paneAltBg;

  /// Menu bar, toolbar, pane title strips, status bar.
  final Color chromeBg;

  final Color border;
  final Color text;
  final Color mutedText;

  /// Clickable scripture references. BibleWorks uses plain hyperlink
  /// blue and so do we — it is the one thing users already know.
  final Color link;

  /// Current verse / selected row.
  final Color selectionBg;

  /// Mouse-over highlight. The Workbench is hover-driven, so this gets
  /// used constantly.
  final Color hoverBg;

  /// Inline Strong's number printed after a word. Green for the word's
  /// own lexical number, blue for a grammar code — the convention
  /// yahwehdehua.net uses, and the reason a tagged verse stays readable
  /// with the numbers on: the eye filters by hue instead of parsing.
  final Color strongsLexical;
  final Color strongsGrammar;

  /// The border drawn round a PINNED word. Its own field rather than
  /// [accent], because a pin has to be legible on all three palettes
  /// and one gold is not: #C9A227 on paper's tan [selectionBg] measures
  /// 1.54:1, which is a marker you cannot see. These three are 3.98 /
  /// 6.67 / 4.13:1 against the fill they sit on — above the 3:1 that
  /// non-text UI needs — while all still reading as the app's gold, so
  /// "pinned is gold" holds whichever theme the reader is in.
  final Color pinMark;

  /// The fill behind every OTHER printed occurrence of the word under
  /// study — the same Greek or Hebrew word landing in the other
  /// translations on screen.
  ///
  /// Green, in all three palettes, because green already means "lexical
  /// Strong's number" here: it is the hue [strongsLexical] prints the
  /// number in after each word. The highlight is exactly "the words
  /// sharing that number", so it borrows the convention instead of
  /// inventing a fourth one.
  ///
  /// It could not be yellow, which is what yahwehdehua.net uses. Paper's
  /// [selectionBg] is already tan, so a yellow echo would be
  /// indistinguishable from the hover fill for anyone reading in
  /// 护眼纸质 — the same trap [pinMark] fell into. Green clears the blue
  /// selection of light and dark AND paper's tan.
  ///
  /// Opaque, never translucent. A translucent fill composites against
  /// whatever is behind it, so the same mark would render as two
  /// different colours depending on whether its row happened to be the
  /// selected one — the defect that made the version pill meaningless.
  final Color siblingBg;

  /// The rule drawn under a word that this edition does not share with
  /// the base edition — bwh30's difference highlighting, see
  /// `lib/utils/version_diff.dart`.
  ///
  /// It is an UNDERLINE and not a fill, and that is the whole reason
  /// this role can exist at all. Every fill on a Browse word is already
  /// spoken for and each one means something about the *word's
  /// identity*: [hoverBg] is "the pointer is here", [selectionBg] is
  /// "your search matched this", [siblingBg] is "this carries the
  /// Strong's number under study", [pinMark] is "this one is held". A
  /// difference is a claim about the word's RELATION TO ANOTHER
  /// EDITION, not about the word, so it takes the one channel nothing
  /// else uses — the baseline edge — and composes with all four instead
  /// of competing with them. A hovered, pinned, searched word that also
  /// differs from the KJV can say all four things at once.
  ///
  /// Rose rather than red: red would be the obvious choice and it sits
  /// opposite [siblingBg]'s green, which is the pairing red-green
  /// colour blindness collapses. Pulled toward magenta it separates
  /// from green on the blue axis as well as the red one, and from
  /// [pinMark]'s gold and [link]'s blue on hue. 5.6 / 8.4 / 6.9:1
  /// against the three pane backgrounds, above the 3:1 a non-text mark
  /// needs on all of them.
  final Color diffMark;

  /// The mark's gold. The single accent, used sparingly — an active
  /// toggle, a focused row — the way the icon uses it on the page.
  Color get accent => const Color(0xFFC9A227);

  /// Is the palette in force a dark one?
  ///
  /// For the few places that legitimately need a HUE rather than a role
  /// — a Hebrew-vs-Greek tag, a script badge — because one fixed hue
  /// cannot be legible on both #FFFFFF and #101A2B. Everything else
  /// should name a field above and never ask this.
  ///
  /// Derived from [paneBg] rather than from `Theme.of(context)
  /// .brightness`, which is the bug it exists to prevent: under the
  /// paper palette the ThemeMode may still be dark while every surface
  /// on screen is cream, so brightness-keyed hues come out inverted.
  /// Ask the palette what colour it is, not the theme.
  bool get isDark =>
      ThemeData.estimateBrightnessForColor(paneBg) == Brightness.dark;

  // 2026-08-06: the greys were neutral-to-warm and the link blue was
  // picked before the icon existed. Both now carry a slight bias toward
  // the mark's ink (#27395A), so the workspace and the icon read as one
  // family instead of two unrelated palettes.
  static const light = WbColors(
    paneBg: Color(0xFFFFFFFF),
    paneAltBg: Color(0xFFF6F7F9),
    chromeBg: Color(0xFFE9EBEF),
    border: Color(0xFFBCC2CC),
    text: Color(0xFF16202E),
    mutedText: Color(0xFF66707F),
    link: Color(0xFF27395A),
    selectionBg: Color(0xFFDCE5F1),
    hoverBg: Color(0xFFEFF2F7),
    strongsLexical: Color(0xFF1E7A3C),
    strongsGrammar: Color(0xFF1B57C4),
    pinMark: Color(0xFF8A6A12),
    siblingBg: Color(0xFFC2E9CE),
    diffMark: Color(0xFFB0246E),
  );

  static const dark = WbColors(
    // Straight off the icon's ground gradient: #152238 → #060B14.
    paneBg: Color(0xFF101A2B),
    paneAltBg: Color(0xFF152238),
    chromeBg: Color(0xFF1B2942),
    border: Color(0xFF33415A),
    text: Color(0xFFDCE5F1),
    mutedText: Color(0xFF8B9AB3),
    link: Color(0xFF9FB2CC),
    selectionBg: Color(0xFF243A5C),
    hoverBg: Color(0xFF1D2C46),
    strongsLexical: Color(0xFF5FC183),
    strongsGrammar: Color(0xFF77A6F0),
    pinMark: Color(0xFFE8C24A),
    siblingBg: Color(0xFF1E4433),
    diffMark: Color(0xFFF08CB8),
  );

  /// 2026-08: 护眼纸质 — the "easy-on-eyes" paper palette, used when
  /// [AppSettings.readingPaperTheme] is on. The classic reader has had
  /// this since it was ported from YsWords, but it stopped at the
  /// BibleReadingPane's content subtree: every workbench chrome surface
  /// (menu bar, status bar, panes, the parallel Browse window) read
  /// [WbColors.of] directly and stayed on the neutral desktop palette,
  /// so a reader who turned paper on got a cream square floating in a
  /// grey workspace. This variant is what the WHOLE workbench swaps to
  /// under paper mode — same hues as the reader's [_PaperTheme], kept
  /// warm regardless of ThemeMode (the point of "paper" is paper, not a
  /// tinted dark mode — see bible_reading_pane.dart).
  static const paper = WbColors(
    paneBg: Color(0xFFF7F1E0),
    paneAltBg: Color(0xFFEFE5C9),
    chromeBg: Color(0xFFE6D9B5),
    border: Color(0xFFDED0A8),
    text: Color(0xFF4A3826),
    mutedText: Color(0xFF7A6A50),
    // Hyperlink blue is the one BibleWorks colour readers already know;
    // a gold link on cream is harder to read, not easier.
    link: Color(0xFF27395A),
    selectionBg: Color(0xFFE3D19D),
    hoverBg: Color(0xFFEFE5C9),
    strongsLexical: Color(0xFF1E7A3C),
    strongsGrammar: Color(0xFF1B57C4),
    pinMark: Color(0xFF7A5C0A),
    siblingBg: Color(0xFFC4E2BF),
    diffMark: Color(0xFF9C2050),
  );

  @override
  WbColors copyWith({
    Color? paneBg,
    Color? paneAltBg,
    Color? chromeBg,
    Color? border,
    Color? text,
    Color? mutedText,
    Color? link,
    Color? selectionBg,
    Color? hoverBg,
    Color? strongsLexical,
    Color? strongsGrammar,
    Color? pinMark,
    Color? siblingBg,
    Color? diffMark,
  }) =>
      WbColors(
        paneBg: paneBg ?? this.paneBg,
        paneAltBg: paneAltBg ?? this.paneAltBg,
        chromeBg: chromeBg ?? this.chromeBg,
        border: border ?? this.border,
        text: text ?? this.text,
        mutedText: mutedText ?? this.mutedText,
        link: link ?? this.link,
        selectionBg: selectionBg ?? this.selectionBg,
        hoverBg: hoverBg ?? this.hoverBg,
        strongsLexical: strongsLexical ?? this.strongsLexical,
        strongsGrammar: strongsGrammar ?? this.strongsGrammar,
        pinMark: pinMark ?? this.pinMark,
        siblingBg: siblingBg ?? this.siblingBg,
        diffMark: diffMark ?? this.diffMark,
      );

  @override
  WbColors lerp(ThemeExtension<WbColors>? other, double t) {
    if (other is! WbColors) return this;
    return WbColors(
      paneBg: Color.lerp(paneBg, other.paneBg, t)!,
      paneAltBg: Color.lerp(paneAltBg, other.paneAltBg, t)!,
      chromeBg: Color.lerp(chromeBg, other.chromeBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      link: Color.lerp(link, other.link, t)!,
      selectionBg: Color.lerp(selectionBg, other.selectionBg, t)!,
      hoverBg: Color.lerp(hoverBg, other.hoverBg, t)!,
      strongsLexical:
          Color.lerp(strongsLexical, other.strongsLexical, t)!,
      strongsGrammar: Color.lerp(strongsGrammar, other.strongsGrammar, t)!,
      pinMark: Color.lerp(pinMark, other.pinMark, t)!,
      siblingBg: Color.lerp(siblingBg, other.siblingBg, t)!,
      diffMark: Color.lerp(diffMark, other.diffMark, t)!,
    );
  }

  /// 2026-08: value equality so tests can assert against the const
  /// `WbColors.light` / `.dark` / `.paper` instances even after Flutter
  /// rebuilds a ThemeData (which can lerp extensions into a fresh
  /// instance during Material 3 normalisation). The default identity
  /// equality made those assertions flaky for no good reason — two
  /// palettes with the same colours ARE the same palette.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WbColors &&
          other.paneBg == paneBg &&
          other.paneAltBg == paneAltBg &&
          other.chromeBg == chromeBg &&
          other.border == border &&
          other.text == text &&
          other.mutedText == mutedText &&
          other.link == link &&
          other.selectionBg == selectionBg &&
          other.hoverBg == hoverBg &&
          other.strongsLexical == strongsLexical &&
          other.strongsGrammar == strongsGrammar &&
          other.pinMark == pinMark &&
          other.siblingBg == siblingBg);

  @override
  int get hashCode => Object.hash(
        paneBg,
        paneAltBg,
        chromeBg,
        border,
        text,
        mutedText,
        link,
        selectionBg,
        hoverBg,
        strongsLexical,
        strongsGrammar,
        pinMark,
        siblingBg,
      );

  static WbColors of(BuildContext context) =>
      Theme.of(context).extension<WbColors>() ?? light;
}

/// The box drawn behind one word in the Browse window.
///
/// One function owns all five states so they cannot drift apart, which
/// is the only way "no ambiguity" survives the next person to touch the
/// file. They differ on two axes at once — fill HUE and border — so no
/// pair rests on a single cue:
///
///   none     no fill,                    no border
///   hit      selection hue at 55%,       no border    (+ bold text)
///   sibling  SIBLING hue at 100%,        no border
///   hover    selection hue at 100%,      no border    (+ underline)
///   pinned   selection hue at 100%,      gold border  (+ underline)
///
/// `sibling` is the echo: the same lexical Strong's number printed
/// somewhere else on screen, usually in another translation. It is
/// deliberately a DIFFERENT HUE rather than a weaker selection tint,
/// because it answers a different question. Hover and pinned say "this
/// is the word you are asking about"; sibling says "and here it is
/// again". Rendering the echo as a paler version of the subject would
/// make the two read as one gradient of the same thing and lose the
/// distinction that makes a parallel view worth having — you want to
/// see one Greek word land in four translations at once, and know at a
/// glance which one your pointer is actually on.
///
/// It carries no border and no underline: with a dozen echoes lit
/// across four rows, a border on each would turn the passage into a
/// grid of boxes and bury the one word that has the gold one.
///
/// The border is always present and only its colour changes. A border
/// that appeared on click would widen the word by 3px and reflow the
/// line under the reader's own pointer, which reads as the text
/// flinching away from them.
/// [diff] turns the bottom edge into the version-difference mark — see
/// [WbColors.diffMark]. It is drawn HERE rather than as a text underline
/// because a tagged word's underline is already spoken for: it says
/// "this is the word you are on" or "this is the word you pinned", and a
/// pin is not transient. Painting the difference there would silently
/// erase it for as long as the reader kept a differing word pinned,
/// which is a false negative in the one feature whose whole job is to
/// say that two editions differ. The border is already 1.5px on every
/// side and always reserved, so switching a side's colour cannot reflow
/// the line.
BoxDecoration wordMarkDecoration(WordMark mark, WbColors wb,
        {bool diff = false}) =>
    BoxDecoration(
      color: switch (mark) {
        WordMark.none => null,
        WordMark.hit => wb.selectionBg.withValues(alpha: 0.55),
        WordMark.sibling => wb.siblingBg,
        WordMark.hover || WordMark.pinned => wb.selectionBg,
      },
      border: switch (diff) {
        false => Border.all(
            width: 1.5,
            color: mark == WordMark.pinned ? wb.pinMark : Colors.transparent,
          ),
        true => Border(
            top: _wordSide(mark, wb),
            left: _wordSide(mark, wb),
            right: _wordSide(mark, wb),
            bottom: BorderSide(width: 1.5, color: wb.diffMark),
          ),
      },
      // BoxDecoration forbids a radius on a non-uniform border, so the
      // marked word squares off. At 2px that is imperceptible, and
      // square is the house rule anyway (see the ratchet at the top of
      // this file) — the radius is the concession, not this.
      borderRadius: diff ? null : BorderRadius.circular(2),
    );

BorderSide _wordSide(WordMark mark, WbColors wb) => BorderSide(
      width: 1.5,
      color: mark == WordMark.pinned ? wb.pinMark : Colors.transparent,
    );

/// A referent gloss — `主[雅伟]`, `主[基督]` — as it should print.
///
/// The brackets are kept and the body is left at full text weight and
/// colour, upright. Every part of that is a correction of something.
///
/// Upright, because italic is the printed convention for a word the
/// TRANSLATOR SUPPLIED, and the gloss says the opposite: the source had
/// the Name and the translation dropped it. Setting 雅伟 in the italic
/// reserved for insertions tells the reader the edition invented the
/// one word it exists to restore.
///
/// Brackets kept, because without them `主[雅伟]` prints as `主雅伟` —
/// a divine title Matthew never wrote, with nothing on screen to show
/// where the text stops and the edition's claim begins. Weight alone
/// cannot carry that boundary at workbench sizes in CJK.
///
/// Brackets muted, because they are apparatus and the Name is text.
/// That is also why the two kinds print identically: the edition sets
/// them the same, and giving the divine name extra weight HERE would
/// make the 212 glossed occurrences louder than the thousands where
/// 雅伟 simply stands in the text unbracketed.
TextSpan glossSpan(ScriptureSpan span, WbColors wb, {TextStyle? style}) =>
    TextSpan(
      style: style,
      children: [
        TextSpan(text: '[', style: TextStyle(color: wb.mutedText)),
        TextSpan(text: span.text, style: TextStyle(color: wb.text)),
        TextSpan(text: ']', style: TextStyle(color: wb.mutedText)),
      ],
    );

/// The edition's own chapter-and-verse, where it differs from the
/// numbering the reader navigated by.
///
/// Muted and small, because it is apparatus and must not be mistaken
/// for the verse — it was mistaken for the verse for as long as it
/// shipped inside the text. Parenthesised, because that is how the
/// edition prints it and a bare `102:12` beside Greek reads as a
/// footnote number.
///
/// Not a tap target. A footnote hides its body and needs opening; this
/// body is four characters and is already on screen, so a marker the
/// reader has to press would hide what it is there to say.
TextSpan versificationSpan(ScriptureSpan span, WbColors wb,
        {double? fontSize}) =>
    TextSpan(
      text: '(${span.text}) ',
      style: TextStyle(
        color: wb.mutedText,
        fontSize: fontSize,
        fontStyle: FontStyle.normal,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

/// Whether a mark underlines its word.
///
/// Only the two marks that name the reader's OWN subject do — the word
/// under the pointer and the word they pinned. An echo does not: it is
/// something the app noticed, not something the reader asked for, and a
/// dozen underlines across four rows would compete with the subject
/// instead of pointing at it.
///
/// This is also the accessibility guarantee, and the reason it is a
/// function rather than three lines inside a widget. The sibling fill
/// and the hover fill sit within 1.1:1 of each other in luminance — they
/// are told apart by HUE, green against blue, which is exactly the
/// distinction a red-green colour-blind reader cannot make. The
/// underline is the second, non-colour channel that keeps "the word I am
/// on" separable from "the same word elsewhere" without relying on the
/// eye seeing green at all.
TextDecoration wordMarkUnderline(WordMark mark) => switch (mark) {
      WordMark.hover || WordMark.pinned => TextDecoration.underline,
      WordMark.none || WordMark.hit || WordMark.sibling =>
        TextDecoration.none,
    };

/// Per-version tag colour. BibleWorks prints a short version code at the
/// start of every line in a saturated colour, and that single device is
/// what makes a wall of interleaved parallel text readable — you find
/// the version you want by colour, not by reading.
///
/// Keys are version CODES — `bibleVersions[].value`, plus the two
/// pseudo-codes the originals row uses. A hand-picked hue for every one,
/// grouped so related editions stay near each other while remaining
/// separable:
///   red = original languages   blue/green = English
///   amber = 和合本 family        purple     = 梁家铿
///
/// 2026-08-07 this map was half keyed on codes and half on LABELS,
/// because `WbVersionTag` was being handed a label. That made the
/// catalog's own colours dependent on display text, so renaming a
/// version silently dropped it to the HSL hash below — and a hash gives
/// a stable colour but guarantees no SEPARATION: two versions can land
/// a few degrees apart and stop carrying information.
///
/// 2026-08-08 (task #285) the label keys are gone and `WbVersionTag`
/// takes a code, so the rename that was about to trip this could not.
/// `test/version_label_scheme_test.dart` asserts every catalog code has
/// a row here and that no two share a colour; the hash stays only so a
/// brand-new code is never invisible.
const Map<String, Color> kVersionTagColors = {
  // Original languages — the highest-value lines, so the strongest hue.
  // `wtt` / `bgt` are not catalog editions: they are the labels the
  // Browse window prints on its Hebrew and Greek rows, after BibleWorks.
  'wtt': Color(0xFF9C1F1F), // Hebrew OT
  'bgt': Color(0xFF9C1F1F), // Greek NT
  'original': Color(0xFF9C1F1F),
  'lxxwh': Color(0xFFB03030), // LXX+WH — Greek, so the red family
  // English
  'nasb': Color(0xFF1B4F9C),
  'leb': Color(0xFF2A6BAF),
  'kjv': Color(0xFF1F7A3D),
  'kjvs': Color(0xFF2F9E57),
  'bsb': Color(0xFF14806B),
  // Chinese — 和合本 family in amber, 梁家铿译本 in purple.
  'cuvs-yhwh': Color(0xFFB0721A), // 雅简+
  'cuvs-yhwh-tr': Color(0xFFC98A2E), // 雅繁+
  'cuvs-plus': Color(0xFF8A5A10), // 和简+
  'biblexg-v2': Color(0xFF7A3FA0), // 梁简
  'biblexg-v2-tr': Color(0xFF9B62BE), // 梁繁
};

/// Fallback for a version with no assigned colour — derived from the
/// code so it is at least stable across sessions rather than random.
Color versionTagColor(String code) {
  final hit = kVersionTagColors[code.toLowerCase()];
  if (hit != null) return hit;
  final h = code.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.55, 0.35).toColor();
}

/// Builds the Workbench's [ThemeData] from the app's own [parent] theme.
///
/// Deliberately does NOT inherit the app's seeded purple scheme: the
/// point is a neutral ground. `primary` is set to the link blue so the
/// handful of Material widgets we still use (checkboxes in the version
/// picker, progress indicators) land somewhere sane.
///
/// It DOES inherit the parent's font family and — critically — its
/// `fontFamilyFallback`. Replacing the text theme without carrying that
/// chain across dropped Hebrew and Greek to notdef boxes, because the
/// bundled CJK subset and the platform faces that actually have those
/// scripts live in the parent's fallback list, not in any font this
/// file names.
ThemeData workbenchTheme(ThemeData parent, {bool paper = false}) {
  final brightness = parent.brightness;
  // Paper wins over light/dark — see [WbColors.paper]. A reader who
  // turned paper on wants paper everywhere in the workbench, including
  // in dark mode (warm cream is the whole point).
  final wb = paper
      ? WbColors.paper
      : (brightness == Brightness.dark ? WbColors.dark : WbColors.light);
  final base = brightness == Brightness.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  final inherited = parent.textTheme.bodyMedium;
  final fallback = inherited?.fontFamilyFallback;

  final scheme = ColorScheme.fromSeed(
    seedColor: wb.link,
    brightness: brightness,
  ).copyWith(
    surface: wb.paneBg,
    onSurface: wb.text,
    onSurfaceVariant: wb.mutedText,
    outline: wb.border,
    outlineVariant: wb.border,
    primary: wb.link,
    surfaceContainerHighest: wb.paneAltBg,
  );

  TextStyle body(double size, {FontWeight? w, Color? c}) => TextStyle(
        fontSize: size,
        height: WbMetrics.lineHeight,
        fontWeight: w,
        color: c ?? wb.text,
        // fontFamily deliberately NOT pinned: naming a family restricts
        // CanvasKit to that face plus the explicit fallback list. Until
        // v1.6.73 that list had no Hebrew at all, so the only thing
        // rendering it was the engine's own fallback — i.e. a download
        // from fonts.gstatic.com, unreachable from mainland China. The
        // chain now carries the bundled Hebrew and polytonic Greek
        // subsets, so leaving this unset is no longer load-bearing; it
        // is just one fewer restriction.
        fontFamilyFallback: fallback,
      );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: wb.chromeBg,
    canvasColor: wb.paneBg,
    dividerColor: wb.border,
    dividerTheme: DividerThemeData(
      color: wb.border,
      thickness: WbMetrics.hairline,
      space: WbMetrics.hairline,
    ),
    // `.apply` FIRST, then the five overrides. The doc comment above has
    // promised since v1.6.73 that this theme inherits the parent's
    // fallback chain, and until 2026-08-17 (#316) only the five styles
    // restated below actually got it — every other style came straight
    // off `ThemeData.light()`, i.e. Roboto with no fallback at all.
    // Roboto has no CJK, the engine's own last resort is a download from
    // fonts.gstatic.com, and `--no-web-resources-cdn` closes that door,
    // so on web those styles drew Chinese as notdef boxes. That is what
    // the rotate advisory's title and instruction were: `headlineSmall`
    // and `titleMedium`. Buttons (`labelLarge`) and AppBar titles
    // (`titleLarge`) sit on the same hole, which is why call sites all
    // over `lib/` carry their own `fontFamilyFallback:` — each one is a
    // separate patch of this single omission.
    //
    // A fallback is only consulted for code points the primary face
    // lacks, so applying it to all fifteen styles changes nothing that
    // already rendered.
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback).copyWith(
          bodyLarge: body(WbMetrics.text),
          bodyMedium: body(WbMetrics.text),
          bodySmall: body(WbMetrics.chrome, c: wb.mutedText),
          labelSmall: body(WbMetrics.chrome, c: wb.mutedText),
          titleSmall: body(WbMetrics.chrome, w: FontWeight.w600),
        ),
    iconTheme: IconThemeData(color: wb.mutedText, size: 15),
    // Square, hairline-bordered, no elevation — everywhere.
    cardTheme: CardThemeData(
      color: wb.paneBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: body(WbMetrics.chrome, c: Colors.white),
    ),
    // A dense text field with a hairline box, not a filled pill.
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: wb.paneBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: wb.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: wb.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: wb.link, width: 1.4),
      ),
      hintStyle: body(WbMetrics.text, c: wb.mutedText),
    ),
    // ---- Component chrome (2026-08-08, task #279) ------------------
    //
    // Everything below is the SAME rule as `cardTheme` above — square
    // corners, a 1px hairline, no elevation — applied to the Material
    // components the app actually uses. It is here rather than in the
    // pages because of how this function is built: `base` is a FRESH
    // `ThemeData.light/dark`, so the caller's per-widget themes are
    // discarded, and only three components (card, input, tooltip) were
    // ever overridden. Every other component therefore rendered on the
    // stock Material 3 defaults, which are STADIUM-shaped — that is
    // where the app's pills come from, not from the pages.
    //
    // #279 measured "67 rounded/elevated sites across 13 pages". A
    // large share of them are not sites at all: no page ever asked for
    // a pill, it asked for a `FilterChip`. Fixing the shape here is one
    // change instead of sixty-seven, and it cannot drift.
    //
    // Deliberately NOT flattened, because these are affordances rather
    // than chrome: Switch (a switch that is not a pill stops reading as
    // a switch), Slider, and the M3 Checkbox's 2px radius.
    //
    // Padding and heights are left at the Material defaults throughout.
    // The spec is about corners, borders, shadows and palette — the
    // brief is explicit that DENSITY is not what has to match, and a
    // touch target shrunk to workbench scale would be a different and
    // much riskier change.

    // Pills, all four families. M3 gives every button a StadiumBorder.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        side: BorderSide(color: wb.border),
        foregroundColor: wb.text,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
        backgroundColor: wb.paneBg,
        foregroundColor: wb.text,
        side: BorderSide(color: wb.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        foregroundColor: wb.link,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        side: BorderSide(color: wb.border),
        selectedBackgroundColor: wb.selectionBg,
        selectedForegroundColor: wb.text,
        foregroundColor: wb.mutedText,
      ),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      borderRadius: BorderRadius.zero,
      borderColor: wb.border,
      selectedBorderColor: wb.link,
      fillColor: wb.selectionBg,
      selectedColor: wb.text,
      color: wb.mutedText,
    ),
    // The checkmark stays. Selected-ness is carried by fill AND by the
    // tick, and dropping the tick would leave a colour-only cue — the
    // same mistake `wordMarkUnderline` exists to avoid.
    chipTheme: ChipThemeData(
      backgroundColor: wb.paneBg,
      selectedColor: wb.selectionBg,
      checkmarkColor: wb.text,
      side: BorderSide(color: wb.border),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      labelStyle: body(WbMetrics.text),
      secondaryLabelStyle: body(WbMetrics.text, c: wb.mutedText),
      elevation: 0,
      pressElevation: 0,
      showCheckmark: true,
    ),
    // Sheets and dialogs keep a hairline so a flat surface still has an
    // edge against the pane behind it. A call site that passes its own
    // `shape:` still wins — those are converted one page at a time.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: wb.paneBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: wb.paneBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: wb.paneBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border),
      ),
      textStyle: body(WbMetrics.text),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(wb.paneBg),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: wb.border),
          ),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      // `behavior` is left alone: floating vs fixed is layout, and a
      // fixed SnackBar ignores `shape` anyway.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 0,
    ),
    // The page's own title strip. Flat, neutral, hairline underneath —
    // the full-page equivalent of `WbPaneTitle`. Previously this fell
    // through to the M3 default, which tints and elevates on scroll.
    appBarTheme: AppBarTheme(
      backgroundColor: wb.chromeBg,
      foregroundColor: wb.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: wb.border)),
      iconTheme: IconThemeData(color: wb.text, size: 20),
      actionsIconTheme: IconThemeData(color: wb.mutedText, size: 20),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: wb.text,
      unselectedLabelColor: wb.mutedText,
      indicatorColor: wb.link,
      dividerColor: wb.border,
      overlayColor: WidgetStatePropertyAll(wb.hoverBg),
    ),
    listTileTheme: ListTileThemeData(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      selectedTileColor: wb.selectionBg,
      selectedColor: wb.text,
      iconColor: wb.mutedText,
      textColor: wb.text,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      collapsedShape:
          const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      iconColor: wb.mutedText,
      collapsedIconColor: wb.mutedText,
      textColor: wb.text,
      collapsedTextColor: wb.text,
    ),
    // M3 gave the linear indicator rounded caps and a gap; a progress
    // bar in this window is a measurement, so it gets square ends.
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: wb.link,
      linearTrackColor: wb.paneAltBg,
      circularTrackColor: wb.paneAltBg,
      borderRadius: BorderRadius.zero,
    ),
    // Kill the ripple. A desktop tool highlights on hover, it doesn't
    // splash on click.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: <ThemeExtension<dynamic>>[wb],
  );
}

/// 2026-08-06: the Workbench's type scale, RESOLVED FROM SETTINGS.
///
/// [WbMetrics] is a const class, so every size in the workbench was a
/// compile-time literal and the Settings sliders drove nothing here. An
/// audit found the workbench honoured 2 of 10 user settings: Font Size
/// (only after a fix earlier today) and Strong's visibility. Font
/// family, Menu Size, Line Spacing, the paper theme, paragraph mode —
/// all ignored, across 82 hardcoded call sites.
///
/// This is the missing piece: one resolved scale, read from context, so
/// a setting reaches the workbench the same way it reaches the reader.
///
/// The workbench stays DENSER than the reader on purpose — it is a
/// three-pane analysis surface, not a reading page. So settings scale
/// it RELATIVE to their own defaults rather than being adopted
/// outright: a reader at font size 24 gets a proportionally larger
/// workbench, not a workbench with 24px body text.
class WbType {
  const WbType({
    required this.text,
    required this.chrome,
    required this.original,
    required this.lineHeight,
    required this.menuBarHeight,
    required this.toolbarHeight,
    required this.statusBarHeight,
    required this.paneTitleHeight,
    this.textScale = 1.0,
    this.chromeScale = 1.0,
    this.fontFamily,
  });

  final double text;
  final double chrome;
  final double original;
  final double lineHeight;
  final double menuBarHeight;
  final double toolbarHeight;
  final double statusBarHeight;
  final double paneTitleHeight;

  /// The two scales, exposed rather than kept as locals in [resolve].
  ///
  /// [text], [chrome] and [original] cover the three sizes the workbench
  /// agreed on, but a pane legitimately needs others: a pane's own
  /// heading, a superscript verse number, a badge. Before these were
  /// fields the only way to write such a size was a literal, and 263 of
  /// them accumulated — every one a place a slider moved nothing. A
  /// surface that needs its own size can now derive it instead of
  /// inventing it.
  final double textScale;
  final double chromeScale;

  /// The reader's chosen font, so the workbench does not silently opt
  /// out of a preference the rest of the app respects.
  final String? fontFamily;

  /// A size of the caller's own choosing, on the body-text scale.
  ///
  /// `t.scaled(9.5)` means "9.5 px when the reader is at the default
  /// 20 pt, and proportionally larger or smaller otherwise" — which is
  /// what every hardcoded literal in the workbench was silently
  /// claiming to be.
  double scaled(double atDefault) => atDefault * textScale;

  /// The same, on the chrome scale, for anything the Menu Size slider
  /// owns: bar heights, icons, tab labels, badges.
  double scaledChrome(double atDefault) => atDefault * chromeScale;

  /// A Material role's own size, put back on the reader's scale.
  ///
  /// A hardcoded literal is not the only way to write a size the slider
  /// cannot move. `main.dart` rewires exactly three roles from
  /// `settings.fontSize` — `bodyLarge`, `bodyMedium`, `titleLarge` — so
  /// every OTHER role in `textTheme` is a fixed number wearing a name,
  /// and `Text(x, style: theme.textTheme.bodySmall)` is as deaf as
  /// `fontSize: 12` would have been. #315's ratchet counts literals and
  /// could not see this.
  ///
  /// Do NOT pass one of the three rewired roles: they already carry the
  /// reader's setting, and scaling them again squares it.
  TextStyle? scaleRole(TextStyle? role) => role?.fontSize == null
      ? role
      : role!.copyWith(fontSize: role.fontSize! * textScale);

  /// A subordinate size on the reader's scale, floored so small print
  /// stays print — see [WbMetrics.smallPrintFloor].
  ///
  /// This is the replacement for `(fontSize - k).clamp(lo, hi)`, and it
  /// differs from that shape in two ways beyond losing the ceiling.
  /// The offset was ADDITIVE, which does not hold a type hierarchy: at
  /// 12 pt `fontSize - 6` and `fontSize - 1` are 6 and 11, a ratio of
  /// 1.8, and at 40 pt they are 34 and 39, a ratio of 1.15. The same
  /// two sizes expressed as [atDefault] keep their proportion at every
  /// stop of the slider, which is what a caption being "smaller than
  /// its heading" actually means.
  ///
  /// [atDefault] is the size the site renders today at the default
  /// 20 pt, so the repair is invisible to a reader who never moved the
  /// slider and changes only the range the slider could not reach.
  double scaledSmall(double atDefault) {
    assert(atDefault >= WbMetrics.smallPrintFloor,
        'small print designed at $atDefault px is already below the '
        '${WbMetrics.smallPrintFloor} px floor at the default setting — '
        'raise the design size rather than relying on the floor');
    return math.max(atDefault * textScale, WbMetrics.smallPrintFloor);
  }

  /// The same, floored so pointing and accents survive.
  ///
  /// Use this for anything rendering Hebrew or Greek. It is the only
  /// place in the app where a setting is deliberately overruled, and the
  /// reason is in [WbMetrics.originalFloor]: below the floor the app is
  /// no longer showing the text, it is showing a smudge.
  ///
  /// [atDefault] must not itself be below the floor — a surface that
  /// renders pointed text at 12 px even at the default setting has the
  /// same defect and should be raised, not clamped, or the floor would
  /// silently make it *bigger* than its own design size.
  double scaledOriginal(double atDefault) {
    assert(atDefault >= WbMetrics.originalFloor,
        'original text at $atDefault px is below the ${WbMetrics.originalFloor} px floor even at the default setting');
    return math.max(atDefault * textScale, WbMetrics.originalFloor);
  }

  /// Defaults, for tests and any surface built without settings.
  static const WbType fallback = WbType(
    text: WbMetrics.text,
    chrome: WbMetrics.chrome,
    original: WbMetrics.original,
    lineHeight: WbMetrics.lineHeight,
    menuBarHeight: WbMetrics.menuBarHeight,
    toolbarHeight: WbMetrics.toolbarHeight,
    statusBarHeight: WbMetrics.statusBarHeight,
    paneTitleHeight: WbMetrics.paneTitleHeight,
  );

  /// Resolve from the ambient settings.
  ///
  /// `watch` rather than `read`: moving a slider in Settings has to
  /// repaint the workbench, which is the entire point.
  static WbType of(BuildContext context) {
    final s = context.watch<AppSettings>();
    return resolve(
      fontSize: s.fontSize,
      lineSpacing: s.lineSpacing,
      menuScale: s.menuScale,
      fontFamily: s.fontFamily,
    );
  }

  /// Build the scale from the reader's settings.
  ///
  /// The clamps are a GUARD, not a design bound: they admit exactly the
  /// range Settings offers and nothing else. Neither `setFontSize`, nor
  /// `restoreState`, nor the settings-import path bounds `fontSize`, so
  /// a legacy or hand-edited value can arrive outside 12–40.
  ///
  /// They used to be narrower than the sliders (0.75–1.6 and 0.8–1.4),
  /// which silently ate **11 of the font slider's 29 stops and 2 of the
  /// menu slider's 9**: dragging to 40 pt showed "40 pt" and moved
  /// nothing from 32 pt on. A control must not advertise travel it does
  /// not have. Widening also un-compresses the live band — the slider
  /// spans 12–40 (3.33×) and the workbench now spans the same 3.33×
  /// rather than 2.13×.
  ///
  /// The wider ends were measured, not assumed: 40 pt / 1.5× and
  /// 12 pt / 0.7× were screenshot at 1456 px and at 1000 px, in 繁體,
  /// light and dark. Nothing overflows or overlaps and the three panes
  /// survive both corners. Two things degrade at 1000 px / 40 pt /
  /// 1.5×, and both degrade gracefully: the search pane's operator
  /// strip wraps to a second row, and the Browse pane's title
  /// ellipsises to `Gene… NA…`. Truncating a title is the correct
  /// answer to "I asked for 40 pt in a 200 px pane" — shrinking it back
  /// would be the app overruling the setting again, which is the very
  /// defect this fixes.
  static WbType resolve({
    required double fontSize,
    required double lineSpacing,
    required double menuScale,
    String? fontFamily,
  }) {
    // 20 / 1.5 / 1.0 are the app defaults for these three. Expressing
    // the bounds as the slider's own ends divided by the default is what
    // makes the two impossible to drift apart again.
    final textScale = (fontSize / kFontSizeDefault).clamp(
      kFontSizeMin / kFontSizeDefault,
      kFontSizeMax / kFontSizeDefault,
    );
    final chromeScale = menuScale.clamp(kMenuScaleMin, kMenuScaleMax);
    // Line spacing moves the workbench's own tighter leading in the
    // same direction the reader asked for, without adopting the
    // reader's roomier value outright.
    final leading =
        (WbMetrics.lineHeight * (lineSpacing / 1.5)).clamp(1.05, 1.9);
    return WbType(
      text: WbMetrics.text * textScale,
      chrome: WbMetrics.chrome * chromeScale,
      // Floored: see [WbMetrics.originalFloor]. A reader who sets 12 pt
      // is asking the rest of the app to be dense; they are not asking
      // for an unreadable qamats.
      original: math.max(WbMetrics.original * textScale,
          WbMetrics.originalFloor),
      lineHeight: leading.toDouble(),
      menuBarHeight: WbMetrics.menuBarHeight * chromeScale,
      toolbarHeight: WbMetrics.toolbarHeight * chromeScale,
      statusBarHeight: WbMetrics.statusBarHeight * chromeScale,
      paneTitleHeight: WbMetrics.paneTitleHeight * chromeScale,
      textScale: textScale.toDouble(),
      chromeScale: chromeScale.toDouble(),
      fontFamily: (fontFamily ?? '').isEmpty ? null : fontFamily,
    );
  }
}
