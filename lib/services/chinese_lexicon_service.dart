/// 2026-08-06 (SeekSparks): the Chinese BDB + Thayer lexicon.
///
/// Imported by `tools/import_yahweh_modules.py` from the MySword module
/// the pastor at yahwehdehua.net publishes and cleared for use here.
///
/// This is a materially deeper source than the CBOL gloss already on
/// [StrongsEntry]: it carries the lemma, transliteration, etymology with
/// TWOT/TDNT reference, the 钦定本 (KJV) occurrence counts, and numbered
/// senses — the shape a printed lexicon entry actually has. For a
/// Chinese reader it is better than the English column BibleWorks
/// shows, not a translation of it.
///
/// It also decodes the GRAMMAR codes (H8804, G5656 …), which nothing
/// else in the app could: those are the blue numbers on a tagged line,
/// and until now they printed as bare numbers with no way to find out
/// what they meant.
///
/// Loaded lazily, per language. The two files are ~3.5 MB together —
/// far too much to hold at boot for a pane the reader may never open.
///
/// SCRIPT: the module is Simplified Chinese only. A `zh-Hant` reader
/// gets the Simplified text rather than nothing; that is a deliberate
/// choice, not an oversight — see [isSimplifiedOnly].
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One lexicon entry, in the shape the source module stores.
@immutable
class ChineseLexEntry {
  const ChineseLexEntry({
    required this.number,
    this.lemma = '',
    this.translit = '',
    this.etymology = '',
    this.usage = '',
    this.senses = const [],
    this.parsing = const [],
  });

  final String number;

  /// The Hebrew/Greek headword, e.g. שׁמים / Ἰσαάκ.
  final String lemma;
  final String translit;

  /// Derivation plus TWOT/TDNT reference and part of speech, as one
  /// line: "字根已不使用, 意为崇高; TWOT - 2407a; 阳性名词".
  final String etymology;

  /// KJV rendering counts: "钦定本 - heaven 398, air 21, …; 420".
  final String usage;

  /// Numbered senses, already split per line.
  final List<String> senses;

  /// Present INSTEAD of the above when [number] is a grammar code —
  /// "时态 - 简单过去式 见 5777", "语态 - 主动 见 5784", …
  final List<String> parsing;

  bool get isGrammarCode => parsing.isNotEmpty;
  bool get isEmpty =>
      lemma.isEmpty && senses.isEmpty && parsing.isEmpty;

  factory ChineseLexEntry.fromJson(String number, Map<String, dynamic> j) =>
      ChineseLexEntry(
        number: number,
        lemma: (j['l'] ?? '') as String,
        translit: (j['t'] ?? '') as String,
        etymology: (j['e'] ?? '') as String,
        usage: (j['u'] ?? '') as String,
        senses: ((j['s'] as List?) ?? const []).cast<String>(),
        parsing: ((j['p'] as List?) ?? const []).cast<String>(),
      );
}

class ChineseLexiconService {
  /// The source is Simplified only, so a Traditional reader sees
  /// Simplified glyphs here. Surfaced to the UI so the pane can say so
  /// rather than letting a 繁體 reader assume it converted and failed.
  static bool isSimplifiedOnly(String locale) =>
      locale.toLowerCase().startsWith('zh-hant');

  /// True when this locale should prefer the Chinese lexicon at all.
  static bool appliesTo(String locale) =>
      locale.toLowerCase().startsWith('zh');

  static final Map<String, Map<String, ChineseLexEntry>> _cache = {};
  static final Map<String, Future<Map<String, ChineseLexEntry>>> _inflight = {};

  /// The entry for a Strong's number or a grammar code. Null when the
  /// module has nothing for it — callers fall back to the English
  /// lexicon rather than showing a gap.
  static Future<ChineseLexEntry?> lookup(String number) async {
    if (number.isEmpty) return null;
    final head = number[0].toUpperCase();
    if (head != 'H' && head != 'G') return null;
    final file = head == 'H' ? 'bdb_zh' : 'thayer_zh';
    final table = await (_cache[file] != null
        ? Future.value(_cache[file]!)
        : (_inflight[file] ??= _load(file)));
    final hit = table[number.toUpperCase()];
    return (hit == null || hit.isEmpty) ? null : hit;
  }

  static Future<Map<String, ChineseLexEntry>> _load(String file) async {
    try {
      final raw = await rootBundle.loadString('assets/strongs/$file.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final out = <String, ChineseLexEntry>{
        for (final e in decoded.entries)
          e.key.toUpperCase(): ChineseLexEntry.fromJson(
              e.key, e.value as Map<String, dynamic>),
      };
      _cache[file] = out;
      return out;
    } catch (_) {
      // Cache the emptiness: a missing asset must not mean a failed
      // bundle read on every single hover.
      _cache[file] = const {};
      return const {};
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _cache.clear();
    _inflight.clear();
  }
}
