/// 2026-08-09 (SeekSparks, task #284): the two presentations of the
/// word study, resolved once.
///
/// `OriginalsSheet` is shown two ways and they want opposite things:
///
///   * As a **modal sheet** from the reading pane and the stats page —
///     the touch-first app. Rounded, roomy, 14px prose.
///   * As the workbench's **Word Study analysis tab**, docked in a pane
///     that can be as narrow as 256px, beside eleven other tabs that
///     all obey `workbench_theme.dart`: "Square corners and 1px hairline
///     borders. No shadows, no cards."
///
/// Until now it only knew the first. That mattered more than it sounds,
/// because the Word Study tab has **two bodies**: hovering a word gives
/// [WordAnalysisPane], hovering a verse or making a selection gives this
/// sheet. Moving the pointer one grade coarser swapped the whole tab
/// between two visual languages.
///
/// `workbenchTheme` already remaps the *semantic* `ColorScheme` roles —
/// `surface`, `onSurface`, `onSurfaceVariant`, `outline`, `primary`,
/// `surfaceContainerHighest` all resolve to `WbColors` inside the
/// workbench subtree. So prose colour was never the problem and is left
/// alone. What does NOT survive that remap is:
///
///   * geometry — corner radii, padding, chip width;
///   * type scale — the sheet hardcodes 9–22px and so ignores the
///     reader's workbench font-size setting entirely;
///   * the *tonal* roles (`primaryContainer`, `secondary`,
///     `tertiaryContainer`), which `ColorScheme.fromSeed` fills in with
///     Material pastels the workbench palette deliberately has no
///     equivalent for.
///
/// Those three are what this resolves, and only those.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart';

/// Every value the word study styles itself with, for one presentation.
///
/// A plain data class on purpose: [resolve] is the only place the two
/// columns are written down, so they cannot drift apart one site at a
/// time, and a test can read them without building a widget.
@immutable
class WordStudyStyle {
  const WordStudyStyle({
    required this.dense,
    required this.body,
    required this.ref,
    required this.gloss,
    required this.translit,
    required this.micro,
    required this.original,
    required this.lemma,
    required this.blockFill,
    required this.blockBorder,
    required this.chipFill,
    required this.chipBorder,
    required this.selectedFill,
    required this.selectedBorder,
    required this.strongs,
    required this.strongsFill,
    required this.accent,
    required this.accentFill,
    required this.listPadding,
    required this.blockPadding,
    required this.chipMaxWidth,
  });

  /// True for the docked workbench pane. Named for what it *is* rather
  /// than for where it came from, so a reader of a call site does not
  /// have to know which presentation is "embedded".
  final bool dense;

  /// Verse text and entry prose.
  final double body;

  /// The `Genesis 1:1` line above an interlinear block, and labels.
  final double ref;

  /// The Strong's gloss printed under each original-language word.
  final double gloss;

  /// Transliteration under the lemma.
  final double translit;

  /// Strong's badge and part-of-speech — the smallest type here.
  final double micro;

  /// Hebrew/Greek inside a word chip.
  final double original;

  /// Hebrew/Greek headword at the top of the entry card.
  final double lemma;

  /// Fill behind a block of content (the translation line, the entry
  /// card, the concordance box).
  final Color blockFill;

  /// Hairline around such a block. Transparent in the modal, which
  /// separates by rounded fill alone.
  final Color blockBorder;

  final Color chipFill;
  final Color chipBorder;

  /// The chip for the word whose entry is currently open.
  final Color selectedFill;
  final Color selectedBorder;

  /// A Strong's number: coloured numerals in the workbench (BibleWorks
  /// prints them exactly so), a tinted pill in the modal.
  final Color strongs;
  final Color strongsFill;

  /// The one saturated colour the workbench allows besides a version
  /// tag: the blue that means "this is a link / this is the subject".
  final Color accent;

  /// A wash of [accent] behind a highlighted row (the parsing line, the
  /// AI panel). Kept as a field rather than an alpha applied at the call
  /// site so the workbench can opt out of washes entirely.
  final Color accentFill;

  final EdgeInsets listPadding;
  final EdgeInsets blockPadding;

  /// A chip may not grow past this. In the workbench the pane floor is
  /// 256px, so two chips plus the gap and the list padding have to fit
  /// inside it: 2 × 112 + 6 + 2 × 8 = 246.
  final double chipMaxWidth;

  /// Corner radius, given the value the modal uses.
  ///
  /// Every rounded corner in the sheet goes through here so that "square
  /// in the workbench" is one rule rather than twenty-six ternaries, and
  /// so a source ratchet can assert no literal radius survives.
  BorderRadius r(double soft) =>
      dense ? BorderRadius.zero : BorderRadius.circular(soft);

  /// Border width. The modal draws a 1.5px selection ring; the
  /// workbench draws hairlines and nothing else.
  double get borderWidth => dense ? WbMetrics.hairline : 1.5;

  static WordStudyStyle resolve({
    required bool embedded,
    required ColorScheme scheme,
    required WbColors wb,
    required WbType type,
  }) {
    if (!embedded) {
      // The modal's PROPORTIONS are unchanged — these are the literals
      // that were spread through the widget before this class existed,
      // and their ratios are the phone reader's design.
      //
      // What changed (#315) is that they are no longer absolute. They
      // were the reason a reader who set 12 pt or 40 pt saw the modal
      // word study at exactly one size either way: `workbenchTheme`'s
      // scale reached the docked branch below and stopped here. Read
      // each as "n px at the default 20 pt".
      return WordStudyStyle(
        dense: false,
        body: type.scaled(14),
        ref: type.scaled(12),
        gloss: type.scaled(11),
        translit: type.scaled(10),
        micro: type.scaled(9),
        original: type.scaledOriginal(18),
        lemma: type.scaledOriginal(22),
        blockFill: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        blockBorder: Colors.transparent,
        chipFill: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        chipBorder: Colors.transparent,
        selectedFill: scheme.primaryContainer,
        selectedBorder: scheme.primary,
        strongs: scheme.secondary,
        strongsFill: scheme.secondary.withValues(alpha: 0.13),
        accent: scheme.primary,
        accentFill: scheme.primary.withValues(alpha: 0.07),
        listPadding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        blockPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        // Scaled with the type it has to contain: a chip whose Hebrew
        // grew to 36 px inside a fixed 118 px box clips the word.
        chipMaxWidth: type.scaled(118),
      );
    }
    return WordStudyStyle(
      dense: true,
      // Scaled, not hardcoded: the workbench has a font-size setting and
      // this pane was the one surface in it that ignored it.
      body: type.text,
      ref: type.chrome,
      gloss: type.chrome,
      // #315 residue, 2026-08-31. These two were 9.0px at the default
      // Menu Size — `resolve` sets `chrome: WbMetrics.chrome *
      // chromeScale`, so the field IS `WbMetrics.smallPrintFloor` and
      // anything subtracted from it is under a floor whose comment says
      // small print "may reach it and stop; it may not go under it".
      //
      // They survived last run's 52-site sweep because that ratchet
      // reads the argument of a `fontSize:` expression, and these are
      // named-argument initialisers on a data class, read six files
      // away as `fontSize: _st.translit`. A guard that counts notation
      // cannot see a number. `word_study_style_test.dart`'s group "no
      // field in the docked column is designed under the floor" reads
      // the resolved values instead.
      //
      // Ranking them BELOW `ref`/`gloss` by size is not what makes them
      // subordinate and never was: all six call sites in
      // `originals_sheet.dart` already mute, italicise, embolden or
      // track them (980, 1004, 1048, 1531, 2234, 2408). One of them is
      // a CC-BY-NC-SA attribution we are obliged to print.
      translit: type.chrome,
      micro: type.chrome,
      original: type.original,
      // The headword is the one thing in the pane worth being large.
      // +6 lands it on WordAnalysisPane's 21px at the default scale,
      // which is the point — the tab's two bodies print a lemma the
      // same size.
      lemma: type.original + 6,
      blockFill: wb.paneAltBg,
      blockBorder: wb.border,
      // A chip sits on the pane ground and is separated by its hairline,
      // not by a fill. Filling every chip turns a 40-word verse into a
      // field of grey boxes at this density.
      chipFill: wb.paneBg,
      chipBorder: wb.border,
      selectedFill: wb.selectionBg,
      // `pinMark`, not a new colour: tapping a chip here is the same act
      // as pinning a word in the Browse pane, and this is the palette's
      // one marker already contrast-checked (WCAG 3:1 non-text) against
      // `selectionBg` in all three themes — including 护眼纸质, where the
      // app's ordinary gold accent measures 1.54:1 and would vanish.
      selectedBorder: wb.pinMark,
      // Green numerals, no pill. `strongsLexical` exists for exactly
      // this and is what the Browse pane already prints.
      strongs: wb.strongsLexical,
      strongsFill: Colors.transparent,
      accent: wb.link,
      // No wash. In the workbench the parsing line earns its emphasis
      // from a hairline and the link colour, the way every other pane
      // does.
      accentFill: Colors.transparent,
      // Deliberately identical to WordAnalysisPane's list padding: the
      // two bodies of this one tab must not shift the text sideways as
      // the pointer moves between a word and its verse.
      listPadding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
      blockPadding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      chipMaxWidth: type.scaled(112),
    );
  }
}
