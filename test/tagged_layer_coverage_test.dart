// The question `bsb_tagged_layer_test.dart` asks of the BSB, asked of the
// other four tagged editions — because it had never been asked of them.
//
// Every tagged edition ships twice: `assets/<code>.json` is the text on
// the page, `assets/tagged/<code>/<book>.json` is what the word under the
// reader's finger answers. They are made by different processes from
// different sources, so each is a witness to the other, and no outside
// authority is needed to ask whether they agree.
//
// Before this file, only the BSB was held to that. `kjvs` and
// `cuvs-plus` had no tagged-layer test at all; `lxxwh` and `cuvs-yhwh`
// had tests about their Strong's numbers and their markup, but nothing
// compared either layer to its own printed text. Check 21 had found
// `assets/tagged/lxxwh/nehemiah.json` missing 15 of Nehemiah 10's verses
// and said in as many words that the gap "has never been chased across
// the other books". This is that sweep, frozen.
//
// The answer, measured over 155,193 verses: three editions reconstruct
// their printed text byte for byte, one has two known departures, 21
// verses of real Greek are absent from a tagged layer, and `cuvs-yhwh`
// disagrees with itself in 350 verses — 372 before check 45g repaired the
// 22 that needed no adjudication — of which the real word differences are
// defects in BOTH files. See docs/DATA-INTEGRITY.md checks 45 and 45g.
//
// WHAT THIS CANNOT SEE, stated because a detector reports its own reach:
// a shift present in BOTH layers. Check 40 found `cuvs-plus` numbering
// the whole of 1 Chronicles 22 one verse low, and its tagged layer
// carried the identical shift — the two agreed with each other, and
// these tests would have passed them. Catching that needed a third
// layer. This file guards against one layer drifting off the other, not
// against both drifting together.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/verse_text_absence.dart';

const _books = <String>[
  'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
  'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
  '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
  'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
  'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel',
  'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
  'haggai', 'zechariah', 'malachi', 'matthew', 'mark', 'luke', 'john',
  'acts', 'romans', '1_corinthians', '2_corinthians', 'galatians',
  'ephesians', 'philippians', 'colossians', '1_thessalonians',
  '2_thessalonians', '1_timothy', '2_timothy', 'titus', 'philemon',
  'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john', '3_john',
  'jude', 'revelation',
];

// `nsn-plus` is deliberately not here. The Eagle's View NASB is licensed,
// never committed and never deployed, so a test that read it would pass
// on this machine and fail on every other.
const _editions = <String>['bsb', 'kjvs', 'lxxwh', 'cuvs-yhwh', 'cuvs-plus'];

/// The 21 verses of real Greek that no tagged record covers.
///
/// Every one carries words in `assets/lxxwh.json`, so this is
/// under-coverage and not a false statement: `TaggedTextService.forVerse`
/// returns null and the caller falls back to the plain string, so the
/// reader still sees the Greek and simply cannot tap it. They are frozen
/// by name rather than by count so that a repair of one cannot be
/// cancelled out by a regression in another.
///
/// One caller is not graceful: `kwic_pane.dart:127` skips the line while
/// `_totalRefs` still counts the reference, so its "All N references"
/// footer overstates when a hit lands on one of these. Recorded here
/// because it is the reason this set matters beyond tidiness.
const _lxxwhUntagged = <String>{
  '1 Chronicles 1:30',
  'Ezra 10:35', 'Ezra 10:36', 'Ezra 10:40',
  'Nehemiah 10:3', 'Nehemiah 10:4', 'Nehemiah 10:5', 'Nehemiah 10:11',
  'Nehemiah 10:12', 'Nehemiah 10:15', 'Nehemiah 10:16', 'Nehemiah 10:18',
  'Nehemiah 10:19', 'Nehemiah 10:20', 'Nehemiah 10:21', 'Nehemiah 10:22',
  'Nehemiah 10:24', 'Nehemiah 10:25', 'Nehemiah 10:27',
  'Nehemiah 12:2', 'Nehemiah 12:3',
};

/// The BSB's two departures, both of them the tagged layer dropping a
/// word its printed text has: "of silver" at Exodus 38:28 and "it" at
/// Judges 16:14. `assets/bsb.json` is the verified side — check 27
/// measured it at 100.0000% against bereanbible.com — so the tagged
/// layer is the one carrying an older revision's wording.
const _bsbDepartures = <String>{'Exodus 38:28', 'Judges 16:14'};

final _tag = RegExp(r'<[^>]*>');
final _marginal = RegExp('〔[^〕]*〕');
final _punct = RegExp(r'''[，。、；：？！「」『』（）〔〕,.;:?!()'"“”‘’—\-–\[\]]''');
final _space = RegExp(r'\s+');

/// The stream both layers should agree on: no markup, no punctuation,
/// no whitespace.
String _normalise(String text) =>
    text.replaceAll(_tag, '').replaceAll(_punct, '').replaceAll(_space, '');

/// The Han characters only, with the 和合本's 〔…〕 marginal notes removed.
String _hanStream(String text) {
  final t = text.replaceAll(_tag, '').replaceAll(_marginal, '');
  return String.fromCharCodes(
      t.runes.where((r) => r >= 0x4E00 && r <= 0x9FFF));
}

/// Book name as the flat assets' `id` numbers it, 1-based.
const _canonNames = <String>[
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
  'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
  '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
  'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
  'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
  'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
  'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John',
  'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
  'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
  '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
  'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
  'Jude', 'Revelation',
];

class _Sweep {
  _Sweep(this.edition);

  final String edition;

  /// Verses in the flat text with no tagged record, whose stored string
  /// is real scripture rather than a placeholder.
  final Set<String> untagged = <String>{};

  /// Verses with no tagged record whose stored string is a placeholder —
  /// having nothing to tag is correct for these.
  int placeholders = 0;

  /// Tagged records naming a verse the flat text does not have.
  final Set<String> orphans = <String>{};

  /// Verses where both layers exist and their text streams differ.
  final Set<String> differ = <String>{};

  /// Verses where the concatenated runs equal the flat string with no
  /// normalisation at all.
  int byteIdentical = 0;

  int compared = 0;
  int flatVerses = 0;
}

Future<_Sweep> _sweep(String edition) async {
  final sweep = _Sweep(edition);
  final flat = jsonDecode(await rootBundle.loadString('assets/$edition.json'))
      as List<dynamic>;

  // book number -> "chapter:verse" -> text
  final byBook = <int, Map<String, String>>{};
  for (final row in flat) {
    final v = row as Map<String, dynamic>;
    final book = int.parse((v['id'] as String).substring(0, 3));
    final ref = '${int.parse('${v['chapter']}')}:${int.parse('${v['verse']}')}';
    (byBook[book] ??= <String, String>{})[ref] = v['text'] as String;
    sweep.flatVerses++;
  }

  final chinese = edition.startsWith('cuvs');

  for (var i = 0; i < _books.length; i++) {
    final bookNumber = i + 1;
    final name = _canonNames[i];
    final raw = await rootBundle
        .loadString('assets/tagged/$edition/${_books[i]}.json');
    final tagged = jsonDecode(raw) as Map<String, dynamic>;

    final runsByRef = <String, String>{};
    for (final entry in tagged.entries) {
      final parts = entry.key.split(':');
      final ref = '${int.parse(parts[0])}:${int.parse(parts[1])}';
      runsByRef[ref] = (entry.value as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['w'] as String)
          .join();
    }

    final flatBook = byBook[bookNumber] ?? const <String, String>{};
    for (final ref in flatBook.keys) {
      final text = flatBook[ref]!;
      final runs = runsByRef[ref];
      if (runs == null) {
        if (verseAbsenceOf(text) != null) {
          sweep.placeholders++;
        } else {
          sweep.untagged.add('$name $ref');
        }
        continue;
      }
      sweep.compared++;
      if (text == runs) sweep.byteIdentical++;
      if (_normalise(text) == _normalise(runs)) continue;
      if (chinese && _hanStream(text) == _hanStream(runs)) continue;
      sweep.differ.add('$name $ref');
    }
    for (final ref in runsByRef.keys) {
      if (!flatBook.containsKey(ref)) sweep.orphans.add('$name $ref');
    }
  }
  return sweep;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, _Sweep> sweeps;

  setUpAll(() async {
    sweeps = <String, _Sweep>{};
    for (final edition in _editions) {
      sweeps[edition] = await _sweep(edition);
    }
  });

  test('no tagged record names a verse its edition does not have', () {
    // An orphan is the shape a versification shift takes when only one
    // layer moves, and it is the cheapest signal that an import went in
    // against the wrong reference.
    for (final edition in _editions) {
      expect(sweeps[edition]!.orphans, isEmpty,
          reason: '$edition has tagged records for absent verses');
    }
  });

  test('every verse without a tagged record is a placeholder, or a known gap',
      () {
    // This also holds `kVerseAbsenceMarkers` against the corpus from the
    // other direction: a placeholder string the table did not know would
    // arrive here as an untagged verse rather than being silently
    // counted as scripture.
    expect(sweeps['bsb']!.untagged, isEmpty);
    expect(sweeps['kjvs']!.untagged, isEmpty);
    expect(sweeps['cuvs-yhwh']!.untagged, isEmpty);
    expect(sweeps['cuvs-plus']!.untagged, isEmpty);
    expect(sweeps['lxxwh']!.untagged, _lxxwhUntagged);
  });

  test('the placeholder counts are the ones check 45 measured', () {
    expect(sweeps['bsb']!.placeholders, 0);
    expect(sweeps['kjvs']!.placeholders, 0);
    expect(sweeps['cuvs-yhwh']!.placeholders, 0);
    expect(sweeps['lxxwh']!.placeholders, 16); // the WH `OMIT` verses
    expect(sweeps['cuvs-plus']!.placeholders, 74); // 见上节 and two blanks
  });

  test('three tagged layers reconstruct their printed text exactly', () {
    // No allowance and no ceiling: these three are held to identity, so
    // a single dropped word anywhere in 92,894 verses fails the build.
    expect(sweeps['kjvs']!.differ, isEmpty);
    expect(sweeps['lxxwh']!.differ, isEmpty);
    expect(sweeps['cuvs-plus']!.differ, isEmpty);
  });

  test('and they do it without needing the normalisation', () {
    // The stronger form of the test above: the runs joined together
    // equal the flat string with nothing stripped. If this ever fails
    // while the test above passes, the normalisation has started
    // carrying the result — which is how a real difference hides.
    expect(sweeps['kjvs']!.byteIdentical, 31102);
    expect(sweeps['cuvs-plus']!.byteIdentical, 31029);
    // lxxwh is 2 short of its 30,763: Numbers 10:35 and Deuteronomy
    // 23:23 carry one trailing space on the tagged side.
    expect(sweeps['lxxwh']!.byteIdentical, 30761);
  });

  test('the BSB tagged layer departs from its printed text in exactly two '
      'verses', () {
    expect(sweeps['bsb']!.differ, _bsbDepartures);
  });

  test('the Chinese layers disagree in at most the 350 left after check 45g',
      () {
    // Holding `cuvs-yhwh`'s two layers to identity would fail for the
    // wrong reason: 161 of check 45d's 372 differ only by settled
    // orthographic pairs (阿/啊, 复/覆, 它/他/她, 吗/么), 116 by where a
    // gloss sits, and 16 are an alignment artefact of removing the 〔…〕
    // notes.
    //
    // But 79 ARE a real word difference, and they are defects in both
    // files. Check 45g repaired the 22 that needed no adjudication — 15
    // verses printing a literal `#`, 7 doubling a character against
    // itself — which is why the ceiling is 350 and not 372.
    //
    // It is still a HOLDING POSITION over a known defect, not a clean
    // result: 21 word-level defects remain in the flat text the reader
    // reads (Isaiah 23:1 no longer names 推罗; Judges 12:7 has lost the
    // 六 of 六年). Tighten it again as those are fixed — do not read a
    // green tick here as the layers agreeing.
    expect(sweeps['cuvs-yhwh']!.differ.length, lessThanOrEqualTo(350));
  });

  test('no tagged run prints a character that is not text', () async {
    // 15 verses render a literal `#` where the flat text prints [基督] —
    // 「算不得吃主#的晚餐」. `browse_window.dart`'s `_TaggedLine` renders
    // the run verbatim, so this is on screen, not just in the file.
    // Frozen by name: the count may only go down.
    const known = <String>{
      'matthew 22:43', 'matthew 22:44', 'matthew 22:45',
      'mark 12:36', 'mark 12:37',
      'luke 20:42', 'luke 20:44',
      'acts 2:34', 'romans 14:9',
      '1_corinthians 11:20', '1_corinthians 11:26', '1_corinthians 11:27',
      '1_thessalonians 4:15', '1_thessalonians 4:16', '1_thessalonians 4:17',
    };
    final found = <String>{};
    for (final book in _books) {
      final raw = await rootBundle
          .loadString('assets/tagged/cuvs-yhwh/$book.json');
      final tagged = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in tagged.entries) {
        final text = (entry.value as List<dynamic>)
            .map((r) => (r as Map<String, dynamic>)['w'] as String)
            .join();
        if (text.contains('#')) found.add('$book ${entry.key}');
      }
    }
    expect(found.difference(known), isEmpty,
        reason: 'a new verse prints a literal # in the tagged layer');
    expect(found.length, lessThanOrEqualTo(known.length));
  });

  test('the corpus is the size check 45 measured', () {
    final flat =
        _editions.map((e) => sweeps[e]!.flatVerses).reduce((a, b) => a + b);
    final compared =
        _editions.map((e) => sweeps[e]!.compared).reduce((a, b) => a + b);
    expect(flat, 155193);
    expect(compared, 155082);
  });
}
