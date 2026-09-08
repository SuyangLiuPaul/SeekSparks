import 'dart:async' show unawaited;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show fullBibleVersionLabel;
import 'package:seeksparks/constants/text_patterns.dart'
    show sanitizeForSearch, versePreviewText;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/word_study_style.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/strongs.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/widgets/collapsible_english_ref.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart'
    show WbToolButton, WbToolIcon;
import 'package:seeksparks/widgets/left_accent_card.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/lxx_service.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/interlinear_editions.dart';
import 'package:seeksparks/utils/ketiv_qere.dart';
import 'package:seeksparks/utils/morphology.dart';
import 'package:seeksparks/widgets/interlinear_verse_text.dart';
import 'package:seeksparks/utils/search_stats.dart' show HitUnit;
import 'package:seeksparks/utils/theme_color_helpers.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localeAwareBookName, toEnglish;
import 'package:seeksparks/widgets/word_distribution.dart';
import 'package:seeksparks/widgets/word_distribution_table.dart';

/// Bottom sheet that shows the original Hebrew/Greek text for one or
/// more selected verses, with each word as a tappable chip linked to
/// its Strong's lexicon entry.
///
/// Pure data — no AI, no network. The sheet falls back to a friendly
/// "no original-language data for this verse yet" message when bundled
/// coverage is missing for the verse, so the affordance always opens.
///
/// `onNavigateRef` is invoked when the user taps a concordance entry
/// (e.g. "John 3:16"). The host widget is responsible for closing the
/// sheet, switching to that book/chapter, and scrolling to the verse —
/// the sheet stays presentation-only.
class OriginalsSheet extends StatefulWidget {
  final List<Verse> verses;
  final List<Verse> allVerses;
  final String locale;
  final String? currentVersion;
  final void Function(ConcordanceRef ref)? onNavigateRef;

  /// 2026-08-04 (Workbench): when true the sheet renders as a
  /// persistent embedded panel (the Workbench's right-hand analysis
  /// pane) instead of a modal sheet/route. It then draws no header of
  /// its own — the pane owns its title strip and its collapse button,
  /// which is the only way those stay put as the pointer moves between
  /// a word and its verse (task #284).
  final bool embedded;

  const OriginalsSheet({
    super.key,
    required this.verses,
    this.allVerses = const [],
    required this.locale,
    this.currentVersion,
    this.onNavigateRef,
    this.embedded = false,
  });

  @override
  State<OriginalsSheet> createState() => _OriginalsSheetState();
}

class _OriginalsSheetState extends State<OriginalsSheet> {
  late Future<List<_VerseOriginals>> _future;
  OriginalWord? _selectedWord;
  StrongsEntry? _selectedEntry;
  ConcordanceResult? _selectedConcordance;
  // When non-null, the user is browsing a root entry instead of the
  // word entry. Back button reverts to the word entry.
  StrongsEntry? _rootEntry;
  ConcordanceResult? _rootConcordance;
  bool _loadingEntry = false;
  // TapGestureRecognizers for inline derivation links — disposed on change.
  final _tapRecognizers = <TapGestureRecognizer>[];

  // Strong's-entry cache for the interlinear gloss line rendered below
  // each word chip. Populated once in [_loadAll] and reused by every
  // chip so we don't re-fetch the same lemma over and over.
  final Map<String, StrongsEntry?> _glossCache = {};

  // Which book group is currently expanded in the concordance section.
  // Null = all collapsed. Reset whenever the user switches to a new
  // word entry or root entry.
  String? _expandedConcordanceBook;

  // Loaded interlinear data — set once _loadAll completes so the
  // "copy table" button can build the TSV without re-awaiting the future.
  List<_VerseOriginals>? _verseOriginals;

  // "englishBook-chapter-verse" → cleaned verse text for concordance preview.
  late final Map<String, String> _verseIndex;

  // Word family (siblings + children) and synonyms (compare refs) for the
  // currently displayed entry. Populated asynchronously after each word tap.
  List<StrongsEntry> _wordFamily = const [];
  List<StrongsEntry> _compareWords = const [];

  // Pre-fetched concordances for every related entry (family + synonym),
  // so tapping a chip can immediately show inline verse refs without
  // a per-tap network round trip. Populated by _loadRelations.
  Map<String, ConcordanceResult?> _relatedConcordances = {};

  // Strong's # of the word-family / synonym chip currently expanded
  // inline (showing its verse refs below the Wrap). Null = all collapsed.
  String? _expandedRelatedNumber;

  // Strong's #s for which the user has tapped "+N more" to reveal
  // every concordance ref (rather than the default first-8 preview).
  // Cleared whenever the user switches to a new word entry.
  final Set<String> _refsShowAll = {};

  // LXX Greek equivalents for the current Hebrew entry (empty for
  // Greek entries). Tapping a chip navigates into that Greek entry,
  // which then loads its own family / synonyms / verses — letting
  // the user pivot from Hebrew to Greek word study seamlessly.
  List<StrongsEntry> _lxxEquivalents = const [];

  // Reverse LXX: Hebrew Strong's that the LXX renders using the
  // current Greek entry. Empty for Hebrew entries. Lets a NT reader
  // surface OT roots — e.g. for κύριος (G2962) shows יהוה (H3068),
  // אֲדֹנָי (H136), etc.
  List<StrongsEntry> _hebrewSources = const [];

  // The Strong's # the user pivoted FROM via Full Study. When that
  // chip is auto-expanded in the new entry, we hide the redundant
  // "Full Study →" link inside it (clicking it would just take them
  // back to where they came from — confusing right after navigation).
  String? _pivotFromNumber;

  // 2026-05-10 (v1.2.30): generation counter for in-flight Strong's /
  // concordance / relations lookups. Bumped at the start of every new
  // word tap (`_onWordTap`), root-entry navigation (`_loadRootEntry`),
  // and clear-root (`_clearRoot`). Each async branch captures the gen
  // at entry and bails out (no setState) if the gen has moved on by
  // the time it tries to land. Without this, tapping word A then word
  // B before A's lookup resolves can leave A's entry/concordance/
  // family rendered under B's selection — same "stale resolution"
  // pattern fixed in v1.2.8 (BYOK Test) but not yet here.
  int _lookupGen = 0;

  // ── the interlinear (2026-09-08) ──────────────────────────────────
  //
  // 「这个原文的时候现在是一个个单词翻译 但是我想好像微读圣经一样可以选
  // 译本 我提供这么多 然后这样看也容易些」. The panel used to print the
  // reader's own verse as plain prose above the word grid; it now
  // prints a TAGGED edition with the numbers set into the line, and the
  // reader says which edition. See `utils/interlinear_editions.dart`
  // for which editions may be offered, and `widgets/
  // interlinear_verse_text.dart` for how a verse is set.
  //
  // The word grid stays. It is not the same data and does not answer
  // the same question: the grid is the ORIGINAL — lemma, translit,
  // parsing, gloss, out of `assets/originals/` — and the interlinear is
  // a TRANSLATION carrying numbers, out of `assets/tagged/`. Deleting
  // the grid would take the Hebrew off a Hebrew panel. It is also the
  // only thing left when a verse has no tagged text, which happens.

  /// The choice the panel resolved this build — which edition, and
  /// whether it is the reader's own or a substitute.
  InterlinearChoice _choice =
      (version: null, source: InterlinearSource.none);

  /// `"Genesis-1-1"` → that verse's runs in [_choice], or null when the
  /// edition has nothing for it. Missing key = not loaded yet.
  Map<String, List<TaggedRun>?> _runs = const {};

  /// The edition [_runs] was loaded for, so a rebuild that did not
  /// change the choice does not reload it.
  String? _runsFor;

  /// Same staleness guard as [_lookupGen], for the same reason: a
  /// reader can change the picker twice before the first load lands.
  int _runsGen = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _verseIndex = {
      for (final v in widget.allVerses)
        '${(toEnglish(v.book) ?? v.book)}-${v.chapter}-${v.verse}': v.text,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribed with `listen: true` on purpose — this is the canonical
    // place to do it, and it is what makes the panel reload when the
    // reader picks a different edition (the pick is a persisted
    // setting, so the picker writes to AppSettings and the reload
    // arrives back here). Guarded by [_runsFor]: AppSettings notifies
    // for every preference in the app, and all but one of those must
    // cost nothing.
    final chosen = Provider.of<AppSettings>(context).interlinearVersion;
    _choice = resolveInterlinearEdition(
      chosen: chosen,
      currentVersion: widget.currentVersion,
    );
    if (_choice.version != _runsFor) _loadInterlinear(_choice.version);
  }

  Future<void> _loadInterlinear(String? version) async {
    final myGen = ++_runsGen;
    _runsFor = version;
    if (version == null) {
      if (mounted) setState(() => _runs = const {});
      return;
    }
    final out = <String, List<TaggedRun>?>{};
    for (final v in widget.verses) {
      final english = toEnglish(v.book) ?? v.book;
      out['$english-${v.chapter}-${v.verse}'] =
          await TaggedTextService.forVerse(
        version: version,
        englishBook: english,
        chapter: v.chapter,
        verse: v.verse,
      );
    }
    if (!mounted || myGen != _runsGen) return;
    setState(() => _runs = out);
  }

  /// Open what a tapped Strong's number has always opened: the word
  /// entry card, by way of [_onWordTap].
  ///
  /// The originals row is preferred over the run because it carries the
  /// things the card prints that a translation cannot — the pointed
  /// Hebrew, the transliteration, the morphology, the Ketiv/Qere role.
  /// The run is the fallback for a number the originals asset does not
  /// have a word for, which is what `browse_window.dart` already does
  /// when a tagged translation word is clicked: the number is still
  /// real and still has a lexicon entry, so refusing the tap would be
  /// worse than showing the entry under the translation's own word.
  void _onRunTap(TaggedRun run, _VerseOriginals vo) {
    for (final w in vo.words ?? const <OriginalWord>[]) {
      if (w.strongs == run.strongs) {
        _onWordTap(w);
        return;
      }
    }
    _onWordTap(OriginalWord(text: run.text.trim(), strongs: run.strongs));
  }

  /// Scroll controller for the embedded (docked-pane) presentation; the
  /// modal presentation gets one from DraggableScrollableSheet instead.
  final ScrollController _embeddedScroll = ScrollController();

  @override
  void dispose() {
    _embeddedScroll.dispose();
    _clearTapRecognizers();
    super.dispose();
  }

  void _clearTapRecognizers() {
    for (final r in _tapRecognizers) {
      r.dispose();
    }
    _tapRecognizers.clear();
  }

  Future<List<_VerseOriginals>> _loadAll() async {
    final results = <_VerseOriginals>[];
    for (final v in widget.verses) {
      final english = toEnglish(v.book) ?? v.book;
      final words =
          await OriginalsService.forVerse(english, v.chapter, v.verse);
      results.add(_VerseOriginals(
        verse: v,
        words: words,
        omitted: words == null &&
            await OriginalsService.isAbsentFromOriginal(
                english, v.chapter, v.verse),
      ));
    }
    // Prefetch Strong's entries for every unique number across all
    // verses so the interlinear gloss row under each chip can render
    // synchronously when the chip first builds. Lookups are async but
    // hit a cached lexicon after the first call, so wrapping them in
    // `Future.wait` parallelises the dictionary scans.
    final uniqueNums = <String>{};
    for (final r in results) {
      for (final w in r.words ?? const <OriginalWord>[]) {
        uniqueNums.add(w.strongs);
      }
    }
    await Future.wait(uniqueNums.map((n) async {
      if (_glossCache.containsKey(n)) return;
      _glossCache[n] = await StrongsService.lookup(n);
    }));
    if (mounted) setState(() => _verseOriginals = results);
    return results;
  }

  Future<void> _onWordTap(OriginalWord w) async {
    final myGen = ++_lookupGen;
    _clearTapRecognizers();
    _pivotFromNumber = null;
    setState(() {
      _selectedWord = w;
      _selectedEntry = null;
      _selectedConcordance = null;
      _rootEntry = null;
      _rootConcordance = null;
      _loadingEntry = true;
      _expandedConcordanceBook = null;
      _wordFamily = const [];
      _compareWords = const [];
      _relatedConcordances = const {};
      _expandedRelatedNumber = null;
      _refsShowAll.clear();
      _lxxEquivalents = const [];
      _hebrewSources = const [];
    });
    // Fire both lookups in parallel — Strong's entry is per-language,
    // concordance is a single shared file that gets warmed by the
    // first lookup of the session.
    final entryFuture = StrongsService.lookup(w.strongs);
    final concordanceFuture = ConcordanceService.lookup(w.strongs);
    final entry = await entryFuture;
    final concordance = await concordanceFuture;
    // v1.2.30: bail if the user has tapped a different word while we
    // were resolving — preserves selection coherence.
    if (!mounted || myGen != _lookupGen) return;
    _clearTapRecognizers();
    setState(() {
      _selectedEntry = entry;
      _selectedConcordance = concordance;
      _loadingEntry = false;
      // All book groups are collapsed by default — user opts in to
      // auto-expand-first via the AppSettings.autoExpandFirstRef flag.
      _expandedConcordanceBook =
          (context.read<AppSettings>().autoExpandFirstRef &&
                  concordance?.refs.isNotEmpty == true)
              ? concordance!.refs.first.englishBook
              : null;
    });
    // Word family + synonyms load in the background — doesn't block the entry card.
    unawaited(_loadRelations(w.strongs, gen: myGen));
  }

  Future<void> _loadRootEntry(String strongsNumber,
      {String? pivotFromNumber}) async {
    final myGen = ++_lookupGen;
    _pivotFromNumber = pivotFromNumber;
    _clearTapRecognizers();
    setState(() {
      _loadingEntry = true;
      _expandedConcordanceBook = null;
      _wordFamily = const [];
      _compareWords = const [];
      _relatedConcordances = const {};
      _expandedRelatedNumber = null;
      _refsShowAll.clear();
      _lxxEquivalents = const [];
      _hebrewSources = const [];
    });
    final entryFuture = StrongsService.lookup(strongsNumber);
    final concordanceFuture = ConcordanceService.lookup(strongsNumber);
    final entry = await entryFuture;
    final concordance = await concordanceFuture;
    // v1.2.30: bail if the user navigated to a different entry while
    // we were resolving.
    if (!mounted || myGen != _lookupGen) return;
    _clearTapRecognizers();
    setState(() {
      _rootEntry = entry;
      _rootConcordance = concordance;
      _loadingEntry = false;
      _expandedConcordanceBook = null;
    });
    // pivotFromNumber: when the user reached this entry via a chip in
    // a cross-language section (LXX or Hebrew Sources), auto-expand the
    // chip pointing back to where they came from so the OT context is
    // visible immediately — saves an extra tap.
    unawaited(_loadRelations(strongsNumber,
        pivotFromNumber: pivotFromNumber, gen: myGen));
  }

  void _clearRoot() {
    _clearTapRecognizers();
    _pivotFromNumber = null;
    setState(() {
      _rootEntry = null;
      _rootConcordance = null;
      _wordFamily = const [];
      _compareWords = const [];
      _relatedConcordances = const {};
      _expandedRelatedNumber = null;
      _refsShowAll.clear();
      _lxxEquivalents = const [];
      _hebrewSources = const [];
      // Restore the word-entry's auto-opened first book.
      _expandedConcordanceBook = null;
    });
    if (_selectedWord != null) {
      // v1.2.30: bump gen so the new relations chain participates in
      // the staleness check (otherwise a fast tap of clear → tap a
      // different word could see clearRoot's relations land afterwards).
      final myGen = ++_lookupGen;
      unawaited(_loadRelations(_selectedWord!.strongs, gen: myGen));
    }
  }

  Future<void> _loadRelations(String number,
      {String? pivotFromNumber, int? gen}) async {
    // v1.2.30: callers (`_onWordTap`, `_loadRootEntry`, `_clearRoot`)
    // pass their generation; if not provided, snapshot the current one
    // (defensive default, though all known callers now pass it).
    final myGen = gen ?? _lookupGen;
    final family = await StrongsService.wordFamily(number);
    final compare = await StrongsService.compareWords(number);
    // Hebrew entries get LXX Greek equivalents (forward).
    // Greek entries get Hebrew sources (reverse LXX).
    final lxx = number.startsWith('H')
        ? await LxxService.greekEntriesFor(number)
        : const <StrongsEntry>[];
    final hebSrc = number.startsWith('G')
        ? await LxxService.hebrewSourceEntriesFor(number)
        : const <StrongsEntry>[];
    if (!mounted || myGen != _lookupGen) return;
    // Prefetch concordances for every related entry in parallel.
    final all = <StrongsEntry>[...family, ...compare, ...lxx, ...hebSrc];
    final entries = <String, ConcordanceResult?>{};
    await Future.wait(all.map((e) async {
      entries[e.number] = await ConcordanceService.lookup(e.number);
    }));
    if (!mounted || myGen != _lookupGen) return;
    // If the user reached this entry by tapping a chip in a related
    // section (Word Family / Synonyms / LXX / Hebrew Sources) on the
    // previous entry, find that "previous" Strong's # in the new
    // entry's related sets and auto-expand it. For an LXX→Greek pivot
    // this surfaces the OT verses (via Hebrew Sources) immediately;
    // for a Hebrew Sources→Hebrew pivot it surfaces the LXX equivalent.
    String? autoExpand;
    if (pivotFromNumber != null) {
      final pivots = {
        for (final e in all) e.number,
      };
      if (pivots.contains(pivotFromNumber)) autoExpand = pivotFromNumber;
    }
    setState(() {
      _wordFamily = family;
      _compareWords = compare;
      _lxxEquivalents = lxx;
      _hebrewSources = hebSrc;
      _relatedConcordances = entries;
      if (autoExpand != null) _expandedRelatedNumber = autoExpand;
    });
  }

  /// Resolved once per build and read by every `_build*` helper below.
  ///
  /// A field rather than a parameter threaded through fifteen methods,
  /// and safe because it is assigned at the top of [build] and every
  /// helper is reached from that build's subtree.
  late WordStudyStyle _st;

  /// The same, for the sizes [WordStudyStyle] does not name.
  ///
  /// [WordStudyStyle] covers the seven sizes the word study's *content*
  /// uses. Around them sit forty section headings, badges, chip labels
  /// and disclaimers, and every one of those was a literal — so the pane
  /// obeyed the font-size setting in its verse text and ignored it
  /// everywhere else (#315). `_ty.scaled(n)` reads "n px at the default
  /// 20 pt".
  late WbType _ty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final title = uiStrings['originalText']?[locale] ?? 'Original Text';
    _ty = WbType.of(context);
    _st = WordStudyStyle.resolve(
      embedded: widget.embedded,
      scheme: scheme,
      wb: WbColors.of(context),
      type: _ty,
    );

    // 2026-08 (SeekSparks): DraggableScrollableSheet is a bottom-sheet
    // affordance. Inside the docked Workbench pane it rendered this panel
    // as a floating sheet starting 30% down the pane (initialChildSize:
    // 0.7), which left a large empty gap above the header and made the
    // "Word Study" title visibly jump down the moment a verse was
    // selected. Embedded fills the pane; the modal keeps the sheet.
    if (widget.embedded) {
      return _buildPanel(context, scheme, locale, title, _embeddedScroll);
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      // Local Scaffold so snackbars from ScaffoldMessenger.of(ctx)
      // (e.g. the "Copied!" feedback after tapping a copy icon)
      // render INSIDE this modal sheet — without it the snackbar
      // anchors to the root scaffold below the modal and the user
      // never sees the feedback.
      builder: (context, scrollController) => Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildPanel(context, scheme, locale, title, scrollController),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, ColorScheme scheme, String locale,
      String title, ScrollController scrollController) {
    return Column(
      mainAxisSize: widget.embedded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // 2026-08 (SeekSparks): the drag handle is a bottom-sheet
        // affordance — meaningless in the docked Workbench pane.
        if (!widget.embedded)
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: _st.r(2),
            ),
          ),
        // 2026-08-09 (task #284): the docked pane draws NO header
        // here. It used to draw its own — a 16px title, a copy
        // button and a collapse chevron — and `workbench_page`
        // suppressed the real `WbPaneTitle` to make room for it.
        // That was only half the tab: hovering a WORD renders
        // `WordAnalysisPane` instead, which has no header at all, so
        // the pane's title and its collapse control appeared and
        // vanished as the pointer crossed between a word and its
        // verse. The pane owns them now; this is content.
        if (!widget.embedded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(Icons.auto_stories, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: _ty.scaled(16),
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        uiStrings['interlinearHint']?[locale] ??
                            'Original · Strong\'s gloss',
                        style: TextStyle(
                          fontSize: _st.gloss,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_verseOriginals != null)
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    iconSize: 20,
                    tooltip:
                        uiStrings['copyTable']?[locale] ?? 'Copy word table',
                    onPressed: () => _copyInterlinearTable(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ]
        // Copy is the one control that was genuinely this widget's
        // own — it copies the word table it built — so it stays,
        // right-aligned at chrome scale. bwh10q puts the Forms tab's
        // Options button in the body for the same reason.
        else if (_verseOriginals != null) ...[
          SizedBox(
            height: WbType.of(context).paneTitleHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                WbToolIcon(
                  button: WbToolButton(
                    icon: Icons.copy_outlined,
                    tooltip:
                        uiStrings['copyTable']?[locale] ?? 'Copy word table',
                    onPressed: () => _copyInterlinearTable(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: FutureBuilder<List<_VerseOriginals>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data ?? const [];
              return ListView(
                controller: scrollController,
                padding: _st.listPadding,
                children: [
                  // Scrolls with the content rather than being pinned
                  // above it: at 375 pt the panel's whole job is to
                  // show a verse and an entry card, and a permanently
                  // parked control row would spend a line of that on
                  // something a reader touches once.
                  _buildInterlinearPicker(scheme, locale),
                  for (final vo in data) _buildVerseBlock(vo, scheme),
                  if (_selectedWord != null) ...[
                    const SizedBox(height: 16),
                    _buildEntryCard(context, scheme, locale),
                  ] else ...[
                    const SizedBox(height: 16),
                    _buildHint(scheme, locale),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// The picker, and the one sentence it sometimes has to say.
  ///
  /// A menu rather than a row of chips, and the rows carry
  /// [fullBibleVersionLabel] rather than the four-character gutter tag.
  /// That is the complaint filed against this app on the same day the
  /// feature was asked for — 「BGT BSB 雅简这些别人看简写不知道什么意思」
  /// — and a chip row of `BSB / CSB / KJV+S / LXX+WH / 雅简+` would be a
  /// fresh instance of it, in a picker whose entire purpose is letting
  /// a reader choose a text they recognise.
  Widget _buildInterlinearPicker(ColorScheme scheme, String locale) {
    final offered = interlinearEditions;
    final label = uiStrings['interlinearVersion']?[locale] ??
        'Interlinear version';

    if (offered.isEmpty || _choice.version == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: _st.dense ? 8 : 12),
        child: Text(
          uiStrings['interlinearNone']?[locale] ??
              'No bundled edition carries a Strong\'s alignment.',
          style: TextStyle(
            fontSize: _st.gloss,
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final shown = _choice.version!;
    return Padding(
      padding: EdgeInsets.only(bottom: _st.dense ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap, not Row: at 375 pt "Interlinear version" beside
          // "和合本雅伟版(简体)" is wider than the column, and a Row
          // would either overflow or ellipsise the edition name — which
          // is the one string on this line the reader is here to read.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: _st.ref,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: label,
                initialValue: shown,
                onSelected: (code) =>
                    context.read<AppSettings>().setInterlinearVersion(code),
                itemBuilder: (_) => [
                  for (final code in offered)
                    PopupMenuItem<String>(
                      value: code,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            code == shown
                                ? Icons.check
                                : Icons.check_box_outline_blank,
                            size: _ty.scaled(14),
                            color: code == shown
                                ? _st.accent
                                : Colors.transparent,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              fullBibleVersionLabel(code),
                              style: TextStyle(fontSize: _st.body),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding: _st.dense
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                      : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _st.chipFill,
                    borderRadius: _st.r(8),
                    border:
                        Border.all(color: _st.chipBorder, width: _st.borderWidth),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          fullBibleVersionLabel(shown),
                          style: TextStyle(
                            fontSize: _st.body,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: _ty.scaled(18),
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Nothing narrows in silence: a reader whose Bible has no
          // tagging is told whose translation they are looking at
          // instead, by name, rather than left to notice.
          if (_choice.source == InterlinearSource.substituted &&
              widget.currentVersion != null) ...[
            SizedBox(height: _st.dense ? 3 : 5),
            Text(
              (uiStrings['interlinearSubstituted']?[locale] ??
                      '{reading} carries no Strong\'s alignment, so the line '
                          'below is {shown}.')
                  .replaceAll(
                      '{reading}', fullBibleVersionLabel(widget.currentVersion!))
                  .replaceAll('{shown}', fullBibleVersionLabel(shown)),
              style: TextStyle(
                fontSize: _st.gloss,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerseBlock(_VerseOriginals vo, ColorScheme scheme) {
    final ref = '${vo.verse.book} ${vo.verse.chapter}:${vo.verse.verse}';
    final isHebrew = (vo.words ?? const []).isNotEmpty &&
        vo.words!.first.strongs.startsWith('H');
    // Round 56 (continued — Aramaic highlight): English book name for
    // [isAramaicWord] lookup. `vo.verse.book` may already be localised
    // depending on the source path, so canonicalise it.
    final englishBook = toEnglish(vo.verse.book) ?? vo.verse.book;
    final words = vo.words;
    // Verse text from the user's current Bible version, with `{...}`
    // emphasis braces and `<note:...>` markers stripped so the panel
    // reads cleanly. We keep `[...]` (e.g. KJV italicized supplied
    // words) since that's part of the published text.
    final verseText = sanitizeForSearch(vo.verse.text);
    // 2026-09-08: the runs of the chosen interlinear edition, when it
    // has this verse. Null covers three states the block treats alike
    // because the reader cannot act differently on them — not loaded
    // yet, this edition has no such book, this edition has no such
    // verse — and only the third is worth a sentence, so the note below
    // waits until the load has actually landed for this edition.
    final runs = _runs['$englishBook-${vo.verse.chapter}-${vo.verse.verse}'];
    final loaded = _runsFor != null && _runs.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: _st.dense ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref,
            style: TextStyle(
              fontSize: _st.ref,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          if (runs != null || verseText.isNotEmpty) ...[
            SizedBox(height: _st.dense ? 3 : 6),
            // The translation line, in the same place it has always
            // been: above the original-language row so the reader can
            // read down from the sentence to the words. What changed on
            // 2026-09-08 is what is IN it — the chosen edition's own
            // words with their Strong's numbers in the line, instead of
            // the current version's text as plain prose. Same block,
            // same accent rule, more in it.
            LeftAccentCard(
              // v1.3.x: was Container(BoxDecoration(border:
              // Border(left:...), borderRadius:...)) — non-uniform
              // border + radius throws in Border.paint.
              padding: _st.blockPadding,
              background: _st.blockFill,
              borderRadius: _st.r(8),
              accentColor: _st.accent,
              // The accent rule is the one thing that survives at
              // workbench density unchanged: it is what says "this line
              // is the translation, the row under it is the original".
              accentWidth: 3,
              child: runs != null
                  ? InterlinearVerseText(
                      runs: runs,
                      style: _st,
                      // The reader's own switch for Strong's numbers in
                      // this panel. Off leaves the line as running
                      // prose, which is what the panel printed before
                      // today — honest, and still the edition they
                      // picked rather than the one they are reading.
                      showNumbers:
                          context.watch<AppSettings>().showStrongsInOriginals,
                      highlightStrongs: _selectedWord?.strongs,
                      onTapRun: (run) => _onRunTap(run, vo),
                    )
                  : Text(
                      verseText,
                      style: TextStyle(
                        fontSize: _st.body,
                        color: scheme.onSurface,
                        height: _st.dense ? WbMetrics.lineHeight : 1.5,
                      ),
                    ),
            ),
            if (runs == null && loaded && _choice.version != null) ...[
              SizedBox(height: _st.dense ? 2 : 4),
              Text(
                (uiStrings['interlinearVerseMissing']?[widget.locale] ??
                        '{shown} has no tagged text for this verse.')
                    .replaceAll(
                        '{shown}', fullBibleVersionLabel(_choice.version!)),
                style: TextStyle(
                  fontSize: _st.gloss,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          SizedBox(height: _st.dense ? 6 : 10),
          if (words == null || words.isEmpty)
            Text(
              vo.omitted
                  ? (uiStrings['originalOmitsVerse']?[widget.locale] ??
                      'This verse is not in the critical edition of the '
                          'original, so there is no original text to show.')
                  : (uiStrings['originalNotAvailable']?[widget.locale] ??
                      'Original-language data not available for this verse '
                          'yet.'),
              style: TextStyle(
                fontSize: _st.dense ? _st.body : _ty.scaled(13),
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Directionality(
              textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                alignment: isHebrew ? WrapAlignment.end : WrapAlignment.start,
                children: [
                  for (final w in words)
                    _wordChip(
                      w,
                      scheme,
                      englishBook: englishBook,
                      chapter: vo.verse.chapter,
                      verse: vo.verse.verse,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _wordChip(
    OriginalWord w,
    ColorScheme scheme, {
    required String englishBook,
    required int chapter,
    required int verse,
  }) {
    final isSelected =
        _selectedWord?.strongs == w.strongs && _selectedWord?.text == w.text;
    // Round 56 (continued — Aramaic highlight): tag chips whose word
    // is Aramaic so the reader can see at a glance which embedded
    // tokens are Aramaic vs. surrounding Hebrew/Greek. Teal matches
    // the Aramaic accent on the Bible Languages card.
    final isAramaic = isAramaicWord(
      englishBook: englishBook,
      chapter: chapter,
      verse: verse,
      strongs: w.strongs,
    );
    // Interlinear gloss row — the Strong's entry's primary meaning in
    // the user's locale (English `gloss` or Chinese `glossZh`). Shown
    // beneath the original word so a reader who doesn't know
    // Hebrew/Greek can immediately see what each word means.
    final entry = _glossCache[w.strongs];
    final gloss = compactGloss(entry?.localizedGloss(widget.locale) ?? '');
    final pos = morphologyPartOfSpeech(w.morph, widget.locale);
    // Aramaic chips: teal-tinted background + 1.5px teal border, even
    // when not selected. Selected Aramaic chips switch to the primary
    // colour scheme so the selection cue stays unambiguous.
    final Color bgColor;
    final Color borderColor;
    if (isSelected) {
      bgColor = _st.selectedFill;
      borderColor = _st.selectedBorder;
    } else if (isAramaic) {
      // Theme-aware teal so the chip stays readable + vivid in dark
      // mode. paletteBg = teal.shade100 (light) / teal.shade900 with
      // alpha (dark); paletteBorder uses a brighter teal in dark
      // mode so the border is still visible.
      //
      // Dense: the border alone carries it. Filling every Aramaic chip
      // in a pane that is mostly Aramaic (Daniel 2–7, Ezra 4–7) turns
      // the distinction into a background, and the badge above the
      // lemma already states it in words.
      bgColor = _st.dense ? _st.chipFill : paletteBg(context, Colors.teal);
      borderColor = paletteBorder(context, Colors.teal);
    } else {
      bgColor = _st.chipFill;
      borderColor = _st.chipBorder;
    }
    return InkWell(
      onTap: () => _onWordTap(w),
      borderRadius: _st.r(8),
      child: Container(
        padding: _st.dense
            ? const EdgeInsets.symmetric(horizontal: 5, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        constraints: BoxConstraints(
          minWidth: _st.dense ? 44 : 56,
          maxWidth: _st.chipMaxWidth,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: _st.r(8),
          border: Border.all(
            color: borderColor,
            width: _st.borderWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Round 56 (continued — Aramaic highlight): tiny teal pill
            // above the lemma reading "亚兰文 / 亞蘭文 / Aramaic" so the
            // distinction is visible without relying on colour alone.
            if (isAramaic) ...[
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: paletteBg(context, Colors.teal),
                    borderRadius: _st.r(8),
                  ),
                  child: Text(
                    uiStrings['aramaicWordBadge']?[widget.locale] ?? 'Aramaic',
                    style: TextStyle(
                      fontSize: _ty.scaled(11),
                      fontWeight: FontWeight.w700,
                      color: paletteFg(context, Colors.teal),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ],
            // Ketiv/Qere. Outlined, not filled like the Aramaic pill:
            // Aramaic is what the word IS, this is a claim about which
            // of two readings to say aloud, and the two should not look
            // like the same kind of fact.
            if (ketivQereMark(w.ketivQere) != null) ...[
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: _st.r(8),
                    border: Border.all(color: _st.chipBorder),
                  ),
                  child: Text(
                    w.isKetiv ? 'Ketiv' : 'Qere',
                    style: TextStyle(
                      fontSize: _ty.scaled(11),
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              w.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _st.original,
                fontWeight: FontWeight.w600,
                // The Ketiv is dimmed so the Qere beside it reads as the
                // running text, which is what the Masoretes direct. Both
                // stay on screen; neither is deleted.
                color: w.isKetiv ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
            if (w.translit != null && w.translit!.isNotEmpty)
              Text(
                w.translit!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _st.translit,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            // Strong's # badge — small, monospace, dimmed so it doesn't
            // compete with the lemma but is identifiable at a glance.
            // Force LTR Directionality so the number reads left-to-right
            // even when the surrounding chip Wrap is RTL for Hebrew.
            // Hidden when the user has disabled the badge in settings.
            if (context.read<AppSettings>().showStrongsInOriginals) ...[
              const SizedBox(height: 2),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding: _st.dense
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _st.strongsFill,
                    borderRadius: _st.r(3),
                  ),
                  child: Text(
                    w.strongs,
                    style: TextStyle(
                      fontSize: _st.micro,
                      fontWeight: FontWeight.w700,
                      color: _st.strongs,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
            if (gloss.isNotEmpty) ...[
              const SizedBox(height: 2),
              // Gloss is locale-script (LTR/Chinese), even when the
              // surrounding chip Wrap is RTL for Hebrew. Force LTR so
              // multi-word glosses don't render right-to-left inside
              // the Hebrew Directionality scope.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  gloss,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _st.gloss,
                    fontWeight: FontWeight.w500,
                    color: _st.accent.withValues(alpha: 0.85),
                    height: 1.2,
                  ),
                ),
              ),
            ],
            // Part of speech, inline. BibleWorks shows parsing without
            // asking, so the chip carries the one-word form and the
            // full parse appears in the card once the word is tapped.
            if (pos != null && pos.isNotEmpty) ...[
              const SizedBox(height: 2),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  pos,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _st.micro,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The parsing line for one word occurrence, e.g.
  /// "verb · aorist active indicative · 3rd person singular".
  ///
  /// Data is MorphGNT (Greek NT) / Open Scriptures (Hebrew OT), merged
  /// into the originals assets offline — see `lib/utils/morphology.dart`.
  /// Returns an empty box when this word has no code, which is the
  /// honest rendering for the small fraction the two text editions
  /// couldn't be aligned on.
  Widget _buildParsingLine(OriginalWord w, ColorScheme scheme, String locale) {
    final parse = describeMorphology(w.morph, locale);
    if (parse == null || parse.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: _st.dense ? 5 : 8),
      child: Container(
        width: double.infinity,
        padding: _st.dense
            ? const EdgeInsets.symmetric(horizontal: 5, vertical: 3)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _st.accentFill,
          borderRadius: _st.r(8),
          border: Border.all(
            color: _st.dense
                ? _st.blockBorder
                : _st.accent.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 6),
              child: Icon(Icons.account_tree_outlined,
                  size: 13, color: _st.accent.withValues(alpha: 0.75)),
            ),
            Expanded(
              child: Text(
                parse,
                style: TextStyle(
                  fontSize: _st.body,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _st.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tiny helper for the proper-noun gloss block — renders one row
  /// with a small italic label on the left and the gloss text on the
  /// right. Used for both "Etymology / 词源" and "Identification / 此处指"
  /// rows so they have a consistent shape.
  Widget _properNounRow({
    required ColorScheme scheme,
    required String label,
    required String value,
    required bool bold,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: _ty.scaled(11),
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: bold ? _ty.scaled(15) : _ty.scaled(13.5),
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: bold
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(
      BuildContext context, ColorScheme scheme, String locale) {
    final w = _selectedWord!;
    if (_loadingEntry) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // When the user has tapped a root link, show that entry instead.
    final isBrowsingRoot = _rootEntry != null;
    final entry = isBrowsingRoot ? _rootEntry : _selectedEntry;
    final concordance =
        isBrowsingRoot ? _rootConcordance : _selectedConcordance;
    // The displayed number: root number when browsing, otherwise the word's.
    final displayNumber = entry?.number ?? w.strongs;
    // Round 56 (continued — Aramaic highlight, entry card): tag the
    // header row when this Strong's entry is Aramaic. Detection
    // mirrors the chip-side rule: NT entries → curated Greek
    // transliteration set; OT entries → first verse falls inside a
    // known Aramaic section AND the entry is H-numbered. Browsing a
    // root pivoted away from the original verse keeps the badge as
    // long as the displayed number itself is in the Aramaic set
    // (true for the NT transliteration roots; false for plain OT
    // roots, which is the right behaviour — those roots aren't
    // exclusively Aramaic).
    bool entryIsAramaic = _aramaicGreekStrongs.contains(displayNumber);
    if (!entryIsAramaic && !isBrowsingRoot && widget.verses.isNotEmpty) {
      final v = widget.verses.first;
      final eb = toEnglish(v.book) ?? v.book;
      entryIsAramaic = isAramaicWord(
        englishBook: eb,
        chapter: v.chapter,
        verse: v.verse,
        strongs: displayNumber,
      );
    }

    return Container(
      padding: EdgeInsets.all(_st.dense ? 7 : 16),
      decoration: BoxDecoration(
        color: _st.blockFill,
        borderRadius: _st.r(12),
        border: Border.all(
            color: _st.dense ? _st.blockBorder : scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isBrowsingRoot) ...[
                InkWell(
                  onTap: _clearRoot,
                  borderRadius: _st.r(6),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child:
                        Icon(Icons.arrow_back, size: 18, color: scheme.primary),
                  ),
                ),
              ],
              Container(
                padding: _st.dense
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _st.dense
                      ? Colors.transparent
                      : _st.accent.withValues(alpha: 0.12),
                  borderRadius: _st.r(6),
                ),
                child: Text(
                  displayNumber,
                  style: TextStyle(
                    fontSize: _st.ref,
                    fontWeight: FontWeight.w700,
                    color: _st.dense ? _st.strongs : _st.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (entryIsAramaic) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _st.dense
                        ? Colors.transparent
                        : paletteBg(context, Colors.teal),
                    borderRadius: _st.r(6),
                    border: Border.all(
                      color: paletteBorder(context, Colors.teal),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    uiStrings['aramaicWordBadge']?[locale] ?? 'Aramaic',
                    style: TextStyle(
                      fontSize: _ty.scaled(11),
                      fontWeight: FontWeight.w700,
                      color: paletteFg(context, Colors.teal),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry?.lemma ?? w.text,
                  style: TextStyle(
                    fontSize: _st.lemma,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.table_chart_outlined),
                iconSize: 18,
                // 2026-05-10 (v1.2.31): keep glyph at 18 dp but bump
                // tap target to 48×48 for Material/WCAG a11y. Was
                // `padding: zero, constraints: BoxConstraints()` =
                // ~18 dp tap target (well below 48 dp minimum).
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: uiStrings['distributionTable']?[locale] ??
                    'Distribution Table',
                onPressed: () => _showDistributionTable(context),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                iconSize: 18,
                // v1.2.31: see above — 48 dp minimum tap target.
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip:
                    uiStrings['copyWordStudy']?[locale] ?? 'Copy word study',
                onPressed: () => _copyWordEntry(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Parsing line — the instance's morphology, not the lemma's.
          // This is the line BibleWorks' Analysis window is built
          // around, and it describes THIS occurrence, so it stays put
          // even while browsing a root entry would change everything
          // below it. Absent for the ~0.5% of words the corpora
          // couldn't align; nothing is shown rather than a guess.
          if (!isBrowsingRoot) _buildParsingLine(w, scheme, locale),
          // Why two words stand where the text has one. Tied to the
          // occurrence, like the parsing line above it, so it vanishes
          // when the reader browses to a root entry.
          if (!isBrowsingRoot)
            if (ketivQereLabel(w.ketivQere, locale) case final kqLabel?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$kqLabel — ${ketivQereNote(w.ketivQere, locale)}',
                  style: TextStyle(
                    fontSize: _ty.scaled(12),
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          if (entry != null) ...[
            if (entry.translit.isNotEmpty || entry.pronunciation.isNotEmpty)
              Text(
                [
                  if (entry.translit.isNotEmpty) entry.translit,
                  if (entry.pronunciation.isNotEmpty)
                    '/${entry.pronunciation}/',
                ].join('  '),
                style: TextStyle(
                  fontSize: _ty.scaled(13),
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            // Headline gloss and full definition follow the user's
            // current locale: Chinese for zh-Hans / zh-Hant when CBOL
            // has data, English fallback otherwise.
            //
            // 2026-05-07: for proper nouns (people, places, deities),
            // the two lexicon sources emphasise different aspects —
            // English Strong's gives the **etymology** (e.g. "Sceva"
            // → Latin "left-handed"), CBOL Chinese gives the **biblical
            // identification** (e.g. "一个祭司长，住在以弗所"). Showing
            // only one made users think the data contradicted itself.
            // Now we render BOTH with role labels so it reads as
            // "etymology + identification" — complementary, not
            // contradictory. Plus a small 👤 badge above so the user
            // knows this is a proper-noun entry.
            if (entry.isProperNoun &&
                entry.complementaryGloss(locale).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _st.dense
                          ? Colors.transparent
                          : scheme.tertiaryContainer.withValues(alpha: 0.55),
                      borderRadius: _st.r(4),
                      border:
                          _st.dense ? Border.all(color: _st.blockBorder) : null,
                    ),
                    child: Text(
                      uiStrings['exegesisProperNounBadge']?[locale] ??
                          'Proper noun',
                      style: TextStyle(
                        fontSize: _ty.scaled(11),
                        fontWeight: FontWeight.w700,
                        color: scheme.onTertiaryContainer,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uiStrings['exegesisProperNounNote']?[locale] ??
                          'Etymology + identification (both correct).',
                      style: TextStyle(
                        fontSize: _ty.scaled(11),
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Primary gloss (locale-preferred). For ZH this is the
              // CBOL identification; for EN this is the Strong's
              // etymology. Render with a subtle label.
              _properNounRow(
                scheme: scheme,
                label: locale.startsWith('zh')
                    ? (uiStrings['exegesisProperNounRoleLabel']?[locale] ??
                        '此处指')
                    : (uiStrings['exegesisProperNounEtymLabel']?['en'] ??
                        'Etymology'),
                value: entry.localizedGloss(locale),
                bold: true,
              ),
              const SizedBox(height: 4),
              // Complementary gloss (the "other" perspective).
              _properNounRow(
                scheme: scheme,
                label: locale.startsWith('zh')
                    ? (uiStrings['exegesisProperNounEtymLabel']?[locale] ??
                        '词源')
                    : (uiStrings['exegesisProperNounRoleLabel']?['en'] ??
                        'Identification'),
                value: entry.complementaryGloss(locale),
                bold: false,
              ),
            ] else if (entry.localizedGloss(locale).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.localizedGloss(locale),
                style: TextStyle(
                  fontSize: _ty.scaled(15),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
            if (entry.partOfSpeech != null &&
                entry.partOfSpeech!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.partOfSpeech!,
                style: TextStyle(
                  fontSize: _ty.scaled(11),
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ],
            // 2026-05-07 follow-up: for proper nouns also render the
            // OTHER language's definition body below, with clear
            // labels — same complementary-perspective philosophy as
            // the gloss block above. Without this the long definition
            // text still looked locale-locked (English etymology
            // paragraph for EN readers, Chinese identification
            // paragraph for ZH readers), making the user feel the
            // data was inconsistent. Now both are shown so the user
            // sees etymology + identification side by side at every
            // level of detail.
            if (entry.isProperNoun &&
                entry.complementaryDefinition(locale).isNotEmpty) ...[
              const SizedBox(height: 10),
              if (entry.localizedDefinition(locale).isNotEmpty)
                Text(
                  entry.localizedDefinition(locale),
                  style: TextStyle(
                    fontSize: _ty.scaled(14),
                    color: scheme.onSurface,
                    height: 1.45,
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: _st.dense
                      ? Colors.transparent
                      : scheme.tertiaryContainer.withValues(alpha: 0.25),
                  borderRadius: _st.r(6),
                  border: Border.all(
                    color: _st.dense
                        ? _st.blockBorder
                        : scheme.tertiary.withValues(alpha: 0.25),
                    width: 0.6,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.startsWith('zh')
                          ? (uiStrings['exegesisProperNounComplDefEn']
                                  ?[locale] ??
                              '英文 Strong\'s 完整释义')
                          : (uiStrings['exegesisProperNounComplDefZh']
                                  ?[locale] ??
                              'Chinese CBOL definition'),
                      style: TextStyle(
                        fontSize: _ty.scaled(11),
                        fontWeight: FontWeight.w700,
                        color: scheme.onTertiaryContainer,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.complementaryDefinition(locale),
                      style: TextStyle(
                        fontSize: _ty.scaled(13),
                        color: scheme.onSurface.withValues(alpha: 0.85),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (entry.cleanChineseDefinition(locale).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                // v1.3.x: English-only CBOL noise (id header, "AV -"
                // KJV counts) stripped for Chinese; the English moves
                // into the collapsible "英文参考" section below.
                entry.cleanChineseDefinition(locale),
                style: TextStyle(
                  fontSize: _ty.scaled(14),
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
              if (locale.startsWith('zh') &&
                  (entry.definitionZh ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  // CC-BY-NC-SA 4.0 attribution required by the source.
                  // Traditional users see the converted attribution
                  // string too — no script-mixing inside the panel.
                  locale == 'zh-Hant'
                      ? '中文釋義來源:CBOL · bible.fhl.net (CC-BY-NC-SA 4.0)'
                      : '中文释义来源:CBOL · bible.fhl.net (CC-BY-NC-SA 4.0)',
                  style: TextStyle(
                    fontSize: _st.translit,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            // Derivation / etymology line with tappable Strong's refs.
            // v1.3.x: this is English-only. In a Chinese panel, tuck it
            // behind a collapsed "英文参考" disclosure so the panel reads
            // as Chinese first; show inline for English readers.
            if ((entry.derivation ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              if (locale.startsWith('zh'))
                CollapsibleEnglishRef(
                  title: uiStrings['englishReference']?[locale] ??
                      'English reference',
                  child: _buildDerivationRich(entry.derivation!, scheme),
                )
              else
                _buildDerivationRich(entry.derivation!, scheme),
            ],
            if (_wordFamily.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRelatedSection(
                uiStrings['wordFamily']?[locale] ?? 'Word Family',
                _wordFamily,
                scheme,
                locale,
              ),
            ],
            if (_compareWords.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRelatedSection(
                uiStrings['synonyms']?[locale] ?? 'Synonyms',
                _compareWords,
                scheme,
                locale,
              ),
            ],
            if (_lxxEquivalents.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRelatedSection(
                uiStrings['lxxEquivalents']?[locale] ?? 'LXX Equivalents',
                _lxxEquivalents, scheme, locale,
                // Override: when expanding an LXX Greek chip, show the
                // OT verses where the source Hebrew word appears (the
                // verses the LXX renders using this Greek lemma). The
                // verse text is auto-displayed in the user's current
                // Bible version (English / Chinese) via _verseIndex.
                overrideConcordance: concordance,
                overrideHeaderLemma: entry.lemma,
              ),
            ],
            if (_hebrewSources.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRelatedSection(
                uiStrings['hebrewSources']?[locale] ?? 'Hebrew Sources',
                _hebrewSources,
                scheme,
                locale,
              ),
            ],
          ] else
            Text(
              uiStrings['strongsNotFound']?[locale] ??
                  'Lexicon entry not found for $displayNumber.',
              style: TextStyle(
                fontSize: _ty.scaled(13),
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (concordance != null && concordance.byBook.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
                height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            WordDistribution(
              byBook: concordance.byBook,
              // `ConcordanceResult.byBook` is the per-book OCCURRENCE
              // map: it sums to `total`, not to `refs.length`.
              unit: HitUnit.occurrences,
              locale: locale,
              currentVersion: widget.currentVersion,
            ),
          ],
          if (concordance != null && concordance.refs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
                height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            _buildConcordance(scheme, locale, concordance),
          ],
        ],
      ),
    );
  }

  /// Renders [text] with any Strong's refs ([GH]\d+) as tappable blue links.
  /// Recognizers are tracked in [_tapRecognizers] and disposed on state change.
  Widget _buildDerivationRich(String text, ColorScheme scheme) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'([GH]\d+)');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final num = m.group(1)!;
      final rec = TapGestureRecognizer()..onTap = () => _loadRootEntry(num);
      _tapRecognizers.add(rec);
      spans.add(TextSpan(
        text: num,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: scheme.primary.withValues(alpha: 0.6),
        ),
        recognizer: rec,
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: _ty.scaled(12),
          color: scheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
          height: 1.45,
        ),
        children: spans,
      ),
    );
  }

  // ── Word family + synonyms ──────────────────────────────────────────────────

  Widget _buildRelatedSection(String label, List<StrongsEntry> entries,
      ColorScheme scheme, String locale,
      {ConcordanceResult? overrideConcordance, String? overrideHeaderLemma}) {
    // Find which entry (if any) in this section is expanded — only
    // expand inline within the section that owns the chip, so a tap
    // on a Word-Family chip doesn't dangle verses inside the Synonyms
    // section.
    StrongsEntry? expanded;
    if (_expandedRelatedNumber != null) {
      for (final e in entries) {
        if (e.number == _expandedRelatedNumber) {
          expanded = e;
          break;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _ty.scaled(11),
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final e in entries) _relatedChip(e, scheme, locale)],
        ),
        if (expanded != null) ...[
          const SizedBox(height: 8),
          _buildExpandedRelatedVerses(expanded, scheme, locale,
              overrideConcordance: overrideConcordance,
              overrideHeaderLemma: overrideHeaderLemma),
        ],
      ],
    );
  }

  Widget _buildExpandedRelatedVerses(
      StrongsEntry e, ColorScheme scheme, String locale,
      {ConcordanceResult? overrideConcordance, String? overrideHeaderLemma}) {
    // For the LXX section we override the concordance so the user sees
    // the Old Testament verses where the source Hebrew word appears
    // (translated as this Greek word in the LXX) — that's the OT
    // context behind the Greek lemma. Verse text is displayed in the
    // current Bible version's locale via _lookupVerseText.
    final cr = overrideConcordance ?? _relatedConcordances[e.number];
    if (cr == null) {
      // Concordance still loading or genuinely unavailable.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
        ),
      );
    }
    if (cr.refs.isEmpty) {
      return Container(
        padding: _st.dense
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _st.dense ? Colors.transparent : _st.blockFill,
          borderRadius: _st.r(8),
          border: _st.dense ? Border.all(color: _st.blockBorder) : null,
        ),
        child: Text(
          uiStrings['concordanceNoResults']?[locale] ??
              'No verse references for this entry.',
          style: TextStyle(
              fontSize: _st.body,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic),
        ),
      );
    }
    final showAll = _refsShowAll.contains(e.number);
    final shown = showAll ? cr.refs : cr.refs.take(8).toList();
    final remaining = cr.refs.length - shown.length;
    final usedTemplate =
        uiStrings['concordanceUsed']?[locale] ?? 'Used {count} times';
    final usedLabel = usedTemplate.replaceAll('{count}', cr.total.toString());
    return Container(
      padding: _st.dense
          ? const EdgeInsets.fromLTRB(6, 5, 6, 5)
          : const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: _st.dense
            ? Colors.transparent
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: _st.r(10),
        border: Border.all(
          color: _st.dense
              ? _st.blockBorder
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: _st.dense ? WbMetrics.hairline : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: _st.dense
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _st.dense
                      ? Colors.transparent
                      : _st.accent.withValues(alpha: 0.12),
                  borderRadius: _st.r(4),
                ),
                child: Text(
                  e.number,
                  style: TextStyle(
                    fontSize: _st.micro,
                    fontWeight: FontWeight.w700,
                    color: _st.dense ? _st.strongs : _st.accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  overrideHeaderLemma != null
                      ? '${e.lemma} ← $overrideHeaderLemma · $usedLabel'
                      : '${e.lemma} · $usedLabel',
                  style: TextStyle(
                    fontSize: _ty.scaled(11),
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Hide the "Full Study →" link when this chip is the
              // back-pivot — clicking it would just take the user
              // where they just came from. Otherwise, tapping it
              // navigates into this entry's full word study, with the
              // current entry recorded as the next back-pivot.
              if (e.number != _pivotFromNumber)
                InkWell(
                  onTap: () {
                    final currentNumber =
                        (_rootEntry ?? _selectedEntry)?.number;
                    _loadRootEntry(e.number, pivotFromNumber: currentNumber);
                  },
                  borderRadius: _st.r(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          uiStrings['fullStudy']?[locale] ?? 'Full study',
                          style: TextStyle(
                            fontSize: _ty.scaled(11),
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            size: 12, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < shown.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: scheme.outlineVariant.withValues(alpha: 0.3)),
            _refRow(shown[i], scheme),
          ],
          if (remaining > 0) ...[
            const SizedBox(height: 4),
            // Tappable: reveal every remaining ref instead of the
            // first-8 preview. Idempotent — stays expanded until the
            // user switches to a new word.
            InkWell(
              onTap: () => setState(() => _refsShowAll.add(e.number)),
              borderRadius: _st.r(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+ $remaining ${uiStrings['moreRefs']?[locale] ?? 'more'}',
                      style: TextStyle(
                        fontSize: _ty.scaled(11),
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    Icon(Icons.expand_more, size: 14, color: scheme.primary),
                  ],
                ),
              ),
            ),
          ] else if (showAll && cr.refs.length > 8) ...[
            // Once expanded, show a "collapse" affordance so the
            // section can fold back to the compact preview.
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _refsShowAll.remove(e.number)),
              borderRadius: _st.r(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      uiStrings['collapse']?[locale] ?? 'Collapse',
                      style: TextStyle(
                        fontSize: _ty.scaled(11),
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    Icon(Icons.expand_less, size: 14, color: scheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _relatedChip(StrongsEntry e, ColorScheme scheme, String locale) {
    // Material ancestor guarantees InkWell.onTap fires on Flutter web.
    // Tap behavior: toggle inline verse-list expansion. To open the
    // full word study, the user uses the "Full study →" affordance
    // inside the expanded section.
    final isExpanded = _expandedRelatedNumber == e.number;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _expandedRelatedNumber = isExpanded ? null : e.number;
        }),
        borderRadius: _st.r(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _st.dense ? 5 : 8,
            vertical: _st.dense ? 4 : 5,
          ),
          constraints: BoxConstraints(maxWidth: _st.dense ? 180 : 200),
          decoration: BoxDecoration(
            color: isExpanded
                ? _st.selectedFill
                : (_st.dense
                    ? _st.chipFill
                    : scheme.secondaryContainer.withValues(alpha: 0.55)),
            borderRadius: _st.r(8),
            border: Border.all(
              color: isExpanded
                  ? _st.selectedBorder
                  : (_st.dense ? _st.chipBorder : scheme.outlineVariant),
              width: _st.dense ? _st.borderWidth : (isExpanded ? 1.5 : 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: _st.dense
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _st.strongsFill,
                      borderRadius: _st.r(4),
                    ),
                    child: Text(
                      e.number,
                      style: TextStyle(
                        fontSize: _st.micro,
                        fontWeight: FontWeight.w700,
                        color: _st.strongs,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      e.lemma,
                      style: TextStyle(
                        fontSize:
                            _st.dense ? _st.original : _ty.scaledOriginal(15),
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                e.localizedGloss(locale),
                style: TextStyle(
                  fontSize: _st.gloss,
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Copy helpers ────────────────────────────────────────────────────────────

  Future<void> _copyInterlinearTable(BuildContext ctx) async {
    final data = _verseOriginals;
    if (data == null) return;
    final locale = widget.locale;
    final buf = StringBuffer();
    buf.writeln(
        "Verse\tWord\tStrong's\tLemma\tTransliteration\tPronunciation\tGloss");
    for (final vo in data) {
      final en = toEnglish(vo.verse.book) ?? vo.verse.book;
      final verseRef =
          '${localeAwareBookName(en, locale, widget.currentVersion)} '
          '${vo.verse.chapter}:${vo.verse.verse}';
      for (final w in vo.words ?? const <OriginalWord>[]) {
        final entry = _glossCache[w.strongs];
        buf.writeln([
          verseRef,
          w.text,
          w.strongs,
          entry?.lemma ?? '',
          // The lemma's romanisation, or nothing. The occurrence's own
          // used to fill this in when the lexicon had no entry, which
          // put two different things in one column of a table a reader
          // pastes into a spreadsheet and sorts.
          entry?.translit ?? '',
          entry?.pronunciation ?? '',
          entry?.localizedGloss(locale) ?? '',
        ].map((s) => s.replaceAll('\t', ' ')).join('\t'));
      }
    }
    await ClipboardHelper.copyWithFeedback(ctx, buf.toString().trimRight());
  }

  Future<void> _copyWordEntry(BuildContext ctx) async {
    final isBrowsingRoot = _rootEntry != null;
    final entry = isBrowsingRoot ? _rootEntry : _selectedEntry;
    final concordance =
        isBrowsingRoot ? _rootConcordance : _selectedConcordance;
    final w = _selectedWord;
    if (entry == null && w == null) return;
    final locale = widget.locale;
    final buf = StringBuffer();

    // Single flat TSV so the whole family + synonyms paste cleanly into
    // Sheets/Excel as one table. Each row is tagged with a Section.
    buf.writeln(
        "Section\tStrong's\tLemma\tTranslit\tGloss\tDefinition\tReference\tVerse Text");

    void writeEntry(String section, StrongsEntry e, ConcordanceResult? cr) {
      final base = [
        section,
        e.number,
        e.lemma,
        e.translit,
        e.localizedGloss(locale),
        e.localizedDefinition(locale),
      ].map((s) => s.replaceAll('\t', ' ').replaceAll('\n', ' ')).toList();
      if (cr != null && cr.refs.isNotEmpty) {
        for (final r in cr.refs) {
          final label =
              '${localeAwareBookName(r.englishBook, locale, widget.currentVersion)} '
              '${r.chapter}:${r.verse}';
          final verseText = (_lookupVerseText(r) ?? '')
              .replaceAll('\t', ' ')
              .replaceAll('\n', ' ');
          buf.writeln([...base, label, verseText].join('\t'));
        }
      } else {
        buf.writeln([...base, '', ''].join('\t'));
      }
    }

    if (entry != null) {
      writeEntry('Main', entry, concordance);
    } else if (w != null) {
      buf.writeln([
        'Main',
        w.strongs,
        w.text,
        w.translit ?? '',
        '',
        '',
        '',
        '',
      ].join('\t'));
    }

    // Word family — fetch concordance per entry; cached after first lookup.
    for (final famEntry in _wordFamily) {
      final famConc = await ConcordanceService.lookup(famEntry.number);
      writeEntry('Family', famEntry, famConc);
    }

    // Synonyms / compare references.
    for (final synEntry in _compareWords) {
      final synConc = await ConcordanceService.lookup(synEntry.number);
      writeEntry('Synonym', synEntry, synConc);
    }

    // LXX Greek equivalents (Hebrew → Greek). Their concordance is
    // already cached in _relatedConcordances from _loadRelations.
    for (final lxxEntry in _lxxEquivalents) {
      final lxxConc = _relatedConcordances[lxxEntry.number] ??
          await ConcordanceService.lookup(lxxEntry.number);
      writeEntry('LXX', lxxEntry, lxxConc);
    }

    // Hebrew sources (Greek → Hebrew). Mirror of LXX for NT entries.
    for (final hebEntry in _hebrewSources) {
      final hebConc = _relatedConcordances[hebEntry.number] ??
          await ConcordanceService.lookup(hebEntry.number);
      writeEntry('HebrewSource', hebEntry, hebConc);
    }

    if (!ctx.mounted) return;
    await ClipboardHelper.copyWithFeedback(ctx, buf.toString().trimRight());
  }

  // ── Distribution table ───────────────────────────────────────────

  void _showDistributionTable(BuildContext ctx) {
    final isBrowsingRoot = _rootEntry != null;
    final entry = isBrowsingRoot ? _rootEntry : _selectedEntry;
    // Resolve the Strong's # from any of: root entry → selected entry →
    // raw selected word. We prefer entry when available (typed lemma)
    // but fall back to the original-word's strongs so the table still
    // opens even if the lexicon lookup hasn't completed.
    final number = entry?.number ?? _selectedWord?.strongs;
    if (number == null || number.isEmpty) return;
    final locale = widget.locale;
    final scheme = Theme.of(ctx).colorScheme;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      // Wider sheet on desktop/iPad — Material's default ~640dp cap
      // squeezes the table on wide screens.
      constraints: const BoxConstraints(maxWidth: 1400),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  // modal-only: the distribution table is always a bottom
                  // sheet, never the docked pane, so it keeps its handle.
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined,
                        color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        uiStrings['distributionTable']?[locale] ??
                            'Distribution Table',
                        style: TextStyle(
                          fontSize: _ty.scaled(16),
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      onPressed: () => Navigator.of(sheetCtx).maybePop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: WordDistributionTable(
                  strongsNumber: number,
                  locale: locale,
                  currentVersion: widget.currentVersion,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConcordance(
      ColorScheme scheme, String locale, ConcordanceResult cr) {
    final usedTemplate =
        uiStrings['concordanceUsed']?[locale] ?? 'Used {count} times';
    final usedLabel = usedTemplate.replaceAll('{count}', cr.total.toString());
    final shown = cr.refs.length;
    final showingFirst = shown < cr.total
        ? (uiStrings['concordanceShowingFirst']?[locale] ??
                'showing first {shown} of {total}')
            .replaceAll('{shown}', shown.toString())
            .replaceAll('{total}', cr.total.toString())
        : null;

    // Group refs by book, preserving canonical order of first appearance.
    final grouped = <String, List<ConcordanceRef>>{};
    for (final r in cr.refs) {
      grouped.putIfAbsent(r.englishBook, () => []).add(r);
    }
    final books = grouped.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                usedLabel,
                style: TextStyle(
                  fontSize: _ty.scaled(13),
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        if (showingFirst != null) ...[
          const SizedBox(height: 2),
          Text(
            showingFirst,
            style: TextStyle(
              fontSize: _ty.scaled(11),
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < books.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    thickness: 0.5,
                    color: scheme.outlineVariant.withValues(alpha: 0.3)),
              _buildBookGroup(
                books[i],
                grouped[books[i]]!,
                cr.byBook[books[i]] ?? grouped[books[i]]!.length,
                scheme,
                locale,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBookGroup(
    String englishBook,
    List<ConcordanceRef> refs,
    int totalCount,
    ColorScheme scheme,
    String locale,
  ) {
    final localBook =
        localeAwareBookName(englishBook, locale, widget.currentVersion);
    final isExpanded = _expandedConcordanceBook == englishBook;
    final countTemplate =
        uiStrings['concordanceBookCount']?[locale] ?? '{count} occurrences';
    final countLabel =
        countTemplate.replaceAll('{count}', totalCount.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book header — tappable to expand/collapse
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() {
              _expandedConcordanceBook = isExpanded ? null : englishBook;
            }),
            borderRadius: _st.r(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.arrow_right_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localBook,
                          style: TextStyle(
                            fontSize: _ty.scaled(13),
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          countLabel,
                          style: TextStyle(
                            fontSize: _ty.scaled(11),
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expandable ref list
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < refs.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        thickness: 0.5,
                        color: scheme.outlineVariant.withValues(alpha: 0.4)),
                  _refRow(refs[i], scheme),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _localizedRefLabel(ConcordanceRef r) {
    final localBook = localeAwareBookName(
        r.englishBook, widget.locale, widget.currentVersion);
    return '$localBook ${r.chapter}:${r.verse}';
  }

  String? _lookupVerseText(ConcordanceRef r) {
    final raw = _verseIndex['${r.englishBook}-${r.chapter}-${r.verse}'];
    if (raw == null) return null;
    return versePreviewText(raw);
  }

  Widget _refRow(ConcordanceRef r, ColorScheme scheme) {
    final canNavigate = widget.onNavigateRef != null;
    final label = _localizedRefLabel(r);
    final preview = _lookupVerseText(r);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canNavigate ? () => widget.onNavigateRef!(r) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: _ty.scaled(12),
                  fontWeight: FontWeight.w600,
                  color: canNavigate ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              if (preview != null) ...[
                const SizedBox(height: 3),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: _ty.scaled(12),
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHint(ColorScheme scheme, String locale) {
    return Container(
      padding: _st.dense ? _st.blockPadding : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _st.dense
            ? Colors.transparent
            : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: _st.r(12),
        border: _st.dense
            ? Border.all(color: _st.blockBorder, width: _st.borderWidth)
            : null,
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined,
              color: scheme.onSurfaceVariant, size: _st.dense ? 14 : 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              uiStrings['originalHint']?[locale] ??
                  'Tap a word to see its Strong\'s entry.',
              style: TextStyle(
                fontSize: _st.dense ? _st.ref : _ty.scaled(13),
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseOriginals {
  final Verse verse;
  final List<OriginalWord>? words;

  /// The original omits this verse entirely — one of the sixteen
  /// Received-Text verses, or Nehemiah 7:68. Distinguishes "we have no
  /// data" from "there is nothing to have".
  final bool omitted;
  _VerseOriginals(
      {required this.verse, required this.words, this.omitted = false});
}

// 2026-05-11 (v1.2.38): the inline markdown parser was extracted
// into `lib/utils/ai_markdown.dart::parseAiMarkdown` so other AI
// surfaces (search_page, evidence_page, settings_page tier panel)
// can render `**bold**` / `*italic*` properly instead of showing
// literal asterisks.

/// Round 56 (continued — Aramaic highlight): when the user taps into
/// an Aramaic passage from the Bible Tools page, the OriginalsSheet
/// should visually distinguish the Aramaic words. The Strong's lexicon
/// in `assets/strongs/hebrew.json` doesn't carry a separate Aramaic
/// flag (Aramaic entries are mixed into the H#### range), so we
/// detect by reference instead. Two rules:
///
///   1) **OT verses inside known Aramaic sections** — every H-numbered
///      word in Daniel 2:4–7:28, Ezra 4:8–6:18, Ezra 7:12–26,
///      Genesis 31:47, and Jeremiah 10:11 is Aramaic. (Daniel 2:4a is
///      Hebrew but the whole verse switches mid-line; we still flag
///      every word in 2:4 because the chip view is per-word.)
///   2) **NT Aramaic transliterations** — specific Greek Strong's
///      numbers that are actually transliterated Aramaic on the lips
///      of Jesus / the early church (raca, talitha koum, ephphatha,
///      abba, eloi/lema/sabachthani, maranatha).
///
/// Only H-numbered words inside the OT ranges are flagged; G-numbered
/// words there (rare cross-references) are not. NT detection is
/// strictly by Strong's # — surrounding Greek words remain Greek.
bool isAramaicWord({
  required String englishBook,
  required int chapter,
  required int verse,
  required String strongs,
}) {
  // NT rule: known Aramaic transliterations carry a fixed set of
  // Greek Strong's #s regardless of the verse they appear in.
  if (_aramaicGreekStrongs.contains(strongs)) return true;
  // OT rule: chapter/verse falls inside a curated Aramaic section
  // AND the word is H-numbered (Hebrew/Aramaic side of the lexicon).
  if (!strongs.startsWith('H')) return false;
  switch (englishBook) {
    case 'Genesis':
      return chapter == 31 && verse == 47;
    case 'Jeremiah':
      return chapter == 10 && verse == 11;
    case 'Daniel':
      // 2:4b – 7:28. We accept the whole of 2:4 (per-word view).
      if (chapter < 2 || chapter > 7) return false;
      if (chapter == 2) return verse >= 4;
      if (chapter == 7) return verse <= 28;
      return true;
    case 'Ezra':
      if (chapter == 4) return verse >= 8;
      if (chapter == 5) return true;
      if (chapter == 6) return verse <= 18;
      if (chapter == 7) return verse >= 12 && verse <= 26;
      return false;
    default:
      return false;
  }
}

/// Greek Strong's numbers whose underlying word is Aramaic
/// transliterated into Greek script. These appear in the NT
/// embedded inside otherwise-Greek verses.
const Set<String> _aramaicGreekStrongs = {
  'G4469', // ῥακά (raca)
  'G5008', // ταλιθα (talitha)
  'G2891', // κουμι / κουμ (koumi/koum)
  'G2188', // εφφαθα (ephphatha)
  'G5', // ἀββα (abba)
  'G1682', // ἐλωΐ (eloi)
  'G2982', // λεμα (lema)
  'G4518', // σαβαχθανι (sabachthani)
  'G3134', // μαρὰν ἀθά (maranatha)
};

/// Compacts a raw Strong's gloss into a short chip label.
///
/// 2026-08 (SeekSparks): the lexicon glosses are full prose — e.g.
/// "a desolation (of surface), i.e. desert" or "above, over, upon, or
/// against (yet always in this last relation with a downward aspect)".
/// Rendered straight into a 140px chip with `maxLines: 2` they clipped
/// mid-abbreviation ("a desolation (of surface), i"), which reads as a
/// rendering bug rather than a definition. We keep the leading sense and
/// drop the parenthetical elaboration; the full text is still shown in
/// the entry card when the word is tapped.
String compactGloss(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  // Strong's separates distinct senses with ';' (or '；' in the
  // Chinese data) — the first is the primary one.
  for (final sep in const [';', '；']) {
    final i = s.indexOf(sep);
    if (i > 0) s = s.substring(0, i);
  }
  // "x, i.e. y" / "x, 即 y" — the part before is the gloss proper.
  for (final marker in const [', i.e.', ' i.e.', '，即', ', 即']) {
    final i = s.indexOf(marker);
    if (i > 0) s = s.substring(0, i);
  }
  // Parenthetical elaboration is detail, not definition.
  for (final open in const ['(', '（']) {
    final i = s.indexOf(open);
    if (i > 0) s = s.substring(0, i);
  }
  s = s.trim().replaceAll(RegExp(r'[,\uFF0C.、]+$'), '').trim();
  // Final safety cap — break on a word boundary rather than mid-word.
  const maxLen = 28;
  if (s.length > maxLen) {
    final cut = s.lastIndexOf(' ', maxLen);
    s = '${s.substring(0, cut > 12 ? cut : maxLen).trimRight()}…';
  }
  return s;
}
