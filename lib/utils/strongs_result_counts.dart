// 2026-08-09 (#295): what a Strong's result header is allowed to claim.
//
// The bundled concordance stores two different numbers per entry and the
// UI had been showing neither of them honestly:
//
//   n  — occurrences across the whole Bible, counted before any cap
//        (H3068 = 6,521). Equal to the sum of the per-book map `b`.
//   r  — the verse list, TRUNCATED by the build pipeline at 500.
//
// The header printed `refs.length`, so H3068 — the divine name — read
// "共 500 節" and there was nothing on screen to say the list stopped
// early. 123 of the 14,039 entries sit on that cap, hiding 160,564
// occurrences between them; the worst is G3588 at 19,859.
//
// Two counts is also what BibleWorks reports (help topic bwh16: its
// status line gives verses AND hits), and the distinction is real: G25
// occurs 143 times in 110 verses.

/// The pipeline's per-entry verse-list limit.
///
/// Nothing in `assets/strongs/concordance.json` marks an entry as
/// truncated, so list length hitting the cap is the only signal there
/// is. Verified against the asset: the longest `r` is exactly 500 and
/// 123 entries reach it.
const int kConcordanceRefCap = 500;

/// What the header may state about one Strong's result.
class StrongsResultCounts {
  /// Verses actually listed on screen.
  final int verses;

  /// Bible-wide occurrences, or null when it must not be shown.
  final int? occurrences;

  /// The verse list stopped at the cap, so more verses exist than are
  /// listed and the header has to say so.
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
/// [listedRefs] is the entry's verse list as bundled; [versesShown] is
/// what survived the `l` search limit. [occurrences] is the entry's `n`,
/// or null when the query was not a single number (a boolean expression
/// composes several entries, and no uncapped total exists for the
/// combination).
///
/// Two deliberate refusals:
///
/// * Under a search limit the occurrence count is suppressed. It counts
///   the whole Bible, and printing it beside a list narrowed to Genesis
///   would read as the scope's own total.
/// * `occurrences <= cap` never counts as truncation even at a full 500
///   verses, because verses can never outnumber occurrences — such an
///   entry is exactly one hit per verse and is complete.
StrongsResultCounts strongsResultCounts({
  required int listedRefs,
  required int versesShown,
  int? occurrences,
  bool scoped = false,
}) {
  if (scoped) return StrongsResultCounts(verses: versesShown);
  final truncated = listedRefs >= kConcordanceRefCap &&
      occurrences != null &&
      occurrences > kConcordanceRefCap;
  return StrongsResultCounts(
    verses: versesShown,
    occurrences: occurrences,
    truncated: truncated,
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
