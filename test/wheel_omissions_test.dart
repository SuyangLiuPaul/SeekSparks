/// THE RECORDS THAT SAY THE CHART DRAWS NOTHING.
///
/// The wheel gives twelve of the seventeen prophetic books a ministry
/// arc and Malachi a dated event. Joel, Obadiah and Habakkuk it does
/// not draw, and until now it did not say so: typing Joel, 约珥 or 約珥
/// into the find box returned "Nothing here matches", which is the
/// exact false absence `wheel_search.dart`'s library comment was
/// written to stop — except that here the record really was missing,
/// and missing ON PURPOSE.
///
/// THE DECISION IS THE RIGHT ONE AND WAS NEVER IN QUESTION. Joel 1:1
/// names no king and dates nothing; Obadiah 11 names a day without
/// saying which; Habakkuk 1:6 names a nation still to be raised up.
/// Every other span on this chart was reached from a regnal
/// superscription (Isaiah 1:1), a verse elsewhere in scripture
/// (2 Kings 14:25 for Jonah) or two dated events (Thebes and Nineveh
/// for Nahum). These three books supply none of the three, so a span
/// would be invented, and this corpus invents no years. What was wrong
/// was the SILENCE — the same defect `tiberius_disclosure_test.dart`
/// exists for, and the same fix: say it out loud, in all three scripts,
/// where the reader is already looking.
///
/// WHAT THIS FILE IS REALLY FOR is the count. "Joel is missing" is one
/// observation; "Joel, Obadiah and Habakkuk are the complete set of
/// prophetic books this wheel cannot reach" is a claim about the whole
/// corpus, and it was measured rather than assumed — see the sweep in
/// the second group, which asks all sixteen named prophets, in three
/// scripts, which of them reaches a record. If a thirteenth ministry
/// ships tomorrow, or a record is renamed and goes quiet, that sweep
/// names the book rather than leaving the next reader to notice.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/book_name_mapping.dart'
    show englishToChinese, englishToChineseTraditional;
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show kMaxYear, wheelStrings;
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/wheel_search.dart';

const _locales = ['en', 'zh-Hans', 'zh-Hant'];

/// The sixteen prophets the Old Testament names a book after.
///
/// Lamentations is deliberately not here: it is Jeremiah's, and the man
/// already has an arc, so asking whether "Lamentations" reaches a record
/// would be asking about a book title rather than about a prophet.
const _prophetBooks = <String>[
  'Isaiah',
  'Jeremiah',
  'Ezekiel',
  'Daniel',
  'Hosea',
  'Joel',
  'Amos',
  'Obadiah',
  'Jonah',
  'Micah',
  'Nahum',
  'Habakkuk',
  'Zephaniah',
  'Haggai',
  'Zechariah',
  'Malachi',
];

/// The books this chart draws no span for. Written down HERE, once, and
/// then checked against the corpus from both directions below — the
/// asset must hold exactly these, and the sweep must find exactly these
/// unreachable without them.
const _undrawn = <String>['Joel', 'Obadiah', 'Habakkuk'];

/// The man's name out of the book's, in the script the reader reads.
///
/// `约珥书` is a BOOK and `约珥` is a MAN, and the wheel indexes men, so
/// a sweep that typed the book name would report every prophet
/// unreachable and prove nothing. Derived from the app's own mapping
/// rather than transcribed, so a spelling fixed there is fixed here.
String _prophetName(String book, String locale) => switch (locale) {
      'zh-Hans' => englishToChinese[book]!.replaceAll('书', ''),
      'zh-Hant' => englishToChineseTraditional[book]!.replaceAll('書', ''),
      _ => book,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final Map<String, dynamic> rawAsset;
  late WheelHistoryData data;

  setUpAll(() async {
    rawAsset = jsonDecode(File('assets/wheel_history.json').readAsStringSync())
        as Map<String, dynamic>;
    data = await WheelHistoryService.instance.load();
  });

  List<Map<String, dynamic>> rawOmissions() =>
      (rawAsset['omissions'] as List).cast<Map<String, dynamic>>();

  WheelSearchResult find(String q, {String locale = 'en'}) => searchWheel(
        data: data,
        query: q,
        locale: locale,
        axisEnd: kMaxYear,
      );

  group('the asset', () {
    test('three records, and every key in them is read by the model', () {
      expect(data.omissions, hasLength(3));
      expect(data.omissions.map((o) => o.id),
          ['joel_undated', 'obadiah_undated', 'habakkuk_undated']);
      // The same rule `wheel_ministries_test.dart` makes for its own
      // rows: a field written into the asset and never read is a field
      // no reader can reach, which is the defect
      // `wheel_history_disclosure_test.dart` was written for. That
      // file's detector sweeps four record lists and cannot see this
      // one, so the rule is restated where the rows live.
      const known = {'id', 'refs', 'name', 'note'};
      for (final raw in rawOmissions()) {
        expect(raw.keys.toSet().difference(known), isEmpty,
            reason: '${raw['id']} carries a key nothing reads');
      }
    });

    /// THE ONE FIELD THAT MUST NEVER APPEAR. A `start`, an `end`, a
    /// `year` — any of them would be the invention the record exists to
    /// refuse, and it would be an invention nothing else in this repo
    /// could catch, because every span-shaped field the wheel has is
    /// legitimate on some other row. `basis` and `approximate` are here
    /// for the same reason one step removed: both are answers to "what
    /// does this year rest on", and a record with no year that carried
    /// one would be hedging a claim it does not make.
    test('no omission carries a year, a span, or a basis for one', () {
      const forbidden = {
        'start',
        'end',
        'year',
        'basis',
        'approximate',
        'anchorKings',
      };
      for (final raw in rawOmissions()) {
        expect(raw.keys.toSet().intersection(forbidden), isEmpty,
            reason: '${raw['id']} has been given a date to stand on');
      }
    });

    test('no id collides with anything else the wheel carries', () {
      final existing = <String>{
        for (final k in ['events', 'powers', 'nations', 'streams',
            'ministries'])
          for (final r in (rawAsset[k] as List).cast<Map<String, dynamic>>())
            r['id'] as String,
      };
      for (final o in data.omissions) {
        expect(existing.contains(o.id), isFalse, reason: o.id);
      }
      expect(data.omissions.map((o) => o.id).toSet(), hasLength(3));
    });

    test('named and explained in all three scripts', () {
      for (final o in data.omissions) {
        for (final locale in _locales) {
          expect(o.nameFor(locale), isNotEmpty, reason: '${o.id} $locale');
          // Not merely present. A note that has been trimmed to a
          // phrase has stopped disclosing anything, and going quiet is
          // the one state this record must never be in.
          expect(o.noteFor(locale).length, greaterThan(120),
              reason: '${o.id} $locale has been shortened into silence');
        }
        // The three scripts must be three different strings — an
        // English note pasted into the Chinese slots would pass every
        // assertion above.
        expect({for (final l in _locales) o.noteFor(l)}, hasLength(3),
            reason: '${o.id} shows the same note to two different readers');
      }
    });

    /// The references are the whole evidence for the claim, so they
    /// have to open. A note saying "Joel 1:1 names no king" beside a
    /// chip that cannot be tapped is an assertion the reader has to take
    /// on trust, which is exactly what this chart refuses to ask.
    test('every reference parses, and cites the book it is about', () {
      for (final o in data.omissions) {
        expect(o.refs, isNotEmpty, reason: o.id);
        final book = o.id.split('_').first;
        for (final ref in o.refs) {
          final parsed = parseReference(ref);
          expect(parsed, isNotNull,
              reason: '${o.id} cites "$ref", which the reader cannot open');
        }
        expect(
            o.refs.any((r) =>
                parseReference(r)!.englishBook.toLowerCase() == book),
            isTrue,
            reason: '${o.id} cites nothing from its own book');
      }
    });
  });

  /// IS JOEL THE ONLY ONE? Asked of the corpus, not of memory.
  ///
  /// The obvious version of this feature adds one record for Joel and
  /// ships. That version would have been wrong twice over, and this
  /// group is what said so: Obadiah and Habakkuk returned nothing in
  /// all three scripts as well, for the same reason and with the same
  /// three-hundred-year spread of proposals behind them.
  group('the complete set of prophets this wheel cannot reach', () {
    /// Every prophet, minus the omissions, must land on something the
    /// chart actually draws. Run with the omissions EXCLUDED, so a
    /// record added here can never quietly paper over a ministry arc
    /// that has stopped answering to its own name.
    test('every other prophet reaches a drawn record, in all three scripts',
        () {
      final silent = <String>[];
      for (final book in _prophetBooks) {
        if (_undrawn.contains(book)) continue;
        for (final locale in _locales) {
          final name = _prophetName(book, locale);
          final drawn = find(name, locale: locale)
              .hits
              .where((h) =>
                  h.kind != WheelHitKind.omission &&
                  h.via != WheelHitVia.yearNear)
              .toList();
          if (drawn.isEmpty) silent.add('$locale $book ("$name")');
        }
      }
      expect(silent, isEmpty,
          reason: 'these prophets have gone silent on the wheel and are '
              'owed either a record or an omission of their own');
    });

    /// The other direction, and the one that makes the count a claim
    /// rather than a note. If a fourth book ever falls out of the
    /// corpus this fails naming it; if one of the three is given a span
    /// this fails too, and the record here should then be deleted
    /// rather than left standing beside an arc that contradicts it.
    test('exactly three reach nothing the chart draws', () {
      final undrawn = <String>[];
      for (final book in _prophetBooks) {
        final reached = <String>{};
        for (final locale in _locales) {
          reached.addAll(find(_prophetName(book, locale), locale: locale)
              .hits
              .where((h) =>
                  h.kind != WheelHitKind.omission &&
                  h.via != WheelHitVia.yearNear)
              .map((h) => h.id));
        }
        if (reached.isEmpty) undrawn.add(book);
      }
      expect(undrawn, _undrawn);
    });

    /// Malachi is the near miss, and is here so the next reader does
    /// not "fix" him into a fourth omission. His book names no king
    /// either — but the chart already carries him as a dated event out
    /// of `bible_timeline.json`, marked conventional and approximate,
    /// and it has since long before this feature. A reader searching
    /// Malachi gets an answer, so he is not a false absence, and
    /// re-dating or removing a shipped record is not what a disclosure
    /// is for.
    test('Malachi is answered by a record, not by an omission', () {
      for (final locale in _locales) {
        final hits = find(_prophetName('Malachi', locale), locale: locale)
            .hits
            .where((h) => h.via != WheelHitVia.yearNear);
        expect(hits.map((h) => h.kind), isNot(contains(WheelHitKind.omission)),
            reason: '$locale: Malachi has been given an omission as well as '
                'a record, and the chart now says both');
        expect(hits, isNotEmpty, reason: locale);
      }
    });
  });

  group('the reader who goes looking finds it', () {
    /// The defect, stated as the reader met it. Before this the answer
    /// to all nine of these was "Nothing here matches".
    test('each name answers, first, in each of the three scripts', () {
      for (final o in data.omissions) {
        for (final locale in _locales) {
          final hits = find(o.nameFor(locale), locale: locale).hits;
          expect(hits, isNotEmpty,
              reason: '$locale: "${o.nameFor(locale)}" still returns nothing');
          expect(hits.first.kind, WheelHitKind.omission,
              reason: '$locale ${o.id} was buried under something else');
          expect(hits.first.id, o.id);
        }
      }
    });

    /// A Traditional reader who pastes Simplified, and the reverse —
    /// the courtesy every other kind of record on this wheel already
    /// extends, asserted here because the omissions are indexed through
    /// the same `classify` and could stop doing so without any other
    /// test noticing.
    test('the other script still reaches it', () {
      for (final o in data.omissions) {
        expect(find(o.nameFor('zh-Hans'), locale: 'zh-Hant').hits, isNotEmpty,
            reason: o.id);
        expect(find(o.nameFor('zh-Hant'), locale: 'zh-Hans').hits, isNotEmpty,
            reason: o.id);
        expect(find(o.nameFor('en'), locale: 'zh-Hans').hits, isNotEmpty,
            reason: o.id);
      }
    });

    /// The verse the note reasons from is a way in of its own, which
    /// matters because a reader may arrive at this question FROM the
    /// text rather than from the name.
    test('the verse that would have carried the date reaches the record', () {
      expect(find('Joel 1').hits.map((h) => h.id), contains('joel_undated'));
      expect(find('Habakkuk 1').hits.map((h) => h.id),
          contains('habakkuk_undated'));
    });

    /// THE BOOK, NOT THE MAN — and the Chinese half of this is a real
    /// gap rather than a courtesy. `约珥` is a man and `约珥书` is a
    /// book, and the matcher is a plain substring, so the name alone
    /// cannot answer to the longer string: a reader who types the book
    /// title would be told nothing matches unless something else in the
    /// record carries it. The note does, because it opens by citing the
    /// verse — which is why this is asserted here rather than left to
    /// hold by accident, since a note reworded to start elsewhere would
    /// take the book title down with it.
    test('the book title reaches the record too, in both Chinese scripts',
        () {
      for (final book in _undrawn) {
        for (final locale in ['zh-Hans', 'zh-Hant']) {
          final title = locale == 'zh-Hans'
              ? englishToChinese[book]!
              : englishToChineseTraditional[book]!;
          expect(find(title, locale: locale).hits.map((h) => h.id),
              contains('${book.toLowerCase()}_undated'),
              reason: '$locale: "$title" reaches no record');
        }
      }
    });
  });

  group('a record with no year behaves like one', () {
    test('it carries no year, and no band that could hide it', () {
      for (final h in find('*').hits.where(
          (h) => h.kind == WheelHitKind.omission)) {
        expect(h.year, isNull, reason: h.id);
        expect(h.streamId, isEmpty, reason: h.id);
        expect(h.streamHidden, isFalse, reason: h.id);
      }
    });

    /// THE FAILURE THAT WOULD BE HARDEST TO SPOT BY EYE: the search
    /// answering a year with a record whose entire content is that it
    /// has no year. Never through the year branch, then — not as an
    /// exact hit, not as a span, and not as a neighbour, all three of
    /// which would put the record on the axis at a year nobody claims.
    ///
    /// IT CAN STILL COME BACK, and this is the case that was measured
    /// rather than guessed: typing `586` DOES return `obadiah_undated`,
    /// because the note says 586 BC in so many words while explaining
    /// that the verse names no year. That is the prose tier answering a
    /// question about prose, it sorts below every exact year hit, and
    /// the row prints an empty year column beside the words "no date" —
    /// so the reader is shown the argument, not a date. Suppressing it
    /// would hide the one record that has something to say about why
    /// that year gets proposed.
    test('a year query never files one as dated, but the prose may answer',
        () {
      const yearTiers = {
        WheelHitVia.yearExact,
        WheelHitVia.yearSpan,
        WheelHitVia.yearNear,
      };
      for (final q in ['586', '-586', 'AD 33', '主前586', '835', '612']) {
        final r = find(q);
        expect(r.years, isNotEmpty, reason: '"$q" stopped reading as a year');
        for (final h in r.hits.where((h) => h.kind == WheelHitKind.omission)) {
          expect(yearTiers.contains(h.via), isFalse,
              reason: '"$q" put ${h.id} on the axis, via ${h.via.name}');
        }
      }
      // The measured one, pinned so that a change of tier is a failure
      // rather than a surprise.
      final obadiah =
          find('586').hits.where((h) => h.id == 'obadiah_undated').toList();
      expect(obadiah, hasLength(1));
      expect(obadiah.single.via, WheelHitVia.description);
      expect(obadiah.single.year, isNull);
    });

    /// Sorted with the bands and the nations — after everything the
    /// text gives a year — which is the rule `wheel_search.dart` already
    /// applies to every undated record and is asserted here because
    /// three new undated records is the largest test that rule has had.
    test('it sorts below the dated records in its own tier', () {
      final hits = find('*').hits;
      for (var i = 1; i < hits.length; i++) {
        if (hits[i - 1].rank != hits[i].rank) continue;
        if (hits[i].kind != WheelHitKind.omission) continue;
        expect(hits[i - 1].year, isNull,
            reason: '${hits[i].id} was sorted above a dated record');
      }
    });
  });

  group('the strings a reader is shown', () {
    test('both new strings exist in all three scripts', () {
      for (final key in ['wheelKindOmission', 'wheelOmissionNoSpan']) {
        final byLocale = wheelStrings[key];
        expect(byLocale, isNotNull, reason: '$key missing from wheelStrings');
        for (final l in _locales) {
          expect(byLocale![l], isNotEmpty, reason: '$key has no $l string');
        }
        // Simplified and Traditional must not be the same string handed
        // to two readers by accident — the slip this repo has shipped
        // before, on 382 events at once.
        expect(byLocale!['zh-Hans'], isNot(byLocale['zh-Hant']),
            reason: '$key shows one script to both Chinese readers');
      }
    });
  });
}
