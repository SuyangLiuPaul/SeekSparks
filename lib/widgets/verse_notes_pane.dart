/// 2026-08-18 (SeekSparks): the User Notes tab — BibleWorks' bwh15,
/// docked beside the text.
///
/// `docs/PARITY-BACKLOG.md` §3.4 called this "the biggest single gap in
/// the Analysis pane", and the reason is not that the app had no notes:
/// it has had them, with titles and timestamps, since v1.2.59. It is
/// that both ways of reaching one — a modal sheet and the Library page —
/// take the verse off the screen in order to show you what you wrote
/// about it. That is exactly the pattern #313 was raised about: in the
/// workbench, content that has a pane goes to the pane.
///
/// What bwh15 actually specifies, and what this keeps:
///   * **Autoload.** "Note files are loaded when the Browse verse
///     changes." The pane follows the focused verse with no Load button.
///   * **No Save button.** "All you have to do is select the User Notes
///     tab and start typing. Note files are saved automatically when the
///     verse changes or you exit." So: a debounce while typing, a flush
///     when the selection moves, and a flush on dispose.
///   * **The location, stated.** BibleWorks prints the notes directory
///     above the editor "so you always know where notes go". Our store
///     is not a directory, it is a set of verse keys — so the pane
///     prints the reference the note will be written to, and says out
///     loud when that is more than one verse.
///   * **Search.** bwh15 searches note files for a phrase and lists the
///     ones that match. The app had no note search at all; `searchNotes`
///     in `verse_notes.dart` is it.
///
/// What it deliberately does NOT keep is bwh15's **chapter notes** and
/// its verse/chapter mode switch. A chapter note has no key in this
/// store — every note here hangs off a verse — so supporting it means
/// inventing a second shape for user data, and inventing a data shape
/// for notes people have already written is not a thing to do without
/// asking. A chapter note can be written on the chapter's first verse
/// today, and the store is unchanged by this tab.
///
/// The pane holds no provider. The store arrives as the two maps
/// `MainProvider` already exposes and leaves through two callbacks, so
/// the whole autosave state machine is testable without SharedPreferences.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/verse_notes.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// How long the pane waits after the last keystroke before writing.
///
/// Every write hits SharedPreferences and bumps the note's timestamp, so
/// per-keystroke saving would rewrite the whole note store on every
/// letter and make "recently edited" meaningless. Long enough to batch a
/// sentence, short enough that a reader who closes the tab a second
/// later has already been saved — and the close path flushes anyway, so
/// this delay can never cost a keystroke.
const Duration kNoteAutosaveDelay = Duration(milliseconds: 700);

class VerseNotesPane extends StatefulWidget {
  const VerseNotesPane({
    super.key,
    required this.verses,
    required this.notes,
    required this.titles,
    required this.locale,
    required this.onSave,
    required this.onDelete,
    required this.onOpenNote,
    this.version,
  });

  /// The focused selection, in canonical order. A note written here is
  /// written to every one of them — the passage-note rule the modal
  /// editor has followed since v1.2.60.
  final List<Verse> verses;

  /// The whole store, `Verse.id` → text, for the editor's prefill and
  /// for search. Passed rather than read from a provider so this widget
  /// can be driven directly in a test.
  final Map<String, String> notes;
  final Map<String, String> titles;

  final String locale;
  final String? version;

  final void Function(List<Verse> verses, String body, String title) onSave;
  final void Function(List<Verse> verses) onDelete;

  /// Open a search result — the host resolves the key to a reference and
  /// navigates, which brings the note back under the editor by way of
  /// the focused verse.
  final void Function(String verseId) onOpenNote;

  @override
  State<VerseNotesPane> createState() => _VerseNotesPaneState();
}

class _VerseNotesPaneState extends State<VerseNotesPane> {
  final TextEditingController _body = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _query = TextEditingController();

  /// True between a keystroke and the write it causes. Held as a
  /// notifier rather than in `setState` so a keystroke repaints the
  /// four-word status line and not the editor under the cursor.
  final ValueNotifier<bool> _pending = ValueNotifier<bool>(false);

  Timer? _debounce;
  bool _dirty = false;
  bool _searching = false;

  /// The verses the text currently in the fields belongs to. Kept
  /// separately from `widget.verses` because the flush that runs when
  /// the selection moves must write to the OLD verses — by the time
  /// `didUpdateWidget` runs, `widget.verses` is already the new ones.
  List<Verse> _loaded = const [];
  String _loadedKey = '';

  @override
  void initState() {
    super.initState();
    _adopt();
  }

  @override
  void didUpdateWidget(VerseNotesPane old) {
    super.didUpdateWidget(old);
    if (_keyFor(widget.verses) != _loadedKey) {
      _flushLater(_loaded);
      _adopt();
      return;
    }
    // Same verses, but the store moved: the modal editor, an import or
    // a delete wrote to this note behind us. Adopt it — unless the
    // reader is mid-edit, in which case what they are typing wins and
    // the debounce will overwrite it in a moment anyway.
    if (!_dirty) {
      final p = _prefill();
      if (p.body != _body.text || p.title != _title.text) _adopt();
    }
  }

  String _keyFor(List<Verse> verses) => verses.map((v) => v.id).join('|');

  NotePrefill _prefill() => resolveNotePrefill(
        widget.verses,
        notes: widget.notes,
        titles: widget.titles,
      );

  /// Load the note for the current selection into the fields.
  void _adopt() {
    final p = _prefill();
    _body.text = p.body;
    _title.text = p.title;
    _loaded = List<Verse>.of(widget.verses);
    _loadedKey = _keyFor(widget.verses);
    _dirty = false;
    _pending.value = false;
  }

  void _onEdited() {
    _dirty = true;
    _pending.value = true;
    _debounce?.cancel();
    _debounce = Timer(kNoteAutosaveDelay, () => _flush(_loaded));
  }

  void _flush(List<Verse> verses) {
    _debounce?.cancel();
    if (!_dirty || verses.isEmpty) return;
    _dirty = false;
    _pending.value = false;
    widget.onSave(verses, _body.text, _title.text);
  }

  /// The same write, posted to a microtask instead of run inline.
  ///
  /// bwh15 saves "when the verse changes or you exit", and both of those
  /// moments land inside a frame that is already building or tearing
  /// down: one runs in `didUpdateWidget`, the other in `dispose`. The
  /// host's save notifies `MainProvider`, which marks the pane's own
  /// ancestor dirty — Flutter asserts on that, so moving to the next
  /// verse with unsaved text would crash the workbench rather than save
  /// it. Everything the write needs is captured by value, so it survives
  /// the pane and lands one microtask later.
  void _flushLater(List<Verse> verses) {
    _debounce?.cancel();
    if (!_dirty || verses.isEmpty) return;
    _dirty = false;
    final body = _body.text;
    final title = _title.text;
    final save = widget.onSave;
    scheduleMicrotask(() => save(verses, body, title));
  }

  @override
  void dispose() {
    _flushLater(_loaded);
    _body.dispose();
    _title.dispose();
    _query.dispose();
    _pending.dispose();
    super.dispose();
  }

  void _delete() {
    _debounce?.cancel();
    _dirty = false;
    _pending.value = false;
    _body.clear();
    _title.clear();
    widget.onDelete(_loaded.isEmpty ? widget.verses : _loaded);
  }

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    final wb = WbColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, t, wb, scheme),
        const Divider(height: 1),
        Expanded(
          child: _searching
              ? _searchBody(context, t, wb, scheme, locale)
              : _editorBody(context, t, wb, scheme, locale),
        ),
      ],
    );
  }

  // ── Header: what this note is attached to ─────────────────────────

  Widget _header(
      BuildContext context, WbType t, WbColors wb, ColorScheme scheme) {
    final locale = widget.locale;
    // Read from the STORE, not from the controller: "delete" removes
    // what is saved, so the button must appear exactly when there is
    // something saved to remove. Keyed to the controller it would
    // appear on the first keystroke and offer to delete nothing.
    final hasNote = !_prefill().isEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          t.scaledChrome(10), t.scaledChrome(6), t.scaledChrome(4),
          t.scaledChrome(6)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // BibleWorks prints the notes DIRECTORY here, "so you
                // always know where notes go". The store's equivalent
                // of a filename is the verse key, so this is that.
                Text(
                  verseNoteRangeLabel(widget.verses),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.scaledChrome(12),
                    fontWeight: FontWeight.w700,
                    color: wb.link,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
                if (widget.verses.length > 1)
                  Text(
                    (uiStrings['notesWritesToRange']?[locale] ??
                            'Written to all {count} selected verses')
                        .replaceAll('{count}', '${widget.verses.length}'),
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: t.scaledChrome(11),
                      color: scheme.outline,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
              ],
            ),
          ),
          if (hasNote && !_searching)
            IconButton(
              tooltip: uiStrings['noteDelete']?[locale] ?? 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              iconSize: t.scaledChrome(17),
              visualDensity: VisualDensity.compact,
              color: scheme.error,
            ),
          IconButton(
            tooltip: _searching
                ? (uiStrings['notesSearchClose']?[locale] ?? 'Back to the note')
                : (uiStrings['notesSearchOpen']?[locale] ?? 'Search notes'),
            onPressed: () => setState(() => _searching = !_searching),
            icon: Icon(_searching ? Icons.edit_note : Icons.search),
            iconSize: t.scaledChrome(17),
            visualDensity: VisualDensity.compact,
            color: _searching ? wb.link : scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  // ── Editor ────────────────────────────────────────────────────────

  Widget _editorBody(BuildContext context, WbType t, WbColors wb,
      ColorScheme scheme, String locale) {
    return Padding(
      padding: EdgeInsets.fromLTRB(t.scaledChrome(10), t.scaledChrome(6),
          t.scaledChrome(10), t.scaledChrome(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            maxLines: 1,
            onChanged: (_) => _onEdited(),
            style: TextStyle(
              fontSize: t.scaled(13.5),
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              fontFamilyFallback: kCjkFontFallback,
            ),
            decoration: InputDecoration(
              hintText: uiStrings['noteTitleHint']?[locale] ??
                  'Title (optional)',
              hintStyle: TextStyle(
                fontSize: t.scaled(13.5),
                fontWeight: FontWeight.w500,
                color: scheme.outline,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Divider(height: t.scaledChrome(10), color: wb.border),
          Expanded(
            child: TextField(
              controller: _body,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => _onEdited(),
              style: TextStyle(
                fontSize: t.scaled(13),
                height: 1.5,
                color: scheme.onSurface,
                fontFamilyFallback: kCjkFontFallback,
              ),
              decoration: InputDecoration(
                hintText: uiStrings['noteHint']?[locale] ??
                    'Type your note for this verse…',
                hintStyle: TextStyle(
                  fontSize: t.scaled(13),
                  height: 1.5,
                  color: scheme.outline,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // There is no Save button on purpose, so the pane has to say
          // so — an editor with no visible way to commit reads as one
          // that has not saved.
          ValueListenableBuilder<bool>(
            valueListenable: _pending,
            builder: (context, pending, _) => Padding(
              padding: EdgeInsets.only(top: t.scaledChrome(4)),
              child: Text(
                pending
                    ? (uiStrings['notesSaving']?[locale] ?? 'Saving…')
                    : (uiStrings['notesAutosave']?[locale] ??
                        'Saved automatically'),
                style: TextStyle(
                  fontSize: t.scaledChrome(11),
                  color: pending ? wb.link : scheme.outline,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────

  Widget _searchBody(BuildContext context, WbType t, WbColors wb,
      ColorScheme scheme, String locale) {
    final hits = searchNotes(
      _query.text,
      notes: widget.notes,
      titles: widget.titles,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(t.scaledChrome(10), t.scaledChrome(8),
              t.scaledChrome(10), t.scaledChrome(4)),
          child: TextField(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: t.scaled(13),
              color: scheme.onSurface,
              fontFamilyFallback: kCjkFontFallback,
            ),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: t.scaledChrome(16)),
              prefixIconConstraints: BoxConstraints(
                  minWidth: t.scaledChrome(28), minHeight: 0),
              hintText: uiStrings['notesSearchHint']?[locale] ??
                  'Search your notes…',
              hintStyle:
                  TextStyle(fontSize: t.scaled(13), color: scheme.outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: wb.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: wb.border),
              ),
              contentPadding: EdgeInsets.symmetric(
                  vertical: t.scaledChrome(8), horizontal: t.scaledChrome(6)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.scaledChrome(10)),
          child: Text(
            _query.text.trim().isEmpty
                ? (uiStrings['notesSearchScope']?[locale] ??
                        'Searches every note you have written — {count} of them.')
                    .replaceAll('{count}', '${widget.notes.length}')
                : (uiStrings['notesSearchCount']?[locale] ?? '{count} found')
                    .replaceAll('{count}', '${hits.length}'),
            style: TextStyle(
              fontSize: t.scaledChrome(11),
              color: scheme.outline,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
        Expanded(
          child: hits.isEmpty
              ? const SizedBox.shrink()
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(t.scaledChrome(10),
                      t.scaledChrome(8), t.scaledChrome(10), t.scaledChrome(16)),
                  physics: const BouncingScrollPhysics(),
                  itemCount: hits.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: t.scaledChrome(6)),
                  itemBuilder: (context, i) =>
                      _hitTile(context, t, wb, scheme, hits[i]),
                ),
        ),
      ],
    );
  }

  Widget _hitTile(BuildContext context, WbType t, WbColors wb,
      ColorScheme scheme, NoteSearchHit hit) {
    final head = parseVerseId(hit.id);
    final tail = parseVerseId(hit.lastId);
    final book =
        localeAwareBookName(head.book, widget.locale, widget.version);
    final label = hit.id == hit.lastId
        ? '$book ${head.chapter}:${head.verseLabel}'
        : '$book ${head.chapter}:${head.verseLabel}-${tail.verseLabel}';
    return InkWell(
      // bwh15's search is "click to LOAD": the result list exists to get
      // you back into a note, so the tap navigates and hands the pane
      // back to the editor, which the new selection has just filled.
      onTap: () {
        widget.onOpenNote(hit.id);
        setState(() => _searching = false);
      },
      child: Container(
        padding: EdgeInsets.all(t.scaledChrome(8)),
        decoration: BoxDecoration(border: Border.all(color: wb.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.scaled(11.5),
                fontWeight: FontWeight.w700,
                color: wb.link,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
            if (hit.title.isNotEmpty)
              Text(
                hit.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.scaled(12),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            SizedBox(height: t.scaledChrome(2)),
            Text(
              hit.snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.scaled(12),
                height: 1.4,
                color: scheme.onSurfaceVariant,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
