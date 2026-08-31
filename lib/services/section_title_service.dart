import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/section_title_map.dart';
import 'package:seeksparks/utils/pericope.dart' show BookHeading;

/// One row from `assets/section_titles.json` — title + optional
/// `context` (a short paragraph of historical / theological
/// background rendered under the heading in the reading pane).
class SectionHeading {
  final String title;
  final String? context;
  const SectionHeading({required this.title, this.context});
}

/// The asset's own header. Parsed because `notPublishedHeadings` and the
/// trilingual `note` are the only record of WHOSE headings these are, and
/// until v1.6.195 nothing read them — the same defect #318 phase 24 found on
/// `wheel_history.json` and the #292 pass found on `hebrew_kings.json`.
class SectionTitleMeta {
  final String source;
  final bool notPublishedHeadings;
  final Map<String, String> note;
  const SectionTitleMeta({
    required this.source,
    required this.notPublishedHeadings,
    required this.note,
  });

  factory SectionTitleMeta.fromJson(Map<String, dynamic> j) {
    final n = j['note'];
    return SectionTitleMeta(
      source: (j['source'] as String?) ?? '',
      notPublishedHeadings: j['notPublishedHeadings'] == true,
      note: n is Map
          ? {
              for (final e in n.entries)
                if (e.value is String) e.key.toString(): e.value as String
            }
          : const {},
    );
  }

  /// The note in [locale], falling back to English. Empty string when the
  /// asset carries nothing — callers render nothing rather than a blank line.
  String noteFor(String locale) => note[locale] ?? note['en'] ?? '';
}

/// Section / paragraph titles bundled at `assets/section_titles.json`.
/// One asset, multiple title-sets (cuv / cuv-tr / english-classic /
/// future cnv), wired via `lib/constants/section_title_map.dart`.
///
/// Lazy-loaded once on first lookup. Single in-memory cache shared
/// across reading-pane calls; deep enough that even tight loops over
/// every verse are O(1) lookups.
class SectionTitleService {
  /// Two-level index: setId → "Book/chapter/verse" → SectionHeading.
  static Map<String, Map<String, SectionHeading>>? _cache;
  static Future<void>? _loadFuture;
  static SectionTitleMeta? _meta;

  /// The asset header, or null before [ensureLoaded] completes.
  static SectionTitleMeta? get meta => _meta;

  /// The provenance sentence for [locale], or null when there is nothing to
  /// say. A caller renders this ONLY where it is adjacent to the headings it
  /// is about; it is not a global disclaimer.
  static String? provenanceNote(String locale) {
    final m = _meta;
    if (m == null) return null;
    final s = m.noteFor(locale);
    return s.isEmpty ? null : s;
  }

  /// Trigger the asset load. Idempotent. The reading pane calls this
  /// from `initState` so the first chapter render already has data.
  static Future<void> ensureLoaded() {
    if (_cache != null) return Future.value();
    return _loadFuture ??= _doLoad();
  }

  static Future<void> _doLoad() async {
    try {
      final raw = await rootBundle.loadString('assets/section_titles.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final metaJson = decoded['_meta'];
      _meta = metaJson is Map<String, dynamic>
          ? SectionTitleMeta.fromJson(metaJson)
          : null;
      final sets = decoded['sets'] as Map<String, dynamic>?;
      final out = <String, Map<String, SectionHeading>>{};
      if (sets != null) {
        sets.forEach((setId, books) {
          final flat = <String, SectionHeading>{};
          if (books is Map<String, dynamic>) {
            books.forEach((book, chapters) {
              if (chapters is Map<String, dynamic>) {
                chapters.forEach((chapter, entries) {
                  if (entries is List) {
                    for (final e in entries) {
                      if (e is Map &&
                          e['verse'] is num &&
                          e['title'] is String) {
                        final ctx = e['context'];
                        flat['$book/$chapter/${(e['verse'] as num).toInt()}'] =
                            SectionHeading(
                          title: e['title'] as String,
                          context: ctx is String && ctx.isNotEmpty
                              ? ctx
                              : null,
                        );
                      }
                    }
                  }
                });
              }
            });
          }
          out[setId] = flat;
        });
      }
      _cache = out;
    } catch (e, st) {
      debugPrint('SectionTitleService load failed: $e\n$st');
      _cache = const {}; // soft-fail; lookups return null below
    } finally {
      _loadFuture = null;
    }
  }

  /// Returns the section heading for the verse at
  /// (`englishBook`, `chapter`, `verse`) under [version], or null if
  /// no heading is configured for that exact verse.
  ///
  /// Looks up the version's primary title set; on miss, consults the
  /// fallback set (CNV → CUV).
  static SectionHeading? headingAt({
    required String version,
    required String englishBook,
    required int chapter,
    required int verse,
  }) {
    final cache = _cache;
    if (cache == null) return null;
    final primarySet = sectionTitleSetFor(version);
    if (primarySet.isEmpty) return null;
    final key = '$englishBook/$chapter/$verse';
    final hit = cache[primarySet]?[key];
    if (hit != null) return hit;
    final fallbackSet = sectionTitleFallbackFor(primarySet);
    if (fallbackSet == null) return null;
    return cache[fallbackSet]?[key];
  }

  /// Convenience for callers that only want the title text.
  static String? titleAt({
    required String version,
    required String englishBook,
    required int chapter,
    required int verse,
  }) =>
      headingAt(
        version: version,
        englishBook: englishBook,
        chapter: chapter,
        verse: verse,
      )?.title;

  /// Every outline heading in one book, sorted, for the Context tab's
  /// pericope scope (BibleWorks `bwh10h`).
  ///
  /// Returns empty before [ensureLoaded] completes or when the set has
  /// no entries for the book.
  static List<BookHeading> headingsInBook({
    required String setId,
    required String englishBook,
  }) {
    final flat = _cache?[setId];
    if (flat == null) return const [];
    final prefix = '$englishBook/';
    final out = <BookHeading>[];
    for (final entry in flat.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final parts = entry.key.split('/');
      if (parts.length != 3) continue;
      final chapter = int.tryParse(parts[1]);
      final verse = int.tryParse(parts[2]);
      if (chapter == null || verse == null) continue;
      out.add(BookHeading(
        chapter: chapter,
        verse: verse,
        title: entry.value.title,
      ));
    }
    out.sort(BookHeading.compare);
    return out;
  }

  /// Which title set to read pericope headings from.
  ///
  /// The reading pane maps only the versions it prints headings above
  /// (`sectionTitleSetFor`), so a tagged version like `cuvs-plus` or
  /// `bsb` resolves to nothing. The Context tab still needs an outline
  /// for those, and can safely borrow one: all three sets sit on
  /// **identical verse boundaries** (verified — 1443 headings each, same
  /// keys), so the choice changes the title TEXT and never the range.
  /// Falling back on the reader's own locale therefore costs nothing and
  /// gives them a heading they can read.
  static String contextSetFor({
    required String version,
    required String locale,
  }) {
    final primary = sectionTitleSetFor(version);
    if (primary.isNotEmpty) return primary;
    if (locale == 'zh-Hant') return 'cuv-tr';
    if (locale.startsWith('zh')) return 'cuv';
    return 'english-classic';
  }

  /// Test-only — clears the cache so a hot-restart picks up edits to
  /// the asset.
  @visibleForTesting
  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
