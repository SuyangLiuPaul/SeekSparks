/// 2026-08-09: the Atlas index, pinned.
///
/// Two of these tests are about REAL gazetteer entries rather than
/// fixtures, because the interesting cases are all things the data
/// actually contains: two cities called Antioch, a name a reader will
/// type without its hyphen, and Jerusalem's 755 references. A fixture
/// that invented them would pass while the shipped index failed.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/atlas_index.dart';

BiblePlace _p(
  String id, {
  int? ordinal,
  String? simplified,
  String? traditional,
  double? lat,
  double? lon,
  List<PlaceRef> refs = const <PlaceRef>[],
}) =>
    BiblePlace(
      id: id,
      name: id,
      ordinal: ordinal,
      simplified: simplified,
      traditional: traditional,
      lat: lat,
      lon: lon,
      refs: refs,
    );

List<PlaceRef> _refs(String book, int count) =>
    <PlaceRef>[for (var i = 1; i <= count; i++) PlaceRef(book, 1, i)];

void main() {
  group('normalisePlaceQuery', () {
    test('folds case and drops the punctuation the gazetteer is full of',
        () {
      expect(normalisePlaceQuery('Baal-zephon'), 'baalzephon');
      expect(normalisePlaceQuery("Solomon's"), 'solomons');
      expect(normalisePlaceQuery('  KIRIATH-JEARIM '), 'kiriathjearim');
    });

    test('keeps Han characters as themselves', () {
      expect(normalisePlaceQuery('耶路撒冷'), '耶路撒冷');
      // A reader pasting a name out of a Chinese Bible brings the
      // punctuation with it.
      expect(normalisePlaceQuery('耶路撒冷、'), '耶路撒冷');
    });

    test('digits survive, because the ordinal is part of the id', () {
      expect(normalisePlaceQuery('Antioch 2'), 'antioch2');
    });
  });

  group('placeMatchRank', () {
    final jerusalem =
        _p('Jerusalem', simplified: '耶路撒冷', traditional: '耶路撒冷');

    test('exact beats prefix beats substring', () {
      expect(placeMatchRank(jerusalem, 'jerusalem'), kPlaceMatchExact);
      expect(placeMatchRank(jerusalem, 'jeru'), kPlaceMatchPrefix);
      expect(placeMatchRank(jerusalem, 'salem'), kPlaceMatchSubstring);
      expect(placeMatchRank(jerusalem, 'nineveh'), kPlaceMatchNone);
    });

    test('an empty query matches everything at the best rank', () {
      expect(placeMatchRank(jerusalem, ''), kPlaceMatchExact);
    });

    test('all three scripts are searched whatever the reader is reading',
        () {
      // Deliberately asymmetric with DISPLAY, which follows the reading
      // version (#283). Finding is not reading: a CUVS reader who knows
      // a site as "Ashkelon" from a commentary should not have to switch
      // editions to look it up.
      expect(placeMatchRank(jerusalem, '耶路撒冷'), kPlaceMatchExact);
      expect(placeMatchRank(jerusalem, '耶路'), kPlaceMatchPrefix);
    });

    test('the best rank across the names wins, not the first tried', () {
      // `aphek` merely CONTAINS "ek" while the second name STARTS with
      // it. Stopping at the first candidate would file the entry with
      // the substring hits and bury it.
      final p = _p('Aphek', simplified: 'Ekron');
      expect(placeMatchRank(p, 'ek'), kPlaceMatchPrefix);
    });
  });

  group('placeIsInBooks', () {
    final joppa = _p('Joppa', refs: [
      const PlaceRef('Jonah', 1, 3),
      const PlaceRef('Acts', 9, 36),
    ]);

    test('null and empty both mean NO LIMIT, not "nothing"', () {
      // Same convention `search_scope.dart` uses, and the reason the
      // picker cannot signal cancel with an empty set.
      expect(placeIsInBooks(joppa, null), isTrue);
      expect(placeIsInBooks(joppa, <String>{}), isTrue);
    });

    test('one reference inside the scope is enough', () {
      expect(placeIsInBooks(joppa, {'Acts'}), isTrue);
      expect(placeIsInBooks(joppa, {'Genesis'}), isFalse);
    });
  });

  group('atlasIndex', () {
    final places = <BiblePlace>[
      _p('Dan', refs: _refs('Judges', 50)),
      _p('Jordan', refs: _refs('Joshua', 180)),
      _p('Daniel-town', refs: _refs('Genesis', 2)),
      _p('Zoar', refs: _refs('Genesis', 10)),
    ];

    test('prefix outranks substring even when the substring is bigger', () {
      // Jordan has 180 references to Dan's 50 and would win any
      // popularity contest. `dan` is still asking for Dan.
      final out = atlasIndex(places, query: 'dan');
      expect(out.first.id, 'Dan');
      expect(out.map((p) => p.id), contains('Jordan'));
    });

    test('within a rank the more-referenced place wins', () {
      final out = atlasIndex(places, query: 'dan');
      final ids = out.map((p) => p.id).toList();
      // Both are prefix hits on "dan"; Dan carries 50 refs, Daniel-town 2.
      expect(ids.indexOf('Dan'), lessThan(ids.indexOf('Daniel-town')));
    });

    test('ranking outranks the sort order', () {
      // Alphabetically Daniel-town precedes Jordan and Zoar. An exact
      // hit must not be buried under A–Z.
      final out = atlasIndex(places, query: 'zoar', sort: AtlasSort.name);
      expect(out.single.id, 'Zoar');
    });

    test('A–Z is alphabetical when nothing is typed', () {
      final out = atlasIndex(places, sort: AtlasSort.name);
      expect(out.map((p) => p.id).toList(),
          <String>['Dan', 'Daniel-town', 'Jordan', 'Zoar']);
    });

    test('by-references is the default and is descending', () {
      final out = atlasIndex(places);
      expect(out.map((p) => p.id).toList(),
          <String>['Jordan', 'Dan', 'Zoar', 'Daniel-town']);
    });

    test('the scope filters the LIST, not just the counts', () {
      final out = atlasIndex(places, scopeBooks: {'Genesis'});
      expect(out.map((p) => p.id).toSet(), <String>{'Zoar', 'Daniel-town'});
    });
  });

  group('groupRefsByBook', () {
    final refs = <PlaceRef>[
      const PlaceRef('Acts', 9, 36),
      const PlaceRef('Jonah', 1, 3),
      const PlaceRef('Acts', 10, 5),
      const PlaceRef('Acts', 9, 38),
      const PlaceRef('Joshua', 19, 46),
    ];

    test('books come back in canonical order, not alphabetical', () {
      final out = groupRefsByBook(refs);
      expect(out.map((g) => g.englishBook).toList(),
          <String>['Joshua', 'Jonah', 'Acts']);
    });

    test('references inside a book are in chapter then verse order', () {
      final acts = groupRefsByBook(refs)
          .firstWhere((g) => g.englishBook == 'Acts');
      expect(acts.refs.map((r) => '${r.chapter}:${r.verse}').toList(),
          <String>['9:36', '9:38', '10:5']);
    });

    test('the scope filters here, so the header and the rows agree', () {
      final out = groupRefsByBook(refs, scopeBooks: {'Acts'});
      expect(out.length, 1);
      expect(out.single.refs.length, 3);
    });
  });

  group('labelPriority', () {
    final jerusalem = _p('Jerusalem', refs: _refs('Psalms', 755));
    final joppa = _p('Joppa', refs: _refs('Acts', 10));
    final tarshish = _p('Tarshish', refs: _refs('Jonah', 28));
    final nineveh = _p('Nineveh', refs: _refs('Jonah', 18));

    test('selected first, then the emphasised layer, then context', () {
      final out = labelPriority(
        <BiblePlace>[joppa, tarshish],
        <BiblePlace>[jerusalem, nineveh],
        selectedId: 'Nineveh',
      );
      expect(out.map((p) => p.id).toList(),
          <String>['Nineveh', 'Tarshish', 'Joppa', 'Jerusalem']);
    });

    test('the emphasised layer outranks a far more-referenced context '
        'place', () {
      // This is the defect the passage map shipped with: it claimed the
      // CONTEXT layer's label rectangles first, so a place merely
      // elsewhere in the chapter could take the label off the place the
      // verse itself names.
      final out = labelPriority(
        <BiblePlace>[joppa],
        <BiblePlace>[jerusalem],
      );
      expect(out.first.id, 'Joppa');
    });

    test('within a layer the more-referenced place wins', () {
      final out = labelPriority(
        <BiblePlace>[nineveh, tarshish],
        const <BiblePlace>[],
      );
      expect(out.map((p) => p.id).toList(), <String>['Tarshish', 'Nineveh']);
    });

    test('a place in both layers is listed once', () {
      final out = labelPriority(
        <BiblePlace>[joppa],
        <BiblePlace>[joppa, jerusalem],
      );
      expect(out.where((p) => p.id == 'Joppa').length, 1);
    });
  });
}
