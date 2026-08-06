import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/services/error_reporter.dart';
import 'package:seeksparks/services/profile_service.dart';
import 'package:seeksparks/utils/verse_list.dart';

/// Persistence for the Verse List Manager (`utils/verse_list.dart`).
///
/// Two things are stored, and they are deliberately different:
///
///   * the **workspace** — the Main and Secondary lists you are working
///     in right now. Restored on open, like the Analysis tab index, so
///     a reload does not throw away a half-built list.
///   * **saved lists** — named lists, the `File ▸ Save as` / `File ▸
///     Open` pair. BibleWorks writes one `.VLS` file per list into a
///     folder; a browser has no folder, so they live in one keyed map.
///
/// Profile-scoped (`ProfileService.scopedKey`) so two profiles on one
/// device do not read each other's lists.
///
/// **Local only — deliberately not synced to Firebase.** Highlights,
/// bookmarks and notes go through `RealtimeDbSyncService`, and verse
/// lists could too. They are left out for now because the sync layer
/// merges per-key and a list is an ORDERED sequence with meaningful
/// duplicates (import appends verbatim); a last-writer-wins merge would
/// silently reorder or dedupe it, which is exactly the behaviour bwh27
/// separates `Sort` out to avoid. Wiring sync needs a merge rule
/// designed for sequences, which is its own piece of work.
class VerseListStore {
  VerseListStore._();

  static const _workspaceKey = 'workbench.verseLists.workspace';
  static const _savedKey = 'workbench.verseLists.saved';

  /// Guard against a corrupt or hostile preference blob turning into
  /// unbounded work at startup.
  static const maxSavedLists = 200;

  // ── Workspace ─────────────────────────────────────────────────────

  /// The Main and Secondary lists, in that order. Returns two empty
  /// lists when nothing has been stored yet or the blob is unreadable.
  static Future<(VerseList, VerseList)> loadWorkspace() async {
    final raw = await _read(_workspaceKey);
    if (raw == null) return (VerseList.empty, VerseList.empty);
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return (VerseList.empty, VerseList.empty);
      }
      return (_listAt(json, 'main'), _listAt(json, 'secondary'));
    } catch (e, s) {
      ErrorReporter.report(e, s, source: 'VerseListStore.loadWorkspace');
      return (VerseList.empty, VerseList.empty);
    }
  }

  static Future<void> saveWorkspace(VerseList main, VerseList secondary) =>
      _write(
        _workspaceKey,
        jsonEncode({'main': main.toJson(), 'secondary': secondary.toJson()}),
        'VerseListStore.saveWorkspace',
      );

  static VerseList _listAt(Map<String, dynamic> json, String key) {
    final v = json[key];
    return v is Map<String, dynamic> ? VerseList.fromJson(v) : VerseList.empty;
  }

  // ── Saved (named) lists ───────────────────────────────────────────

  /// Every saved list, keyed by name, sorted by name so the `Open`
  /// menu is stable between builds.
  static Future<Map<String, VerseList>> loadSaved() async {
    final raw = await _read(_savedKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return {};
      final out = <String, VerseList>{};
      for (final entry in json.entries) {
        final v = entry.value;
        if (v is Map<String, dynamic>) {
          out[entry.key] = VerseList.fromJson(v);
        }
      }
      final names = out.keys.toList()..sort();
      return {for (final n in names) n: out[n]!};
    } catch (e, s) {
      ErrorReporter.report(e, s, source: 'VerseListStore.loadSaved');
      return {};
    }
  }

  /// Save [list] under its own name, replacing any list already stored
  /// under it. Returns the full saved map so the caller can refresh a
  /// menu without a second read.
  static Future<Map<String, VerseList>> saveNamed(VerseList list) async {
    final name = list.name.trim();
    if (name.isEmpty) return loadSaved();
    final all = await loadSaved();
    if (!all.containsKey(name) && all.length >= maxSavedLists) return all;
    all[name] = list.copyWith(name: name);
    await _writeSaved(all);
    return all;
  }

  static Future<Map<String, VerseList>> deleteNamed(String name) async {
    final all = await loadSaved();
    if (all.remove(name) == null) return all;
    await _writeSaved(all);
    return all;
  }

  static Future<void> _writeSaved(Map<String, VerseList> all) => _write(
        _savedKey,
        jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}),
        'VerseListStore.saveNamed',
      );

  // ── Prefs plumbing ────────────────────────────────────────────────

  static Future<String?> _read(String base) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(ProfileService.instance.scopedKey(base));
    } catch (e, s) {
      ErrorReporter.report(e, s, source: 'VerseListStore._read');
      return null;
    }
  }

  static Future<void> _write(String base, String value, String source) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ProfileService.instance.scopedKey(base), value);
    } catch (e, s) {
      ErrorReporter.report(e, s, source: source);
    }
  }
}
