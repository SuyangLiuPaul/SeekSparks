/// 2026-08-06 (SeekSparks): Strong's-tagged translation text.
///
/// Until now no translation SeekSparks shipped carried Strong's tagging,
/// so hovering a word in a translation line could only report the
/// *verse*. BibleWorks reports the *word* — its translations ship
/// tagged, and that tagging is part of its licensed data.
///
/// 和合本【雅伟】简体版＋ (修订编辑：孙树民) is tagged, and its publisher
/// cleared it for use here, so the Chinese column can now do exactly
/// what BibleWorks' English column does.
///
/// 2026-08-06: the Berean Standard Bible joins it. That mattered
/// because tagging was Chinese-only — an English reader hovering a word
/// learned nothing the verse number did not already tell them. The BSB
/// is public domain AND ships word-aligned to the WLC/Nestle base, the
/// rare pairing that lets an English column be tagged without licensing
/// anything. Built by `tools/import_bsb.py`.
///
/// Assets are built by `tools/import_yahweh_modules.py` into
/// `assets/tagged/<version>/<book>.json`, one file per book, loaded
/// lazily — the whole set is ~13 MB, far too much to hold eagerly.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One run of translation text and the original-language word behind it.
@immutable
class TaggedRun {
  const TaggedRun({
    required this.text,
    required this.strongs,
    this.implied = const [],
    this.grammar = const [],
  });

  /// The translation text as printed, punctuation included.
  final String text;

  /// Primary Strong's number, or '' for text the tagger left unmarked
  /// (opening quotes, inserted connectives).
  final String strongs;

  /// Numbers the original has that this text does not render — the
  /// Hebrew direct-object marker אֵת, the Greek article. Worth showing
  /// as secondary, never as the word's own identity.
  final List<String> implied;

  /// Grammar codes: Hebrew stem/aspect, Greek tense-voice-mood.
  final List<String> grammar;

  bool get isTagged => strongs.isNotEmpty;

  factory TaggedRun.fromJson(Map<String, dynamic> j) => TaggedRun(
        text: (j['w'] ?? '') as String,
        strongs: (j['s'] ?? '') as String,
        implied: ((j['i'] as List?) ?? const []).cast<String>(),
        grammar: ((j['g'] as List?) ?? const []).cast<String>(),
      );
}

class TaggedTextService {
  /// Version codes that have a tagged asset set. Checked before any
  /// load so an untagged version costs nothing.
  /// 2026-08-07: kjvs / lxxwh / cuvs-plus join them, imported from
  /// Eagle's View by `tools/import_eaglesview.py`. That module tags
  /// BOTH testaments, so the English and Chinese columns are now tagged
  /// in the Old Testament too — previously only the BSB reached back
  /// past Malachi.
  static const Set<String> taggedVersions = {
    'cuvs-yhwh',
    'bsb',
    'kjvs',
    'lxxwh',
    'cuvs-plus',
    // 'cuv-yhwd' was here. Removed with its catalog row — it duplicated
    // cuvs-yhwh's text AND its tagging, only coarser. See the note at the
    // end of lib/constants/bible_versions.dart.
  };

  static final Map<String, Map<String, List<TaggedRun>>> _cache = {};
  static final Map<String, Future<Map<String, List<TaggedRun>>>> _inflight = {};

  static bool supports(String version) =>
      taggedVersions.contains(version.toLowerCase());

  /// The tagged runs for one verse, or null when this version has no
  /// tagging or the verse is missing. Callers fall back to plain text.
  static Future<List<TaggedRun>?> forVerse({
    required String version,
    required String englishBook,
    required int chapter,
    required int verse,
  }) async {
    if (!supports(version)) return null;
    final book = await _book(version, englishBook);
    return book?['$chapter:$verse'];
  }

  static Future<Map<String, List<TaggedRun>>?> _book(
      String version, String englishBook) async {
    final key = '${version.toLowerCase()}/${_fileName(englishBook)}';
    final hit = _cache[key];
    if (hit != null) return hit;
    final loaded = await (_inflight[key] ??= _load(key));
    return loaded.isEmpty ? null : loaded;
  }

  static Future<Map<String, List<TaggedRun>>> _load(String key) async {
    try {
      final raw = await rootBundle.loadString('assets/tagged/$key.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final out = <String, List<TaggedRun>>{
        for (final e in decoded.entries)
          e.key: (e.value as List)
              .map((r) => TaggedRun.fromJson(r as Map<String, dynamic>))
              .toList(growable: false),
      };
      _cache[key] = out;
      return out;
    } catch (_) {
      // A missing book is normal for a version with a partial canon;
      // cache the emptiness so we do not retry on every verse.
      _cache[key] = const {};
      return const {};
    }
  }

  /// "1 Corinthians" → "1_corinthians", matching the importer's output
  /// and the existing assets/originals/ naming.
  static String _fileName(String englishBook) =>
      englishBook.toLowerCase().replaceAll(' ', '_');
}
