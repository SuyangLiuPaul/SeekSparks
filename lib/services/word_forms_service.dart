/// 2026-08-07 (SeekSparks): loads the Forms index — BibleWorks bwh10q.
///
/// Three assets, three loading rules, because they are asked for at very
/// different rates:
///
///   `index.json`     tiny; the book table and nothing else. Once.
///   `ambiguous.json` 319 KB; consulted for EVERY word the pointer
///                    crosses, so it is held after the first hit rather
///                    than re-fetched.
///   `l/<shard>.json` ~50 KB each, 151 of them, 7.5 MB in total. Fetched
///                    per Strong's hundred and cached. Running text
///                    stays inside a handful of shards, so the second
///                    word onward is usually free.
///
/// Nothing here is loaded at startup. The Analysis pane follows the
/// mouse, so a synchronous 7.5 MB would be paid by every reader who
/// never opens the section.
///
/// The whole index is derived from the original-language texts already
/// bundled with the app (MorphGNT, CC BY-SA; OSHB, CC BY 4.0). No
/// third-party morphology database is reproduced.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/utils/word_forms.dart';

class WordFormsService {
  static const _dir = 'assets/forms';

  static List<String>? _books;
  static Future<void>? _indexLoading;

  static Map<String, List<FormParse>>? _ambiguous;
  static Future<void>? _ambiguousLoading;

  static final Map<String, Map<String, List<WordForm>>> _shards = {};
  static final Map<String, Future<void>> _shardLoading = {};

  /// Book slugs in the order the asset's refs index into them.
  static List<String> get books => _books ?? const [];

  static Future<void> _ensureIndex() {
    if (_books != null) return Future.value();
    return _indexLoading ??= () async {
      try {
        final raw = await rootBundle.loadString('$_dir/index.json');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _books = [
          for (final b in (json['books'] as List? ?? const []))
            if (b is String) b,
        ];
      } catch (_) {
        // A missing or malformed index must not take the Analysis pane
        // down with it — the section simply does not render.
        _books = const [];
      }
    }();
  }

  static Future<void> _ensureAmbiguous() {
    if (_ambiguous != null) return Future.value();
    return _ambiguousLoading ??= () async {
      final out = <String, List<FormParse>>{};
      try {
        final raw = await rootBundle.loadString('$_dir/ambiguous.json');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in json.entries) {
          final rows = <FormParse>[];
          for (final r in (e.value as List? ?? const [])) {
            final p = FormParse.fromJson(r);
            if (p != null) rows.add(p);
          }
          if (rows.isNotEmpty) out[e.key] = rows;
        }
      } catch (_) {
        // Falling back to an empty map means every form reads as
        // unambiguous. That is the safe direction: it under-claims
        // rather than inventing an ambiguity that is not there.
      }
      _ambiguous = out;
    }();
  }

  static Future<void> _ensureShard(String shard) {
    if (_shards.containsKey(shard)) return Future.value();
    return _shardLoading[shard] ??= () async {
      final out = <String, List<WordForm>>{};
      try {
        final raw = await rootBundle.loadString('$_dir/l/$shard.json');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in json.entries) {
          final rows = <WordForm>[];
          for (final r in (e.value as List? ?? const [])) {
            final f = WordForm.fromJson(r);
            if (f != null) rows.add(f);
          }
          if (rows.isNotEmpty) out[e.key] = rows;
        }
      } catch (_) {
        // Absent shard = no data for this hundred. Cached as empty so a
        // reader hovering along a line does not re-request it per word.
      }
      _shards[shard] = out;
    }();
  }

  /// Every inflected form the corpus parses as [strongs], frequency
  /// first. Empty when the number is unknown — bwh10q's top section.
  static Future<List<WordForm>> formsFor(String strongs) async {
    if (strongs.isEmpty) return const [];
    final shard = formsShardFor(strongs);
    if (shard == null) return const [];
    await _ensureShard(shard);
    return _shards[shard]?[strongs] ?? const [];
  }

  /// Every way the corpus parses the surface form [form] — bwh10q's
  /// bottom section, and the answer to "how certain is the parse I am
  /// being shown".
  ///
  /// A form the asset does not list has exactly one parse, so the miss
  /// resolves to [FormAmbiguity.unambiguous] rather than to null.
  static Future<FormAmbiguity> ambiguityFor(String form) async {
    if (form.isEmpty) return const FormAmbiguity.unambiguous('');
    await _ensureAmbiguous();
    final rows = _ambiguous?[form];
    if (rows == null || rows.isEmpty) return FormAmbiguity.unambiguous(form);
    return FormAmbiguity(form, rows);
  }

  /// Resolves the capped example refs on a [WordForm] to navigable
  /// references. Loads the book table on first use.
  static Future<List<FormRef>> refsOf(WordForm form) async {
    if (form.refs.isEmpty) return const [];
    await _ensureIndex();
    final books = _books ?? const <String>[];
    if (books.isEmpty) return const [];
    return [
      for (final raw in form.refs)
        if (parseFormRef(raw, books) case final r?) r,
    ];
  }
}
