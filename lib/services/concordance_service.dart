import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:seeksparks/utils/short_book_name.dart' show shortBookName;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// Result of a concordance lookup for one Strong's number.
///
/// Two different units, both complete. `total` counts OCCURRENCES across
/// the whole Bible; `refs` lists the VERSES that contain at least one,
/// in canonical order. They differ whenever a word recurs inside a verse
/// — G25 occurs 143 times in 110 verses. `byBook` is the per-book
/// occurrence map keyed by canonical English book name, used by the
/// WordDistribution panel.
///
/// `refs` was capped at 500 by the build pipeline until v1.6.96. Because
/// the list is in canonical order, that cap was not a sample of the word
/// but a prefix of the canon, and every consumer that filtered or
/// intersected it inherited the prefix as an answer.
class ConcordanceResult {
  final int total;
  final List<ConcordanceRef> refs;
  final Map<String, int> byBook;
  const ConcordanceResult({
    required this.total,
    required this.refs,
    this.byBook = const {},
  });
}

class ConcordanceRef {
  final String englishBook;
  final int chapter;
  final int verse;
  final String label;
  const ConcordanceRef({
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.label,
  });

  /// The reference as a reader should SEE it.
  ///
  /// [label] is canonical English because `concordance.json` is keyed in
  /// English, and it stays that way — navigation and sorting both read
  /// it. Anything that puts a reference on SCREEN or on the CLIPBOARD
  /// goes through here instead, so the book name matches the [version]
  /// being read rather than the corpus the index happens to be built on.
  ///
  /// [short] gives the abbreviated form (民 32:18) for narrow columns.
  /// That is the same call BibleWorks makes for its own reference
  /// columns (help topic bwh42): the formal name does not fit, and a
  /// truncated formal name is worse than an abbreviation.
  String display(String locale, String? version, {bool short = false}) {
    final book = short
        ? shortBookName(englishBook, locale, version)
        : localeAwareBookName(englishBook, locale, version);
    return '$book $chapter:$verse';
  }

  static ConcordanceRef? tryParse(String label) {
    final m = RegExp(r'^(.+?)\s+(\d+):(\d+)$').firstMatch(label);
    if (m == null) return null;
    return ConcordanceRef(
      englishBook: m.group(1)!,
      chapter: int.parse(m.group(2)!),
      verse: int.parse(m.group(3)!),
      label: label,
    );
  }
}

/// Lazy loader for `assets/strongs/concordance.json` — the inverted
/// index from Strong's number to the verse references where that
/// number appears. The file is loaded once on first lookup and held in
/// memory. ~6.9 MB; acceptable for a Bible study app where any concord
/// lookup is preceded by a deliberate user action (selecting a verse,
/// opening the originals sheet, tapping a word).
class ConcordanceService {
  static Map<String, dynamic>? _cache;
  static Future<Map<String, dynamic>>? _loading;

  /// Parsed results, by Strong's number.
  ///
  /// [lookup] turns each ref string into a [ConcordanceRef] with a regex,
  /// and the lists run to 6,977 entries. KWIC re-looks-up the same number
  /// on every page of its pagination, so without this the reader pays for
  /// 6,977 regex matches per "load more".
  static final Map<String, ConcordanceResult?> _parsed = {};

  static Future<Map<String, dynamic>> _load() async {
    final raw = await rootBundle.loadString('assets/strongs/concordance.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// 2026-06-18 (v1.3.91): all Strong's numbers in the concordance whose
  /// normalized form starts with [prefix] (e.g. "G25" → G25, G250, G251, …
  /// G2599). Powers the `G25*` prefix wildcard in boolean search.
  ///
  /// [limit] stops a very short prefix unioning the whole lexicon: `G1✶`
  /// matches 1,067 numbers and `H6✶` 1,111. 13 prefixes exceed it, all of
  /// them a single digit. `cut` says the expansion was stopped, because a
  /// wildcard that silently dropped 767 of its words returns a confident
  /// answer about a query it never ran.
  static Future<({List<String> numbers, bool cut})> numbersMatchingPrefix(
      String prefix,
      {int limit = 300}) async {
    if (prefix.isEmpty) return (numbers: const <String>[], cut: false);
    _cache ??= await (_loading ??= _load());
    final out = <String>[];
    var cut = false;
    for (final key in _cache!.keys) {
      if (key.startsWith(prefix)) {
        if (out.length >= limit) {
          cut = true;
          break;
        }
        out.add(key);
      }
    }
    return (numbers: out, cut: cut);
  }

  static Future<ConcordanceResult?> lookup(String strongsNumber) async {
    if (strongsNumber.isEmpty) return null;
    if (_parsed.containsKey(strongsNumber)) return _parsed[strongsNumber];
    _cache ??= await (_loading ??= _load());
    final result = _parse(_cache![strongsNumber]);
    _parsed[strongsNumber] = result;
    return result;
  }

  static ConcordanceResult? _parse(Object? entry) {
    if (entry is! Map) return null;
    final n = entry['n'];
    final r = entry['r'];
    final b = entry['b'];
    if (r is! List) return null;
    final refs = <ConcordanceRef>[];
    for (final raw in r) {
      if (raw is String) {
        final parsed = ConcordanceRef.tryParse(raw);
        if (parsed != null) refs.add(parsed);
      }
    }
    final byBook = <String, int>{};
    if (b is Map) {
      for (final entry in b.entries) {
        final v = entry.value;
        if (v is int) byBook[entry.key.toString()] = v;
      }
    }
    return ConcordanceResult(
      total: n is int ? n : refs.length,
      refs: refs,
      byBook: byBook,
    );
  }
}
