import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_sword/constants/bible_versions.dart';
import 'package:yahwehs_sword/constants/version_attribution.dart';
import 'package:yahwehs_sword/constants/workbench_theme.dart';
import 'package:yahwehs_sword/constants/book_names.dart' show standardBookOrder;
import 'package:yahwehs_sword/utils/phrasing.dart' show isRtlText;

/// The Hebrew Old Testament — the missing half of a pair the app already
/// advertised, since the originals row offered Greek and nothing else.
///
/// Source: openscriptures/morphhb. The OSIS headers state both licences
/// themselves — `<rights>Public Domain</rights>` for the WLC text,
/// `<rights>Creative Commons Attribution 4.0</rights>` for the lemma and
/// morphology — which is why an attribution row exists in About and is
/// pinned here.
void main() {
  List<Map<String, dynamic>> corpus() =>
      (jsonDecode(File('assets/wlc.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  group('the corpus', () {
    test('is the whole Hebrew canon and nothing else', () {
      final d = corpus();
      final books = <String>{for (final v in d) v['book'] as String};
      expect(d.length, 23213);
      expect(books.length, 39, reason: 'the Hebrew Bible, not 66 books');
      // Every book is one this app already knows how to order, or the
      // reader lands on a book the picker cannot place.
      for (final b in books) {
        expect(standardBookOrder.contains(b), isTrue, reason: b);
      }
      expect(books.contains('Matthew'), isFalse,
          reason: 'the WLC has no New Testament, and pretending otherwise '
              'is how a reader gets an empty chapter');
    });

    test('reads as Hebrew, with the ids this app keys on', () {
      final d = corpus();
      final gen11 = d.first;
      expect(gen11['book'], 'Genesis');
      expect(gen11['id'], '001001001');
      expect(isRtlText(gen11['text'] as String), isTrue);
      // The Shema, which is the verse the importer's one real bug
      // corrupted: the large ע and ד are nested inside their words, and
      // a descendant walk emitted each of them twice.
      final shema = d.firstWhere((v) =>
          v['book'] == 'Deuteronomy' &&
          v['chapter'] == '6' &&
          v['verse'] == '4');
      expect(shema['text'], 'שְׁמַ֖ע יִשְׂרָאֵ֑ל יְהוָ֥ה אֱלֹהֵ֖ינוּ יְהוָ֥ה ׀ אֶחָֽד׃');
    });

    test('carries no markup and no typesetting instructions', () {
      final d = corpus();
      // The `/` morpheme divider is markup; no printed Hebrew Bible
      // has it.
      expect(d.where((v) => (v['text'] as String).contains('/')), isEmpty);
      expect(d.where((v) => (v['text'] as String).contains('<')), isEmpty);
      // ס / פ / ׆ mark paragraphs. A reader meeting one in the running
      // text sees a stray Hebrew letter, so they are dropped — the same
      // rule that drops a 見上節 line rather than quoting an edition's
      // typesetting as scripture.
      final strays = <String>[
        for (final v in d)
          for (final w in (v['text'] as String).split(' '))
            if (w.length == 1 && !'־׃׀'.contains(w))
              '${v['book']} ${v['chapter']}:${v['verse']} $w',
      ];
      expect(strays, isEmpty);
      expect(d.where((v) => (v['text'] as String).trim().isEmpty), isEmpty);
    });

    test('is canonically ordered, so it compares equal to typed Hebrew', () {
      // The WLC ships marks in Michigan-Claremont order — shin dot before
      // the vowel. A reader pasting from anywhere else, or typing, gets
      // Unicode canonical order. The two look identical on screen and are
      // unequal as strings, which is a search bug nobody can see.
      final d = corpus();
      const shinDot = '\u05c1';
      const sheva = '\u05b0';
      final shema = d.firstWhere((v) =>
          v['book'] == 'Deuteronomy' &&
          v['chapter'] == '6' &&
          v['verse'] == '4')['text'] as String;
      expect(shema.indexOf(sheva), lessThan(shema.indexOf(shinDot)));
    });

    test('maqqef binds and sof pasuq hugs, because the spacing is the text',
        () {
      final d = corpus();
      // A maqqef with spaces around it reads as two words where the
      // text has one.
      expect(
          d.where((v) =>
              (v['text'] as String).contains(' ־') ||
              (v['text'] as String).contains('־ ')),
          isEmpty);
      expect(d.where((v) => (v['text'] as String).endsWith(' ׃')), isEmpty);
    });
  });

  group('the edition is registered where a reader can reach it', () {
    test('in the catalogue, as Hebrew, and in the language order', () {
      final info = bibleVersions.firstWhere((v) => v.value == 'wlc');
      expect(info.language, 'he');
      expect(info.shortLabel, 'WLC');
      expect(bibleLanguageOrder.contains('he'), isTrue,
          reason: 'a language with no tab is an edition nobody can pick');
      expect(versionsForLanguage('he').map((v) => v.value), contains('wlc'));
      expect(bibleVersionLanguage('wlc'), 'he');
    });

    test('the asset ships, and the picker has a word for the language', () {
      expect(File('pubspec.yaml').readAsStringSync().contains('assets/wlc.json'),
          isTrue, reason: 'an undeclared asset is not in the build');
      final picker =
          File('lib/widgets/version_picker_sheet.dart').readAsStringSync();
      expect(picker.contains("case 'he':"), isTrue);
    });

    test('the Copy Center and the gutter both know it', () {
      // Registering an edition is more than the catalogue row: without
      // these two it reaches the Copy Center with no licence line and
      // the gutter with a hashed colour. Both were missed on the way in
      // and caught by the catalogue-wide guards; pinned here so the
      // edition's own file says what registering it means.
      expect(attributionKeyFor('wlc'), 'aboutLicenseWlc');
      expect(unrestrictedCopyVersions.contains('wlc'), isTrue,
          reason: 'the Hebrew text itself is public domain');
      expect(kVersionTagColors.containsKey('wlc'), isTrue);
    });

    test('About carries the attribution CC BY 4.0 asks for', () {
      final about = File('lib/pages/about_page.dart').readAsStringSync();
      expect(about.contains('aboutVerWlc'), isTrue);
      expect(about.contains('openscriptures/morphhb'), isTrue,
          reason: 'the licence names the work and where it lives');
    });
  });

  group('it is drawn right to left', () {
    test('both verse painters decide by script, not by edition code', () {
      for (final f in [
        'lib/widgets/verse_widget.dart',
        'lib/widgets/paragraph_group_widget.dart',
      ]) {
        // Comments stripped first. These files EXPLAIN the old rule by
        // quoting it, and a grep that cannot tell a call from a
        // paragraph about a call would forbid the explanation — which
        // is the part most worth keeping.
        final src = File(f)
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(src.contains('TextDirection.rtl'), isTrue, reason: f);
        // 2026-09-15: this used to demand `isRtlText(` here, with the
        // reason 「a Hebrew quotation inside an English verse is still
        // Hebrew」. That reason was WRONG, and it was reported from the
        // reader: 「Sword全部right aligned了」. 梁简 carries 109 verses
        // whose translator's notes cite a Hebrew word, and `isRtlText`
        // — asked of the raw record, markup included — set every
        // paragraph containing one flush right.
        //
        // A Chinese verse quoting one Hebrew word is a Chinese verse.
        // The painters now ask `scriptIsRtl`, which ignores the
        // apparatus and goes by which script the scripture is MOSTLY
        // in; `rtl_only_for_hebrew_scripture_test.dart` holds that rule
        // to the actual editions.
        expect(src.contains('scriptIsRtl('), isTrue,
            reason: '$f must ask the SCRIPT of the scripture, not the '
                'version code and not the presence of one character');
        expect(src.contains('isRtlText('), isFalse,
            reason: '$f went back to "any Hebrew character anywhere", '
                'which is what right-aligned 罗马书 8');
      }
    });

    test('and English is untouched', () {
      expect(isRtlText('In the beginning God created'), isFalse);
      expect(isRtlText('起初，神创造天地。'), isFalse);
      expect(isRtlText('בְּרֵאשִׁ֖ית'), isTrue);
    });
  });
}
