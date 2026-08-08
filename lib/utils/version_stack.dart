/// 2026-08-08 (task #288): the Browse stack as an ORDERED list, and the
/// four operations a picker needs to edit one.
///
/// The order of the columns is part of how a comparison reads — put the
/// Greek next to the edition you are checking it against and the eye
/// does the work; put a third translation between them and it does not.
/// BibleWorks treats this as a first-class setting twice over: the
/// Parallel Versions Window (bwh38) builds its list with Add / delete /
/// **up** / **down** buttons, and `View | Version Display Order`
/// (bwh29) is a whole window of Move Up / Move Down / Move to Top /
/// Move to Bottom whose result is saveable to a named `.vdo` file.
///
/// SeekSparks already had the ordered list — `p bsb kjvs lxxwh` on the
/// command line sets it, and `WorkbenchProvider.parallelVersions` keeps
/// it — but the only pointer-driven editor was a column of checkboxes,
/// which cannot express an order, so it re-sorted the reader's stack
/// into registry order every time it was opened.
///
/// Two invariants, both inherited rather than invented here:
///
///   * **The reading version is always the first column and is never in
///     this list.** `applyDisplayVerb` seeds every stack with the search
///     version, the command line refuses `d -kjv` while the KJV is the
///     search version (`cannotRemoveSearchVersion`), and `command_pane`
///     strips it before storing. Same rule, one implementation.
///   * **A code this build cannot load never enters the stack.** Retired
///     codes are mapped to their successors by [loadableVersions]; that
///     is what stops a stale `cuv-yhwd` in SharedPreferences from asking
///     for an asset the host answers with `<!DOCTYPE`.
library;

import 'package:seeksparks/constants/bible_versions.dart'
    show loadableVersions;

/// The comparison list, cleaned: loadable codes only, retired codes
/// mapped forward, de-duplicated, [reading] removed, order preserved.
///
/// Every entry point into the stack goes through here, so "which codes
/// are legal" is answered once instead of at each of the six call sites
/// that write it.
List<String> normaliseComparisons(Iterable<String> codes, String reading) {
  final normalisedReading = loadableVersions([reading]);
  final read = normalisedReading.isEmpty ? null : normalisedReading.first;
  return [for (final c in loadableVersions(codes)) if (c != read) c];
}

/// What the Browse pane actually paints, top to bottom: the edition
/// being read first, then the comparisons in the reader's order.
///
/// Mirrors `WorkbenchProvider.displayVersions`. Duplicated as a pure
/// function so the picker can show the stack it is about to install
/// without reaching into the provider.
List<String> displayStack(List<String> comparisons, String reading) =>
    [reading, ...normaliseComparisons(comparisons, reading)];

/// Add [code] if absent, remove it if present.
///
/// Adding appends to the END rather than dropping the code into registry
/// order, because that is what `d nas` does (`applyDisplayVerb`'s
/// `displayAdd` and bwh38's Add button both append) — and because a
/// column that appears where the reader last looked is findable, while
/// one that appears somewhere in the middle has to be hunted for.
///
/// Removing the reading version is a no-op: it is not in this list, and
/// silently succeeding at nothing is better than throwing at a caller
/// that had no way to know.
List<String> toggleComparison(
    List<String> comparisons, String code, String reading) {
  final next = normaliseComparisons(comparisons, reading);
  if (next.remove(code)) return next;
  return normaliseComparisons([...next, code], reading);
}

/// Move the entry at [oldIndex] to [newIndex], where both index the list
/// as it will be AFTER the move.
///
/// Deliberately not the older convention. `ReorderableListView.onReorder`
/// reported `newIndex` as measured before the dragged row was lifted
/// out, so every caller had to subtract one on a downward drag — an
/// off-by-one that is invisible in an upward drag and wrong in every
/// downward one. Flutter deprecated that callback in favour of
/// `onReorderItem`, which does the adjustment itself, so this takes the
/// index at face value and the correction lives in exactly one place:
/// the framework's.
List<String> moveComparison(
    List<String> comparisons, int oldIndex, int newIndex) {
  final next = [...comparisons];
  if (oldIndex < 0 || oldIndex >= next.length) return next;
  final target = newIndex.clamp(0, next.length - 1);
  if (target == oldIndex) return next;
  next.insert(target, next.removeAt(oldIndex));
  return next;
}
