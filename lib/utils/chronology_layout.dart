/// Pure geometry and arithmetic for the Genesis chronology chart.
///
/// The chart's hard problem is the opposite of the kings chart's. There,
/// reigns spanned four orders of magnitude and the labels had to be
/// pushed apart. Here every life is the same order of magnitude — 148 to
/// 969 years — and there are only twenty of them, so the bars are easy.
/// What is hard is the thing the chart exists to show: **who was alive
/// at the same time as whom**, which is not in the data and has to be
/// computed from it.
///
/// That is worth more than it sounds. The generations in Genesis 5 look
/// like a list of strangers until the arithmetic is done, and then Adam
/// turns out to have still been alive when Lamech was born, and
/// Methuselah to have died in the year of the flood. Those are the facts
/// the printed chronologies were drawn to show, and none of them is
/// stated anywhere in the text — each is a consequence of adding up ages
/// the text does state.
///
/// Kept free of widgets because it is the part worth testing.
library;

/// Horizontal offset for [year] on an axis running from [firstYear] to
/// [lastYear] across [width] pixels.
double xForYear(int year, int firstYear, int lastYear, double width) {
  final span = lastYear - firstYear;
  if (span <= 0 || width <= 0) return 0;
  final t = (year - firstYear) / span;
  return (t * width).clamp(0.0, width);
}

/// Years during which the spans `[aBirth, aDeath]` and `[bBirth, bDeath]`
/// were both running.
///
/// Zero when they never met. Endpoints count as touching: a man born in
/// the year another died shares no years with him but was alive while he
/// was, on the same reckoning the chart draws, so the overlap is
/// measured on closed intervals and a bare touch yields 0 rather than a
/// negative.
int sharedYears(int aBirth, int aDeath, int bBirth, int bDeath) {
  final start = aBirth > bBirth ? aBirth : bBirth;
  final end = aDeath < bDeath ? aDeath : bDeath;
  final years = end - start;
  return years > 0 ? years : 0;
}

/// Whether someone born [birth] and dead [death] was alive in [year].
bool aliveAt(int birth, int death, int year) => year >= birth && year <= death;

/// Round year values to put ticks on, spaced at least [minGapPx] apart.
///
/// Picks the smallest of 100/200/250/500/1000 years that fits, so the
/// axis is labelled in the units a reader of these genealogies already
/// counts in, rather than in whatever the pixel width happened to
/// divide into.
List<int> axisTicks(
  int firstYear,
  int lastYear,
  double width, {
  double minGapPx = 70,
}) {
  final span = lastYear - firstYear;
  if (span <= 0 || width <= 0) return const [];
  const steps = [100, 200, 250, 500, 1000, 2000];
  var step = steps.last;
  for (final s in steps) {
    if (width * s / span >= minGapPx) {
      step = s;
      break;
    }
  }
  final out = <int>[];
  var y = (firstYear ~/ step) * step;
  if (y < firstYear) y += step;
  while (y <= lastYear) {
    out.add(y);
    y += step;
  }
  return out;
}

/// One man's overlap with another, for the contemporaries list.
class Contemporary {
  const Contemporary({
    required this.id,
    required this.years,
    required this.bornDuring,
    required this.diedDuring,
  });

  final String id;

  /// How many years the two lives ran alongside each other.
  final int years;

  /// He was born while the subject was already alive.
  final bool bornDuring;

  /// He died while the subject was still alive.
  final bool diedDuring;
}

/// Everyone in [lives] whose life touched the span `[birth, death]`,
/// longest overlap first.
///
/// [lives] maps id to `(birth, death)`. The subject is excluded by id.
/// Sorted by overlap rather than by generation because the question a
/// reader brings here is "who did he actually know", and the answer is
/// ordered by how long, not by who came first.
List<Contemporary> contemporaries(
  String subjectId,
  int birth,
  int death,
  Map<String, (int, int)> lives,
) {
  final out = <Contemporary>[];
  for (final e in lives.entries) {
    if (e.key == subjectId) continue;
    final (b, d) = e.value;
    final years = sharedYears(birth, death, b, d);
    if (years <= 0) continue;
    out.add(Contemporary(
      id: e.key,
      years: years,
      bornDuring: b > birth && b <= death,
      diedDuring: d >= birth && d < death,
    ));
  }
  out.sort((a, b) {
    final byYears = b.years.compareTo(a.years);
    return byYears != 0 ? byYears : a.id.compareTo(b.id);
  });
  return out;
}
