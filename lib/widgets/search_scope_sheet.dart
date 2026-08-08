/// 2026-08-08 (task #280): the scope picker — bwh29's book tree, in the
/// shape this workspace uses.
///
/// BibleWorks reaches "Setting Search Limits" from four places (the
/// Search menu, the command-line options button, `limits rom 1:1-10`,
/// and a double-click on the status bar's Limits field) because a
/// narrowed search is the one state a reader most often forgets they
/// are in. SeekSparks had only the fourth kind of entry — the `l` verb —
/// so the feature existed and was unreachable without documentation.
///
/// Staged, not live: applying a book set re-runs the last query, and a
/// tree of 66 checkboxes that each re-ran a search would be unusable.
/// So the sheet owns a draft and hands it back on Apply; the caller
/// installs it. Returns null when dismissed, which is a CANCEL — the
/// draft is discarded and the active scope is untouched.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/command_verb.dart' show LimitSpec;
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/search_scope.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// Opens the picker over [context]. Returns the chosen book set, or
/// null if the reader dismissed it. An EMPTY set is a real answer — it
/// means "no limit", and is why this cannot signal cancel with empty.
Future<Set<String>?> showSearchScopeSheet({
  required BuildContext context,
  required String locale,
  required String? version,
  required LimitSpec? activeSpec,
  required String? activeFallbackLabel,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    // Square, per workbench_theme: the sheet is a window edge, not a card.
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => SearchScopeSheet(
      locale: locale,
      version: version,
      activeSpec: activeSpec,
      activeFallbackLabel: activeFallbackLabel,
    ),
  );
}

class SearchScopeSheet extends StatefulWidget {
  const SearchScopeSheet({
    super.key,
    required this.locale,
    required this.version,
    required this.activeSpec,
    required this.activeFallbackLabel,
  });

  final String locale;

  /// Which edition's book naming to print — book names follow the
  /// READING version, not the UI locale (#283).
  final String? version;

  final LimitSpec? activeSpec;

  /// The Verse List Manager's list name, when the active limit came
  /// from there and has no ranges to read back.
  final String? activeFallbackLabel;

  @override
  State<SearchScopeSheet> createState() => _SearchScopeSheetState();
}

class _SearchScopeSheetState extends State<SearchScopeSheet> {
  late Set<String> _selected;

  /// True when there IS an active limit that this sheet cannot show —
  /// a chapter range from `l matt 5-7`, or a verse list. The draft then
  /// starts empty and the sheet says so, rather than presenting a
  /// widened version of the reader's own scope as if it were theirs.
  late bool _unrepresentable;

  @override
  void initState() {
    super.initState();
    final spec = widget.activeSpec;
    final books = spec == null ? null : wholeBooksOfSpec(spec);
    _selected = {...?books};
    _unrepresentable =
        (spec != null && books == null) || (spec == null && _hasFallback);
  }

  bool get _hasFallback =>
      widget.activeFallbackLabel != null &&
      widget.activeFallbackLabel!.isNotEmpty;

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  void _toggleBook(String book) => setState(() {
        _unrepresentable = false;
        if (!_selected.remove(book)) _selected.add(book);
      });

  /// A group chip is a three-state control, not a checkbox: fully
  /// selected → deselect those books; otherwise → add them all. That
  /// makes "Pentateuch, plus Joshua" reachable in two taps and keeps
  /// the chip honest about what it is showing.
  void _toggleGroup(ScopeGroup g) => setState(() {
        _unrepresentable = false;
        if (_selected.containsAll(g.books)) {
          _selected.removeAll(g.books);
        } else {
          _selected.addAll(g.books);
        }
      });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    // Leaves the sheet short when the list is short and caps it well
    // below full height, so the reader keeps sight of what they are
    // scoping.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

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
                      if (_unrepresentable) _notice(wb, t),
                      _sectionLabel(
                          wb, t, _s('scopeGroupsLabel', 'Common ranges')),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final g in kScopeGroups)
                            _chip(
                              wb,
                              t,
                              label: _s(g.key, g.key),
                              selected: _selected.containsAll(g.books),
                              onTap: () => _toggleGroup(g),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _books(wb, t, 'oldTestament', canonicalOtBooks),
                      const SizedBox(height: 10),
                      _books(wb, t, 'newTestament', canonicalNtBooks),
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
                _s('scopeTitle', 'Search scope'),
                style: TextStyle(
                  fontSize: t.text,
                  fontWeight: FontWeight.w700,
                  color: wb.text,
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

  Widget _notice(WbColors wb, WbType t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          _s(
                  'scopeNotBookShaped',
                  'The active limit ({name}) is not a whole-book '
                      'selection. Choosing books here replaces it.')
              .replaceAll('{name}', _activeName()),
          style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
        ),
      );

  String _activeName() => scopeDisplayName(
        spec: widget.activeSpec,
        fallbackLabel: widget.activeFallbackLabel,
        locale: widget.locale,
        version: widget.version,
      );

  Widget _sectionLabel(WbColors wb, WbType t, String text,
          {Widget? trailing}) =>
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
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );

  Widget _books(WbColors wb, WbType t, String titleKey, List<String> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(wb, t, _s(titleKey, titleKey)),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final b in books)
              _chip(
                wb,
                t,
                label: localeAwareBookName(b, widget.locale, widget.version),
                selected: _selected.contains(b),
                onTap: () => _toggleBook(b),
              ),
          ],
        ),
      ],
    );
  }

  /// Selected state on INK and VALUE, never on a hue: a filled chip in
  /// the selection colour with the body text on it, against an outlined
  /// chip in muted text. The workbench spends saturation on exactly two
  /// things and neither of them is a checkbox.
  Widget _chip(
    WbColors wb,
    WbType t, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? wb.selectionBg : wb.paneBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: selected ? wb.text : wb.border,
          width: WbMetrics.hairline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: wb.hoverBg,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: t.fontFamily,
              fontSize: t.chrome,
              height: 1.0,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? wb.text : wb.mutedText,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
      ),
    );
  }

  /// The desktop dialog's OK/Cancel row, pinned to the bottom over a
  /// hairline — not a floating corner button. It carries the count so
  /// the row earns its height, which is also the one place the reader
  /// can see what they are about to apply without counting chips.
  Widget _actions(WbColors wb, WbType t) {
    final count = _selected.length;
    final summary = count == 0
        ? _s('scopeNoneSelected', 'No limit — the whole Bible')
        : _s('scopeSelected', '{count} books selected')
            .replaceAll('{count}', '$count');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(
            top: BorderSide(color: wb.border, width: WbMetrics.hairline)),
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
                color: count == 0 ? wb.mutedText : wb.text,
              ),
            ),
          ),
          TextButton(
            onPressed:
                count == 0 ? null : () => setState(() => _selected.clear()),
            child: Text(_s('scopeClearAll', 'Clear all'),
                style: TextStyle(fontSize: t.chrome)),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _apply,
            child: Text(_s('scopeApply', 'Apply'),
                style: TextStyle(fontSize: t.chrome)),
          ),
        ],
      ),
    );
  }

  void _apply() => Navigator.of(context).pop(_selected);
}
