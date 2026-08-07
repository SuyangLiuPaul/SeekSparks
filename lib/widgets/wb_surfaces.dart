/// 2026-08-08 (task #279): the Workbench's PAGE-level surfaces.
///
/// `workbench_chrome.dart` owns the shell — the menu bar, the 21px pane
/// title strips, the status bar. This file owns what goes *inside* a
/// full page: the titled box, the small tag, and the row.
///
/// It exists because the chrome pass is thirteen pages long and the
/// alternative is spelling `Container(decoration: BoxDecoration(border:
/// Border.all(color: wb.border)))` sixty-seven times. Two
/// implementations of "a section box" drift; one does not.
///
/// The rule these encode is `workbench_theme.dart`'s: **square corners,
/// 1px hairline borders, no shadows, no cards.** What they deliberately
/// do NOT encode is density — padding and type here sit close to what
/// the pages already used, because the brief for this pass is that the
/// CHROME must match the workbench, not the line height. A page that
/// wants to be read is allowed to breathe.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart';

/// A titled section box.
///
/// The header is a strip on [WbColors.paneAltBg] with a hairline under
/// it and the body on [WbColors.paneBg] — the same two-tone shape as
/// `WbPaneTitle` over a pane, so a section on a page and a pane in the
/// workbench read as the same object at two sizes.
///
/// With no [title] it is just the box, which is what the lemma tables
/// and the distribution surfaces want.
class WbPanel extends StatelessWidget {
  const WbPanel({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
    this.alt = false,
    required this.child,
  });

  final IconData? icon;
  final String? title;
  final String? subtitle;

  /// Sits at the far end of the header strip — a count, a control.
  /// Ignored when there is no [title].
  final Widget? trailing;

  /// Padding around [child] only. The header strip has its own.
  final EdgeInsets padding;

  /// Fill the body with [WbColors.paneAltBg] instead of `paneBg`.
  ///
  /// This is the whole of what used to be a `primaryContainer` tint:
  /// "slightly more important than its neighbours" is a step in VALUE,
  /// not a wash of the seed colour, because the workbench reserves
  /// saturation for the version tag and the link blue. A tinted panel
  /// in a neutral window reads as decoration; a shaded one reads as
  /// structure.
  final bool alt;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final hasHeader = title != null;

    return Container(
      decoration: BoxDecoration(
        color: alt ? wb.paneAltBg : wb.paneBg,
        border: Border.all(color: wb.border, width: WbMetrics.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              decoration: BoxDecoration(
                color: wb.chromeBg,
                border: Border(
                  bottom:
                      BorderSide(color: wb.border, width: WbMetrics.hairline),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: t.text + 3, color: wb.mutedText),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title!,
                          style: TextStyle(
                            fontFamily: t.fontFamily,
                            fontSize: t.text + 1,
                            height: t.lineHeight,
                            fontWeight: FontWeight.w700,
                            color: wb.text,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontFamily: t.fontFamily,
                              fontSize: t.chrome,
                              height: t.lineHeight,
                              color: wb.mutedText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A short code printed next to something — `H3068`, `OT`, `NT`.
///
/// The hue moved from the FILL to the TEXT. That is not a preference:
/// it is how the workbench already prints a Strong's number after a
/// word ([WbColors.strongsLexical] green on no fill), and it is the
/// only version that survives the paper palette, where a Material
/// `shade100` pastel on cream loses its edge entirely.
class WbTag extends StatelessWidget {
  const WbTag({super.key, required this.text, this.color, this.dense = true});

  final String text;

  /// The distinction the tag is carrying — Hebrew vs Greek, OT vs NT.
  /// Defaults to muted, for a tag that is only a label.
  final Color? color;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: wb.paneAltBg,
        border: Border.all(color: wb.border, width: WbMetrics.hairline),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: t.fontFamily,
          fontSize: t.chrome,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: color ?? wb.mutedText,
        ),
      ),
    );
  }
}

/// One row inside a [WbPanel] — a passage, a book, a daily verse.
///
/// Hoverable when [onTap] is set, because that is what the rest of this
/// workspace does: a desktop tool tells you what is clickable by
/// lighting it under the pointer, not by drawing a raised card around
/// it. [WbColors.hoverBg] is the same fill the Browse window uses.
class WbTile extends StatelessWidget {
  const WbTile({
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(8, 6, 8, 6),
    this.alt = true,
    required this.child,
  });

  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Fill with `paneAltBg` so a row separates from the panel it sits
  /// in. Off for rows that are already inside an alternating list.
  final bool alt;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final body = Padding(padding: padding, child: child);
    if (onTap == null) {
      return Container(
        decoration: BoxDecoration(
          color: alt ? wb.paneAltBg : null,
          border: Border.all(color: wb.border, width: WbMetrics.hairline),
        ),
        child: body,
      );
    }
    return Material(
      color: alt ? wb.paneAltBg : wb.paneBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border, width: WbMetrics.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: wb.hoverBg,
        // The theme already kills the ripple globally; naming the
        // colours here keeps the row correct if it is ever rendered
        // outside the workbench theme.
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: body,
      ),
    );
  }
}
