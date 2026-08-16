/// 2026-08-09: the Atlas index, pinned.
///
/// Some of these tests are about REAL gazetteer entries rather than
/// fixtures, because the interesting cases are all things the data
/// actually contains: two cities called Antioch, a name a reader will
/// type without its hyphen, Jerusalem's 755 references, and a book code
/// that reads like Nahum and is Jonah. A fixture that invented them
/// would pass while the shipped index failed.
library;

import 'dart:convert';
import 'dart:io';

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

  group('the reference ranking counts the scope, not the whole Bible', () {
    // Joshua's own shape, and the clearest of the 23 books the
    // whole-Bible ranking got wrong: the book is about crossing the
    // Jordan, and it opened with Jerusalem because Jerusalem is famous
    // everywhere else.
    final jordan = _p('Jordan', refs: <PlaceRef>[
      ..._refs('Joshua', 58),
      ..._refs('Genesis', 7),
    ]);
    final jerusalem = _p('Jerusalem', refs: <PlaceRef>[
      ..._refs('Joshua', 8),
      ..._refs('Psalms', 747),
    ]);
    final places = <BiblePlace>[jerusalem, jordan];

    test('scoped to Joshua, Joshua leads with the Jordan', () {
      final out = atlasIndex(places, scopeBooks: {'Joshua'});
      expect(out.map((p) => p.id).toList(), <String>['Jordan', 'Jerusalem']);
    });

    test('unscoped, the whole-Bible order is unchanged', () {
      expect(atlasIndex(places).map((p) => p.id).toList(),
          <String>['Jerusalem', 'Jordan']);
    });

    test('a tie inside the scope falls back to the whole-Bible count', () {
      final zion = _p('Zion', refs: <PlaceRef>[
        ..._refs('Esther', 1),
        ..._refs('Psalms', 40),
      ]);
      final zoar = _p('Zoar', refs: _refs('Esther', 1));
      expect(atlasIndex(<BiblePlace>[zoar, zion], scopeBooks: {'Esther'})
          .map((p) => p.id)
          .toList(),
          <String>['Zion', 'Zoar']);
    });

    test('a typed query still outranks the count', () {
      expect(atlasIndex(places, query: 'jeru', scopeBooks: {'Joshua'}).first.id,
          'Jerusalem');
    });
  });

  group('refCountInBooks', () {
    final teman = _p('Teman', refs: const <PlaceRef>[
      PlaceRef('Obadiah', 1, 9),
      PlaceRef('Jeremiah', 49, 7),
      PlaceRef('Jeremiah', 49, 20),
      PlaceRef('Amos', 1, 12),
    ]);

    test('counts only the references inside the scope', () {
      expect(refCountInBooks(teman, {'Obadiah'}), 1);
      expect(refCountInBooks(teman, {'Jeremiah'}), 2);
      expect(refCountInBooks(teman, {'Obadiah', 'Amos'}), 2);
      expect(refCountInBooks(teman, {'Ruth'}), 0);
    });

    test('no scope counts everything, so an unfiltered row is unchanged', () {
      for (final scope in <Set<String>?>[null, <String>{}]) {
        expect(refCountInBooks(teman, scope), teman.refs.length);
      }
    });

    test('it agrees with the partition the detail panel prints', () {
      for (final scope in <Set<String>>[
        {'Obadiah'},
        {'Jeremiah'},
        {'Ruth'},
      ]) {
        expect(refCountInBooks(teman, scope),
            partitionRefsByScope(teman.refs, scopeBooks: scope).inScopeCount,
            reason: 'scope $scope');
      }
    });
  });

  group('partitionRefsByScope', () {
    final refs = <PlaceRef>[
      const PlaceRef('Acts', 9, 36),
      const PlaceRef('Jonah', 1, 3),
      const PlaceRef('Acts', 10, 5),
      const PlaceRef('Joshua', 19, 46),
    ];

    test('no scope puts everything in scope and leaves nothing out', () {
      for (final scope in <Set<String>?>[null, <String>{}]) {
        final out = partitionRefsByScope(refs, scopeBooks: scope);
        expect(out.inScopeCount, refs.length);
        expect(out.elsewhere, isEmpty);
        expect(out.elsewhereCount, 0);
      }
    });

    test('a scope SPLITS the references instead of discarding half', () {
      // The whole of #319. Trimming would leave a reader unable to tell
      // "not in Jonah" from "nowhere in scripture" — the worse of the two
      // things they could believe.
      final out = partitionRefsByScope(refs, scopeBooks: {'Jonah'});
      expect(out.inScopeCount, 1);
      expect(out.elsewhereCount, 3);
      expect(out.inScope.single.englishBook, 'Jonah');
    });

    test('nothing is lost: the two halves always add up', () {
      for (final scope in <Set<String>>[
        {'Jonah'},
        {'Acts', 'Joshua'},
        {'Genesis'},
      ]) {
        final out = partitionRefsByScope(refs, scopeBooks: scope);
        expect(out.inScopeCount + out.elsewhereCount, refs.length,
            reason: 'scope $scope');
      }
    });

    test('a place the scope never names comes back empty on one side, '
        'not empty on both', () {
      final out = partitionRefsByScope(refs, scopeBooks: {'Genesis'});
      expect(out.inScope, isEmpty);
      expect(out.elsewhereCount, refs.length);
    });

    test('both halves are grouped in canonical order', () {
      final out = partitionRefsByScope(refs, scopeBooks: {'Acts'});
      expect(out.inScope.map((g) => g.englishBook).toList(), <String>['Acts']);
      expect(out.elsewhere.map((g) => g.englishBook).toList(),
          <String>['Joshua', 'Jonah']);
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

  group('every book, against the shipped gazetteer', () {
    final places = parseGazetteer(
      json.decode(File('assets/bible_places.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final books = <String>{
      for (final p in places)
        for (final r in p.refs) r.englishBook,
    };

    test('no book opens with a place it barely names', () {
      final wrong = <String>[];
      for (final b in books) {
        final scope = <String>{b};
        final list = atlasIndex(places, scopeBooks: scope);
        if (list.isEmpty) continue;
        final best = list
            .map((p) => refCountInBooks(p, scope))
            .reduce((a, b) => a > b ? a : b);
        if (refCountInBooks(list.first, scope) != best) wrong.add(b);
      }
      expect(wrong, isEmpty);
    });

    test('the books the whole-Bible ranking got wrong', () {
      String top(String book) =>
          atlasIndex(places, scopeBooks: <String>{book}).first.id;
      // Ranking on the whole-Bible count these opened with Jerusalem,
      // Jerusalem, Jerusalem and Tarshish. Jonah is the one worth pinning:
      // its code in the raw asset is `nah`, which reads like Nahum.
      expect(top('Esther'), 'Susa');
      expect(top('Joshua'), 'Jordan');
      expect(top('Jeremiah'), 'Babylon');
      expect(top('Jonah'), 'Nineveh');
      expect(top('Nahum'), 'Nineveh');
    });
  });
}
