/// 2026-08 (SeekSparks): the Workbench's window chrome — menu bar,
/// toolbar, pane title strips and status bar.
///
/// BibleWorks does not look like a modern app and that is the point: a
/// menu bar across the top, a strip of small icon buttons under it,
/// hairline-bordered panes with 21px grey title strips, and a status bar
/// at the bottom that reports whatever the mouse is over. Those four
/// pieces are most of what makes a window read as "professional desktop
/// tool" rather than "phone app stretched wide", and none of them
/// existed here.
///
/// Everything in this file draws from [WbColors] / [WbMetrics], so the
/// whole workspace stays on one rhythm.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show fullBibleVersionLabel, shortBibleVersionLabel;
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/version_gutter.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/overflow_hint_scroll.dart';

// ── Menu bar ────────────────────────────────────────────────────────

/// One entry in a drop-down menu. A null [onSelected] renders the item
/// greyed out, which is how a real menu says "exists, not available
/// right now" — better than hiding it and changing shape each time.
class WbMenuItem {
  const WbMenuItem(this.label, this.onSelected, {this.checked, this.shortcut});

  /// A horizontal rule between groups.
  const WbMenuItem.separator()
      : label = '',
        onSelected = null,
        checked = null,
        shortcut = null;

  final String label;
  final VoidCallback? onSelected;

  /// Non-null renders a check column — for toggles like "Search window".
  final bool? checked;

  /// Right-aligned accelerator hint, e.g. "Ctrl+F".
  final String? shortcut;

  bool get isSeparator => label.isEmpty && onSelected == null;
}

class WbMenu {
  const WbMenu(this.title, this.items);
  final String title;
  final List<WbMenuItem> items;
}

/// The menu bar strip. Click a title to open its menu.
class WorkbenchMenuBar extends StatelessWidget {
  const WorkbenchMenuBar({super.key, required this.menus, this.trailing});

  final List<WbMenu> menus;

  /// Right-aligned content — used for the version/build label, the way
  /// desktop apps put status at the far end of the bar.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final locale = context.watch<AppSettings>().locale;
    return Container(
      height: t.menuBarHeight,
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      // 2026-09-14: the menu titles scroll when they do not fit, the
      // same answer the toolbar below got and for the same reason. File
      // / View / Search / Tools / Resources / Help plus the build label
      // wanted 365px of a 320px screen with both sliders at maximum
      // (reader size 40, menu scale 1.5) — 45 pixels of Help and the
      // version number clipped off the right edge, which is the first
      // row on the screen. `minWidth` is the viewport, so nothing moves
      // at any width where the titles already fit, which is every
      // desktop size this tool is designed for.
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => OverflowHintScroll(
                fadeColor: wb.chromeBg,
                minWidth: box.maxWidth,
                moreLabel: uiStrings['moreActions']?[locale] ?? 'More',
                backLabel: uiStrings['moreActionsBack']?[locale] ??
                    'Previous actions',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in menus) _MenuTitle(menu: m),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

class _MenuTitle extends StatelessWidget {
  const _MenuTitle({required this.menu});
  final WbMenu menu;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    // 2026-09-14: the surface comes from `popupMenuTheme` — paneBg, a
    // hairline, elevation 0 and `radiusSurface` corners. This call site
    // used to restate all four and get two of them wrong: square corners
    // and a shadow, both retired on 2026-09-07 when the owner asked for
    // "最现代的界面风格". The File/View/Search menus are the first thing
    // on the screen, so they were the most visible copy of the old rule
    // left in the app.
    return PopupMenuButton<VoidCallback>(
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 0),
      padding: EdgeInsets.zero,
      onSelected: (cb) => cb(),
      itemBuilder: (context) => [
        for (final item in menu.items)
          if (item.isSeparator)
            const PopupMenuDivider(height: 5)
          else
            PopupMenuItem<VoidCallback>(
              value: item.onSelected,
              enabled: item.onSelected != null,
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: item.checked == true
                        ? Icon(Icons.check, size: 12, color: wb.text)
                        : null,
                  ),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: t.chrome,
                      color: item.onSelected == null ? wb.mutedText : wb.text,
                    ),
                  ),
                  if (item.shortcut != null) ...[
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        item.shortcut!,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: t.chrome,
                          color: wb.mutedText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ],
      child: _HoverBox(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Center(
          child: Text(
            menu.title,
            style: TextStyle(fontSize: t.chrome, color: wb.text),
          ),
        ),
      ),
    );
  }
}

// ── Toolbar ─────────────────────────────────────────────────────────

class WbToolButton {
  const WbToolButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Drawn pressed-in, for toggles that are currently on.
  final bool active;

  /// Prints the label beside the icon. Used for the Browse/Reader mode
  /// switch: two book-ish glyphs side by side are indistinguishable, and
  /// a reader who lands in the wrong mode has no way to guess the way
  /// back. Everything else stays icon-only.
  final String? label;
}

/// A strip of small square icon buttons, separated into groups.
class WorkbenchToolbar extends StatelessWidget {
  const WorkbenchToolbar({super.key, required this.groups});

  /// Each inner list is a group; groups are divided by a vertical rule.
  final List<List<WbToolButton>> groups;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final locale = context.watch<AppSettings>().locale;
    return Container(
      height: t.toolbarHeight,
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      // 2026-09-14: the toolbar scrolls when it does not fit.
      //
      // It was a bare Row, and a bare Row that runs out of width does not
      // shrink or wrap — it overflows and CLIPS. Measured at 320x568
      // (iPhone SE, and the same build ships there): 18 pixels off the
      // right, which is Settings, with nothing on screen to say the
      // control exists. In a debug build that is the yellow-and-black
      // hazard band; in release it is silence.
      //
      // `OverflowHintScroll` is the app's existing answer to this — the
      // reading pane's selection bar and the projection control strip
      // both use it — and it is the right one here for the reason the
      // brief gives: the toolbar must not respond to a narrow window by
      // shrinking its targets or hiding commands. It fades the edge that
      // has more behind it and puts a tappable chevron there, so the
      // reader can see that the strip continues.
      //
      // `minWidth` is the viewport, so nothing changes at any width where
      // the Row already fits — which is every desktop size this tool is
      // designed for. Found by adding WorkbenchPage to
      // `test/responsive_overflow_smoke_test.dart`, which had covered
      // About, Settings and Library and skipped the screen the app opens
      // on.
      child: LayoutBuilder(
        builder: (context, box) => OverflowHintScroll(
          fadeColor: wb.chromeBg,
          minWidth: box.maxWidth,
          moreLabel: uiStrings['moreActions']?[locale] ?? 'More',
          backLabel:
              uiStrings['moreActionsBack']?[locale] ?? 'Previous actions',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var g = 0; g < groups.length; g++) ...[
                if (g > 0)
                  Container(
                    width: WbMetrics.hairline,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: wb.border,
                  ),
                for (final b in groups[g]) WbToolIcon(button: b),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One small square icon button, as drawn in the toolbar and at the
/// right end of a pane title.
///
/// Public since 2026-08-09 (task #284): a pane that carries its own
/// action — the Word Study tab's "copy word table" — has to draw the
/// same button, and re-deriving 15px/`mutedText`/square-hover by hand is
/// how a second chrome dialect starts.
class WbToolIcon extends StatelessWidget {
  const WbToolIcon({super.key, required this.button});
  final WbToolButton button;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final enabled = button.onPressed != null;
    return Tooltip(
      message: button.tooltip,
      child: _HoverBox(
        onTap: button.onPressed,
        baseColor: button.active ? wb.selectionBg : null,
        padding: EdgeInsets.symmetric(horizontal: button.label == null ? 5 : 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              button.icon,
              size: 15,
              // 2026-09-08: `disabledMark`, not an ad-hoc 50% muted.
              // `enabled` here is `onPressed != null` — genuinely
              // inactive, unlike the status fields and the operator
              // buttons, which stay tappable while drawn back and were
              // both raised to full `mutedText` the same day. The token
              // exists to say exactly this, and saying it in the token
              // is what lets `palette_legibility_walk_test.dart` tell an
              // exempt control from an unreadable one.
              color: enabled ? wb.text : wb.disabledMark,
            ),
            if (button.label != null) ...[
              const SizedBox(width: 4),
              Text(
                button.label!,
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: button.active ? FontWeight.w700 : FontWeight.w400,
                  color: enabled ? wb.text : wb.mutedText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Pane title strip ────────────────────────────────────────────────

/// The thin grey strip at the top of a pane. Replaces the tall icon
/// headers the Workbench inherited from the phone UI.
class WbPaneTitle extends StatelessWidget {
  const WbPaneTitle({
    super.key,
    required this.title,
    this.trailing = const [],
    this.onTitleTap,
  });

  final String title;

  /// Small icon buttons at the right end of the strip.
  final List<WbToolButton> trailing;

  /// Makes the title itself a control. Used by the Browse window, whose
  /// title lists the active versions — clicking that list to change it
  /// is what a reader tries first.
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Container(
      height: t.paneTitleHeight,
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        children: [
          Expanded(
            child: _HoverBox(
              onTap: onTitleTap,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontWeight: FontWeight.w600,
                    color: wb.text,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
          for (final b in trailing) WbToolIcon(button: b),
        ],
      ),
    );
  }
}

// ── Status bar ──────────────────────────────────────────────────────

/// The bar along the bottom. BibleWorks reports the word under the
/// cursor here — lemma, parsing, gloss — which is why you can read the
/// text with the mouse and never open a dialog. [message] is whatever
/// the hover target last reported; [fields] are the persistent
/// right-hand readouts (version, reference, verse count).
/// One clickable readout in the status bar.
///
/// From the manual: "Many options can also be changed by double-clicking
/// on the various status windows. When a particular option is disabled
/// the text … will be grayed out." So these are controls, not labels —
/// which is why the status bar is worth its 20 pixels.
class WbStatusField {
  const WbStatusField(this.label, {this.enabled = true, this.onTap});

  final String label;

  /// Greyed when false, exactly as BibleWorks reports a disabled option.
  final bool enabled;

  /// Fired on double-tap, matching the desktop convention. Null makes
  /// the field a plain readout.
  final VoidCallback? onTap;
}

class WorkbenchStatusBar extends StatelessWidget {
  const WorkbenchStatusBar({
    super.key,
    required this.message,
    this.fields = const [],
  });

  final String message;
  final List<WbStatusField> fields;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Container(
      height: t.statusBarHeight,
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(top: BorderSide(color: wb.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.chrome,
                color: message.isEmpty ? wb.mutedText : wb.text,
              ),
            ),
          ),
          for (final f in fields) ...[
            Container(
              width: WbMetrics.hairline,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: wb.border,
            ),
            Tooltip(
              message: f.onTap == null ? '' : 'Double-click to change',
              child: _HoverBox(
                onDoubleTap: f.onTap,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  f.label,
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontWeight: f.enabled ? FontWeight.w600 : FontWeight.w400,
                    // 2026-09-08: was `.withValues(alpha: 0.55)`, 1.98:1
                    // on the chrome. `enabled` here means the thing the
                    // field CONTROLS is on — Limits is "off" when
                    // nothing is limiting — and the field stays
                    // double-clickable either way, so this is a live
                    // control that could not be read. The weight above
                    // already carries the distinction on its own
                    // channel; the colour does not have to spend
                    // legibility to repeat it.
                    color: f.enabled ? wb.text : wb.mutedText,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Version tag ─────────────────────────────────────────────────────

/// The short coloured version code printed at the start of a line.
///
/// This is the single most load-bearing visual device in BibleWorks: in
/// a wall of interleaved parallel text you find the version you want by
/// colour, without reading. Rendered inline (not as a chip on its own
/// row) so it costs no vertical space.
class WbVersionTag extends StatelessWidget {
  const WbVersionTag({super.key, required this.code, this.width});

  /// A version CODE (`cuvs-yhwh`, `kjv`), or one of the Browse window's
  /// two original-language pseudo-codes (`wtt` / `bgt`).
  ///
  /// NOT a label — it used to be, and that is what made the per-version
  /// colour map key on display text, so renaming an edition detached it
  /// from its hue. Looking both the text and the colour up from one key
  /// removes that whole class of bug.
  final String code;

  /// Fixed width so the text of every version starts on the same column.
  /// That alignment is the point of the gutter — it is what lets the eye
  /// run down one translation in a wall of interleaved rows — so this
  /// stays fixed rather than sizing to content.
  ///
  /// Null means "wide enough for this one label". A caller rendering a
  /// STACK of editions passes a single [versionGutterWidth] computed
  /// over the whole stack instead, so they share one column.
  ///
  /// This was a hard-coded 92 and was wrong three times (52 → 68 → 92);
  /// `lib/utils/version_gutter.dart` documents both reasons, the second
  /// of which — the reader's `menuScale` multiplies the type size but
  /// not the box — was still live at 92.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    final fontSize = t.chrome - 0.5;
    final label = shortBibleVersionLabel(code).toUpperCase();
    // 2026-09-08: the tag says what it can fit; the tooltip says what it
    // means. Reported as 「BGT BSB 雅简这些别人看简写不知道什么意思」 — a
    // parallel view has room for four characters and no room for
    // 和合本雅伟版(简体), so the gutter had been printing a code the
    // reader was expected to already know.
    //
    // `triggerMode: tap` matters more than the tooltip does. A hover
    // tooltip answers the question on a desktop and leaves it unanswered
    // on the iPad and the phone, which is where an unfamiliar reader
    // actually is. Tap is the gesture they will try, and this is the
    // pattern `browse_window.dart` already uses for its two other
    // explain-yourself affordances.
    return Tooltip(
      message: fullBibleVersionLabel(code),
      triggerMode: TooltipTriggerMode.tap,
      child: SizedBox(
        width: width ?? versionGutterWidthForLabels([label], fontSize),
        child: Text(
          label,
          maxLines: 1,
          // Ellipsis, not clip. If a future label outgrows the gutter
          // again, "CUV+S…" is honest about being shortened; "CUV+S("
          // looks like the string itself is damaged.
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: t.lineHeight,
            color: versionTagColor(code),
            letterSpacing: 0.2,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      ),
    );
  }
}

// ── Shared hover affordance ─────────────────────────────────────────

/// Fills with [WbColors.hoverBg] under the mouse. A desktop tool
/// signals affordance by hovering, not by rippling on release, so this
/// is used for every clickable chrome element.
class _HoverBox extends StatefulWidget {
  const _HoverBox({
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.padding = EdgeInsets.zero,
    this.baseColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final EdgeInsets padding;
  final Color? baseColor;

  @override
  State<_HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<_HoverBox> {
  bool _hovering = false;
  bool _focused = false;

  /// How much of the pane's ink a hover lays over a fill that is
  /// already saying something.
  ///
  /// Measured rather than chosen: over `selectionBg` this is a 1.21
  /// step in light and 1.32 in dark, against the 1.111 that plain
  /// `hoverBg` makes over `paneBg` — so it is at least as visible as
  /// the hover this app already relies on, and it stays inside the
  /// selection's own hue. Blending `hoverBg` over the selection was
  /// tried and measured first: it lands within 1.04 of `hoverBg`
  /// itself, which is the bug rather than the fix.
  static const double _kActiveHoverInk = 0.10;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final interactive = widget.onTap != null || widget.onDoubleTap != null;
    final onTap = widget.onTap;
    final minTarget = WbMetrics.minTarget(Theme.of(context).platform);

    // Hover is a step FROM the current fill, not a replacement for it.
    //
    // It used to be `_hovering ? wb.hoverBg : widget.baseColor`, so
    // putting the pointer on a toggle that was ON — "Hide Strong's
    // numbers", say — dropped `selectionBg` and painted the ordinary
    // hover instead. The only signal that the toggle was on vanished
    // at the exact moment the reader was aiming at it.
    final base = widget.baseColor;
    final Color? fill = !(interactive && _hovering)
        ? base
        : base == null
            ? wb.hoverBg
            : Color.alphaBlend(
                wb.text.withValues(alpha: _kActiveHoverInk), base);

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      // Every chrome control in this workspace is drawn by this box, so
      // this is the one place that decides whether the Workbench can be
      // driven from the keyboard. Until 2026-09-14 the answer was no:
      // of 499 tappable nodes on the Browse screen only 41 were in the
      // tab order, and the whole top strip — Next chapter, Search,
      // Analysis, Choose versions, Command line, Copy Center, Settings
      // — was outside it. A `MouseRegion` over a `GestureDetector`
      // creates no focus node, so the engine never exposes anything to
      // focus. The library doc calls this "a dense, flat, neutral,
      // keyboard-driven desktop tool"; that word is the requirement.
      child: FocusableActionDetector(
        enabled: interactive,
        mouseCursor: MouseCursor.defer,
        onShowFocusHighlight: (v) {
          if (v != _focused) setState(() => _focused = v);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: widget.padding,
            color: fill,
            // A FOREGROUND decoration: the ring is painted over the
            // control rather than added to it, so a focused button is
            // the same size as an unfocused one and the strip does not
            // reflow as the reader tabs along it.
            foregroundDecoration: _focused
                ? BoxDecoration(
                    border: Border.all(color: wb.link, width: 2),
                    borderRadius:
                        BorderRadius.circular(WbMetrics.radiusControl),
                  )
                : null,
            // 2026-09-14: on a touch device the control cannot be
            // smaller than `WbMetrics.minTarget` — 24px, WCAG 2.5.8.
            // Every chrome control in the workspace is drawn by this
            // box, which is why the rule can live in one place; the
            // reasoning, and why it is 24 rather than Apple's 44 or
            // Material's 48, is on `minTarget` itself.
            //
            // `Align` with both factors at 1, inside a `ConstrainedBox`,
            // rather than an alignment on the Container: an aligned
            // Container expands to its constraints, and in a Row the
            // main axis is unbounded, so that route asserts instead of
            // centring. This one takes the child's size, raises it to
            // the minimum, and centres the glyph in what is left.
            child: minTarget == 0
                ? widget.child
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: minTarget,
                      minHeight: minTarget,
                    ),
                    child: Align(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: widget.child,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
