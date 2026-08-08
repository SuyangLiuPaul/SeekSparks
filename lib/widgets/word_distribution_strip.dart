/// 2026-08-08 (SeekSparks): where a word lives, at a glance — task #290,
/// BibleWorks bwh23 ("Analysis Window — The Search Statistics Tab").
///
/// The Stats tab already says how OFTEN each original word of the focused
/// verse occurs. A total is a number; WHERE those occurrences fall is an
/// observation, and it is the one that changes a reading. λόγος occurs
/// 330 times, which tells you it is common. That 65 of them are in Acts
/// and 40 in John, and that it is nearly absent from the Pentateuch,
/// tells you something about Acts.
///
/// Two renderings, because one cannot do both jobs:
///
///   * [WordDistributionStrip] — this file. A 66-slot bar strip with no
///     labels at all, in canonical order, drawn to whatever width the
///     pane gives it. Every book keeps a FIXED position whether or not
///     it has a hit, because with no labels the position is the only
///     thing naming the book. Drop the empty ones and every remaining
///     bar slides left, which turns "heavy in the Gospels" into noise.
///     bwh23 has this as the "Show Zeros" option; here it is not
///     optional, it is what makes the strip legible.
///
///   * `WordChartView` — the labelled chart in the centre pane, opened
///     by tapping this strip. There the labels exist, so the empty books
///     come OUT (bwh23 hides them by default too) and their absence is
///     stated as a number instead.
///
/// Drawn by a [CustomPainter] rather than 66 `Container`s. The Analysis
/// pane runs from 256 px (an iPad mini in Split View) to about 560, the
/// Stats tab stacks one of these per distinct word in the verse, and a
/// row of fixed-width boxes at the narrow end is precisely where a
/// RenderFlex overflow hides. A painter divides whatever width it is
/// handed and cannot overflow.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/search_stats.dart';

/// Height of the drawn strip. Tall enough that a ratio between two bars
/// is readable, short enough to sit under a word row without turning the
/// list into a stack of charts.
const double kWordStripHeight = 22.0;

class WordDistributionStrip extends StatelessWidget {
  const WordDistributionStrip({
    super.key,
    required this.distribution,
    this.currentBook,
    this.onTap,
    this.semanticsLabel,
  });

  /// Built with `includeEmpty: true` — see the library comment. A
  /// distribution without its empty books will still draw, it will just
  /// be drawing the wrong thing.
  final SearchDistribution distribution;

  /// Canonical English name of the book the reader is in, marked with a
  /// tick below the axis so the strip answers "and where am I in this?"
  final String? currentBook;

  final VoidCallback? onTap;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();
    final wb = WbColors.of(context);

    final strip = SizedBox(
      height: kWordStripHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: _StripPainter(
          books: distribution.books,
          peak: distribution.peak,
          currentBook: currentBook,
          hebrew: wb.link,
          greek: wb.strongsLexical,
          empty: wb.border,
          marker: wb.text,
        ),
      ),
    );

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: onTap == null
          ? strip
          : InkWell(
              onTap: onTap,
              // Square, per workbench_theme's rule. A rounded ink splash
              // here would be the only rounded thing in the pane.
              borderRadius: BorderRadius.zero,
              child: strip,
            ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.books,
    required this.peak,
    required this.currentBook,
    required this.hebrew,
    required this.greek,
    required this.empty,
    required this.marker,
  });

  final List<BookHits> books;
  final int peak;
  final String? currentBook;
  final Color hebrew;
  final Color greek;
  final Color empty;
  final Color marker;

  /// Room under the bars for the "you are here" tick.
  static const double _tickBand = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (books.isEmpty || size.width <= 0) return;

    // Bars share the width evenly with a hairline gap between them. At
    // 256 px and 66 books that is a 3.9 px slot; the gap is taken from
    // the slot rather than added to it, so the strip always ends exactly
    // at the pane edge however narrow it gets.
    final slot = size.width / books.length;
    final gap = slot > 3.0 ? 1.0 : 0.0;
    final barWidth = slot - gap;
    if (barWidth <= 0) return;

    final barTop = 0.0;
    final barBand = size.height - _tickBand - 1;
    final baseline = barTop + barBand;

    final paint = Paint()..style = PaintingStyle.fill;
    final safePeak = peak > 0 ? peak : 1;

    for (var i = 0; i < books.length; i++) {
      final b = books[i];
      final x = i * slot;

      if (b.count == 0) {
        // A one-pixel floor on the baseline. The empty books have to be
        // VISIBLE as empty — a blank gap reads as the strip ending, and
        // the reader would lose the canonical ruler the whole rendering
        // depends on.
        paint.color = empty;
        canvas.drawRect(
          Rect.fromLTWH(x, baseline - 1, barWidth, 1),
          paint,
        );
      } else {
        // Floor the drawn height at 2 px so a single occurrence in
        // Philemon is a bar rather than something indistinguishable from
        // an empty slot.
        final h = (b.count / safePeak) * barBand;
        final drawn = h < 2.0 ? 2.0 : h;
        paint.color = b.isOldTestament ? hebrew : greek;
        canvas.drawRect(
          Rect.fromLTWH(x, baseline - drawn, barWidth, drawn),
          paint,
        );
      }

      if (currentBook != null && b.englishBook == currentBook) {
        paint.color = marker;
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - _tickBand, barWidth, _tickBand - 1),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.peak != peak ||
      old.currentBook != currentBook ||
      old.hebrew != hebrew ||
      old.greek != greek ||
      old.empty != empty ||
      old.marker != marker ||
      !identical(old.books, books);
}
