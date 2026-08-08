// 2026-08-09 (#295): resolving `d nas` to NASB.
//
// The command line's version verb matched only a version's exact code or
// its exact short label, so `d nas` — BibleWorks' own abbreviation, and
// the first example in the matcher's own doc comment — was refused with
// "no version named nas". A reader who knows BibleWorks types the
// abbreviation; a reader who does not is guessing anyway.

/// Resolve [raw] to a version code from [candidates], a code → short
/// label map.
///
/// Exact wins over prefix, so `kjv` stays KJV and never drifts to KJV+S.
/// A prefix must be unambiguous — `l` matches both LEB and LXX+WH and so
/// resolves to neither — and at least [minPrefix] characters long, which
/// keeps single letters available to the command verbs (`l`, `d`, `p`)
/// that are parsed on the same line.
///
/// Returns null when nothing matches, which is the caller's signal to
/// carry on with reference-parsing and then search.
String? matchVersionAbbreviation(
  String raw,
  Map<String, String> candidates, {
  int minPrefix = 3,
}) {
  final q = raw.trim().toLowerCase();
  if (q.isEmpty || q.contains(' ')) return null;

  for (final entry in candidates.entries) {
    if (entry.key.toLowerCase() == q || entry.value.toLowerCase() == q) {
      return entry.key;
    }
  }
  if (q.length < minPrefix) return null;

  String? hit;
  for (final entry in candidates.entries) {
    if (entry.key.toLowerCase().startsWith(q) ||
        entry.value.toLowerCase().startsWith(q)) {
      if (hit != null && hit != entry.key) return null; // ambiguous
      hit = entry.key;
    }
  }
  return hit;
}
