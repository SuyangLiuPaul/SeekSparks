/// Nave's Topical Bible: the core, and the assets it reads.
///
/// The tests that matter here are the ones pinned to a defect that
/// actually shipped in the source text. CCEL's tagger cannot read a
/// one-chapter book: it emitted every one of the 250 references to
/// Obadiah, Philemon, 2 John, 3 John and Jude as `BOOK.1.1` and left the
/// real verse in the prose behind the link. Imported literally, Jude 1:1
/// carried 115 unrelated topics and Jude 1:14 — "And Enoch also, the
/// seventh from Adam, prophesied" — carried none, while the pane looked
/// perfectly healthy. Nothing about the shape of the asset gives that
/// away, so the checks below are about DISTRIBUTION and about the verses
/// the repair claims, not about whether the JSON parses.
///
/// The second defect class is the tagger reading a personal name plus the
/// next reference's leading digit as a book: "Micah 2 Ch 34:20" became a
/// link to Micah 2. Its repair is pinned on 2 Chronicles 34:20, which
/// names "Abdon the son of Micah" and so witnesses itself.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/book_names.dart';
import 'package:seeksparks/services/naves_service.dart';

/// Books with no chapter number to print, and their verse counts.
const _singleChapter = {
  'Obadiah': 21,
  'Philemon': 25,
  '2 John': 13,
  '3 John': 14,
  'Jude': 25,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NaveRef', () {
    test('reads the three granularities Nave printed', () {
      final verse = NaveRef.parse('14.34.20')!;
      expect(verse.book, '2 Chronicles');
      expect(verse.chapter, 34);
      expect(verse.verse, 20);
      expect(verse.endVerse, isNull);
      expect(verse.isChapter, isFalse);

      final range = NaveRef.parse('13.6.3-15')!;
      expect(range.book, '1 Chronicles');
      expect(range.verse, 3);
      expect(range.endVerse, 15);

      final chapter = NaveRef.parse('4.17')!;
      expect(chapter.book, 'Numbers');
      expect(chapter.chapter, 17);
      expect(chapter.verse, isNull);
      expect(chapter.isChapter, isTrue);
    });

    test('refuses what it cannot read rather than guessing', () {
      expect(NaveRef.parse('14'), isNull);
      expect(NaveRef.parse('0.1.1'), isNull);
      expect(NaveRef.parse('67.1.1'), isNull);
      expect(NaveRef.parse('x.1.1'), isNull);
      expect(NaveRef.parse('1.x.1'), isNull);
    });

    test('a chapter citation covers the chapter, a range only its span', () {
      final chapter = NaveRef.parse('4.17')!;
      expect(chapter.covers('Numbers', 17, 1), isTrue);
      expect(chapter.covers('Numbers', 17, 40), isTrue);
      expect(chapter.covers('Numbers', 18, 1), isFalse);
      expect(chapter.covers('Leviticus', 17, 1), isFalse);

      final range = NaveRef.parse('13.6.3-15')!;
      expect(range.covers('1 Chronicles', 6, 3), isTrue);
      expect(range.covers('1 Chronicles', 6, 15), isTrue);
      expect(range.covers('1 Chronicles', 6, 16), isFalse);
      expect(range.covers('1 Chronicles', 6, 2), isFalse);
    });

    test('labels in the reading language', () {
      expect(NaveRef.parse('14.34.20')!.label('en'), '2 Chronicles 34:20');
      expect(NaveRef.parse('13.6.3-15')!.label('en'), '1 Chronicles 6:3-15');
      expect(NaveRef.parse('4.17')!.label('en'), 'Numbers 17');
    });
  });

  group('NaveTopic.ancestorsOf', () {
    // Nave's own indentation is the argument structure: a ".Paul" at
    // depth 3 is a fragment until you can see the "–Called of God" it
    // hangs beneath.
    NaveLine at(int depth, String text) =>
        NaveLine(depth: depth, text: text, refs: const [], see: const []);
    final topic = NaveTopic(id: 0, head: 'MINISTER', lines: [
      at(1, 'Called of God'),
      at(2, 'Paul'),
      at(3, 'To the Gentiles'),
      at(1, 'Duties of'),
      at(3, 'Orphaned depth'),
    ]);

    test('walks outward, outermost first', () {
      expect(topic.ancestorsOf(0), isEmpty);
      expect(topic.ancestorsOf(1).map((l) => l.text), ['Called of God']);
      expect(topic.ancestorsOf(2).map((l) => l.text),
          ['Called of God', 'Paul']);
      expect(topic.ancestorsOf(3), isEmpty);
    });

    test('a skipped level yields what exists, not a wrong parent', () {
      expect(topic.ancestorsOf(4).map((l) => l.text), ['Duties of']);
    });

    test('out-of-range indexes are empty, not an exception', () {
      expect(topic.ancestorsOf(-1), isEmpty);
      expect(topic.ancestorsOf(99), isEmpty);
    });
  });

  group('the shipped asset', () {
    late Map<String, dynamic> index;
    late Set<String> canon;
    late Map<String, int> chapterVerses;

    setUpAll(() {
      index = jsonDecode(File('assets/nave/index.json').readAsStringSync())
          as Map<String, dynamic>;
      canon = {};
      chapterVerses = {};
      for (final r in jsonDecode(File('assets/kjv.json').readAsStringSync())
          as List) {
        final row = r as Map<String, dynamic>;
        final key = '${row['book']}|${row['chapter']}';
        final v = int.parse('${row['verse']}');
        canon.add('$key|$v');
        if (v > (chapterVerses[key] ?? 0)) chapterVerses[key] = v;
      }
    });

    test('the index carries every topic and its licence statement', () {
      expect(index['topicCount'], 5322);
      expect((index['topics'] as List).length, 5322);
      // The pane reads the credit out of the asset, so an empty string
      // here would silently drop it from the screen.
      final attribution = index['attribution'] as String;
      expect(attribution, contains('Nave'));
      expect(attribution, contains('Public domain'));
      expect(attribution, contains('ccel.org'));
    });

    test('every reference resolves in the KJV Nave keyed the work to', () {
      final perShard = index['topicsPerShard'] as int;
      var refs = 0;
      final bad = <String>[];
      for (final file in Directory('assets/nave/t').listSync()) {
        final shard = jsonDecode(File(file.path).readAsStringSync())
            as Map<String, dynamic>;
        for (final entry in shard.entries) {
          final id = int.parse(entry.key);
          expect(id ~/ perShard, int.parse(_stem(file.path)),
              reason: 'topic $id is filed in the wrong shard');
          for (final line in (entry.value['l'] as List? ?? const [])) {
            for (final code in ((line as Map)['r'] as List? ?? const [])) {
              refs++;
              final ref = NaveRef.parse(code as String);
              if (ref == null) {
                bad.add('unparseable $code');
                continue;
              }
              final key = '${ref.book}|${ref.chapter}';
              if (ref.verse == null) {
                if (!chapterVerses.containsKey(key)) bad.add('$code -> $key');
                continue;
              }
              for (var v = ref.verse!; v <= (ref.endVerse ?? ref.verse!); v++) {
                if (!canon.contains('$key|$v')) bad.add('$code -> $key:$v');
              }
            }
          }
        }
      }
      expect(bad, isEmpty, reason: 'references outside the KJV: $bad');
      expect(refs, index['refCount']);
      expect(refs, 77974);
    });

    test('the reverse index points at lines that really cite the verse', () {
      final perShard = index['topicsPerShard'] as int;
      final shards = <int, Map<String, dynamic>>{};
      Map<String, dynamic> topicOf(int id) => (shards[id ~/ perShard] ??=
          jsonDecode(File('assets/nave/t/${id ~/ perShard}.json')
              .readAsStringSync()) as Map<String, dynamic>)['$id']!;

      var rows = 0;
      final bad = <String>[];
      for (final file in Directory('assets/nave/v').listSync()) {
        final book = _bookOfSlug(_stem(file.path));
        final byChapter = jsonDecode(File(file.path).readAsStringSync())
            as Map<String, dynamic>;
        for (final ch in byChapter.entries) {
          final chapter = int.parse(ch.key);
          for (final vs in (ch.value as Map<String, dynamic>).entries) {
            final verse = int.parse(vs.key);
            for (final hit in vs.value as List) {
              rows++;
              final topic = topicOf((hit as List)[0] as int);
              final line = (topic['l'] as List)[hit[1] as int] as Map;
              final refs = [
                for (final c in (line['r'] as List? ?? const []))
                  NaveRef.parse(c as String)!,
              ];
              // Key "0" is a whole-chapter citation; anything else has to
              // be covered by a reference on that very line.
              final ok = verse == 0
                  ? refs.any((r) =>
                      r.isChapter && r.book == book && r.chapter == chapter)
                  : refs.any((r) => r.covers(book, chapter, verse));
              if (!ok) bad.add('$book $chapter:$verse -> ${hit[0]}/${hit[1]}');
            }
          }
        }
      }
      expect(bad, isEmpty, reason: 'index rows with no matching ref: $bad');
      expect(rows, greaterThan(150000));
    });

    test('the one-chapter books are spread over their verses, not piled '
        'on verse 1', () {
      for (final entry in _singleChapter.entries) {
        final slug = entry.key.toLowerCase().replaceAll(' ', '_');
        final chapter = (jsonDecode(File('assets/nave/v/$slug.json')
            .readAsStringSync()) as Map<String, dynamic>)['1'] as Map;
        final cited = <int, int>{
          for (final e in chapter.entries)
            int.parse(e.key as String): (e.value as List).length,
        };
        final verses = cited.keys.where((v) => v > 0).toList();

        // Every repaired verse is inside the book. A misparse of the
        // orphan text would overflow a 13-verse epistle.
        expect(verses.reduce((a, b) => a > b ? a : b), entry.value,
            reason: '${entry.key} should reach its last verse');
        // Before the repair this was the whole book: 115 topics on Jude
        // 1:1 and nothing anywhere else.
        expect(verses.length, greaterThan(entry.value ~/ 2),
            reason: '${entry.key} cites only ${verses.length} of its verses');
        expect(cited[1]!, lessThan(15),
            reason: '${entry.key} 1:1 has ${cited[1]} topics — the pile is back');
      }
    });
  });

  group('NavesService, against the real bundle', () {
    setUpAll(() async {
      NavesService.resetForTest();
      await NavesService.heads();
    });

    test('heads and attribution load once and hold', () async {
      final heads = await NavesService.heads();
      expect(heads.length, 5322);
      expect(heads.first, isNotEmpty);
      expect(NavesService.attribution, contains('Public domain'));
    });

    test('the Micah repair reaches the verse that witnesses it', () async {
      // "Micah 2 Ch 34:20" was tagged as a link to Micah 2. 2 Chronicles
      // 34:20 is the verse that names "Abdon the son of Micah".
      final hits = await NavesService.forVerse(
          englishBook: '2 Chronicles', chapter: 34, verse: 20);
      expect(hits.map((h) => h.head), contains('MICAH'));
    });

    test('Jude 1:14 is Enoch, and 1:1 is no longer the whole epistle',
        () async {
      final enoch = await NavesService.forVerse(
          englishBook: 'Jude', chapter: 1, verse: 14);
      expect(enoch.map((h) => h.head), contains('ENOCH'));
      expect(enoch.map((h) => h.head), contains('ANTEDILUVIANS'));

      final first = await NavesService.forVerse(
          englishBook: 'Jude', chapter: 1, verse: 1);
      expect(first.length, lessThan(15));
    });

    test('verse-level citations come before chapter-level ones', () async {
      // Numbers 17 is Nave's "Rod of, buds — Nu 17", a chapter citation
      // sitting on a chapter that also has verse-level ones.
      final hits = await NavesService.forVerse(
          englishBook: 'Numbers', chapter: 17, verse: 8);
      expect(hits.any((h) => h.chapterLevel), isTrue);
      final firstChapterLevel = hits.indexWhere((h) => h.chapterLevel);
      expect(hits.skip(firstChapterLevel).every((h) => h.chapterLevel), isTrue);
    });

    test('a citation carries the path a reader needs to read the line',
        () async {
      final hits = await NavesService.forVerse(
          englishBook: '2 Chronicles', chapter: 34, verse: 20);
      final micah = hits.firstWhere((h) => h.head == 'MICAH');
      expect(micah.path, startsWith('MICAH'));
      expect(micah.line.refs.any((r) => r.covers('2 Chronicles', 34, 20)),
          isTrue);
    });

    test('a book Nave never cites answers empty rather than throwing',
        () async {
      final hits = await NavesService.forVerse(
          englishBook: 'Nonexistent Book', chapter: 1, verse: 1);
      expect(hits, isEmpty);
    });

    test('headword search puts prefix matches first', () async {
      final ids = await NavesService.search('love');
      final heads = await NavesService.heads();
      expect(ids, isNotEmpty);
      final names = [for (final i in ids) heads[i].toUpperCase()];
      final lastPrefix =
          names.lastIndexWhere((n) => n.startsWith('LOVE'));
      expect(names.take(lastPrefix + 1).every((n) => n.startsWith('LOVE')),
          isTrue);
      expect(await NavesService.search('   '), isEmpty);
    });
  });
}

String _stem(String path) =>
    path.split(Platform.pathSeparator).last.replaceAll('.json', '');

String _bookOfSlug(String slug) => standardBookOrder
    .firstWhere((b) => b.toLowerCase().replaceAll(' ', '_') == slug);
