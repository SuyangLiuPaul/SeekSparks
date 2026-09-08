/// 2026-08-07 (SeekSparks): Eagle's View's Greek New Testament statistics.
///
/// `ConcordanceService` answers "how often does this word occur?" with one
/// number. That number is the least interesting thing about a word's
/// distribution. βδέλυγμα occurs 6 times — but three of those are in
/// Revelation and the other three are one each in the Synoptics, which is
/// the fact that means something.
///
/// This service supplies the shape behind the total: the count in each of
/// the 27 New Testament books, the same count RESCALED to Luke's length,
/// the word's totals across the Gospels & Acts / Paul / John / the other
/// authors, and — derived here rather than shipped — where the word sits
/// in a book's own frequency order.
///
/// It is the part of Eagle's View that BibleWorks has no equivalent for.
/// BibleWorks will count whatever you ask it to count; it ships no
/// precomputed table saying a word is 2nd most common in Luke and absent
/// from Jude.
///
/// Greek only, and New Testament only — the source is a Westcott-Hort
/// profile, so a Hebrew Strong's number returns null and that is correct
/// rather than a gap. Callers must SAY so; an empty panel over an Old
/// Testament verse reads as a bug.
///
/// Built by `tools/import_eaglesview_greek_stats.py` from `Default.cdb`.
/// Bucketed by Strong's thousand so a lookup pulls ~200 KB, not 1.1 MB.
///
/// Rights: corpus statistics © 2007 AOSurvey Co., Ltd., supplied with
/// Eagle's View, used by the permission the ministry granted.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// What the asset knows about one word in one book.
///
/// **[scaledToLuke] is not a rank.** It was read as one for a month — the
/// Stats pane printed `Rev 3 ·#6` for βδέλυγμα, which says the word is
/// the sixth commonest in Revelation, and it is the 343rd. The asset's
/// column is `<abbr> RC`, and what it actually holds was settled against
/// the shipped data, not against the column name:
///
///   * every one of the 18,949 (count, RC) pairs in the asset satisfies
///     `RC == round(count × k)` for a single constant `k` per book —
///     solved as an interval intersection over all of them, with no
///     contradiction in any of the 27 books;
///   * in Luke itself `k` is 1, so RC and count are equal for all 2,033
///     of its words — which no rank could be;
///   * every other `k` runs the same way as, and within about 1.5% of,
///     Luke's length over that book's: Revelation 2.00 against 1.98,
///     Jude 43.97 against 42.67, Galatians 8.85 against 8.72.
///
/// So it is the count the book would have shown if the book were as long
/// as Luke. That is the whole Eagle's View idea: raw counts cannot be
/// compared across a 19,457-word Gospel and a 219-word letter, and this
/// column makes them comparable.
///
/// **The residual 1.5% is not explained**, and is recorded rather than
/// smoothed over. `index.json`'s `ratioVsLuke` IS the plain length ratio
/// — `round(19457 / totalWords, 1)` reproduces all 27 values, and the
/// per-book counts in the word files sum to those `totalWords` exactly
/// in 26 books and one over in Revelation — so the source program
/// derived RC from a slightly different divisor
/// than the one it published, and the asset does not say which. The gap
/// runs in both directions across books, so it is not a systematic
/// exclusion. It is far too small to touch any ORDERING, which is what
/// this figure is for; it is big enough that a reader who multiplies a
/// count by the printed ratio will not always land on the printed
/// figure, which is why the UI says "about".
///
/// **Named fields were tried and rejected**, and the reason is worth
/// keeping. `({int count, int? scaledToLuke})` would make the swap a
/// compile error rather than a reading error, which is exactly what this
/// pair needs — but `lib/pages/workbench_page.dart` reads `e.value.$2`
/// to build the full-page chart's figures, and that file belongs to
/// another hand. A type change that forces an edit into someone else's
/// file to compile is not a safety improvement, it is a merge conflict.
/// So the record stays positional and the names arrive as an extension:
/// every call site in this feature reads `.count` and `.scaledToLuke`,
/// the existing one keeps compiling, and
/// `test/greek_relative_ranking_test.dart` holds the two apart by value.
typedef GreekBookCount = (int, int?);

/// The two figures by name. See [GreekBookCount] for what they are and
/// why they are not fields.
extension GreekBookCountFields on GreekBookCount {
  /// Times the word occurs in that book. The number a reader can check.
  int get count => $1;

  /// The same occurrence count rescaled to Luke's length — **not a
  /// rank**. Null where the asset gave no figure.
  int? get scaledToLuke => $2;
}

/// One Greek word's distribution across the New Testament.
@immutable
class GreekWordStats {
  const GreekWordStats({
    required this.strongs,
    required this.greek,
    required this.gloss,
    required this.partOfSpeech,
    required this.roots,
    required this.totals,
    required this.ranks,
    required this.books,
  });

  final String strongs;
  final String greek;
  final String gloss;

  /// "verb", "noun feminine", "adjective" — the source's own vocabulary.
  final String partOfSpeech;

  /// Strong's numbers this word is built from. Eagle's View's own
  /// etymology: G1 (Α) decomposes to G427 + G260.
  final List<String> roots;

  /// `nt`, `gospelsActs`, `paul`, `john`, `otherAuthors`. Absent means
  /// zero — the importer drops zeroes to halve the asset.
  ///
  /// **The four author groups overlap and do not partition the corpus.**
  /// Checked against all 5,696 words: `gospelsActs` is Matthew..Acts,
  /// `john` is the Fourth Gospel PLUS 1–3 John and Revelation, `paul` is
  /// Romans..Philemon, `otherAuthors` is Hebrews, James, 1–2 Peter and
  /// Jude — so John's Gospel is counted twice and the four sum to more
  /// than `nt` for any word that occurs in it (ἀγάπη: 9+73+30+9 = 121
  /// against an `nt` of 114). A UI that prints the four in a row has to
  /// say this, or it prints an arithmetic error.
  final Map<String, int> totals;

  /// `abs` and `rel` — the word's absolute and relative rank in the
  /// corpus as a whole.
  ///
  /// **Always empty in the shipped asset**, and kept anyway. The
  /// importer reads `R(A)` and `R(R)` out of `Default.cdb`, and both
  /// columns export blank for every one of the 5,696 words, so the key
  /// is dropped entirely. `index.json` still counts words "in R(A) 1-2"
  /// per book, which is evidence the columns meant something in the
  /// original program — but nothing in the asset says what, and a number
  /// whose unit cannot be established must not be put on screen. Nothing
  /// may depend on this map until a re-import fills it;
  /// `test/greek_relative_ranking_test.dart` pins that it is empty so a
  /// future import that fills it is noticed rather than assumed.
  final Map<String, int> ranks;

  /// English book name -> what the asset knows about the word there.
  /// Books where the word does not occur are absent entirely.
  final Map<String, GreekBookCount> books;

  int get nt => totals['nt'] ?? 0;

  /// Books this word occurs in, **by raw count**, commonest first.
  ///
  /// One of the two orders this data supports, and the ordinary one:
  /// where the word literally appears most often.
  List<MapEntry<String, GreekBookCount>> get byFrequency {
    final list = books.entries.toList();
    list.sort((a, b) => b.value.count.compareTo(a.value.count));
    return list;
  }

  /// Books this word occurs in, **scaled to Luke's length**, densest
  /// first.
  ///
  /// The other order, and the one Eagle's View was built around. ἀγάπη
  /// occurs 18 times in 1 John and 13 in 1 Corinthians, so [byFrequency]
  /// leads with 1 John either way — but Philemon's 3 occurrences in 334
  /// words outrank both once length is taken out, and no absolute count
  /// can show that.
  ///
  /// Ties fall back to the raw count so the order is total; a book with
  /// no scaled figure sorts last rather than as zero, since "the asset
  /// did not say" is not "the word is thin here".
  List<MapEntry<String, GreekBookCount>> get byDensity {
    final list = books.entries.toList();
    list.sort((a, b) {
      final av = a.value.scaledToLuke, bv = b.value.scaledToLuke;
      if (av == null && bv == null) return b.value.count.compareTo(a.value.count);
      if (av == null) return 1;
      if (bv == null) return -1;
      final byScaled = bv.compareTo(av);
      return byScaled != 0 ? byScaled : b.value.count.compareTo(a.value.count);
    });
    return list;
  }

  factory GreekWordStats.fromJson(Map<String, dynamic> j) => GreekWordStats(
        strongs: (j['g'] ?? '') as String,
        greek: (j['w'] ?? '') as String,
        gloss: (j['d'] ?? '') as String,
        partOfSpeech: (j['p'] ?? '') as String,
        roots: [for (final r in (j['r'] as List?) ?? const []) r as String],
        totals: {
          for (final e in ((j['totals'] ?? const {}) as Map).entries)
            e.key as String: (e.value as num).toInt(),
        },
        ranks: {
          for (final e in ((j['rank'] ?? const {}) as Map).entries)
            e.key as String: (e.value as num).toInt(),
        },
        books: {
          for (final e in ((j['books'] ?? const {}) as Map).entries)
            e.key as String: (
              ((e.value as List)[0] as num).toInt(),
              (e.value as List).length > 1 && e.value[1] != null
                  ? (e.value[1] as num).toInt()
                  : null,
            ),
        },
      );
}

/// One New Testament book's vocabulary profile.
///
/// Deliberately not on any screen as a 27-row table — see the
/// `BookVocabulary` entry in `test/data_surface_reachability_test.dart`,
/// which records why (the Bible Tools Overview already prints running
/// words and distinct lemmas for all 66 books from the app's own tagged
/// text, and a second table would restate two of these four columns with
/// DIFFERENT numbers). [GreekStatsService.lengthRatioVsLuke] and
/// [GreekStatsService.lukeRunningWords] hand out the two figures a
/// reader needs to interpret [GreekBookCount.scaledToLuke], which is a
/// caption on a number already on screen rather than a rival table.
@immutable
class BookVocabulary {
  const BookVocabulary({
    required this.name,
    required this.abbr,
    required this.totalWords,
    required this.distinctWords,
    required this.meanOccurrence,
    required this.ratioVsLuke,
  });

  final String name;
  final String abbr;

  /// Running words — the length of the book.
  final int totalWords;

  /// Distinct Greek words — the size of its vocabulary.
  final int distinctWords;
  final double meanOccurrence;

  /// How many times this book fits into Luke: Luke's running words over
  /// this book's, to one decimal. 1.0 for Luke itself, 88.8 for 3 John.
  ///
  /// It is a LENGTH ratio, not a richness one — measured against the
  /// asset, `count × ratioVsLuke` reproduces every `scaledToLuke` figure
  /// in the word files, and `distinctWords` has nothing to do with it.
  final double ratioVsLuke;
}

/// Where every word of one book stands in that book's frequency order.
///
/// Derived here, not imported: the asset stores a count and a
/// Luke-scaled count per book and no rank at all. "The 2nd commonest
/// word in Luke" is the sentence both the import script and this file
/// have advertised since 2026-08-07 as the thing BibleWorks cannot do,
/// and it was the one sentence the app could not say.
///
/// Ranking within a book is the same either way — [GreekBookCount.count]
/// and [GreekBookCount.scaledToLuke] differ by one constant factor per
/// book, so they order that book's words identically. The scaled figure
/// earns its keep ACROSS books, not inside one. This ranks by raw count
/// because that is the number a reader can check by hand.
@immutable
class GreekBookRanking {
  const GreekBookRanking({
    required this.book,
    required this.rankedWords,
    required Map<String, int> ranks,
  }) : _ranks = ranks;

  /// Canonical English book name, as `index.json` spells it.
  final String book;

  /// How many distinct words the profile records in this book — the
  /// denominator, so a rank is never printed without its population.
  ///
  /// Counted from the profile itself rather than read off
  /// [BookVocabulary.distinctWords], which disagrees by one for
  /// Revelation (906 against the 907 words actually filed under it). A
  /// rank out of a total the same table cannot produce is worse than no
  /// rank.
  final int rankedWords;

  final Map<String, int> _ranks;

  /// Competition ranking (1, 2, 2, 4): every word on the same count
  /// gets the same rank. Ties are the norm at the thin end — 950 of
  /// Luke's 2,033 words occur exactly once — and inventing an order
  /// between them would be a fabricated fact.
  int? rankOf(String strongs) => _ranks[strongs.trim().toUpperCase()];
}

class GreekStatsService {
  static const _base = 'assets/greek_stats';

  static final Map<int, Map<String, GreekWordStats>> _buckets = {};
  static final Map<String, GreekBookRanking> _rankings = {};
  static List<BookVocabulary>? _books;
  static List<int> _bucketIds = const [];
  static String _attribution = '';

  static String get attribution => _attribution;

  /// The distribution of one Greek Strong's number, or null when the
  /// number is Hebrew, unknown, or malformed.
  static Future<GreekWordStats?> lookup(String strongs) async {
    final n = _strongsNumber(strongs);
    if (n == null) return null;
    return (await _bucket(n ~/ 1000))['G$n'];
  }

  /// The 27-book comparative profile.
  static Future<List<BookVocabulary>> books() async {
    final hit = _books;
    if (hit != null) return hit;
    try {
      final j = json.decode(await rootBundle.loadString('$_base/index.json'))
          as Map<String, dynamic>;
      _attribution = (j['attribution'] ?? '') as String;
      _bucketIds = [
        for (final b in (j['buckets'] as List? ?? const [])) (b as num).toInt(),
      ];
      return _books = [
        for (final b in (j['books'] as List? ?? const []))
          if (b['name'] != null)
            BookVocabulary(
              name: b['name'] as String,
              abbr: (b['abbr'] ?? '') as String,
              totalWords: ((b['totalWords'] ?? 0) as num).toInt(),
              distinctWords: ((b['distinctWords'] ?? 0) as num).toInt(),
              meanOccurrence: ((b['meanOccurrence'] ?? 0) as num).toDouble(),
              ratioVsLuke: ((b['ratioVsLuke'] ?? 0) as num).toDouble(),
            ),
      ];
    } catch (_) {
      return _books = const [];
    }
  }

  /// Luke's running words — the baseline every `scaledToLuke` figure is
  /// expressed in, and therefore a number the UI has to be able to print
  /// beside them. A ratio whose baseline is off screen is not a ratio,
  /// it is a decoration. 0 if the index will not load.
  static Future<int> lukeRunningWords() async {
    for (final b in await books()) {
      if (b.ratioVsLuke == 1) return b.totalWords;
    }
    return 0;
  }

  /// How many times [book] fits into Luke, or null for a name the
  /// profile does not carry (every Old Testament book, and any
  /// misspelling).
  static Future<double?> lengthRatioVsLuke(String book) async {
    for (final b in await books()) {
      if (b.name == book) return b.ratioVsLuke;
    }
    return null;
  }

  /// Every word of [book] placed in that book's frequency order, or null
  /// for a book the profile does not cover.
  ///
  /// **This is the expensive call and the only one.** A rank needs the
  /// whole corpus — a word's position among Mark's 1,342 depends on the
  /// other 1,341 — so it loads all six bucket files, about 1.1 MB of
  /// JSON, where [lookup] loads one. Callers must therefore make it a
  /// consequence of the reader ASKING (opening the ranking), never of a
  /// verse coming into focus. Both the corpus and the per-book order are
  /// cached for the process, so the cost is paid once.
  static Future<GreekBookRanking?> rankingIn(String book) async {
    final hit = _rankings[book];
    if (hit != null) return hit;

    // `books()` for the bucket list, which is in `index.json` rather
    // than assumed to be 0..5: a re-import that added a seventh
    // thousand would otherwise rank a corpus quietly missing it.
    await books();
    final counts = <String, int>{};
    for (final id in _bucketIds) {
      for (final e in (await _bucket(id)).entries) {
        final here = e.value.books[book];
        if (here != null) counts[e.key] = here.count;
      }
    }
    if (counts.isEmpty) return null;

    final ordered = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ranks = <String, int>{};
    int? previous;
    var rank = 0;
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].value != previous) {
        rank = i + 1;
        previous = ordered[i].value;
      }
      ranks[ordered[i].key] = rank;
    }
    return _rankings[book] = GreekBookRanking(
      book: book,
      rankedWords: ordered.length,
      ranks: ranks,
    );
  }

  /// `G26` / `g26` / ` G26 ` -> 26. Null for Hebrew and for anything
  /// that is not a Strong's number at all.
  static int? _strongsNumber(String strongs) {
    final s = strongs.trim().toUpperCase();
    if (!s.startsWith('G')) return null;
    return int.tryParse(s.substring(1));
  }

  /// One thousand's worth of words, cached. A bucket that will not load
  /// caches as empty so a missing file is not re-read on every word.
  static Future<Map<String, GreekWordStats>> _bucket(int bucket) async {
    final hit = _buckets[bucket];
    if (hit != null) return hit;
    Map<String, GreekWordStats> loaded;
    try {
      final j = json.decode(await rootBundle.loadString('$_base/w/$bucket.json'))
          as Map<String, dynamic>;
      loaded = {
        for (final e in j.entries)
          e.key: GreekWordStats.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      loaded = const {};
    }
    return _buckets[bucket] = loaded;
  }

  @visibleForTesting
  static void resetForTest() {
    _buckets.clear();
    _rankings.clear();
    _books = null;
    _bucketIds = const [];
    _attribution = '';
  }
}
