/// 2026-08-07 (SeekSparks): Verse Lists — BibleWorks help topic bwh27,
/// the Verse List Manager (VLM).
///
/// The name undersells it. "Verse List Manager" sounds like bookmarks:
/// a folder of verses you liked. What BibleWorks actually built is a
/// two-list workspace for SET ALGEBRA over search results, and the
/// interesting design decisions are all in the parts the name hides.
///
/// Four things a naive build would miss:
///
///   * **Two lists, one active.** Every menu action applies to the
///     ACTIVE list only. The second list is not a second folder; it
///     exists so the two can be compared. Drop it and the feature
///     collapses back into bookmarks.
///   * **Selection is a first-class layer, not a filter.** BibleWorks
///     has no "intersect" button. It has `Select verses common to both
///     lists`, `Invert selections`, and `Delete selected`. Those three
///     primitives compose into intersection, difference and symmetric
///     difference — AND they leave room to hand-correct the selection
///     before you commit, which a one-shot intersect button does not.
///     So selection is modelled here, not left as widget state.
///   * **Sort and dedupe are ONE operation.** The help is explicit:
///     "This will sort the verse list by book and remove any
///     duplicates." Import, by contrast, appends and does neither —
///     deliberately, so you can see what you just added at the bottom
///     before you commit to merging it.
///   * **Every entry carries the version it came from**, "because
///     there are variations in numbering schemes among some versions".
///     See [VerseListEntry.version] for what we can and cannot do with
///     that.
///
/// And the payoff, which is documented away from bwh27 — in bwh29
/// (Search Limits) and bwh44 (Shortcuts): a saved list can be used as a
/// SEARCH LIMIT (`l test.vls`), and as a range in the Word List Manager
/// (`mytest / luk`). A verse list is a reusable scope, not an archive.
/// That is why this lives in `utils/` as plain data rather than inside
/// a pane: the search path consumes it too.
///
/// Pure list and set work — no Flutter, no I/O, no assets. Persistence
/// is `services/verse_list_store.dart`; the pane is
/// `widgets/verse_list_pane.dart`.
library;

import 'package:seeksparks/constants/book_groups.dart'
    show canonicalNtBooks, canonicalOtBooks;
import 'package:seeksparks/utils/reference_parser.dart';

// ── Canonical ordering ──────────────────────────────────────────────

/// Genesis … Revelation, as one flat list.
const _canonicalBooks = <String>[...canonicalOtBooks, ...canonicalNtBooks];

/// Canonical English book name → 0-based position in the canon.
final Map<String, int> _bookIndex = <String, int>{
  for (var i = 0; i < _canonicalBooks.length; i++) _canonicalBooks[i]: i,
};

/// Position of [englishBook] in the canon, or [_canonicalBooks.length]
/// for anything unrecognised — unknown books sort to the end rather
/// than to the front, so a typo cannot silently displace Genesis.
int canonicalBookIndex(String englishBook) =>
    _bookIndex[englishBook] ?? _canonicalBooks.length;

/// No chapter in the Bible has more verses than Psalm 119 (176). Used
/// as the hard cap when expanding a user-typed range, so `Gen 1:1-99999`
/// cannot spin out a hundred thousand entries.
const maxVersesInAChapter = 176;

// ── A reference ─────────────────────────────────────────────────────

/// One verse, identified the way a verse list identifies it: canonical
/// English book, chapter, verse.
///
/// This — not [VerseListEntry] — is the identity used for dedupe and
/// for every set operation. See [VerseListEntry.version] for why the
/// version is deliberately NOT part of it.
class VerseRef implements Comparable<VerseRef> {
  const VerseRef(this.englishBook, this.chapter, this.verse);

  final String englishBook;
  final int chapter;
  final int verse;

  /// `'Genesis-1-1'` — the same shape as `WorkbenchProvider.verseByRef`
  /// and `Verse.id`, so a list can be joined against the corpus without
  /// a translation step.
  String get key => '$englishBook-$chapter-$verse';

  @override
  int compareTo(VerseRef other) {
    final b = canonicalBookIndex(englishBook)
        .compareTo(canonicalBookIndex(other.englishBook));
    if (b != 0) return b;
    // Two unrecognised books share the same index; fall back to name so
    // the ordering stays total (and therefore stable and testable).
    if (englishBook != other.englishBook) {
      return englishBook.compareTo(other.englishBook);
    }
    final c = chapter.compareTo(other.chapter);
    if (c != 0) return c;
    return verse.compareTo(other.verse);
  }

  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.englishBook == englishBook &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(englishBook, chapter, verse);

  @override
  String toString() => '$englishBook $chapter:$verse';
}

/// One row of a verse list: a reference plus the version it was
/// captured from.
class VerseListEntry {
  const VerseListEntry(this.ref, {this.version = ''});

  final VerseRef ref;

  /// The version this reference was captured from (`'bsb'`,
  /// `'cuvs-yhwh'`, …), or `''` when it was typed by hand.
  ///
  /// BibleWorks stores this "because there are variations in numbering
  /// schemes among some versions … This ensures that you really get the
  /// verse you want", and offers `Remap selected verses to another
  /// version` to convert between schemes — which needs the per-version
  /// `.VMF` verse-map files.
  ///
  /// **We do not have verse maps, so we do not remap.** The version is
  /// carried as provenance (it is shown in the pane and survives a
  /// round-trip) but it is NOT part of [VerseRef] identity: a list that
  /// captured Ps 51:1 from the BSB and one that captured it from a
  /// Chinese edition intersect, as a reader would expect. Where Hebrew
  /// and English numbering genuinely disagree — Psalm superscriptions,
  /// most visibly — the reference is reported as captured rather than
  /// silently converted. Inventing a mapping we cannot verify would be
  /// guessing at scripture; showing the version we actually recorded
  /// lets the reader see the discrepancy and judge it.
  final String version;

  @override
  bool operator ==(Object other) =>
      other is VerseListEntry && other.ref == ref && other.version == version;

  @override
  int get hashCode => Object.hash(ref, version);

  @override
  String toString() => version.isEmpty ? '$ref' : '$ref ($version)';
}

// ── The list ────────────────────────────────────────────────────────

/// One of the VLM's two lists: ordered entries, a name, a description,
/// and the current selection.
///
/// Immutable — every operation returns a new list. That is what lets
/// the whole VLM menu be tested without a widget: `Edit ▸ Sort`,
/// `Select ▸ Common`, `Edit ▸ Delete selected` are functions here, and
/// the pane only has to call them in the right order.
class VerseList {
  const VerseList({
    this.name = '',
    this.description = '',
    this.entries = const [],
    this.selected = const {},
  });

  static const empty = VerseList();

  /// User-visible name. Empty for a scratch list that has never been
  /// saved under a name.
  final String name;

  /// "You can even save short descriptions of the lists" (bwh27) — the
  /// reason a list is still useful six months later.
  final String description;

  /// In insertion order. Import APPENDS here; only [sortedAndDeduped]
  /// reorders.
  final List<VerseListEntry> entries;

  /// Which refs are currently selected. Keyed by [VerseRef] rather than
  /// by list position so a selection survives a sort.
  final Set<VerseRef> selected;

  int get length => entries.length;
  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;

  /// Distinct references in this list.
  Set<VerseRef> get refs => {for (final e in entries) e.ref};

  /// Entries whose ref is selected, in list order.
  List<VerseListEntry> get selectedEntries =>
      [for (final e in entries) if (selected.contains(e.ref)) e];

  /// How many entries are selected. Not `selected.length` — the
  /// selection can name a ref that a later delete removed.
  int get selectedCount => selectedEntries.length;

  VerseList copyWith({
    String? name,
    String? description,
    List<VerseListEntry>? entries,
    Set<VerseRef>? selected,
  }) =>
      VerseList(
        name: name ?? this.name,
        description: description ?? this.description,
        entries: entries ?? this.entries,
        selected: selected ?? this.selected,
      );

  // ── Import (Import ▸ …) ───────────────────────────────────────────

  /// Append [added] to the end. Does NOT sort and does NOT dedupe —
  /// bwh27: "the verses will be appended to the current Verse List. If
  /// you select Edit | Sort List from the VLM Menu, the list will be
  /// sorted and duplicates removed."
  ///
  /// That separation is the point: after an import you can see exactly
  /// what arrived, at the bottom, before you merge it into the rest.
  VerseList addAll(Iterable<VerseListEntry> added) {
    if (added.isEmpty) return this;
    return copyWith(entries: [...entries, ...added]);
  }

  // ── Edit ▸ … ──────────────────────────────────────────────────────

  /// `Edit ▸ Sort list` — canonical order AND duplicates removed, in
  /// one operation, because that is what BibleWorks does.
  ///
  /// The FIRST occurrence of a ref wins, so the version recorded by
  /// whichever import got there first is the one kept.
  VerseList sortedAndDeduped() {
    final seen = <VerseRef>{};
    final unique = <VerseListEntry>[];
    for (final e in entries) {
      if (seen.add(e.ref)) unique.add(e);
    }
    unique.sort((a, b) => a.ref.compareTo(b.ref));
    return copyWith(entries: unique, selected: _prune(selected, unique));
  }

  /// `Edit ▸ Delete selected`.
  VerseList deleteSelected() {
    if (selected.isEmpty) return this;
    final kept = [for (final e in entries) if (!selected.contains(e.ref)) e];
    if (kept.length == entries.length) return this;
    return copyWith(entries: kept, selected: const {});
  }

  /// `Edit ▸ Clear list` — drops the entries, keeps name/description so
  /// a named list stays named while you refill it.
  VerseList cleared() => copyWith(entries: const [], selected: const {});

  // ── Selection ▸ … ─────────────────────────────────────────────────

  VerseList selectAll() => copyWith(selected: refs);

  VerseList unselectAll() => copyWith(selected: const {});

  /// `Selection ▸ Invert selections`.
  VerseList invertSelection() =>
      copyWith(selected: {for (final r in refs) if (!selected.contains(r)) r});

  /// Toggle one ref — the checkbox next to a row.
  VerseList toggle(VerseRef ref) {
    final next = Set<VerseRef>.of(selected);
    if (!next.remove(ref)) next.add(ref);
    return copyWith(selected: next);
  }

  /// `Selection ▸ Select verses common to both lists` — selects the
  /// entries of THIS list that also appear in [other].
  ///
  /// Combined with [deleteSelected] this is set difference; combined
  /// with [invertSelection] then [deleteSelected] it is intersection.
  VerseList selectCommonWith(VerseList other) {
    final theirs = other.refs;
    return copyWith(selected: {for (final r in refs) if (theirs.contains(r)) r});
  }

  /// `Selection ▸ Select verses not common to both lists`, applied to
  /// this list — selects the entries here that do NOT appear in
  /// [other].
  ///
  /// bwh27 describes this symmetrically ("if a reference appears only
  /// in the inactive Verse List … it will be selected"), but it also
  /// states the governing rule: "When you manipulate the Verse List
  /// using the menus and buttons, only the active Verse List is
  /// affected." A selection in one list cannot name a row the other
  /// list does not have, so we follow the rule: this operates on one
  /// list, and the pane runs it on the active one.
  VerseList selectUniqueTo(VerseList other) {
    final theirs = other.refs;
    return copyWith(
        selected: {for (final r in refs) if (!theirs.contains(r)) r});
  }

  /// Drop selected refs that no longer exist in [rows].
  static Set<VerseRef> _prune(Set<VerseRef> sel, List<VerseListEntry> rows) {
    if (sel.isEmpty) return const {};
    final live = {for (final e in rows) e.ref};
    return {for (final r in sel) if (live.contains(r)) r};
  }

  // ── Serialization ────────────────────────────────────────────────

  /// The selection is deliberately NOT serialized: it is a working
  /// gesture, not a property of the list. Reloading with three verses
  /// mysteriously ticked would be a bug, not a restored session.
  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'entries': [
          for (final e in entries)
            {
              'b': e.ref.englishBook,
              'c': e.ref.chapter,
              'v': e.ref.verse,
              if (e.version.isNotEmpty) 'ver': e.version,
            },
        ],
      };

  static VerseList fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = <VerseListEntry>[];
    if (rawEntries is List) {
      for (final raw in rawEntries) {
        if (raw is! Map) continue;
        final book = raw['b'];
        final chapter = raw['c'];
        final verse = raw['v'];
        if (book is! String || chapter is! int || verse is! int) continue;
        if (book.isEmpty || chapter <= 0 || verse <= 0) continue;
        final version = raw['ver'];
        entries.add(VerseListEntry(
          VerseRef(book, chapter, verse),
          version: version is String ? version : '',
        ));
      }
    }
    return VerseList(
      name: json['name'] is String ? json['name'] as String : '',
      description:
          json['description'] is String ? json['description'] as String : '',
      entries: entries,
    );
  }
}

// ── Search limits ───────────────────────────────────────────────────

/// The `'EnglishBook-chapter-verse'` keys a list covers, for use as a
/// search limit.
///
/// bwh29 (Search Limits) and bwh44 (Shortcuts) document `l test.vls` —
/// pointing the search at a saved verse list instead of a book range.
/// This is what turns a verse list from an archive into a scope.
Set<String> verseListKeys(VerseList list) =>
    {for (final e in list.entries) e.ref.key};

/// Keep only the items whose key is inside [limit]. A null [limit]
/// means "no limit set" and returns [items] untouched — distinct from
/// an EMPTY limit, which is a real (if useless) restriction to nothing
/// and must not silently behave like "unlimited".
List<T> applySearchLimit<T>(
  List<T> items,
  Set<String>? limit,
  String Function(T item) keyOf,
) {
  if (limit == null) return items;
  return [for (final i in items) if (limit.contains(keyOf(i))) i];
}

// ── Reference expansion ─────────────────────────────────────────────

/// Expand a parsed [ref] into the individual verses it names.
///
/// bwh27 allows a range in the manual-entry box ("like Eph 2:8-10")
/// but notes "ranges cannot span books". Our [parseReference] already
/// collapses a cross-chapter range such as `2 Kings 22:8-23:25` to its
/// first verse, so every range that reaches here is inside one chapter.
///
/// A chapter-only reference ("John 3") needs to know how long the
/// chapter is; that is corpus knowledge, so it arrives as
/// [chapterLength]. Without it a chapter-only reference expands to
/// nothing rather than guessing — silently adding only verse 1 would
/// look like it worked.
List<VerseRef> expandReference(
  BibleReference ref, {
  int Function(String englishBook, int chapter)? chapterLength,
}) {
  final book = ref.englishBook;
  final chapter = ref.chapter;

  if (ref.hasExplicitVerses) {
    return [for (final v in ref.verses) if (v > 0) VerseRef(book, chapter, v)];
  }

  final start = ref.verseStart;
  if (start == null) {
    final len = chapterLength?.call(book, chapter) ?? 0;
    if (len <= 0) return const [];
    return [
      for (var v = 1; v <= len && v <= maxVersesInAChapter; v++)
        VerseRef(book, chapter, v),
    ];
  }
  if (start <= 0) return const [];

  var end = ref.verseEnd ?? start;
  if (end < start) end = start;
  // Clamp a typed range to the chapter when we know its length, and to
  // the longest chapter in the Bible when we do not. `Gen 1:1-99999`
  // is a typo, not a request for 99,999 rows.
  final len = chapterLength?.call(book, chapter) ?? 0;
  if (len > 0 && end > len) end = len;
  if (end - start >= maxVersesInAChapter) end = start + maxVersesInAChapter - 1;

  return [for (var v = start; v <= end; v++) VerseRef(book, chapter, v)];
}

/// Parse one line of free text into the verses it names, for the manual
/// "add a verse" box. Returns an empty list when the line is not a
/// reference.
List<VerseRef> parseVerseListLine(
  String line, {
  int Function(String englishBook, int chapter)? chapterLength,
}) {
  final ref = parseReference(line);
  if (ref == null) return const [];
  return expandReference(ref, chapterLength: chapterLength);
}

/// `Import ▸ From Document` — scan arbitrary prose for references and
/// return them in the order they appear.
///
/// bwh27 points this at "an HTML, RTF or Text file"; the app's reality
/// is a paste box, which is the same job without the file picker.
/// Splits on line breaks, semicolons and commas because that is how
/// reference lists are actually written ("Isaiah 53; Psalm 22, Micah
/// 5:2") and [parseReference] deliberately keeps only the first
/// reference of such a chain.
///
/// Duplicates are NOT removed and the result is NOT sorted — this is an
/// import, and imports append verbatim so you can see what arrived.
List<VerseRef> parseVerseListDocument(
  String text, {
  int Function(String englishBook, int chapter)? chapterLength,
}) {
  final out = <VerseRef>[];
  for (final chunk in text.split(RegExp(r'[\n\r;,、；]+'))) {
    final trimmed = chunk.trim();
    if (trimmed.isEmpty) continue;
    final whole = parseVerseListLine(trimmed, chapterLength: chapterLength);
    if (whole.isNotEmpty) {
      out.addAll(whole);
    } else {
      out.addAll(_scanEmbedded(trimmed, chapterLength));
    }
  }
  return out;
}

/// A `chapter:verse` (optionally `-verse`) sitting inside prose.
final _embeddedCv = RegExp(r'(\d+)\s*[:：.]\s*(\d+)(?:\s*[-–—]\s*(\d+))?');

/// How many candidate book-name suffixes to try before each `3:16`.
/// "1 John" already needs two tokens; the rest is slack for the prose
/// that precedes it ("and again in …").
const _maxBookCandidates = 16;

/// Pull references out of a chunk that is NOT itself a reference —
/// "As we saw in John 3:16" rather than "John 3:16".
///
/// [parseReference] requires the whole string to be a reference, so
/// prose has to be reduced to one first. For each `chapter:verse` found,
/// walk the preceding text as candidate book names longest-first and
/// keep the first that resolves: "again in Romans" fails, "in Romans"
/// fails, "Romans" wins — and longest-first is what makes "in 1 John"
/// resolve to `1 John` rather than `John`.
///
/// Only `chapter:verse` forms are recognised here. A bare "Psalm 117"
/// buried in a sentence is indistinguishable from an ordinary number,
/// and guessing would import verses nobody cited.
List<VerseRef> _scanEmbedded(
  String chunk,
  int Function(String englishBook, int chapter)? chapterLength,
) {
  final out = <VerseRef>[];
  for (final m in _embeddedCv.allMatches(chunk)) {
    final prefix = chunk.substring(0, m.start);
    final tail = m.group(0)!;
    for (final start in _bookNameStarts(prefix)) {
      final candidate = prefix.substring(start).trim();
      if (candidate.isEmpty) continue;
      final ref = parseReference('$candidate $tail');
      if (ref != null) {
        out.addAll(expandReference(ref, chapterLength: chapterLength));
        break;
      }
    }
  }
  return out;
}

/// Offsets in [prefix] where a book name could start, longest suffix
/// first. Latin names start at whitespace boundaries; CJK names butt
/// straight up against surrounding text, so every CJK character counts.
List<int> _bookNameStarts(String prefix) {
  final starts = <int>[];
  for (var i = prefix.length - 1; i >= 0 && starts.length < _maxBookCandidates; i--) {
    final c = prefix.codeUnitAt(i);
    if (_isSpace(c)) continue;
    final isCjk = c >= 0x2E80 && c <= 0x9FFF;
    if (isCjk || i == 0 || _isSpace(prefix.codeUnitAt(i - 1))) {
      starts.add(i);
    }
  }
  return starts.reversed.toList();
}

bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

// ── Plain-text interchange ──────────────────────────────────────────

/// Render a list as one reference per line, canonical English names.
///
/// BibleWorks writes `.VLS`, "standard ASCII text files [that] can be
/// edited with any word processor". The help never specifies the layout
/// of that file, so this does NOT claim to be a `.VLS` — it is a plain
/// reference list, which [parseVerseListDocument] reads back and any
/// other Bible program can be pointed at. Emitting a file with a `.vls`
/// extension whose format we inferred would be worse than useless.
String verseListToText(VerseList list) {
  final buffer = StringBuffer();
  if (list.name.isNotEmpty) buffer.writeln('# ${list.name}');
  if (list.description.isNotEmpty) buffer.writeln('# ${list.description}');
  for (final e in list.entries) {
    buffer.writeln(e.ref.toString());
  }
  return buffer.toString();
}
