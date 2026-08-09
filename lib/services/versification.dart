import 'dart:convert';

import 'package:flutter/services.dart';

/// Translates a reader's chapter-and-verse into the original text's own.
///
/// `assets/originals/*.json` is numbered in the ORIGINAL's versification —
/// Masoretic for the Hebrew Bible, the critical text for the Greek — while
/// every shipped edition, and so every reference a reader types, follows
/// the English tradition. Where the two disagree, joining them on the
/// reader's key showed **another verse's Hebrew**: English Psalm 3:1 got
/// the psalm's heading instead of its first line, and Joel 2:28 got
/// nothing at all. Measured over the whole corpus, 1,823 references
/// resolved to the wrong verse and 152 to none.
///
/// The table is derived, not asserted: `tools/derive_versification.py`
/// aligns Strong's-number streams between the originals and three
/// independent tagged translations (KJV+S, 和合本雅伟版, BSB) and keeps a
/// row only where all three agree. See `docs/DATA-INTEGRITY.md` check 9.
class Versification {
  Versification._(this._map, this._absent);

  /// book -> reader `"c:v"` -> the original keys that verse's words span.
  /// Only differences are stored; anything absent maps to itself.
  final Map<String, Map<String, List<String>>> _map;

  /// book -> reader keys with no counterpart in the original at all.
  /// These are the sixteen Received-Text verses the critical text omits,
  /// not gaps in our data, and the reader is told which.
  final Map<String, Set<String>> _absent;

  /// Reverse direction, built per book on first use: original key ->
  /// the reader key that owns it. Used to re-key whole-book scans so a
  /// search hit reports the reference the reader can actually navigate to.
  final Map<String, Map<String, String>> _reverse = {};

  static Versification? _instance;
  static Future<Versification>? _loading;

  static Future<Versification> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    return _instance = await (_loading ??= _read());
  }

  static Future<Versification> _read() async {
    try {
      final raw = await rootBundle.loadString('assets/versification.json');
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A missing or malformed table must not take the Word Study pane
      // down with it; identity is what shipped before this existed.
      return Versification._(const {}, const {});
    }
  }

  static Versification fromJson(Map<String, dynamic> json) {
    final map = <String, Map<String, List<String>>>{};
    final rawMap = json['map'] as Map<String, dynamic>? ?? const {};
    for (final book in rawMap.entries) {
      map[book.key] = {
        for (final verse in (book.value as Map<String, dynamic>).entries)
          verse.key: [
            for (final k in verse.value as List) k as String,
          ],
      };
    }
    final absent = <String, Set<String>>{};
    final rawAbsent = json['absent'] as Map<String, dynamic>? ?? const {};
    for (final book in rawAbsent.entries) {
      absent[book.key] = {
        for (final k in book.value as List) k as String,
      };
    }
    return Versification._(map, absent);
  }

  /// The original-text keys whose words the reader's verse contains.
  ///
  /// Usually one. A merge returns several — English Psalm 3:1 carries
  /// both Masoretic 3:1 (the heading) and 3:2 — and an omitted verse
  /// returns none.
  List<String> originalKeys(String book, int chapter, int verse) {
    final key = '$chapter:$verse';
    final mapped = _map[book]?[key];
    if (mapped != null) return mapped;
    return [key];
  }

  /// Whether the reader's verse has no counterpart in the original text.
  /// True only for the verses the critical text omits, so the pane can
  /// say why it is empty instead of looking broken.
  bool isAbsentFromOriginal(String book, int chapter, int verse) =>
      _absent[book]?.contains('$chapter:$verse') ?? false;

  /// Whether this book is numbered identically in both traditions.
  bool matchesReader(String book) => !_map.containsKey(book);

  /// The reader key that owns [originalKey], for reporting a scan of the
  /// original text in references the reader can navigate to.
  String readerKey(String book, String originalKey) =>
      _reverseFor(book)[originalKey] ?? originalKey;

  Map<String, String> _reverseFor(String book) {
    final cached = _reverse[book];
    if (cached != null) return cached;
    final out = <String, String>{};
    final forward = _map[book];
    if (forward != null) {
      for (final entry in forward.entries) {
        for (final original in entry.value) {
          // First writer wins: where two reader verses render the same
          // original verse, the scan is attributed once, to the earlier.
          out.putIfAbsent(original, () => entry.key);
        }
      }
    }
    return _reverse[book] = out;
  }

  /// Re-key a whole book of original-text verses by reader reference.
  ///
  /// A **partition**: every original verse lands under exactly one reader
  /// key, so counts drawn from it cannot double-count. That is the right
  /// semantics for statistics and search; [originalKeys] is the right one
  /// for display, where a verse rendered in two places should appear in
  /// both.
  /// Where several original verses belong to one reference — an English
  /// verse rendering a psalm's heading and its first line both — their
  /// words are CONCATENATED in the original's order. Overwriting instead
  /// would silently drop the heading and leave the totals short.
  Map<String, List<T>> rekeyBook<T>(
      String book, Map<String, List<T>> byOriginalKey) {
    if (matchesReader(book)) return byOriginalKey;
    final reverse = _reverseFor(book);
    final ordered = byOriginalKey.keys.toList()
      ..sort((a, b) {
        final ka = _parse(a);
        final kb = _parse(b);
        return ka.$1 != kb.$1 ? ka.$1.compareTo(kb.$1) : ka.$2.compareTo(kb.$2);
      });
    final forward = _map[book] ?? const {};
    final out = <String, List<T>>{};
    for (final key in ordered) {
      final owner = reverse[key];
      if (owner == null) {
        // No reference claims this original verse. Usually it keeps its
        // own number — but if the reader's verse of that number renders
        // something else, the number means two different things and
        // attributing it would put foreign words under a real reference.
        // The verse is unreachable either way; leave it out rather than
        // recreate the defect this table exists to fix.
        if (forward.containsKey(key)) continue;
        (out[key] ??= <T>[]).addAll(byOriginalKey[key]!);
      } else {
        (out[owner] ??= <T>[]).addAll(byOriginalKey[key]!);
      }
    }
    return out;
  }

  static (int, int) _parse(String key) {
    final colon = key.indexOf(':');
    if (colon < 0) return (0, 0);
    return (
      int.tryParse(key.substring(0, colon)) ?? 0,
      int.tryParse(key.substring(colon + 1)) ?? 0,
    );
  }
}
