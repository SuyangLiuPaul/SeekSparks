import 'package:flutter/foundation.dart';

import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/search_service.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/command_verb.dart' show LimitSpec;
import 'package:seeksparks/utils/strongs_boolean_search.dart';
import 'package:seeksparks/utils/verse_list.dart' show applySearchLimit;
import 'package:seeksparks/utils/version_mapper.dart' show toEnglish;

/// State glue for the three-pane Workbench (`workbench_page.dart`) —
/// SeekSparks' BibleWorks-style pad workspace: command line + results
/// (left), Bible reader (center), live original-language analysis
/// (right).
///
/// The center reader needs ZERO changes to participate: the analysis
/// pane is driven entirely by [MainProvider.selectedVerses] — a verse
/// tap in the reader selects the verse, and the listener here mirrors
/// that selection into [analysisVerses], which the embedded
/// `OriginalsSheet` renders.
///
/// Owned by `_WorkbenchPageState` (created in `initState`, disposed
/// with the page) — deliberately NOT registered globally in main.dart,
/// so no listener or state lives on when the workbench isn't open.
class WorkbenchProvider extends ChangeNotifier {
  WorkbenchProvider({required this.mainProvider}) {
    mainProvider.addListener(_onMainChanged);
    // Pick up any selection that predates the workbench (e.g. the user
    // selected verses in the plain reader, then switched over).
    _syncSelection();
  }

  final MainProvider mainProvider;

  // ── Command pane (left) ───────────────────────────────────────────

  String lastQuery = '';
  bool searching = false;
  bool searchPerformed = false;

  /// Text-scan results (last query was NOT Strong's-shaped).
  List<Verse> textResults = const [];

  /// Strong's results: the display label (verbatim query, uppercased)
  /// plus refs. Null when the last search was a text scan.
  String? strongsQueryLabel;
  List<ConcordanceRef>? strongsRefs;

  /// The last query, parsed, when it was written in the command-line
  /// grammar (`.love god`, `'in the beginning`, …). The pane echoes it
  /// back in words: a grammar whose operators are punctuation is only
  /// safe if the reader can see what the punctuation was taken to mean.
  CommandQuery? commandQuery;

  /// Why a command-shaped query was refused. Set exactly when the query
  /// began with a control character and did not parse — never for
  /// ordinary text, which is not a failed command but a plain search.
  CommandIssue? commandIssue;

  /// Search limit — restrict results to these
  /// `'EnglishBook-chapter-verse'` keys. Null means unrestricted.
  ///
  /// BibleWorks sets this from a saved verse list (`l test.vls`, bwh29
  /// / bwh44); here it comes from the Verse List Manager tab. Kept as a
  /// key set rather than a `VerseList` so the search path does not have
  /// to know what produced it.
  Set<String>? searchLimit;

  /// What to call the active limit in the UI (the list's name). Null
  /// exactly when [searchLimit] is null.
  String? searchLimitLabel;

  bool get hasSearchLimit => searchLimit != null;

  /// Point subsequent searches at [keys], labelled [label], and re-run
  /// the last query so the results on screen match the limit that is
  /// now displayed. Passing null clears the limit.
  Future<void> setSearchLimit(Set<String>? keys, String? label) async {
    searchLimit = keys;
    searchLimitLabel = keys == null ? null : (label ?? '');
    _notify();
    if (lastQuery.isNotEmpty) await runSearch(lastQuery);
  }

  /// Install the `l gen` / `l nt` style limit described by [spec].
  ///
  /// Returns false, changing nothing, when the spec selects no verses in
  /// the loaded edition — `l revelation 30`, or a book the current
  /// edition does not carry. Emptiness is only knowable here, not at
  /// parse time, and installing an empty limit would silently make every
  /// subsequent search return nothing.
  ///
  /// The keys are a SNAPSHOT of the loaded corpus, matching how the
  /// Verse List Manager's limit already works. Versification differs
  /// between editions, so a limit taken in one edition is not re-derived
  /// when the reader switches to another; at book and chapter
  /// granularity that is almost always harmless, and the alternative —
  /// a live predicate — would change the shape every limit in the app
  /// already has.
  Future<bool> setSearchLimitFromSpec(LimitSpec spec, String label) async {
    final keys = <String>{};
    for (final v in mainProvider.verses) {
      final book = toEnglish(v.book) ?? v.book;
      if (spec.covers(book, v.chapter)) keys.add('$book-${v.chapter}-${v.verse}');
    }
    if (keys.isEmpty) return false;
    await setSearchLimit(keys, label);
    return true;
  }

  // ── Browse stack (centre pane) ────────────────────────────────────

  /// Whether the centre pane is the Browse stack (several editions of
  /// the same verse) rather than the chapter reader.
  bool parallelMode = true;

  /// The comparison editions in the Browse stack, in display order.
  ///
  /// Lives here rather than in `_WorkbenchPageState` because the command
  /// line addresses it (`d nas`, `p a b c`, bwh44) and the command line
  /// is a sibling widget, not a child. The page still owns persistence
  /// and calls back through [onBrowseStateChanged].
  List<String> parallelVersions = const [];

  /// Called after the command line changes [parallelMode] or
  /// [parallelVersions], so the page can persist them.
  VoidCallback? onBrowseStateChanged;

  /// What the Browse pane actually renders: the edition being read
  /// FIRST, then the comparisons.
  ///
  /// BibleWorks defines `d c` as clearing "all versions except the
  /// search version", which makes the search version's presence an
  /// invariant of the display rather than a default. Deriving the stack
  /// here means the command line validates against what is on screen —
  /// otherwise `d -kjv` while reading the KJV would remove it from
  /// storage, this getter would put it straight back, and the reader
  /// would be told nothing.
  List<String> get displayVersions => [
        mainProvider.currentVersion,
        ...parallelVersions.where((c) => c != mainProvider.currentVersion),
      ];

  void setParallelMode(bool on) {
    if (parallelMode == on) return;
    parallelMode = on;
    _notify();
    onBrowseStateChanged?.call();
  }

  void setParallelVersions(List<String> codes) {
    parallelVersions = List.unmodifiable(codes);
    _notify();
    onBrowseStateChanged?.call();
  }

  /// One line of feedback from a command verb — an echo of the new
  /// Browse stack, or the reason a verb was refused.
  ///
  /// Cleared by the next search, because a notice that outlives the
  /// thing it describes is worse than no notice.
  String? verbNotice;

  void showVerbNotice(String? text) {
    verbNotice = text;
    _notify();
  }

  // ── Analysis pane (right) ─────────────────────────────────────────

  /// Verses currently shown in the analysis pane (mirrors the reader's
  /// verse selection, in corpus order).
  List<Verse> analysisVerses = const [];

  bool _disposed = false;

  /// A bare Strong's number (`G25`, `H157`). parseStrongsBoolean
  /// deliberately returns null for these (single plain number = lexicon
  /// path), so the command line handles them itself.
  static final RegExp _singleStrongsRe = RegExp(r'^[GgHh]\d{1,4}$');

  /// Last selection snapshot, so [_onMainChanged] — which fires on
  /// EVERY MainProvider notification (chapter nav, settings, …) — can
  /// bail in O(selection size) instead of re-filtering the 31k-verse
  /// corpus via `selectedVerses` each time.
  Set<String> _lastSelectedIds = const {};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onMainChanged() {
    final ids = mainProvider.selectedIds;
    if (ids.length == _lastSelectedIds.length &&
        ids.containsAll(_lastSelectedIds)) {
      return;
    }
    _syncSelection();
  }

  void _syncSelection() {
    _lastSelectedIds = Set.of(mainProvider.selectedIds);
    analysisVerses = List.unmodifiable(mainProvider.selectedVerses);
    _notify();
  }

  // ── Search ────────────────────────────────────────────────────────

  /// Run the command-line query. Four shapes, checked in order:
  ///  1. The BibleWorks command-line grammar (`.love god`, `/faith
  ///     works`, `'in the beginning`, `;a b;3`) → [runCommandQuery].
  ///  2. Structured Strong's (`G25 AND G26`, `G25 NEAR5 G26`, `G25✶`)
  ///     → the shared boolean/proximity engine.
  ///  3. A bare Strong's number (`G25`, `H157`) → its concordance refs.
  ///  4. Anything else → the plain text scan over the loaded corpus.
  ///
  /// The grammar goes first because it is the only shape identified by
  /// its FIRST character, so it can never steal a query from the three
  /// below: no reference, version abbreviation or Strong's expression
  /// begins with `.`, `/`, `'` or `;`. Everything else is unchanged,
  /// which is the point — a reader who has never heard of a control
  /// character still has the substring search they had yesterday.
  Future<void> runSearch(String raw) async {
    final query = raw.trim();
    lastQuery = query;
    if (query.isEmpty) {
      clearResults();
      return;
    }
    searching = true;
    searchPerformed = false;
    strongsQueryLabel = null;
    strongsRefs = null;
    commandQuery = null;
    commandIssue = null;
    verbNotice = null;
    textResults = const [];
    _notify();

    try {
      final parse = parseCommandQuery(query);
      if (parse.isCommand) {
        commandQuery = parse.query;
        commandIssue = parse.issue;
        if (parse.query != null) {
          textResults = _runCommand(parse.query!);
        }
        return;
      }

      final bq = parseStrongsBoolean(query);
      if (bq != null) {
        strongsQueryLabel = query.toUpperCase();
        strongsRefs = _limitRefs(await SearchService.runStrongsBoolean(bq));
      } else if (_singleStrongsRe.hasMatch(query)) {
        final number = query.toUpperCase();
        final result = await ConcordanceService.lookup(number);
        strongsQueryLabel = number;
        // The bundled concordance already lists refs in canonical
        // order (Genesis … Revelation), so no re-sort here.
        strongsRefs = _limitRefs(result?.refs ?? const []);
      } else {
        final scan = SearchService.scanText(
          verses: mainProvider.verses,
          searchKeys: mainProvider.searchKeys,
          query: query,
          bookOrder: mainProvider.bookOrder,
          // The workbench command line always scans the whole Bible —
          // book scoping lives in the standalone SearchPage.
          searchAll: true,
        );
        textResults = applySearchLimit(
          scan.matches,
          searchLimit,
          (v) => '${toEnglish(v.book) ?? v.book}-${v.chapter}-${v.verse}',
        );
      }
    } finally {
      searching = false;
      searchPerformed = true;
      _notify();
    }
  }

  /// Run a parsed command query over the loaded corpus.
  ///
  /// Synchronous on purpose. The engine prefilters on the cached
  /// [MainProvider.searchKeys] before it tokenizes anything, so a
  /// realistic worst case over the whole 31,102-verse KJV measures in
  /// the low hundreds of milliseconds — cheaper than the isolate hop
  /// that hiding it behind a Future would cost.
  List<Verse> _runCommand(CommandQuery query) {
    final verses = mainProvider.verses;
    final result = runCommandQuery(
      query: query,
      texts: mainProvider.wordKeys,
      searchKeys: mainProvider.searchKeys,
      books: [for (final v in verses) v.book],
    );
    return applySearchLimit(
      [for (final i in result.indices) verses[i]],
      searchLimit,
      (v) => '${toEnglish(v.book) ?? v.book}-${v.chapter}-${v.verse}',
    );
  }

  List<ConcordanceRef> _limitRefs(List<ConcordanceRef> refs) => applySearchLimit(
        refs,
        searchLimit,
        (r) => '${r.englishBook}-${r.chapter}-${r.verse}',
      );

  void clearResults() {
    searching = false;
    searchPerformed = false;
    strongsQueryLabel = null;
    strongsRefs = null;
    commandQuery = null;
    commandIssue = null;
    verbNotice = null;
    textResults = const [];
    _notify();
  }

  // ── Ref → Verse lookup (shared by command pane + analysis pane) ──

  Map<String, Verse>? _verseByRefCache;
  List<Verse>? _verseByRefCacheVerses;
  String? _verseByRefCacheVersion;

  /// `'EnglishBook-chapter-verse'` → [Verse] over the loaded corpus.
  /// Rebuilt only when the corpus instance or version changes (same
  /// invalidation pattern as SearchPage's `_getVerseIndex`).
  Map<String, Verse> get verseByRef {
    if (identical(_verseByRefCacheVerses, mainProvider.verses) &&
        _verseByRefCacheVersion == mainProvider.currentVersion &&
        _verseByRefCache != null) {
      return _verseByRefCache!;
    }
    _verseByRefCacheVerses = mainProvider.verses;
    _verseByRefCacheVersion = mainProvider.currentVersion;
    _verseByRefCache = <String, Verse>{
      for (final v in mainProvider.verses)
        '${toEnglish(v.book) ?? v.book}-${v.chapter}-${v.verse}': v,
    };
    return _verseByRefCache!;
  }

  Verse? verseForRef(ConcordanceRef ref) =>
      verseByRef['${ref.englishBook}-${ref.chapter}-${ref.verse}'];

  // ── Analysis pane actions ─────────────────────────────────────────

  /// Focus a single verse in the analysis pane by making it the ONLY
  /// selected verse in the reader. Selection drives the pane, so this
  /// also visually selects it in the text (consistent with how a tap
  /// on the verse behaves).
  void focusVerse(Verse verse) {
    for (final s in mainProvider.selectedVerses) {
      if (s.id != verse.id) mainProvider.toggleVerse(verse: s);
    }
    if (!mainProvider.isSelected(verse)) {
      mainProvider.toggleVerse(verse: verse);
    }
  }

  /// Clear the reader's verse selection (empties the analysis pane).
  void clearAnalysis() {
    for (final s in mainProvider.selectedVerses) {
      mainProvider.toggleVerse(verse: s);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    mainProvider.removeListener(_onMainChanged);
    super.dispose();
  }
}
