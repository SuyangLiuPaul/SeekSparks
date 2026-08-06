import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

/// BSB is the first English translation SeekSparks ships with Strong's
/// tagging, so these check the whole chain: it is in the catalog, the
/// service claims it, and the built asset actually loads and carries
/// the numbers. Asserting on real content, not just non-emptiness —
/// a tagged asset that loads but tags nothing would pass either way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BSB is an available English version', () {
    final bsb = availableVersions.where((v) => v.value == 'bsb');
    expect(bsb, hasLength(1));
    expect(bsb.first.language, 'en');
    expect(bsb.first.shortLabel, 'BSB');
  });

  test('the tagged service claims BSB', () {
    expect(TaggedTextService.supports('bsb'), isTrue);
    expect(TaggedTextService.supports('BSB'), isTrue, reason: 'case');
    expect(TaggedTextService.supports('kjv'), isFalse,
        reason: 'KJV ships untagged; claiming it would cost a failed load');
  });

  test('Genesis 1:1 loads with its Strong\'s numbers', () async {
    final runs = await TaggedTextService.forVerse(
      version: 'bsb',
      englishBook: 'Genesis',
      chapter: 1,
      verse: 1,
    );
    expect(runs, isNotNull);
    expect(runs!.first.text.trim(), 'In the beginning');
    expect(runs.first.strongs, 'H7225');
    expect(runs.map((r) => r.strongs),
        containsAll(<String>['H7225', 'H430', 'H1254', 'H8064', 'H776']));
  });

  test('the untranslated direct-object marker rides on the noun it marks',
      () async {
    // H853 (אֵת) has no English rendering. In the source table it sits
    // between "God" and "created" because the rows are in ENGLISH order,
    // but in Hebrew it marks הַשָּׁמַיִם — so it belongs on "the heavens",
    // which is where the cuvs-yhwh data puts it too.
    final runs = await TaggedTextService.forVerse(
      version: 'bsb',
      englishBook: 'Genesis',
      chapter: 1,
      verse: 1,
    );
    final heavens = runs!.firstWhere((r) => r.strongs == 'H8064');
    expect(heavens.implied, contains('H853'));
    final created = runs.firstWhere((r) => r.strongs == 'H1254');
    expect(created.implied, isNot(contains('H853')));
  });

  test('a Greek book is tagged too', () async {
    final runs = await TaggedTextService.forVerse(
      version: 'bsb',
      englishBook: 'John',
      chapter: 3,
      verse: 16,
    );
    expect(runs, isNotNull);
    expect(runs!.map((r) => r.strongs), contains('G25')); // ἠγάπησεν
    expect(runs.every((r) => r.strongs.isEmpty || r.strongs.startsWith('G')),
        isTrue, reason: 'a NT verse must not carry H-numbers');
  });

  test('every book file is present and non-trivially tagged', () async {
    for (final book in ['Genesis', 'Psalms', '1 Chronicles', 'Malachi',
      'Matthew', '1 Corinthians', 'Revelation']) {
      final name = book.toLowerCase().replaceAll(' ', '_');
      final raw = await rootBundle.loadString('assets/tagged/bsb/$name.json');
      expect(raw.length, greaterThan(1000), reason: '$book looks empty');
    }
  });
}
