import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:seeksparks/models/original_word.dart';

/// Lazy loader for the tagged original-language Bible text.
///
/// Per-book JSON lives at `assets/originals/{slug}.json` with the shape
/// `{ "1:1": [{w, s, t?, m?}, ...], ... }`. A book that has no bundled
/// asset (e.g. while we are still rolling out coverage) is cached as an
/// empty map so the second lookup doesn't re-hit the bundle.
class OriginalsService {
  static final Map<String, Map<String, List<OriginalWord>>> _byBook = {};
  static final Map<String, Future<Map<String, List<OriginalWord>>>>
      _loading = {};

  static String _slug(String englishBook) {
    return englishBook
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '');
  }

  static Future<Map<String, List<OriginalWord>>> _load(String book) async {
    final slug = _slug(book);
    try {
      final raw =
          await rootBundle.loadString('assets/originals/$slug.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in map.entries)
          entry.key: (entry.value as List)
              .map((w) => OriginalWord.fromJson(w as Map<String, dynamic>))
              .toList(growable: false),
      };
    } catch (_) {
      return <String, List<OriginalWord>>{};
    }
  }

  static Future<List<OriginalWord>?> forVerse(
    String englishBook,
    int chapter,
    int verse,
  ) async {
    if (!_byBook.containsKey(englishBook)) {
      _byBook[englishBook] =
          await (_loading[englishBook] ??= _load(englishBook));
    }
    final words = _byBook[englishBook]?['$chapter:$verse'];
    if (words == null || words.isEmpty) return null;
    return words;
  }

  /// Every original-language word in one chapter, in verse order.
  ///
  /// 2026-08-06: added for the Word List Manager, which counts a whole
  /// passage rather than looking a verse up. Reuses the same per-book
  /// cache `forVerse` fills, so opening the word list for a chapter you
  /// are already reading costs no extra load.
  static Future<List<OriginalWord>> forChapter(
    String englishBook,
    int chapter,
  ) async {
    final book = await _bookMap(englishBook);
    final out = <OriginalWord>[];
    // Verse keys are "c:v" strings; walk them numerically so the list
    // is in reading order rather than "10" before "2".
    final verses = <int>[];
    for (final key in book.keys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      if (int.tryParse(parts[0]) != chapter) continue;
      final v = int.tryParse(parts[1]);
      if (v != null) verses.add(v);
    }
    verses.sort();
    for (final v in verses) {
      out.addAll(book['$chapter:$v'] ?? const []);
    }
    return out;
  }

  /// Every original-language word in a book, in reading order.
  static Future<List<OriginalWord>> forBook(String englishBook) async {
    final book = await _bookMap(englishBook);
    final keys = book.keys.toList()
      ..sort((a, b) {
        final pa = a.split(':');
        final pb = b.split(':');
        final ca = int.tryParse(pa.first) ?? 0;
        final cb = int.tryParse(pb.first) ?? 0;
        if (ca != cb) return ca.compareTo(cb);
        final va = int.tryParse(pa.length > 1 ? pa[1] : '0') ?? 0;
        final vb = int.tryParse(pb.length > 1 ? pb[1] : '0') ?? 0;
        return va.compareTo(vb);
      });
    return [for (final k in keys) ...?book[k]];
  }

  /// Every verse of a book, keyed `"chapter:verse"`.
  ///
  /// 2026-08-07: added for the Vocabulary tab, which needs the tagged
  /// text broken by VERSE rather than flattened — bwh40's Example Verse
  /// Finder reports which verses you can read, so it cannot use
  /// [forBook]'s single reading-order list.
  ///
  /// Returns the shared cache; treat it as read-only.
  static Future<Map<String, List<OriginalWord>>> versesOfBook(
          String englishBook) =>
      _bookMap(englishBook);

  static Future<Map<String, List<OriginalWord>>> _bookMap(
      String englishBook) async {
    if (!_byBook.containsKey(englishBook)) {
      _byBook[englishBook] =
          await (_loading[englishBook] ??= _load(englishBook));
    }
    return _byBook[englishBook] ?? const {};
  }

  /// Whether bundled original-language data exists for any verse in
  /// [englishBook]. Useful for showing/hiding the "Original" affordance
  /// without per-verse probing.
  static Future<bool> hasBook(String englishBook) async {
    if (!_byBook.containsKey(englishBook)) {
      _byBook[englishBook] =
          await (_loading[englishBook] ??= _load(englishBook));
    }
    return _byBook[englishBook]?.isNotEmpty ?? false;
  }
}
