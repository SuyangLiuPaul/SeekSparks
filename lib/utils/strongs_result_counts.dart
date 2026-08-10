// 2026-08-09 (#295): what a Strong's result header is allowed to claim.
//
// The bundled concordance stores two different numbers per entry:
//
//   n  — occurrences across the whole Bible (H3068 = 6,521). Equal to
//        the sum of the per-book map `b`.
//   r  — the verses that contain at least one (H3068 = 5,522).
//
// The header printed `refs.length` and called it the total, so the two
// units were being conflated. Reporting both is also what BibleWorks
// does (help topic bwh16: its status line gives verses AND hits), and
// the distinction is real: G25 occurs 143 times in 110 verses.
//
// 2026-08-10 (v1.6.96): `r` used to stop at 500, and this file inferred
// truncation from a list that reached it. That inference is gone with
// the cap — both counts are now complete, and a header that still said
// "first 500 verses listed" would have been the new untruth.

/// What the header may state about one Strong's result.
class StrongsResultCounts {
  /// Verses actually listed on screen.
  final int verses;

  /// Bible-wide occurrences, or null when it must not be shown.
  final int? occurrences;

  /// The result stands for less than the query named, so [verses] is a
  /// floor rather than a count. The one surviving cause is a wildcard
  /// whose expansion was stopped at its limit.
  final bool truncated;

  const StrongsResultCounts({
    required this.verses,
    this.occurrences,
    this.truncated = false,
  });

  @override
  bool operator ==(Object other) =>
      other is StrongsResultCounts &&
      other.verses == verses &&
      other.occurrences == occurrences &&
      other.truncated == truncated;

  @override
  int get hashCode => Object.hash(verses, occurrences, truncated);

  @override
  String toString() =>
      'StrongsResultCounts(verses: $verses, occurrences: $occurrences, '
      'truncated: $truncated)';
}

/// Decide what the header may claim.
///
/// [versesShown] is what survived the `l` search limit. [occurrences] is
/// the entry's `n`, or null when the query was not a single number: a
/// boolean expression composes several entries and no occurrence total
/// exists for the combination. [incomplete] is passed by the boolean
/// path when a wildcard expansion was stopped short.
///
/// One deliberate refusal: under a search limit the occurrence count is
/// suppressed. It counts the whole Bible, and printing it beside a list
/// narrowed to Genesis would read as the scope's own total.
StrongsResultCounts strongsResultCounts({
  required int versesShown,
  int? occurrences,
  bool scoped = false,
  bool incomplete = false,
}) {
  if (scoped) {
    return StrongsResultCounts(verses: versesShown, truncated: incomplete);
  }
  return StrongsResultCounts(
    verses: versesShown,
    occurrences: occurrences,
    truncated: incomplete,
  );
}

/// Group [n] in thousands — 19859 → "19,859".
///
/// The counts this file exists to surface are five digits wide, and an
/// ungrouped 19859 is the kind of number a reader skims past.
String groupThousands(int n) {
  final digits = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}
