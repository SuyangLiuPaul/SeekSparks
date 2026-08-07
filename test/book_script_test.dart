/// Task #283 — English book names in a Chinese UI.
///
/// The reported symptom was the KWIC list printing "Numbers 32:18" and
/// "Deuteronomy …" while the reading version was CUVS(简). The cause was
/// structural rather than local: book names have two renderers, the
/// formal name and the abbreviation, and only the formal one knew about
/// the reading version. These tests pin the rule that both now share.
///
/// The rule: the READING VERSION decides the language, and the UI locale
/// is only the fallback for surfaces with no version in hand. A reader
/// on BSB with a Chinese UI wants "Numbers", because that is the word
/// printed in the verse next to it.
library;

// ignore: depend_on_referenced_packages
import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/book_name_mapping.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/utils/short_book_name.dart';
import 'package:seeksparks/utils/version_mapper.dart';

void main() {
  group('bookScriptFor', () {
    test('the version wins over the locale, in both directions', () {
      // The whole point of the task: neither of these follows the UI.
      expect(bookScriptFor('zh-Hans', 'bsb'), BookScript.english);
      expect(bookScriptFor('en', 'cuvs-yhwh'), BookScript.simplified);
    });

    test('every English-corpus version is classed English', () {
      for (final v in ['kjv', 'leb', 'nasb', 'bsb', 'kjvs', 'lxxwh']) {
        expect(bookScriptFor('zh-Hans', v), BookScript.english, reason: v);
      }
    });

    test('a -tr version is Traditional whatever the locale', () {
      expect(bookScriptFor('en', 'cuvs-yhwh-tr'), BookScript.traditional);
      expect(bookScriptFor('zh-Hans', 'cuvs-tr'), BookScript.traditional);
    });

    test('version codes are normalized before classifying', () {
      expect(bookScriptFor('zh-Hans', ' NASB '), BookScript.english);
      expect(bookScriptFor('zh-Hans', 'Nasb'), BookScript.english);
    });

    test('with no version the locale decides', () {
      expect(bookScriptFor('zh-Hant'), BookScript.traditional);
      expect(bookScriptFor('zh-Hans'), BookScript.simplified);
      expect(bookScriptFor('en'), BookScript.english);
      // An empty version is "no version", not "an unknown version".
      expect(bookScriptFor('en', ''), BookScript.english);
      expect(bookScriptFor('en', '   '), BookScript.english);
    });
  });

  group('toLocale keeps its long-standing empty-version behaviour', () {
    // Several callers pass mp.currentVersion before it has loaded.
    // Simplified, NOT English — changing this would flip book names
    // across the app during startup.
    test('empty version falls back to Simplified', () {
      expect(toLocale('Numbers', ''), '民数记');
    });

    test('known versions are unaffected', () {
      expect(toLocale('Numbers', 'bsb'), 'Numbers');
      expect(toLocale('Numbers', 'cuvs-yhwh'), '民数记');
      expect(toLocale('Numbers', 'cuvs-yhwh-tr'), '民數記');
    });
  });

  group('shortBookName follows the version, not the locale', () {
    test('a Chinese UI reading an English version gets English', () {
      expect(shortBookName('Numbers', 'zh-Hans', 'bsb'), 'Num');
      expect(shortBookName('Deuteronomy', 'zh-Hans', 'kjv'), 'Deu');
    });

    test('an English UI reading a Chinese version gets Chinese', () {
      expect(shortBookName('Numbers', 'en', 'cuvs-yhwh'), '民');
      expect(shortBookName('1 Thessalonians', 'en', 'cuvs-yhwh'), '帖前');
    });

    test('Traditional versions get Traditional abbreviations', () {
      expect(shortBookName('Joshua', 'zh-Hans', 'cuvs-yhwh-tr'), '書');
      expect(shortBookName('Joshua', 'zh-Hant', 'cuvs-yhwh-tr'), '書');
      expect(shortBookName('Joshua', 'zh-Hans', 'cuvs-yhwh'), '书');
    });

    test('localized input is accepted as well as English', () {
      expect(shortBookName('民数记', 'zh-Hans', 'cuvs-yhwh'), '民');
      expect(shortBookName('民數記', 'zh-Hant', 'cuvs-yhwh-tr'), '民');
      // Crossing scripts: a Traditional spelling read under a
      // Simplified version still abbreviates Simplified.
      expect(shortBookName('約書亞記', 'zh-Hant', 'cuvs-yhwh'), '书');
    });

    test('omitting the version leaves the old locale behaviour', () {
      expect(shortBookName('Numbers', 'zh-Hans'), '民');
      expect(shortBookName('Numbers', 'en'), 'Num');
    });

    test('all 66 books abbreviate in all three scripts', () {
      // This is what keeps the last-character fallback unreachable for
      // real references. A book missing from one map would silently
      // abbreviate to a meaningless tail character ("书" for four
      // different books) rather than fail.
      for (final english in englishToChinese.keys) {
        for (final v in ['bsb', 'cuvs-yhwh', 'cuvs-yhwh-tr']) {
          final short = shortBookName(english, 'en', v).characters;
          expect(short.isNotEmpty, isTrue, reason: '$english/$v');
          // Three characters is what the narrow reference columns are
          // sized for; anything longer means the map missed this book
          // and the formal name leaked through.
          expect(short.length <= 3, isTrue,
              reason: 'no abbreviation for $english under $v (got $short)');
        }
      }
    });
  });

  group('localeAwareBookName still agrees with the shared rule', () {
    test('version-driven', () {
      expect(localeAwareBookName('Numbers', 'zh-Hans', 'bsb'), 'Numbers');
      expect(localeAwareBookName('Numbers', 'en', 'cuvs-yhwh'), '民数记');
      expect(localeAwareBookName('Numbers', 'en', 'cuvs-yhwh-tr'), '民數記');
    });

    test('locale-driven when no version is available', () {
      expect(localeAwareBookName('Numbers', 'zh-Hans'), '民数记');
      expect(localeAwareBookName('Numbers', 'zh-Hant'), '民數記');
      expect(localeAwareBookName('Numbers', 'en'), 'Numbers');
      expect(localeAwareBookName('Numbers', 'zh-Hans', ''), '民数记');
    });
  });

  group('ConcordanceRef.display — the KWIC regression', () {
    // concordance.json is keyed in English, so every reference reaching
    // the KWIC list, the Strong's occurrence list and the clipboard
    // starts life as "Numbers 32:18". Printing it as-is was the bug.
    final ref = ConcordanceRef.tryParse('Numbers 32:18')!;

    test('the stored label stays canonical English', () {
      // Navigation parses it back, so it is data and must not move.
      expect(ref.label, 'Numbers 32:18');
      expect(ref.englishBook, 'Numbers');
    });

    test('a Chinese version renders a Chinese book name', () {
      expect(ref.display('zh-Hans', 'cuvs-yhwh'), '民数记 32:18');
      expect(ref.display('zh-Hans', 'cuvs-yhwh', short: true), '民 32:18');
    });

    test('no Latin letters survive under a Chinese version', () {
      // The screenshot that opened this task showed exactly that.
      for (final label in [
        ref.display('zh-Hans', 'cuvs-yhwh'),
        ref.display('zh-Hans', 'cuvs-yhwh', short: true),
        ref.display('en', 'cuvs-yhwh-tr', short: true),
      ]) {
        expect(RegExp(r'[A-Za-z]').hasMatch(label), isFalse, reason: label);
      }
    });

    test('an English version is left alone even in a Chinese UI', () {
      expect(ref.display('zh-Hans', 'bsb'), 'Numbers 32:18');
      expect(ref.display('zh-Hans', 'bsb', short: true), 'Num 32:18');
    });

    test('the short form is short enough for the 84px column', () {
      // The formal English name is what ellipsised in the report.
      final long = ConcordanceRef.tryParse('1 Thessalonians 5:23')!;
      expect(long.display('zh-Hans', 'cuvs-yhwh', short: true), '帖前 5:23');
      expect(long.display('en', 'bsb', short: true), '1Th 5:23');
    });

    test('an unparseable label is passed through, not dropped', () {
      expect(ConcordanceRef.tryParse('Multiple Books'), isNull);
    });
  });
}
