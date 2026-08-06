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

import 'package:seeksparks/constants/workbench_theme.dart';

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
    return Container(
      height: t.menuBarHeight,
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      child: Row(
        children: [
          for (final m in menus) _MenuTitle(menu: m),
          const Spacer(),
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
    return PopupMenuButton<VoidCallback>(
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 0),
      padding: EdgeInsets.zero,
      color: wb.paneBg,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border),
      ),
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
                          fontSize: t.chrome - 1,
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
    return Container(
      height: t.toolbarHeight,
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      child: Row(
        children: [
          for (var g = 0; g < groups.length; g++) ...[
            if (g > 0)
              Container(
                width: WbMetrics.hairline,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: wb.border,
              ),
            for (final b in groups[g]) _ToolIcon(button: b),
          ],
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.button});
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
              color: enabled ? wb.text : wb.mutedText.withValues(alpha: 0.5),
            ),
            if (button.label != null) ...[
              const SizedBox(width: 4),
              Text(
                button.label!,
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight:
                      button.active ? FontWeight.w700 : FontWeight.w400,
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
          for (final b in trailing) _ToolIcon(button: b),
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
                    fontWeight:
                        f.enabled ? FontWeight.w600 : FontWeight.w400,
                    color: f.enabled
                        ? wb.text
                        : wb.mutedText.withValues(alpha: 0.55),
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
  const WbVersionTag({super.key, required this.code, this.width = 52});

  final String code;

  /// Fixed width so the text of every version starts on the same column.
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    return SizedBox(
      width: width,
      child: Text(
        code.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: t.chrome - 0.5,
          fontWeight: FontWeight.w700,
          height: t.lineHeight,
          color: versionTagColor(code),
          letterSpacing: 0.2,
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

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final interactive = widget.onTap != null || widget.onDoubleTap != null;
    return MouseRegion(
      cursor: interactive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: widget.padding,
          color: _hovering && interactive ? wb.hoverBg : widget.baseColor,
          child: widget.child,
        ),
      ),
    );
  }
}
