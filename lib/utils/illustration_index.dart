/// 2026-08-09 (SeekSparks): the picture database's index — pure.
///
/// **What this is the index OF.** `assets/maps_index.json` holds 1,192
/// illustrations: 55 bundled Bible-history maps and 1,137 public-domain
/// plates (Doré, Tissot, Schnorr) on the yswords-data CDN. Every one
/// carries a title AND a description in `en` / `zh-Hans` / `zh-Hant`,
/// and a book→chapter-range map covering 66 books. It is one of the
/// larger reference databases in the app and, until this file existed,
/// the only way to reach any of it was to already be reading a chapter
/// that happened to match.
///
/// **Why it is a Resource.** bwh07 gives its Pictures entry a paragraph
/// of its own — *"One item that deserves special mention here is the
/// option 'Bible Views' on this menu. This opens up a picture database
/// …"* — and files it under Resources, beside Maps and the dictionaries,
/// on the same test that put the Atlas and the Family Tree there: it is
/// a database you CONSULT, not a tool that operates on the verse in
/// front of you. The verse-linked half ("what pictures go with this
/// chapter?") stays in the reading pane, which is the half that *does*.
///
/// **Where BibleWorks stops, and why that decides the shape.** Bible
/// Views is a photograph archive of the Holy Land, browsed by place. It
/// has no notion of which passage a picture belongs to. This corpus
/// does — every plate is book- and chapter-scoped — so the index can be
/// ordered CANONICALLY and scoped by book, which turns a bag of 1,192
/// pictures into a walk through scripture. That is the whole argument
/// for [illustrationAnchor] being scope-aware rather than a fixed sort:
/// scoped to Acts, the index is not "the pictures that mention Acts", it
/// is Acts in order.
///
/// Ordering, filtering and counting live here so they can be tested
/// without a widget; `pages/illustrations_page.dart` is layout.
library;

import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/utils/search_scope.dart' show kScopeAllBooks;

/// Canonical position of each of the 66 books.
final Map<String, int> _bookOrder = <String, int>{
  for (var i = 0; i < kScopeAllBooks.length; i++) kScopeAllBooks[i]: i,
};

/// Sorts after every canonical book, so an unrecognised book name in the
/// asset lands at the end of the index instead of at Genesis.
const int _unknownBook = 1 << 20;

/// The categories `maps_index.json` uses, in the order they are offered.
///
/// Maps first because they are the 55 that have always shipped and the
/// only ones that are bundled rather than fetched; then the narrative
/// plates, which are 91% of the corpus; then the two small teaching
/// sets. A kind found in the data but missing here is still offered —
/// see [illustrationKinds] — because a filter that silently hides a
/// category is worse than one that lists it in an odd position.
const List<String> kIllustrationKindOrder = <String>[
  'map',
  'scene',
  'parable',
  'teaching',
];

/// `uiStrings` key for a kind's name, or null when the data carries a
/// kind this build has no word for.
String? illustrationKindLabelKey(String kind) => switch (kind) {
      'map' => 'illusKindMap',
      'scene' => 'illusKindScene',
      'parable' => 'illusKindParable',
      'teaching' => 'illusKindTeaching',
      _ => null,
    };

/// Every kind present in [all]: the known ones in [kIllustrationKindOrder]
/// order, then anything unrecognised, alphabetically.
List<String> illustrationKinds(Iterable<BibleMap> all) {
  final present = <String>{for (final m in all) m.kind};
  final known = [
    for (final k in kIllustrationKindOrder)
      if (present.remove(k)) k,
  ];
  final rest = present.toList()..sort();
  return [...known, ...rest];
}

/// Where an illustration sits in scripture: the earliest canonical
/// (book, chapter) among the books it covers.
///
/// [scope] is what makes this worth a function. A plate of the Ancient
/// Near East is filed under both Genesis 1–11 and Job; unscoped it
/// belongs at Genesis, but a reader who has scoped the index to Job is
/// asking about Job and wants it in Job's order. Restricting the anchor
/// to the books in scope is what keeps a scoped index in the order of
/// the thing it was scoped to.
({int book, int chapter}) illustrationAnchor(
  BibleMap m, [
  Set<String>? scope,
]) {
  var bestBook = _unknownBook;
  var bestChapter = 0;
  for (final entry in m.books.entries) {
    if (scope != null && scope.isNotEmpty && !scope.contains(entry.key)) {
      continue;
    }
    final idx = _bookOrder[entry.key] ?? _unknownBook;
    final chapter = entry.value.isEmpty ? 0 : entry.value.first;
    if (idx < bestBook || (idx == bestBook && chapter < bestChapter)) {
      bestBook = idx;
      bestChapter = chapter;
    }
  }
  // No book survived the scope — the caller filtered on the same scope,
  // so this only happens for an entry with no books at all.
  if (bestBook == _unknownBook && bestChapter == 0 && m.books.isEmpty) {
    return (book: _unknownBook, chapter: 0);
  }
  return (book: bestBook, chapter: bestChapter);
}

/// True when [query] appears in any of the six localised strings an
/// illustration carries.
///
/// All three locales are searched at once, whatever the reading version
/// is — the same decision the Atlas index made, and for the same reason:
/// a reader in CUVS who knows a plate as "Doré" should not have to
/// switch the UI language to find it, and a reader in English should
/// still find 光的创造. Substring rather than token matching, which is
/// also what makes it work on Chinese without a tokenizer.
bool matchesIllustrationQuery(BibleMap m, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (final v in m.title.values) {
    if (v.toLowerCase().contains(q)) return true;
  }
  for (final v in m.description.values) {
    if (v.toLowerCase().contains(q)) return true;
  }
  return false;
}

/// The index, in canonical order.
///
/// [kinds] and [scopeBooks] are both "no filter" when null OR empty:
/// an empty chip row means nothing has been narrowed, and an empty book
/// set is what `showSearchScopeSheet` returns for "whole Bible".
List<BibleMap> filterIllustrations(
  Iterable<BibleMap> all, {
  String query = '',
  Set<String>? kinds,
  Set<String>? scopeBooks,
}) {
  final byKind = kinds != null && kinds.isNotEmpty;
  final byBook = scopeBooks != null && scopeBooks.isNotEmpty;

  final out = <BibleMap>[
    for (final m in all)
      if ((!byKind || kinds.contains(m.kind)) &&
          (!byBook || m.books.keys.any(scopeBooks.contains)) &&
          matchesIllustrationQuery(m, query))
        m,
  ];

  out.sort((a, b) {
    final pa = illustrationAnchor(a, scopeBooks);
    final pb = illustrationAnchor(b, scopeBooks);
    if (pa.book != pb.book) return pa.book.compareTo(pb.book);
    if (pa.chapter != pb.chapter) return pa.chapter.compareTo(pb.chapter);
    // Stable and reproducible for the many plates sharing a chapter;
    // the id is the only field guaranteed unique and locale-free.
    return a.id.compareTo(b.id);
  });
  return out;
}

/// How many of [all] fall in each kind, for the counts on the filter
/// chips. Counted BEFORE the kind filter is applied and after every
/// other one, so a chip reads "what would I get if I picked this",
/// rather than "how many are showing" (which is 0 for every chip the
/// reader has not picked).
Map<String, int> illustrationKindCounts(
  Iterable<BibleMap> all, {
  String query = '',
  Set<String>? scopeBooks,
}) {
  final counts = <String, int>{};
  for (final m in filterIllustrations(all,
      query: query, scopeBooks: scopeBooks)) {
    counts[m.kind] = (counts[m.kind] ?? 0) + 1;
  }
  return counts;
}

/// The books an illustration is filed under, canonical English, in
/// canonical order — what the caller localises for display (#283).
List<String> illustrationBooks(BibleMap m) {
  final books = m.books.keys.toList();
  books.sort((a, b) =>
      (_bookOrder[a] ?? _unknownBook).compareTo(_bookOrder[b] ?? _unknownBook));
  return books;
}

/// The chapter span an illustration covers within [book], as `1` or
/// `1–11`, or an empty string when the entry names no chapters.
///
/// An en dash, not a hyphen: it is a range, and the rest of the app
/// already prints `马太福音 5–7` in [localizedRangeLabel].
String illustrationChapterSpan(BibleMap m, String book) {
  final range = m.books[book];
  if (range == null || range.isEmpty) return '';
  if (range.length == 1 || range.first == range.last) return '${range.first}';
  return '${range.first}–${range.last}';
}
