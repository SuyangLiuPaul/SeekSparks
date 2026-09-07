/// Laying a synopsis out as columns — bwh38, and the last thing
/// `docs/PARITY-BACKLOG.md` §3.5 was waiting on.
///
/// The row said what was missing in one sentence: *"Ours is a sheet of
/// tappable chips, so a reader compares two passages by jumping between
/// them instead of reading them beside each other, which is the whole
/// point of a synopsis."* It also parked the fix behind #292, on the
/// grounds that the Kings/Chronicles parallel was about to acquire a
/// Resource of its own and a tab built first would be the wrong home.
/// **#292 closed on 2026-09-02**, so the gate is lifted and this is the
/// re-decision it asked for.
///
/// ## What a synopsis column has to be able to say
///
/// bwh38 lays one Browse column per passage and offers a "Remove
/// Blanks" toggle. The toggle exists because of the shape of the data,
/// not as a preference: a Gospel event recorded by two evangelists and
/// not the other two produces two columns of text and two of nothing,
/// and a reader comparing Matthew with Luke does not want half the
/// screen spent saying that Mark is silent.
///
/// But the silence is itself a finding — "only in John" is a fact about
/// the passage — so the blank columns are removable, not removed. Which
/// is why this is a function over the event rather than a filter baked
/// into the loader.
///
/// Flutter-free: this decides what the columns ARE. Drawing them, and
/// fetching each passage's verses, is the pane's job.
library;

import 'package:seeksparks/services/synopsis_service.dart'
    show SynopsisEvent, SynopsisPassage;

/// One column of a synopsis: a passage, and whether it has any text.
class SynopsisColumn {
  const SynopsisColumn({
    required this.passage,
    required this.resolves,
  });

  final SynopsisPassage passage;

  /// False when the source names a passage whose reference does not
  /// parse. Kept as a column rather than dropped: the source said this
  /// book records the event, and hiding that because our parser could
  /// not place it would silently narrow the reader's synopsis.
  final bool resolves;

  String get book => passage.book;
  String get raw => passage.raw;
}

/// The columns for [event], in the order the source lists them.
///
/// Order is the source's, not the canon's: a Gospel harmony lists
/// Matthew–Mark–Luke–John and an Old Testament group lists the primary
/// narrative before its parallel, and both orders carry meaning that
/// re-sorting would throw away.
///
/// [removeBlanks] drops the columns with no resolvable passage — bwh38's
/// own toggle. The event's own book is never dropped, even when it does
/// not resolve: a synopsis that hid the passage the reader is standing
/// in would be answering about somewhere else.
List<SynopsisColumn> synopsisColumns(
  SynopsisEvent event, {
  bool removeBlanks = false,
  String? keepBook,
}) {
  final all = [
    for (final p in event.passages)
      SynopsisColumn(passage: p, resolves: p.reference != null),
  ];
  if (!removeBlanks) return all;
  return [
    for (final c in all)
      if (c.resolves ||
          (keepBook != null && c.book.toLowerCase() == keepBook.toLowerCase()))
        c,
  ];
}

/// How many columns removing the blanks would take away.
///
/// Printed beside the toggle so a reader can see what it costs before
/// they use it — the difference between "3 of 4 Gospels" and a screen
/// that quietly became narrower.
int blankColumnCount(SynopsisEvent event) =>
    event.passages.where((p) => p.reference == null).length;

/// True when this event is worth laying out side by side at all.
///
/// One passage is not a parallel. The Gospel harmony marks such entries
/// as "only in this Gospel" and the reader is better served by that
/// sentence than by a single column pretending to be a comparison.
bool isComparable(SynopsisEvent event) => event.passages.length > 1;
