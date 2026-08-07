/// 2026-08-07 (SeekSparks): Eagle's View's Greek New Testament statistics.
///
/// `ConcordanceService` answers "how often does this word occur?" with one
/// number. That number is the least interesting thing about a word's
/// distribution. βδέλυγμα occurs 6 times — but three of those are in
/// Revelation and the other three are one each in the Synoptics, which is
/// the fact that means something.
///
/// This service supplies the shape behind the total: the count in each of
/// the 27 New Testament books, the word's rank *within* each of those
/// books, its totals across the Gospels & Acts / Paul / John / the other
/// authors, and its absolute and relative rank in the corpus.
///
/// It is the part of Eagle's View that BibleWorks has no equivalent for.
/// BibleWorks will count whatever you ask it to count; it ships no
/// precomputed table saying a word is 12th most common in Luke and absent
/// from Jude.
///
/// Greek only, and New Testament only — the source is a Westcott-Hort
/// profile, so a Hebrew Strong's number returns null and that is correct
/// rather than a gap.
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
  final Map<String, int> totals;

  /// `abs` and `rel` — the word's absolute and relative corpus rank.
  final Map<String, int> ranks;

  /// English book name -> (count in that book, rank within that book).
  /// Books where the word does not occur are absent entirely.
  final Map<String, (int, int?)> books;

  int get nt => totals['nt'] ?? 0;

  /// Books this word occurs in, commonest first. The ordering is what
  /// makes the distribution readable at a glance.
  List<MapEntry<String, (int, int?)>> get byFrequency {
    final list = books.entries.toList();
    list.sort((a, b) => b.value.$1.compareTo(a.value.$1));
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

  /// The concordance's own yardstick: vocabulary richness against Luke,
  /// the largest book in the New Testament.
  final double ratioVsLuke;
}

class GreekStatsService {
  static const _base = 'assets/greek_stats';

  static final Map<int, Map<String, GreekWordStats>> _buckets = {};
  static List<BookVocabulary>? _books;
  static String _attribution = '';

  static String get attribution => _attribution;

  /// The distribution of one Greek Strong's number, or null when the
  /// number is Hebrew, unknown, or malformed.
  static Future<GreekWordStats?> lookup(String strongs) async {
    final s = strongs.trim().toUpperCase();
    if (!s.startsWith('G')) return null;
    final n = int.tryParse(s.substring(1));
    if (n == null) return null;
    final bucket = n ~/ 1000;
    var loaded = _buckets[bucket];
    if (loaded == null) {
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
      _buckets[bucket] = loaded;
    }
    return loaded['G$n'];
  }

  /// The 27-book comparative profile.
  static Future<List<BookVocabulary>> books() async {
    final hit = _books;
    if (hit != null) return hit;
    try {
      final j = json.decode(await rootBundle.loadString('$_base/index.json'))
          as Map<String, dynamic>;
      _attribution = (j['attribution'] ?? '') as String;
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

  @visibleForTesting
  static void resetForTest() {
    _buckets.clear();
    _books = null;
    _attribution = '';
  }
}
