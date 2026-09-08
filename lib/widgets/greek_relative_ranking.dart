/// 2026-09-08 (SeekSparks): the statistic Eagle's View was built around.
///
/// Its title bar calls the program "The Electronic Bible Statistical
/// Concordance", and the move that distinguishes it from every modern
/// Bible app is not counting — it is **normalising**. Absolute frequency
/// tells you καί is everywhere. A count rescaled to a baseline book tells
/// you which words make Luke sound like Luke.
///
/// Both halves of that were already imported and shipped. Only one was on
/// screen, and it was on screen WRONG: the Stats pane printed the asset's
/// `<abbr> RC` column as `Rev 3 ·#6`, a rank, which it is not — see
/// [GreekBookCount] for how that was settled. βδέλυγμα is the 343rd
/// commonest word in Revelation, not the 6th; 6 is its 3 occurrences
/// rescaled to Luke's length. A number under the wrong label is worse
/// than no number, because a reader cannot tell it is wrong.
///
/// So this widget's job is mostly typographic, and the labels carry more
/// weight than the figures:
///
///   * **the two orders are never adjacent and never share a heading.**
///     "Times it occurs" and "Scaled to Luke's length" are separate
///     rows with separate headings, and the scaled figures wear a `≈`
///     that the raw counts do not — three ways of saying the same thing,
///     because one is what the old `·#6` had;
///   * **the baseline is printed, not implied.** A ratio whose baseline
///     is off screen is decoration. Luke's running-word total and this
///     book's multiple of it are both stated;
///   * **the author groups say that they overlap.** The four totals do
///     not partition the corpus — the Fourth Gospel is inside both
///     Gospels+Acts and John — so printing them in a row without that
///     sentence prints an arithmetic error.
///
/// **Cost.** The collapsed block is free: everything in it comes from the
/// word entry the pane already loaded. The rank is not — it needs the
/// whole corpus, 1.1 MB of JSON, because a word's position among Mark's
/// 1,342 depends on the other 1,341. That is why the block starts
/// collapsed and [GreekStatsService.rankingIn] is only ever called from
/// the expansion: the reader pays for the rank by asking for it, and a
/// verse merely coming into focus pays nothing.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/greek_stats_service.dart';

/// "1 Corinthians" -> "1Co". The pane is 320–560 px wide and these sit
/// four to a row, so the full name is not an option.
String greekBookAbbr(String book) {
  final parts = book.split(' ');
  return parts.length == 1
      ? book.substring(0, book.length < 3 ? book.length : 3)
      : '${parts[0]}${parts[1].substring(0, 2)}';
}

/// The Eagle's View corpus profile for one Greek word.
///
/// Collapsed it is the old chip strip with its false rank removed.
/// Expanded it is the feature: this word's place in the book being read,
/// the two orders side by side under headings that separate them, the
/// baseline the scaled order is expressed in, and the four author
/// totals with the caveat that makes them readable.
class GreekRelativeRanking extends StatefulWidget {
  const GreekRelativeRanking({
    super.key,
    required this.stats,
    required this.locale,
    this.currentBook,
  });

  final GreekWordStats stats;
  final String locale;

  /// Canonical English name of the book being read. The rank is about
  /// THIS book — "the 8th commonest word in Mark" is a fact about Mark —
  /// so with no book in hand there is nothing to rank against and the
  /// line is omitted rather than guessed at from the word's own top book.
  final String? currentBook;

  @override
  State<GreekRelativeRanking> createState() => _GreekRelativeRankingState();
}

class _GreekRelativeRankingState extends State<GreekRelativeRanking> {
  bool _open = false;

  /// Created on the first expansion and never before — see the note on
  /// cost in this file's doc. Held rather than rebuilt so collapsing and
  /// reopening does not re-walk the corpus.
  Future<GreekBookRanking?>? _ranking;
  Future<_Baseline>? _baseline;

  void _toggle() {
    setState(() {
      _open = !_open;
      if (!_open) return;
      final book = widget.currentBook;
      _ranking ??= book == null
          ? Future<GreekBookRanking?>.value(null)
          : GreekStatsService.rankingIn(book);
      _baseline ??= _Baseline.load(book);
    });
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final g = widget.stats;
    if (g.books.isEmpty) return const SizedBox.shrink();
    final wb = WbColors.of(context);
    final t = WbType.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The raw counts, as chips, as before — minus the `·#6`.
          _chips(context, g.byFrequency.take(4).toList(), g.books.length),
          const SizedBox(height: 3),
          InkWell(
            onTap: _toggle,
            hoverColor: wb.hoverBg,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: t.scaled(13),
                    color: wb.mutedText,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _s('greekStatsRelativeToggle', 'Relative ranking'),
                    style: TextStyle(
                      fontSize: t.scaled(11),
                      color: wb.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open) _expansion(context),
        ],
      ),
    );
  }

  Widget _chips(
    BuildContext context,
    List<MapEntry<String, GreekBookCount>> top,
    int booksInAll,
  ) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Wrap(
      spacing: 5,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final e in top)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            // No fill. `WbTag` settled this for the workbench: the hue
            // belongs on the TEXT, because a tinted fill under a fixed
            // green loses its edge on the paper palette, and
            // [WbColors.selectionBg] follows the reader's theme colour
            // while [WbColors.strongsLexical] does not — a pairing whose
            // contrast nothing audits.
            decoration: BoxDecoration(
              border: Border.all(color: wb.border),
              borderRadius:
                  BorderRadius.circular(WbMetrics.radiusControl),
            ),
            child: Text(
              '${greekBookAbbr(e.key)} ${e.value.count}',
              style: TextStyle(
                fontSize: t.scaled(11),
                color: wb.strongsLexical,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        if (booksInAll > top.length)
          Text(
            '+${booksInAll - top.length}',
            style: TextStyle(fontSize: t.scaled(11), color: wb.mutedText),
          ),
      ],
    );
  }

  Widget _expansion(BuildContext context) {
    final g = widget.stats;
    final wb = WbColors.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
      decoration: BoxDecoration(
        color: wb.paneAltBg,
        border: Border.all(color: wb.border),
        borderRadius: BorderRadius.circular(WbMetrics.radiusSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _caption(context, _s('greekStatsCorpus',
              'Westcott–Hort Greek New Testament · 27 books')),
          const SizedBox(height: 4),
          _rankLine(context),
          if (widget.currentBook != null &&
              widget.stats.books.containsKey(widget.currentBook))
            _caption(
              context,
              _s(
                'greekStatsRankSameEitherWay',
                'Within one book the two orders agree — scaling multiplies '
                    'every count in it by the same number.',
              ),
            ),
          const SizedBox(height: 5),

          // Order one. Plain integers, the unit a reader can verify by
          // opening the book and counting.
          _heading(context, _s('greekStatsByCount', 'Times it occurs')),
          _figures(
            context,
            [for (final e in g.byFrequency.take(5)) (e.key, '${e.value.count}')],
            wb.strongsLexical,
          ),
          const SizedBox(height: 5),

          // Order two, and the reason this widget exists. Deliberately
          // NOT beside order one: two columns of small integers side by
          // side is exactly the misreading the old `·#6` was.
          _heading(context, _s('greekStatsByLuke', "Scaled to Luke's length")),
          _figures(
            context,
            [
              for (final e in g.byDensity.take(5))
                if (e.value.scaledToLuke != null)
                  (e.key, '≈${e.value.scaledToLuke}')
            ],
            wb.accent,
          ),
          _baselineLine(context),
          const SizedBox(height: 5),

          _heading(context, _s('greekStatsGroups', 'By author group')),
          _groupLine(context),
          _caption(
            context,
            _s(
              'greekStatsGroupsOverlap',
              "These overlap — John's Gospel is counted in both Gospels+Acts "
                  'and John — so they do not add up to the {total} in the '
                  'New Testament.',
            ).replaceAll('{total}', '${g.nt}'),
          ),
        ],
      ),
    );
  }

  /// The word's place in the book being read, or a plain sentence saying
  /// it is not there. The whole line waits on the corpus load.
  Widget _rankLine(BuildContext context) {
    final book = widget.currentBook;
    final t = WbType.of(context);
    final wb = WbColors.of(context);
    if (book == null) return const SizedBox.shrink();

    final here = widget.stats.books[book];
    if (here == null) {
      return Text(
        _s('greekStatsNotInBook', 'Not in {book}').replaceAll('{book}', book),
        style: TextStyle(fontSize: t.scaled(11.5), color: wb.mutedText),
      );
    }

    return FutureBuilder<GreekBookRanking?>(
      future: _ranking,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Text(
            '…',
            style: TextStyle(fontSize: t.scaled(11.5), color: wb.mutedText),
          );
        }
        final ranking = snap.data;
        final rank = ranking?.rankOf(widget.stats.strongs);
        if (ranking == null || rank == null) {
          return Text(
            '$book ${here.count}',
            style: TextStyle(
              fontSize: t.scaled(11.5),
              color: wb.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
        }
        return Text(
          _s('greekStatsRankInBook',
                  'In {book}: {count}× · #{rank} of {total} words')
              .replaceAll('{book}', book)
              .replaceAll('{count}', '${here.count}')
              .replaceAll('{rank}', '$rank')
              .replaceAll('{total}', '${ranking.rankedWords}'),
          style: TextStyle(
            fontSize: t.scaled(11.5),
            fontWeight: FontWeight.w600,
            color: wb.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }

  /// Luke's length, and this book's multiple of it. Without these the
  /// scaled figures above are numbers with no unit.
  Widget _baselineLine(BuildContext context) {
    return FutureBuilder<_Baseline>(
      future: _baseline,
      builder: (context, snap) {
        final b = snap.data;
        if (b == null || b.lukeWords == 0) return const SizedBox.shrink();
        final sentences = <String>[
          _s(
            'greekStatsLukeBaseline',
            'Baseline: Luke, {words} running words — every figure above is '
                'rescaled as if the book were that long, so a short letter '
                'can be read beside a long Gospel.',
          ).replaceAll('{words}', '${b.lukeWords}'),
          if (b.ratio != null && b.ratio! > 1 && widget.currentBook != null)
            _s('greekStatsLukeThisBook',
                    'Luke is about {ratio}× the length of {book}.')
                .replaceAll('{ratio}', _trim(b.ratio!))
                .replaceAll('{book}', widget.currentBook!),
        ];
        return _caption(context, sentences.join(' '));
      },
    );
  }

  /// All four totals, zeros included. "Absent from Paul" is the
  /// observation; a row that silently drops the empty groups cannot
  /// make it.
  Widget _groupLine(BuildContext context) {
    final g = widget.stats;
    final t = WbType.of(context);
    final wb = WbColors.of(context);
    const groups = <String, (String, String)>{
      'gospelsActs': ('greekGroupGospelsActs', 'Gospels+Acts'),
      'paul': ('greekGroupPaul', 'Paul'),
      'john': ('greekGroupJohn', 'John'),
      'otherAuthors': ('greekGroupOther', 'Other'),
    };
    return Text(
      [
        for (final e in groups.entries)
          '${_s(e.value.$1, e.value.$2)} ${g.totals[e.key] ?? 0}',
      ].join(' · '),
      style: TextStyle(
        fontSize: t.scaled(11.5),
        color: wb.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _heading(BuildContext context, String text) {
    final t = WbType.of(context);
    final wb = WbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        text,
        style: TextStyle(
          fontSize: t.scaled(11),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: wb.mutedText,
        ),
      ),
    );
  }

  Widget _figures(
    BuildContext context,
    List<(String, String)> rows,
    Color colour,
  ) {
    final t = WbType.of(context);
    final wb = WbColors.of(context);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      children: [
        for (final r in rows)
          // `Text.rich`, not a bare `RichText`: the latter starts from an
          // empty style and would drop the reader's chosen family and the
          // bundled fallback chain, which is how Greek and Hebrew turn
          // into notdef boxes elsewhere in this app.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${greekBookAbbr(r.$1)} ',
                  style: TextStyle(fontSize: t.scaled(11.5), color: wb.text),
                ),
                TextSpan(
                  text: r.$2,
                  style: TextStyle(
                    fontSize: t.scaled(11.5),
                    fontWeight: FontWeight.w700,
                    color: colour,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _caption(BuildContext context, String text) {
    final t = WbType.of(context);
    final wb = WbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: t.scaled(11),
          height: 1.35,
          color: wb.mutedText,
        ),
      ),
    );
  }

  /// 8.7 -> "8.7", 2.0 -> "2". A trailing ".0" on a length ratio reads
  /// as precision the source's one decimal place does not have.
  static String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';
}

/// The two numbers that make a scaled figure interpretable, loaded once
/// per expansion.
class _Baseline {
  const _Baseline({required this.lukeWords, required this.ratio});

  final int lukeWords;

  /// How many times the book being read fits into Luke, or null when
  /// there is no book or the profile does not carry it.
  final double? ratio;

  static Future<_Baseline> load(String? book) async => _Baseline(
        lukeWords: await GreekStatsService.lukeRunningWords(),
        ratio:
            book == null ? null : await GreekStatsService.lengthRatioVsLuke(book),
      );
}

/// What an Old Testament verse gets instead of an empty panel.
///
/// The whole statistical apparatus stops at the Greek New Testament —
/// there is no Hebrew equivalent in the asset and there is no plan to
/// invent one. A reader whose verse is in Genesis has to be told that,
/// in a sentence, or the missing block reads as a defect they might sit
/// and wait for.
class GreekStatsUnavailableNote extends StatelessWidget {
  const GreekStatsUnavailableNote({super.key, required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    final wb = WbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        uiStrings['greekStatsNoHebrew']?[locale] ??
            'Greek New Testament only — this corpus profile has no Hebrew '
                'equivalent.',
        style: TextStyle(
          fontSize: t.scaled(11),
          height: 1.35,
          color: wb.mutedText,
        ),
      ),
    );
  }
}
