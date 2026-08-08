/// 2026-08-07 (SeekSparks): the Verse List Manager pane — BibleWorks
/// help topic bwh27.
///
/// The logic is all in `utils/verse_list.dart`; this file is the VLM's
/// menus and rows. Two adaptations to a 320–560 px analysis pane, both
/// deliberate:
///
///   * BibleWorks shows both lists side by side in a floating window.
///     There is no room for two columns here, so ONE list is shown at a
///     time and the header carries both names with their counts —
///     which is exactly the `Active List: Main / Secondary` radio pair
///     BibleWorks already has, doing double duty as the comparison
///     readout. Every menu action applies to the active list, as bwh27
///     specifies, and the comparison items name the other list so it is
///     never ambiguous which side you are operating on.
///   * BibleWorks' menu bar becomes four popup menus (Import, Edit,
///     Select, File) with the same items under the same headings, so
///     the help file still describes this pane.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/verse_list_store.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/scripture_markup.dart';
import 'package:seeksparks/utils/verse_list.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/widgets/wb_pane_bits.dart';

/// Which VLM menu an item belongs to — one enum per popup so the
/// callbacks stay flat.
enum _ImportAction { currentVerse, searchResults, fromText }

enum _EditAction { sort, deleteSelected, copyToOther, clear }

enum _SelectAction { all, none, invert, common, unique }

enum _FileAction { saveAs, open, deleteSaved, copyText }

class VerseListPane extends StatefulWidget {
  const VerseListPane({
    super.key,
    required this.locale,
    required this.version,
    required this.verseByRef,
    required this.currentRef,
    required this.searchResults,
    required this.searchLimitActive,
    required this.onOpenRef,
    required this.onSetSearchLimit,
  });

  final String locale;
  final String version;

  /// `'EnglishBook-chapter-verse'` → verse, from
  /// `WorkbenchProvider.verseByRef`. Used to print each row's text and
  /// to work out how long a chapter is when expanding "John 3".
  final Map<String, Verse> verseByRef;

  /// The verse the reader is on — `Import ▸ Current verse`.
  final VerseRef? currentRef;

  /// The command pane's current result list — `Import ▸ Search
  /// results`. Already flattened to refs so this pane need not know
  /// whether the search was a text scan or a Strong's lookup.
  final List<VerseRef> searchResults;

  /// Whether a verse list is currently limiting searches.
  final bool searchLimitActive;

  final void Function(VerseRef ref) onOpenRef;

  /// Set (or, with null, clear) the search limit. bwh29 / bwh44:
  /// a verse list is a search scope, not just an archive.
  final void Function(VerseList? list) onSetSearchLimit;

  @override
  State<VerseListPane> createState() => _VerseListPaneState();
}

class _VerseListPaneState extends State<VerseListPane> {
  VerseList _main = VerseList.empty;
  VerseList _secondary = VerseList.empty;
  bool _activeIsMain = true;
  Map<String, VerseList> _saved = const {};
  bool _restored = false;

  final _addCtrl = TextEditingController();

  /// `'Book-chapter'` → highest verse number present in the corpus.
  /// Built once per corpus so `expandReference` can turn a chapter-only
  /// reference into its verses.
  Map<String, int>? _chapterLengths;
  Map<String, Verse>? _chapterLengthsSource;

  VerseList get _active => _activeIsMain ? _main : _secondary;
  VerseList get _inactive => _activeIsMain ? _secondary : _main;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final (main, secondary) = await VerseListStore.loadWorkspace();
    final saved = await VerseListStore.loadSaved();
    if (!mounted) return;
    setState(() {
      _main = main;
      _secondary = secondary;
      _saved = saved;
      _restored = true;
    });
  }

  void _setActive(VerseList next) {
    setState(() {
      if (_activeIsMain) {
        _main = next;
      } else {
        _secondary = next;
      }
    });
    VerseListStore.saveWorkspace(_main, _secondary);
  }

  void _setBoth(VerseList active, VerseList inactive) {
    setState(() {
      if (_activeIsMain) {
        _main = active;
        _secondary = inactive;
      } else {
        _secondary = active;
        _main = inactive;
      }
    });
    VerseListStore.saveWorkspace(_main, _secondary);
  }

  String _t(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  // ── Chapter lengths ───────────────────────────────────────────────

  int _chapterLength(String englishBook, int chapter) {
    final source = widget.verseByRef;
    if (!identical(_chapterLengthsSource, source) || _chapterLengths == null) {
      final lengths = <String, int>{};
      for (final key in source.keys) {
        // Keys are 'Book-chapter-verse'; the book name itself can
        // contain '-' in no canonical name, but split from the RIGHT
        // to be safe.
        final lastDash = key.lastIndexOf('-');
        if (lastDash <= 0) continue;
        final verse = int.tryParse(key.substring(lastDash + 1));
        if (verse == null) continue;
        final head = key.substring(0, lastDash);
        final prev = lengths[head] ?? 0;
        if (verse > prev) lengths[head] = verse;
      }
      _chapterLengths = lengths;
      _chapterLengthsSource = source;
    }
    return _chapterLengths!['$englishBook-$chapter'] ?? 0;
  }

  List<VerseRef> _expand(String text) => parseVerseListDocument(
        text,
        chapterLength: _chapterLength,
      );

  // ── Menu handlers ─────────────────────────────────────────────────

  void _onImport(_ImportAction action) {
    switch (action) {
      case _ImportAction.currentVerse:
        final ref = widget.currentRef;
        if (ref == null) {
          return _toast(
              _t('vlmNoCurrentVerse', 'No verse is selected in the reader.'));
        }
        _setActive(_active
            .addAll([VerseListEntry(ref, version: widget.version)]));
      case _ImportAction.searchResults:
        if (widget.searchResults.isEmpty) {
          return _toast(_t('vlmNoSearchResults', 'No search results to add.'));
        }
        _setActive(_active.addAll([
          for (final r in widget.searchResults)
            VerseListEntry(r, version: widget.version),
        ]));
      case _ImportAction.fromText:
        _promptImportText();
    }
  }

  void _onEdit(_EditAction action) {
    switch (action) {
      case _EditAction.sort:
        _setActive(_active.sortedAndDeduped());
      case _EditAction.deleteSelected:
        if (_active.selectedCount == 0) {
          return _toast(_t('vlmNothingSelected', 'Nothing is selected.'));
        }
        _setActive(_active.deleteSelected());
      case _EditAction.copyToOther:
        final picked = _active.selectedEntries;
        if (picked.isEmpty) {
          return _toast(_t('vlmNothingSelected', 'Nothing is selected.'));
        }
        _setBoth(_active, _inactive.addAll(picked));
      case _EditAction.clear:
        _setActive(_active.cleared());
    }
  }

  void _onSelect(_SelectAction action) {
    switch (action) {
      case _SelectAction.all:
        _setActive(_active.selectAll());
      case _SelectAction.none:
        _setActive(_active.unselectAll());
      case _SelectAction.invert:
        _setActive(_active.invertSelection());
      case _SelectAction.common:
        _setActive(_active.selectCommonWith(_inactive));
      case _SelectAction.unique:
        _setActive(_active.selectUniqueTo(_inactive));
    }
  }

  Future<void> _onFile(_FileAction action) async {
    switch (action) {
      case _FileAction.saveAs:
        await _promptSaveAs();
      case _FileAction.open:
        await _promptOpen();
      case _FileAction.deleteSaved:
        await _promptDeleteSaved();
      case _FileAction.copyText:
        await _copyAsText();
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────

  Future<void> _promptImportText() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('vlmImportText', 'Import from text')),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            autofocus: true,
            decoration: InputDecoration(
              hintText: _t('vlmImportTextHint',
                  'Paste any text. Every reference in it is added.'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('cancel', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t('vlmAdd', 'Add'))),
        ],
      ),
    );
    final text = ctrl.text;
    ctrl.dispose();
    if (ok != true || !mounted) return;
    final refs = _expand(text);
    if (refs.isEmpty) {
      return _toast(_t('vlmNoRefsFound', 'No references found in that text.'));
    }
    _setActive(_active.addAll([
      for (final r in refs) VerseListEntry(r, version: widget.version),
    ]));
    _toast(_t('vlmAddedCount', '{count} added')
        .replaceAll('{count}', '${refs.length}'));
  }

  Future<void> _promptSaveAs() async {
    final ctrl = TextEditingController(text: _active.name);
    final descCtrl = TextEditingController(text: _active.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('vlmSaveAs', 'Save list as')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _t('vlmListName', 'List name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _t('vlmDescription', 'Description'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('cancel', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t('vlmSave', 'Save'))),
        ],
      ),
    );
    final name = ctrl.text.trim();
    final desc = descCtrl.text.trim();
    ctrl.dispose();
    descCtrl.dispose();
    if (ok != true || name.isEmpty || !mounted) return;
    final next = _active.copyWith(name: name, description: desc);
    _setActive(next);
    final saved = await VerseListStore.saveNamed(next);
    if (!mounted) return;
    setState(() => _saved = saved);
    _toast(_t('vlmSaved', 'Saved.'));
  }

  Future<void> _promptOpen() async {
    if (_saved.isEmpty) {
      return _toast(_t('vlmNoSavedLists', 'No saved lists yet.'));
    }
    final name = await _pickSavedName(_t('vlmOpen', 'Open list'));
    if (name == null || !mounted) return;
    final list = _saved[name];
    if (list == null) return;
    // bwh27: "Loads a Verse List from a file and MERGES it into the
    // active Verse List." Open appends like every other import — it
    // does not replace what you were building.
    _setActive(_active.addAll(list.entries).copyWith(
          name: _active.isEmpty ? list.name : _active.name,
          description:
              _active.description.isEmpty ? list.description : null,
        ));
    _toast(_t('vlmOpened', 'Merged into the active list.'));
  }

  Future<void> _promptDeleteSaved() async {
    if (_saved.isEmpty) {
      return _toast(_t('vlmNoSavedLists', 'No saved lists yet.'));
    }
    final name = await _pickSavedName(_t('vlmDeleteSaved', 'Delete saved list'));
    if (name == null || !mounted) return;
    final saved = await VerseListStore.deleteNamed(name);
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  Future<String?> _pickSavedName(String title) => showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(title),
          children: [
            for (final entry in _saved.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, entry.key),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${entry.value.length} · ${entry.value.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Future<void> _copyAsText() async {
    if (_active.isEmpty) {
      return _toast(_t('vlmListEmpty', 'This list is empty.'));
    }
    await ClipboardHelper.copyText(verseListToText(_active));
    if (!mounted) return;
    _toast(_t('vlmCopied', 'Copied.'));
  }

  // ── Manual entry ──────────────────────────────────────────────────

  void _addTyped() {
    final refs = _expand(_addCtrl.text);
    if (refs.isEmpty) {
      return _toast(_t('vlmNotAReference', 'Not a reference.'));
    }
    _setActive(_active.addAll([
      for (final r in refs) VerseListEntry(r, version: widget.version),
    ]));
    _addCtrl.clear();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_restored) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _header(scheme),
        _toolbar(scheme),
        const Divider(height: 1),
        Expanded(child: _rows(scheme)),
        _addBar(scheme),
      ],
    );
  }

  Widget _header(ColorScheme scheme) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: _ListChip(
                label: _t('vlmMain', 'Main'),
                name: _main.name,
                count: _main.length,
                active: _activeIsMain,
                onTap: () => setState(() => _activeIsMain = true),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ListChip(
                label: _t('vlmSecondary', 'Secondary'),
                name: _secondary.name,
                count: _secondary.length,
                active: !_activeIsMain,
                onTap: () => setState(() => _activeIsMain = false),
              ),
            ),
          ],
        ),
      );

  Widget _toolbar(ColorScheme scheme) {
    final limited = widget.searchLimitActive;
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          const SizedBox(width: 4),
          PopupMenuButton<_ImportAction>(
            tooltip: _t('vlmImport', 'Import'),
            icon: const Icon(Icons.download_rounded, size: 18),
            onSelected: _onImport,
            itemBuilder: (_) => [
              _item(_ImportAction.currentVerse,
                  _t('vlmImportCurrent', 'Current verse')),
              _item(_ImportAction.searchResults,
                  '${_t('vlmImportResults', 'Search results')} '
                  '(${widget.searchResults.length})'),
              _item(_ImportAction.fromText,
                  _t('vlmImportText', 'Import from text')),
            ],
          ),
          PopupMenuButton<_EditAction>(
            tooltip: _t('vlmEdit', 'Edit'),
            icon: const Icon(Icons.tune_rounded, size: 18),
            onSelected: _onEdit,
            itemBuilder: (_) => [
              _item(_EditAction.sort,
                  _t('vlmSortDedupe', 'Sort list (removes duplicates)')),
              _item(_EditAction.deleteSelected,
                  _t('vlmDeleteSelected', 'Delete selected')),
              _item(
                  _EditAction.copyToOther,
                  _t('vlmCopyToOther', 'Copy selected to {other}').replaceAll(
                      '{other}',
                      _activeIsMain
                          ? _t('vlmSecondary', 'Secondary')
                          : _t('vlmMain', 'Main'))),
              _item(_EditAction.clear, _t('vlmClear', 'Clear list')),
            ],
          ),
          PopupMenuButton<_SelectAction>(
            tooltip: _t('vlmSelect', 'Select'),
            icon: const Icon(Icons.checklist_rounded, size: 18),
            onSelected: _onSelect,
            itemBuilder: (_) => [
              _item(_SelectAction.all, _t('vlmSelectAll', 'Select all')),
              _item(_SelectAction.none, _t('vlmSelectNone', 'Unselect all')),
              _item(_SelectAction.invert,
                  _t('vlmInvertSelection', 'Invert selection')),
              _item(
                  _SelectAction.common,
                  _t('vlmSelectCommon', 'Common with {other}').replaceAll(
                      '{other}',
                      _activeIsMain
                          ? _t('vlmSecondary', 'Secondary')
                          : _t('vlmMain', 'Main'))),
              _item(
                  _SelectAction.unique,
                  _t('vlmSelectUnique', 'Not in {other}').replaceAll(
                      '{other}',
                      _activeIsMain
                          ? _t('vlmSecondary', 'Secondary')
                          : _t('vlmMain', 'Main'))),
            ],
          ),
          PopupMenuButton<_FileAction>(
            tooltip: _t('vlmFile', 'File'),
            icon: const Icon(Icons.folder_outlined, size: 18),
            onSelected: _onFile,
            itemBuilder: (_) => [
              _item(_FileAction.saveAs, _t('vlmSaveAs', 'Save list as')),
              _item(_FileAction.open,
                  '${_t('vlmOpen', 'Open list')} (${_saved.length})'),
              _item(_FileAction.deleteSaved,
                  _t('vlmDeleteSaved', 'Delete saved list')),
              _item(_FileAction.copyText, _t('vlmCopyText', 'Copy as text')),
            ],
          ),
          const Spacer(),
          // The search-limit toggle. This is the whole reason a verse
          // list is worth keeping — bwh29/bwh44's `l test.vls`.
          Tooltip(
            message: limited
                ? _t('vlmLimitOn', 'Searches are limited to this list')
                : _t('vlmLimitOff', 'Limit searches to this list'),
            child: IconButton(
              icon: Icon(
                limited ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 18,
                color: limited ? scheme.primary : null,
              ),
              onPressed: () {
                if (limited) {
                  widget.onSetSearchLimit(null);
                } else if (_active.isEmpty) {
                  _toast(_t('vlmListEmpty', 'This list is empty.'));
                } else {
                  widget.onSetSearchLimit(_active);
                }
              },
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  PopupMenuItem<T> _item<T>(T value, String label) => PopupMenuItem<T>(
        value: value,
        height: 38,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      );

  Widget _rows(ColorScheme scheme) {
    final list = _active;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_add_rounded,
                  size: 28, color: scheme.outlineVariant),
              const SizedBox(height: 10),
              Text(
                _t('vlmEmptyHint',
                    'Empty. Import the current verse or your search results, '
                        'or type a reference below.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final entry = list.entries[i];
        final ref = entry.ref;
        final selected = list.selected.contains(ref);
        final verse = widget.verseByRef[ref.key];
        final label =
            '${localeAwareBookName(ref.englishBook, widget.locale, widget.version)} '
            '${ref.chapter}:${ref.verse}';
        return InkWell(
          onTap: () => widget.onOpenRef(ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Checkbox(
                    value: selected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => _setActive(_active.toggle(ref)),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      if (verse != null)
                        Text(
                          scriptureReadingText(verse.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _addBar(ColorScheme scheme) => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                onSubmitted: (_) => _addTyped(),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _t('vlmAddHint', 'Add a verse, e.g. Eph 2:8-10'),
                  hintStyle: const TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            IconButton(
              tooltip: _t('vlmAdd', 'Add'),
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: _addTyped,
            ),
          ],
        ),
      );
}

/// One of the two list buttons in the header — the `Active List:
/// Main / Secondary` radio pair, carrying each list's count so the
/// effect of an operation on the other list is visible without
/// switching to it.
class _ListChip extends StatelessWidget {
  const _ListChip({
    required this.label,
    required this.name,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String name;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    // The active state was `primaryContainer`, one of the tonal roles
    // `workbenchTheme` does NOT remap — so it was a Material pastel from
    // `ColorScheme.fromSeed`, and on the paper palette a lavender wash
    // on cream. `selectionBg` plus the accent hairline is what the
    // workbench's own toolbar uses for an active button.
    return WbPaneChip(
      label: name.isEmpty ? label : name,
      on: active,
      onTap: onTap,
      foreground: active ? wb.link : wb.mutedText,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      alignment: MainAxisAlignment.center,
      trailing: '$count',
      trailingColor: active ? wb.link : wb.mutedText,
      trailingBold: true,
    );
  }
}
