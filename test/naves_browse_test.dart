/// Nave's browse logic, tested without a bundle.
///
/// The cases that matter here are the ones a widget test would pass
/// straight through: a count that reports what it HANDED BACK rather than
/// what it FOUND, and an outline that walks into the wrong branch when a
/// depth level is skipped.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/naves_browse.dart';

void main() {
  group('matchHeadwords', () {
    const heads = ['ANGER', 'BROTHERLY LOVE', 'LOVE', 'LOVE OF GOD', 'MALICE'];

    test('prefix matches rank above contained ones', () {
      final hits = matchHeadwords(heads, 'love');
      expect(hits.map((h) => heads[h.topicId]),
          ['LOVE', 'LOVE OF GOD', 'BROTHERLY LOVE']);
      expect(hits.map((h) => h.prefix), [true, true, false]);
    });

    test('a contained match is kept, never dropped', () {
      expect(matchHeadwords(heads, 'BROTHERLY').single.topicId, 1);
    });

    test('an empty query matches nothing rather than everything', () {
      expect(matchHeadwords(heads, '   '), isEmpty);
    });
  });

  group('searchLineText', () {
    final lines = {
      2: ['the love of God', 'love one another'],
      0: ['anger is not love'],
      1: ['nothing here'],
    };

    test('ordered by topic id, then by line', () {
      final r = searchLineText(lines, 'love');
      expect(r.hits.map((h) => '${h.topicId}:${h.lineIndex}'),
          ['0:0', '2:0', '2:1']);
    });

    test('total counts every match, not the ones handed back', () {
      final r = searchLineText(lines, 'love', limit: 1);
      expect(r.hits.length, 1);
      expect(r.total, 3);
      expect(r.truncated, isTrue);
    });

    test('an uncapped result does not claim to be truncated', () {
      expect(searchLineText(lines, 'love').truncated, isFalse);
    });

    test('no match is a zero total, not an absent one', () {
      final r = searchLineText(lines, 'despond');
      expect(r.total, 0);
      expect(r.hits, isEmpty);
    });
  });

  group('letterStarts', () {
    test('records the first index of each letter present', () {
      final s = letterStarts(['ANGER', 'ANXIETY', 'BAAL', 'ZEAL']);
      expect(s, {'A': 0, 'B': 2, 'Z': 3});
    });

    test('offers no letter the list cannot honour', () {
      expect(letterStarts(['ANGER']).keys, ['A']);
    });

    test('anything outside A-Z files under #', () {
      expect(letterStarts(['1 KINGS', 'ANGER']), {'#': 0, 'A': 1});
    });
  });

  group('descendantCount', () {
    test('counts the whole subtree, not the immediate children', () {
      expect(descendantCount([1, 2, 3, 2, 1], 0), 3);
    });

    test('a leaf has none, and an index out of range is not a crash', () {
      expect(descendantCount([1, 2, 3, 2, 1], 2), 0);
      expect(descendantCount([1, 2], 9), 0);
    });
  });

  group('ancestorIndices', () {
    test('walks the whole path outermost first', () {
      expect(ancestorIndices([1, 2, 3, 2, 1], 2), [0, 1]);
    });

    // The trap the function exists for: matching only on `depth - 1`
    // would step over the depth-1 line at index 3 and keep walking back
    // into the previous branch.
    test('a skipped depth level does not send it into the wrong branch', () {
      expect(ancestorIndices([1, 2, 3, 1, 3], 4), [3]);
    });

    test('a top-level line hangs beneath nothing', () {
      expect(ancestorIndices([1, 2], 0), isEmpty);
    });
  });

  group('outlineRows', () {
    const depths = [1, 2, 3, 2, 1];

    test('collapsed, only the top level shows and says what it hides', () {
      final rows = outlineRows(depths, {});
      expect(rows.map((r) => r.lineIndex), [0, 4]);
      expect(rows.first.hidden, 3);
      expect(rows.first.hasChildren, isTrue);
      expect(rows.first.expanded, isFalse);
      expect(rows.last.hasChildren, isFalse);
    });

    test('expanding one line reveals its children, not its grandchildren', () {
      final rows = outlineRows(depths, {0});
      expect(rows.map((r) => r.lineIndex), [0, 1, 3, 4]);
      expect(rows[0].expanded, isTrue);
      expect(rows[0].hidden, 0);
      expect(rows[1].hidden, 1);
    });

    test('a flat topic is left exactly as Nave wrote it', () {
      final rows = outlineRows([1, 1, 1], {});
      expect(rows.map((r) => r.lineIndex), [0, 1, 2]);
      expect(rows.every((r) => !r.hasChildren), isTrue);
    });
  });

  test('expandedForLine opens the path to a line found by search', () {
    // Opening on line 2 must show it, so both lines it hangs beneath
    // have to be open — and nothing else.
    expect(expandedForLine([1, 2, 3, 2, 1], 2), {0, 1});
    expect(expandedForLine([1, 2, 3, 2, 1], 0), isEmpty);
  });
}
