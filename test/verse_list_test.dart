import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/verse_list.dart';

VerseListEntry _e(String book, int c, int v, [String version = '']) =>
    VerseListEntry(VerseRef(book, c, v), version: version);

VerseList _list(List<VerseListEntry> entries) => VerseList(entries: entries);

/// A stand-in corpus: John 3 has 36 verses, Jude has 25, Psalm 117 has 2.
int _chapterLength(String book, int chapter) {
  if (book == 'John' && chapter == 3) return 36;
  if (book == 'Jude' && chapter == 1) return 25;
  if (book == 'Psalms' && chapter == 117) return 2;
  return 0;
}

void main() {
  group('VerseRef ordering', () {
    test('sorts canonically, not alphabetically', () {
      final refs = [
        const VerseRef('Revelation', 1, 1),
        const VerseRef('Genesis', 1, 1),
        const VerseRef('Matthew', 1, 1),
        const VerseRef('Malachi', 1, 1),
      ]..sort();
      expect(
        refs.map((r) => r.englishBook).toList(),
        ['Genesis', 'Malachi', 'Matthew', 'Revelation'],
      );
    });

    test('orders by book, then chapter, then verse', () {
      final refs = [
        const VerseRef('John', 3, 16),
        const VerseRef('John', 1, 1),
        const VerseRef('John', 3, 2),
        const VerseRef('Acts', 1, 1),
      ]..sort();
      expect(refs.map((r) => r.toString()).toList(), [
        'John 1:1',
        'John 3:2',
        'John 3:16',
        'Acts 1:1',
      ]);
    });

    test('unknown books sort to the end, not to the front', () {
      final refs = [
        const VerseRef('Enoch', 1, 1),
        const VerseRef('Genesis', 1, 1),
        const VerseRef('Revelation', 22, 21),
      ]..sort();
      expect(refs.last.englishBook, 'Enoch');
    });

    test('two unknown books still order deterministically', () {
      expect(const VerseRef('Baruch', 1, 1).compareTo(const VerseRef('Enoch', 1, 1)),
          lessThan(0));
      expect(const VerseRef('Enoch', 1, 1).compareTo(const VerseRef('Baruch', 1, 1)),
          greaterThan(0));
    });

    test('key matches the verseByRef / Verse.id shape', () {
      expect(const VerseRef('1 Corinthians', 13, 4).key, '1 Corinthians-13-4');
    });

    test('value equality ignores nothing — book, chapter and verse all count',
        () {
      expect(const VerseRef('John', 3, 16), const VerseRef('John', 3, 16));
      expect(const VerseRef('John', 3, 16), isNot(const VerseRef('John', 3, 17)));
      // Set membership is what every VLM operation is built on, so the
      // hashCode has to agree with the ==.
      final deduped = <VerseRef>{}
        ..add(const VerseRef('John', 3, 16))
        ..add(const VerseRef('John', 3, 16));
      expect(deduped.length, 1);
    });
  });

  group('Import appends — it does not sort or dedupe', () {
    // bwh27 separates these deliberately: after an import you can see
    // exactly what arrived, at the bottom, before merging it.
    test('addAll preserves order and keeps duplicates', () {
      final list = _list([_e('John', 3, 16)])
          .addAll([_e('Genesis', 1, 1), _e('John', 3, 16)]);
      expect(list.length, 3);
      expect(list.entries.map((e) => e.ref.toString()).toList(),
          ['John 3:16', 'Genesis 1:1', 'John 3:16']);
    });

    test('addAll of nothing returns the same list', () {
      final list = _list([_e('John', 3, 16)]);
      expect(identical(list.addAll(const []), list), isTrue);
    });
  });

  group('Edit ▸ Sort list — sorts AND dedupes in one operation', () {
    test('canonical order with duplicates removed', () {
      final sorted = _list([
        _e('John', 3, 16),
        _e('Genesis', 1, 1),
        _e('John', 3, 16),
        _e('Genesis', 1, 1),
        _e('Acts', 2, 38),
      ]).sortedAndDeduped();
      expect(sorted.entries.map((e) => e.ref.toString()).toList(),
          ['Genesis 1:1', 'John 3:16', 'Acts 2:38']);
    });

    test('the first occurrence wins, so its version survives', () {
      final sorted = _list([
        _e('John', 3, 16, 'bsb'),
        _e('John', 3, 16, 'cuvs-yhwh'),
      ]).sortedAndDeduped();
      expect(sorted.length, 1);
      expect(sorted.entries.single.version, 'bsb');
    });

    test('a selection survives the sort and is pruned of vanished dupes', () {
      final before = _list([
        _e('John', 3, 16),
        _e('Genesis', 1, 1),
        _e('John', 3, 16),
      ]).selectAll();
      final after = before.sortedAndDeduped();
      expect(after.length, 2);
      expect(after.selectedCount, 2);
    });
  });

  group('Selection is a layer, not a filter', () {
    final main = _list([
      _e('Genesis', 1, 1),
      _e('John', 3, 16),
      _e('Acts', 2, 38),
    ]);
    final other = _list([
      _e('John', 3, 16),
      _e('Romans', 8, 28),
    ]);

    test('selectAll / unselectAll', () {
      expect(main.selectAll().selectedCount, 3);
      expect(main.selectAll().unselectAll().selectedCount, 0);
    });

    test('toggle flips one ref', () {
      final t = main.toggle(const VerseRef('John', 3, 16));
      expect(t.selected, {const VerseRef('John', 3, 16)});
      expect(t.toggle(const VerseRef('John', 3, 16)).selected, isEmpty);
    });

    test('invert selects exactly the complement', () {
      final inverted =
          main.toggle(const VerseRef('John', 3, 16)).invertSelection();
      expect(inverted.selected, {
        const VerseRef('Genesis', 1, 1),
        const VerseRef('Acts', 2, 38),
      });
    });

    test('select common with the other list', () {
      expect(main.selectCommonWith(other).selected,
          {const VerseRef('John', 3, 16)});
    });

    test('select unique to this list', () {
      expect(main.selectUniqueTo(other).selected, {
        const VerseRef('Genesis', 1, 1),
        const VerseRef('Acts', 2, 38),
      });
    });

    test('common and unique partition the list', () {
      final common = main.selectCommonWith(other).selected;
      final unique = main.selectUniqueTo(other).selected;
      expect(common.intersection(unique), isEmpty);
      expect(common.union(unique), main.refs);
    });

    // The composition claim from the header comment — the reason
    // BibleWorks ships select-then-delete instead of set-op buttons.
    test('common + delete gives set DIFFERENCE', () {
      final difference = main.selectCommonWith(other).deleteSelected();
      expect(difference.entries.map((e) => e.ref.toString()).toList(),
          ['Genesis 1:1', 'Acts 2:38']);
    });

    test('unique + delete gives INTERSECTION', () {
      final intersection = main.selectUniqueTo(other).deleteSelected();
      expect(intersection.entries.map((e) => e.ref.toString()).toList(),
          ['John 3:16']);
    });

    test('common + invert + delete also gives intersection', () {
      final intersection =
          main.selectCommonWith(other).invertSelection().deleteSelected();
      expect(intersection.entries.map((e) => e.ref.toString()).toList(),
          ['John 3:16']);
    });

    test('deleteSelected clears the selection and is a no-op when empty', () {
      expect(main.deleteSelected().selectedCount, 0);
      expect(identical(main.deleteSelected(), main), isTrue);
    });

    test('selectedEntries follows list order, not selection order', () {
      final s = main
          .toggle(const VerseRef('Acts', 2, 38))
          .toggle(const VerseRef('Genesis', 1, 1));
      expect(s.selectedEntries.map((e) => e.ref.toString()).toList(),
          ['Genesis 1:1', 'Acts 2:38']);
    });

    test('selectedCount ignores a stale selection left by a delete', () {
      // Delete clears the selection, but a list built by hand can carry
      // a ref it no longer contains; selectedCount must not count it.
      final stale = VerseList(
        entries: [_e('Genesis', 1, 1)],
        selected: {const VerseRef('John', 3, 16)},
      );
      expect(stale.selected.length, 1);
      expect(stale.selectedCount, 0);
    });
  });

  group('Clear keeps the list identity', () {
    test('entries go, name and description stay', () {
      const named = VerseList(
        name: 'Suffering Servant',
        description: 'for the Advent series',
        entries: [VerseListEntry(VerseRef('Isaiah', 53, 1))],
      );
      final cleared = named.cleared();
      expect(cleared.isEmpty, isTrue);
      expect(cleared.name, 'Suffering Servant');
      expect(cleared.description, 'for the Advent series');
    });
  });

  group('Version is provenance, not identity', () {
    // The deliberate decision documented on VerseListEntry.version: we
    // have no verse maps, so we do not remap — but neither do we let a
    // version tag split one reference into two.
    test('the same reference from two versions is ONE ref for set ops', () {
      final a = _list([_e('Psalms', 51, 1, 'bsb')]);
      final b = _list([_e('Psalms', 51, 1, 'cuvs-yhwh')]);
      expect(a.selectCommonWith(b).selectedCount, 1);
      expect(a.selectUniqueTo(b).selectedCount, 0);
    });

    test('but the entry still remembers which version it came from', () {
      expect(_e('Psalms', 51, 1, 'bsb').version, 'bsb');
      expect(_e('Psalms', 51, 1, 'bsb') == _e('Psalms', 51, 1, 'cuvs-yhwh'),
          isFalse);
    });
  });

  group('Reference expansion', () {
    test('a single verse expands to itself', () {
      final refs = parseVerseListLine('John 3:16');
      expect(refs, [const VerseRef('John', 3, 16)]);
    });

    test('the range from the help file — Eph 2:8-10', () {
      final refs = parseVerseListLine('Eph 2:8-10');
      expect(refs.map((r) => r.toString()).toList(),
          ['Ephesians 2:8', 'Ephesians 2:9', 'Ephesians 2:10']);
    });

    test('a chapter expands only when the chapter length is known', () {
      expect(parseVerseListLine('Psalms 117'), isEmpty);
      final refs =
          parseVerseListLine('Psalms 117', chapterLength: _chapterLength);
      expect(refs, [
        const VerseRef('Psalms', 117, 1),
        const VerseRef('Psalms', 117, 2),
      ]);
    });

    test('a range is clamped to the real length of the chapter', () {
      final refs =
          parseVerseListLine('John 3:34-99', chapterLength: _chapterLength);
      expect(refs.length, 3);
      expect(refs.last, const VerseRef('John', 3, 36));
    });

    test('a runaway range is capped even with no chapter data', () {
      final refs = parseVerseListLine('John 3:1-99999');
      expect(refs.length, maxVersesInAChapter);
    });

    test('a reversed range does not produce an empty list', () {
      expect(parseVerseListLine('John 3:16-10'), [const VerseRef('John', 3, 16)]);
    });

    test('Chinese references parse and expand', () {
      final refs = parseVerseListLine('约 3:16-17');
      expect(refs, [
        const VerseRef('John', 3, 16),
        const VerseRef('John', 3, 17),
      ]);
    });

    test('a single-chapter book keeps its verses in chapter 1', () {
      final refs = parseVerseListLine('Jude 14-15');
      expect(refs, [
        const VerseRef('Jude', 1, 14),
        const VerseRef('Jude', 1, 15),
      ]);
    });

    test('non-contiguous compact refs expand to each listed verse', () {
      final parsed = parseReference('Gen 1:2,5');
      // The parser keeps only the first span of a comma list; the
      // document importer is what recovers the rest.
      expect(expandReference(parsed!), [const VerseRef('Genesis', 1, 2)]);
      expect(
        expandReference(const BibleReference(
          englishBook: 'Genesis',
          chapter: 1,
          verses: [2, 5, 7],
        )),
        [
          const VerseRef('Genesis', 1, 2),
          const VerseRef('Genesis', 1, 5),
          const VerseRef('Genesis', 1, 7),
        ],
      );
    });

    test('nonsense is not a reference', () {
      expect(parseVerseListLine('the quick brown fox'), isEmpty);
      expect(parseVerseListLine(''), isEmpty);
    });
  });

  group('Import ▸ From document', () {
    test('pulls every reference out of a chain, in order', () {
      final refs = parseVerseListDocument(
          'Isaiah 53; Psalm 22, Micah 5:2\nZechariah 11:12');
      expect(refs.map((r) => r.toString()).toList(), [
        'Micah 5:2',
        'Zechariah 11:12',
      ]);
      // Isaiah 53 and Psalm 22 are whole chapters: with no corpus to
      // say how long they are, they are dropped rather than guessed at.
    });

    test('whole chapters come through once the corpus is available', () {
      final refs = parseVerseListDocument('Psalms 117; John 3:16',
          chapterLength: _chapterLength);
      expect(refs.map((r) => r.toString()).toList(),
          ['Psalms 117:1', 'Psalms 117:2', 'John 3:16']);
    });

    test('prose with references embedded in it still yields them', () {
      final refs = parseVerseListDocument(
          'As we saw in John 3:16, and again in Romans 8:28, the point holds');
      expect(refs, contains(const VerseRef('Romans', 8, 28)));
    });

    test('duplicates are kept — an import appends verbatim', () {
      final refs = parseVerseListDocument('John 3:16; John 3:16');
      expect(refs.length, 2);
    });

    test('empty text yields nothing', () {
      expect(parseVerseListDocument('   \n\n  '), isEmpty);
    });
  });

  group('Search limits', () {
    final list = _list([_e('John', 3, 16), _e('Genesis', 1, 1)]);

    test('verseListKeys uses the corpus key shape', () {
      expect(verseListKeys(list), {'John-3-16', 'Genesis-1-1'});
    });

    test('a null limit means unrestricted and returns the input untouched', () {
      final items = ['John-3-16', 'Acts-2-38'];
      expect(identical(applySearchLimit(items, null, (s) => s), items), isTrue);
    });

    test('an EMPTY limit restricts to nothing — it is not "no limit"', () {
      expect(applySearchLimit(['John-3-16'], <String>{}, (s) => s), isEmpty);
    });

    test('filters to the members of the limit, preserving order', () {
      final items = ['Acts-2-38', 'John-3-16', 'Genesis-1-1'];
      expect(
        applySearchLimit(items, verseListKeys(list), (s) => s),
        ['John-3-16', 'Genesis-1-1'],
      );
    });
  });

  group('Round-trip', () {
    test('name, description, entries and versions survive JSON', () {
      const original = VerseList(
        name: 'Kingdom parables',
        description: 'Matthew 13 study',
        entries: [
          VerseListEntry(VerseRef('Matthew', 13, 44), version: 'bsb'),
          VerseListEntry(VerseRef('Matthew', 13, 45)),
        ],
      );
      final back = VerseList.fromJson(original.toJson());
      expect(back.name, original.name);
      expect(back.description, original.description);
      expect(back.entries, original.entries);
    });

    test('the selection is deliberately NOT persisted', () {
      final selected = _list([_e('John', 3, 16)]).selectAll();
      expect(selected.selectedCount, 1);
      expect(VerseList.fromJson(selected.toJson()).selectedCount, 0);
    });

    test('a malformed blob degrades to an empty list instead of throwing', () {
      expect(VerseList.fromJson(const {}).isEmpty, isTrue);
      expect(VerseList.fromJson(const {'entries': 'nope'}).isEmpty, isTrue);
      expect(
        VerseList.fromJson(const {
          'entries': [
            {'b': 'John', 'c': 3, 'v': 16},
            {'b': 'John', 'c': 3},
            {'b': '', 'c': 1, 'v': 1},
            {'b': 'John', 'c': 0, 'v': 1},
            'garbage',
          ],
        }).length,
        1,
      );
    });
  });

  group('Text export', () {
    test('one canonical reference per line, with the header', () {
      const list = VerseList(
        name: 'Advent',
        description: 'week 1',
        entries: [
          VerseListEntry(VerseRef('Isaiah', 53, 5)),
          VerseListEntry(VerseRef('John', 1, 14)),
        ],
      );
      expect(verseListToText(list),
          '# Advent\n# week 1\nIsaiah 53:5\nJohn 1:14\n');
    });

    test('exported text re-imports to the same references', () {
      const list = VerseList(entries: [
        VerseListEntry(VerseRef('Isaiah', 53, 5)),
        VerseListEntry(VerseRef('1 Corinthians', 13, 4)),
      ]);
      expect(parseVerseListDocument(verseListToText(list)),
          list.entries.map((e) => e.ref).toList());
    });

    test('the header lines do not come back as references', () {
      const list = VerseList(
        name: 'Advent',
        description: 'week 1',
        entries: [VerseListEntry(VerseRef('John', 1, 14))],
      );
      expect(parseVerseListDocument(verseListToText(list)),
          [const VerseRef('John', 1, 14)]);
    });
  });
}
