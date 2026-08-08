/// 2026-08-08 (task #288): the Browse stack's editor — which editions
/// the centre pane shows, **and in what order**.
///
/// What it replaces was a `showModalBottomSheet` full of
/// `CheckboxListTile`s with no confirm control, no cancel, and this
/// comment at the call site: *"Registry order, because a checkbox list
/// cannot express an order."* It was right about the checkbox list and
/// wrong to settle for it — a reader who had built the stack
/// `雅简+ · LXX+WH · BSB` from the command line lost that arrangement
/// the moment they opened the picker to add a fourth column.
///
/// **Staged, not live**, for the same three reasons as the scope sheet
/// plus one of its own: applying parses an edition's JSON, so four
/// toggles on the way to a two-version answer would parse two editions
/// nobody asked to see; and a drag is far easier to do by accident than
/// a checkbox is, so reordering without a Cancel is a trap. Dismissing —
/// the ×, Esc, the scrim, a swipe — is therefore a CANCEL and returns
/// null. That is a behaviour change: the old sheet applied on dismiss
/// and had no other way to apply at all, which is neither model.
///
/// BibleWorks' two equivalents are both staged and both two-box: the
/// Parallel Versions Window (bwh38) moves rows from "Available Bible
/// Versions" into "Versions to Display in Parallel" and orders them with
/// up/down before an OK; `View | Version Display Order` (bwh29) is a
/// list of Move Up / Move Down / Move to Top / Move to Bottom over
/// *every* installed version, with a **Show Active Only** checkbox
/// because ordering the long list is otherwise unusable. A "displayed"
/// section stacked over an "available" one is that checkbox, made
/// structural — the rows you can order are the rows you are ordering.
///
/// Not built here, and the honest next step: BibleWorks saves an order
/// to a named `.vdo` file recallable as `<o grkheb>`, and saves version
/// sets as Parallel Versions Favorites. One stack, remembered, is the
/// slice that stands on its own; named sets need a manager, and the
/// Verse List Manager is the precedent for how much that costs.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/version_stack.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart' show WbVersionTag;

/// Opens the picker. Returns the new COMPARISON list — the display stack
/// without the reading version, which is what
/// `WorkbenchProvider.parallelVersions` stores — or null if the reader
/// cancelled.
Future<List<String>?> showVersionStackSheet({
  required BuildContext context,
  required String locale,
  required String reading,
  required List<String> comparisons,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    // Square, per workbench_theme: the sheet is a window edge, not a card.
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    // Ten rows of a two-word label do not want 1440px of width. The
    // scope sheet spans the window because 66 book chips need the room;
    // this one would just push its remove buttons out of sight of the
    // labels they belong to.
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => VersionStackSheet(
      locale: locale,
      reading: reading,
      comparisons: comparisons,
    ),
  );
}

class VersionStackSheet extends StatefulWidget {
  const VersionStackSheet({
    super.key,
    required this.locale,
    required this.reading,
    required this.comparisons,
  });

  final String locale;

  /// The edition being read. Always the first column, never movable,
  /// never removable — see `version_stack.dart` for why that invariant
  /// belongs to the command line as much as to this sheet.
  final String reading;

  final List<String> comparisons;

  @override
  State<VersionStackSheet> createState() => _VersionStackSheetState();
}

class _VersionStackSheetState extends State<VersionStackSheet> {
  late List<String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = normaliseComparisons(widget.comparisons, widget.reading);
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  String _langLabel(String lang) => switch (lang) {
        'en' => _s('versionLangEnglish', 'English'),
        'zh-Hant' => _s('versionLangTraditional', 'Traditional'),
        'grc' => _s('versionLangGreek', 'Greek'),
        _ => _s('versionLangSimplified', 'Simplified'),
      };

  void _toggle(String code) => setState(
      () => _draft = toggleComparison(_draft, code, widget.reading));

  void _reorder(int oldIndex, int newIndex) =>
      setState(() => _draft = moveComparison(_draft, oldIndex, newIndex));

  void _apply() => Navigator.of(context).pop(_draft);

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final chosen = _draft.toSet();
    final available = [
      for (final lang in bibleLanguageOrder)
        (
          lang,
          [
            for (final v in versionsForLanguage(lang))
              if (v.value != widget.reading && !chosen.contains(v.value)) v,
          ]
        ),
    ].where((g) => g.$2.isNotEmpty).toList();

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): _apply,
      },
      child: FocusScope(
        autofocus: true,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title(wb, t),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    children: [
                      _sectionLabel(
                        wb,
                        t,
                        _s('versionStackShown', 'In display order'),
                        trailing: _draft.length > 1
                            ? Text(
                                _s('versionStackReorderHint',
                                    'Drag to reorder'),
                                style: TextStyle(
                                    fontSize: t.chrome, color: wb.mutedText),
                              )
                            : null,
                      ),
                      _readingRow(wb, t),
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, _, __) => _lifted(wb, child),
                        onReorderItem: _reorder,
                        children: [
                          for (var i = 0; i < _draft.length; i++)
                            _chosenRow(wb, t, _draft[i], i),
                        ],
                      ),
                      if (available.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _sectionLabel(
                            wb, t, _s('versionStackAvailable', 'Available')),
                        for (final group in available) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 6, 0, 2),
                            child: Text(
                              _langLabel(group.$1),
                              style: TextStyle(
                                fontSize: t.chrome,
                                color: wb.mutedText,
                                fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                          ),
                          for (final v in group.$2) _availableRow(wb, t, v),
                        ],
                      ],
                    ],
                  ),
                ),
                _actions(wb, t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(WbColors wb, WbType t) => Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: wb.chromeBg,
          border: Border(
              bottom: BorderSide(color: wb.border, width: WbMetrics.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _s('versionStackTitle', 'Versions displayed'),
                style: TextStyle(
                  fontSize: t.text,
                  fontWeight: FontWeight.w700,
                  color: wb.text,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: uiStrings['cancel']?[widget.locale] ?? 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

  Widget _sectionLabel(WbColors wb, WbType t, String text, {Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w700,
                  color: wb.mutedText,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );

  /// Row 1 of the stack, drawn like the others and inert: no handle, no
  /// remove button, and the reason printed on it. A reader who cannot
  /// move the top row needs to be told why on the row itself — an
  /// affordance that is simply absent reads as a bug.
  Widget _readingRow(WbColors wb, WbType t) => _row(
        wb,
        key: const ValueKey<String>('version-stack-reading'),
        code: widget.reading,
        leading: SizedBox(
          width: 22,
          child: Icon(Icons.lock_outline, size: 12, color: wb.mutedText),
        ),
        trailing: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            _s('versionStackReading', 'reading'),
            style: TextStyle(
              fontSize: t.chrome,
              color: wb.mutedText,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
        t: t,
      );

  Widget _chosenRow(WbColors wb, WbType t, String code, int index) => _row(
        wb,
        key: ValueKey<String>('version-stack-$code'),
        code: code,
        leading: ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: SizedBox(
              width: 22,
              child: Icon(Icons.drag_indicator, size: 14, color: wb.mutedText),
            ),
          ),
        ),
        trailing: IconButton(
          // Not a bare ×: the sheet's title bar has one and it means
          // "cancel the whole edit". Two closes, two scopes, one icon is
          // how a reader loses a stack they meant to keep.
          icon: const Icon(Icons.remove_circle_outline, size: 13),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 26, height: 22),
          tooltip: _s('versionStackRemove', 'Remove'),
          onPressed: () => _toggle(code),
        ),
        t: t,
      );

  Widget _availableRow(WbColors wb, WbType t, BibleVersionInfo v) => _row(
        wb,
        key: ValueKey<String>('version-stack-available-${v.value}'),
        code: v.value,
        muted: true,
        onTap: () => _toggle(v.value),
        leading: SizedBox(
          width: 22,
          child: Icon(Icons.add, size: 13, color: wb.mutedText),
        ),
        trailing: null,
        t: t,
      );

  Widget _row(
    WbColors wb, {
    required Key key,
    required String code,
    required Widget leading,
    required Widget? trailing,
    required WbType t,
    bool muted = false,
    VoidCallback? onTap,
  }) {
    final body = Container(
      decoration: BoxDecoration(
        color: muted ? wb.paneBg : wb.paneAltBg,
        border: Border.all(color: wb.border, width: WbMetrics.hairline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          leading,
          WbVersionTag(code: code),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              menuBibleVersionLabel(code),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.text,
                color: muted ? wb.mutedText : wb.text,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 2),
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              hoverColor: wb.hoverBg,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: body,
            ),
    );
  }

  /// The dragged row, without Material's default elevation — a shadow is
  /// the one thing workbench_theme forbids outright, so the lift is drawn
  /// with the selection ground and a solid border instead.
  Widget _lifted(WbColors wb, Widget child) => Material(
        color: wb.selectionBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: wb.text, width: WbMetrics.hairline),
        ),
        child: child,
      );

  /// The desktop dialog's OK/Cancel row, pinned to the bottom over a
  /// hairline. It carries the count so the row earns its height — and
  /// the count is of the whole stack, reading version included, because
  /// that is the number of columns the reader is about to see.
  Widget _actions(WbColors wb, WbType t) {
    final total = _draft.length + 1;
    final summary = _draft.isEmpty
        ? _s('versionStackOnlyReading', 'Only the edition you are reading')
        : _s('versionStackCount', '{count} versions displayed')
            .replaceAll('{count}', '$total');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border:
            Border(top: BorderSide(color: wb.border, width: WbMetrics.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: FontWeight.w600,
                color: _draft.isEmpty ? wb.mutedText : wb.text,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ),
          TextButton(
            onPressed:
                _draft.isEmpty ? null : () => setState(() => _draft = []),
            child: Text(_s('versionStackClear', 'Remove all'),
                style: TextStyle(
                    fontSize: t.chrome, fontFamilyFallback: kCjkFontFallback)),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _apply,
            child: Text(_s('scopeApply', 'Apply'),
                style: TextStyle(
                    fontSize: t.chrome, fontFamilyFallback: kCjkFontFallback)),
          ),
        ],
      ),
    );
  }
}
