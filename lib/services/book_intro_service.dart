// _LocalizedText / _LocalizedList are deliberately private — they're
// internal value objects whose only public API is the getX(locale)
// accessors on BookIntro. The lint warnings about private types in
// the BookIntro constructor are spurious for this internal-only use.
// ignore_for_file: library_private_types_in_public_api

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Localized text bundle. Each field can be looked up via the
/// active app locale (`zh-Hans`, `zh-Hant`, `en`).
class _LocalizedText {
  final Map<String, String> _byLang;
  const _LocalizedText(this._byLang);

  String get(String locale) {
    return _byLang[locale] ?? _byLang['en'] ?? _byLang.values.firstOrNull ?? '';
  }
}

class _LocalizedList {
  final Map<String, List<String>> _byLang;
  const _LocalizedList(this._byLang);

  List<String> get(String locale) {
    return _byLang[locale] ??
        _byLang['en'] ??
        (_byLang.values.firstOrNull ?? const <String>[]);
  }
}

/// One book's introduction card data. Authored in Chinese (Hans + Hant)
/// and English. Surfaces in the reading pane above chapter 1.
class BookIntro {
  final String englishBook;
  final _LocalizedText _subtitle;
  final _LocalizedText _summary;
  final _LocalizedText _author;
  final _LocalizedText _date;
  final _LocalizedText _audience;
  final _LocalizedList _themes;
  final String keyPassage;
  final _LocalizedText _keyPassageDescription;

  const BookIntro({
    required this.englishBook,
    required _LocalizedText subtitle,
    required _LocalizedText summary,
    required _LocalizedText author,
    required _LocalizedText date,
    required _LocalizedText audience,
    required _LocalizedList themes,
    required this.keyPassage,
    required _LocalizedText keyPassageDescription,
  })  : _subtitle = subtitle,
        _summary = summary,
        _author = author,
        _date = date,
        _audience = audience,
        _themes = themes,
        _keyPassageDescription = keyPassageDescription;

  String getSubtitle(String locale) => _subtitle.get(locale);
  String getSummary(String locale) => _summary.get(locale);
  String getAuthor(String locale) => _author.get(locale);
  String getDate(String locale) => _date.get(locale);
  String getAudience(String locale) => _audience.get(locale);
  List<String> getThemes(String locale) => _themes.get(locale);
  String getKeyPassageDescription(String locale) =>
      _keyPassageDescription.get(locale);
}

/// The asset's own header. Parsed because `source`, `datingSystem` and the
/// trilingual `note` are the only record of WHOSE ascriptions and WHOSE
/// chronology these 66 cards print, and until now nothing read them — the
/// same defect #318 phase 24 found on `wheel_history.json`, the #292 pass
/// found on `hebrew_kings.json` and v1.6.195 found on `section_titles.json`.
/// This asset is the sharpest of the four: it is the only one that prints a
/// DATE and an AUTHOR, which #292 and #318 both require to name their system.
class BookIntroMeta {
  final String source;
  final bool notFromAnyEdition;
  final String datingSystem;
  final Map<String, String> note;
  const BookIntroMeta({
    required this.source,
    required this.notFromAnyEdition,
    required this.datingSystem,
    required this.note,
  });

  factory BookIntroMeta.fromJson(Map<String, dynamic> j) {
    final n = j['note'];
    return BookIntroMeta(
      source: (j['source'] as String?) ?? '',
      notFromAnyEdition: j['notFromAnyEdition'] == true,
      datingSystem: (j['datingSystem'] as String?) ?? '',
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

/// Lazy loader for `assets/book_introductions.json`. Single
/// in-memory cache. Returns null when the requested book has no
/// authored intro yet (all 66 books are authored; the null is kept for the
/// deuterocanon and for a book name the asset does not carry).
class BookIntroService {
  static Map<String, BookIntro>? _cache;
  static Future<void>? _loadFuture;
  static BookIntroMeta? _meta;

  /// The asset header, or null before [ensureLoaded] completes.
  static BookIntroMeta? get meta => _meta;

  /// The provenance sentence for [locale], or null when there is nothing to
  /// say. A caller renders this ONLY inside the card it is about; it is not
  /// a global disclaimer.
  static String? provenanceNote(String locale) {
    final m = _meta;
    if (m == null) return null;
    final s = m.noteFor(locale);
    return s.isEmpty ? null : s;
  }

  static Future<void> ensureLoaded() {
    if (_cache != null) return Future.value();
    return _loadFuture ??= _doLoad();
  }

  static Future<void> _doLoad() async {
    try {
      final raw =
          await rootBundle.loadString('assets/book_introductions.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final metaJson = decoded['_meta'];
      _meta = metaJson is Map<String, dynamic>
          ? BookIntroMeta.fromJson(metaJson)
          : null;
      final intros = decoded['intros'] as Map<String, dynamic>?;
      final out = <String, BookIntro>{};
      if (intros != null) {
        intros.forEach((book, data) {
          if (data is! Map<String, dynamic>) return;
          out[book] = BookIntro(
            englishBook: book,
            subtitle: _LocalizedText(_textMap(data['subtitle'])),
            summary: _LocalizedText(_textMap(data['summary'])),
            author: _LocalizedText(_textMap(data['author'])),
            date: _LocalizedText(_textMap(data['date'])),
            audience: _LocalizedText(_textMap(data['audience'])),
            themes: _LocalizedList(_listMap(data['themes'])),
            keyPassage: (data['keyPassage'] as String?) ?? '',
            keyPassageDescription:
                _LocalizedText(_textMap(data['keyPassageDescription'])),
          );
        });
      }
      _cache = out;
    } catch (e, st) {
      debugPrint('BookIntroService load failed: $e\n$st');
      _cache = const {};
    } finally {
      _loadFuture = null;
    }
  }

  static Map<String, String> _textMap(Object? raw) {
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          if (entry.value is String)
            entry.key.toString(): entry.value as String,
      };
    }
    return const {};
  }

  static Map<String, List<String>> _listMap(Object? raw) {
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          if (entry.value is List)
            entry.key.toString():
                (entry.value as List).whereType<String>().toList(),
      };
    }
    return const {};
  }

  /// Lookup an intro by canonical English book name. Returns null
  /// when this book hasn't been authored yet.
  static BookIntro? forBook(String englishBook) {
    final cache = _cache;
    if (cache == null) return null;
    return cache[englishBook];
  }

  @visibleForTesting
  static void clearCache() {
    _cache = null;
    _loadFuture = null;
    _meta = null;
  }
}
