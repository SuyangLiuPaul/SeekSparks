import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/wheel_history.dart';

/// THE COVERAGE PASS OF 2026-09-05, AND THE THREE RULES IT LEFT BEHIND.
///
/// The occasion was a re-measurement. `docs/OPEN-ITEMS.md` said "462 of
/// the chart's 784 names are still off the wheel" under a `[verified
/// 2026-09-04]` tag; neither number reproduces. The checklist has 786
/// distinct headwords, not 784, and every one of them is accounted for
/// — covered, placed, or refused with a stated reason — because three
/// audit passes ran AFTER the sentence carrying the 462 was written and
/// closed it. So this file does not pin a count of names remaining.
/// Counts of that kind are what went stale.
///
/// It pins three RULES instead, each of which is a defect the
/// re-measurement actually found, stated so that the defect cannot
/// return:
///
///   1. NO EVENT IS DRAWN TWICE. Three pairs were drawing one event on
///      two rings — Einstein at 1905, Kitty Hawk at 1903, and Columbus
///      at 1492 and again at 1500. The wheel has no way to notice: two
///      records with different ids on different streams are two
///      perfectly legal records, and every test in this directory
///      passed over all three.
///
///   2. A CHAIN THE WHEEL DRAWS IS DRAWN WHOLE. The Chinese stream drew
///      Shang, Zhou, Han, Jin, Sui, Tang, Song, Yuan, Ming and Qing and
///      skipped Qin, the Three Kingdoms and the northern-southern
///      dynasties. The Islamic stream jumped from the Abbasids ending
///      1258 to the Ottomans starting 1299, over two and a half
///      centuries in which the Mamluks held Jerusalem. Neither hole was
///      a judgement about what belongs on a Bible-study wheel; both
///      were simply unnoticed, because nothing read a stream in order.
///
///   3. THE JUDGES BAND ARRANGES NOTHING INSIDE ITSELF. `judges-of-israel`
///      is the one addition here that could quietly become a lie. The
///      app rules the era counted and not drawn, because the years the
///      book states sum to about 530 against the 479 of 1 Kings 6:1;
///      the band states the era's outer ends and no more. The day
///      someone puts Gideon on the axis inside it, that ruling has been
///      reversed by accident, and this fails.
///
/// EVERY RULE HERE WAS MUTATED BEFORE IT WAS BELIEVED. Six tests were
/// found in this repo on 2026-09-05 that passed while the thing they
/// tested was broken, so each assertion below was re-run against
/// deliberately broken data and confirmed to fail. The mutations are
/// named in the report that accompanied this file.
void main() {
  late Map<String, dynamic> raw;
  late WheelHistoryData data;

  setUpAll(() {
    raw = json.decode(File('assets/wheel_history.json').readAsStringSync())
        as Map<String, dynamic>;
    data = WheelHistoryData.fromJson(raw);
  });

  List<Map<String, dynamic>> rawList(String key) =>
      (raw[key] as List).cast<Map<String, dynamic>>();

  // ---------------------------------------------------------------
  // 1. No event is drawn twice.
  // ---------------------------------------------------------------

  /// Words that carry no subject, so that two unrelated events sharing
  /// only "the", "of" and "first" are not reported as one. Kept
  /// deliberately short: the looser this list, the more real pairs the
  /// detector stops seeing.
  const noise = {
    'the', 'of', 'and', 'in', 'a', 'to', 'for', 'by', 'on', 'at', 'from',
    'as', 'is', 'was', 'with', 'its', 'his', 'her', 'their', 'it', 'that',
    'this', 'an', 'be', 'are', 'were', 'not', 'no', 'under', 'over',
    'into', 'out', 'first', 'second', 'third', 'new', 'great', 'year',
    'years',
  };

  Set<String> subjectWords(String s) => RegExp(r'[a-z]{3,}')
      .allMatches(s.toLowerCase())
      .map((m) => m.group(0)!)
      .where((w) => !noise.contains(w))
      .toSet();

  /// WHY THIS IS NOT WORD OVERLAP. The obvious detector — two events on
  /// one year whose titles are mostly the same words — was written
  /// first and thrown away, because it is wrong in both directions at
  /// once. At a threshold loose enough to catch "First Powered Flight
  /// at Kitty Hawk" against "Wright Brothers Fly at Kitty Hawk" (they
  /// share two words in seven, 0.29) it also merges "Cities Rise in the
  /// Indus Valley" with "Ceremonial Cities Rise in the Supe Valley" —
  /// two civilisations on opposite sides of the world, sharing
  /// "cities", "rise" and "valley" at 0.50. Overlap cannot tell a
  /// shared SUBJECT from a shared sentence shape.
  ///
  /// Rarity can. The signal that two records are one event is not how
  /// many words they share but how UNUSUAL the shared words are in this
  /// corpus: "kitty" and "hawk" name one beach and appear in two titles
  /// out of seven hundred, while "cities" and "valley" appear all over
  /// it. So the rule is: within [window] years, sharing at least two
  /// words that each occur in at most [rarest] titles corpus-wide.
  ///
  /// This is also what found the fourth pair. Bi Sheng's movable type
  /// was on the wheel twice, at 1040 and 1045, on the same ring — and
  /// the 1040 record stated a year outside the 1041-1048 window that
  /// Shen Kuo, the only source either record cites, actually gives.
  /// Word overlap at any usable threshold missed it; rarity did not.
  /// How many of the corpus's titles each word appears in. Rarity is a
  /// property OF THIS CORPUS, so this is always measured from the
  /// shipped events, never from whatever list a caller is sweeping —
  /// which is the mistake that made the first version of the witness
  /// test below pass "cities" off as a rare word.
  Map<String, int> titleFrequencies() {
    final freq = <String, int>{};
    for (final e in data.events) {
      for (final w in subjectWords(e.titleFor('en'))) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    return freq;
  }

  List<String> duplicatePairs(
    List<({int year, String id, String title})> corpus,
    Map<String, int> titlesContaining, {
    int window = 25,
    int rarest = 3,
  }) {
    final found = <String>[];
    for (var i = 0; i < corpus.length; i++) {
      for (var j = i + 1; j < corpus.length; j++) {
        final a = corpus[i];
        final b = corpus[j];
        if ((a.year - b.year).abs() > window) continue;
        final shared = subjectWords(a.title).intersection(subjectWords(b.title));
        final rare = shared
            .where((w) => (titlesContaining[w] ?? 0) <= rarest)
            .toList()
          ..sort();
        if (rare.length >= 2) {
          found.add('${a.year} ${a.id} ("${a.title}") and '
              '${b.year} ${b.id} ("${b.title}") share $rare');
        }
      }
    }
    return found;
  }

  group('no event is drawn twice', () {
    /// The detector, run against the shipped asset.
    test('no two events near a year share a rare subject', () {
      final pairs = duplicatePairs([
        for (final e in data.events)
          (year: e.year, id: e.id, title: e.titleFor('en')),
      ], titleFrequencies());
      expect(pairs, isEmpty, reason: pairs.join('\n'));
    });

    /// THE DETECTOR PROVED ABLE TO SEE — and proved to have a blind
    /// spot, which is stated here rather than left for someone to
    /// discover by trusting it.
    ///
    /// It cannot be proved against the live asset any more: with the
    /// twins removed there is nothing left in it to catch, which is
    /// exactly how a sweep like this goes quietly vacuous. So it is
    /// aimed at the four pairs AS THEY ACTUALLY SHIPPED, using the live
    /// corpus's own word frequencies, plus three pairs it must leave
    /// alone — all seven are real rows of this file.
    ///
    /// IT CATCHES THREE OF THE FOUR. The Columbus pair it does not see:
    /// the two titles share "columbus", which is rare, and "reaches",
    /// which is in eleven titles, so only one rare word is shared and
    /// the rule wants two. That pair was found another way — its title
    /// said one thing while its own id and description said another —
    /// and the miss is asserted below so that nobody reads a green
    /// sweep as proof there are no duplicates left. It is proof there
    /// are none OF THIS SHAPE.
    test('the detector catches three of the four, and spares three lookalikes',
        () {
      const witness = <({int year, String id, String title})>[
        // The four that were really there.
        (year: 1903, id: 'wright_first_flight', title: 'First Powered Flight at Kitty Hawk'),
        (year: 1903, id: 'powered_flight', title: 'Wright Brothers Fly at Kitty Hawk'),
        (year: 1905, id: 'einstein_relativity', title: 'Einstein Publishes Relativity'),
        (year: 1905, id: 'special_relativity', title: 'Einstein Publishes Special Relativity'),
        (year: 1040, id: 'movable_type_china', title: 'Movable Type Invented in China'),
        (year: 1045, id: 'bi_sheng_movable_type', title: 'Bi Sheng Invents Movable Type'),
        (year: 1492, id: 'columbus_caribbean', title: 'Columbus Reaches the Caribbean'),
        (year: 1500, id: 'columbian_exchange', title: 'Columbus Reaches the Americas'),
        // Three the wheel is RIGHT to draw twice. Two civilisations
        // that share a sentence shape and nothing else; one year that
        // holds a fire and a persecution; and one man who published two
        // different books twelve years apart.
        (year: -2600, id: 'indus_valley_cities', title: 'Cities Rise in the Indus Valley'),
        (year: -2600, id: 'caral_supe_valley', title: 'Ceremonial Cities Rise in the Supe Valley'),
        (year: 64, id: 'great_fire_rome', title: 'Great Fire of Rome'),
        (year: 64, id: 'nero_persecution', title: "Nero's Persecution of the Christians Begins"),
        (year: 1522, id: 'luther_nt', title: "Luther's German New Testament"),
        (year: 1534, id: 'luther_bible', title: "Luther's Complete German Bible"),
      ];

      final found = duplicatePairs(witness, titleFrequencies());
      String pairOf(String a, String b) =>
          found.firstWhere((f) => f.contains(a) && f.contains(b),
              orElse: () => '');

      for (final pair in const [
        ('wright_first_flight', 'powered_flight'),
        ('einstein_relativity', 'special_relativity'),
        ('movable_type_china', 'bi_sheng_movable_type'),
      ]) {
        expect(pairOf(pair.$1, pair.$2), isNotEmpty,
            reason: 'the detector no longer sees ${pair.$1} / ${pair.$2}, '
                'which really was on this wheel twice');
      }
      for (final pair in const [
        ('indus_valley_cities', 'caral_supe_valley'),
        ('great_fire_rome', 'nero_persecution'),
        ('luther_nt', 'luther_bible'),
      ]) {
        expect(pairOf(pair.$1, pair.$2), isEmpty,
            reason: 'the detector has gone blunt and now merges ${pair.$1} '
                'with ${pair.$2}, which are two different events');
      }

      // The blind spot, asserted so it stays known. If this ever starts
      // failing the detector has got sharper, which is good news — but
      // it is news, and the comment above has gone stale.
      expect(pairOf('columbus_caribbean', 'columbian_exchange'), isEmpty,
          reason: 'the detector now catches the Columbus pair; the '
              'documented blind spot above is out of date');

      expect(found, hasLength(3),
          reason: 'the detector found something in this corpus that is '
              'neither one of the three nor one of the three: '
              '${found.join('\n')}');
    });

    /// The four ids that came off. An id that returns brings the second
    /// ring back with it, and the sweep above would catch that — but
    /// only while the titles stay similar. This catches it whatever the
    /// title says.
    test('the four records that drew a second ring stay off', () {
      const removed = {
        'special_relativity',
        'powered_flight',
        'columbian_exchange',
        'movable_type_china',
      };
      final ids = {for (final r in rawList('events')) r['id'] as String};
      expect(ids.intersection(removed), isEmpty);

      // ...and the survivor of each pair is still there, so this rule
      // can never be satisfied by deleting both.
      expect(ids, containsAll(<String>{
        'einstein_relativity',
        'wright_first_flight',
        'columbus_caribbean',
        'bi_sheng_movable_type',
      }));
    });

    /// Bi Sheng's surviving record keeps the date its own source
    /// supports AND the comparison the deleted one was making. Losing
    /// the second is how a de-duplication quietly costs a reader
    /// something: the point of the record, on a chart a European reader
    /// is reading, is that this happened four centuries before Europe.
    test('the survivor keeps both its window and what its twin said', () {
      final e =
          data.events.firstWhere((x) => x.id == 'bi_sheng_movable_type');
      expect(e.year, 1045);
      expect(e.descFor('en'), contains('1041'));
      expect(e.descFor('en'), contains('1048'));
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(e.descFor(locale).toLowerCase(),
            anyOf(contains('europe'), contains('欧洲'), contains('歐洲')),
            reason: '$locale lost the comparison the deleted twin carried');
      }
    });

    /// The one sentence the deleted 1500 record was carrying that was
    /// true — the exchange itself — moved onto the 1492 landfall rather
    /// than being lost with it. In all three scripts, because dropping
    /// it from two of them is the same loss for two of three readers.
    test('the exchange survives its record, in every script', () {
      final columbus =
          data.events.firstWhere((e) => e.id == 'columbus_caribbean');
      expect(columbus.descFor('en').toLowerCase(), contains('exchange'));
      expect(columbus.descFor('zh-Hans'), contains('交流'));
      expect(columbus.descFor('zh-Hant'), contains('交流'));
    });
  });

  // ---------------------------------------------------------------
  // 2. A chain the wheel draws is drawn whole.
  // ---------------------------------------------------------------

  group('a chain the wheel draws is drawn whole', () {
    /// The gap a stream may leave between one band ending and the next
    /// beginning before it reads as an omission rather than as history.
    /// 25 years is about a generation, and it is wide enough to let a
    /// genuine interregnum stand while catching the 54, 45 and 161 year
    /// holes this pass found in the Chinese stream.
    const tolerance = 25;

    List<String> gapsIn(String stream, {required int from, required int to}) {
      final bands = data.powers.where((p) => p.stream == stream).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      final gaps = <String>[];
      int? reached;
      String previous = '';
      for (final p in bands) {
        if (p.start < from || p.start > to) continue;
        if (reached != null && p.start - reached > tolerance) {
          gaps.add('$stream: ${p.start - reached} years unbanded between '
              '$previous (ends $reached) and ${p.id} (starts ${p.start})');
        }
        final ends = p.end ?? p.start;
        if (reached == null || ends > reached) {
          reached = ends;
          previous = p.id;
        }
      }
      return gaps;
    }

    /// CHINA, from the first empire to the last. Every dynasty between
    /// these two ends is now a band, so a reader tracing the stream
    /// never crosses a century of nothing.
    test('the Chinese stream runs unbroken from Qin to the fall of Qing',
        () {
      final gaps = gapsIn('china', from: -221, to: 1912);
      expect(gaps, isEmpty, reason: gaps.join('\n'));
    });

    /// ISLAM, from the first caliphate to the end of the Ottomans. The
    /// hole this closes is the one that mattered most to a Bible
    /// reader: who held Jerusalem between the crusades and the
    /// Ottomans, which the wheel could not answer.
    test('the Islamic stream runs unbroken from the Rashidun to 1922', () {
      final gaps = gapsIn('islam', from: 632, to: 1922);
      expect(gaps, isEmpty, reason: gaps.join('\n'));
    });

    /// THE SWEEP PROVED ABLE TO SEE. `gapsIn` returning an empty list
    /// for the wrong reason — a stream name that matches nothing, a
    /// window that admits no band — would make both tests above pass
    /// over any corpus at all.
    test('the gap sweep is not passing vacuously', () {
      expect(data.powers.where((p) => p.stream == 'china').length,
          greaterThanOrEqualTo(15),
          reason: 'the Chinese stream has emptied out and the sweep above '
              'is walking nothing');
      expect(data.powers.where((p) => p.stream == 'islam').length,
          greaterThanOrEqualTo(8));

      // The sweep, aimed at a stream that genuinely has a hole in it and
      // is RIGHT to: the papal bands are selective before 1775 by
      // design, and this is the shape of a positive result.
      expect(gapsIn('church', from: 600, to: 1500), isNotEmpty,
          reason: 'the sweep found no gap in the selective pope chain, '
              'which means it is not detecting gaps at all');
    });

    /// The five bands this pass added, pinned by span. A band whose
    /// years drift is a band that has stopped saying what it was
    /// sourced to say, and the gap sweep above would not notice as long
    /// as the ends still met.
    test('the five new bands carry the years they were sourced to', () {
      const expected = {
        'qin-dynasty': (-221, -206, true),
        'three-kingdoms-china': (220, 280, true),
        'northern-southern-dynasties': (420, 589, true),
        'mamluk-sultanate': (1250, 1517, false),
        'judges-of-israel': (-1380, -1050, true),
      };
      for (final entry in expected.entries) {
        final p = data.powers.firstWhere((q) => q.id == entry.key,
            orElse: () => throw StateError('${entry.key} is not in the '
                'asset — a band this pass added has been removed'));
        expect(p.start, entry.value.$1, reason: entry.key);
        expect(p.end, entry.value.$2, reason: entry.key);
        // `approximate` is the flag that says references genuinely
        // differ. Three of these five have a disagreement written into
        // the note; flipping the flag to false would leave the note
        // describing a doubt the data no longer admits to.
        expect(p.approximate, entry.value.$3,
            reason: '${entry.key} has changed what it claims about its '
                'own certainty');
      }
    });

    /// A rounded band must SAY where the references part, in every
    /// script. `approximate: true` on its own tells a reader that
    /// something is uncertain and never what; these three notes name
    /// the competing year, which is the whole difference between
    /// recording an uncertainty and hiding one.
    test('every rounded band names the year the other references give', () {
      const disagreements = {
        'qin-dynasty': ['207', '207', '207'],
        'three-kingdoms-china': ['265', '265', '265'],
        'northern-southern-dynasties': ['386', '386', '386'],
      };
      const locales = ['en', 'zh-Hans', 'zh-Hant'];
      for (final entry in disagreements.entries) {
        final p = data.powers.firstWhere((q) => q.id == entry.key);
        for (var i = 0; i < locales.length; i++) {
          expect(p.noteFor(locales[i]), contains(entry.value[i]),
              reason: '${entry.key} does not tell a ${locales[i]} reader '
                  'which other year the references give');
        }
      }
    });
  });

  // ---------------------------------------------------------------
  // 3. The judges band arranges nothing inside itself.
  // ---------------------------------------------------------------

  group('the judges band arranges nothing inside itself', () {
    /// `chronology.json` rules the era of the judges COUNTED AND NOT
    /// DRAWN, because the years the book states for the judges sum to
    /// about 530 while 1 Kings 6:1 allows 479 from the exodus to the
    /// temple. The band added on 2026-09-05 states the era's two outer
    /// ends and nothing between them. If a judge ever appears as a span
    /// inside it, that ruling has been reversed by accident.
    test('no span begins and ends inside the judges band', () {
      final judges =
          data.powers.firstWhere((p) => p.id == 'judges-of-israel');
      final inside = <String>[];
      for (final p in data.powers) {
        if (p.id == judges.id) continue;
        if (p.stream != 'israel') continue;
        final end = p.end;
        if (end == null) continue;
        if (p.start > judges.start && end < judges.end!) {
          inside.add('power ${p.id} (${p.start}..$end)');
        }
      }
      for (final m in data.ministries) {
        if (m.stream != 'israel') continue;
        if (m.start > judges.start && m.end < judges.end!) {
          inside.add('ministry ${m.id} (${m.start}..${m.end})');
        }
      }
      expect(inside, isEmpty,
          reason: 'the era chronology.json rules counted-and-not-drawn is '
              'being drawn after all:\n${inside.join('\n')}');
    });

    /// Both ends are years the wheel already draws, which is the whole
    /// argument for the band being placeable at all. If either end
    /// moves off its anchor the band has started asserting a year of
    /// its own, and this file's rule against invented dates has been
    /// broken quietly.
    test('both ends are anchored on records the app already carries', () {
      final judges =
          data.powers.firstWhere((p) => p.id == 'judges-of-israel');
      final timeline = json.decode(
          File('assets/bible_timeline.json').readAsStringSync())
          as Map<String, dynamic>;
      final years = <String, int>{
        for (final e in (timeline['events'] as List)
            .cast<Map<String, dynamic>>())
          e['id'] as String: e['year'] as int,
      };
      expect(years['judges_period'], isNotNull,
          reason: 'the anchor record has been renamed or removed, so this '
              'test can no longer check the end it is checking');
      expect(judges.start, years['judges_period'],
          reason: 'the band no longer opens where the app says the period '
              'of the judges opens');
      expect(judges.end, years['saul_anointed'],
          reason: 'the band no longer closes where the app says Israel '
              'got its first king');
    });

    /// The band's own note has to carry the reason, not just the years,
    /// because a reader who sees an empty band and no explanation will
    /// read it as missing data rather than as a decision. In all three
    /// scripts: an explanation only two readers in three can read is
    /// two thirds of a disclosure.
    test('the note states the 530-against-479 reason in every script', () {
      final judges =
          data.powers.firstWhere((p) => p.id == 'judges-of-israel');
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final note = judges.noteFor(locale);
        expect(note, contains('530'), reason: locale);
        expect(note, contains('479'), reason: locale);
        expect(note.length, greaterThan(120),
            reason: '$locale has been shortened past the point of '
                'explaining anything');
      }
    });
  });

  // ---------------------------------------------------------------
  // The three events, and the one thing they must never do.
  // ---------------------------------------------------------------

  group('the two new events, and the one that could not be afforded', () {
    test('each carries its sourced year and its own certainty', () {
      const expected = {
        'pope_john_paul_i': (1978, false),
        'kanto_earthquake': (1923, false),
      };
      for (final entry in expected.entries) {
        final e = data.events.firstWhere((x) => x.id == entry.key,
            orElse: () => throw StateError('${entry.key} is gone'));
        expect(e.year, entry.value.$1, reason: entry.key);
        expect(e.approximate, entry.value.$2, reason: entry.key);
        expect(e.basis, 'conventional', reason: entry.key);
      }
    });

    /// John Paul I is drawn as a MOMENT and not as a band, and that is
    /// the whole of the decision: the papal chain is unbroken from 1775
    /// to the present and he was the one man missing from it, but
    /// thirty-three days has no width on an axis six thousand years
    /// long. `pope-leo-v` set the precedent in 903. A band with
    /// start == end would draw as an artefact, so if one ever appears
    /// under this name the decision has been reversed by accident.
    test('John Paul I is a moment, not a zero-width band', () {
      expect(data.events.any((e) => e.id == 'pope_john_paul_i'), isTrue);
      expect(data.powers.any((p) => p.id.contains('john-paul-i') &&
          !p.id.contains('john-paul-ii')), isFalse,
          reason: 'a thirty-three-day pontificate has been given a band');

      // ...and the chain it completes really is unbroken, which is the
      // only reason a reign this short earned a spoke at all. Anything
      // more than a year between one modern pontificate ending and the
      // next beginning means the premise of this addition has failed.
      final modern = data.powers
          .where((p) => p.stream == 'church' && p.start >= 1775 &&
              p.id.startsWith('pope-'))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      expect(modern.length, greaterThanOrEqualTo(14),
          reason: 'the modern pope chain has emptied out, so the check '
              'below is walking almost nothing');
      for (var i = 1; i < modern.length; i++) {
        final previousEnd = modern[i - 1].end;
        if (previousEnd == null) continue;
        expect(modern[i].start - previousEnd, lessThanOrEqualTo(1),
            reason: 'the chain John Paul I was added to complete has a '
                'hole between ${modern[i - 1].id} and ${modern[i].id}');
      }
    });

    /// THE RECORD THAT WAS RESEARCHED AND LEFT OFF, pinned so the
    /// decision is not quietly re-taken.
    ///
    /// The prologue to Sirach at 132 BC — the earliest surviving
    /// witness to the Hebrew scriptures in three divisions — was
    /// written, sourced, and then removed. The Israel pass had flagged
    /// it as an anchor to add "only if the annulus has room", and this
    /// pass measured the room: with it in, `wheel_label_legibility_test`
    /// falls to 61 whole Chinese names at 900 px against a floor of 62.
    /// Dropping either modern event instead does not recover the name,
    /// because the crowding is at 132 BC.
    ///
    /// So this asserts the ABSENCE, and it fails the day the record
    /// comes back without the legibility floor having moved with it.
    /// The floor is the thing to change first; the legibility file says
    /// so itself, in its own words: "the next batch of records should
    /// not simply move this number again".
    test('the Sirach prologue stays off until the rim can hold it', () {
      expect(data.events.any((e) => e.id == 'ecclesiasticus_prologue'),
          isFalse,
          reason: 'the Sirach prologue is back on the wheel; it costs one '
              'whole Chinese name at 900 px at rest, so check that '
              'wheel_label_legibility_test.dart was re-measured and not '
              'merely relaxed');
    });

    /// No record may carry a scripture reference the app cannot open,
    /// and the two new ones carry none at all — neither the papacy nor
    /// an earthquake is dated from scripture, and a `basis` of
    /// `conventional` beside a verse would be claiming otherwise.
    test('neither new event cites a verse it has no business citing', () {
      for (final id in const ['pope_john_paul_i', 'kanto_earthquake']) {
        final e = data.events.firstWhere((x) => x.id == id);
        expect(e.refs, isEmpty, reason: id);
      }
    });
  });
}
