/// bwh38's side-by-side synopsis — `docs/PARITY-BACKLOG.md` §3.5.
///
/// The row named the defect precisely: *"a reader compares two passages
/// by jumping between them instead of reading them beside each other,
/// which is the whole point of a synopsis"* — and parked the fix behind
/// #292, which closed on 2026-09-02.
///
/// The guards are about the SILENCES, because that is where a synopsis
/// misleads: a Gospel that does not record an event and an edition that
/// does not carry the passage are different facts, and a layout that
/// blurred them would make an argument from silence out of a missing
/// asset.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/services/synopsis_service.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/utils/synopsis_columns.dart';

SynopsisPassage passage(String book, {bool resolves = true}) =>
    SynopsisPassage(
      book: book,
      raw: '$book 1:1',
      reference: resolves
          ? BibleReference(englishBook: book, chapter: 1, verseStart: 1)
          : null,
    );

SynopsisEvent event(List<SynopsisPassage> passages, {bool gospel = true}) =>
    SynopsisEvent(
      id: 'e',
      title: const {'en': 'An event'},
      passages: passages,
      isGospelHarmony: gospel,
    );

void main() {
  group('order is the source\'s, not the canon\'s', () {
    test('columns come back in the order the entry lists them', () {
      // A Gospel harmony lists Matthew–Mark–Luke–John; an OT group lists
      // the primary narrative before its parallel. Both orders carry
      // meaning that re-sorting would throw away.
      final e = event([passage('Luke'), passage('Matthew')]);
      expect(synopsisColumns(e).map((c) => c.book), ['Luke', 'Matthew']);
    });

    test('the same book twice keeps both columns', () {
      // "Benjamin's Descendants" is 1 Chronicles 8:1-9:1 AND 9:34-44.
      // Keying by book dropped 37 of the 313 OT passages once already.
      final e = event([passage('1 Chronicles'), passage('1 Chronicles')]);
      expect(synopsisColumns(e), hasLength(2));
    });
  });

  group('Remove Blanks — bwh38\'s own toggle', () {
    final e = event([
      passage('Matthew'),
      passage('Mark', resolves: false),
      passage('Luke'),
    ]);

    test('off by default, because silence is a finding', () {
      // "Only in Matthew and Luke" is a fact about the passage. The
      // blanks are REMOVABLE, not removed.
      expect(synopsisColumns(e), hasLength(3));
    });

    test('on, it drops only the unresolvable ones', () {
      final kept = synopsisColumns(e, removeBlanks: true);
      expect(kept.map((c) => c.book), ['Matthew', 'Luke']);
    });

    test('the count is offered before the toggle is used', () {
      // So the reader can see what it costs, rather than watching the
      // screen quietly get narrower.
      expect(blankColumnCount(e), 1);
      expect(blankColumnCount(event([passage('Matthew')])), 0);
    });

    test('the book the reader is standing in is never dropped', () {
      // A synopsis that hid the passage the reader is IN would be
      // answering about somewhere else.
      final here = event([
        passage('Mark', resolves: false),
        passage('Luke'),
      ]);
      final kept =
          synopsisColumns(here, removeBlanks: true, keepBook: 'Mark');
      expect(kept.map((c) => c.book), ['Mark', 'Luke']);
    });

    test('and the keep is case-insensitive, like every book match here',
        () {
      final here = event([passage('Mark', resolves: false)]);
      expect(
        synopsisColumns(here, removeBlanks: true, keepBook: 'mark'),
        hasLength(1),
      );
    });
  });

  group('one passage is not a parallel', () {
    test('a single-passage entry is not comparable', () {
      // The Gospel harmony marks these "only in this Gospel", and that
      // sentence serves the reader better than one column pretending to
      // be a comparison.
      expect(isComparable(event([passage('John')])), isFalse);
      expect(isComparable(event([passage('John'), passage('Luke')])), isTrue);
    });

    test('an empty entry is not comparable either', () {
      expect(isComparable(event(const [])), isFalse);
    });
  });

  group('an unresolvable passage stays a column', () {
    test('because the source said this book records the event', () {
      // Dropping it because OUR parser could not place it would silently
      // narrow the reader's synopsis on our own limitation.
      final e = event([passage('Matthew'), passage('Mark', resolves: false)]);
      final cols = synopsisColumns(e);
      expect(cols, hasLength(2));
      expect(cols.last.resolves, isFalse);
      expect(cols.last.raw, 'Mark 1:1',
          reason: 'the reference the source printed is still shown');
    });
  });
}
