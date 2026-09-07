/// Cross-version search — BibleWorks help topic bwh16, "Cross Version
/// Searches", the last ABSENT entry in `docs/PARITY-BACKLOG.md` §3.1.
///
/// ## The entry in the backlog described a feature BibleWorks does not have
///
/// It read: *"Find verses where the KJV says X and the LXX says Y … one
/// operator that takes a version tag per term."* That is a conjunction
/// across two editions, and bwh16 does not offer one. What BibleWorks
/// ships is a **mode**, set from `Search | Cross Versions Search Mode`,
/// which runs the one query the reader typed against **several editions
/// of the same language** and reports the hits per version:
///
///   * *Search Only Current Search Version* — the default.
///   * *Search All Display Versions* — every display version sharing the
///     search version's language.
///   * *Search and Display All Same Language Versions* — every installed
///     version of that language. bwh16 gives the use case in its own
///     words: looking for a phrase "that occurs in some version but you
///     don't remember which one".
///   * *Search and Prune All Same Language Versions* — the same, but
///     versions with no hits are dropped from the display list.
///
/// §3 of the backlog warns that "guessing a feature from its name is how
/// you build the wrong one", and names `NEAR5` as the standing example.
/// This is the second: building the entry as written would have shipped
/// a cross-language conjunction under the name of a same-language
/// broadcast, and left the actual feature still missing.
///
/// The conjunction is worth having — this repo needed it three times in
/// one day adjudicating the CSB's divine name — but it is a different
/// feature, it is nearer the Graphical Search Engine (§3.2) than to
/// this, and it is now recorded as its own entry rather than smuggled in
/// under this one.
///
/// ## Two places this deliberately differs from BibleWorks
///
/// **"Same language" means the same script here.** BibleWorks' language
/// is a property of a version; ours is the tab the version picker groups
/// it under, and for Chinese that tab is the *script*: 简体 and 繁體 are
/// one language and two corpora. A reader searching 雅伟 gets nothing
/// from a 繁體 edition that spells it 雅偉, so broadcasting across the
/// script boundary would produce a row of confident zeros. Grouping by
/// [BibleVersionInfo.language] — which is what the picker already does —
/// keeps the answer honest, and `searchAcrossScripts` is the one knob
/// that opens it for a caller who knows better.
///
/// **Prune is not implemented, and that is a decision.** Its value is
/// "show me only the versions that hit"; [CrossVersionHits] carries the
/// count for every version searched, including the zeros, so a reader
/// gets that answer by reading a row instead of by having their Browse
/// stack rearranged underneath them. The stack is an ordered list the
/// reader arranges by hand (task #288 made the order first-class), and a
/// search is a question, not an instruction to redecorate. Recorded in
/// the backlog as REJECTED with this reason rather than left unbuilt and
/// unexplained.
///
/// Flutter-free on purpose: this decides WHICH editions a search covers.
/// Running it is `WorkbenchProvider`'s job.
library;

import 'package:seeksparks/constants/bible_versions.dart';

/// How wide the command line casts, from bwh16's menu of the same name.
enum CrossVersionSearchMode {
  /// BibleWorks' *Search Only Current Search Version*, and the default
  /// there and here: one query, one edition, which is what every search
  /// this app has ever run did.
  currentOnly,

  /// BibleWorks' *Search All Display Versions*: the editions already in
  /// the Browse stack that share the reading version's language.
  ///
  /// The narrower of the two broadcasts, and the more useful one day to
  /// day — the stack is the comparison the reader has already chosen, so
  /// this answers "does the column next to me say it too" without
  /// loading anything new.
  displayStack,

  /// BibleWorks' *Search and Display All Same Language Versions*: every
  /// edition of that language the app offers, whether or not it is on
  /// screen.
  sameLanguage,
}

/// The editions one search covers, in the order they should be reported.
///
/// The reading version is always first and always present, even when it
/// has no hits — bwh16 is explicit that the search version is never
/// dropped, and a report that can omit the edition the reader is looking
/// at would be answering a different question from the one they asked.
///
/// [stack] is the comparison list (the reading version NOT included,
/// matching `WorkbenchProvider.parallelVersions`). Codes are cleaned by
/// [loadableVersions], so a retired code in SharedPreferences resolves
/// to its successor instead of asking for an asset that does not exist.
///
/// Set [searchAcrossScripts] to broadcast across 简体/繁體 as well. Off by
/// default; see the library comment for why.
List<String> crossVersionTargets({
  required CrossVersionSearchMode mode,
  required String reading,
  List<String> stack = const [],
  bool searchAcrossScripts = false,
}) {
  final read = loadableVersions([reading]);
  if (read.isEmpty) return const [];
  final code = read.first;
  if (mode == CrossVersionSearchMode.currentOnly) return [code];

  final lang = bibleVersionLanguage(code);
  bool sameFamily(String other) {
    final otherLang = bibleVersionLanguage(other);
    if (otherLang == lang) return true;
    if (!searchAcrossScripts) return false;
    return otherLang.startsWith('zh') && lang.startsWith('zh');
  }

  final Iterable<String> candidates;
  switch (mode) {
    case CrossVersionSearchMode.displayStack:
      candidates = loadableVersions(stack);
    case CrossVersionSearchMode.sameLanguage:
      // `availableVersions`, not `bibleVersions`: a hidden edition is one
      // nothing offers (`disabledVersions`), and broadcasting into it
      // would put the NASB back on screen through a side door the owner
      // closed on purpose.
      candidates = availableVersions.map((v) => v.value);
    case CrossVersionSearchMode.currentOnly:
      candidates = const [];
  }

  final out = <String>[code];
  final seen = <String>{code};
  for (final c in candidates) {
    if (!seen.add(c)) continue;
    if (!sameFamily(c)) {
      seen.remove(c);
      continue;
    }
    out.add(c);
  }
  return out;
}

/// What one edition contributed to a cross-version search.
class VersionHits {
  const VersionHits({
    required this.version,
    required this.count,
    this.searched = true,
  });

  final String version;

  /// Verses matched in this edition.
  final int count;

  /// False when the edition could not be loaded at all.
  ///
  /// Distinct from `count == 0`, and the distinction is the point: "this
  /// edition does not say it" and "we could not read this edition" are
  /// different facts, and reporting the second as the first is how a
  /// search tells a confident lie.
  final bool searched;

  bool get isEmpty => searched && count == 0;
}

/// The per-version report bwh16 shows in a popup menu.
class CrossVersionHits {
  const CrossVersionHits({
    required this.mode,
    required this.reading,
    required this.perVersion,
  });

  final CrossVersionSearchMode mode;

  /// The search version — [perVersion]'s first entry, always.
  final String reading;

  /// One row per edition searched, reading version first.
  final List<VersionHits> perVersion;

  /// Editions that matched at least one verse.
  Iterable<VersionHits> get hitting => perVersion.where((v) => v.count > 0);

  /// Editions that loaded and matched nothing — what BibleWorks' prune
  /// mode would have removed from the display list.
  Iterable<VersionHits> get empty => perVersion.where((v) => v.isEmpty);

  /// Editions that could not be read.
  Iterable<VersionHits> get unread => perVersion.where((v) => !v.searched);

  /// True when there is anything to report beyond the reading version —
  /// the gate the UI uses, so a `currentOnly` search draws no strip.
  bool get isBroadcast => perVersion.length > 1;

  /// Total verses matched across every edition. Not a verse count: the
  /// same verse matching in four editions counts four times, which is
  /// what a per-version report means and why this is not offered as
  /// "results".
  int get totalHits =>
      perVersion.fold(0, (sum, v) => sum + v.count);
}

/// A stored preference back into a mode, defensively.
///
/// Persisted by `name` rather than by `index` so that inserting a mode
/// cannot silently turn a saved `sameLanguage` into something else, and
/// an unrecognised or absent value lands on [CrossVersionSearchMode.currentOnly]
/// — the default here and in BibleWorks, and the behaviour of every
/// search this app ran before the setting existed.
CrossVersionSearchMode crossVersionModeFromName(String? name) {
  for (final m in CrossVersionSearchMode.values) {
    if (m.name == name) return m;
  }
  return CrossVersionSearchMode.currentOnly;
}
