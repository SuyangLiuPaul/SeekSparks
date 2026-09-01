import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show loadableVersions;
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/models/wb_centre_mode.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/ai_bible_search_service.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/search_service.dart';
import 'package:seeksparks/services/vocabulary_service.dart';
import 'package:seeksparks/utils/ai_ref_resolution.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/command_verb.dart' show LimitSpec;
import 'package:seeksparks/utils/compound_query.dart';
import 'package:seeksparks/utils/romanised_lemma.dart';
import 'package:seeksparks/utils/search_broadening.dart';
import 'package:seeksparks/utils/search_scope.dart' show limitSpecForBooks;
import 'package:seeksparks/utils/strongs_boolean_search.dart';
import 'package:seeksparks/utils/strongs_result_counts.dart';
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

  /// The locale the last search ran under, so a re-run triggered from
  /// inside the provider (setting a limit, say) glosses its lemma offer
  /// the same way the reader's own search did.
  String _lastLocale = 'en';

  bool searching = false;
  bool searchPerformed = false;

  /// Text-scan results (last query was NOT Strong's-shaped).
  List<Verse> textResults = const [];

  /// Strong's results: the display label (verbatim query, uppercased)
  /// plus refs. Null when the last search was a text scan.
  String? strongsQueryLabel;
  List<ConcordanceRef>? strongsRefs;

  /// What the header may claim about [strongsRefs] — see
  /// `strongs_result_counts.dart`. Carries the occurrence total beside
  /// the verse count, so H3068 reports 5,522 verses AND 6,521
  /// occurrences rather than picking one and leaving the unit implied.
  StrongsResultCounts? strongsCounts;

  /// Uncapped occurrences per canonical English book, for a query that
  /// named exactly ONE Strong's number. Empty for everything else.
  ///
  /// The concordance's per-book map is the only whole-Bible per-book
  /// count in the repo, and it is what lets the results distribution
  /// draw a common word at all — see `strongsDistribution`. A composed
  /// expression has no such map, because no uncapped total exists for a
  /// set operation over several entries.
  Map<String, int> strongsByBook = const <String, int>{};

  /// Whether this result stands for less than the query named.
  ///
  /// Since v1.6.96 that can only mean a WILDCARD whose expansion was cut
  /// at its own limit, dropping whole numbers out of the query — the
  /// per-entry verse cap that used to cause it is gone.
  ///
  /// Deliberately NOT read off [strongsCounts]: that object answers what
  /// the HEADER may claim, and it suppresses truncation under a search
  /// limit on purpose. The distribution needs the raw fact — a scope
  /// narrows which verses are shown, it does not restore the terms that
  /// were never searched.
  bool strongsListTruncated = false;

  /// The whole-Bible totals for a SINGLE-number query, before the `l`
  /// search limit narrowed them. Null when the concordance has no entry
  /// for the number, and null on every other search shape.
  ///
  /// Kept raw and separate from [strongsCounts] on purpose:
  /// `strongsResultCounts` drops the occurrence total whenever a limit is
  /// active (correctly — an unattributed Bible-wide number beside a
  /// Genesis-only list reads as Genesis's own). The empty-result message
  /// names the scope in the same sentence, so it may state both.
  int? strongsCorpusVerses;
  int? strongsCorpusOccurrences;

  /// The last query, parsed, when it was written in the command-line
  /// grammar (`.love god`, `'in the beginning`, …). The pane echoes it
  /// back in words: a grammar whose operators are punctuation is only
  /// safe if the reader can see what the punctuation was taken to mean.
  CommandQuery? commandQuery;

  /// Why a command-shaped query was refused. Set exactly when the query
  /// began with a control character and did not parse — never for
  /// ordinary text, which is not a failed command but a plain search.
  CommandIssue? commandIssue;

  /// The last query when it was written as a compound search
  /// (`(.grac* work*;5).15(/jesus christ)`). Set instead of
  /// [commandQuery], never alongside it.
  CompoundQuery? compoundQuery;

  /// How many verses each group of [compoundQuery] matched on its own,
  /// in the order written. The combined list cannot show which half of a
  /// compound was the empty one; this can.
  List<int>? compoundGroupCounts;

  /// The looser reading of the last query, and how many verses it really
  /// returns. Null whenever it would not help — including, deliberately,
  /// when it returns no more than the search the reader already ran.
  ///
  /// See `search_broadening.dart`: the count here is measured, not
  /// predicted, and is measured under the same edition and the same
  /// scope, so tapping it cannot land on a shorter list than the one it
  /// advertised.
  SearchBroadening? broadening;

  /// Which of the last query's words the corpus does not contain, when
  /// the search and its looser reading both returned nothing.
  TermPresence? termsMissing;

  /// The Strong's entries a romanised Greek or Hebrew word reaches, when
  /// the edition on screen does not use the word — `agape` → G26,
  /// `shalom` → H7965. See `romanised_lemma.dart`.
  ///
  /// Gated on the word occurring in NO verse of the whole edition — at
  /// any scope, see [_measureLemmaOffer] — and that gate is the whole
  /// safety argument. 1,814 of the KJV's 12,546 distinct words fold onto
  /// some romanised lexicon key — mostly its own transliterated proper
  /// names, which resolve correctly, but also `bad` → H905 בַּד, `den` →
  /// H1836 and `dove` → H1679, which next to an English result would be
  /// false etymological claims. Not one of the 1,814 occurs zero times
  /// in the KJV. So the gate excludes every word the edition contains,
  /// and the class cannot arise.
  ///
  /// Arrives a beat after the results because building the index costs
  /// several MB of assets that nothing else on the page needs.
  LemmaOffer? lemmaOffer;

  // ── AI passage search ─────────────────────────────────────────────
  //
  // A fourth result shape beside text, Strong's and command queries,
  // and the only one whose answer does not come out of the corpus.
  // Kept as its own state rather than folded into [textResults]
  // because the reader has to be able to tell the difference: these
  // are suggestions from a model, they carry a stated reason, and some
  // of them will not be in the loaded edition at all.

  bool aiBusy = false;

  /// The question, as asked. Null when the last search was not an AI one.
  String? aiQuery;

  /// Every reference the AI returned that survived the search limit, in
  /// its order — including the ones that resolved to nothing.
  List<AiBibleRef>? aiRefs;

  /// `AiBibleRef.display` of the references with no verse behind them.
  Set<String> aiUnresolved = const {};

  /// Why some of the answer is missing, or why there is no answer.
  /// Model-authored prose in the reader's locale, or a service error.
  String? aiNotice;

  bool get hasAiResults => aiRefs != null;

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
  ///
  /// Only the description of last resort. When [searchLimitSpec] is
  /// present it is what the UI should name the scope from, because it
  /// can be re-localised and this cannot.
  String? searchLimitLabel;

  /// The book/chapter description that produced [searchLimit], when one
  /// did — the `l` verb's spec, or the scope picker's book set.
  ///
  /// Null when the limit is a Verse List Manager list, which is an
  /// arbitrary set of verses with no range description to recover.
  /// Holding it matters for two things the key set cannot do: the
  /// picker reads back which books are ticked, and the banner prints
  /// 创世记 rather than "Genesis" (the same defect class as #283 — a
  /// display surface printing the canonical English name).
  LimitSpec? searchLimitSpec;

  bool get hasSearchLimit => searchLimit != null;

  /// Point subsequent searches at [keys], labelled [label], and re-run
  /// the last query so the results on screen match the limit that is
  /// now displayed. Passing null clears the limit.
  Future<void> setSearchLimit(Set<String>? keys, String? label,
      {LimitSpec? spec}) async {
    searchLimit = keys;
    searchLimitLabel = keys == null ? null : (label ?? '');
    searchLimitSpec = keys == null ? null : spec;
    _notify();
    if (lastQuery.isNotEmpty) await runSearch(lastQuery, locale: _lastLocale);
  }

  /// Install the scope picker's book selection. An empty set clears the
  /// limit, which is the sheet's "whole Bible" option.
  Future<bool> setSearchLimitFromBooks(Set<String> books) async {
    if (books.isEmpty) {
      await setSearchLimit(null, null);
      return true;
    }
    final spec = limitSpecForBooks(books);
    return setSearchLimitFromSpec(spec, spec.label);
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
    await setSearchLimit(keys, label, spec: spec);
    return true;
  }

  // ── Browse stack (centre pane) ────────────────────────────────────

  /// What the centre pane is showing — the chapter reader, the Browse
  /// stack, or two editions side by side. See [WbCentreMode].
  ///
  /// This was a `bool parallelMode` while there were two answers. It is
  /// deliberately NOT kept as a derived `parallelMode` getter alongside
  /// the enum: with three modes, `!parallelMode` no longer means "the
  /// chapter reader", and every call site that still read it that way
  /// would have been wrong in split mode without failing to compile.
  WbCentreMode centreMode = WbCentreMode.browse;

  List<String> _parallelVersions = const [];

  /// The comparison editions in the Browse stack, in display order.
  ///
  /// Lives here rather than in `_WorkbenchPageState` because the command
  /// line addresses it (`d nas`, `p a b c`, bwh44) and the command line
  /// is a sibling widget, not a child. The page still owns persistence
  /// and calls back through [onBrowseStateChanged].
  List<String> get parallelVersions => _parallelVersions;

  /// 2026-08-08: assignment runs through [loadableVersions], so a code
  /// this build cannot load can never enter the stack.
  ///
  /// A setter rather than a filter at the restore site, because the
  /// stack is written from three directions — the page restoring
  /// SharedPreferences, the command line's `p` / `d` verbs, and the
  /// version picker — and read from four more. Guarding each of those
  /// separately is precisely how the reading version came to be
  /// validated on some paths and not others, which is the bug this
  /// exists to close: a retired code reached `FetchVerses`, the missing
  /// asset came back as the host's SPA fallback, and boot died inside
  /// `json.decode` on a message naming neither the version nor the file.
  ///
  /// Silent on purpose. The comparison stack is scenery around the
  /// reader's real choice and one substituted column does not warrant an
  /// interruption; a retired PRIMARY reading version does, and says so
  /// through `MainProvider.retiredVersionNotice`.
  set parallelVersions(List<String> codes) {
    _parallelVersions = List.unmodifiable(loadableVersions(codes));
  }

  /// Called after the command line changes [centreMode] or
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

  /// Colour the words where the editions on screen disagree — bwh30's
  /// *Toggle Difference Highlighting*.
  ///
  /// Off by default, and BibleWorks agrees: it ships the feature behind
  /// a settings window and a menu toggle rather than on. A Browse stack
  /// with the marks always on would be a page of underlines the moment a
  /// reader added a second English edition, and the reader has to be the
  /// one who asks the question.
  ///
  /// Lives here beside [parallelVersions] rather than in `AppSettings`
  /// because it is a property of the comparison stack, and it is only
  /// meaningful while that stack holds two editions of one language.
  bool browseDiff = false;

  void setBrowseDiff(bool on) {
    if (browseDiff == on) return;
    browseDiff = on;
    _notify();
    onBrowseStateChanged?.call();
  }

  void setCentreMode(WbCentreMode mode) {
    if (centreMode == mode) return;
    centreMode = mode;
    _notify();
    onBrowseStateChanged?.call();
  }

  void setParallelVersions(List<String> codes) {
    parallelVersions = codes;
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
  Future<void> runSearch(String raw, {String locale = 'en'}) async {
    final query = raw.trim();
    lastQuery = query;
    _lastLocale = locale;
    if (query.isEmpty) {
      clearResults();
      return;
    }
    searching = true;
    searchPerformed = false;
    strongsQueryLabel = null;
    strongsRefs = null;
    strongsCounts = null;
    strongsByBook = const <String, int>{};
    strongsListTruncated = false;
    strongsCorpusVerses = null;
    strongsCorpusOccurrences = null;
    commandQuery = null;
    compoundQuery = null;
    compoundGroupCounts = null;
    broadening = null;
    termsMissing = null;
    lemmaOffer = null;
    commandIssue = null;
    verbNotice = null;
    textResults = const [];
    _clearAi();
    _notify();

    try {
      // Compound first: it is the only shape that can open with `(`, and
      // it declines every line that is not unambiguously compound, so it
      // cannot take a plain `(hello)` away from the text scan below.
      final compound = parseCompoundQuery(query);
      if (compound.isCompound) {
        compoundQuery = compound.query;
        commandIssue = compound.issue;
        if (compound.query != null) {
          textResults = _runCompound(compound.query!);
        }
        return;
      }

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
        final composed = await SearchService.runStrongsBoolean(bq);
        final refs = _limitRefs(composed.refs);
        strongsRefs = refs;
        // No occurrence total exists for a composed expression: it is a
        // set operation over verse lists, and one verse can carry
        // several hits of each term.
        strongsCounts = strongsResultCounts(
          versesShown: refs.length,
          incomplete: composed.truncatedTerms,
        );
        strongsListTruncated = composed.truncatedTerms;
      } else if (_singleStrongsRe.hasMatch(query)) {
        final number = query.toUpperCase();
        final result = await ConcordanceService.lookup(number);
        strongsQueryLabel = number;
        // The bundled concordance already lists refs in canonical
        // order (Genesis … Revelation), so no re-sort here.
        final listed = result?.refs ?? const <ConcordanceRef>[];
        final refs = _limitRefs(listed);
        // Raw, pre-limit, so an empty list can say WHICH kind of empty it
        // is: absent from the corpus, or present and excluded by the `l`
        // limit. Null lookup ⇔ absent — the concordance ships no entry
        // with an empty ref list (14,040 checked).
        strongsCorpusVerses = result == null ? null : listed.length;
        strongsCorpusOccurrences = result?.total;
        strongsRefs = refs;
        strongsByBook = result?.byBook ?? const <String, int>{};
        // A single number's verse list is complete since v1.6.96, so the
        // scoped count below is exact and the distribution can be drawn
        // from the verses the reader is actually holding.
        strongsListTruncated = false;
        strongsCounts = strongsResultCounts(
          versesShown: refs.length,
          occurrences: result?.total,
          scoped: hasSearchLimit,
        );
      } else {
        // A Strong's expression the parser REFUSED is not plain text.
        // Before this, `G25 NEAR G26` fell through to the literal scan
        // below and came back "no results" — the engine's refusal and an
        // empty Bible are different facts and the reader saw only the
        // second. `G25* NEAR G26` was worse: it carries a `*`, so the
        // promotion below rewrote it into `.G25* NEAR G26` and ran it as
        // a wildcard TEXT search. Hence: before the promotion, not after.
        final strongsIssue = diagnoseStrongsBoolean(query);
        if (strongsIssue != null) {
          commandIssue = strongsIssue;
          return;
        }
        // A bare `faith*` reaches here only because it is not a command
        // and not Strong's, and the scan below is literal — so it would
        // find nothing, which is what the `✶` chip's own example did
        // (#295). Run it as `.faith*` instead. Only when that parses:
        // otherwise the reader would be shown a command error for a line
        // they never wrote as a command.
        final promoted = needsWildcardPromotion(query)
            ? parseCommandQuery('.$query')
            : null;
        if (promoted?.query != null) {
          commandQuery = promoted!.query;
          textResults = _runCommand(promoted.query!);
          return;
        }
        final scan = SearchService.scanText(
          verses: mainProvider.verses,
          searchKeys: mainProvider.searchKeys,
          query: query,
          bookOrder: mainProvider.bookOrder,
          // The command line always scans the whole Bible; scoping is
          // the `l` verb's job (a verse-key search limit), applied
          // below, so a limit can be a chapter range and not just a
          // book.
          searchAll: true,
        );
        textResults = applySearchLimit(
          scan.matches,
          searchLimit,
          (v) => '${toEnglish(v.book) ?? v.book}-${v.chapter}-${v.verse}',
        );
      }
    } finally {
      // Only the text shapes have a rung below them. A Strong's number
      // is not a word order, and a grammar error is not a thin result.
      if (strongsRefs == null && commandIssue == null) _measureBroadening();
      searching = false;
      searchPerformed = true;
      _notify();
      // Deliberately after the page is on screen, and deliberately not
      // awaited: the romanised index needs the concordance and both
      // lexicons, several MB the reader has not necessarily paid for
      // yet, and none of it can change the result that was just shown.
      unawaited(_measureLemmaOffer(query, locale));
    }
  }

  /// Which Strong's entries the reader's word reaches, when no verse of
  /// the edition uses the word.
  ///
  /// The last rung of the ladder `search_broadening.dart` starts, and
  /// the only one that reaches a single-word query: a looser reading of
  /// one word does not exist (there is no word order to drop), and
  /// [termPresence] needs two terms before it can name the guilty one.
  /// So until now a reader who typed `agape` got "No results found" and
  /// nothing else, over a corpus that contains the word 116 times.
  ///
  /// Every guard the other shapes need is already inside [romanisedKey]
  /// — a digit, a space or any of the grammar's control characters
  /// fails it — so a Strong's number, a command line and a compound
  /// cannot reach the index.
  Future<void> _measureLemmaOffer(String query, String locale) async {
    if (romanisedKey(query) == null) return;
    // The gate is the word, not the page. A plain one-word search is a
    // substring match over space-stripped keys, so in the KJV `theos`
    // matches "these are", `shalom` matches "Jehovahshalom", `torah`
    // matches "unto Rahab" and `charis` matches "Issachar is" — and a
    // gate on the result list being empty would have stayed silent for
    // exactly the words this exists for. Read as words, all four occur
    // nowhere.
    //
    // And deliberately over the WHOLE corpus, not the reader's scope.
    // `wen`, `dam`, `owl`, `bat`, `cud`, `homer` are all KJV words that
    // appear nowhere in Genesis, so a scoped probe would call them
    // absent and offer `wen` → H1121 bên "a son". An etymological claim
    // is about the language, not about the passage she is standing in;
    // if the edition uses the word anywhere, the claim is false
    // everywhere. 152 of the KJV's 1,814 resolving words leaked through
    // a Genesis-scoped gate before this line said `verses` directly.
    final probe = parseCommandQuery('.$query').query;
    if (probe == null) return;
    final corpus = mainProvider.verses;
    final present = runCommandQuery(
      query: probe,
      texts: mainProvider.wordKeys,
      searchKeys: mainProvider.searchKeys,
      books: [for (final v in corpus) v.book],
    ).indices.isNotEmpty;
    if (present) return;

    final index = await _romanisedIndex(locale);
    if (index == null) return;

    final hits = <LemmaHit>[];
    for (final candidate in index.resolve(query)) {
      final result = await ConcordanceService.lookup(candidate.strongs);
      if (result == null) continue;
      final verses = _limitRefs(result.refs).length;
      // Under a search limit a real word can occur nowhere in scope.
      // The rule this whole ladder exists for: the app does not offer a
      // query it has not run, and never one it has run to nothing.
      if (verses == 0) continue;
      hits.add(LemmaHit(candidate: candidate, verses: verses));
    }
    if (hits.isEmpty) return;
    // The reader may have typed something else, or left the search
    // behind entirely, while the assets loaded.
    if (lastQuery != query || !searchPerformed) return;
    lemmaOffer = LemmaOffer(query: query, hits: hits);
    _notify();
  }

  RomanisedLemmaIndex? _romanisedIndexCache;
  String? _romanisedIndexLocale;

  /// The romanised index for [locale], built once.
  ///
  /// Keyed on locale because the gloss shown in the offer is, and built
  /// from [VocabularyService.corpusVocabulary] rather than from the
  /// assets directly so there is exactly one join of the concordance to
  /// the lexicons in the app.
  Future<RomanisedLemmaIndex?> _romanisedIndex(String locale) async {
    if (_romanisedIndexCache != null && _romanisedIndexLocale == locale) {
      return _romanisedIndexCache;
    }
    final words = await VocabularyService.corpusVocabulary(locale);
    if (words.isEmpty) return null;
    _romanisedIndexLocale = locale;
    return _romanisedIndexCache = RomanisedLemmaIndex.fromWords(words);
  }

  /// Run the looser reading of the last query and keep it only if it
  /// beats the one the reader ran.
  ///
  /// Gated on the result count for two reasons at once: above
  /// [kBroadenBelow] the offer would be noise, and below it the second
  /// scan is free — the reader is looking at a short list, and the scan
  /// measures at 14-42 ms over the whole 31,102-verse corpus, which is
  /// why this is a plain synchronous call and not an isolate.
  void _measureBroadening() {
    broadening = null;
    termsMissing = null;
    // A compound line has no looser reading: dropping its operators
    // would leave `broadenedCommandLine` staring at parentheses it does
    // not know, and the useful thing to say about an empty compound is
    // WHICH group was empty, which `compoundGroupCounts` already holds.
    if (compoundQuery != null) return;
    final current = textResults.length;
    if (current > kBroadenBelow) return;

    CommandQuery? broader;
    final line = broadenedCommandLine(parsed: commandQuery, raw: lastQuery);
    if (line != null) {
      broader = parseCommandQuery(line).query;
      if (broader != null) {
        final verses = _runCommand(broader).length;
        // The whole point: an offer that does not beat what the reader
        // already has is a second dead end, so it is not made.
        if (verses > current) {
          broadening =
              SearchBroadening(line: line, query: broader, verses: verses);
        }
      }
    }

    if (current > 0 || broadening != null) return;
    // Nothing found and nothing looser to offer: say which word is the
    // reason rather than repeating that there are no results.
    final subject = commandQuery ?? broader;
    if (subject == null || subject.positiveTerms.length < 2) return;
    final limit = searchLimit;
    final verses = mainProvider.verses;
    termsMissing = termPresence(
      query: subject,
      texts: mainProvider.wordKeys,
      searchKeys: mainProvider.searchKeys,
      books: [for (final v in verses) v.book],
      inScope: limit == null
          ? null
          : (i) {
              final v = verses[i];
              return limit.contains(
                  '${toEnglish(v.book) ?? v.book}-${v.chapter}-${v.verse}');
            },
    );
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

  /// Run a parsed compound query, keeping each group's own count.
  List<Verse> _runCompound(CompoundQuery query) {
    final verses = mainProvider.verses;
    final result = runCompoundQuery(
      query: query,
      texts: mainProvider.wordKeys,
      searchKeys: mainProvider.searchKeys,
      books: [for (final v in verses) v.book],
    );
    compoundGroupCounts = result.groupCounts;
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
    strongsCounts = null;
    strongsByBook = const <String, int>{};
    strongsListTruncated = false;
    strongsCorpusVerses = null;
    strongsCorpusOccurrences = null;
    commandQuery = null;
    compoundQuery = null;
    compoundGroupCounts = null;
    broadening = null;
    termsMissing = null;
    lemmaOffer = null;
    commandIssue = null;
    verbNotice = null;
    textResults = const [];
    _clearAi();
    _notify();
  }

  void _clearAi() {
    aiBusy = false;
    aiQuery = null;
    aiRefs = null;
    aiUnresolved = const {};
    aiNotice = null;
  }

  /// The AI call itself, injectable so everything around it — clearing
  /// the other result shapes, the busy flag, the scope closure, the
  /// mirror into [textResults] — can be tested without a network.
  /// Production never sets this.
  @visibleForTesting
  Future<AiBibleSearchResult> Function(String query)? aiAsk;

  /// Ask the model for passages matching [question], then join its
  /// answer to the loaded edition.
  ///
  /// Takes the AI settings as arguments rather than reading them: this
  /// provider is constructed with a [MainProvider] and nothing else,
  /// and reaching for `AppSettings` here would make every test that
  /// touches the workbench need one.
  Future<void> runAiSearch({
    required String question,
    required String locale,
    String? userApiKey,
    String? aiModel,
  }) async {
    final query = question.trim();
    if (query.isEmpty) return;

    // The AI answer replaces whatever was on screen, exactly as a new
    // text search would. Leaving the old hits under a new header is
    // the bug that makes a results pane untrustworthy.
    strongsQueryLabel = null;
    strongsRefs = null;
    strongsCounts = null;
    strongsByBook = const <String, int>{};
    strongsListTruncated = false;
    strongsCorpusVerses = null;
    strongsCorpusOccurrences = null;
    commandQuery = null;
    compoundQuery = null;
    compoundGroupCounts = null;
    broadening = null;
    termsMissing = null;
    lemmaOffer = null;
    commandIssue = null;
    verbNotice = null;
    textResults = const [];
    lastQuery = query;
    _clearAi();

    aiBusy = true;
    aiQuery = query;
    searchPerformed = false;
    _notify();

    try {
      final result = await (aiAsk?.call(query) ??
          AiBibleSearchService.ask(
            query: query,
            locale: locale,
            userApiKey:
                (userApiKey == null || userApiKey.isEmpty) ? null : userApiKey,
            aiModel: aiModel,
          ));

      if (result.unavailable) {
        aiRefs = const [];
        aiNotice = result.unavailableReason;
        return;
      }

      final limit = searchLimit;
      final resolution = resolveAiRefs(
        refs: result.refs,
        verses: mainProvider.verses,
        inScope: limit == null
            ? null
            : (ref) {
                for (var v = ref.verseStart; v <= ref.verseEnd; v++) {
                  if (limit.contains('${ref.book}-${ref.chapter}-$v')) {
                    return true;
                  }
                }
                return false;
              },
      );

      aiRefs = resolution.kept;
      aiUnresolved = resolution.unresolvedDisplays;
      // The resolved verses also become the ordinary result set, so
      // everything downstream that consumes a hit list — the Verse
      // List Manager, "limit to these results", the copy paths —
      // works on an AI answer without knowing where it came from.
      textResults = resolution.verses;
      aiNotice = describeAiGaps(
        locale: locale,
        outOfScope: resolution.outOfScope,
        unresolved: resolution.unresolvedDisplays.length,
        empty: resolution.kept.isEmpty,
      );
    } finally {
      // Unconditional: an exception escaping the service would
      // otherwise leave the pane spinning with no way back.
      aiBusy = false;
      searchPerformed = true;
      _notify();
    }
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
