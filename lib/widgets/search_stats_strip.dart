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

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final s = uiStrings;
    final top = topBooks(distribution);

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
                  message:
                      '${localeAwareBookName(b.englishBook, locale, version)}'
                      ' · ${b.count}',
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
            '${s['searchStatsTop']?[locale] ?? 'Most in'}: '
            '${top.map((b) => '${localeAwareBookName(b.englishBook, locale, version)} ${b.count}').join(' · ')}'
            '  ·  ${distribution.books.length} '
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
