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
import 'package:seeksparks/utils/ketiv_qere.dart'
    show ketivQereLabel, ketivQereMark, ketivQereNote;
import 'package:seeksparks/utils/morphology.dart' show describeMorphology;
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/strongs_inline.dart';
import 'package:seeksparks/utils/verse_text_absence.dart';
import 'package:seeksparks/utils/version_gutter.dart'
    show referenceGutterWidth, versionGutterWidth;
import 'package:seeksparks/utils/version_diff.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/workbench_chrome.dart' show WbVersionTag;

/// The one word gap in the Browse pane.
///
/// Two of the three render paths are `Wrap`s of individual words, and
/// until 2026-08-17 they disagreed: the originals set `spacing: 5`, the
/// tagged translation set nothing at all. The gap is named once here,
/// and it stays applied to the originals ONLY — which looks like the
/// inconsistency this pass was cleaning up, so here is the measurement
/// that says it is not.
///
/// An originals token is bare: **0 of 438,821** words in
/// `assets/originals/` carry any whitespace of their own, so without a
/// gap the Hebrew and the Greek would run together. Every tagged
/// edition, by contrast, already carries its own spacing IN THE DATA —
/// but by three different conventions, which is why the tempting
/// one-line summary ("tagged runs end in a space") is false. Share of
/// runs carrying a leading or trailing space, whole corpus:
///
///   `bsb`       91.57%  — TRAILING          (`"Adam, "`)
///   `kjvs`      68.53%  — LEADING           (`", Sheth"`)
///   `lxxwh`     94.28%  — mixed, both
///   `cuvs-plus`  0.00%  — Chinese does not put spaces between words
///   `cuvs-yhwh`  0.05%    at all, so a gap would open a hole in the
///                         middle of 亚当生塞特
///
/// So the rule is "add a gap where the text has none of its own", and
/// the tagged path is the one that must NOT get it: the same 5px would
/// double-space the BSB, mis-space the KJV, and break Chinese outright.
/// Do not "harmonise" these two numbers by making them equal.
const double kBrowseWordGap = 5.0;

/// Wrapped lines take their rhythm from `WbType.lineHeight` alone.
///
/// The originals `Wrap` used to add 1px of `runSpacing` on top of it,
/// so an originals verse that wrapped to three lines stood a little
/// taller than a translation of the same verse beside it — and the
/// untagged path, being an ordinary text flow, has no `runSpacing` to
/// set at all. Nothing but the line height, in all three.
const double kBrowseRunSpacing = 0.0;

/// The tracking the reference column is both MEASURED and PAINTED with.
///
/// It has to be one named number in both places. A `Text` merges its
/// style onto the ambient `DefaultTextStyle`, and under a `Scaffold`
/// that is `bodyMedium` — which carries `letterSpacing: 0.25`. The
/// reference style never set the field, so it inherited that 0.25 while
/// [referenceGutterWidth] modelled the column with none: the painted
/// string ran `runes.length * 0.25` px wider than the width computed
/// for it. Naming the constant and passing it to both sides makes them
/// the same number by construction rather than by luck.
const double kBrowseReferenceLetterSpacing = 0.25;

/// One printed line: a translation of a verse, or its originals line.
class _BrowseRow {
  _BrowseRow({
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

  /// bwh30 difference highlighting: this row's tokens, and which of them
  /// are worded differently from the base edition of its language group.
  ///
  /// Computed at LOAD, not at paint, and computed whether or not the
  /// toggle is on. That is what makes the toggle instant — flipping it
  /// repaints, it does not refetch a chapter — and it is why the pane's
  /// widget key deliberately does not mention the flag.
  ///
  /// Written once, immediately after the verse's rows are built, and
  /// never again; the fields are mutable only because a row cannot know
  /// its neighbours until they exist.
  List<VersionDiffToken> diffTokens = const [];
  Set<int> diffMarks = const {};

  /// The drawn units holding at least one marked token. The tagged path
  /// marks whole runs — a run IS a word there — so this is all it needs.
  Set<int> diffUnits = const {};
}

/// The strings the diff walks for one row, in the exact order the row
/// will be DRAWN from.
///
/// This is the load-bearing part of the whole feature. The comparison
/// and the paint traverse the same list in the same order, so a token
/// index cannot mean one word here and a different word on screen. An
/// untagged row's unit is a `parseScripture` span; a tagged row's unit
/// is a run.
///
/// Notes and versification markers become EMPTY units rather than being
/// dropped, so the indices still line up with the renderer's walk. They
/// are emptied rather than compared because neither is scripture: a
/// footnote is the publisher talking, and `(102:12)` is the edition's
/// own numbering. Comparing either would report a difference in
/// apparatus as a difference in translation.
///
/// Supplied words, the divine name and referent glosses ARE compared.
/// They are printed, the reader reads them, and `主[雅伟]` against a
/// bare 主 is precisely the difference this feature exists to show.
List<String> _diffUnitsOf(_BrowseRow row) {
  if (row.absence != null) return const [];
  final runs = row.runs;
  if (runs != null) return [for (final r in runs) _readableText(r.text)];
  final text = row.text;
  if (text == null) return const [];
  return [
    for (final s in parseScripture(text))
      if (s.kind == ScriptureSpanKind.note ||
          s.kind == ScriptureSpanKind.versification)
        ''
      else
        s.text,
  ];
}

String _readableText(String raw) {
  final b = StringBuffer();
  for (final s in parseScripture(raw)) {
    if (s.kind == ScriptureSpanKind.note ||
        s.kind == ScriptureSpanKind.versification) {
      continue;
    }
    b.write(s.text);
  }
  return b.toString();
}

/// Fill in [_BrowseRow.diffMarks] for one verse's translation rows.
///
/// [groups] is [comparableVersionGroups]' answer for the whole stack;
/// each group is compared separately, so Greek is never diffed against
/// English and 简体 is never diffed against 繁體.
///
/// A row the edition does not carry drops out of its group for THIS
/// verse only. That matters: the Septuagint's absences and the BSB's
/// sixteen Received-Text verses would otherwise diff a verse against a
/// row that says "this edition does not have this verse", and every word
/// of the base would come back marked. Where the drop-out leaves fewer
/// than two rows there is nothing to compare and nothing is marked.
void _markDifferences(
  List<_BrowseRow> verseRows,
  Map<String, List<String>> groups,
) {
  if (groups.isEmpty) return;
  for (final codes in groups.values) {
    final members = [
      for (final r in verseRows)
        if (codes.contains(r.code) && r.absence == null) r,
    ];
    if (members.length < 2) continue;
    final tokens = [for (final r in members) versionDiffTokens(_diffUnitsOf(r))];
    final marks = versionDiffMarks([
      for (final t in tokens) [for (final x in t) x.norm],
    ]);
    for (final (i, r) in members.indexed) {
      r.diffTokens = tokens[i];
      r.diffMarks = marks[i];
      r.diffUnits = {for (final j in marks[i]) tokens[i][j].unit};
    }
  }
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
    this.showDiff = false,
  });

  /// Paint the bwh30 version-difference marks. Only the PAINT: the marks
  /// themselves are computed with the chapter either way, so this toggles
  /// in a frame and does not reload anything.
  final bool showDiff;

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
    // than a list written by hand. A fourth, below, IS a list, because
    // no evidence in the repository can derive it.
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
    // Which editions on screen can be compared with which, by language.
    // Empty for a stack of one edition per language, and for the `wtt` /
    // `bgt` rows, which the catalog does not know — see
    // [comparableVersionGroups].
    final diffGroups = comparableVersionGroups(widget.versionCodes);
    _firstRowOfVerse.clear();
    for (var n = 1; n <= lastVerse; n++) {
      var first = true;
      final verseStart = rows.length;
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
        // The fourth explanation, and the only one that is a list: the
        // Septuagint prints seven English references inside an earlier
        // Greek record, and nothing in the numbering says so — the
        // Greek runs in its own frame, which is neither the reader's
        // nor the original's. docs/DATA-INTEGRITY.md check 39.
        var editionMerged = false;
        if (isAbsent) {
          editionMerged =
              isEditionMerged(code, widget.book, widget.chapter, n);
          absentHead = rangeHeads[code]?[n] ??
              sharedHeads[code]?[n] ??
              editionMergedHeadVerse(code, widget.book, widget.chapter, n);
        }
        final VerseAbsence? absence;
        if (!isAbsent) {
          absence = verseAbsenceOf(text!);
        } else if (absentHead != null || editionMerged) {
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

      // Before the originals row is appended, because the originals are
      // not a comparable edition and must not be swept into a group.
      _markDifferences(rows.sublist(verseStart), diffGroups);

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
                  style: TextStyle(fontSize: t.text, color: wb.mutedText),
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
        // And one reference column, on the same terms and for the same
        // reason. A chapter's references are one book name and a run of
        // verse numbers, so this is a set of at most ~176 short strings
        // — and it has to be recomputed per build too, because `t.text`
        // follows the same font-size slider.
        final referenceWidth = referenceGutterWidth(
          {for (final r in rows) r.reference},
          t.text,
          letterSpacing: kBrowseReferenceLetterSpacing,
        );
        final groups = comparableVersionGroups(widget.versionCodes);
        return Container(
          color: wb.paneBg,
          child: Column(
            children: [
              // Above the text, not below it: the legend names the base
              // edition, and a reader who does not know which row the
              // marks are measured against cannot read the marks at all.
              if (widget.showDiff && groups.isNotEmpty)
                _DiffLegend(bases: [
                  for (final codes in groups.values) codes.first,
                ]),
              Expanded(
                child: ScrollablePositionedList.builder(
                    itemScrollController: _scroll,
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _RowView(
                      row: rows[i],
                      gutterWidth: gutterWidth,
                      referenceWidth: referenceWidth,
                      focused: rows[i].verse == widget.focusedVerse,
                      highlight: widget.highlight,
                      showDiff: widget.showDiff,
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The one sentence that makes the marks readable.
///
/// A mark on its own says "this word is special" and nothing more. The
/// two facts a reader cannot recover from the ink are WHAT the mark
/// measures against and WHAT IT DOES NOT COMPARE, and both are here:
/// the base edition of every language group on screen, and the reason
/// the Greek line carries no marks at all.
///
/// Several bases, joined, rather than one: a stack of five English and
/// three 简体 editions is two independent comparisons, and naming only
/// the first would misdescribe the Chinese rows.
class _DiffLegend extends StatelessWidget {
  const _DiffLegend({required this.bases});

  final List<String> bases;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final locale = context.watch<AppSettings>().locale;
    final template = uiStrings['browseDiffLegend']?[locale] ??
        'Underlined = worded differently from {base}. '
            'Only editions in the same language are compared.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: wb.paneBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      child: Text.rich(
        TextSpan(children: [
          // The sample is drawn in the mark's own ink and with the
          // mark's own underline, so the legend is a specimen rather
          // than a description of one.
          TextSpan(
            text: '　',
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: wb.diffMark,
              decorationThickness: 2,
            ),
          ),
          TextSpan(
            text: '  ${template.replaceAll('{base}', bases.map(
                  shortBibleVersionLabel,
                ).join(' · '))}',
          ),
        ]),
        style: TextStyle(
          fontSize: t.chrome,
          height: 1.3,
          color: wb.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
    );
  }
}

// ── One printed line ────────────────────────────────────────────────

/// The one layout every printed line in the Browse pane goes through.
///
/// It exists because there were three. An untagged edition built its
/// line as a single `Text.rich` with the reference as the first span,
/// so the reference took part in line-breaking: the verse began after
/// it and every wrapped line began *under* it, at the far left. The two
/// tagged paths each built their own `Row` with an intrinsic-width
/// reference cell, so their text began wherever that row's own verse
/// number ended — `1:1` and `1:12` starting the text at different x.
/// Five editions stacked therefore showed the verse text at three
/// different left edges, which is what the reader reported on
/// 2026-08-17: 「不要不协调，要 harmony」.
///
/// [referenceWidth] is a MINIMUM, deliberately, not a fixed width. The
/// column is measured by a character model rather than a `TextPainter`
/// (see `version_gutter.dart` for why), and a model can be beaten by a
/// font wider than the one it was calibrated on. When that happens the
/// column goes slightly ragged, which is a blemish; clipping the
/// reference would instead be a lie about which verse this is.
class BrowseVerseRow extends StatelessWidget {
  const BrowseVerseRow({
    super.key,
    required this.reference,
    required this.referenceWidth,
    required this.referenceStyle,
    required this.child,
  });

  /// Printed on every row of every edition on purpose — that repetition
  /// is what lets a reader run their eye down a single translation.
  final String reference;

  final double referenceWidth;
  final TextStyle referenceStyle;

  /// The verse itself: a text flow, or a `Wrap` of tappable words.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: referenceWidth),
          child: Text(
            reference,
            style: referenceStyle,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.focused,
    required this.glosses,
    required this.keyPrefix,
    required this.gutterWidth,
    required this.referenceWidth,
    this.focus = AnalysisFocus.empty,
    this.onWordTap,
    this.onWordHover,
    this.onTap,
    this.highlight = const SearchHighlight(),
    this.showDiff = false,
  });

  final _BrowseRow row;
  final bool focused;
  final SearchHighlight highlight;
  final bool showDiff;
  final Map<String, StrongsEntry?> glosses;

  /// One width shared by every row in the chapter, so the verse text of
  /// all editions starts on the same x. Computed once from the editions
  /// actually on screen — a reader comparing four Chinese texts gets a
  /// two-character gutter and does not pay for `LXX+WH` existing.
  final double gutterWidth;

  /// The second fixed column, one width for the whole chapter, so the
  /// verse text starts on the same x whether or not this edition is
  /// tagged. See [BrowseVerseRow].
  final double referenceWidth;

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
    final t = WbType.of(context);
    final settings = context.watch<AppSettings>();
    // One style for the reference, built once here, because the three
    // paths each used to build their own and they had drifted: the two
    // tagged ones carried no `fontFamilyFallback`, so a Chinese book
    // name in their column had only the app font to draw 歷代志下 with.
    final referenceStyle = TextStyle(
      fontSize: t.text,
      height: t.lineHeight,
      fontWeight: FontWeight.w600,
      // Stated, not inherited: the column's width is computed with this
      // exact number. See [kBrowseReferenceLetterSpacing].
      letterSpacing: kBrowseReferenceLetterSpacing,
      color: wb.link,
      fontFamily: t.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
    );

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
                  // Indented past the reference column: it is text, and
                  // the text column has to stay straight.
                  if (row.superscription.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: referenceWidth),
                      child: _SuperscriptionLine(
                        text: row.superscription,
                        settings: settings,
                        highlight: highlight,
                      ),
                    ),
                  BrowseVerseRow(
                    reference: row.reference,
                    referenceWidth: referenceWidth,
                    referenceStyle: referenceStyle,
                    child: row.words != null
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
                            // Tagged translation: every run is its own
                            // hover target, like the originals line.
                            ? _TaggedLine(
                                row: row,
                                highlight: highlight,
                                showDiff: showDiff,
                                glosses: glosses,
                                keyPrefix: keyPrefix,
                                focus: focus,
                                showNumbers:
                                    settings.showStrongsInOriginals,
                                onWordTap: onWordTap,
                                onWordHover: onWordHover,
                              )
                            // Untagged translation reports the VERSE.
                            // Guessing which original word an untagged
                            // word renders would be a heuristic dressed
                            // as fact.
                            : MouseRegion(
                                onEnter: (_) =>
                                    onWordHover?.call(BrowseHover(
                                  reference: row.reference,
                                  verse: row.verse,
                                )),
                                child: _TranslationLine(
                                  row: row,
                                  settings: settings,
                                  highlight: highlight,
                                  showDiff: showDiff,
                                ),
                              ),
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
    this.showDiff = false,
  });

  final _BrowseRow row;
  final AppSettings settings;
  final SearchHighlight highlight;
  final bool showDiff;

  /// The marked stretches of one drawn span, or nothing when the mark is
  /// switched off. Resolved per span rather than per row because the
  /// offsets are relative to the span's own string.
  List<({int start, int end})> _spansOf(int unit) => showDiff
      ? mergedMarkSpans(row.diffTokens, row.diffMarks, unit)
      : const [];

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    // 2026-08-06: the Browse pane ignored Settings > Font Size entirely
    // — every size here was a hardcoded WbMetrics constant, so the
    // slider moved and nothing happened. The workbench is deliberately
    // denser than the reader, so it scales RELATIVE to the reader's
    // setting (20 is the default) rather than adopting it outright.
    //
    // 2026-08-17: the reference used to be the first span of this very
    // paragraph, which is why an untagged edition's second line began
    // underneath it instead of beside it. It is [BrowseVerseRow]'s now,
    // and this is the verse and nothing else.
    return Text.rich(
      TextSpan(
        children: [
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
            for (final (unit, span) in parseScripture(row.text ?? '').indexed)
              switch (span.kind) {
                // A plain span is where a text-query hit can live, so it
                // is split again on the search terms. Strong's queries
                // mark the tagged runs instead (see _HoverWord).
                //
                // The difference mark cuts the same string on its own
                // boundaries, so the two splits are merged: a hit keeps
                // its fill, a differing word keeps its underline, and a
                // word that is both keeps both.
                ScriptureSpanKind.plain => TextSpan(
                    children: [
                      for (final h in _hitPieces(span.text, unit))
                        TextSpan(
                          text: h.text,
                          style: TextStyle(
                            color: wb.text,
                            backgroundColor:
                                h.isHit ? wb.selectionBg : null,
                            fontWeight: h.isHit ? FontWeight.w700 : null,
                            decoration: h.diff ? TextDecoration.underline : null,
                            decorationColor: h.diff ? wb.diffMark : null,
                            decorationThickness: h.diff ? 2 : null,
                          ),
                        ),
                    ],
                  ),
                ScriptureSpanKind.supplied => TextSpan(
                    style: TextStyle(
                      color: wb.text,
                      fontStyle: FontStyle.italic,
                    ),
                    children: [
                      for (final p in sliceByMarks(
                          0, span.text.length, _spansOf(unit)))
                        TextSpan(
                          text: span.text.substring(p.start, p.end),
                          style: p.marked
                              ? TextStyle(
                                  decoration: TextDecoration.underline,
                                  decorationColor: wb.diffMark,
                                  decorationThickness: 2,
                                )
                              : null,
                        ),
                    ],
                  ),
                // Marked whole or not at all. `主[雅伟]` is one editorial
                // act and the brackets are apparatus, so underlining the
                // 雅伟 and leaving the 主 bare would draw a boundary
                // inside a device that has no inside.
                ScriptureSpanKind.divineName ||
                ScriptureSpanKind.gloss =>
                  glossSpan(
                    span,
                    wb,
                    style: showDiff && row.diffUnits.contains(unit)
                        ? TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: wb.diffMark,
                            decorationThickness: 2,
                          )
                        : null,
                  ),
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

  /// One plain span, cut on the union of the search boundaries and the
  /// difference boundaries.
  ///
  /// `splitOnTerms` reports no offsets — it returns pieces that
  /// concatenate back to the input — so the position is carried along by
  /// a cursor. That is exact by construction and stays exact as long as
  /// the pieces tile the string, which is the contract the highlighter
  /// already has to keep for the text to render at all.
  List<({String text, bool isHit, bool diff})> _hitPieces(
      String text, int unit) {
    final spans = _spansOf(unit);
    final out = <({String text, bool isHit, bool diff})>[];
    var at = 0;
    for (final h in splitOnTerms(text, highlight.textTerms)) {
      final end = at + h.text.length;
      if (spans.isEmpty) {
        out.add((text: h.text, isHit: h.isHit, diff: false));
      } else {
        for (final p in sliceByMarks(at, end, spans)) {
          out.add((
            text: text.substring(p.start, p.end),
            isHit: h.isHit,
            diff: p.marked,
          ));
        }
      }
      at = end;
    }
    return out;
  }
}

/// 2026-08-12 (docs/DATA-INTEGRITY.md check 31): the psalm title an
/// edition prints above verse 1. Its own line above the verse rather
/// than a row of its own: no other edition has a reference there, so a
/// row would print "this edition does not carry this verse" in every
/// other column for something three of them do carry, merged into
/// their verse 1.
class _SuperscriptionLine extends StatelessWidget {
  const _SuperscriptionLine({
    required this.text,
    required this.settings,
    this.highlight = const SearchHighlight(),
  });

  final String text;
  final AppSettings settings;

  /// 2026-08-12 (check 33): the title is in the search corpus, so a hit
  /// can land here. Marking the verse and leaving the line that
  /// actually matched unmarked would point the reader's eye away from
  /// the word they searched for.
  final SearchHighlight highlight;

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
              ScriptureSpanKind.plain => TextSpan(
                  children: [
                    for (final h in splitOnTerms(span.text, highlight.textTerms))
                      TextSpan(
                        text: h.text,
                        style: h.isHit
                            ? TextStyle(
                                backgroundColor: wb.selectionBg,
                                fontWeight: FontWeight.w700,
                                color: wb.text,
                              )
                            : null,
                      ),
                  ],
                ),
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
    this.showDiff = false,
    this.onWordTap,
    this.onWordHover,
  });

  final SearchHighlight highlight;
  final bool showDiff;

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
    // No `spacing`: a tagged run carries its own trailing space, so a
    // gap here would double it. See [kBrowseWordGap].
    return Wrap(
      runSpacing: kBrowseRunSpacing,
      children: [
        for (final (i, r) in runs.indexed)
          if (r.isTagged)
            _HoverWord(
              // A Strong's query marks the word carrying the
              // number — the tagging already knows which one.
              hit: highlight.matchesStrongs(r.strongs),
              diff: showDiff && row.diffUnits.contains(i),
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
                // An untagged run inside a tagged line is what the
                // tagger could not place — usually a connective or bare
                // punctuation. It has no hover state to collide with, so
                // the mark is an ordinary underline here, and it is
                // all-or-nothing because the run is a word or two.
                decoration: showDiff && row.diffUnits.contains(i)
                    ? TextDecoration.underline
                    : null,
                decorationColor: wb.diffMark,
                decorationThickness: 2,
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
    final words = row.words ?? const <OriginalWord>[];
    // The reference sits OUTSIDE this RTL scope — [BrowseVerseRow]
    // holds it, in the pane's own direction. Inside here, being the
    // first child put it at the right-hand end of a Hebrew line, so the
    // column of references no longer lined up down the page.
    return Directionality(
      textDirection: row.rtl ? TextDirection.rtl : TextDirection.ltr,
      // An originals word is a bare token with no space of its
      // own, which is the whole reason this path has a gap and
      // the tagged translation does not.
      child: Wrap(
        spacing: kBrowseWordGap,
        runSpacing: kBrowseRunSpacing,
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
    this.diff = false,
    this.onTap,
    this.onHover,
  });

  /// True when the active search marks this word.
  final bool hit;

  /// True when this word is worded differently from the base edition of
  /// its language group, and the reader has asked to see that. Drawn as
  /// the bottom edge of the word's box — see [wordMarkDecoration].
  final bool diff;

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
      // A doubled word is the one thing on this line a reader cannot
      // work out from the word itself, so it gets a sentence, not just
      // the letter printed beside the text.
      if (ketivQereLabel(widget.word.ketivQere, locale) case final label?)
        TextSpan(
          text: '\n$label',
          style: base(wb.link, w: FontWeight.w600),
        ),
      if (ketivQereNote(widget.word.ketivQere, locale) case final note?)
        TextSpan(text: '\n$note', style: base(wb.mutedText)),
    ]);
  }

  bool get _hasNumbers =>
      widget.word.strongs.isNotEmpty ||
      widget.grammar.isNotEmpty ||
      widget.implied.isNotEmpty;

  (String, String) get _splitWord =>
      splitTrailingCjkPunctuation(widget.word.text);
  String get _wordStem => _splitWord.$1;
  String get _trailingPunctuation => _splitWord.$2;

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
            decoration: wordMarkDecoration(mark, wb, diff: widget.diff),
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
                // 2026-08-25: the run's own trailing CJK punctuation
                // (baked into `w` by the source format — see
                // splitTrailingCjkPunctuation) is split off HERE and
                // printed after the numbers below, not as part of this
                // block, so 起初，H7225 becomes 起初H7225，— the number
                // sits against the word it tags, not against the CUV's
                // own comma.
                for (final span in parseScripture(_wordStem))
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
                if (_trailingPunctuation.isNotEmpty)
                  TextSpan(
                    text: _trailingPunctuation,
                    style: TextStyle(
                      fontWeight: widget.hit ? FontWeight.w700 : null,
                    ),
                  ),
                // LAST, and not behind [showNumbers]. A Strong's number
                // is optional apparatus; this letter is the only thing
                // saying why two words stand where the text has one, so
                // it always prints — and it has to touch the word it
                // marks. Every Latin span after a Hebrew one joins a
                // single left-to-right run, so span order is reversed on
                // screen: emitted first, the `K` came out at the far
                // left of `K H1409 בגד` and a reader scanning right to
                // left met the number before the mark. Emitted last, it
                // sits against the word.
                if (ketivQereMark(widget.word.ketivQere) case final kq?)
                  _num(kq, wb.mutedText),
              ]),
              style: TextStyle(
                // The doc on [translation] promises body size for a
                // translation run; only the originals line gets the
                // larger original-script treatment.
                fontSize: widget.translation
                    ? t.text
                    : t.original,
                height: t.lineHeight,
                // The Ketiv is set in the muted ink so the eye takes the
                // Qere as the running text — which is what the Masoretes
                // direct. It is still here, still hoverable, still
                // searchable; nothing is deleted, only de-emphasised.
                color: widget.word.isKetiv ? wb.mutedText : wb.text,
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
