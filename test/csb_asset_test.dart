/// `assets/csb.json` + `assets/tagged/csb/` — the CSB 2017, imported
/// 2026-09-07 by `tools/import_csb.py`.
///
/// Licence and the decisions behind it: `docs/permissions/README.md`.
/// The 2017 Holman grant, Pastor Raymond's extension of it to the
/// Yahweh's Words products, and the owner's decision on territory.
///
/// **What Holman licensed is the CSB with Strong's Numbers**, so unlike
/// the YsWords copy of this text the numbers are kept, and roughly half
/// the assertions below are about the tagged layer rather than the
/// words. The one that matters most is that the runs concatenate to the
/// verse: two files that can disagree about the same text eventually do.
///
/// **This text is not the module as received.** The importer restores
/// the divine name in 967 verses where the source had lost CSB's own
/// small-caps LORD and left a bare "Lord" behind — Deuteronomy 6:4, the
/// Shema, among them. Shipping it untouched would put a Bible that
/// spells the divine name two ways next to one named for the name.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/book_name_mapping.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/version_attribution.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

void main() {
  late List<Map<String, dynamic>> csb;
  late List<Map<String, dynamic>> kjv;

  List<Map<String, dynamic>> load(String p) =>
      (json.decode(File(p).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  setUpAll(() {
    csb = load('assets/csb.json');
    kjv = load('assets/kjv.json');
  });

  String verse(String id) =>
      csb.firstWhere((r) => r['id'] == id)['text'] as String;

  Map<String, dynamic> tagged(String book) => json.decode(
      File('assets/tagged/csb/${book.toLowerCase().replaceAll(' ', '_')}'
              '.json')
          .readAsStringSync()) as Map<String, dynamic>;

  group('the text', () {
    test('it is a whole Bible, versified like the one already shipping', () {
      // Against kjv.json rather than a typed-in number: the importer maps
      // book names by canonical POSITION, so two canons ordered alike but
      // versified differently would file every verse after the
      // disagreement under the wrong reference while the count still
      // looked right.
      expect(csb, hasLength(31102));
      expect(csb.map((r) => r['book']).toSet(), hasLength(66));
      expect(csb.map((r) => r['id']).toList(), kjv.map((r) => r['id']).toList());
      expect(csb.map((r) => r['book']).toList(),
          kjv.map((r) => r['book']).toList());
    });

    test('no markup survived the import', () {
      // Six kinds in the module: Strong's numbers, <CL>, <CM>,
      // <TS…>/<Ts> section headings, <redletter>, plus two malformed
      // Strong's tags (WH5766x, WH853x) that a `<W[HG]\d+>` pattern
      // misses. Headings are dropped, not inlined — left in, Ps 23:1
      // reads "The Good ShepherdA psalm of David".
      final withTags = csb.where((r) => (r['text'] as String).contains('<'));
      expect(withTags, isEmpty,
          reason: withTags.isEmpty ? '' : 'e.g. ${withTags.first}');
      for (final r in csb) {
        final t = r['text'] as String;
        expect(t.contains('  '), isFalse, reason: '${r['id']}: double space');
        expect(RegExp(r'\s[,.;:!?]').hasMatch(t), isFalse,
            reason: '${r['id']}: space before punctuation — the residue a '
                'lost small-caps run leaves behind');
        expect(t, t.trim());
      }
    });

    test('the text is CSB 2017, not HCSB', () {
      // The source table is named `bsapp_bible_hcsbs`. It is a legacy
      // key; these are the readings that tell the two editions apart,
      // and they are also what the credit line has to be right about.
      expect(verse('019023001'), contains('I have what I need'));
      expect(verse('045001001'), contains('servant'));
      expect(verse('043003016'), contains('his one and only Son'));
    });
  });

  group('the divine name', () {
    test('the Shema reads as a name, not as a title', () {
      // The module had lost the small caps and read "The Lord  our God";
      // the first version of the importer replaced only the word and
      // produced "The Yahweh our God, the Yahweh is one", which is why
      // the article is part of the rule.
      expect(verse('005006004'), contains('Yahweh our God, Yahweh is one'));
    });

    test('the article never survives in front of it', () {
      for (final r in csb) {
        final t = r['text'] as String;
        expect(t.contains('the Yahweh'), isFalse, reason: '${r['id']}: $t');
        expect(t.contains('The Yahweh'), isFalse, reason: '${r['id']}: $t');
      }
    });

    test('Adonai is left alone — Psalm 110:1 carries both', () {
      final ps110 = verse('019110001');
      expect(ps110, contains('declaration of Yahweh'));
      expect(ps110, contains('to my Lord'));
    });

    test('the module\'s own Strong\'s numbers are the witness', () {
      // This repo can do what the YsWords import could not: ask the
      // module what a word IS instead of how it was set in type. Psalm
      // 44:23's "Lord" carries H136 — Adonai — and 110:1's carries H113.
      // Both survive untouched, and they are tagged, which is the
      // evidence that the restoration rule never overwrote a Lord the
      // module itself had identified.
      final ps = tagged('Psalms');
      String? numberOn(String ref, String word) {
        for (final r in (ps[ref] as List).cast<Map<String, dynamic>>()) {
          if ((r['w'] as String).contains(word)) return r['s'] as String;
        }
        return null;
      }

      expect(numberOn('44:23', 'Lord'), 'H136');
      expect(numberOn('110:1', 'Lord'), 'H113');
      expect(numberOn('110:1', 'Yahweh'), 'H3068');
      expect(numberOn('23:1', 'Yahweh'), 'H3068');
    });

    test('the restored name carries the number the module lost with it', () {
      // Deut 6:4 arrived as "The Lord  our God" — the small-caps run
      // gone AND its tag with it. The repair splices both back, which is
      // not inventing tagging: all 5,041 instances the module kept read
      // `Yahweh<WH3068>`.
      final runs = (tagged('Deuteronomy')['6:4'] as List)
          .cast<Map<String, dynamic>>();
      final yahweh = runs.where((r) => (r['w'] as String).contains('Yahweh'));
      expect(yahweh, hasLength(2));
      for (final r in yahweh) {
        expect(r['s'], 'H3068');
      }
    });

    test('the five stragglers the tagged layer made findable', () {
      // With every candidate carrying a number, the verses the rule
      // could NOT see became enumerable — twelve, each adjudicated by
      // name in `UNTAGGED_OT_LORD`. Five of them turned out not to be
      // leftovers:
      //
      //   Ps 15:4    a `<CL>` sat where the lookahead wanted a space —
      //              this verse spelled the name both ways at once
      //   Jer 5:13   `the<WH9998> Lord ’s`, a tag between the article
      //              and the name
      //   1Kgs 3:15, Isa 59:20, Mal 1:12
      //              possessives that lost the residue space too
      expect(verse('019015004'),
          contains('rejected by Yahweh but honors those who fear Yahweh'));
      expect(verse('024005013'), contains('Yahweh’s word is not in them'));
      expect(verse('011003015'), contains('the ark of Yahweh’s covenant'));
      expect(verse('023059020'), contains('This is Yahweh’s declaration'));
      expect(verse('039001012'), contains('Yahweh’s table is defiled'));
    });

    test('and the ones beside them that are NOT the name', () {
      // From the same sweep. Each looks like a lost LORD and is not, and
      // the first two would have been renamed by any rule keyed on "this
      // verse contains YHWH":
      //
      //   Lam 2:20   opens "Yahweh, look and consider" and closes "in
      //              the Lord’s sanctuary" — H3068 and H136, one verse
      //   2Sam 5:20  "The Lord Bursts Out" glosses Baal-perazim and the
      //              module tags that run H1188 — בַּעַל, master, not
      //              the divine name
      expect(verse('025002020'), contains('Yahweh, look'));
      expect(verse('025002020'), contains('the Lord’s sanctuary'));
      expect(verse('010005020'), contains('The Lord Bursts Out'));
      expect(verse('026018025'), contains('The Lord’s way'));
      expect(verse('011008026'), contains('Now Lord God of Israel'));
    });

    test('the three vocative Psalms keep their Lord', () {
      for (final id in const ['019044023', '019062012', '019116008']) {
        expect(verse(id), contains('Lord'), reason: id);
        expect(verse(id), isNot(contains('Yahweh')), reason: id);
      }
    });

    test('the module\'s own stray articles were repaired too', () {
      // The 5,041 verses that arrived already restored included ones
      // that kept the article: "This is the Yahweh's gate",
      // "Holy to the Yahweh".
      expect(verse('019118020'), contains('This is Yahweh’s gate'));
      expect(verse('002028036'), contains('Holy to Yahweh'));
    });

    test('the population is pinned', () {
      // 5,041 already in the module + the restorations. A re-import that
      // silently lost the divine-name pass would sit at 5,041 and every
      // spot check above except the Shema would still pass.
      final withName =
          csb.where((r) => (r['text'] as String).contains('Yahweh'));
      expect(withName, hasLength(5805));
    });
  });

  group('the tagged layer', () {
    test('every book has one, and the app knows it', () {
      expect(Directory('assets/tagged/csb').listSync().length, 66);
      expect(TaggedTextService.supports('csb'), isTrue);
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('assets/tagged/csb/'),
          reason: 'an unlisted directory is tagging that 404s at runtime');
    });

    test('the runs ARE the verse', () {
      // The invariant the whole importer is arranged around. Whitespace
      // is normalised per run and never on the joined string, so the
      // plain asset and the tagged asset are two views of one thing. If
      // this ever fails, a reader hovering a word is being shown text
      // the page is not printing.
      final byId = {for (final r in csb) r['id']: r['text'] as String};
      final books = csb.map((r) => r['book'] as String).toSet().toList();
      var checked = 0;
      for (final book in books) {
        final bi = books.indexOf(book) + 1;
        tagged(book).forEach((ref, runs) {
          final parts = ref.split(':');
          final id = '${bi.toString().padLeft(3, '0')}'
              '${parts[0].padLeft(3, '0')}${parts[1].padLeft(3, '0')}';
          final joined = (runs as List)
              .cast<Map<String, dynamic>>()
              .map((r) => r['w'] as String)
              .join();
          expect(joined, byId[id], reason: '$book $ref');
          checked++;
        });
      }
      expect(checked, greaterThan(30000));
    });

    test('no run carries a number that is not a Strong\'s number', () {
      // The module tags ~106,000 English words with H9900-H9999 — the
      // band it uses for words that render a Hebrew prefix or particle
      // with no headword of its own ("In<WH9996> the<WH9998>
      // beginning<WH7225>"). Strong's stops at H8674 and G5624, and this
      // module's real numbers stop exactly there, so the two sets do not
      // overlap. Emitting one would send the lexicon looking for an
      // entry Brown-Driver-Briggs has never had.
      final bad = <String>[];
      for (final book in csb.map((r) => r['book'] as String).toSet()) {
        tagged(book).forEach((ref, runs) {
          for (final r in (runs as List).cast<Map<String, dynamic>>()) {
            for (final n in [r['s'] as String, ...(r['i'] as List).cast<String>()]) {
              if (n.isEmpty) continue;
              final v = int.parse(n.substring(1));
              final top = n[0] == 'H' ? 8674 : 5624;
              if (v < 1 || v > top) bad.add('$book $ref: $n');
            }
          }
        });
      }
      expect(bad, isEmpty, reason: bad.take(5).join('; '));
    });

    test('the Old Testament is tagged in Hebrew and the New in Greek', () {
      final books = csb.map((r) => r['book'] as String).toSet().toList();
      for (final book in [books[0], books[38], books[39], books[65]]) {
        final wantH = books.indexOf(book) < 39;
        final runs = (tagged(book).values.first as List)
            .cast<Map<String, dynamic>>()
            .where((r) => (r['s'] as String).isNotEmpty);
        expect(runs, isNotEmpty, reason: book);
        for (final r in runs) {
          expect((r['s'] as String)[0], wantH ? 'H' : 'G', reason: book);
        }
      }
    });

    test('no grammar codes, because the module has none', () {
      // Eagle's View ships tense/voice/mood alongside the numbers; this
      // module does not — not one of its tags falls between the Strong's
      // ceiling and the placeholder band. Pinned so a re-import that
      // starts emitting them has to be looked at rather than trusted.
      for (final book in csb.map((r) => r['book'] as String).toSet()) {
        tagged(book).forEach((ref, runs) {
          for (final r in (runs as List).cast<Map<String, dynamic>>()) {
            expect(r['g'], isEmpty, reason: '$book $ref');
          }
        });
      }
    });
  });

  group('the edition is wired up', () {
    test('it is registered, offered, and English', () {
      final info = bibleVersions.where((v) => v.value == 'csb').toList();
      expect(info, hasLength(1));
      expect(info.single.language, 'en');
      expect(info.single.shortLabel, 'CSB');
      expect(disabledVersions.contains('csb'), isFalse,
          reason: 'the owner decided worldwide distribution is fine — see '
              'docs/permissions/. NASB is the hidden one, not this.');
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('assets/csb.json'),
          reason: 'an unlisted asset is a version that 404s at runtime');
    });

    test('its book names are read as English', () {
      // The trap `book_name_mapping.dart` documents in full: bsb, kjvs
      // and lxxwh entered the catalog without joining this set, so
      // `toLocale` classified them as Chinese, the reading pane filtered
      // an English corpus by a Chinese book name, and the pane rendered
      // BLANK on production with no error.
      expect(bookScriptFor('zh-Hans', 'csb'), BookScript.english);
    });

    test('copying it out carries the licence, and is capped', () {
      // The grant is gratis only while the work is distributed free, and
      // the credit line has to travel with the text — which is exactly
      // what the clipboard is.
      expect(attributionKeyFor('csb'), 'aboutLicenseCsb');
      expect(unrestrictedCopyVersions.contains('csb'), isFalse,
          reason: 'the CSB is licensed, not public domain');
    });

    test('the credit line Holman requires is present, word for word', () {
      // The grant names this sentence and says it must appear on the
      // copyright or title page. The About screen is that page. Quoted
      // in full deliberately: a paraphrase is a breach of the grant, and
      // a test that checked a fragment would not notice one.
      const required =
          'Scripture quotations marked CSB®, are taken from the Christian '
          'Standard Bible®, Copyright © 2017 by Holman Bible '
          'Publishers. Used by permission. Christian Standard Bible®, '
          'and CSB® are federally registered trademarks of Holman Bible '
          'Publishers.';
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(uiStrings['aboutLicenseCsb']?[locale], required,
            reason: '$locale: the grant does not allow this to be '
                'translated or trimmed');
      }
      expect(File('lib/pages/about_page.dart').readAsStringSync(),
          contains("uiStrings['aboutLicenseCsb']"),
          reason: 'the string existing is not the same as the page drawing it');
    });
  });
}
