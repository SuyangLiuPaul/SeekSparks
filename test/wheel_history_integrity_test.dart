import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE THREE CHECKS A WALL CHART FAILED.
///
/// A printed world-history chart of the same kind this wheel draws — one
/// sheet, every nation as a ribbon, every reign as a band — was read out
/// tile by tile and then checked fact by fact against the KJV this app
/// already ships. It is careful work, and it still carried sixteen errors.
/// They fell into exactly three shapes, and only one of the three is
/// something a machine can see:
///
///   1. A DIGIT TRANSPOSED IN A YEAR. Arphaxad's 438 printed as 483;
///      Henry VIII's 1491 as 1481; Cromwell's 1599 as 1559. Nothing
///      detects this. Every year has to be sourced by a person.
///
///   2. A REGNAL NUMERAL REPEATED INSTEAD OF ADVANCED. Gregory VII
///      appeared at 1073 and again at 1227, where the pope elected in
///      1227 was Gregory IX. Leo XIII appeared at 1823 and again at
///      1878, where 1823 was Leo XII. Ahaziah appeared twice in the
///      kings of Judah, where the second was Azariah — and the chart
///      printed Azariah's own fifty-two years and both of his
///      references beside the wrong name. THIS ONE LEAVES A
///      FINGERPRINT: the same name, twice, in one stream, at two
///      different years. That is the first group below — but only for
///      NUMBERED rulers. Ahaziah carries no numeral, so the first group
///      is blind to him, and pretending otherwise would be the same
///      failure this file exists to prevent. He is caught by the fourth
///      group instead, which measures every king the wheel names against
///      the reign `hebrew_kings.json` gives him.
///
///   3. A REFERENCE MANGLED WHILE THE DATA STAYED RIGHT. `Judg. 12:8-10`
///      printed as `Judg. 8:10-12`; `II Kings 16:1-20` as `1:12-20`;
///      `Josh. 11:3` as `John 11:3`; `Ezra 5:1` as `Ex. 5:1`. Five of
///      those six still RESOLVE — they name a real book, a real chapter,
///      a real verse — so a structural validator passes them. Only
///      reading the passage catches them. That is the third group below,
///      and it is the reason the second group is not enough.
///
/// So: the second group is cheap insurance, the third is the one that
/// found the real defects, and neither of them helps with the first.
///
/// WHAT THESE TESTS ARE FOR. The wheel is clean today — nothing here
/// fails as it stands, and none of these was written to fix a known bug.
/// They are written now because the wheel's thinnest streams are the
/// kings of Israel and Judah and the succession of the church, and those
/// are precisely the two places where shape 2 breeds. The check is worth
/// having in place BEFORE that data lands, not after.
///
/// EVERY GROUP BELOW GUARDS ITS OWN VACUITY. A test that has quietly
/// stopped looking at anything passes just as loudly as one that looked
/// and found nothing, so each group first asserts that it really did
/// examine the data — and the last group proves it by rejecting a
/// deliberately wrong reference before it trusts its verdict on the real
/// ones.
void main() {
  final wheel =
      json.decode(File('assets/wheel_history.json').readAsStringSync())
          as Map<String, dynamic>;
  final nations = (wheel['nations'] as List).cast<Map<String, dynamic>>();
  final powers = (wheel['powers'] as List).cast<Map<String, dynamic>>();
  final events = (wheel['events'] as List).cast<Map<String, dynamic>>();

  /// `book` -> `chapter` -> last verse number, and the verse text itself.
  /// Built from the KJV the app ships, so the standard these tests hold the
  /// wheel to is the same text a reader can open in the app and check.
  final lastVerse = <String, Map<int, int>>{};
  final verseText = <String, String>{};
  for (final r in json.decode(File('assets/kjv.json').readAsStringSync())
      as List) {
    final row = r as Map<String, dynamic>;
    final book = row['book'] as String;
    // `kjv.json` numbers its chapters and verses as strings.
    final ch = int.parse('${row['chapter']}');
    final v = int.parse('${row['verse']}');
    final chapters = lastVerse.putIfAbsent(book, () => <int, int>{});
    if (v > (chapters[ch] ?? 0)) chapters[ch] = v;
    verseText['$book|$ch|$v'] = row['text'] as String;
  }

  /// `Genesis 10:2`, `1 Kings 9:20-21`, `Genesis 11` — the shapes the
  /// wheel actually writes. A reference this cannot read is reported as a
  /// failure rather than skipped: silently ignoring the unparseable is how
  /// a reference check stops checking anything.
  final refPattern =
      RegExp(r'^([1-3]?\s*[A-Za-z][A-Za-z ]*?)\s+(\d{1,3})(?::(\d{1,3})(?:\s*-\s*(\d{1,3}))?)?$');

  /// Every scripture reference the wheel states, with where it came from.
  final allRefs = <MapEntry<String, String>>[];
  void collect(String where, Map<String, dynamic> row) {
    final single = row['ref'];
    if (single is String && single.trim().isNotEmpty) {
      allRefs.add(MapEntry(where, single.trim()));
    }
    for (final r in (row['refs'] as List?) ?? const []) {
      if (r is String && r.trim().isNotEmpty) {
        allRefs.add(MapEntry(where, r.trim()));
      }
    }
  }

  for (final n in nations) {
    collect('nations/${n['id']}', n);
  }
  for (final p in powers) {
    collect('powers/${p['id']}', p);
  }
  for (final e in events) {
    collect('events/${e['id']}', e);
  }

  group('no regnal name is repeated instead of advanced', () {
    /// A name and the roman numeral that follows it: `Ramesses II`,
    /// `Tiglath-Pileser III`, `Darius I`. A bare numeral on its own is
    /// ignored — `I` and `V` are ordinary words too often to be evidence.
    final regnal = RegExp(r'\b([A-Z][A-Za-z-]+)\s+([IVXL]{1,5})\b');

    /// `stream|name numeral` -> the years it is stated at.
    final seen = <String, Set<int>>{};
    final examples = <String>{};
    void note(String stream, String name, int year) {
      for (final m in regnal.allMatches(name)) {
        final key = '$stream|${m.group(0)!.toLowerCase()}';
        examples.add(m.group(0)!);
        seen.putIfAbsent(key, () => <int>{}).add(year);
      }
    }

    for (final p in powers) {
      note(p['stream'] as String, (p['name'] as Map)['en'] as String,
          (p['start'] as num).toInt());
    }
    for (final e in events) {
      note(e['stream'] as String, (e['title'] as Map)['en'] as String,
          (e['year'] as num).toInt());
    }

    test('the check is looking at real regnal names', () {
      // Ramesses II, Sargon II, Darius I, Antiochus IV, Herod Agrippa I and
      // II, Peter I... If this number collapses, the group below has stopped
      // guarding anything and is passing for the wrong reason.
      expect(examples.length, greaterThanOrEqualTo(10),
          reason: 'found only $examples');
    });

    test('the same ruler never appears at two different years', () {
      final clashes = <String>[];
      seen.forEach((key, years) {
        if (years.length > 1) {
          clashes.add('$key stated at ${(years.toList()..sort()).join(", ")}');
        }
      });
      // A ruler CAN legitimately head two entries — an accession and a death.
      // If that is ever wanted, the fix is to give the two entries different
      // titles, not to delete this test: the chart's Gregory VII and its
      // Gregory IX were also "the same name at two years", and that was the
      // whole defect.
      expect(clashes, isEmpty);
    });
  });

  group('every scripture reference the wheel states resolves', () {
    test('there are references to check', () {
      expect(allRefs.length, greaterThanOrEqualTo(150));
    });

    test('each one lands on a verse the KJV actually has', () {
      final broken = <String>[];
      for (final entry in allRefs) {
        for (final part in entry.value.split(';')) {
          final text = part.trim();
          if (text.isEmpty) continue;
          final m = refPattern.firstMatch(text);
          if (m == null) {
            broken.add('${entry.key}: "$text" cannot be parsed');
            continue;
          }
          final book = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
          final ch = int.parse(m.group(2)!);
          final chapters = lastVerse[book];
          if (chapters == null) {
            broken.add('${entry.key}: "$text" — no book named "$book"');
            continue;
          }
          final last = chapters[ch];
          if (last == null) {
            broken.add('${entry.key}: "$text" — $book has no chapter $ch');
            continue;
          }
          final from = m.group(3) == null ? null : int.parse(m.group(3)!);
          final to = m.group(4) == null ? from : int.parse(m.group(4)!);
          if (from != null && from > last) {
            broken.add('${entry.key}: "$text" — $book $ch ends at verse $last');
          } else if (to != null && to > last) {
            broken.add('${entry.key}: "$text" — range ends past $book $ch:$last');
          } else if (from != null && to != null && to < from) {
            broken.add('${entry.key}: "$text" — the range runs backwards');
          }
        }
      }
      expect(broken, isEmpty);
    });
  });

  group('every nation is named in the verse it cites', () {
    /// This is the group that matters, and the reason is worth stating.
    ///
    /// The check above proves a reference EXISTS. It cannot prove the
    /// reference is ABOUT the thing it is attached to, and that is the
    /// defect that actually got through on the printed chart: `John 11:3`
    /// beside the Perizzites is a real verse about Lazarus, and every
    /// structural validator in the world passes it.
    ///
    /// The 82 nations are where this can be settled completely rather than
    /// sampled: all of them cite Genesis 10 or 11, and every one of them is
    /// a name the passage either says or does not say.

    /// The wheel's English and the KJV's spelling do not always agree
    /// (Kittim/Chittim), so the comparison is on a prefix of the letters.
    String letters(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

    /// The verses a reference covers, joined. A chapter-only reference
    /// ("Genesis 11") is read as the whole chapter.
    String passageFor(String ref) {
      final m = refPattern.firstMatch(ref.trim());
      if (m == null) return '';
      final book = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      final ch = int.parse(m.group(2)!);
      final chapters = lastVerse[book];
      if (chapters == null || chapters[ch] == null) return '';
      final from = m.group(3) == null ? 1 : int.parse(m.group(3)!);
      final to = m.group(3) == null
          ? chapters[ch]!
          : (m.group(4) == null ? from : int.parse(m.group(4)!));
      final buffer = StringBuffer();
      for (var v = from; v <= to; v++) {
        buffer.write(verseText['$book|$ch|$v'] ?? '');
        buffer.write(' ');
      }
      return buffer.toString();
    }

    bool named(String name, String ref) {
      final stem = letters(name);
      if (stem.length < 3) return true; // too short to assert anything about
      return letters(passageFor(ref)).contains(
          stem.length > 5 ? stem.substring(0, 5) : stem);
    }

    test('the matcher rejects a reference that merely resolves', () {
      // Proof that the assertion below is capable of failing. Both of these
      // are real, resolvable references; neither passage names the nation.
      // They are the exact shape of the defect this group exists to catch.
      expect(named('Magog', 'John 11:3'), isFalse);
      expect(named('Meshech', 'Genesis 5:32'), isFalse);
      // ...and that it still accepts the true one.
      expect(named('Meshech', 'Genesis 10:2'), isTrue);
    });

    test('all 82 nations are named where they point', () {
      expect(nations.length, greaterThanOrEqualTo(82));
      final wrong = <String>[];
      for (final n in nations) {
        final name = (n['name'] as Map)['en'] as String;
        final ref = (n['ref'] as String?)?.trim() ?? '';
        if (ref.isEmpty) {
          wrong.add('${n['id']}: no reference at all');
          continue;
        }
        if (!named(name, ref)) {
          wrong.add('${n['id']}: "$name" is not named in $ref');
        }
      }
      expect(wrong, isEmpty);
    });
  });

  group('no king is placed outside the reign this app gives him', () {
    /// The check that catches the chart's worst single error, and the one
    /// the regnal-numeral group above cannot: AHAZIAH printed where the
    /// Bible has AZARIAH, carrying Azariah's fifty-two years and both of
    /// Azariah's references. No numeral, so no fingerprint — but the year
    /// was ninety years away from the only Ahaziah of Judah there is.
    ///
    /// The app already ships the answer: `hebrew_kings.json` is its Thiele
    /// chart, forty-two kings with reigns, and the same file that
    /// `cross_asset_year_agreement_test.dart` treats as authoritative for
    /// the division of the kingdom. So this asks only for consistency
    /// between two files we already ship, never for an outside authority.
    ///
    /// A NOTE ON WHAT THIS GUARDS TODAY. The wheel currently names exactly
    /// one of those forty-two kings, which is itself the finding: the
    /// kings are dated, referenced and translated in `hebrew_kings.json`
    /// and almost none of them is on the wheel. This test is therefore
    /// mostly insurance on work not yet done — which is the right time to
    /// write it, not after.

    final kings = (json
                .decode(File('assets/hebrew_kings.json').readAsStringSync())
            as Map<String, dynamic>)['kings'] as List;

    /// Lower-cased king name -> every reign span stated for him.
    final reigns = <String, List<List<int>>>{};
    for (final k in kings.cast<Map<String, dynamic>>()) {
      final name = ((k['name'] as Map)['en'] as String).toLowerCase();
      for (final s in (k['spans'] as List).cast<Map<String, dynamic>>()) {
        final from = (s['start'] as num).toInt();
        final to = (s['end'] as num).toInt();
        reigns
            .putIfAbsent(name, () => <List<int>>[])
            .add([from < to ? from : to, from < to ? to : from]);
      }
    }

    /// Every king named in [title] whose reign does not contain [year].
    /// A three-year grace absorbs the accession-vs-first-full-year
    /// convention, which is a real disagreement between chronologists and
    /// not the defect being hunted here.
    List<String> misplaced(String title, int year) {
      final lower = title.toLowerCase();
      final out = <String>[];
      reigns.forEach((name, spans) {
        if (!RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(lower)) return;
        final inside = spans.any((s) => year >= s[0] - 3 && year <= s[1] + 3);
        if (!inside) out.add('"$name" at $year, but he reigned $spans');
      });
      return out;
    }

    test('the check would catch the chart\'s Ahaziah', () {
      // Ahaziah of Judah reigned one year, about 841 BC. The chart put his
      // name on Azariah's fifty-two-year reign, which begins about 792.
      expect(misplaced('Ahaziah Reigns Fifty-Two Years', -792), isNotEmpty);
      // The same sentence at his own date must NOT be flagged, or the
      // check is just noise.
      expect(misplaced('Ahaziah Reigns in Judah', -841), isEmpty);
    });

    test('every king the wheel names is inside his reign', () {
      final wrong = <String>[];
      for (final e in events) {
        final stream = e['stream'] as String;
        if (stream != 'israel' && stream != 'judah') continue;
        for (final m in misplaced((e['title'] as Map)['en'] as String,
            (e['year'] as num).toInt())) {
          wrong.add('events/${e['id']}: $m');
        }
      }
      for (final p in powers) {
        final stream = p['stream'] as String;
        if (stream != 'israel' && stream != 'judah') continue;
        for (final m in misplaced((p['name'] as Map)['en'] as String,
            (p['start'] as num).toInt())) {
          wrong.add('powers/${p['id']}: $m');
        }
      }
      expect(wrong, isEmpty);
    });
  });
}
