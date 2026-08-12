// docs/DATA-INTEGRITY.md check 33: the words the app was showing and
// could not find.
//
// Check 31b made the LEB's 116 psalm superscriptions visible — in the
// reader, in Browse and on the clipboard — and stopped at the search
// corpus, which reads `Verse.text` alone. So the app answered *"does
// this Bible contain the word maskil"* with 13 under BSB and 0 under
// the LEB, from titles the LEB was printing on screen.
//
// The same question, asked one layer down, found a much larger one:
// `[supplied]` words render WITHOUT their brackets, so LEB Genesis 1:2
// reads "darkness was over the face of the deep" while its key held
// `darkness[was]over`. 16,975 of that edition's 31,083 verses carry a
// bracket, so any phrase crossing a supplied word failed silently in
// more than half of it.
//
// The witness for both is that three editions carry the same psalm
// titles by different routes: `kjvs` and `bsb` merge them into verse 1
// and have always been searchable, the LEB types them apart. After the
// fix the three must return the SAME verse counts for a title's words —
// including under three different spellings of the same Hebrew word
// (maskil / maskil / maschil). A count that agrees with two
// independently produced editions is evidence; a count that only agrees
// with itself is not.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/search_service.dart';
import 'package:seeksparks/utils/psalm_superscription.dart';

List<Map<String, dynamic>> _records(String asset) => [
      for (final e in json.decode(File(asset).readAsStringSync()) as List)
        (e as Map).cast<String, dynamic>(),
    ];

/// The loader's own path: fold the titles onto verse 1, drop whatever
/// is still non-numeric, parse. `FetchVerses` does exactly this.
MainProvider _corpus(String asset) {
  final folded = foldSuperscriptions(_records(asset));
  final verses = <Verse>[];
  for (final m in folded.records) {
    if (int.tryParse(m['verse']?.toString() ?? '') == null) continue;
    verses.add(Verse.fromJson(m));
  }
  return MainProvider()..setVerses(verses);
}

int _hits(MainProvider mp, String query) => SearchService.scanText(
      verses: mp.verses,
      searchKeys: mp.searchKeys,
      query: query,
      bookOrder: mp.bookOrder,
      searchAll: true,
    ).matches.length;

void main() {
  group('Verse.scriptureText — the one flattening', () {
    test('is the verse alone when there is no title', () {
      const v = Verse(
          book: 'Psalms', chapter: 1, verse: 1, text: 'Blessed is the man');
      expect(v.scriptureText, 'Blessed is the man');
    });

    test('puts the title first, where the other editions print it', () {
      const v = Verse(
        book: 'Psalms',
        chapter: 90,
        verse: 1,
        text: 'Lord, you have been our dwelling place',
        superscription: 'A prayer of Moses, the man of God.',
      );
      expect(
        v.scriptureText,
        'A prayer of Moses, the man of God. '
        'Lord, you have been our dwelling place',
      );
    });

    test('does not disturb absence, which is a property of text alone', () {
      const v = Verse(
        book: 'Psalms',
        chapter: 90,
        verse: 1,
        text: '見上節',
        superscription: 'A prayer of Moses.',
      );
      expect(v.absence, isNotNull);
    });
  });

  group('sanitizeForSearchKey', () {
    test('takes the brackets and keeps the words', () {
      expect(
        sanitizeForSearchKey('darkness [was] over the face of the deep'),
        'darkness was over the face of the deep',
      );
    });

    test('leaves sanitizeForSearch alone — previews still mark supplied '
        'words', () {
      expect(
        sanitizeForSearch('darkness [was] over'),
        'darkness [was] over',
      );
    });

    test('a note is still a popup and stays out of the corpus', () {
      // Every one of the 116 superscriptions ends in one of these. A
      // reader searching "the Hebrew Bible counts" must not be handed
      // 116 psalms.
      expect(
        sanitizeForSearchKey('A prayer of Moses.<note: The Hebrew Bible '
            'counts the superscription as the first verse>'),
        'A prayer of Moses.',
      );
    });

    test('takes the 和合本 name brackets too', () {
      expect(sanitizeForSearchKey('主[雅伟]说'), '主雅伟说');
    });
  });

  group('the corpus carries the title', () {
    final mp = MainProvider()
      ..setVerses(const [
        Verse(
          book: 'Psalms',
          chapter: 51,
          verse: 1,
          text: 'Be gracious to me, O God',
          superscription: 'For the [music] director. A psalm of David. '
              'When Nathan the prophet came to him.<note: The Hebrew Bible '
              'counts the superscription as the first two verses>',
        ),
        Verse(
            book: 'Psalms',
            chapter: 51,
            verse: 2,
            text: 'Wash me thoroughly from my guilt'),
      ]);

    test('searchKeys holds the title, without its footnote', () {
      expect(mp.searchKeys.first, contains('nathantheprophet'));
      expect(mp.searchKeys.first, contains('begraciousto'));
      expect(mp.searchKeys.first, isNot(contains('hebrewbiblecounts')));
    });

    test('wordKeys keeps the boundaries the tokenizers need', () {
      expect(mp.wordKeys.first, contains('When Nathan the prophet'));
    });

    test('a phrase crossing a supplied word matches', () {
      expect(_hits(mp, 'music director'), 1);
    });

    test('a verse with no title is untouched', () {
      expect(mp.wordKeys.last, 'Wash me thoroughly from my guilt');
    });
  });

  group('the three editions agree, which is the witness', () {
    late MainProvider leb;
    late MainProvider bsb;
    late MainProvider kjvs;

    setUpAll(() {
      leb = _corpus('assets/leb.json');
      bsb = _corpus('assets/bsb.json');
      kjvs = _corpus('assets/kjvs.json');
    });

    test('the LEB is the only edition that types its titles apart', () {
      expect(leb.verses.where((v) => v.superscription.isNotEmpty).length, 116);
      expect(bsb.verses.any((v) => v.superscription.isNotEmpty), isFalse);
      expect(kjvs.verses.any((v) => v.superscription.isNotEmpty), isFalse);
    });

    // Same words, same psalms, three editions produced independently.
    // These were 0 in the LEB before the fold reached the corpus.
    test('a phrase all three translate the same way', () {
      expect(_hits(leb, 'Nathan the prophet'), 16);
      expect(_hits(bsb, 'Nathan the prophet'), 16);
      expect(_hits(kjvs, 'Nathan the prophet'), 16);
    });

    test('the names in the titles', () {
      expect(_hits(leb, 'Jeduthun'), 14);
      expect(_hits(bsb, 'Jeduthun'), 14);
      expect(_hits(kjvs, 'Jeduthun'), 14);
    });

    test('the musical instructions', () {
      expect(_hits(leb, 'Gittith'), 3);
      expect(_hits(bsb, 'Gittith'), 3);
      expect(_hits(kjvs, 'Gittith'), 3);

      expect(_hits(leb, 'Shiggaion'), 1);
      expect(_hits(bsb, 'Shiggaion'), 1);
      expect(_hits(kjvs, 'Shiggaion'), 1);
    });

    test('one Hebrew word, three spellings, the same 13 psalms', () {
      expect(_hits(leb, 'maskil'), 13);
      expect(_hits(bsb, 'maskil'), 13);
      expect(_hits(kjvs, 'maschil'), 13);
      // And the spelling really is the only difference between them.
      expect(_hits(kjvs, 'maskil'), 0);
    });

    test('and the same 6 miktams', () {
      expect(_hits(leb, 'miktam'), 6);
      expect(_hits(bsb, 'miktam'), 6);
      expect(_hits(kjvs, 'michtam'), 6);
    });

    test('the Songs of Ascents are findable, all fifteen', () {
      // Psalms 120-134. The KJV calls them "Songs of degrees", so it is
      // not a witness here — it is a different English word.
      expect(_hits(leb, 'ascents'), 15);
      expect(_hits(bsb, 'ascents'), 15);
    });

    test('the 55 psalms addressed to the music director', () {
      // The LEB brackets "music" as supplied, so this phrase needs BOTH
      // halves of the fix: the title in the corpus and the brackets out
      // of the key. The KJV+S "chief Musician" is the same 55 psalms.
      expect(_hits(leb, 'music director'), 55);
      expect(_hits(kjvs, 'chief Musician'), 55);
    });

    test('a phrase that crosses a supplied word, in the verses too', () {
      // LEB Genesis 1:2 prints "darkness was over the face of the deep"
      // and stored `darkness [was] over`.
      expect(_hits(leb, 'darkness was over the face of the deep'), 1);
    });
  });
}
