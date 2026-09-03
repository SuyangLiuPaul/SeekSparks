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
///
/// WHERE THE SIBLING ASSETS ARE COVERED, so nobody writes this twice:
/// `data_integrity_test.dart` already sweeps `ot_synopsis`,
/// `gospel_synopsis`, `family_tree`, `bible_timeline`, `bible_evidence`,
/// `hebrew_kings` and `section_titles` for references that name a verse
/// which does not exist. `wheel_history.json` was the one asset in that
/// family it did not reach, which is why the second group below exists.
/// The 97 narrative events merged in from `bible_timeline.json` at load
/// are pinned by `wheel_bible_narrative_test.dart` and their references
/// by that same sweep, so this file deliberately reads the wheel's own
/// asset and does not re-check them.
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
    ///
    /// 2026-09-03: it takes the WHOLE run of capitalised words before the
    /// numeral, not just the last one. With only the last, `John Paul II`
    /// keyed as `paul ii` and collided with `Paul II` — two popes five
    /// centuries apart reported as one man reigning twice, which is what
    /// this check exists to deny. A compound regnal name is a different
    /// name, not the same one with a word in front.
    final regnal =
        RegExp(r'\b((?:[A-Z][A-Za-z-]+\s+)*[A-Z][A-Za-z-]+)\s+([IVXL]{1,5})\b');

    /// …but an HONORIFIC in front is not part of the name, and dropping
    /// it is what keeps `Pope Paul II` and `Paul II` the same key — the
    /// clash this check is actually for.
    const honorifics = {
      'pope', 'king', 'queen', 'emperor', 'empress', 'pharaoh', 'tsar',
      'czar', 'sultan', 'caliph', 'saint', 'st', 'antipope',
    };
    String regnalKey(RegExpMatch m) {
      final words = m.group(1)!.split(RegExp(r'\s+'));
      while (words.length > 1 && honorifics.contains(words.first.toLowerCase())) {
        words.removeAt(0);
      }
      return '${words.join(' ')} ${m.group(2)}'.toLowerCase();
    }

    /// `stream|name numeral` -> the years it is stated at.
    final seen = <String, Set<int>>{};
    final examples = <String>{};
    void note(String stream, String name, int year) {
      for (final m in regnal.allMatches(name)) {
        final key = '$stream|${regnalKey(m)}';
        examples.add(m.group(0)!);
        seen.putIfAbsent(key, () => <int>{}).add(year);
      }
    }

    /// `stream|name numeral` -> the reigns it is stated as a SPAN.
    final reigns = <String, List<({int start, int end})>>{};

    for (final p in powers) {
      final start = (p['start'] as num).toInt();
      final end = (p['end'] as num?)?.toInt() ?? start;
      for (final m
          in regnal.allMatches((p['name'] as Map)['en'] as String)) {
        final key = '${p['stream']}|${regnalKey(m)}';
        examples.add(m.group(0)!);
        reigns.putIfAbsent(key, () => []).add((start: start, end: end));
      }
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
      // 2026-09-02: this used to fold a power's START into the same set
      // as an event's year, and 42 pontificates broke it correctly —
      // Pope Nicholas I reigns 858–867 and an event has him deposing
      // two archbishops in 863. Same man, two years, and no defect at
      // all: one is a reign and the other is a thing he did inside it.
      //
      // The premise only ever held while every record was a POINT. So
      // the check now reads a span as an interval, which makes it
      // STRICTER rather than looser — an event attributed to a ruler
      // outside his own reign is a new thing it can catch, and the
      // chart's Gregory VII / Gregory IX defect is still caught by the
      // last clause exactly as before.
      final clashes = <String>[];

      reigns.forEach((key, spans) {
        if (spans.length > 1) {
          clashes.add('$key reigns twice: '
              '${spans.map((s) => "${s.start}-${s.end}").join(", ")}');
        }
      });

      seen.forEach((key, years) {
        final spans = reigns[key];
        if (spans == null || spans.isEmpty) {
          // No reign known for him: the original check, unchanged. A
          // ruler CAN legitimately head two entries — an accession and
          // a death — and if that is ever wanted the fix is to give the
          // two entries different titles, not to delete this test.
          if (years.length > 1) {
            clashes.add(
                '$key stated at ${(years.toList()..sort()).join(", ")}');
          }
          return;
        }
        for (final y in years) {
          final inside =
              spans.any((s) => y >= s.start - 1 && y <= s.end + 1);
          if (!inside) {
            clashes.add('$key acts in $y, outside '
                '${spans.map((s) => "${s.start}-${s.end}").join(", ")}');
          }
        }
      });

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

    /// The wheel's English and an edition's spelling do not always agree
    /// (Kittim/Chittim), so the comparison is on a prefix of the letters.
    String letters(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

    /// EVERY ENGLISH BIBLE THE APP SHIPS, not just the KJV — and the
    /// change is the whole point of this block rather than a widening
    /// of convenience.
    ///
    /// The band at Genesis 10:24 used to display "Salah" because that
    /// is what the KJV reads there, while `family_tree.json`,
    /// `bible_timeline.json` and the birth spoke the wheel draws all
    /// said "Shelah". The owner saw a spoke reading "Birth of Kenan"
    /// beside an arc reading "Cainan" and ruled for the modern
    /// spellings, so the band reads "Shelah" now.
    ///
    /// Witnessing that against the KJV alone would fail it, and the
    /// failure would be an artefact of asking one edition. The app
    /// ships five English Bibles and the reader can open any of them:
    /// Genesis 10:24 reads "Shelah" in the BSB, the NASB and the LEB,
    /// and "Salah" in the KJV and `kjvs.json`. So the standard is the
    /// one `family_tree_names_test.dart` already holds the tree to —
    /// SOME shipped edition of the verse the record itself cites must
    /// contain the name printed over it. No aliases, no near misses,
    /// and no second chance from a verse the record does not point at.
    const editions = <String>['kjv', 'bsb', 'nasb', 'leb', 'kjvs'];
    final byEdition = <String, Map<String, String>>{};
    for (final ed in editions) {
      final rows = <String, String>{};
      for (final r
          in json.decode(File('assets/$ed.json').readAsStringSync()) as List) {
        final row = r as Map<String, dynamic>;
        // Psalm superscriptions carry `title` where a verse number
        // belongs; they are not verses and nothing here cites one.
        final v = int.tryParse('${row['verse']}');
        if (v == null) continue;
        rows['${row['book']}|${int.parse('${row['chapter']}')}|$v'] =
            row['text'] as String;
      }
      byEdition[ed] = rows;
    }

    /// The verses a reference covers, joined, in one edition. A
    /// chapter-only reference ("Genesis 11") is read as the whole
    /// chapter. Chapter LENGTHS stay the KJV's, because they decide
    /// which verses to read, not what those verses say.
    String passageIn(String ref, String edition) {
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
        buffer.write(byEdition[edition]!['$book|$ch|$v'] ?? '');
        buffer.write(' ');
      }
      return buffer.toString();
    }

    bool namedIn(String name, String ref, String edition) {
      final stem = letters(name);
      if (stem.length < 3) return true; // too short to assert anything about
      return letters(passageIn(ref, edition)).contains(
          stem.length > 5 ? stem.substring(0, 5) : stem);
    }

    /// Which shipped edition witnesses this name at this reference, or
    /// null when none does.
    String? witnessFor(String name, String ref) {
      for (final ed in editions) {
        if (namedIn(name, ref, ed)) return ed;
      }
      return null;
    }

    test('the matcher rejects a reference that merely resolves', () {
      // Proof that the assertion below is capable of failing. Both of these
      // are real, resolvable references; neither passage names the nation
      // in ANY edition the app ships. They are the exact shape of the
      // defect this group exists to catch.
      expect(witnessFor('Magog', 'John 11:3'), isNull);
      expect(witnessFor('Meshech', 'Genesis 5:32'), isNull);
      // ...and that it still accepts the true one.
      expect(witnessFor('Meshech', 'Genesis 10:2'), isNotNull);
      // The editions really are different texts, which is what makes
      // the widening above mean anything. If this ever passes for the
      // KJV the fixture has silently loaded the same file five times.
      expect(namedIn('Shelah', 'Genesis 10:24', 'kjv'), isFalse);
      expect(namedIn('Shelah', 'Genesis 10:24', 'bsb'), isTrue);
      expect(namedIn('Salah', 'Genesis 10:24', 'kjv'), isTrue);
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
        if (witnessFor(name, ref) == null) {
          wrong.add('${n['id']}: "$name" is named in $ref by no edition '
              'this app ships');
        }
      }
      expect(wrong, isEmpty);
    });

    /// THE BRIDGE BACK TO THE KJV, and the reason it is an assertion
    /// rather than a courtesy.
    ///
    /// A band the KJV does not witness is a band a KJV reader cannot
    /// reconcile: they are looking at Genesis 10:24, it says "Salah",
    /// and the wheel says "Shelah". `nameKjv` is what closes that — it
    /// is printed under the name and searched wherever a name is
    /// searched, so the older spelling still finds the man. Requiring
    /// it exactly where the KJV disagrees means the bridge cannot be
    /// forgotten the next time a name is modernised.
    test('every name the KJV spells differently carries its KJV form', () {
      final missing = <String>[];
      final wrong = <String>[];
      for (final n in nations) {
        final name = (n['name'] as Map)['en'] as String;
        final ref = (n['ref'] as String?)?.trim() ?? '';
        final kjvName = (n['nameKjv'] as String?) ?? '';
        if (ref.isEmpty) continue;
        if (!namedIn(name, ref, 'kjv') && kjvName.isEmpty) {
          missing.add('${n['id']}: "$name" is not in the KJV at $ref and the '
              'record carries no nameKjv, so a reader of the KJV has no way '
              'back to him');
        }
        if (kjvName.isNotEmpty && !namedIn(kjvName, ref, 'kjv')) {
          wrong.add('${n['id']}: nameKjv "$kjvName" is not what the KJV reads '
              'at $ref');
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });

    /// TWO ROWS, ONE LABEL, AND NOTHING ON SCREEN TELLING THEM APART.
    ///
    /// The band sheet lists a stream's nations as name + reference, so
    /// two records that display the same string in the same stream read
    /// as one man written twice. The Israel sheet did exactly that for
    /// Genesis 11:22 (Terah's father) and Genesis 11:26 (Abram's
    /// brother) — both "Nahor" — and `family_tree.json` had already
    /// settled that pair as `nahor_elder` "Nahor (the elder)" /
    /// 拿鹤(亚伯拉罕祖父) and `nahor_younger` "Nahor". Those exact
    /// strings are now what the bands display, so the two are told
    /// apart in all three scripts by the label itself and not only by
    /// the note under it.
    ///
    /// TWO PAIRS ARE LEFT AND ARE ALLOWED BY NAME, because there is no
    /// honest string to give them. Genesis 10 holds two men called
    /// Havilah (10:7, Cush's son; 10:29, Joktan's) and two called Sheba
    /// (10:7, Raamah's son; 10:28, Joktan's), and `family_tree.json`
    /// carries no record of any of the four — so unlike Nahor there is
    /// no existing display string to copy, and writing one here would
    /// be inventing a name the app does not otherwise use. What is
    /// required of them instead is the thing that IS in the text: each
    /// must carry a `note`, in all three locales, and the note must
    /// cite the other one's chapter and verse. The exception is
    /// therefore a documented one rather than a hole, and a NEW
    /// collision — one nobody has looked at — still fails.
    test('no two bands in a stream display the same name', () {
      // The pairs Genesis itself doubles, with no second spelling to
      // reach for. Anything else colliding is a defect.
      const allowed = {'Havilah', 'Sheba'};
      final clashes = <String>[];
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final byKey = <String, List<Map<String, dynamic>>>{};
        for (final n in nations) {
          final names = n['name'] as Map;
          final shown = (names[locale] ?? names['en']) as String;
          byKey.putIfAbsent('${n['stream']}|$shown', () => []).add(n);
        }
        byKey.forEach((key, group) {
          if (group.length < 2) return;
          final en = (group.first['name'] as Map)['en'] as String;
          if (allowed.contains(en)) return;
          clashes.add('$locale $key: '
              '${group.map((n) => n['id']).join(', ')}');
        });
      }
      expect(clashes, isEmpty,
          reason: 'a band sheet would print these rows with the same '
              'label and no way to tell them apart\n${clashes.join('\n')}');
    });

    /// The price of the exception above: an allowed twin must say, in
    /// every locale, where its namesake is. Without this the allow-list
    /// would be a licence rather than a record.
    test('every allowed twin points at its namesake in all three locales',
        () {
      const allowed = {'Havilah', 'Sheba'};
      // Where the OTHER one of each pair is stated, by band id. Written
      // out rather than derived, so a band silently changing its
      // reference cannot quietly satisfy its twin's note.
      const namesake = {
        'havilah_cush': '10:29',
        'havilah_joktan': '10:7',
        'sheba_raamah': '10:28',
        'sheba_joktan': '10:7',
      };
      final twins = nations
          .where((n) => allowed.contains((n['name'] as Map)['en']))
          .toList();
      expect(twins.map((n) => n['id']).toSet(), namesake.keys.toSet(),
          reason: 'the allow-list and the bands must name the same records');
      final bad = <String>[];
      for (final n in twins) {
        final note = n['note'] as Map?;
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          final text = note?[locale] as String?;
          if (text == null || text.isEmpty) {
            bad.add('${n['id']}: no $locale note');
            continue;
          }
          if (!text.contains(namesake[n['id']]!)) {
            bad.add('${n['id']}: the $locale note does not cite '
                '${namesake[n['id']]}, so a reader cannot find the other one');
          }
        }
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
    });

    /// The Nahor pair specifically, pinned to the strings
    /// `family_tree.json` already uses. Copied, never coined: if the
    /// tree ever renames those two records, this fails rather than
    /// letting the wheel drift away from it.
    test('the two Nahors display what the family tree calls them', () {
      final tree = jsonDecode(
              File('assets/family_tree.json').readAsStringSync())
          as Map<String, dynamic>;
      final people = {
        for (final p in (tree['people'] as List).cast<Map<String, dynamic>>())
          p['id'] as String: p,
      };
      final bands = {for (final n in nations) n['id'] as String: n};
      for (final pair in const [
        ('nahor', 'nahor_elder'),
        ('nahor_terah', 'nahor_younger'),
      ]) {
        final band = bands[pair.$1]!;
        final person = people[pair.$2]!;
        final names = band['name'] as Map;
        expect(names['en'], person['name'], reason: pair.$1);
        expect(names['zh-Hans'], person['nameZhHans'], reason: pair.$1);
        expect(names['zh-Hant'], person['nameZhHant'], reason: pair.$1);
      }
      // And the band still cites the verse it always did — a display
      // name is the only thing that moved.
      expect(bands['nahor']!['ref'], 'Genesis 11:22');
      expect(bands['nahor_terah']!['ref'], 'Genesis 11:26');
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
    /// A DYNASTY IS NOT A REIGN, and English spells it with the king's
    /// own name. "Jehu's Revolt Ends the House of Ahab" is dated 841 —
    /// twelve years after Ahab himself died, which is exactly right,
    /// because what ended then was his LINE. The check read the name and
    /// called it misplaced.
    ///
    /// Narrow on purpose: only `house of X` and `X's house`, and only
    /// for that occurrence. A title that names the man anywhere else in
    /// the same sentence is still checked against his reign.
    String stripDynasties(String lower) => lower
        .replaceAll(RegExp(r"\bhouse of \w+"), ' ')
        .replaceAll(RegExp(r"\b\w+'s house\b"), ' ');

    List<String> misplaced(String title, int year) {
      final lower = stripDynasties(title.toLowerCase());
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

      // The dynasty exception, both ways. A house may be named long
      // after its founder died...
      expect(misplaced('Jehu\'s Revolt Ends the House of Ahab', -841),
          isEmpty);
      // ...but the man himself, in the same sentence, is still checked.
      expect(misplaced('Ahab Falls with the House of Omri', -841),
          isNotEmpty);
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
