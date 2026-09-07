/// Importing and forgetting a reader's own Bible — bwh47.
///
/// Ties the three halves together: the validator
/// (`imported_version.dart`), the store (`local_version_store.dart`) and
/// the runtime catalog registry (`importedVersionLabels`).
///
/// Nothing here uploads, shares or syncs, and nothing here can be made
/// to — the store has no network and this has no client. That is the
/// row's own condition and the reason the feature is defensible at all.
library;

import 'package:seeksparks/constants/bible_versions.dart'
    show importedVersionLabels;
import 'package:seeksparks/services/local_version_store.dart';
import 'package:seeksparks/utils/imported_version.dart';

/// What happened, in the terms the reader needs.
enum ImportOutcome {
  imported,

  /// The file was fine and the browser refused to keep it — quota, or
  /// private browsing. Distinct from every parse failure, because the
  /// reader's next move is different: nothing is wrong with their file.
  couldNotStore,

  /// This build has no local store at all (native).
  unsupported,

  /// The file was refused; see [VersionImportResult.problem].
  rejected,
}

class VersionImportResult {
  const VersionImportResult(this.outcome, {this.problem, this.detail,
      this.code, this.verseCount});

  final ImportOutcome outcome;
  final ImportProblem? problem;
  final String? detail;
  final String? code;
  final int? verseCount;

  bool get ok => outcome == ImportOutcome.imported;
}

class VersionImportService {
  VersionImportService._();

  /// Put every already-imported edition back in the catalog.
  ///
  /// Called once at boot. Failure is silent BY DESIGN: a reader whose
  /// browser will not open IndexedDB should get the app, not an error
  /// about a feature they may never have used.
  static Future<void> restore() async {
    if (!LocalVersionStore.isAvailable) return;
    final labels = await LocalVersionStore.labels();
    importedVersionLabels
      ..clear()
      ..addAll(labels);
  }

  /// Validate [raw], store it, and register it.
  ///
  /// The order matters: validate first so a bad file never reaches the
  /// store, store second so a registered edition always has text behind
  /// it, and register last so the picker never offers a version that
  /// would fail to load.
  static Future<VersionImportResult> import(String raw, String label) async {
    final parsed = parseImportedVersion(raw, label,
        existingCodes: importedVersionLabels.keys.toSet());
    if (!parsed.ok) {
      return VersionImportResult(ImportOutcome.rejected,
          problem: parsed.problem, detail: parsed.detail);
    }
    if (!LocalVersionStore.isAvailable) {
      return const VersionImportResult(ImportOutcome.unsupported);
    }
    final v = parsed.version!;
    // Stored as the app's own verse shape, not as the reader's file:
    // `FetchVerses` reads this back through the same parser it uses for
    // a bundled asset, so an import cannot take a code path of its own
    // and drift from how every other edition is loaded.
    final payload = _encode(v);
    final wrote = await LocalVersionStore.write(v.code, v.label, payload);
    if (!wrote) {
      return const VersionImportResult(ImportOutcome.couldNotStore);
    }
    importedVersionLabels[v.code] = v.label;
    return VersionImportResult(ImportOutcome.imported,
        code: v.code, verseCount: v.verseCount);
  }

  /// Remove one, from the store and the catalog.
  ///
  /// Store first: an edition still on disk but out of the picker is
  /// invisible clutter, where one in the picker with no text behind it
  /// is a version that fails to open.
  static Future<void> forget(String code) async {
    await LocalVersionStore.delete(code);
    importedVersionLabels.remove(code);
  }

  static String _encode(ImportedVersion v) {
    final buf = StringBuffer('[');
    for (var i = 0; i < v.verses.length; i++) {
      final e = v.verses[i];
      if (i > 0) buf.write(',');
      buf.write(_obj(e));
    }
    buf.write(']');
    return buf.toString();
  }

  /// Hand-built rather than `jsonEncode` over a list of maps: a whole
  /// Bible is ~31,000 records and building that many intermediate maps
  /// to throw them away doubles the peak memory of an import on a
  /// device that may not have it.
  static String _obj(ImportedVerse v) {
    String esc(String s) => s
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '{"book":"${esc(v.book)}","chapter":"${v.chapter}",'
        '"verse":"${v.verse}","text":"${esc(v.text)}"}';
  }
}
