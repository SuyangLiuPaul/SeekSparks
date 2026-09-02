/// Find something on the world-history wheel.
///
/// BibleWorks' Timeline (`bwh39`) puts a command line on the toolbar:
/// type a term and the matching events are listed; type a date and the
/// timeline scrolls to it. That is the half this app was missing. The
/// wheel holds 754 records — 588 events, 62 powers, 82 nations of
/// Genesis 10, 22 bands — and until now the only way to reach one was
/// to recognise it on the rim. The declutter draws 64 labels at rest,
/// so a reader looking for Sennacherib had no way to find him even
/// though the record was there and reachable by tap once found.
///
/// FOUR THINGS A NAIVE VERSION WOULD GET WRONG, each of which is a
/// false ABSENCE — the reader is told the app does not know something
/// it does know, which is worse than a slow search:
///
///  1. SEARCHING EVENTS ONLY. A reader typing "Babylon" wants the
///     BAND and the POWER at least as much as the events; "Javan"
///     wants a nation out of Genesis 10. All four record kinds are
///     searched and each says what kind it is.
///  2. SEARCHING ONE LOCALE. Every record here carries all three
///     locales (measured: 588/588 titles in en, zh-Hans and
///     zh-Hant). A bilingual reader types whichever comes
///     to mind, and a Traditional reader may paste Simplified. So all
///     locales are matched, and when the hit was not in the displayed
///     string the row SHOWS the string that matched — otherwise the
///     result looks like a bug.
///  3. LETTING THE STREAM FILTER SWALLOW RESULTS. A hidden band drops
///     its events from the wheel entirely. Excluding them from search
///     too would make the filter silently narrow an answer the reader
///     never asked it to narrow (#280, #319). They are returned, and
///     flagged [WheelHit.streamHidden] so the page can say so and
///     un-hide on the way in.
///  4. GUESSING WHAT A BARE NUMBER MEANS. `586` is 586 BC to one
///     reader and AD 586 to another, and this corpus holds both eras.
///     Rather than pick, a bare number searches BOTH and every row
///     prints its own year, so the ambiguity is resolved on screen by
///     the reader instead of silently by us.
library;

import 'package:seeksparks/models/chronology.dart' show Patriarch;
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/diacritics.dart' show foldDiacritics;
import 'package:seeksparks/utils/reference_parser.dart';

/// Which of the wheel's five record kinds a hit is.
///
/// [patriarch] is a LIFE — one of the arcs the annulus carries, drawn
/// from a birth year to a death year — as against an [event], which is
/// a moment. They are indexed apart because they answer different
/// questions and open different sheets, and because a reader typing
/// "Methuselah" should get both: the birth spoke that says WHEN, and
/// the arc that says HOW LONG and alongside whom.
enum WheelHitKind { event, power, nation, stream, patriarch }

/// The id the lifespan layer answers to in the stream filter.
///
/// NOT a stream id — the stream set is pinned by tests and a collision
/// would switch a band off with the arcs. It is also the `streamId` a
/// patriarch hit carries, so the page's existing "un-hide what you
/// found" step needs no special case.
const String kLifespanLayerId = 'lifespans';

/// The two layers that joined the same annulus on 2026-09-02: the 42
/// reigns out of `hebrew_kings.json` and the 39 ministries out of
/// `wheel_history.json`.
///
/// They are separate switches rather than one because they are separate
/// KINDS OF CLAIM — a stated age, a synchronised reign, and the window
/// a text places a man's work in — and because they cost different
/// amounts of annulus. The reigns are free: they fall in years the
/// patriarchs have left, so eleven sub-rings still hold them. The
/// ministries are not: they overlap each other and the reigns through
/// the whole divided monarchy and take the band to fifteen, which at a
/// 700 px canvas is a 7.1 px sub-ring against the 9 px a finger wants.
/// So the reader who needs a bigger target has a switch that gives it
/// back, and `wheel_lifespans_test.dart` pins both numbers.
const String kReignLayerId = 'reigns';
const String kMinistryLayerId = 'ministries';

/// Where in the record the query was found.
///
/// This is shown to the reader. A row whose title does not visibly
/// contain what they typed has to explain itself, or it reads as a
/// wrong result.
enum WheelHitVia {
  /// In the title as displayed.
  title,

  /// In the title, but in one of the other two locales — [WheelHit.matched]
  /// carries that title.
  otherLocale,

  /// In the same language, under a spelling the app does not display —
  /// the Authorised Version's, which [WheelHit.matched] carries.
  ///
  /// FIVE RECORDS ANSWER TO ONE. The wheel shows a reader "Kenan",
  /// because that is what the modern versions read and what every other
  /// asset here already said; the KJV this same app ships reads
  /// "Cainan" at Genesis 5:9, so that is the only spelling some readers
  /// have ever seen and the one they will type. A search that answered
  /// "nothing" would be reporting an absence about a record it draws.
  ///
  /// Its own tier rather than [otherLocale] because the claim is
  /// different and the row has to be able to say which: not "we have
  /// this under another language" but "this edition spells him that
  /// way".
  otherSpelling,

  /// In the description or note.
  description,

  /// In the name of one of the people the record NAMES —
  /// [WheelHit.matched] carries that name, in the script it matched in.
  ///
  /// Above [reference] because the person is a subject of the record
  /// and the reference is only its address, and because five of the
  /// people the wheel's records name appear in no title or description
  /// anywhere in the corpus: for those readers this tier is not a
  /// refinement of the answer, it IS the answer.
  person,

  /// In one of the verses the record cites — [WheelHit.matched] carries
  /// the reference, in its stored English form.
  reference,

  /// The record's span contains the year that was typed.
  yearSpan,

  /// The record is dated exactly to the year that was typed.
  yearExact,

  /// One of the nearest records to the year that was typed. Its own
  /// year is printed, so the distance is visible.
  ///
  /// This is the ONE approximate claim the search makes, so it sorts
  /// below every exact one — including the term tiers. A reader who
  /// types `1948` and gets six events from the 1940s above the record
  /// whose own text says 1948 has been answered with a guess ahead of
  /// an answer.
  yearNear,
}

class WheelHit {
  const WheelHit({
    required this.kind,
    required this.via,
    required this.id,
    required this.streamId,
    required this.title,
    required this.year,
    required this.matched,
    required this.rank,
    required this.streamHidden,
  });

  final WheelHitKind kind;
  final WheelHitVia via;
  final String id;

  /// The band this record belongs to; for a band, its own id.
  final String streamId;

  /// Localised, exactly as the wheel would print it.
  final String title;

  /// The year to print beside the row, or null for a record with no
  /// year of its own (a band, a nation of Genesis 10 — the text gives
  /// those no dates and this app does not invent any).
  final int? year;

  /// The string the query actually hit, when that is not [title].
  final String matched;

  /// Lower sorts first. Not shown.
  final int rank;

  /// True when the reader has this band switched off, so the record is
  /// not currently on the wheel at all.
  final bool streamHidden;
}

/// What one search found, and what it did.
class WheelSearchResult {
  const WheelSearchResult({
    required this.hits,
    required this.years,
    required this.nearestShown,
  });

  const WheelSearchResult.empty()
      : hits = const [],
        years = const [],
        nearestShown = 0;

  final List<WheelHit> hits;

  /// The year or years the query was read as, empty when it was not a
  /// year at all. Two entries when a bare number was ambiguous.
  final List<int> years;

  /// How many near-miss year rows are included. A cap on a sorted list
  /// is a hidden WHERE clause unless it is stated, and this is the one
  /// cap in this file.
  final int nearestShown;

  bool get isEmpty => hits.isEmpty;
}

/// How many events either side of a typed year are offered.
///
/// The corpus is 588 events over 6,026 years, so an exact year usually
/// has no event on it at all and a strict match would answer "nothing"
/// for almost every year a reader could type. The neighbours are what
/// makes a year query useful — but they are a different claim from an
/// exact hit, so they are ranked below, capped, counted, and each row
/// prints its own year.
const int kWheelNearestPerYear = 6;

/// The rank a near-miss year row carries — below every exact tier, so
/// the approximate answers are always the tail of the list.
const int _kNearRank = 20;

/// Fold a string to the form both sides of a comparison are held in.
///
/// Case and diacritics only. Han is left exactly as typed: Simplified
/// and Traditional are DIFFERENT CHARACTERS and folding one into the
/// other here would be a second, silent transliteration engine. The
/// corpus carries both scripts already, and matching every locale is
/// what covers the reader who types the other one.
String foldForWheelSearch(String s) => foldDiacritics(s.trim().toLowerCase());

/// True when [haystack] contains [needle], honouring BOTH wildcards
/// BibleWorks' command line takes: `*` for any run of characters and
/// `?` for exactly one (`bwh18_CommandLineExamples.htm`).
///
/// `?` is here because leaving it out is a false absence wearing the
/// costume of a feature: a reader who knows BibleWorks types `Sen?ach*`
/// and, without it, is told this app has never heard of Sennacherib —
/// not because the record is missing but because the `?` was taken
/// literally and matched nothing.
///
/// Unanchored on both ends, which IS a deliberate departure from
/// BibleWorks, where a term is word-anchored: `faith*` there means
/// words beginning "faith", and here it means the same as `faith`.
/// Saying so is the point — an anchoring rule the reader cannot see is
/// worse than none, and the looser rule cannot hide a record.
bool wheelMatches(String haystack, String needle) {
  if (needle.isEmpty) return false;
  if (!needle.contains('*') && !needle.contains('?')) {
    return haystack.contains(needle);
  }
  return _wildcard(needle).hasMatch(haystack);
}

/// Compiled once per pattern. A keystroke runs the matcher a few
/// thousand times — once per localised field of all 754 records — so
/// building the same `RegExp` each time is the difference between a
/// search box that keeps up with typing and one that does not.
final _wildcards = <String, RegExp>{};

RegExp _wildcard(String needle) {
  final cached = _wildcards[needle];
  if (cached != null) return cached;
  // Runes, not code units: a lone half of a surrogate pair is not a
  // character and must never reach `RegExp.escape`.
  final pattern = needle.runes.map((r) {
    final c = String.fromCharCode(r);
    return switch (c) {
      '*' => '.*',
      '?' => '.',
      _ => RegExp.escape(c),
    };
  }).join();
  final re = RegExp(pattern, dotAll: true);
  // The reader is one person typing; anything past a few dozen distinct
  // patterns is a session long enough that the early ones are cold.
  if (_wildcards.length > 64) _wildcards.clear();
  _wildcards[needle] = re;
  return re;
}

/// Read a year out of whatever a reader typed.
///
/// THE RULE THAT KEEPS THIS HONEST: the parser accepts every YEAR the
/// wheel prints. `yearLabel` renders `586 BC`, `AD 33`, `主前586` and
/// `主後33`, so all four come back, in every locale — pinned by a test
/// that round-trips all 588 events through both functions. Anything
/// else it accepts (`-586`, `公元前586`, `b.c. 586`) is a courtesy on
/// top of that floor.
///
/// ONE THING THE WHEEL PRINTS IS NOT A YEAR AND IS NOT PARSED: the tick
/// at the origin says `BC | AD` / `主前｜主后`, because the era it counts
/// in has no year zero (see `centuryTickLabel`). It names a boundary,
/// no record carries that value, and there is nothing for a reader to
/// search for — so the exemption costs nothing and is written down here
/// rather than left for the next round-trip test to trip over.
///
/// Returns 0, 1 or 2 years. Two when the reader typed a bare number
/// with no era: that is genuinely ambiguous on a chart running from
/// 4000 BC to the present, and guessing is the one thing not to do.
List<int> parseWheelYears(String input) {
  var s = input.trim().toLowerCase();
  if (s.isEmpty) return const [];
  // Punctuation in `b.c.` / `a.d.`, and any spacing.
  s = s.replaceAll('.', '').replaceAll(' ', '').replaceAll('　', '');
  // Chinese eras, both scripts, both vocabularies. 主後/主后 differ by
  // script only; the app prints one per locale and accepts either.
  const bcPrefixes = ['主前', '公元前', '西元前', 'bc', 'b/c'];
  const adPrefixes = ['主後', '主后', '公元', '西元', 'ad'];
  const bcSuffixes = ['bc', 'bce'];
  const adSuffixes = ['ad', 'ce'];

  var negative = false;
  var explicit = false;
  for (final p in bcPrefixes) {
    if (s.startsWith(p)) {
      s = s.substring(p.length);
      negative = true;
      explicit = true;
      break;
    }
  }
  if (!explicit) {
    for (final p in adPrefixes) {
      if (s.startsWith(p)) {
        s = s.substring(p.length);
        explicit = true;
        break;
      }
    }
  }
  if (!explicit) {
    for (final p in bcSuffixes) {
      if (s.endsWith(p)) {
        s = s.substring(0, s.length - p.length);
        negative = true;
        explicit = true;
        break;
      }
    }
  }
  if (!explicit) {
    for (final p in adSuffixes) {
      if (s.endsWith(p)) {
        s = s.substring(0, s.length - p.length);
        explicit = true;
        break;
      }
    }
  }
  // 主前586年 — the trailing 年 the rest of the app prints.
  if (s.endsWith('年')) s = s.substring(0, s.length - 1);
  if (s.startsWith('-') || s.startsWith('−')) {
    // A leading minus is BibleWorks' own convention for BC and is
    // unambiguous, so it counts as explicit even with no era word.
    s = s.substring(1);
    negative = true;
    explicit = true;
  }
  if (s.isEmpty || s.length > 5) return const [];
  final n = int.tryParse(s);
  if (n == null || n < 0) return const [];
  if (explicit) return [negative ? -n : n];
  // Bare number: both eras, earliest first so the list reads in the
  // wheel's own direction.
  return [-n, n];
}

/// Search everything the wheel knows.
///
/// [hiddenStreams] does not filter — it only marks. See the library
/// comment: a filter the reader set for the CHART must not silently
/// answer a question they asked the SEARCH.
/// [patriarchs] are the lives the annulus draws as arcs. They arrive as
/// records rather than as another list on [data] because they come out
/// of a different asset (`chronology.json`) that the wheel merges at
/// paint time, and because this function must stay pure.
///
/// [creationYear] is `bible_timeline.json`'s `_meta.creation.year`, and
/// null means "the anchor could not be read": the lives are then not
/// indexed at all rather than indexed at a year invented here.
WheelSearchResult searchWheel({
  required WheelHistoryData data,
  required String query,
  required String locale,
  required int axisEnd,
  Set<String> hiddenStreams = const {},
  List<Patriarch> patriarchs = const [],
  int? creationYear,
  String tradition = 'mt',
}) {
  final raw = query.trim();
  if (raw.isEmpty) return const WheelSearchResult.empty();
  final q = foldForWheelSearch(raw);
  final years = parseWheelYears(raw);

  final hits = <WheelHit>[];
  final seen = <String>{};

  bool take(String key) => seen.add(key);
  bool hidden(String stream) => hiddenStreams.contains(stream);

  // ── the year branch ────────────────────────────────────────────────
  //
  // Runs FIRST and is never exclusive of the term branch: `70` is both
  // a year and a word, and answering only one of those is how a search
  // box lies. Anything found twice keeps its first, stronger rank.
  //
  // THE RANKS, and why in this order. An event dated TO the year is the
  // literal answer to "what happened in 586", so it leads. A power
  // whose span merely contains the year answers the neighbouring
  // question — "what was standing then" — so it follows. Both are
  // exact, so both stay above the term tiers. The near misses are not
  // exact and sort below everything (rank [_kNearRank]).
  // The lives, as the page draws them: figures out of `chronology.json`
  // turned into BC years against the one anchor. Empty when either half
  // is missing, which is the same "draw nothing rather than guess" rule
  // the painter follows.
  final lives = creationYear == null
      ? const <({Patriarch man, int birth, int death, List<String> refs})>[]
      : [
          for (final p in patriarchs)
            if (p.figures[tradition] != null)
              (
                man: p,
                birth: creationYear + p.figures[tradition]!.birthAm,
                death: creationYear + p.figures[tradition]!.deathAm,
                refs: p.figures[tradition]!.refs.values.toSet().toList(),
              )
        ];

  var nearestShown = 0;
  for (final y in years) {
    // A life that was being lived in the year asked for. Same tier as a
    // power spanning it and for the same reason: "who was alive in 2200
    // BC" is the neighbouring question to "what happened in 2200 BC",
    // and on this stretch of the axis it is often the only one the text
    // can answer.
    for (final l in lives) {
      if (l.birth <= y && y <= l.death && take('patriarch:${l.man.id}')) {
        hits.add(WheelHit(
          kind: WheelHitKind.patriarch,
          via: WheelHitVia.yearSpan,
          id: l.man.id,
          streamId: kLifespanLayerId,
          title: l.man.nameFor(locale),
          year: l.birth,
          matched: '',
          rank: 1,
          streamHidden: hidden(kLifespanLayerId),
        ));
      }
    }
    for (final p in data.powers) {
      // A power with no end year runs to the end of the axis — the same
      // reading [WheelPower.endFor] gives the painter, not a sentinel
      // year invented here.
      if (p.start <= y && y <= p.endFor(axisEnd) && take('power:${p.id}')) {
        hits.add(WheelHit(
          kind: WheelHitKind.power,
          via: WheelHitVia.yearSpan,
          id: p.id,
          streamId: p.stream,
          title: p.nameFor(locale),
          year: p.start,
          matched: '',
          rank: 1,
          streamHidden: hidden(p.stream),
        ));
      }
    }
    for (final e in data.events) {
      if (e.year == y && take('event:${e.id}')) {
        hits.add(WheelHit(
          kind: WheelHitKind.event,
          via: WheelHitVia.yearExact,
          id: e.id,
          streamId: e.stream,
          title: e.titleFor(locale),
          year: e.year,
          matched: '',
          rank: 0,
          streamHidden: hidden(e.stream),
        ));
      }
    }
  }

  // ── the term branch ────────────────────────────────────────────────
  //
  // One pass per record, deciding the strongest way it matches. The
  // tiers are: the name the reader can see, then the same name in
  // another script, then the prose, then the verses. A record is only
  // ever listed once.
  final refQuery = raw.contains(RegExp(r'\d')) ? parseReference(raw) : null;

  bool refHit(List<String> refs, void Function(String) keep) {
    for (final r in refs) {
      if (wheelMatches(foldForWheelSearch(r), q)) {
        keep(r);
        return true;
      }
      if (refQuery != null) {
        final parsed = parseReference(r);
        if (parsed != null &&
            parsed.englishBook == refQuery.englishBook &&
            parsed.chapter == refQuery.chapter) {
          keep(r);
          return true;
        }
      }
    }
    return false;
  }

  /// The strongest tier this record matches on, or null.
  ///
  /// [people] is empty for every kind but an event — a band, a nation
  /// of Genesis 10 and a power carry no person links — so the tier
  /// simply never fires for them rather than needing a special case.
  /// [aliases] are spellings the record answers to and never shows —
  /// today, the Authorised Version's forms of the four antediluvian
  /// names the app displays as most modern versions do. Ranked below
  /// every displayed name and above the prose, because it IS the name,
  /// just not the one on screen.
  (int, WheelHitVia, String)? classify(
    Map<String, String> names,
    Map<String, String> prose,
    List<String> refs, {
    List<WheelPersonLink> people = const [],
    List<String> aliases = const [],
  }) {
    final shown = names[locale] ?? names['en'] ?? '';
    final foldedShown = foldForWheelSearch(shown);
    if (foldedShown == q) return (10, WheelHitVia.title, '');
    if (wheelMatches(foldedShown, q)) return (11, WheelHitVia.title, '');
    for (final entry in names.entries) {
      if (entry.key == locale) continue;
      if (wheelMatches(foldForWheelSearch(entry.value), q)) {
        return (12, WheelHitVia.otherLocale, entry.value);
      }
    }
    for (final a in aliases) {
      if (a.isNotEmpty && wheelMatches(foldForWheelSearch(a), q)) {
        return (12, WheelHitVia.otherSpelling, a);
      }
    }
    for (final text in prose.values) {
      if (wheelMatches(foldForWheelSearch(text), q)) {
        return (13, WheelHitVia.description, '');
      }
    }
    // The reader's own script first, so `matched` prints the name the
    // chip beside it will print. Falling through to the other two is
    // the same courtesy `otherLocale` extends to a title.
    for (final p in people) {
      final own = p.names[locale];
      if (own != null && wheelMatches(foldForWheelSearch(own), q)) {
        return (14, WheelHitVia.person, own);
      }
    }
    for (final p in people) {
      for (final n in p.allNames) {
        if (wheelMatches(foldForWheelSearch(n), q)) {
          return (14, WheelHitVia.person, n);
        }
      }
    }
    var found = '';
    if (refHit(refs, (r) => found = r)) {
      return (15, WheelHitVia.reference, found);
    }
    return null;
  }

  for (final e in data.events) {
    if (seen.contains('event:${e.id}')) continue;
    final c = classify(e.titles, e.descs, e.refs, people: e.people);
    if (c == null) continue;
    take('event:${e.id}');
    hits.add(WheelHit(
      kind: WheelHitKind.event,
      via: c.$2,
      id: e.id,
      streamId: e.stream,
      title: e.titleFor(locale),
      year: e.year,
      matched: c.$3,
      rank: c.$1,
      streamHidden: hidden(e.stream),
    ));
  }
  for (final p in data.powers) {
    if (seen.contains('power:${p.id}')) continue;
    final c = classify(p.names, p.notes, p.refs);
    if (c == null) continue;
    take('power:${p.id}');
    hits.add(WheelHit(
      kind: WheelHitKind.power,
      via: c.$2,
      id: p.id,
      streamId: p.stream,
      title: p.nameFor(locale),
      year: p.start,
      matched: c.$3,
      rank: c.$1,
      streamHidden: hidden(p.stream),
    ));
  }
  for (final s in data.streams) {
    final c = classify(s.names, const {}, const []);
    if (c == null) continue;
    hits.add(WheelHit(
      kind: WheelHitKind.stream,
      via: c.$2,
      id: s.id,
      streamId: s.id,
      title: s.nameFor(locale),
      year: null,
      matched: c.$3,
      rank: c.$1,
      streamHidden: hidden(s.id),
    ));
  }
  for (final n in data.nations) {
    final c = classify(n.names, n.notes, n.ref.isEmpty ? const [] : [n.ref],
        aliases: [n.nameKjv]);
    if (c == null) continue;
    hits.add(WheelHit(
      kind: WheelHitKind.nation,
      via: c.$2,
      id: n.id,
      streamId: n.stream,
      title: n.nameFor(locale),
      year: null,
      matched: c.$3.isEmpty && n.ref.isNotEmpty ? n.ref : c.$3,
      rank: c.$1,
      streamHidden: hidden(n.stream),
    ));
  }

  // The lives, by name. Their names are in the same three scripts as
  // everything else, and the verses are the ones each FIGURE rests on
  // — Genesis 5:27 for Methuselah's 969 — so a reader who searches a
  // verse of Genesis 5 reaches the man it numbers.
  for (final l in lives) {
    if (seen.contains('patriarch:${l.man.id}')) continue;
    final c =
        classify(l.man.names, const {}, l.refs, aliases: [l.man.nameKjv]);
    if (c == null) continue;
    take('patriarch:${l.man.id}');
    hits.add(WheelHit(
      kind: WheelHitKind.patriarch,
      via: c.$2,
      id: l.man.id,
      streamId: kLifespanLayerId,
      title: l.man.nameFor(locale),
      year: l.birth,
      matched: c.$3,
      rank: c.$1,
      streamHidden: hidden(kLifespanLayerId),
    ));
  }

  // ── the near misses ────────────────────────────────────────────────
  //
  // LAST, not with the rest of the year branch, and the order is
  // load-bearing rather than tidiness. These are claimed through the
  // same `take` as everything else, so a pass that ran earlier would
  // lock an event at the weakest rank in the file and the term branch
  // would then skip it: type `1948` and the event whose own title says
  // 1948 would be filed under "nearby", at the bottom, beneath six
  // events it outranks. Computing the fallback after the answers means
  // it can only ever pick up what nothing else claimed.
  for (final y in years) {
    final near = data.events.where((e) => e.year != y).toList()
      ..sort((a, b) {
        final d = (a.year - y).abs().compareTo((b.year - y).abs());
        return d != 0 ? d : a.year.compareTo(b.year);
      });
    var added = 0;
    for (final e in near) {
      if (added == kWheelNearestPerYear) break;
      if (!take('event:${e.id}')) continue;
      added++;
      nearestShown++;
      hits.add(WheelHit(
        kind: WheelHitKind.event,
        via: WheelHitVia.yearNear,
        id: e.id,
        streamId: e.stream,
        title: e.titleFor(locale),
        year: e.year,
        matched: '',
        rank: _kNearRank,
        streamHidden: hidden(e.stream),
      ));
    }
  }

  // Within a tier, chronological — this is a chronology, and a reader
  // scanning results is reading history in order. Records the text
  // gives no year (bands, and the nations of Genesis 10) sort after
  // the dated ones rather than pretending to a position on the axis.
  hits.sort((a, b) {
    final r = a.rank.compareTo(b.rank);
    if (r != 0) return r;
    if (a.year == null && b.year == null) return a.title.compareTo(b.title);
    if (a.year == null) return 1;
    if (b.year == null) return -1;
    final y = a.year!.compareTo(b.year!);
    return y != 0 ? y : a.title.compareTo(b.title);
  });

  return WheelSearchResult(
    hits: hits,
    years: years,
    nearestShown: nearestShown,
  );
}
