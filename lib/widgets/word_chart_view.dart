/// 2026-08-08 (SeekSparks): the labelled word-distribution chart — task
/// #290, BibleWorks bwh23.
///
/// The strip in the Analysis pane (`word_distribution_strip.dart`) gives
/// the SHAPE with no labels, because at 256–560 px there is no room for
/// 66 book names. This is the other half: the same numbers with the book
/// names attached, in the centre pane, where there is room for them.
///
/// bwh23 makes the same split, and for the same reason — it ships the
/// Search Statistics tab inside the Analysis window AND a "New Window"
/// command that reopens it resizable, noting that this "allows you to
/// display more of the graph at once". A chart of 66 categories does not
/// fit a sidebar and BibleWorks does not pretend otherwise.
///
/// Three decisions taken from bwh23 rather than invented:
///
///   * Book names run down the vertical axis, bars grow rightwards.
///     That is BibleWorks' default; its "Swap Axis" option is what
///     turns the names horizontal. Names read better stacked, and 66
///     rows scroll where 66 columns cannot.
///   * Empty books are omitted here. bwh23's "Show Zeros" defaults off,
///     and with labels present their absence is better said as a number
///     ("in 24 of 66 books") than drawn as 42 blank rows.
///   * Order is switchable. bwh23's "Sort Books" offers canonical order
///     and ascending/descending value side by side because they answer
///     different questions: canonical shows where in the canon the word
///     lives, sorted ranks the books.
///
/// What is deliberately NOT copied is the appearance — the grey 3D frame
/// and the pink bars. This holds `workbench_theme.dart`: square corners,
/// 1 px hairlines, no shadows, no cards, and the only saturated colour
/// carrying meaning.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/search_scope.dart' show kScopeAllBooks;
import 'package:seeksparks/utils/search_stats.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// How the rows are ordered. bwh23's "Sort Books", minus the ascending
/// and custom orders: ascending is descending read from the bottom, and
/// a custom canon order is a preference this app does not offer.
enum WordChartOrder { canonical, mostFirst }

class WordChartView extends StatefulWidget {
  const WordChartView({
    super.key,
    required this.strongs,
    required this.word,
    required this.gloss,
    required this.distribution,
    required this.locale,
    required this.version,
    required this.onClose,
    this.currentBook,
    this.ranks = const <String, int>{},
    this.scopeName,
  });

  /// The Strong's number this is a chart of, printed because the chart
  /// outlives the tap that opened it — the reader can move the verse
  /// underneath and the header must still say what is being counted.
  final String strongs;

  /// The original-language word, and its gloss.
  final String word;
  final String gloss;

  /// Built with `includeEmpty: false`. See the library comment.
  final SearchDistribution distribution;

  final String locale;
  final String version;
  final VoidCallback onClose;

  /// Canonical English name of the book being read, highlighted so the
  /// chart answers "and where am I in this?".
  final String? currentBook;

  /// This word's rank among the words of a given book, where it is
  /// known. The Eagle's View Greek profile carries it; nothing carries
  /// it for Hebrew, so the map is simply empty there and the rows omit
  /// the figure rather than printing a zero.
  final Map<String, int> ranks;

  /// The active search limit's name, when there is one. The chart itself
  /// is always whole-Bible — the per-book counts come from the
  /// concordance index, which is not narrowable — so this exists to SAY
  /// so, not to filter.
  final String? scopeName;

  @override
  State<WordChartView> createState() => _WordChartViewState();
}

class _WordChartViewState extends State<WordChartView> {
  WordChartOrder _order = WordChartOrder.canonical;

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  List<BookHits> get _rows => switch (_order) {
        WordChartOrder.canonical => [
            for (final b in widget.distribution.books)
              if (b.count > 0) b,
          ],
        WordChartOrder.mostFirst => booksByCount(widget.distribution),
      };

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final rows = _rows;

    return ColoredBox(
      color: c.paneBg,
      child: Column(
        children: [
          _header(c, t),
          Divider(height: WbMetrics.hairline, color: c.border),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      _s('analysisNoStats',
                          'No original-language data for this verse.'),
                      style: TextStyle(fontSize: t.text, color: c.mutedText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _row(c, t, rows[i]),
                  ),
          ),
          Divider(height: WbMetrics.hairline, color: c.border),
          _footer(c, t),
        ],
      ),
    );
  }

  Widget _header(WbColors c, WbType t) {
    final d = widget.distribution;
    return Container(
      height: t.paneTitleHeight + 4,
      color: c.chromeBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(Icons.bar_chart, size: t.chrome + 2, color: c.mutedText),
          const SizedBox(width: 6),
          // The word may be truncated; the Strong's number may not. It
          // is what names the quantity, and the chart outlives the tap
          // that opened it — so it sits outside the Flexible, where the
          // ellipsis cannot reach it.
          if (widget.word.isNotEmpty) ...[
            Flexible(
              child: Text(
                widget.word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            widget.strongs,
            style: TextStyle(
              fontSize: t.chrome,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${d.total}',
            style: TextStyle(
              fontSize: t.chrome,
              fontWeight: FontWeight.w700,
              color: c.link,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          _toggle(c, t, _s('wordChartSortCanonical', 'Canonical'),
              _order == WordChartOrder.canonical, () {
            setState(() => _order = WordChartOrder.canonical);
          }),
          const SizedBox(width: 4),
          _toggle(c, t, _s('wordChartSortMost', 'Most first'),
              _order == WordChartOrder.mostFirst, () {
            setState(() => _order = WordChartOrder.mostFirst);
          }),
          const SizedBox(width: 8),
          _toggle(c, t, _s('close', 'Close'), false, widget.onClose),
        ],
      ),
    );
  }

  Widget _toggle(
      WbColors c, WbType t, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: active ? c.selectionBg : null,
          border: Border.all(color: c.border, width: WbMetrics.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: t.chrome - 0.5,
            color: active ? c.text : c.mutedText,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _row(WbColors c, WbType t, BookHits b) {
    final d = widget.distribution;
    final isCurrent = b.englishBook == widget.currentBook;
    final name = localeAwareBookName(b.englishBook, widget.locale, widget.version);
    final rank = widget.ranks[b.englishBook];
    final fill = b.isOldTestament ? c.link : c.strongsLexical;
    final share = d.total == 0 ? 0.0 : b.count / d.total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.text,
                color: isCurrent ? c.text : c.mutedText,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Stack(
              children: [
                // The track runs the full width so every bar is read
                // against the same 100%, which is what makes two rows
                // comparable at a glance.
                Container(height: 13, color: c.paneAltBg),
                FractionallySizedBox(
                  widthFactor: d.peak == 0
                      ? 0.0
                      : (b.count / d.peak).clamp(0.0, 1.0).toDouble(),
                  child: Container(height: 13, color: fill),
                ),
                if (isCurrent)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: c.text, width: WbMetrics.hairline),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '${b.count}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: t.text,
                fontWeight: FontWeight.w700,
                color: c.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              // One decimal below 10%, none above: "0.3%" carries
              // information where "12.4%" is noise at this width.
              share >= 0.0995
                  ? '${(share * 100).round()}%'
                  : '${(share * 100).toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: t.chrome,
                color: c.mutedText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: rank == null
                ? const SizedBox.shrink()
                : Tooltip(
                    message: _s('wordChartRankInBook', 'Ranked #{n} in that book')
                        .replaceAll('{n}', '$rank'),
                    child: Text(
                      '#$rank',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: t.chrome,
                        color: c.mutedText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _footer(WbColors c, WbType t) {
    final d = widget.distribution;
    final scope = widget.scopeName;
    final parts = <String>[
      _s('wordChartInBooks', 'In {n} of {total} books')
          .replaceAll('{n}', '${d.bookCount}')
          .replaceAll('{total}', '${kScopeAllBooks.length}'),
      if (d.oldTestament > 0 && d.newTestament > 0)
        '${_s('oldTestamentShort', 'Hebrew')} ${d.oldTestament}'
            ' · ${_s('newTestamentShort', 'Greek')} ${d.newTestament}',
      _s('wordChartUnit',
          'Counted by occurrence, not by verse — one verse may carry the '
          'word more than once.'),
      if (scope != null && scope.isNotEmpty)
        _s('wordChartWholeBible',
                'Whole Bible — not narrowed by the active limit ({name})')
            .replaceAll('{name}', scope),
    ];

    return Container(
      width: double.infinity,
      color: c.chromeBg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        parts.join('  ·  '),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: t.chrome - 0.5, color: c.mutedText),
      ),
    );
  }
}
