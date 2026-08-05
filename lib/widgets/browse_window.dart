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
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/models/strongs.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/morphology.dart' show describeMorphology;
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/workbench_chrome.dart' show WbVersionTag;

/// One printed line: a translation of a verse, or its originals line.
class _BrowseRow {
  const _BrowseRow({
    required this.verse,
    required this.label,
    required this.reference,
    required this.firstOfVerse,
    this.text,
    this.words,
    this.runs,
    this.rtl = false,
  });

  final int verse;

  /// Short version code shown in the gutter (NAS / KJV / WTT / BGT).
  final String label;

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
  });

  /// Null for a verse-level hover (a translation line).
  final OriginalWord? word;

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
  });

  /// Canonical English book name, e.g. "Genesis".
  final String book;
  final int chapter;

  /// Translation codes to print, in order. The originals line is always
  /// appended last, mirroring BibleWorks' BGT/WTT placement.
  final List<String> versionCodes;

  /// Verse the workspace cursor is on — highlighted, and scrolled to.
  final int? focusedVerse;

  final void Function(OriginalWord word)? onWordTap;

  /// Null is passed when the pointer leaves a word, so the status bar
  /// can clear.
  final void Function(BrowseHover? hover)? onWordHover;

  final void Function(int verse)? onVerseTap;

  @override
  State<BrowseWindow> createState() => _BrowseWindowState();
}

class _BrowseWindowState extends State<BrowseWindow> {
  /// Whole-version verse lists are expensive to parse, so they live for
  /// the life of the process — the same handful of versions is printed
  /// over and over as the reader walks through a book.
  static final Map<String, List<Verse>> _versionCache = {};
  static final Map<String, Future<List<Verse>?>> _inflight = {};

  late Future<List<_BrowseRow>> _future;

  /// A positioned list, not a plain ListView: picking a verse from the
  /// nav strip has to SCROLL there, and row heights vary too much
  /// (a one-line KJV verse vs a wrapped originals line) to compute an
  /// offset.
  final ItemScrollController _scroll = ItemScrollController();

  /// Row index of the first line of each verse, so a jump lands on the
  /// verse's own block rather than mid-way through the previous one.
  final Map<int, int> _firstRowOfVerse = {};

  /// Strong's number -> entry, for every original word in the chapter.
  /// Prefetched with the rows: the hover popup has to appear the instant
  /// the pointer lands, and an async lookup per word would make it
  /// arrive after the pointer has already moved on.
  final Map<String, StrongsEntry?> _glosses = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant BrowseWindow old) {
    super.didUpdateWidget(old);
    // The focused verse deliberately does NOT reload: moving the cursor
    // within a chapter is a highlight change plus a scroll, not a fetch.
    if (old.book != widget.book ||
        old.chapter != widget.chapter ||
        !_sameList(old.versionCodes, widget.versionCodes)) {
      setState(() => _future = _load());
    } else if (old.focusedVerse != widget.focusedVerse) {
      _scrollToFocused();
    }
  }

  /// Bring the focused verse into view. Deferred a frame so it also
  /// works right after a load, when the list has not been laid out yet.
  void _scrollToFocused() {
    final v = widget.focusedVerse;
    if (v == null) return;
    final index = _firstRowOfVerse[v];
    if (index == null) return;
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

  static Future<List<Verse>?> _versionVerses(String code) async {
    final cached = _versionCache[code];
    if (cached != null) return cached;
    final list = await (_inflight[code] ??= FetchVerses.loadVerseList(code));
    if (list != null) _versionCache[code] = list;
    return list;
  }

  Future<List<_BrowseRow>> _load() async {
    final locale = context.read<AppSettings>().locale;

    // Fetch every version AT ONCE. Awaiting them one at a time meant a
    // cold Browse window parsed three whole-Bible JSONs in series and
    // took ~30s to first paint; in parallel it costs roughly the slowest
    // one. (They are cached process-wide afterwards, so this only bites
    // on the first chapter of a session.)
    final loaded = await Future.wait(widget.versionCodes.map(_versionVerses));

    // version code -> {verse number: text}, plus the chapter's extent.
    final byVersion = <String, Map<int, String>>{};
    var lastVerse = 0;
    for (var i = 0; i < widget.versionCodes.length; i++) {
      final verses = loaded[i];
      if (verses == null) continue;
      final map = <int, String>{};
      for (final v in verses) {
        if (v.chapter != widget.chapter) continue;
        if ((bookNameToEnglish[v.book] ?? v.book) != widget.book) continue;
        map[v.verse] = v.text;
        if (v.verse > lastVerse) lastVerse = v.verse;
      }
      if (map.isNotEmpty) byVersion[widget.versionCodes[i]] = map;
    }
    if (lastVerse == 0) return const [];

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
        if (text == null) continue;
        final runs = await TaggedTextService.forVerse(
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
          label: shortBibleVersionLabel(code),
          reference: reference,
          firstOfVerse: first,
          text: text,
          runs: runs,
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
          label: isHebrew ? 'WTT' : 'BGT',
          reference: reference,
          firstOfVerse: first,
          words: words,
          rtl: isHebrew,
        ));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return FutureBuilder<List<_BrowseRow>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: wb.paneBg,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
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
                  fontSize: WbMetrics.text, color: wb.mutedText),
            ),
          );
        }
        // Land on the focused verse as soon as the rows exist.
        _scrollToFocused();
        return Container(
          color: wb.paneBg,
          child: ScrollablePositionedList.builder(
              itemScrollController: _scroll,
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              itemBuilder: (context, i) => _RowView(
                row: rows[i],
                focused: rows[i].verse == widget.focusedVerse,
                glosses: _glosses,
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
    this.onWordTap,
    this.onWordHover,
    this.onTap,
  });

  final _BrowseRow row;
  final bool focused;
  final Map<String, StrongsEntry?> glosses;
  final void Function(OriginalWord word)? onWordTap;
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
            WbVersionTag(code: row.label),
            Expanded(
              child: row.words != null
                  ? _OriginalsLine(
                      row: row,
                      glosses: glosses,
                      onWordTap: onWordTap,
                      onWordHover: onWordHover,
                    )
                  : row.runs != null
                      // Tagged translation: every run is its own hover
                      // target, exactly like the originals line.
                      ? _TaggedLine(
                          row: row,
                          glosses: glosses,
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
                              _TranslationLine(row: row, settings: settings),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslationLine extends StatelessWidget {
  const _TranslationLine({required this.row, required this.settings});

  final _BrowseRow row;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
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
          TextSpan(text: row.text ?? '', style: TextStyle(color: wb.text)),
        ],
      ),
      style: TextStyle(
        fontSize: WbMetrics.text,
        height: WbMetrics.lineHeight,
        fontFamilyFallback: kCjkFontFallback,
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
    this.onWordTap,
    this.onWordHover,
  });

  final _BrowseRow row;
  final Map<String, StrongsEntry?> glosses;
  final void Function(OriginalWord word)? onWordTap;
  final void Function(BrowseHover? hover)? onWordHover;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final runs = row.runs ?? const <TaggedRun>[];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            row.reference,
            style: TextStyle(
              fontSize: WbMetrics.text,
              height: WbMetrics.lineHeight,
              fontWeight: FontWeight.w600,
              color: wb.link,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            children: [
              for (final r in runs)
                if (r.isTagged)
                  _HoverWord(
                    // Reuse the originals hover target: same behaviour,
                    // same popup, only the script differs.
                    word: OriginalWord(text: r.text, strongs: r.strongs),
                    reference: row.reference,
                    verse: row.verse,
                    entry: glosses[r.strongs],
                    grammar: r.grammar,
                    translation: true,
                    onTap: onWordTap,
                    onHover: onWordHover,
                  )
                else
                  Text(
                    r.text,
                    style: TextStyle(
                      fontSize: WbMetrics.text,
                      height: WbMetrics.lineHeight,
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
    this.onWordTap,
    this.onWordHover,
  });

  final _BrowseRow row;
  final Map<String, StrongsEntry?> glosses;
  final void Function(OriginalWord word)? onWordTap;
  final void Function(BrowseHover? hover)? onWordHover;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
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
              fontSize: WbMetrics.text,
              height: WbMetrics.lineHeight,
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
                for (final w in words)
                  _HoverWord(
                    word: w,
                    reference: row.reference,
                    verse: row.verse,
                    entry: glosses[w.strongs],
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
    this.grammar = const [],
    this.translation = false,
    this.onTap,
    this.onHover,
  });

  final OriginalWord word;
  final String reference;
  final int verse;

  /// Prefetched lexicon entry, used to build the hover popup. Null when
  /// the number is missing from the lexicon — the popup then shows just
  /// the word and its number rather than nothing.
  final StrongsEntry? entry;

  /// Grammar codes carried by a tagged translation run.
  final List<String> grammar;

  /// Translation text renders at body size in the body colour; only the
  /// originals line gets the larger original-script treatment.
  final bool translation;
  final void Function(OriginalWord word)? onTap;
  final void Function(BrowseHover? hover)? onHover;

  @override
  State<_HoverWord> createState() => _HoverWordState();
}

class _HoverWordState extends State<_HoverWord> {
  bool _hovering = false;

  /// The popup BibleWorks shows beside the cursor: Strong's number, the
  /// word itself in the accent colour, its transliteration, then the
  /// gloss — and, since we have it, the parsing. This is the whole
  /// reason its Browse window can be *read* with the mouse: you never
  /// leave the text to find out what a word is.
  InlineSpan _popup(BuildContext context) {
    final wb = WbColors.of(context);
    final locale = context.read<AppSettings>().locale;
    final e = widget.entry;
    final gloss = e?.localizedGloss(locale) ?? '';
    final parse = describeMorphology(widget.word.morph, locale);

    TextStyle base(Color c, {FontWeight? w, double? size}) => TextStyle(
          fontSize: size ?? WbMetrics.chrome,
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
            w: FontWeight.w600, size: WbMetrics.original),
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

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
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
          widget.onHover?.call(BrowseHover(
            word: widget.word,
            reference: widget.reference,
            verse: widget.verse,
          ));
        },
        onExit: (_) {
          setState(() => _hovering = false);
          widget.onHover?.call(null);
        },
        child: GestureDetector(
          onTap:
              widget.onTap == null ? null : () => widget.onTap!(widget.word),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: _hovering ? wb.selectionBg : null,
            child: Text(
              widget.word.text,
              style: TextStyle(
                fontSize: WbMetrics.original,
                height: WbMetrics.lineHeight,
                color: wb.text,
                // Underline on hover, so touch users (who get no hover)
                // and mouse users both see that words are live.
                decoration:
                    _hovering ? TextDecoration.underline : TextDecoration.none,
                decorationColor: wb.link,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
