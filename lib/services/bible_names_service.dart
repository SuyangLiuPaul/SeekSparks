/// 2026-08-07 (SeekSparks): Hitchcock's Bible Names Dictionary (1869).
///
/// 2,622 name meanings, and — this is the point — the OT half of them is
/// reachable from nothing else the app ships. Thayer's glosses proper
/// nouns inline (`Aaron = "light-bringer"`) but Thayer's is a New
/// Testament lexicon, so 2,213 of Hitchcock's names have no counterpart
/// here at all.
///
/// Where both have an opinion they often DISAGREE — Hitchcock reads
/// Aaron as "a teacher; lofty; mountain of strength", Thayer as
/// "light-bringer"; Barnabas as "son of consolation" against "son of
/// rest". Neither is authoritative, so the pane prints both, labelled by
/// source, the way [StrongsEntry.complementaryGloss] already does for
/// the English/Chinese pair.
///
/// LOOKUP is by the English name, which the app only has as the head of
/// a Strong's gloss ("Aharon, the brother of Moses"). That head is a
/// transliteration and Hitchcock's is KJV spelling, so roughly half the
/// Hebrew entries simply do not match — Abshalom/Absalom,
/// Abimelek/Abimelech. A miss renders nothing, which is the right
/// failure: fuzzy matching a name dictionary would attach the wrong
/// meaning to the right word, and a reader has no way to catch that.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class BibleNamesService {
  static Map<String, String>? _byName;
  static String _attribution = '';
  static Future<Map<String, String>>? _inflight;

  static String get attribution => _attribution;

  /// Letters only, lower case — absorbs the hyphen and spacing drift
  /// between "Abialbon" and "Abi-albon". Verified collision-free across
  /// all 2,622 names, so it cannot merge two distinct people.
  static String _key(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  /// The proper name at the head of a Strong's gloss, if there is one.
  /// "Abigail or Abigal, the name of two Israelitesses" yields both
  /// spellings; "the sacred name" yields none.
  static List<String> namesInGloss(String gloss) {
    final head = gloss.split(',').first.replaceAll(RegExp(r'\(.*?\)'), '');
    final out = <String>[];
    for (final part in head.split(RegExp(r'\bor\b'))) {
      final p = part.trim().replaceAll(RegExp(r"[.;:]+$"), '');
      if (p.isNotEmpty && RegExp(r"^[A-Z][A-Za-z'\- ]*$").hasMatch(p)) {
        out.add(p);
      }
    }
    return out;
  }

  static Future<String?> lookup(String name) async {
    if (name.trim().isEmpty) return null;
    final table = _byName ?? await (_inflight ??= _load());
    return table[_key(name)];
  }

  /// The first of [namesInGloss] that Hitchcock knows.
  static Future<String?> lookupFromGloss(String gloss) async {
    for (final n in namesInGloss(gloss)) {
      final hit = await lookup(n);
      if (hit != null) return hit;
    }
    return null;
  }

  static Future<Map<String, String>> _load() async {
    try {
      final text = await rootBundle.loadString('assets/bible_names.json');
      final decoded = json.decode(text) as Map<String, dynamic>;
      _attribution = (decoded['attribution'] ?? '') as String;
      final list = (decoded['names'] as List?) ?? const [];
      final out = <String, String>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final n = (m['n'] ?? '') as String;
        final meaning = (m['m'] ?? '') as String;
        if (n.isEmpty || meaning.isEmpty) continue;
        out[_key(n)] = meaning;
      }
      _byName = out;
      return out;
    } catch (_) {
      _byName = const {};
      return const {};
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _byName = null;
    _inflight = null;
    _attribution = '';
  }
}
