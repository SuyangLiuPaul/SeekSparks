/// 2026-08-07 (SeekSparks): the English Thayer's + Hitchcock services.
///
/// These read the real asset bundle, which `flutter test` serves. That
/// matters more than usual here: both files were committed months ago
/// and neither was listed in `pubspec.yaml`, so they were invisible at
/// runtime with nothing failing. A test that mocks the bundle would not
/// have caught that, and would not catch it coming back.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/services/bible_names_service.dart';
import 'package:seeksparks/services/thayer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    ThayerService.resetForTest();
    BibleNamesService.resetForTest();
  });

  group("Thayer's", () {
    test('G26 agape loads from the bundle with its full article',
        () async {
      final e = await ThayerService.lookup('G26');
      expect(e, isNotNull, reason: 'assets/thayer.json is not bundled');
      expect(e!.headword, 'agape');
      expect(e.avTotal, 116);
      expect(e.senses, hasLength(2));
      expect(e.tdnt, '1:21,5');
    });

    test('the attribution the source asked for is available', () async {
      await ThayerService.lookup('G26');
      expect(ThayerService.attribution, contains("Thayer's"));
      expect(ThayerService.attribution, contains('public domain'));
    });

    test('Hebrew numbers miss — Thayer is a New Testament lexicon',
        () async {
      expect(ThayerService.covers('H8064'), isFalse);
      expect(await ThayerService.lookup('H8064'), isNull);
    });

    test('a grammar code resolves, which English readers had no way to '
        'decode before', () async {
      final e = await ThayerService.lookup('G5656');
      expect(e, isNotNull);
      expect(e!.isGrammarCode, isTrue);
      expect(e.grammarLines.join(' '), contains('Voice'));
    });

    test('G190 ἀκολουθέω resolves — it was shipped and unreachable',
        () async {
      // Two of the 5,799 keys are zero-padded where every other one is
      // bare, so `lookup('G190')` missed the New Testament's verb for
      // following Jesus, and G446 ἀνθύπατος with it. The article was in
      // the bundle the whole time.
      final e = await ThayerService.lookup('G190');
      expect(e, isNotNull);
      expect(await ThayerService.lookup('G446'), isNotNull);
    });

    test('canonicalKey strips padding and touches nothing else', () {
      expect(ThayerService.canonicalKey('G0190'), 'G190');
      expect(ThayerService.canonicalKey('g0446'), 'G446');
      expect(ThayerService.canonicalKey('G190'), 'G190');
      expect(ThayerService.canonicalKey('H1'), 'H1');
      expect(ThayerService.canonicalKey('G5656'), 'G5656');
      // Not a Strong's number at all: left as it came in, only
      // upper-cased, so this can never eat a key it does not understand.
      expect(ThayerService.canonicalKey('attribution'), 'ATTRIBUTION');
      expect(ThayerService.canonicalKey('G0'), 'G0');
    });

    test(
        'the whole table is available to the Lexicon Browser, keyed '
        'canonically', () async {
      final raw = await ThayerService.rawArticles();
      expect(raw, contains('G190'));
      expect(raw, isNot(contains('G0190')));
      expect(raw.length, greaterThan(5700));
    });

    test('an unknown number is null, and stays null without re-reading',
        () async {
      expect(await ThayerService.lookup('G99999'), isNull);
      expect(await ThayerService.lookup('G99999'), isNull);
    });
  });

  group('Hitchcock', () {
    test('a name resolves', () async {
      expect(await BibleNamesService.lookup('Aaron'),
          'a teacher; lofty; mountain of strength');
    });

    test('spacing and hyphens do not have to match', () async {
      // Strong's transliterates "Abialbon"; Hitchcock prints
      // "Abi-albon".
      expect(await BibleNamesService.lookup('Abialbon'), isNotNull);
    });

    test('the name is read off the head of a Strong\'s gloss', () async {
      expect(
        BibleNamesService.namesInGloss(
            'Abigail or Abigal, the name of two Israelitesses'),
        ['Abigail', 'Abigal'],
      );
      expect(BibleNamesService.namesInGloss('the sacred name'), isEmpty);
      expect(
        await BibleNamesService.lookupFromGloss(
            'David, the youngest son of Jesse'),
        isNotNull,
      );
    });

    test('Hitchcock and Thayer disagree, and both are kept', () async {
      final thayer = await ThayerService.lookup('G2');
      expect(thayer!.nameMeaning, 'light-bringer');
      final hitchcock = await BibleNamesService.lookup('Aaron');
      expect(hitchcock, isNot(thayer.nameMeaning));
    });

    test('the attribution the source asked for is available', () async {
      await BibleNamesService.lookup('Aaron');
      expect(BibleNamesService.attribution, contains('Hitchcock'));
    });

    test('an unknown name is null rather than a near miss', () async {
      expect(await BibleNamesService.lookup('Qwertyuiop'), isNull);
    });
  });
}
