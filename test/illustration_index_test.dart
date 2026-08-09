import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/utils/illustration_index.dart';

BibleMap _m(
  String id, {
  Map<String, List<int>> books = const {},
  String kind = 'scene',
  String en = '',
  String zh = '',
  String descEn = '',
}) =>
    BibleMap(
      id: id,
      title: {'en': en, 'zh-Hans': zh, 'zh-Hant': zh},
      description: {'en': descEn, 'zh-Hans': '', 'zh-Hant': ''},
      books: books,
      file: '$id.jpg',
      kind: kind,
    );

void main() {
  group('canonical ordering', () {
    test('the index walks scripture, not the file', () {
      final all = [
        _m('rev', books: {'Revelation': [1, 22]}),
        _m('gen12', books: {'Genesis': [12, 25]}),
        _m('matt', books: {'Matthew': [1, 2]}),
        _m('gen1', books: {'Genesis': [1, 11]}),
      ];
      expect(
        filterIllustrations(all).map((m) => m.id),
        ['gen1', 'gen12', 'matt', 'rev'],
      );
    });

    test('an entry filed under several books anchors at the earliest', () {
      // The real `ancient_near_east` case: Genesis 1-11 AND Job.
      final ane = _m('ane', books: {'Job': [1, 42], 'Genesis': [1, 11]});
      expect(illustrationAnchor(ane).book, illustrationAnchor(_m('g', books: {'Genesis': [1, 1]})).book);
    });

    test('a scope re-anchors it, so a scoped index reads in scope order', () {
      // Scoped to Job, the Ancient Near East plate belongs among Job's,
      // not ahead of every Genesis plate.
      final ane = _m('ane', books: {'Job': [1, 42], 'Genesis': [1, 11]});
      final job = _m('job', books: {'Job': [1, 1]});
      final unscoped = illustrationAnchor(ane).book;
      final scoped = illustrationAnchor(ane, {'Job'}).book;
      expect(scoped, greaterThan(unscoped));
      expect(scoped, illustrationAnchor(job, {'Job'}).book);
    });

    test('an unrecognised book sorts last, not first', () {
      final all = [
        _m('weird', books: {'Enoch': [1, 1]}),
        _m('rev', books: {'Revelation': [22, 22]}),
      ];
      expect(filterIllustrations(all).map((m) => m.id), ['rev', 'weird']);
    });

    test('ties break on id, so the order is reproducible', () {
      final all = [
        _m('b', books: {'Genesis': [1, 1]}),
        _m('a', books: {'Genesis': [1, 1]}),
      ];
      expect(filterIllustrations(all).map((m) => m.id), ['a', 'b']);
      expect(filterIllustrations(all.reversed).map((m) => m.id), ['a', 'b']);
    });
  });

  group('query', () {
    final all = [
      _m('dore', en: 'The Creation of Light (Doré)', zh: '光的创造',
          books: {'Genesis': [1, 1]}),
      _m('exodus', en: 'The Exodus Route', zh: '出埃及路线',
          kind: 'map', books: {'Exodus': [12, 19]}),
      _m('sower', en: 'The Sower', descEn: 'A parable of the kingdom.',
          kind: 'parable', books: {'Matthew': [13, 13]}),
    ];

    test('matches every locale at once, whatever the UI language is', () {
      expect(filterIllustrations(all, query: 'Doré').map((m) => m.id), ['dore']);
      expect(filterIllustrations(all, query: '光的').map((m) => m.id), ['dore']);
    });

    test('is case-insensitive and trimmed', () {
      expect(filterIllustrations(all, query: '  SOWER ').map((m) => m.id),
          ['sower']);
    });

    test('searches the description, not only the title', () {
      expect(filterIllustrations(all, query: 'kingdom').map((m) => m.id),
          ['sower']);
    });

    test('an empty query is not a filter', () {
      expect(filterIllustrations(all, query: '   ').length, all.length);
    });

    test('no match is an empty list, not everything', () {
      expect(filterIllustrations(all, query: 'zzzz'), isEmpty);
    });
  });

  group('kind and book filters', () {
    final all = [
      _m('m1', kind: 'map', books: {'Genesis': [1, 11]}),
      _m('s1', kind: 'scene', books: {'Genesis': [1, 1]}),
      _m('p1', kind: 'parable', books: {'Matthew': [13, 13]}),
    ];

    test('null and empty both mean "not narrowed"', () {
      expect(filterIllustrations(all, kinds: null).length, 3);
      expect(filterIllustrations(all, kinds: <String>{}).length, 3);
      expect(filterIllustrations(all, scopeBooks: <String>{}).length, 3);
    });

    test('kinds are a union, not an intersection', () {
      expect(filterIllustrations(all, kinds: {'map', 'parable'}).map((m) => m.id),
          ['m1', 'p1']);
    });

    test('a book scope keeps anything that touches the scope', () {
      expect(filterIllustrations(all, scopeBooks: {'Genesis'}).map((m) => m.id),
          ['m1', 's1']);
    });

    test('the filters compose', () {
      expect(
        filterIllustrations(all, kinds: {'scene'}, scopeBooks: {'Genesis'})
            .map((m) => m.id),
        ['s1'],
      );
    });

    test('chip counts ignore the kind filter but honour the others', () {
      // Otherwise every chip the reader has not picked reads 0, which
      // tells them a category is empty when it is merely unselected.
      final counts = illustrationKindCounts(all, scopeBooks: {'Genesis'});
      expect(counts['map'], 1);
      expect(counts['scene'], 1);
      expect(counts.containsKey('parable'), isFalse);
    });
  });

  group('kinds offered', () {
    test('known kinds keep their order, unknown ones are still offered', () {
      final all = [
        _m('a', kind: 'scene'),
        _m('b', kind: 'zebra'),
        _m('c', kind: 'map'),
        _m('d', kind: 'parable'),
      ];
      expect(illustrationKinds(all), ['map', 'scene', 'parable', 'zebra']);
    });

    test('a kind absent from the data is not offered', () {
      expect(illustrationKinds([_m('a', kind: 'map')]), ['map']);
    });

    test('every kind the shipped asset uses has a label key', () {
      final raw = File('assets/maps_index.json').readAsStringSync();
      final all = (jsonDecode(raw) as List)
          .map((e) => BibleMap.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final kind in illustrationKinds(all)) {
        expect(illustrationKindLabelKey(kind), isNotNull,
            reason: 'assets/maps_index.json uses kind "$kind", which the '
                'filter row has no localised name for.');
      }
    });
  });

  group('reference labels', () {
    test('books come back in canonical order', () {
      final m = _m('x', books: {'Matthew': [1, 1], 'Genesis': [1, 1]});
      expect(illustrationBooks(m), ['Genesis', 'Matthew']);
    });

    test('a span prints as a range, a single chapter as a number', () {
      final m = _m('x', books: {'Genesis': [1, 11], 'Job': [3, 3]});
      expect(illustrationChapterSpan(m, 'Genesis'), '1–11');
      expect(illustrationChapterSpan(m, 'Job'), '3');
      expect(illustrationChapterSpan(m, 'Exodus'), '');
    });
  });

  group('the shipped corpus', () {
    late List<BibleMap> all;

    setUpAll(() {
      final raw = File('assets/maps_index.json').readAsStringSync();
      all = (jsonDecode(raw) as List)
          .map((e) => BibleMap.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('every entry is reachable from the index', () {
      // A plate with no books can never be anchored, so it would sit in
      // the unknown bucket at the end of every scope — findable, but only
      // by scrolling past 1,192 others.
      expect(all.where((m) => m.books.isEmpty), isEmpty);
      expect(filterIllustrations(all).length, all.length);
    });

    test('every entry carries all three locales', () {
      for (final m in all) {
        for (final loc in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(m.title[loc], isNotNull, reason: '${m.id} title/$loc');
        }
      }
    });

    test('scoping to a book narrows, and the count carries', () {
      final genesis = filterIllustrations(all, scopeBooks: {'Genesis'});
      expect(genesis, isNotEmpty);
      expect(genesis.length, lessThan(all.length));
      expect(genesis.every((m) => m.books.containsKey('Genesis')), isTrue);
    });

    test('every bundled plate has a thumbnail, and it is much smaller', () {
      // The grid and the filmstrip load `thumbAssetPath`, which falls
      // back to the full plate when a thumbnail is missing — so a plate
      // added without re-running `tools/gen_map_thumbs.sh` degrades
      // silently into the exact failure the thumbnails exist to prevent
      // (~28 full-size decodes on one screen, no frame produced). This
      // is the only thing that says so.
      var full = 0;
      var thumbs = 0;
      for (final m in all.where((m) => m.source == 'asset')) {
        final t = File(m.thumbAssetPath);
        expect(t.existsSync(), isTrue,
            reason: '${m.thumbAssetPath} missing — run '
                'tools/gen_map_thumbs.sh');
        full += File(m.assetPath).lengthSync();
        thumbs += t.lengthSync();
      }
      expect(thumbs * 4, lessThan(full),
          reason: 'thumbnails are $thumbs bytes against $full — that is '
              'not small enough to be worth the bundle');
    });

    test('no referenced book scopes to an empty index', () {
      // Inherited from the retired `illustration_grouping.dart`, whose
      // browse-all catalogue PARTITIONED the corpus and twice lost whole
      // books doing it: v1.3.118's primary-book-only rule emptied 13 NT
      // books whose every plate also touched an earlier one (Ephesians
      // lost "Paul leaves Ephesus" to Acts). Scoping is a filter, not a
      // partition, so it cannot lose a book by construction — this pins
      // that, so nobody reintroduces a "primary book" to save tiles.
      final referenced = <String>{for (final m in all) ...m.books.keys};
      expect(referenced, isNotEmpty);
      for (final book in referenced) {
        expect(filterIllustrations(all, scopeBooks: {book}), isNotEmpty,
            reason: book);
      }
    });
  });
}
