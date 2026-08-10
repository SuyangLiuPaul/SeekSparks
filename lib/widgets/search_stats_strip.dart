/// 2026-08-06 (SeekSparks): search-hit distribution — BibleWorks bwh23.
///
/// Sits above the hit list, because the shape of a result is worth
/// seeing before the first line of it. That a word clusters in John, or
/// appears only in the Pentateuch, is an observation; "140 hits" is
/// not.
///
/// Deliberately compact — the command pane is 240–480 px and this is a
/// header, not a report. One testament split bar, one row of per-book
/// bars, one line naming the top books.
///
/// 2026-08-10 (#308): that line used to read `Most in: John 27` and
/// never said what 27 counted. It is VERSES; the same word occurs 37
/// times in John, and a reader arriving from software that plots
/// occurrences reads 27 as a frequency and is wrong by ten. bwh23 makes
/// the unit an explicit menu choice for exactly this reason. So the unit
/// is named here, both counts are printed where both are known, and a
/// distribution that was tallied from a truncated list is not drawn at
/// all — see [SearchDistribution.partial].
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/search_stats.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

class SearchStatsStrip extends StatelessWidget {
  const SearchStatsStrip({
    super.key,
    required this.distribution,
    required this.locale,
    required this.version,
    this.onBookTap,
  });

  final SearchDistribution distribution;
  final String locale;
  final String version;
  final void Function(String englishBook)? onBookTap;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  /// The name of [unit], for the one place per strip that says it.
  String _unitName(HitUnit unit) => unit == HitUnit.verses
      ? _s('hitUnitVerses', 'verses')
      : _s('hitUnitOccurrences', 'occurrences');

  /// One book, both units, spelled out — the tooltip and the semantics
  /// string. Nothing here is abbreviated: it is read once, deliberately.
  String _bookLabel(BookHits b) {
    final name = localeAwareBookName(b.englishBook, locale, version);
    final primary = '${b.count} ${_unitName(distribution.unit)}';
    final second = b.secondary;
    if (second == null) return '$name · $primary';
    return '$name · $primary · $second '
        '${_unitName(distribution.secondaryUnit)}';
  }

  /// One entry of the "Most in" line. Only the [leading] book carries
  /// both counts; repeating the pair three times stops the line fitting
  /// a 240 px pane.
  String _topEntry(BookHits b, {required bool leading}) {
    final name = localeAwareBookName(b.englishBook, locale, version);
    final second = b.secondary;
    if (second == null || !leading) return '$name ${b.count}';
    return '$name ${b.count} ($second${_s('hitUnitTimesSuffix', '×')})';
  }

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final s = uiStrings;
    final top = topBooks(distribution);

    // Drawn from a sample, so not drawn. The listed verses stop at the
    // pipeline cap in canonical order, which means the bars would trace
    // where the list was cut rather than where the word lives — H3068
    // would show three books peaking in Exodus against a real 36 books
    // peaking in Jeremiah. Say why instead.
    if (distribution.partial) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Text(
          _s(
              'searchStatsTruncated',
              'No distribution: this result was cut at the '
                  '500-verse list limit, so a chart of it would show the '
                  'limit rather than the word.'),
          style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Testament split. Only meaningful when both sides have hits;
          // a solid single-colour bar says nothing worth the pixels.
          if (distribution.oldTestament > 0 && distribution.newTestament > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Row(
                      children: [
                        Expanded(
                          flex: distribution.oldTestament,
                          child: Container(height: 4, color: wb.link),
                        ),
                        Expanded(
                          flex: distribution.newTestament,
                          child: Container(
                              height: 4, color: wb.strongsLexical),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Was a hardcoded "OT … · NT …", which put English in
                  // a Chinese UI (#283's defect class) and named the
                  // corpora in terms #280 settled against: this project
                  // says 希伯来圣经 / 希腊圣经, not 旧约 / 新约.
                  Text(
                    '${s['oldTestamentShort']?[locale] ?? 'Hebrew'} '
                    '${distribution.oldTestament} · '
                    '${s['newTestamentShort']?[locale] ?? 'Greek'} '
                    '${distribution.newTestament}',
                    style: TextStyle(
                        fontSize: t.chrome, color: wb.mutedText),
                  ),
                ],
              ),
            ),

          // Per-book bars, canonical order left to right.
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: distribution.books.length,
              separatorBuilder: (_, __) => const SizedBox(width: 3),
              itemBuilder: (context, i) {
                final b = distribution.books[i];
                // Scale against the peak so the tallest bar fills the
                // strip; a floor keeps a single hit visible rather than
                // rendering as nothing.
                final h = distribution.peak == 0
                    ? 0.0
                    : (b.count / distribution.peak) * 22;
                return Tooltip(
                  message: _bookLabel(b),
                  child: InkWell(
                    onTap: onBookTap == null
                        ? null
                        : () => onBookTap!(b.englishBook),
                    child: SizedBox(
                      width: 7,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: h < 2 ? 2 : h,
                            decoration: BoxDecoration(
                              color: b.isOldTestament
                                  ? wb.link
                                  : wb.strongsLexical,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            // The unit is named ONCE, in the label, and governs every
            // number on the line. The heaviest book also carries its
            // count in the other unit, because that pair is what teaches
            // the distinction — and because on a tablet the tooltips
            // that carry it elsewhere never appear (there is no hover).
            '${_s('searchStatsTopIn', 'Most in ({unit})').replaceAll('{unit}', _unitName(distribution.unit))}: '
            '${[for (final (i, b) in top.indexed) _topEntry(b, leading: i == 0)].join(' · ')}'
            '  ·  ${distribution.bookCount} '
            '${s['searchStatsBooks']?[locale] ?? 'books'}',
            style:
                TextStyle(fontSize: t.chrome, color: wb.mutedText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
