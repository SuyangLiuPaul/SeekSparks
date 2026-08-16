/// 2026-08-17 (#313): the Related Sermons tab.
///
/// The last of the reader's four content actions to still open a modal
/// sheet over the verse it was describing. #313's rule — *a modal is
/// for a DECISION; content that has a pane goes to the pane* — left
/// this one behind because its body lived inside an 8,000-line file and
/// a thirteenth tab had to be re-measured against #297's strip
/// arithmetic. Both are dealt with here: the body is a pane of its own,
/// and the strip's own measurement (not a constant) decides the labels.
///
/// **BibleWorks docks exactly this.** Its Resource Summary tab shows,
/// for the verse under the cursor, "a list of locations where the
/// current verse is cited… an entry for each reference", and its Verse
/// tab "automatically loads the content matching the current verse" as
/// the pointer moves (bwh10, bwh14). The analysis surface follows the
/// text; it is never summoned over it.
///
/// **Two deliberate departures from that, both declared:**
///
/// 1. BibleWorks prints one entry *per reference*, so a commentary
///    citing Romans 8:1, 8:5 and 8:9 appears three times. In a 320 px
///    pane that reads as three sermons. Here it is one row per sermon
///    carrying the references it makes — measured first: no sermon in
///    this corpus cites more than **4** verses of any one chapter, so
///    the row never has to be clever.
/// 2. The tier headings are ours, not BibleWorks'. They exist because
///    the underlying match is chapter-wide and, unlabelled, that
///    overstates every row — see `passage_sermons.dart`.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/sermon_credit.dart';
import 'package:seeksparks/constants/sermon_topics.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/sermon.dart';
import 'package:seeksparks/services/sermon_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/passage_sermons.dart';

class SermonsPane extends StatefulWidget {
  const SermonsPane({
    super.key,
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.displayBook,
    required this.locale,
    required this.onOpenSermon,
  });

  final String englishBook;
  final int chapter;

  /// The verse the reader has selected, or 0 when the pane was reached
  /// without one. Zero is not a missing value here — it is the honest
  /// statement that no verse was asked about, and it suppresses the
  /// "cites this verse" tier rather than inventing one.
  final int verse;

  /// The book as the reader's version spells it, for the heading —
  /// through `localeAwareBookName` at the call site, never formatted
  /// here (#283/#290).
  final String displayBook;

  final String locale;
  final void Function(Sermon sermon) onOpenSermon;

  @override
  State<SermonsPane> createState() => _SermonsPaneState();
}

class _SermonsPaneState extends State<SermonsPane> {
  late Future<PassageSermons> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(SermonsPane old) {
    super.didUpdateWidget(old);
    if (old.englishBook != widget.englishBook ||
        old.chapter != widget.chapter ||
        old.verse != widget.verse) {
      _future = _load();
    }
  }

  Future<PassageSermons> _load() => SermonService.instance.sermonsForPassage(
        englishBook: widget.englishBook,
        chapter: widget.chapter,
        verse: widget.verse,
      );

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  String get _reference => widget.verse > 0
      ? '${widget.displayBook} ${widget.chapter}:${widget.verse}'
      : '${widget.displayBook} ${widget.chapter}';

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    return FutureBuilder<PassageSermons>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final data = snap.data;
        if (data == null || data.isEmpty) {
          return _empty(c, t);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            _countLine(c, t, data),
            if (data.verse.isNotEmpty) ...[
              _sectionTitle(
                  c, t, _s('sermonsOnThisVerse', 'Preaching this verse')),
              for (final p in data.verse) _row(c, t, p, emphasised: true),
            ],
            if (data.chapter.isNotEmpty) ...[
              _sectionTitle(c, t,
                  _s('sermonsInThisChapter', 'Elsewhere in this chapter')),
              for (final p in data.chapter) _row(c, t, p, emphasised: false),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                sermonLibraryCredit(widget.locale),
                style: TextStyle(
                  fontSize: t.chrome - 1.5,
                  color: c.mutedText,
                  height: 1.35,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(WbColors c, WbType t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            // Names the chapter, because "no sermons" on its own leaves
            // the reader unsure whether the corpus was even consulted.
            _s('sermonsNone', 'No sermon in the library cites {ref}.')
                .replaceAll('{ref}', '${widget.displayBook} ${widget.chapter}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: t.text,
              color: c.mutedText,
              height: 1.5,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
      );

  /// The count, with its unit and its scope both named.
  ///
  /// #308's rule, applied before it could be broken again: this list is
  /// chapter-wide, and a bare "49" beside a verse reference reads as 49
  /// sermons on that verse. It is not.
  Widget _countLine(WbColors c, WbType t, PassageSermons data) {
    // `data.verse` is already empty when no verse was asked about —
    // nothing can cite a focused verse that does not exist.
    final template = _s(
        sermonCountKey(total: data.total, onVerse: data.verse.length),
        '{total} sermons cite {chapter}.');
    final text = template
        .replaceAll('{total}', '${data.total}')
        .replaceAll('{onVerse}', '${data.verse.length}')
        .replaceAll('{chapter}', '${widget.displayBook} ${widget.chapter}')
        .replaceAll('{ref}', _reference);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: t.chrome,
          color: c.mutedText,
          height: 1.4,
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
    );
  }

  Widget _sectionTitle(WbColors c, WbType t, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: FontWeight.w700,
            color: c.mutedText,
            letterSpacing: 0.3,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      );

  Widget _row(WbColors c, WbType t, PassageSermon p,
      {required bool emphasised}) {
    final s = p.sermon;
    final cited = citedVerseLabel(p.citation);
    // What the row claims, in the reader's words: the verses of THIS
    // chapter this sermon cites, or that it names the chapter only.
    final citation = cited != null
        ? _s('sermonsCites', 'cites v{verses}').replaceAll('{verses}', cited)
        : _s('sermonsCitesChapter', 'cites the chapter');
    final meta = <String>[
      if (s.displayDate != '—') s.displayDate,
      localizedSermonTopic(s.topic, widget.locale),
    ];

    return InkWell(
      onTap: () => widget.onOpenSermon(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.5),
              child: Icon(
                emphasised
                    ? Icons.menu_book_rounded
                    : Icons.menu_book_outlined,
                size: t.text,
                color: emphasised ? c.link : c.mutedText,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.localizedTitle(widget.locale),
                    // Two lines, not one: a sermon title is a sentence,
                    // and #297's rule is that a clipped CJK label
                    // identifies nothing. Wrapping costs a row; an
                    // ellipsis costs the title.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.text,
                      fontWeight:
                          emphasised ? FontWeight.w700 : FontWeight.w500,
                      color: c.text,
                      height: 1.3,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      citation,
                      style: TextStyle(
                        fontSize: t.chrome - 1,
                        color: emphasised ? c.link : c.mutedText,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        meta.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.chrome - 1,
                          color: c.mutedText,
                          fontFamilyFallback: kCjkFontFallback,
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
