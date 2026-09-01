/// #320: joining the picture database to the gazetteer.
///
/// The corpus group is the point of this file. #320 made the feature
/// conditional on measuring the join rate first, so the measurement is
/// frozen here rather than quoted in a commit message: if a plate is
/// added or a caption edited and the join moves, this says so.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/place_illustrations.dart';

BibleMap _m(
  String id, {
  Map<String, List<int>> books = const {},
  String en = '',
  String descEn = '',
}) =>
    BibleMap(
      id: id,
      title: {'en': en, 'zh-Hans': '', 'zh-Hant': ''},
      description: {'en': descEn, 'zh-Hans': '', 'zh-Hant': ''},
      books: books,
      file: '$id.jpg',
    );

BiblePlace _p(String name, List<PlaceRef> refs, {int? ordinal}) => BiblePlace(
      id: ordinal == null ? name : '$name $ordinal',
      name: name,
      ordinal: ordinal,
      simplified: null,
      traditional: null,
      lat: 0,
      lon: 0,
      refs: refs,
    );

void main() {
  group('the name half', () {
    test('a whole word matches, a substring does not', () {
      final cana = _p('Cana', [const PlaceRef('John', 2, 1)]);
      final onCana = _m('a', en: 'The Marriage at Cana',
          books: {'John': [2, 2]});
      final onCanaan = _m('b', en: 'The Grapes of Canaan',
          books: {'John': [2, 2]});
      expect(illustrationNamesPlace(onCana, cana), isTrue);
      expect(illustrationNamesPlace(onCanaan, cana), isFalse);
    });

    test('the boundary is Unicode, so Dor is not inside Doré', () {
      // An ASCII `(?![A-Za-z])` boundary treats é as a separator and
      // attached all 145 Doré plates to the town of Dor.
      final dor = _p('Dor', [const PlaceRef('Joshua', 11, 2)]);
      final dore = _m('a', en: 'Israel Crosses the Jordan (Doré)',
          books: {'Joshua': [11, 11]});
      expect(illustrationNamesPlace(dore, dor), isFalse);
    });

    test('the description counts, not only the title', () {
      final joppa = _p('Joppa', [const PlaceRef('Acts', 10, 5)]);
      final m = _m('a',
          en: 'Peter on the Housetop',
          descEn: 'Peter prays on the roof of the tanner at Joppa.',
          books: {'Acts': [10, 10]});
      expect(illustrationNamesPlace(m, joppa), isTrue);
    });

    test('an ambiguous name is refused outright', () {
      // `On` is a city in Genesis 41 and the commonest English
      // preposition; without the guard it is a whole word in 51 captions.
      final on = _p('On', [const PlaceRef('Genesis', 41, 45)]);
      final m = _m('a', en: 'Joseph on the Throne',
          books: {'Genesis': [41, 41]});
      expect(illustrationNamesPlace(m, on), isFalse);
      expect(placeIllustrations(on, [m]).total, 0);
    });
  });

  group('the chapter half', () {
    final cyrene = _p('Cyrene', [const PlaceRef('Acts', 11, 20)]);

    test('a caption match outside the plate\'s chapters is refused', () {
      final m = _m('a', en: 'Simon of Cyrene', books: {'Matthew': [27, 27]});
      expect(illustrationNamesPlace(m, cyrene), isTrue);
      expect(placeIllustrations(cyrene, [m]).total, 0);
    });

    test('a range covers the chapters between its ends', () {
      final m = _m('a', en: 'Cyrene', books: {'Acts': [9, 13]});
      expect(placeIllustrations(cyrene, [m]).total, 1);
    });
  });

  group('scope', () {
    final bethlehem = _p('Bethlehem', const [
      PlaceRef('Ruth', 1, 1),
      PlaceRef('Luke', 2, 4),
    ]);
    final plates = [
      _m('ruth', en: 'Ruth in Bethlehem', books: {'Ruth': [1, 4]}),
      _m('luke', en: 'Bethlehem', books: {'Luke': [2, 2]}),
    ];

    test('with no scope, everything is drawn', () {
      final r = placeIllustrations(bethlehem, plates);
      expect(r.inScope.map((m) => m.id), ['ruth', 'luke']);
      expect(r.total, 2);
    });

    test('a scope narrows what is drawn but not the total', () {
      final r = placeIllustrations(bethlehem, plates,
          scopeBooks: {'Luke'});
      expect(r.inScope.map((m) => m.id), ['luke']);
      // The header prints "1 / 2" off these two, so a reader can see the
      // scope is holding one back rather than that none exists (#319).
      expect(r.total, 2);
    });

    test('an empty scope is no limit, not nothing', () {
      expect(placeIllustrations(bethlehem, plates, scopeBooks: {}).total, 2);
    });

    test('a scope can empty the strip while the plates still exist', () {
      // The case the panel must not render as silence: `total` survives
      // so the header can say "0 / 2" instead of disappearing and
      // implying the place has no pictures at all.
      final r = placeIllustrations(bethlehem, plates, scopeBooks: {'Micah'});
      expect(r.inScope, isEmpty);
      expect(r.total, 2);
    });
  });

  test('the strip walks scripture in order', () {
    final place = _p('Zion', const [
      PlaceRef('Revelation', 14, 1),
      PlaceRef('Genesis', 14, 18),
      PlaceRef('Matthew', 21, 5),
    ]);
    final plates = [
      _m('c', en: 'Zion', books: {'Revelation': [14, 14]}),
      _m('a', en: 'Zion', books: {'Genesis': [14, 14]}),
      _m('b', en: 'Zion', books: {'Matthew': [21, 21]}),
    ];
    expect(placeIllustrations(place, plates).inScope.map((m) => m.id),
        ['a', 'b', 'c']);
  });

  group('the shipped corpus', () {
    late List<BiblePlace> places;
    late List<BibleMap> plates;

    setUpAll(() {
      places = parseGazetteer(
        jsonDecode(File('assets/bible_places.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      plates = (jsonDecode(File('assets/maps_index.json').readAsStringSync())
              as List)
          .map((e) => BibleMap.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    PlaceIllustrations forId(String id) =>
        placeIllustrations(places.firstWhere((p) => p.id == id), plates);

    test('the measured join rate', () {
      var joined = 0;
      var pairs = 0;
      final distinct = <String>{};
      for (final p in places) {
        final r = placeIllustrations(p, plates);
        if (r.total == 0) continue;
        joined++;
        pairs += r.total;
        distinct.addAll(r.inScope.map((m) => m.id));
      }
      // 79 of 1,266 places — 6.2%. All 218 pairs were read by hand before
      // the feature shipped; moving these numbers means re-reading the
      // ones that changed, not editing the expectation.
      expect(joined, 79);
      expect(pairs, 218);
      expect(distinct.length, 149);
      expect(places.length, 1266);
      expect(plates.length, 1192);
    });

    test('how much of the join a scope can hide', () {
      // The size of the case the panel prints "0 / n" for. If this went
      // to zero the header branch would be dead code; while it is 292 a
      // strip that vanished under a scope would be telling 56 places'
      // readers that no picture of them exists. Counted by id, the unit
      // the 79 above uses — by NAME it is 48, because the ordinal groups
      // share a name and check 38 says nothing can tell them apart.
      var pairs = 0;
      final hidden = <String>{};
      for (final p in places) {
        if (placeIllustrations(p, plates).total == 0) continue;
        for (final b in <String>{for (final r in p.refs) r.englishBook}) {
          final r = placeIllustrations(p, plates, scopeBooks: {b});
          if (r.inScope.isEmpty && r.total > 0) {
            pairs++;
            hidden.add(p.id);
          }
        }
      }
      expect(pairs, 292);
      expect(hidden.length, 56);
    });

    test('every excluded name is real, and costs nothing today', () {
      final byName = {for (final p in places) p.name};
      for (final n in kAmbiguousPlaceNames) {
        // A typo here would silently protect nothing.
        expect(byName, contains(n), reason: '$n is not a gazetteer name');
      }
      for (final p in places) {
        if (!kAmbiguousPlaceNames.contains(p.name)) continue;
        expect(placeIllustrations(p, plates).total, 0);
      }
    });

    test('the plates a chapter-only join would have got wrong', () {
      // Each of these places overlaps the plate's chapter range and is
      // not named by it. They are the reason the join is not "which
      // pictures come from a chapter that mentions this place".
      expect(forId('Ziph 1').inScope.map((m) => m.title['en']),
          isNot(contains('Valley of Hinnom (Tissot)')));
      expect(forId('Caesarea').inScope.map((m) => m.title['en']),
          isNot(contains('Peters Vision At Joppa (Schnorr)')));
      expect(forId('Tigris').total, 0);
    });

    test('the plates it does get right', () {
      expect(forId('Nineveh').inScope.map((m) => m.title['en']),
          contains('Jonah Preaches to Nineveh (Doré)'));
      expect(forId('Joppa').inScope.map((m) => m.title['en']),
          contains('Peters Vision At Joppa (Schnorr)'));
      expect(forId('Babel').total, 5);
      expect(forId('Jerusalem').total, 36);
    });

    test('an ordinal cannot split the plates, and does not pretend to', () {
      // Antioch 1 (Syrian) and Antioch 2 (Pisidian) carry byte-identical
      // reference lists in the gazetteer — see docs/DATA-INTEGRITY.md —
      // so no join built on those refs can tell them apart. The header
      // says "naming it" for exactly this reason.
      final a1 = forId('Antioch 1').inScope.map((m) => m.id).toList();
      final a2 = forId('Antioch 2').inScope.map((m) => m.id).toList();
      expect(a1, isNotEmpty);
      expect(a1, a2);
    });
  });
}
