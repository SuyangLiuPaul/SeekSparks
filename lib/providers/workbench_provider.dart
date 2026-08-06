import 'package:flutter/foundation.dart';

import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/search_service.dart';
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

  /// Run the command-line query. Three shapes, checked in order:
  ///  1. Structured Strong's (`G25 AND G26`, `G25 NEAR5 G26`, `G25✶`)
  ///     → the shared boolean/proximity engine.
  ///  2. A bare Strong's number (`G25`, `H157`) → its concordance refs.
  ///  3. Anything else → the plain text scan over the loaded corpus.
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
    textResults = const [];
    _notify();

    try {
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
