/// 2026-08-07 (SeekSparks): Thayer's Greek-English Lexicon, in English.
///
/// The app already shipped Thayer's — but only in Chinese
/// (`assets/strongs/thayer_zh.json`). An English reader hovering a Greek
/// word got Strong's 1890 one-line gloss and nothing else, while a
/// Chinese reader got the full article. `assets/thayer.json` closes that
/// asymmetry, and additionally supplies G5627–G5798, the parsing codes a
/// tagged line carries, which English readers previously had no way at
/// all to decode.
///
/// Parsed on demand rather than at load: the file is one flat block of
/// text per entry, and turning all 5,799 into structures at boot would
/// cost more than a reader who opens three of them ever recovers.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/utils/thayer_parse.dart';

class ThayerService {
  static Map<String, String>? _raw;
  static String _attribution = '';
  static Future<Map<String, String>>? _inflight;
  static final Map<String, ThayerEntry?> _parsed = {};

  /// The licence line the asset carries. Rendered under the entry —
  /// the source asked for it, and a reader is entitled to know which
  /// edition they are reading.
  static String get attribution => _attribution;

  /// True for the numbers this lexicon covers at all. Thayer's is a New
  /// Testament lexicon, so Hebrew numbers never hit the bundle.
  static bool covers(String number) => number.toUpperCase().startsWith('G');

  static Future<ThayerEntry?> lookup(String number) async {
    if (!covers(number)) return null;
    final key = number.toUpperCase();
    if (_parsed.containsKey(key)) return _parsed[key];
    final table = _raw ?? await (_inflight ??= _load());
    final raw = table[key];
    if (raw == null || raw.trim().isEmpty) {
      _parsed[key] = null;
      return null;
    }
    final entry = parseThayerEntry(key, raw);
    final out = entry.isEmpty ? null : entry;
    _parsed[key] = out;
    return out;
  }

  static Future<Map<String, String>> _load() async {
    try {
      final text = await rootBundle.loadString('assets/thayer.json');
      final decoded = json.decode(text) as Map<String, dynamic>;
      _attribution = (decoded['attribution'] ?? '') as String;
      final entries = (decoded['entries'] as Map<String, dynamic>?) ?? const {};
      final out = <String, String>{
        for (final e in entries.entries)
          e.key.toUpperCase(): e.value as String,
      };
      _raw = out;
      return out;
    } catch (_) {
      // Cache the emptiness: a missing asset must not mean a failed
      // bundle read on every hover.
      _raw = const {};
      return const {};
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _raw = null;
    _inflight = null;
    _attribution = '';
    _parsed.clear();
  }
}
