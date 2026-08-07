/// 2026-08-07 (SeekSparks): Thayer's parser.
///
/// The fixtures below are verbatim entries from `assets/thayer.json`,
/// each chosen because it broke an earlier version of the parser. The
/// corpus assertions at the bottom then run the real 5,799-entry file,
/// which is the only way to know a rule generalises — every rule here
/// looked right on three hand-picked entries first.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/thayer_parse.dart';

const _g26 = '''agape

 from 25; TDNT - 1:21,5; n f

 AV - love 86, charity 27, dear 1, charitably+2596 1,
 feast of charity 1; 116

 1) brotherly love, affection, good will, love, benevolence
 2) love feasts''';

const _g20 = '''agalliasis

 from 21; TDNT - 1:19,4; n f

 AV - gladness 3, joy 1, exceeding joy 1; 5

 1) exultation, extreme joy, gladness

 At feasts, people were anointed with the "oil of gladness".''';

const _g111 = '''athemitos

 from 1 (as a negative particle); adj

 AV - unlawful thing 1, abominable 1, 2

 1) contrary to law and justice''';

const _g619 = '''apolausis

 from a comparative of 575 and lauo; n f

 AV - to enjoy + 1519, enjoy the pleasures + 2192 1; 2

 1) enjoyment''';

const _g2424 = '''Iesous

 of Hebrew origin 3091; TDNT - 3:284,360; n pr m

 AV - Jesus 972; 972

 Jesus = "Jehovah is salvation"

 1) Jesus, the Son of God''';

const _nested = '''charis

 from 5463; n f

 AV - grace 130; 130

 1) grace
   1a) that which affords joy
     1a1) of speech
       1a2a) deepest
 2) good will''';

void main() {
  test('G26: the AV block ends at its total, not at the newline', () {
    final e = parseThayerEntry('G26', _g26);
    expect(e.headword, 'agape');
    expect(e.etymology, 'from 25');
    expect(e.partOfSpeech, 'n f');
    expect(e.tdnt, '1:21,5');
    expect(e.avTotal, 116);
    expect(e.avCounts.map((a) => a.rendering),
        containsAll(['love', 'charity', 'feast of charity']));
    expect(e.avCounts.firstWhere((a) => a.rendering == 'love').count, 86);
    // The defect this parser exists to avoid: the Chinese sibling
    // splits the AV block on the newline, so "feast of charity 1; 116"
    // becomes its first "sense".
    expect(e.senses, hasLength(2));
    expect(e.senses.first.text, startsWith('brotherly love'));
    expect(e.senses.map((s) => s.text).join(), isNot(contains('116')));
  });

  test('G20: a commentary note indented like a sense is still a note', () {
    final e = parseThayerEntry('G20', _g20);
    expect(e.senses, hasLength(1));
    expect(e.senses.single.text, 'exultation, extreme joy, gladness');
    expect(e.notes, hasLength(1));
    expect(e.notes.single, startsWith('At feasts'));
  });

  test('G111: a comma may separate the AV total', () {
    final e = parseThayerEntry('G111', _g111);
    expect(e.avTotal, 2);
    expect(e.avCounts.map((a) => a.rendering),
        ['unlawful thing', 'abominable']);
    expect(e.senses, hasLength(1));
  });

  test('G619: a rendering whose count the source dropped keeps no count',
      () {
    final e = parseThayerEntry('G619', _g619);
    final first = e.avCounts.first;
    // "to enjoy + 1519" — 1519 is the Strong's it combines with, not a
    // count of 1,519 occurrences.
    expect(first.rendering, 'to enjoy + 1519');
    expect(first.count, 0);
    expect(e.avTotal, 2);
  });

  test('G2424: the name gloss is extracted, not left as commentary', () {
    final e = parseThayerEntry('G2424', _g2424);
    expect(e.nameMeaning, 'Jehovah is salvation');
    expect(e.notes, isEmpty);
    expect(e.partOfSpeech, 'n pr m');
    expect(decodePartOfSpeech(e.partOfSpeech), 'noun proper masculine');
  });

  test('sense markers nest four deep', () {
    final e = parseThayerEntry('G5485', _nested);
    expect(e.senses.map((s) => '${s.marker}:${s.level}'),
        ['1:1', '1a:2', '1a1:3', '1a2a:4', '2:1']);
  });

  test("'Not Used' entries are flagged, not parsed", () {
    final e = parseThayerEntry('G4', "'Not Used'");
    expect(e.isNotUsed, isTrue);
    expect(e.senses, isEmpty);
  });

  test('grammar codes are kept raw', () {
    final e = parseThayerEntry('G5656', '''Tense - First Aorist

 Voice - Active See 5784
 Mood - Indicative See 5791''');
    expect(e.isGrammarCode, isTrue);
    expect(e.grammarLines, contains('Voice - Active See 5784'));
    expect(e.senses, isEmpty);
  });

  test('a malformed entry degrades instead of throwing', () {
    expect(parseThayerEntry('G0', '').isEmpty, isTrue);
    expect(() => parseThayerEntry('G0', 'AV - ; \n 1)'), returnsNormally);
  });

  group('corpus', () {
    late Map<String, dynamic> entries;

    setUpAll(() {
      final raw = json.decode(File('assets/thayer.json').readAsStringSync())
          as Map<String, dynamic>;
      entries = raw['entries'] as Map<String, dynamic>;
    });

    test('every entry parses and keeps a headword', () {
      var parsed = 0;
      for (final e in entries.entries) {
        final t = parseThayerEntry(e.key, e.value as String);
        expect(t.headword, isNotEmpty, reason: e.key);
        parsed++;
      }
      expect(parsed, 5799);
    });

    test('no AV debris leaks into the senses', () {
      // `<count>; <total>` at the end of a sense means the AV block was
      // cut at a newline — the exact shape of the Chinese sibling's bug.
      final debris = RegExp(r'\d+;\s*\d+$');
      final bad = <String>[];
      for (final e in entries.entries) {
        final t = parseThayerEntry(e.key, e.value as String);
        for (final s in t.senses) {
          if (debris.hasMatch(s.text)) bad.add('${e.key}: ${s.text}');
        }
      }
      expect(bad, isEmpty);
    });

    test('AV counts sum to the stated total for 99% of entries', () {
      var withAv = 0, agree = 0;
      for (final e in entries.entries) {
        final t = parseThayerEntry(e.key, e.value as String);
        if (t.avCounts.isEmpty || t.avTotal == 0) continue;
        withAv++;
        final sum = t.avCounts.fold<int>(0, (a, b) => a + b.count);
        if (sum == t.avTotal) agree++;
      }
      expect(withAv, greaterThan(5000));
      // The residual disagreements are the source's own: buckets like
      // "misc 7" and "not tr 7" are counted in the total but listed
      // without being enumerated.
      expect(agree / withAv, greaterThan(0.99));
    });

    test('the grammar-code range is complete', () {
      var codes = 0;
      for (var n = 5627; n <= 5798; n++) {
        final raw = entries['G$n'];
        if (raw == null) continue;
        final t = parseThayerEntry('G$n', raw as String);
        expect(t.isGrammarCode, isTrue, reason: 'G$n');
        codes++;
      }
      expect(codes, 172);
    });

    test('name glosses are extracted rather than left in the notes', () {
      var named = 0;
      final leaked = <String>[];
      for (final e in entries.entries) {
        final t = parseThayerEntry(e.key, e.value as String);
        if (t.nameMeaning.isNotEmpty) named++;
        for (final n in t.notes) {
          if (RegExp(r'^[A-Z][A-Za-z ]* = "').hasMatch(n)) leaked.add(e.key);
        }
      }
      expect(named, greaterThan(450));
      expect(leaked, isEmpty);
    });
  });
}
