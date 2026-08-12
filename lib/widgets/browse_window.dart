/// 2026-08 (SeekSparks): the Browse window, rebuilt to match BibleWorks.
///
/// The first attempt showed ONE verse at a time, stacked across
/// versions, with a stepper to move. That is not what BibleWorks' Browse
/// window does and it made the pane feel like a flash card rather than a
/// text. The real thing shows the **whole chapter, continuously**, with
/// every selected version printed one after another for each verse:
///
///     NAS  Genesis 1:1  In the beginning God created the heavens…
///     KJV  Genesis 1:1  In the beginning God created the heaven…
///     WTT  Genesis 1:1  בְּרֵאשִׁית בָּרָא אֱלֹהִים …
///     NAS  Genesis 1:2  And the earth was a formless and desolate…
///
/// You scroll it like a text, and the version tag colour is what lets
/// you read one translation straight down without the others getting in
/// the way. This file replaces `parallel_verse_view.dart`.
///
/// Hovering an original-language word reports it upward without a click
/// — BibleWorks' defining interaction, and the reason its Analysis
/// window feels alive.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show shortBibleVersionLabel;
import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/constants/ui_strings.dart' show uiStrings;
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/analysis_focus.dart';
import 'package:seeksparks/utils/scripture_markup.dart';
import 'package:seeksparks/utils/search_highlight.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/models/strongs.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/services/versification.dart';
import 'package:seeksparks/utils/morphology.dart' show describeMorphology;
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/strongs_inline.dart';
import 'package:seeksparks/utils/verse_text_absence.dart';
import 'package:seeksparks/utils/version_gutter.dart' show versionGutterWidth;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/workbench_chrome.dart' show WbVersionTag;

/// One printed line: a translation of a verse, or its originals line.
class _BrowseRow {
  const _BrowseRow({
    required this.verse,
    required this.code,
    required this.reference,
    required this.firstOfVerse,
    this.text,
    this.words,
    this.runs,
    this.rtl = false,
    this.absence,
    this.mergedWith,
    this.superscription = '',
  });

  final int verse;

  /// The edition this line came from — a catalog code (`kjv`,
  /// `cuvs-yhwh`), or `wtt` / `bgt` for the original-language rows,
  /// which are assembled here rather than loaded from the catalog.
  ///
  /// The gutter resolves its own display label from this. The row used
  /// to store the label instead, which meant the word-identity keys it
  /// hands out were built from display text — so renaming an edition
  /// would have silently invalidated every pinned word.
  final String code;

  /// Localised "Genesis 1:1", printed after the tag like BibleWorks.
  final String reference;

  /// True on the first line of a verse group — draws the hairline above.
  final bool firstOfVerse;

  final String? text;
  final List<OriginalWord>? words;

  /// Strong's-tagged runs, when this version ships tagging. Present
  /// alongside [text]: the plain string is still the fallback for any
  /// verse the tagger missed.
  final List<TaggedRun>? runs;

  final bool rtl;

  /// Set when [text] is the edition's typographic instruction rather than
  /// scripture — the 和合本's 見上節, an `OMIT`, an empty record. The row
  /// then prints why, not the instruction.
  final VerseAbsence? absence;

  /// For [VerseAbsence.merged], the verse whose text this one is printed
  /// under. Resolved per version because the merges differ by edition.
  final int? mergedWith;

  /// The psalm title this edition prints above the verse, where it ships
  /// one as its own record. Only `leb` does; the other editions that
  /// carry a superscription have it merged into verse 1's text, and it
  /// renders as part of the verse. docs/DATA-INTEGRITY.md check 31.
  final String superscription;
}

/// What the mouse is currently over, reported to the status bar and the
/// Analysis window.
///
/// The manual describes the Analysis window as showing "information
/// about the word **or verse** being examined" — so a hover has two
/// grades. Over an original-language word you get that word; over a
/// translation, whose words carry no Strong's tagging in any version we
/// ship, you get the verse. Only the originals line being live was the
/// gap: the other three lines were dead text.
class BrowseHover {
  const BrowseHover({
    required this.reference,
    required this.verse,
    this.word,
    this.grammar = const [],
    this.occurrence,
  });

  /// Which printed occurrence this is — see [browseWordKey]. Null for a
  /// verse-level hover, which names no single word and so can never be
  /// pinned.
  final String? occurrence;

  /// Null for a verse-level hover (a translation line).
  final OriginalWord? word;

  /// Grammar / TVM codes on this word, so the Analysis window can
  /// decode them instead of leaving the blue numbers unexplained.
  final List<String> grammar;

  final String reference;
  final int verse;
}

class BrowseWindow extends StatefulWidget {
  const BrowseWindow({
    super.key,
    required this.book,
    required this.chapter,
    required this.versionCodes,
    this.focusedVerse,
    this.onWordTap,
    this.onWordHover,
    this.onVerseTap,
    this.focus = AnalysisFocus.empty,
    this.highlight = const SearchHighlight(),
  });

  /// Canonical English book name, e.g. "Genesis".
  final String book;
  final int chapter;

  /// Translation codes to print, in order. The originals line is always
  /// appended last, mirroring BibleWorks' BGT/WTT placement.
  final List<String> versionCodes;

  /// Verse the workspace cursor is on — highlighted, and scrolled to.
  final int? focusedVerse;

  /// What the active search marks. Empty when nothing is searched, in
  /// which case every span renders plain and this costs nothing.
  final SearchHighlight highlight;

  /// A word was clicked. Carries the same payload as a hover — notably
  /// the tapped word's OWN verse, which the old `(word, grammar)`
  /// signature could not express: the caller had to supply a verse from
  /// its enclosing scope and supplied the workspace CURSOR verse, so
  /// clicking a word in v5 while the cursor sat on v3 filed it under v3
  /// and pointed every verse-keyed Analysis tab at the wrong verse.
  final void Function(BrowseHover hover)? onWordTap;

  /// Null is passed when the pointer leaves a word, so the status bar
  /// can clear.
  final void Function(BrowseHover? hover)? onWordHover;

  /// What the Analysis pane is looking at: the pinned occurrence, the
  /// subject occurrence, and the Strong's number whose other printed
  /// occurrences should light up. Every word in the window is drawn
  /// against this one value, which is what lets a pointer on the Greek
  /// line mark the matching word four rows down in Chinese.
  ///
  /// It arrives from above rather than being derived here because the
  /// pane and the text must never disagree about what is under study —
  /// there is one answer and both read it.
  final AnalysisFocus focus;

  final void Function(int verse)? onVerseTap;

  @override
  State<BrowseWindow> createState() => _BrowseWindowState();
}

class _BrowseWindowState extends State<BrowseWindow> {
  late Future<List<_BrowseRow>> _future;

  /// A positioned list, not a plain ListView: picking a verse from the
  /// nav strip has to SCROLL there, and row heights vary too much
  /// (a one-line KJV verse vs a wrapped originals line) to compute an
  /// offset.
  final ItemScrollController _scroll = ItemScrollController();

  /// Row index of the first line of each verse, so a jump lands on the
  /// verse's own block rather than mid-way through the previous one.
  final Map<int, int> _firstRowOfVerse = {};

  /// The verse the pane has already scrolled to. Guards against
  /// re-scrolling to where we already are — see [_scrollToFocused].
  int? _scrolledTo;

  /// Strong's number -> entry, for every original word in the chapter.
  /// Prefetched with the rows: the hover popup has to appear the instant
  /// the pointer lands, and an async lookup per word would make it
  /// arrive after the pointer has already moved on.
  final Map<String, StrongsEntry?> _glosses = {};

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  /// Load, then scroll ONCE when the rows land. Doing this here rather
  /// than in `build` is the whole point: build must have no side
  /// effects, and a scroll is about as side-effecting as it gets.
  void _startLoad() {
    _scrolledTo = null;
    _future = _load()
      ..then((_) {
        if (mounted) _scrollToFocused();
      });
  }

  @override
  void didUpdateWidget(covariant BrowseWindow old) {
    super.didUpdateWidget(old);
    // The focused verse deliberately does NOT reload: moving the cursor
    // within a chapter is a highlight change plus a scroll, not a fetch.
    if (old.book != widget.book ||
        old.chapter != widget.chapter ||
        !_sameList(old.versionCodes, widget.versionCodes)) {
      setState(_startLoad);
    } else if (old.focusedVerse != widget.focusedVerse) {
      _scrollToFocused();
    }
  }

  /// Bring the focused verse into view. Deferred a frame so it also
  /// works right after a load, when the list has not been laid out yet.
  void _scrollToFocused() {
    final v = widget.focusedVerse;
    if (v == null || v == _scrolledTo) return;
    final index = _firstRowOfVerse[v];
    if (index == null) return;
    // Record before the frame lands so a rebuild in between cannot
    // queue the same jump twice.
    _scrolledTo = v;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.isAttached) return;
      _scroll.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        // A little headroom so the verse is not flush against the
        // pane's top edge.
        alignment: 0.08,
      );
    });
  }

  static bool _sameList(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);

  /// One whole-version verse list, from the app's ONE cache.
  ///
  /// 2026-08-08 (#274): this pane used to keep its own static
  /// `_versionCache`, which meant the version the reader is already
  /// READING — parsed at boot and sitting in `MainProvider`'s LRU — was
  /// downloaded and `json.decode`d a second time just to print it here,
  /// on the workbench's very first paint. It also made the pane immune
  /// to `dropCachesOnMemoryPressure`, so iOS could ask for memory back
  /// and get none. `MainProvider` owns the cache; this asks it.
  static Future<List<Verse>?> _versionVerses(
      String code, MainProvider mp) async {
    final cached = mp.peekCachedVersion(code);
    if (cached != null) return cached;
    await mp.preloadVersion(code);
    return mp.peekCachedVersion(code);
  }

  Future<List<_BrowseRow>> _load() async {
    final locale = context.read<AppSettings>().locale;
    // Read before the first await: `context` is not safe to touch once
    // this has yielded.
    final mp = context.read<MainProvider>();

    // Fetch every version AT ONCE. Awaiting them one at a time meant a
    // cold Browse window parsed three whole-Bible JSONs in series and
    // took ~30s to first paint; in parallel it costs roughly the slowest
    // one. (They are cached process-wide afterwards, so this only bites
    // on the first chapter of a session.)
    final loaded =
        await Future.wait(widget.versionCodes.map((c) => _versionVerses(c, mp)));

    // version code -> {verse number: text}, plus the chapter's extent.
    final byVersion = <String, Map<int, String>>{};
    // version code -> {verse number: the number the publisher PRINTS},
    // which is `1-4` where two or more verses share a block. Kept
    // separate from the text because it answers a different question.
    final labels = <String, Map<int, String>>{};
    // version code -> {verse number: the psalm title printed above it}.
    final supers = <String, Map<int, String>>{};
    var lastVerse = 0;
    for (var i = 0; i < widget.versionCodes.length; i++) {
      final verses = loaded[i];
      if (verses == null) continue;
      final map = <int, String>{};
      final label = <int, String>{};
      final title = <int, String>{};
      for (final v in verses) {
        if (v.chapter != widget.chapter) continue;
        if ((bookNameToEnglish[v.book] ?? v.book) != widget.book) continue;
        map[v.verse] = v.text;
        label[v.verse] = v.verseLabel;
        if (v.superscription.isNotEmpty) title[v.verse] = v.superscription;
        if (v.verse > lastVerse) lastVerse = v.verse;
      }
      if (map.isNotEmpty) {
        byVersion[widget.versionCodes[i]] = map;
        labels[widget.versionCodes[i]] = label;
        supers[widget.versionCodes[i]] = title;
      }
    }
    if (lastVerse == 0) return const [];

    // Which of this chapter's references are printed under an earlier
    // verse's number, per edition — the merges differ between editions,
    // and resolving the head needs the whole chapter (they chain).
    final mergedHeads = <String, Map<int, int>>{
      for (final e in byVersion.entries) e.key: mergedVerseHeads(e.value),
    };

    // Which of this chapter's references each edition does not have at
    // all. Only editions that carry some of the chapter appear here, so
    // an edition that stops before this book keeps its column silent.
    final absentVerses = <String, Set<int>>{
      for (final e in byVersion.entries)
        e.key: absentVerseNumbers(e.value, lastVerse),
    };

    // Three things an absent reference can be, beyond "we have no
    // verse", each read off evidence already in the repository rather
    // than a list written by hand.
    //
    // The publisher's own range label answers the first: 路加福音 1:1
    // is marked `1-4`, so 1:2-1:4 are printed, under a number the
    // reader can see. The critical-text table answers the second: the
    // seventeen references no original-language file has words for. The
    // same table answers the third from its other half — where two
    // reader verses render ONE original verse, an edition following the
    // original prints them together. Between them they account for 113
    // of the corpus's 424 absences. docs/DATA-INTEGRITY.md check 30.
    final rangeHeads = <String, Map<int, int>>{
      for (final e in labels.entries) e.key: rangeLabelHeads(e.value),
    };
    final versification = await Versification.load();
    List<String> originalKeysOf(int verse) =>
        versification.originalKeys(widget.book, widget.chapter, verse);
    final sharedHeads = <String, Map<int, int>>{
      for (final e in absentVerses.entries)
        e.key: sharedOriginalHeads(
          e.value
              .where((n) => !versification.isAbsentFromOriginal(
                  widget.book, widget.chapter, n))
              .toSet(),
          // Only a verse that carries WORDS can be named as the place
          // another verse is printed — the same rule mergedVerseHeads
          // follows. A 見上節 or an OMIT is a record, not a text.
          {
            for (final v in byVersion[e.key]!.entries)
              if (verseAbsenceOf(v.value) == null) v.key,
          },
          originalKeysOf,
        ),
    };

    // One call warms the whole book's originals; the per-verse lookups
    // below then hit the cache instead of re-reading the asset.
    await OriginalsService.forVerse(widget.book, widget.chapter, 1);

    final rows = <_BrowseRow>[];
    _firstRowOfVerse.clear();
    for (var n = 1; n <= lastVerse; n++) {
      var first = true;
      _firstRowOfVerse[n] = rows.length;
      final reference =
          '${localeAwareBookName(widget.book, locale, widget.versionCodes.isEmpty ? '' : widget.versionCodes.first)} '
          '${widget.chapter}:$n';

      for (final code in widget.versionCodes) {
        final text = byVersion[code]?[n];
        // 2026-08-12: a reference the edition does not have used to
        // render as NOTHING — the row was simply not emitted, so the
        // Septuagint's 68 missing verses in Jeremiah, the BSB's sixteen
        // Received-Text verses, 426 references in all, looked like a
        // column that happened to be short. BibleWorks inserts a blank
        // verse for exactly this and says to leave that setting on; we
        // can do better than blank and say why the row is empty.
        // docs/DATA-INTEGRITY.md check 29.
        final isAbsent = absentVerses[code]?.contains(n) ?? false;
        if (text == null && !isAbsent) continue;
        int? absentHead;
        if (isAbsent) {
          absentHead = rangeHeads[code]?[n] ?? sharedHeads[code]?[n];
        }
        final VerseAbsence? absence;
        if (!isAbsent) {
          absence = verseAbsenceOf(text!);
        } else if (absentHead != null) {
          absence = VerseAbsence.merged;
        } else if (versification.isAbsentFromOriginal(
            widget.book, widget.chapter, n)) {
          absence = VerseAbsence.notInCriticalText;
        } else {
          absence = VerseAbsence.absent;
        }
        // A reference with no scripture has nothing to tag, so skip the
        // tagged/gloss lookup entirely rather than render the marker as
        // a word run.
        final runs = absence != null
            ? null
            : await TaggedTextService.forVerse(
                version: code,
                englishBook: widget.book,
                chapter: widget.chapter,
                verse: n,
              );
        if (runs != null) {
          for (final r in runs) {
            if (r.strongs.isNotEmpty && !_glosses.containsKey(r.strongs)) {
              _glosses[r.strongs] = await StrongsService.lookup(r.strongs);
            }
          }
        }
        rows.add(_BrowseRow(
          verse: n,
          code: code,
          reference: reference,
          firstOfVerse: first,
          text: text,
          runs: runs,
          absence: absence,
          mergedWith: absentHead ?? mergedHeads[code]?[n],
          superscription: supers[code]?[n] ?? '',
        ));
        first = false;
      }

      final words =
          await OriginalsService.forVerse(widget.book, widget.chapter, n);
      if (words != null && words.isNotEmpty) {
        for (final w in words) {
          if (w.strongs.isNotEmpty && !_glosses.containsKey(w.strongs)) {
            _glosses[w.strongs] = await StrongsService.lookup(w.strongs);
          }
        }
        final isHebrew = words.first.strongs.startsWith('H');
        rows.add(_BrowseRow(
          verse: n,
          code: isHebrew ? 'wtt' : 'bgt',
          reference: reference,
          firstOfVerse: first,
          words: words,
          rtl: isHebrew,
        ));
      }
    }
    return rows;
  }

  /// What the pane is actually waiting for, named.
  ///
  /// The editions still absent from the corpus cache are the honest
  /// answer while any are missing — on a cold cache that is several
  /// megabytes each and the reason the column is empty. Once they are
  /// all in, the remaining wait is the chapter's tagging and originals,
  /// which is a different (and much shorter) sentence.
  String _loadingLabel(BuildContext context) {
    final locale = context.read<AppSettings>().locale;
    final mp = context.read<MainProvider>();
    final missing = widget.versionCodes
        .where((c) => mp.peekCachedVersion(c) == null)
        .map(shortBibleVersionLabel)
        .toList();
    if (missing.isEmpty) {
      return uiStrings['wbBrowseLoadingChapter']?[locale] ??
          'Preparing this chapter';
    }
    final lead = uiStrings['wbBrowseLoadingVersions']?[locale] ??
        'Loading editions';
    return '$lead · ${missing.join(" · ")}';
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return FutureBuilder<List<_BrowseRow>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: wb.paneBg,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  _loadingLabel(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: WbMetrics.text, color: wb.mutedText),
                ),
              ],
            ),
          );
        }
        // Surface a load failure instead of rendering nothing. A blank
        // pane gives the reader no idea whether the chapter is empty,
        // still loading, or broken.
        if (snap.hasError) {
          return Container(
            color: wb.paneBg,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Could not load this chapter.\n${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: t.text, color: wb.mutedText),
              ),
            ),
          );
        }
        final rows = snap.data ?? const <_BrowseRow>[];
        if (rows.isEmpty) {
          return Container(
            color: wb.paneBg,
            alignment: Alignment.center,
            child: Text(
              'No text for this chapter.',
              style: TextStyle(
                  fontSize: t.text, color: wb.mutedText),
            ),
          );
        }
        // One gutter for the chapter, sized to the editions on screen —
        // not to the catalog, and not to whatever this row happens to
        // print. Cheap enough to recompute per build (a handful of short
        // strings) and it has to be, because `t.chrome` follows the
        // reader's font-size slider.
        final gutterWidth = versionGutterWidth(
          {for (final r in rows) r.code},
          t.chrome - 0.5,
        );
        return Container(
          color: wb.paneBg,
          child: ScrollablePositionedList.builder(
              itemScrollController: _scroll,
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              itemBuilder: (context, i) => _RowView(
                row: rows[i],
                gutterWidth: gutterWidth,
                focused: rows[i].verse == widget.focusedVerse,
                highlight: widget.highlight,
                glosses: _glosses,
                keyPrefix: browseKeyPrefix(widget.book, widget.chapter),
                focus: widget.focus,
                onWordTap: widget.onWordTap,
                onWordHover: widget.onWordHover,
                onTap: widget.onVerseTap == null
                    ? null
                    : () => widget.onVerseTap!(rows[i].verse),
              ),
          ),
        );
      },
    );
  }
}

// ── One printed line ────────────────────────────────────────────────

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.focused,
    required this.glosses,
    required this.keyPrefix,
    required this.gutterWidth,
    this.focus = AnalysisFocus.empty,
    this.onWordTap,
    this.onWordHover,
    this.onTap,
    this.highlight = const SearchHighlight(),
  });

  final _BrowseRow row;
  final bool focused;
  final SearchHighlight highlight;
  final Map<String, StrongsEntry?> glosses;

  /// One width shared by every row in the chapter, so the verse text of
  /// all editions starts on the same x. Computed once from the editions
  /// actually on screen — a reader comparing four Chinese texts gets a
  /// two-character gutter and does not pay for `LXX+WH` existing.
  final double gutterWidth;

  /// "Genesis|1" — the book and chapter half of every [browseWordKey]
  /// this row hands out.
  final String keyPrefix;
  final AnalysisFocus focus;
  final void Function(BrowseHover hover)? onWordTap;
  final void Function(BrowseHover? hover)? onWordHover;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final settings = context.watch<AppSettings>();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: focused ? wb.selectionBg : null,
          border: row.firstOfVerse
              ? Border(top: BorderSide(color: wb.border.withValues(alpha: 0.55)))
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: WbMetrics.rowPadH,
          vertical: WbMetrics.rowPadV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WbVersionTag(code: row.code, width: gutterWidth),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Above the line, in this edition's column only — the
                  // other editions print their title inside verse 1.
                  if (row.superscription.isNotEmpty)
                    _SuperscriptionLine(
                        text: row.superscription, settings: settings),
                  row.words != null
                  ? _OriginalsLine(
                      row: row,
                      glosses: glosses,
                      keyPrefix: keyPrefix,
                      focus: focus,
                      showNumbers: settings.showStrongsInOriginals,
                      onWordTap: onWordTap,
                      onWordHover: onWordHover,
                    )
                  : row.runs != null
                      // Tagged translation: every run is its own hover
                      // target, exactly like the originals line.
                      ? _TaggedLine(
                          row: row,
                          highlight: highlight,
                          glosses: glosses,
                          keyPrefix: keyPrefix,
                          focus: focus,
                          showNumbers: settings.showStrongsInOriginals,
                          onWordTap: onWordTap,
                          onWordHover: onWordHover,
                        )
                      // Untagged translation reports the VERSE. Guessing
                      // which original word an untagged word renders
                      // would be a heuristic dressed as fact.
                      : MouseRegion(
                          onEnter: (_) => onWordHover?.call(BrowseHover(
                            reference: row.reference,
                            verse: row.verse,
                          )),
                          child:
                              _TranslationLine(
                                  row: row,
                                  settings: settings,
                                  highlight: highlight),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslationLine extends StatelessWidget {
  const _TranslationLine({
    required this.row,
    required this.settings,
    required this.highlight,
  });

  final _BrowseRow row;
  final AppSettings settings;
  final SearchHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    // 2026-08-06: the Browse pane ignored Settings > Font Size entirely
    // — every size here was a hardcoded WbMetrics constant, so the
    // slider moved and nothing happened. The workbench is deliberately
    // denser than the reader, so it scales RELATIVE to the reader's
    // setting (20 is the default) rather than adopting it outright.
    // Reference then text on one line, exactly as BibleWorks prints it —
    // the reference repeated on every version row is what lets you read
    // a single translation straight down the column.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${row.reference}  ',
            style: TextStyle(
              color: wb.link,
              fontWeight: FontWeight.w600,
            ),
          ),
          // 2026-08-06: publisher markup used to print raw here —
          // `Now<note: Or "And"> the earth … darkness [was] over` in
          // 48% of LEB. Notes leave the flow for a marker; supplied
          // words stay, set in italic like a printed Bible.
          if (row.absence != null)
            TextSpan(
              text: verseAbsenceNote(row.absence!, settings.locale,
                  mergedWith: row.mergedWith),
              style: TextStyle(
                color: wb.mutedText,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...[
            for (final span in parseScripture(row.text ?? ''))
              switch (span.kind) {
                // A plain span is where a text-query hit can live, so it
                // is split again on the search terms. Strong's queries
                // mark the tagged runs instead (see _HoverWord).
                ScriptureSpanKind.plain => TextSpan(
                    children: [
                      for (final h
                          in splitOnTerms(span.text, highlight.textTerms))
                        TextSpan(
                          text: h.text,
                          style: TextStyle(
                            color: wb.text,
                            backgroundColor:
                                h.isHit ? wb.selectionBg : null,
                            fontWeight: h.isHit ? FontWeight.w700 : null,
                          ),
                        ),
                    ],
                  ),
                ScriptureSpanKind.supplied => TextSpan(
                    text: span.text,
                    style: TextStyle(
                      color: wb.text,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ScriptureSpanKind.divineName ||
                ScriptureSpanKind.gloss =>
                  glossSpan(span, wb),
                ScriptureSpanKind.versification =>
                  versificationSpan(span, wb, fontSize: t.text * 0.8),
                ScriptureSpanKind.note => WidgetSpan(
                    alignment: PlaceholderAlignment.top,
                    child: Tooltip(
                      message: span.text,
                      triggerMode: TooltipTriggerMode.tap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Text(
                          'n',
                          style: TextStyle(
                            fontSize: t.chrome * 0.85,
                            fontWeight: FontWeight.w700,
                            color: wb.link,
                          ),
                        ),
                      ),
                    ),
                  ),
              },
          ],
        ],
      ),
      style: TextStyle(
        fontSize: t.text,
        height: t.lineHeight,
        fontFamily: t.fontFamily,
        fontFamilyFallback: kCjkFontFallback,
      ),
    );
  }
}

/// 2026-08-12 (docs/DATA-INTEGRITY.md check 31): the psalm title an
/// edition prints above verse 1. Its own line above the verse rather
/// than a row of its own: no other edition has a reference there, so a
/// row would print "this edition does not carry this verse" in every
/// other column for something three of them do carry, merged into
/// their verse 1.
class _SuperscriptionLine extends StatelessWidget {
  const _SuperscriptionLine({required this.text, required this.settings});

  final String text;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Text.rich(
      TextSpan(
        children: [
          for (final span in parseScripture(text))
            switch (span.kind) {
              ScriptureSpanKind.note => WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Tooltip(
                    message: span.text,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Text(
                        'n',
                        style: TextStyle(
                          fontSize: t.chrome * 0.85,
                          fontWeight: FontWeight.w700,
                          color: wb.link,
                        ),
                      ),
                    ),
                  ),
                ),
              ScriptureSpanKind.divineName ||
              ScriptureSpanKind.gloss =>
                glossSpan(span, wb),
              ScriptureSpanKind.versification =>
                versificationSpan(span, wb, fontSize: t.text * 0.8),
              _ => TextSpan(text: span.text),
            },
        ],
      ),
      style: TextStyle(
        fontSize: t.text * 0.92,
        height: t.lineHeight,
        fontFamily: t.fontFamily,
        fontFamilyFallback: kCjkFontFallback,
        fontStyle: FontStyle.italic,
        color: wb.mutedText,
      ),
    );
  }
}

/// A Strong's-tagged translation line: the reference, then the verse
/// text broken into runs that each carry an original-language word.
/// Reads as ordinary prose; hovers like an interlinear.
class _TaggedLine extends StatelessWidget {
  const _TaggedLine({
    required this.row,
    required this.glosses,
    required this.keyPrefix,
    required this.focus,
    required this.showNumbers,
    this.highlight = const SearchHighlight(),
    this.onWordTap,
    this.onWordHover,
  });

  final SearchHighlight highlight;

  final _BrowseRow row;
  final Map<String, StrongsEntry?> glosses;
  final String keyPrefix;
  final AnalysisFocus focus;
  final bool showNumbers;
  final void Function(BrowseHover hover)? onWordTap;
  final void Function(BrowseHover? hover)? onWordHover;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final runs = row.runs ?? const <TaggedRun>[];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            row.reference,
            style: TextStyle(
              fontSize: t.text,
              height: t.lineHeight,
              fontWeight: FontWeight.w600,
              color: wb.link,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            children: [
              for (final (i, r) in runs.indexed)
                if (r.isTagged)
                  _HoverWord(
                    // A Strong's query marks the word carrying the
                    // number — the tagging already knows which one.
                    hit: highlight.matchesStrongs(r.strongs),
                    // Reuse the originals hover target: same behaviour,
                    // same popup, only the script differs.
                    word: OriginalWord(text: r.text, strongs: r.strongs),
                    reference: row.reference,
                    verse: row.verse,
                    occurrence: browseWordKey(
                      prefix: keyPrefix,
                      versionCode: row.code,
                      verse: row.verse,
                      index: i,
                    ),
                    focus: focus,
                    entry: glosses[r.strongs],
                    grammar: r.grammar,
                    implied: r.implied,
                    showNumbers: showNumbers,
                    translation: true,
                    onTap: onWordTap,
                    onHover: onWordHover,
                  )
                else
                  Text.rich(
                    TextSpan(children: [
                      for (final span in parseScripture(r.text))
                        if (span.kind == ScriptureSpanKind.divineName ||
                            span.kind == ScriptureSpanKind.gloss)
                          glossSpan(span, wb)
                        else if (span.kind ==
                            ScriptureSpanKind.versification)
                          versificationSpan(span, wb,
                              fontSize: t.text * 0.8)
                        else
                          TextSpan(
                            text: span.text,
                            style: span.kind == ScriptureSpanKind.supplied
                                ? const TextStyle(fontStyle: FontStyle.italic)
                                : null,
                          ),
                    ]),
                    style: TextStyle(
                      fontSize: t.text,
                      height: t.lineHeight,
                      color: wb.text,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The originals line. Every word is its own hover/tap target, which is
/// what makes mouse-over analysis possible.
class _OriginalsLine extends StatelessWidget {
  const _OriginalsLine({
    required this.row,
    required this.glosses,
    required this.keyPrefix,
    required this.focus,
    required this.showNumbers,
    this.onWordTap,
    this.onWordHover,
  });

  final _BrowseRow row;
  final Map<String, StrongsEntry?> glosses;
  final String keyPrefix;
  final AnalysisFocus focus;
  final bool showNumbers;
  final void Function(BrowseHover hover)? onWordTap;
  final void Function(BrowseHover? hover)? onWordHover;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final words = row.words ?? const <OriginalWord>[];
    // The reference sits OUTSIDE the RTL scope. Inside it, being the
    // first child put it at the right-hand end of a Hebrew line, so the
    // column of references no longer lined up down the page.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            row.reference,
            style: TextStyle(
              fontSize: t.text,
              height: t.lineHeight,
              fontWeight: FontWeight.w600,
              color: wb.link,
            ),
          ),
        ),
        Expanded(
          child: Directionality(
            textDirection: row.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Wrap(
              spacing: 5,
              runSpacing: 1,
              children: [
                for (final (i, w) in words.indexed)
                  _HoverWord(
                    word: w,
                    reference: row.reference,
                    verse: row.verse,
                    occurrence: browseWordKey(
                      prefix: keyPrefix,
                      versionCode: row.code,
                      verse: row.verse,
                      index: i,
                    ),
                    focus: focus,
                    entry: glosses[w.strongs],
                    showNumbers: showNumbers,
                    onTap: onWordTap,
                    onHover: onWordHover,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HoverWord extends StatefulWidget {
  const _HoverWord({
    required this.word,
    required this.reference,
    required this.verse,
    required this.entry,
    required this.occurrence,
    required this.focus,
    this.grammar = const [],
    this.implied = const [],
    this.showNumbers = false,
    this.translation = false,
    this.hit = false,
    this.onTap,
    this.onHover,
  });

  /// True when the active search marks this word.
  final bool hit;

  final OriginalWord word;
  final String reference;
  final int verse;

  /// This word's stable identity — see [browseWordKey].
  final String occurrence;

  /// What the whole window is looking at — the pin, the subject, and the
  /// Strong's number being echoed. Threaded down rather than held here
  /// because a word has to know about a pointer that is nowhere near it:
  /// that is the difference between marking the word you are on and
  /// marking the same original word in every translation on screen.
  final AnalysisFocus focus;

  /// Prefetched lexicon entry, used to build the hover popup. Null when
  /// the number is missing from the lexicon — the popup then shows just
  /// the word and its number rather than nothing.
  final StrongsEntry? entry;

  /// Grammar codes carried by a tagged translation run.
  final List<String> grammar;

  /// Numbers the original carries that this word does not render — the
  /// Hebrew object marker, the Greek article. Printed parenthesised, as
  /// yahwehdehua.net prints them, so they read as context rather than as
  /// this word's identity.
  final List<String> implied;

  /// Print the Strong's numbers inline after the word. Off, the line is
  /// ordinary prose; on, it is an interlinear you can still read.
  final bool showNumbers;

  /// Translation text renders at body size in the body colour; only the
  /// originals line gets the larger original-script treatment.
  final bool translation;
  final void Function(BrowseHover hover)? onTap;
  final void Function(BrowseHover? hover)? onHover;

  @override
  State<_HoverWord> createState() => _HoverWordState();
}

class _HoverWordState extends State<_HoverWord> {
  bool _hovering = false;

  BrowseHover _asHover() => BrowseHover(
        word: widget.word,
        reference: widget.reference,
        verse: widget.verse,
        grammar: widget.grammar,
        occurrence: widget.occurrence,
      );

  /// The popup BibleWorks shows beside the cursor: Strong's number, the
  /// word itself in the accent colour, its transliteration, then the
  /// gloss — and, since we have it, the parsing. This is the whole
  /// reason its Browse window can be *read* with the mouse: you never
  /// leave the text to find out what a word is.
  InlineSpan _popup(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final locale = context.read<AppSettings>().locale;
    final e = widget.entry;
    final gloss = e?.localizedGloss(locale) ?? '';
    final parse = describeMorphology(widget.word.morph, locale);

    TextStyle base(Color c, {FontWeight? w, double? size}) => TextStyle(
          fontSize: size ?? t.chrome,
          height: 1.4,
          fontWeight: w,
          color: c,
        );

    return TextSpan(children: [
      TextSpan(
        text: '${widget.word.strongs}  ',
        style: base(wb.mutedText),
      ),
      TextSpan(
        text: widget.word.text,
        // Red, as BibleWorks prints the headword.
        style: base(const Color(0xFFB3261E),
            w: FontWeight.w600, size: t.original),
      ),
      if ((e?.translit ?? '').isNotEmpty)
        TextSpan(
          text: '  (${e!.translit})',
          style: base(wb.mutedText).copyWith(fontStyle: FontStyle.italic),
        ),
      if (gloss.isNotEmpty)
        TextSpan(text: '\n$gloss', style: base(wb.text, w: FontWeight.w600)),
      if (parse != null && parse.isNotEmpty)
        TextSpan(text: '\n$parse', style: base(wb.mutedText)),
    ]);
  }

  bool get _hasNumbers =>
      widget.word.strongs.isNotEmpty ||
      widget.grammar.isNotEmpty ||
      widget.implied.isNotEmpty;

  /// One inline number, set small and raised — a superscript in all but
  /// name. Flutter has no baseline-shift, so the size drop plus the hue
  /// is what keeps it from reading as part of the sentence.
  InlineSpan _num(String text, Color color) => TextSpan(
        text: ' $text',
        style: TextStyle(
          // Resolved here rather than passed down: _num is called from
          // a span builder, not from build().
          fontSize: WbType.of(context).chrome - 2,
          color: color,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    // The pointer's own position wins over the threaded subject, so a
    // word still lights under the mouse while the pane is held by a pin
    // or by Shift. Everywhere else the threaded subject stands, which is
    // what stops the mark blinking as the pointer crosses the gap
    // between two words.
    final focus = _hovering
        ? widget.focus.withHover(widget.occurrence)
        : widget.focus;
    final mark = focus.markFor(
      widget.occurrence,
      strongs: widget.word.strongs,
      hit: widget.hit,
    );
    return Tooltip(
      richMessage: _popup(context),
      // A pale bordered box, not Material's dark rounded bubble.
      decoration: BoxDecoration(
        color: wb.paneBg,
        border: Border.all(color: wb.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      margin: const EdgeInsets.only(left: 4),
      // Fast enough to feel like a readout, slow enough not to strobe
      // while the pointer crosses a line of text.
      waitDuration: const Duration(milliseconds: 180),
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hovering = true);
          widget.onHover?.call(_asHover());
        },
        onExit: (_) {
          setState(() => _hovering = false);
          widget.onHover?.call(null);
        },
        child: GestureDetector(
          onTap: widget.onTap == null
              ? null
              : () => widget.onTap!(_asHover()),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: wordMarkDecoration(mark, wb),
            child: Text.rich(
              TextSpan(children: [
                // 2026-08-06: a tagged run can itself be a supplied
                // word — BSB prints `[was]`, `[He]`. Set those in
                // italic like a printed Bible instead of leaving the
                // brackets to read as punctuation.
                // 2026-08-07: and it can be a referent gloss instead —
                // `主[雅伟]` is ONE tagged run once the halves are put
                // back together, and it is κύριος, so this is the word
                // a Strong's search on G2962 marks as its hit.
                for (final span in parseScripture(widget.word.text))
                  if (span.kind == ScriptureSpanKind.divineName ||
                      span.kind == ScriptureSpanKind.gloss)
                    glossSpan(
                      span,
                      wb,
                      style: TextStyle(
                        fontWeight: widget.hit ? FontWeight.w700 : null,
                      ),
                    )
                  else
                    TextSpan(
                      text: span.text,
                      style: TextStyle(
                        fontStyle: span.kind == ScriptureSpanKind.supplied
                            ? FontStyle.italic
                            : null,
                        fontWeight: widget.hit ? FontWeight.w700 : null,
                      ),
                    ),
                if (widget.showNumbers) ...[
                  for (final t in inlineStrongsNumbers(
                    strongs: widget.word.strongs,
                    grammar: widget.grammar,
                    implied: widget.implied,
                  ))
                    _num(t.text, switch (t.kind) {
                      StrongsNumberKind.lexical => wb.strongsLexical,
                      StrongsNumberKind.grammar => wb.strongsGrammar,
                      StrongsNumberKind.implied =>
                        wb.strongsLexical.withValues(alpha: 0.6),
                    }),
                  // Chinese has no inter-word space, so without this the
                  // number collides with the next character: 亚伯拉罕G11的.
                  // The originals line does not need it — its own script
                  // is already space-separated.
                  if (widget.translation && _hasNumbers)
                    const TextSpan(text: ' '),
                ],
              ]),
              style: TextStyle(
                // The doc on [translation] promises body size for a
                // translation run; only the originals line gets the
                // larger original-script treatment.
                fontSize: widget.translation
                    ? t.text
                    : t.original,
                height: t.lineHeight,
                color: wb.text,
                fontFamilyFallback: kCjkFontFallback,
                // Underline on hover, so touch users (who get no hover)
                // and mouse users both see that words are live. The pin
                // keeps it: a pinned word is the one the reader is
                // working on and must not look deader than the one
                // their pointer happens to be crossing. An echo does
                // not — see [wordMarkUnderline].
                decoration: wordMarkUnderline(mark),
                decorationColor:
                    mark == WordMark.pinned ? wb.pinMark : wb.link,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
