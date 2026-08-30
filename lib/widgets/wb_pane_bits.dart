/// 2026-08-09 (task #279): the Analysis pane's shared controls.
///
/// `wb_surfaces.dart` owns the workbench's PAGE-level furniture — the
/// titled box, the tag, the row — at page density. This file is the same
/// idea one scale down, for the thirteen tabs of the Analysis pane,
/// which live in 256–560 px and are therefore a different density
/// regime: `WbType.chrome` type, 2–3 px of vertical padding, counts
/// printed beside labels rather than under them.
///
/// It exists because the chrome pass found the pane was not thirteen
/// tabs with forty-five rounded corners in them. It was **thirteen tabs
/// built by copying their neighbour**: one toggle chip written five
/// times, one icon button written seven, one magnitude bar written
/// three. Squaring forty-five corners in place would have preserved
/// every one of those copies, and the copies are the actual defect —
/// which the chip proves.
///
/// **The chip's ellipsis was decoration.** Three of the five copies
/// carried `maxLines: 1, overflow: TextOverflow.ellipsis` and the other
/// two did not, so it read as a small inconsistency. It was not: the
/// label sits in a `Row(mainAxisSize: MainAxisSize.min)`, which hands
/// non-flex children UNBOUNDED main-axis constraints, so there is
/// nothing for `ellipsis` to measure against. Measured, a phrase chip
/// reading "in the beginning was the word…" overflows a 256 px pane by
/// **402 px** — with the ellipsis property present. All five copies were
/// broken; three of them merely looked handled, which is worse, because
/// a reader of the source stops there. The label is [Flexible] here, and
/// that is the whole fix.
///
/// The rule these encode is `workbench_theme.dart`'s: **square corners,
/// 1px hairline borders, no shadows, no cards.** As in `wb_surfaces`,
/// what they deliberately do NOT encode is density — padding and type
/// stay where the panes already had them.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart';

/// A toggle in an Analysis pane's filter row — a sort order, a
/// morphology slot value, a search term, a phrase.
///
/// `on` is the whole state machine: it drives the fill
/// ([WbColors.selectionBg]), the border, and the weight. [foreground]
/// exists because the panes disagree about the accent and are right to
/// — the morphology pane uses [WbColors.strongsGrammar] because its
/// chips ARE grammar, the rest use [WbColors.strongsLexical] — and
/// because two panes carry a third state (emphasised, or too-common-to-
/// search) that is neither on nor off.
class WbPaneChip extends StatelessWidget {
  const WbPaneChip({
    super.key,
    required this.label,
    required this.on,
    this.onTap,
    this.onLongPress,
    this.foreground,
    this.trailing,
    this.trailingColor,
    this.trailingBold = false,
    this.strikeWhenOff = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    this.alignment = MainAxisAlignment.start,
  });

  final String label;
  final bool on;

  /// A null [onTap] is the disabled case, and is deliberately not a
  /// separate `enabled` flag: `InkWell` already renders a null callback
  /// as un-hoverable, and the pane that needs it (Phrases, for a phrase
  /// too common to have been indexed) also wants its own [foreground].
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Defaults to the lexical accent when on, muted when off.
  final Color? foreground;

  /// The count printed after the label — how much of the Bible carries
  /// this word. In every pane that shows one it is most of what tells a
  /// reader whether the chip is worth turning on, so it is part of the
  /// chip rather than something callers bolt on.
  final String? trailing;
  final Color? trailingColor;
  final bool trailingBold;

  /// Strikes the label when off. Reads as "excluded from the query",
  /// which is what off means in the Related and Phrases panes; in the
  /// sort-order rows off just means "not the current sort", so those
  /// leave it alone.
  final bool strikeWhenOff;

  final EdgeInsets padding;

  /// Centres the content, for the one caller that is a segmented pair
  /// rather than a chip in a `Wrap`: the Verse List Manager's
  /// Main/Secondary radio, which sits in an `Expanded` and so is given
  /// tight width the chip would otherwise leave left-aligned.
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final fg = foreground ?? (on ? wb.strongsLexical : wb.mutedText);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      hoverColor: wb.hoverBg,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: on ? wb.selectionBg : Colors.transparent,
          border: Border.all(
            color: on ? fg : wb.border,
            width: WbMetrics.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignment,
          children: [
            // Flexible, not a bare Text: see the library doc. A
            // `mainAxisSize.min` Row gives non-flex children unbounded
            // width, so `overflow: ellipsis` on the Text alone is inert
            // and a long phrase overflows the pane instead.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: t.fontFamily,
                  fontSize: t.chrome,
                  color: fg,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  decoration: !on && strikeWhenOff
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Text(
                trailing!,
                style: TextStyle(
                  fontFamily: t.fontFamily,
                  fontSize: t.chrome,
                  color: trailingColor ?? wb.mutedText,
                  fontWeight: trailingBold ? FontWeight.w700 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A bare icon control at pane density — a stepper arrow, an expand
/// chevron, the arrow that opens a hit in the reading pane, the tick
/// that marks a vocabulary word learned.
///
/// Seven copies of `InkWell > Padding > Icon` across five panes, each
/// with its own rounded corner and its own idea of the disabled colour.
/// A null [onTap] is disabled and paints [WbColors.border], which is
/// what all seven already did.
class WbIconTap extends StatelessWidget {
  const WbIconTap({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 14,
    this.color,
    this.padding = const EdgeInsets.all(2),
    this.tooltip,
  });

  final IconData icon;

  /// Null disables the control.
  final VoidCallback? onTap;
  final double size;

  /// The enabled colour. Defaults to [WbColors.link], which is what the
  /// steppers used; the panes that want a quieter arrow pass
  /// [WbColors.mutedText].
  final Color? color;
  final EdgeInsets padding;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final enabled = onTap != null;
    Widget child = InkWell(
      onTap: onTap,
      hoverColor: wb.hoverBg,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: padding,
        child: Icon(
          icon,
          size: size,
          color: enabled ? (color ?? wb.link) : wb.border,
        ),
      ),
    );
    if (tooltip != null) child = Tooltip(message: tooltip!, child: child);
    return child;
  }
}

/// A horizontal magnitude bar — how much of this word's occurrences sit
/// in this book, how much of the maximum this row reaches.
///
/// Three implementations before the pass: a `ClipRRect` over a
/// `LinearProgressIndicator` in the Stats tab, a `Stack` of two
/// `Container`s in the distribution chart, and a 3 px vertical sliver in
/// the Context tab. The first was arguing with the theme —
/// `progressIndicatorTheme` already sets `BorderRadius.zero`, so the
/// `ClipRRect` existed only to round a bar the workbench had already
/// squared.
class WbMeterBar extends StatelessWidget {
  const WbMeterBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 4,
    this.trackColor,
  });

  /// Clamped, so a caller dividing by a zero maximum cannot make the
  /// bar disappear or run past its track.
  final double fraction;
  final Color color;
  final double height;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: trackColor ?? wb.paneAltBg,
            ),
          ),
          FractionallySizedBox(
            widthFactor: fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0,
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ],
      ),
    );
  }
}
