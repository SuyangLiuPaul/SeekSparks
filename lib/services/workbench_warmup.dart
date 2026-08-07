/// Warming the workbench's centre pane before it is asked to paint.
///
/// ## The measurement this exists for
///
/// Task #274 reported the workbench panes as "empty on first paint".
/// Measured against the deployed dev build (Chrome, CDP screenshots at
/// ~380 ms intervals, 1440×900):
///
/// * warm HTTP cache — every boot asset, including the 7 MB reading
///   version, finished by ~1.0 s; the splash then held until ~4.15 s;
///   the Browse pane painted a BLANK centre at 4.16 s and filled at
///   ~4.6 s. The chapter reader (`parallelMode == false`) had no blank
///   frame at all.
/// * cold cache, 12 Mbps — the workbench appeared at ~11.4 s, and only
///   THEN did the Browse pane start fetching `bsb.json` + `kjv.json` +
///   `hebrew.json` + the tagged book: ~4.3 MB more, downloaded after
///   the reader was already looking at an empty column.
///
/// So the pane was never "not repainting". It was being asked, at the
/// worst possible moment, to download and parse whole Bibles it could
/// have had already — the app spends ~3 s on a splash timer
/// (`loading_page.dart`, `Timer(Duration(seconds: 3))`) doing nothing
/// while exactly the work the next screen needs sits unstarted.
///
/// This warms it during that window. It is deliberately fire-and-forget
/// and never awaited by boot: if it does not finish, the Browse window
/// loads what it is missing exactly as before, only with a head start.
///
/// ## Why it does not preload speculatively
///
/// `main.dart`'s `_eagerPreloadAllVersions` is disabled on web on
/// purpose (v1.3.61): downloading every bundled version costs real
/// mobile data for versions the reader may never open. This warm-up is
/// not that. It loads ONLY what the pane that is about to be shown will
/// itself demand a second later — so it moves work earlier without
/// adding any. When the centre pane is the chapter reader rather than
/// the Browse stack, there are no comparison versions to fetch and the
/// version step does nothing.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

/// SharedPreferences key for "is the centre pane the Browse stack".
///
/// Shared with `WorkbenchPage` rather than duplicated: the warm-up runs
/// before the page is mounted and has to read the same value the page
/// will restore, and two copies of a key string drift silently.
const String kWorkbenchParallelModeKey = 'workbench.browseMode.v2';

/// SharedPreferences key for the comparison editions in the Browse stack.
const String kWorkbenchParallelVersionsKey = 'workbench.parallelVersions';

/// The stack a first-time reader gets, by UI locale.
///
/// Lives here rather than in `WorkbenchPage` for the same reason as the
/// keys: the warm-up has to predict what the page will choose on a
/// first run, when nothing is persisted yet.
List<String> defaultParallelVersions(String locale) {
  switch (locale) {
    case 'zh-Hans':
      return const ['cuvs-yhwh', 'biblexg-v2', 'bsb'];
    case 'zh-Hant':
      return const ['cuvs-yhwh-tr', 'biblexg-v2-tr', 'bsb'];
    default:
      return const ['bsb', 'nasb', 'kjv'];
  }
}

/// Which whole-version corpora the Browse stack will need and does not
/// already have, in the order it will ask for them.
///
/// Pure, so the decision can be tested without touching an asset. The
/// reading version is deliberately excluded: `MainProvider.setVerses`
/// files it in the same LRU at boot, so asking for it again would parse
/// a 7 MB JSON that is already in memory — which is precisely what the
/// Browse window used to do through its own private cache.
///
/// Returns empty when the centre pane is the chapter reader: that pane
/// renders from `MainProvider.verses` and needs nothing else.
List<String> browseWarmupOrder({
  required bool parallelMode,
  required String readingVersion,
  required List<String> parallelVersions,
  required bool Function(String code) isCached,
}) {
  if (!parallelMode) return const [];
  final reading = readingVersion.toLowerCase();
  final seen = <String>{reading};
  final out = <String>[];
  for (final raw in parallelVersions) {
    final code = raw.toLowerCase();
    if (code.isEmpty) continue;
    if (!seen.add(code)) continue;
    if (isCached(code)) continue;
    out.add(code);
  }
  return out;
}

/// Read the persisted Browse-stack state. Falls back to the same
/// defaults `WorkbenchPage._restorePrefs` applies, so the warm-up and
/// the page agree on a first run.
Future<({bool parallelMode, List<String> versions})> readBrowsePrefs(
  String locale,
) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList(kWorkbenchParallelVersionsKey);
  return (
    parallelMode: prefs.getBool(kWorkbenchParallelModeKey) ?? true,
    versions: (saved != null && saved.isNotEmpty)
        ? saved
        : defaultParallelVersions(locale),
  );
}

/// Load, into the caches the workbench reads from, everything the
/// centre pane will want for the chapter the reader is about to land on.
///
/// Sequential on purpose. These are multi-megabyte assets and the point
/// is to use idle time, not to saturate a phone's connection alongside
/// whatever else boot is still finishing.
///
/// Every step is individually best-effort: a version that fails to load
/// here simply is not warm, and the Browse window's own load path (with
/// its retry and error surface) handles it as it always did.
Future<void> warmWorkbenchFirstPaint({
  required MainProvider mainProvider,
  required String locale,
}) async {
  final prefs = await readBrowsePrefs(locale);
  final order = browseWarmupOrder(
    parallelMode: prefs.parallelMode,
    readingVersion: mainProvider.currentVersion,
    parallelVersions: prefs.versions,
    isCached: mainProvider.hasCachedVersion,
  );
  for (final code in order) {
    await mainProvider.preloadVersion(code);
  }

  // The chapter's own apparatus. Both panes need this — the Browse
  // stack prints an originals line under every verse, and the chapter
  // reader's Analysis pane asks for the same book the moment a verse is
  // selected — so it is warmed regardless of which centre pane is up.
  final localBook = mainProvider.currentBook;
  final chapter = mainProvider.currentChapter;
  if (localBook == null || chapter == null) return;
  final book = bookNameToEnglish[localBook] ?? localBook;

  final words = await OriginalsService.forVerse(book, chapter, 1);

  // One lookup pulls the whole lexicon. Which lexicon is decided by the
  // text in front of the reader rather than by a canon table, because a
  // Greek quotation inside a Hebrew book would otherwise warm the wrong
  // 5 MB file.
  final probe = words != null && words.isNotEmpty ? words.first.strongs : '';
  if (probe.isNotEmpty) await StrongsService.lookup(probe);

  final versions = <String>{
    mainProvider.currentVersion.toLowerCase(),
    if (prefs.parallelMode) ...prefs.versions.map((v) => v.toLowerCase()),
  };
  for (final code in versions) {
    if (!TaggedTextService.supports(code)) continue;
    await TaggedTextService.forVerse(
      version: code,
      englishBook: book,
      chapter: chapter,
      verse: 1,
    );
  }
}
