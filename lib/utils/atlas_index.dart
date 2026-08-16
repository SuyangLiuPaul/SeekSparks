/// 2026-08-09 (SeekSparks): the gazetteer read as an INDEX — the pure
/// half of the Atlas.
///
/// #277 gave the gazetteer one direction: verse → places, in the Analysis
/// pane. That answers "what does the passage in front of me name" and it
/// is the direction BibleWorks cannot be asked. It leaves the other
/// direction — the one every printed atlas has an index for — with no
/// surface at all: **where is Ashkelon, and where does scripture name
/// it?** 1,271 places ship in the bundle and a reader can only reach the
/// twelve of them their current chapter happens to mention.
///
/// bwh33 answers it with the Find Place window: type a name, get a site,
/// and from the site right-click to run a *text search* for the word.
/// That last step is the weak link and it is worth being precise about
/// why, because it is the thing this file replaces. A text search for
/// "Antioch" cannot tell Syrian Antioch from Pisidian Antioch — they are
/// 800 km apart and share a spelling — and it finds only the verses whose
/// *translation* used that spelling. The gazetteer carries a curated
/// reference list per site, ordinal included, so the same question is
/// answered exactly and in any language the reader is reading in.
///
/// Everything here is pure: no Flutter, no assets. The parts that are
/// easy to get quietly wrong — which name matched, what "in scope" means,
/// which label a crowded map keeps — are the parts under test.
library;

import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/search_scope.dart' show canonicalScopeOrder;

/// Fold a name or a query into the form the two are compared in.
///
/// Lower-cased, and everything that is not a letter, a digit or a Han
/// character removed. The gazetteer is full of `Baal-zephon`,
/// `Kiriath-jearim` and `Solomon's`, and a reader typing a name they
/// heard read aloud will not reproduce the hyphens. Dropping them costs
/// nothing: no two entries differ only by punctuation.
///
/// Han characters are kept as themselves — there is no case to fold and
/// no separator to drop — so `耶路撒冷` matches `耶路撒冷`.
String normalisePlaceQuery(String input) {
  final buf = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ok = (rune >= 0x30 && rune <= 0x39) || // 0-9
        (rune >= 0x61 && rune <= 0x7a) || // a-z
        (rune >= 0x3400 && rune <= 0x9fff) || // CJK
        (rune >= 0xf900 && rune <= 0xfaff); // CJK compatibility
    if (ok) buf.writeCharCode(rune);
  }
  return buf.toString();
}

/// How well a place answered the query. Lower sorts first.
///
/// Prefix beats substring deliberately: `dan` should offer Dan before
/// Jordan, and `beth` should open on Bethel rather than on Aphek-in-the-
/// valley-of-Beth-something. Within a rank the more-referenced place
/// wins, because a gazetteer's own measure of how much a place matters
/// to scripture is how often scripture names it.
const int kPlaceMatchExact = 0;
const int kPlaceMatchPrefix = 1;
const int kPlaceMatchSubstring = 2;
const int kPlaceMatchNone = 3;

/// Best rank across the entry's English, Simplified and Traditional
/// names.
///
/// All three are searched whatever the reading version is, which is a
/// deliberate asymmetry with how names are *displayed* (#283: the script
/// follows the text on screen). Display is about reading; search is about
/// finding, and a reader in CUVS who knows a site as "Ashkelon" from a
/// commentary should not have to switch editions to look it up.
int placeMatchRank(BiblePlace place, String normalisedQuery) {
  if (normalisedQuery.isEmpty) return kPlaceMatchExact;
  var best = kPlaceMatchNone;
  for (final candidate in <String?>[
    place.name,
    place.simplified,
    place.traditional,
  ]) {
    if (candidate == null || candidate.isEmpty) continue;
    final hay = normalisePlaceQuery(candidate);
    if (hay.isEmpty) continue;
    final rank = hay == normalisedQuery
        ? kPlaceMatchExact
        : hay.startsWith(normalisedQuery)
            ? kPlaceMatchPrefix
            : hay.contains(normalisedQuery)
                ? kPlaceMatchSubstring
                : kPlaceMatchNone;
    if (rank < best) best = rank;
    if (best == kPlaceMatchExact) break;
  }
  return best;
}

/// True when [place] is named anywhere in [books].
///
/// A null or empty scope is "no limit" rather than "nothing" — the same
/// convention `search_scope.dart` uses, and the reason the picker cannot
/// signal cancel with an empty set.
bool placeIsInBooks(BiblePlace place, Set<String>? books) {
  if (books == null || books.isEmpty) return true;
  for (final r in place.refs) {
    if (books.contains(r.englishBook)) return true;
  }
  return false;
}

/// How many of [place]'s references fall inside [books].
///
/// A null or empty scope counts everything, matching [placeIsInBooks].
int refCountInBooks(BiblePlace place, Set<String>? books) {
  if (books == null || books.isEmpty) return place.refs.length;
  var n = 0;
  for (final r in place.refs) {
    if (books.contains(r.englishBook)) n++;
  }
  return n;
}

/// How the index list is ordered when nothing is typed.
enum AtlasSort {
  /// Most-referenced first — most-referenced **within the scope**, which
  /// is what makes this the only order that answers a question: scoped
  /// to Acts it prints the itinerary of Acts, and scoped to nothing it
  /// prints the geography scripture is mostly about.
  ///
  /// It used to rank on the whole-Bible count even under a scope, and
  /// that falsified the sentence above rather than implementing it: 23
  /// of the 62 books in the gazetteer opened with the wrong place at the
  /// top. Joshua led with Jerusalem, named 8 times, above the Jordan,
  /// named 58; Esther led with Jerusalem, named ONCE, above Susa, where
  /// the book is set; Nahum led with Tarshish over Nineveh. The ranking
  /// was really "the most famous places, among those this book happens
  /// to name", which is a question nobody asked.
  references,

  /// The English name, A–Z — an atlas index, and the order every
  /// commentary and lexicon the reader might reach for next shares.
  /// Sorted on the English name in every locale on purpose: sorting Han
  /// characters by code point produces an order no reader recognises.
  name,
}

/// The index, filtered and ordered.
///
/// Query ranking always outranks [sort]: a reader who typed something is
/// asking a question, and answering it in alphabetical order would bury
/// the exact hit under every substring one.
List<BiblePlace> atlasIndex(
  List<BiblePlace> places, {
  String query = '',
  Set<String>? scopeBooks,
  AtlasSort sort = AtlasSort.references,
}) {
  final q = normalisePlaceQuery(query);
  // (place, query rank, references inside the scope). The third is
  // counted once here rather than in the comparator, which sees each
  // place O(log n) times.
  final ranked = <(BiblePlace, int, int)>[];
  for (final p in places) {
    if (!placeIsInBooks(p, scopeBooks)) continue;
    final rank = placeMatchRank(p, q);
    if (rank == kPlaceMatchNone) continue;
    ranked.add((p, rank, refCountInBooks(p, scopeBooks)));
  }
  ranked.sort((a, b) {
    if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
    if (sort == AtlasSort.name) {
      final byName = a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
      if (byName != 0) return byName;
    }
    final byRefs = b.$3.compareTo(a.$3);
    if (byRefs != 0) return byRefs;
    // Ties on the scoped count fall back to the whole-Bible one, so a
    // book that names Zion and Zoar once each still leads with Zion.
    final byWhole = b.$1.refs.length.compareTo(a.$1.refs.length);
    if (byWhole != 0) return byWhole;
    return a.$1.id.compareTo(b.$1.id);
  });
  return [for (final e in ranked) e.$1];
}

/// One book's worth of a place's references.
class PlaceRefGroup {
  const PlaceRefGroup(this.englishBook, this.refs);

  final String englishBook;

  /// In chapter then verse order.
  final List<PlaceRef> refs;
}

/// A place's reference list, grouped by book in canonical order.
///
/// Jerusalem carries 755 references across 40 books. Printed flat that is
/// a wall a reader scrolls past; grouped it becomes a shape — where in
/// scripture this place is talked about — which is the same argument
/// #290 makes for the distribution chart.
///
/// [scopeBooks] filters, and filtering here rather than at the call site
/// is what keeps the count in the header and the rows underneath it
/// describing the same set.
List<PlaceRefGroup> groupRefsByBook(
  List<PlaceRef> refs, {
  Set<String>? scopeBooks,
}) {
  final byBook = <String, List<PlaceRef>>{};
  for (final r in refs) {
    if (scopeBooks != null &&
        scopeBooks.isNotEmpty &&
        !scopeBooks.contains(r.englishBook)) {
      continue;
    }
    (byBook[r.englishBook] ??= <PlaceRef>[]).add(r);
  }
  final ordered = canonicalScopeOrder(byBook.keys);
  return [
    for (final book in ordered)
      PlaceRefGroup(
        book,
        byBook[book]!
          ..sort((a, b) => a.chapter == b.chapter
              ? a.verse.compareTo(b.verse)
              : a.chapter.compareTo(b.chapter)),
      ),
  ];
}

/// One place's references, SPLIT by the scope rather than trimmed to it.
///
/// The difference between splitting and trimming is the whole of #319,
/// and it is not an inconsistency that the same filter does both.
///
/// Filtering the **index** means removing rows: "which places does
/// Obadiah name" has twelve answers and the other 1,259 are not answers.
/// Filtering **one place's references** means something else, because
/// the reader has already picked the place and this panel is about that
/// place. Dropping the three verses in Jeremiah that name Teman does not
/// narrow an answer — it withholds one, and leaves a reader unable to
/// tell "not in Obadiah" from "nowhere in scripture", which is the worse
/// of the two things they could believe.
///
/// So the scope REMOVES in [atlasIndex] and PARTITIONS here. Both halves
/// are counted and both are on screen: a filter that silently subtracts
/// is the defect #280 and #308 were each about.
class ScopedRefGroups {
  const ScopedRefGroups({required this.inScope, required this.elsewhere});

  /// Grouped by book, canonical order — the references the scope keeps.
  final List<PlaceRefGroup> inScope;

  /// The same, for the references it leaves out. Empty when no scope is
  /// set, because then nothing is left out.
  final List<PlaceRefGroup> elsewhere;

  static int _count(List<PlaceRefGroup> groups) =>
      groups.fold<int>(0, (n, g) => n + g.refs.length);

  int get inScopeCount => _count(inScope);
  int get elsewhereCount => _count(elsewhere);
}

/// [refs] grouped by book on both sides of [scopeBooks].
///
/// A null or empty scope puts everything in [ScopedRefGroups.inScope] —
/// the same "no limit rather than nothing" convention as
/// [placeIsInBooks].
ScopedRefGroups partitionRefsByScope(
  List<PlaceRef> refs, {
  Set<String>? scopeBooks,
}) {
  if (scopeBooks == null || scopeBooks.isEmpty) {
    return ScopedRefGroups(
      inScope: groupRefsByBook(refs),
      elsewhere: const <PlaceRefGroup>[],
    );
  }
  final inside = <PlaceRef>[];
  final outside = <PlaceRef>[];
  for (final r in refs) {
    (scopeBooks.contains(r.englishBook) ? inside : outside).add(r);
  }
  return ScopedRefGroups(
    inScope: groupRefsByBook(inside),
    elsewhere: groupRefsByBook(outside),
  );
}

/// The order labels are handed out in on a crowded map.
///
/// A map that draws 1,228 sites cannot label them all, and which ones it
/// gives up on is a cartographic decision rather than an accident of list
/// order. Three rules, in order: the selected place always keeps its
/// label, the emphasised layer outranks the context layer, and within a
/// layer the more-referenced place wins.
///
/// The third is what makes the map readable at world scale — Jerusalem,
/// Egypt and Babylon are named and the unnamed dots around them are
/// exactly the ones a reader is least likely to be looking for.
///
/// This is not only a new-feature concern. The passage map had the rule
/// inverted: it claimed the context layer's label rectangles *first*, so
/// a place merely elsewhere in the chapter could take the label off the
/// place the verse itself names.
List<BiblePlace> labelPriority(
  List<BiblePlace> emphasised,
  List<BiblePlace> context, {
  String? selectedId,
}) {
  int refsOf(BiblePlace p) => p.refs.length;
  final tiers = <List<BiblePlace>>[
    [
      for (final p in <BiblePlace>[...emphasised, ...context])
        if (p.id == selectedId) p
    ],
    [
      for (final p in emphasised)
        if (p.id != selectedId) p
    ],
    [
      for (final p in context)
        if (p.id != selectedId) p
    ],
  ];
  final out = <BiblePlace>[];
  final seen = <String>{};
  for (final tier in tiers) {
    final sorted = [...tier]..sort((a, b) {
        final byRefs = refsOf(b).compareTo(refsOf(a));
        return byRefs != 0 ? byRefs : a.id.compareTo(b.id);
      });
    for (final p in sorted) {
      if (seen.add(p.id)) out.add(p);
    }
  }
  return out;
}
