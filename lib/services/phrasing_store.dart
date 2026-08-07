import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/services/error_reporter.dart';
import 'package:seeksparks/services/profile_service.dart';
import 'package:seeksparks/utils/phrasing.dart';

/// Persistence for Phrasing (`utils/phrasing.dart`).
///
/// One chapter of one edition is one piece of work, so that — not the
/// verse window — is the key. A reader who narrows from 3–14 to 3–6 has
/// not started a second analysis, and finding their indentation gone
/// because they moved a stepper would be indefensible.
///
/// Saved silently on every edit rather than behind a Save button.
/// bwh25 makes you name a `.dgm` file; a browser tab can be closed by
/// the OS, and losing an hour of phrasing to a reload is the single
/// worst thing this pane could do.
///
/// Profile-scoped, and local only — same reasoning as `VerseListStore`:
/// the sync layer merges last-writer-wins per key, and a phrasing is a
/// structure whose parts are meaningless individually.
class PhrasingStore {
  PhrasingStore._();

  static const _key = 'workbench.phrasing.saved';

  /// A reader who phrases every chapter of Romans has 16 entries; the
  /// cap exists so a corrupt or hostile blob cannot turn startup into
  /// unbounded work, not because anyone will reach it.
  static const maxSaved = 300;

  static String passageKey(String version, String book, int chapter) =>
      '$version|$book|$chapter';

  static Future<Map<String, Phrasing>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ProfileService.instance.scopedKey(_key));
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      final out = <String, Phrasing>{};
      for (final e in json.entries) {
        if (out.length >= maxSaved) break;
        final v = e.value;
        if (v is! Map<String, dynamic>) continue;
        final p = Phrasing.fromJson(v);
        if (p != null) out['${e.key}'] = p;
      }
      return out;
    } catch (e, s) {
      ErrorReporter.report(e, s, source: 'PhrasingStore.loadAll');
      return {};
    }
  }

  static Future<Phrasing?> load(
    String version,
    String book,
    int chapter,
  ) async =>
      (await loadAll())[passageKey(version, book, chapter)];

  /// Stores [p], or — when the reader has undone everything back to the
  /// bare proposal — removes the entry instead of writing an empty one.
  /// An untouched phrasing is indistinguishable from never having
  /// opened the chapter, and keeping it would let the cap fill with
  /// nothing.
  static Future<void> save(Phrasing p) async {
    final all = await loadAll();
    final key = passageKey(p.version, p.book, p.chapter);
    if (p.isTouched) {
      if (all.length >= maxSaved && !all.containsKey(key)) return;
      all[key] = p;
    } else {
      all.remove(key);
    }
    await _write(all);
  }

  static Future<void> delete(String version, String book, int chapter) async {
    final all = await loadAll();
    if (all.remove(passageKey(version, book, chapter)) == null) return;
    await _write(all);
  }

  static Future<void> _write(Map<String, Phrasing> all) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ProfileService.instance.scopedKey(_key),
        jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}),
      );
    } catch (e, s) {
      ErrorReporter.report(e, s, source: 'PhrasingStore._write');
    }
  }
}
