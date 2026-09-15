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
