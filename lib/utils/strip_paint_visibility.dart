/// Whether a painted interval can touch the visible part of an axis.
///
/// Both ends are inclusive because zero-duration reigns and event ticks
/// still draw a point. Event callers pass the interval up to the next
/// tick, not just the current tick: a title that starts off-screen may
/// still have a readable tail inside the viewport.
bool stripPaintIntersects({
  required double start,
  required double end,
  required double visibleStart,
  required double visibleEnd,
  double padding = 0,
}) =>
    end + padding >= visibleStart && start - padding <= visibleEnd;

/// A ruler label may not reach the preceding label. Tick marks remain
/// even when their words do not fit; the separate endpoint row still
/// names the full extent of the axis.
bool stripPaintLabelFits({
  required double labelStart,
  required double previousLabelEnd,
  double gap = 8,
}) =>
    labelStart >= previousLabelEnd + gap;

/// A ruler label may not stand ON TOP OF an axis end.
///
/// 2026-09-16 「主后2000直接跳到2026年了」. The 250-year grid runs …主后
/// 1500, 主后1750, 主后2000 and then the axis stops at 主后2026 — five
/// pixels further on at whole-history fit. The end label is on its own
/// lower row and nothing actually overlaps, but read across, the ruler
/// appears to take a 26-year step after taking 250-year ones all the
/// way there. The far end is not affected in this corpus — 主前4200 is
/// 200 years from its nearest tick, which reads as two labels — but the
/// rule is written for both, because the axis bounds are data.
///
/// THE END WINS AND THE TICK LOSES ITS WORD. The ends 「say what the
/// chart's range IS」 — the wheel's rule, which this ruler inherited —
/// and a grid tick a reader can count to anyway is the cheaper of the
/// two to give up. Its MARK stays, so the 250-year rhythm is unbroken.
///
/// THE TEST IS DISTANCE, NOT OVERLAP. Two rows cannot collide, so
/// asking whether the boxes intersect answers the wrong question and
/// answers it far too often: the right-aligned 主后2026 reaches back
/// over 主后1750 as well, and 主后1750 is not confusing anybody. What
/// confuses is two different years labelled at the same place. So a
/// tick gives way only when the axis end falls inside the tick's own
/// word — [halfWidth] either side of its mark, plus a little air.
bool stripTickLabelClearsEnds({
  required double tickX,
  required double halfWidth,
  required List<double> endXs,
  double gap = 8,
}) =>
    !endXs.any((e) => (tickX - e).abs() < halfWidth + gap);
