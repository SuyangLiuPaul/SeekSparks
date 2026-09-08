import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

/// BSB is the first English translation SeekSparks ships with Strong's
/// tagging, so these check the whole chain: it is in the catalog, the
/// service claims it, and the built asset actually loads and carries
/// the numbers. Asserting on real content, not just non-emptiness —
/// a tagged asset that loads but tags nothing would pass either way.
///
/// 2026-09-08: `bsb` was hidden from the interface (「bsbs 不用，就 bsb
/// yahweh 版本导入」), and this file deliberately STAYS about `bsb`
/// rather than being repointed at `bsb-yhwh`.
///
/// The question is what the file is for, and only the first test was
/// ever about the catalogue. The other five are about the CORPUS —
/// `assets/tagged/bsb/`, the seven book files sampled below, its
/// H-numbers, the H853
/// direct-object marker riding on the noun, the Greek books carrying no
/// H-numbers. None of that changed: the asset still ships, is still
/// declared in pubspec, and `TaggedTextService` still claims the code,
/// which is why five of the six tests here went on passing untouched.
/// It also has to keep working, because `bsb-yhwh` is DERIVED from this
/// text and `test/yahwehdehua_editions_test.dart` reads
/// `assets/bsb.json` as the baseline it diffs against.
///
/// Repointing this file at `bsb-yhwh` would have been the wrong move
/// twice over: it would have left the plain BSB corpus with no test at
/// all, and it would have duplicated coverage that already exists —
/// `bsb-yhwh` has its own tagged layer (`bsbys`) and its own far more
/// detailed file in `yahwehdehua_editions_test.dart`.
///
/// So only the first test moved, and it moved to say the true thing:
/// `bsb` is in the catalogue, is NOT on offer, and its tagging still
/// loads underneath.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BSB is an English version in the catalog, hidden from the picker',
      () {
    // 2026-09-08: this read `availableVersions` and asserted BSB was on
    // offer. It is hidden now, so the row is asserted from
    // `bibleVersions` — the raw catalog, which hiding does not touch —
    // and its absence from `availableVersions` is asserted alongside,
    // in the same test, so the two halves cannot drift.
    final bsb = bibleVersions.where((v) => v.value == 'bsb');
    expect(bsb, hasLength(1),
        reason: 'the row is what the notice SnackBar and every label '
            'lookup read for a reader arriving on a stale ?v=bsb link');
    expect(bsb.first.language, 'en');
    expect(bsb.first.shortLabel, 'BSB');
    expect(availableVersions.any((v) => v.value == 'bsb'), isFalse,
        reason: 'hidden 2026-09-08 — 「bsbs 不用，就 bsb yahweh 版本导入」; '
            'test/hidden_version_test.dart is where that half lives');
  });

  // Everything below this line is about the CORPUS, not the catalogue,
  // and is unchanged by the hiding: the asset ships, the tagging loads,
  // and `bsb-yhwh` is derived from this text.
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
