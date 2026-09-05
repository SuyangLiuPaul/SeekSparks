// Imported data that no screen can reach is invisible to every other
// kind of test.
//
// `page_reachability_test.dart` catches a PAGE that has fallen off the
// navigation graph. This catches the same defect one level down: a
// service that is reached, holding a public entry point that is not, so
// a whole branch of an import ships in the bundle and no reader can get
// to it.
//
// The instrument this replaces is recorded in `docs/PARITY-BACKLOG.md`
// (~line 596): a 2026-08-12 audit checked each Eagle's View import three
// ways — present on disk, declared in `pubspec.yaml`, referenced from
// `lib/` — and passed all six. It could not have failed. It stops at the
// SERVICE boundary, and `GreekStatsService` was "referenced from lib/"
// the whole time on the strength of `lookup()`, while `books()` and the
// entire `BookVocabulary` model had no caller anywhere. The same was
// true of `ModernConcordanceService.topics()`: the service was reached
// through `forVerse()`, and the call returning all 341 topics was dead
// for a month.
//
// So the rule is asserted about the SOURCE, per member rather than per
// file. Import edges over-approximate — a symbol can be named without
// its data reaching a pixel — which is the safe direction: this test
// never cries wolf, it only catches a branch that has become unreachable
// outright.
//
// Two ways to make it pass, and the difference is the point:
//   • You orphaned a branch by accident -> give it a surface, or delete it.
//   • You orphaned one on purpose       -> move it to [_knownUnsurfaced]
//     WITH a reason and who decided.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One public entry point that opens a branch of an imported dataset,
/// and the data a reader loses if nothing calls it.
class _Surface {
  const _Surface(this.owner, this.symbol, this.opens);

  /// The file that defines it. References from here do not count.
  final String owner;

  /// The text a call site writes — `Service.member`, or a bare type.
  final String symbol;

  /// What the reader cannot reach when this has no caller.
  final String opens;
}

/// The Eagle's View reference imports, member by member. This is the
/// axis `docs/PARITY-BACKLOG.md` audits, at the resolution the audit
/// was missing.
const List<_Surface> _surfaces = <_Surface>[
  // Modern Concordance — 341 topics, 1,645 sections, 4.8 MB.
  _Surface('lib/services/modern_concordance_service.dart',
      'ModernConcordanceService.topics', 'the whole 341-topic index'),
  _Surface('lib/services/modern_concordance_service.dart',
      'ModernConcordanceService.sections', 'one topic, fully joined'),
  _Surface('lib/services/modern_concordance_service.dart',
      'ModernConcordanceService.forVerse', 'the topics citing a verse'),
  _Surface('lib/services/modern_concordance_service.dart',
      'ModernConcordanceService.attribution',
      'the credit this data ships under'),

  // Greek NT corpus statistics — permission-granted, not public domain.
  _Surface('lib/services/greek_stats_service.dart',
      'GreekStatsService.lookup', "one word's distribution"),
  _Surface('lib/services/greek_stats_service.dart',
      'GreekStatsService.books', 'the 27-book comparative profile'),
  _Surface('lib/services/greek_stats_service.dart',
      'GreekStatsService.attribution', 'the AOSurvey copyright line'),

  // Thayer + Hitchcock.
  _Surface('lib/services/thayer_service.dart', 'ThayerService.lookup',
      "one Thayer's article"),
  _Surface('lib/services/thayer_service.dart', 'ThayerService.rawArticles',
      'the lexicon as a browsable list'),
  _Surface('lib/services/thayer_service.dart', 'ThayerService.attribution',
      'the credit'),
  _Surface('lib/services/bible_names_service.dart',
      'BibleNamesService.lookupFromGloss', "Hitchcock's meaning of a name"),
  _Surface('lib/services/bible_names_service.dart',
      'BibleNamesService.attribution', 'the credit'),

  // The gazetteer.
  _Surface('lib/services/places_service.dart', 'PlacesService.all',
      'every place, for the Atlas index'),
  _Surface('lib/services/places_service.dart', 'PlacesService.forPassage',
      'the places named in a passage'),
  _Surface('lib/services/places_service.dart', 'PlacesService.baseMap',
      'the base map the places are plotted on'),
  _Surface('lib/services/places_service.dart', 'PlacesService.attribution',
      'the credit'),

  // The OT synopsis.
  _Surface('lib/services/synopsis_service.dart', 'SynopsisService.byChapter',
      'the parallel passages for a chapter'),
  _Surface('lib/services/synopsis_service.dart', 'SynopsisService.byVerse',
      'the parallels covering the verse under the cursor'),
  _Surface('lib/services/synopsis_service.dart',
      'SynopsisService.hasSynopsisSync',
      'whether to offer the menu item at all'),
  _Surface('lib/services/synopsis_service.dart',
      'SynopsisService.otAttribution',
      "Eagle's View's credit, which its permission is conditional on"),
];

/// Branches that ship unreachable. Empty is the goal. An entry is a
/// decision, or an open question carrying its evidence — never a silent
/// accident, and never a place to park something because it is
/// inconvenient to wire up.
const Map<String, String> _knownUnsurfaced = <String, String>{
  'BookVocabulary':
      'The 27-book Greek vocabulary table (name/abbr/totalWords/'
          'distinctWords/meanOccurrence/ratioVsLuke, 27 rows in '
          'assets/greek_stats/index.json). Declined 2026-09-05, not '
          'forgotten: the Bible Tools Overview already prints per-book '
          'running words and distinct lemmas for all 66 books from the '
          "app's own tagged text (stats_page.dart, "
          'OriginalsBookStat.totalWords/uniqueLemmas), so a second table '
          'would restate two of its four columns with DIFFERENT numbers '
          '(Westcott-Hort vs the shipped tagged Greek) — a contradiction '
          'the reader cannot resolve, and the near-identical-lists '
          'defect the Round 56 cleanup removed. The two genuinely new '
          'columns are 54 cells nothing in the app asks for. If it is '
          'ever wanted, the shape is a NT-only expandable row on the '
          'Overview showing only those two columns. `books()` itself IS '
          'called — it is what loads the AOSurvey attribution.',
  'SynopsisService.count':
      'A whole-corpus total for the synopsis. Nothing prints it: both '
          'synopsis surfaces are entered from the chapter in hand, and '
          'no screen states the size of the work. Harmless; listed so '
          'the next reader does not re-discover it as a defect.',
};

/// [source] with its comments removed.
///
/// Not fussiness. The first version of this test scanned raw source and
/// passed with the browse page DELETED, because `workbench_page.dart`
/// carries a comment that names `ModernConcordanceService.topics()`
/// while explaining why the page exists. An instrument a doc comment can
/// satisfy measures prose, not wiring — and this codebase writes long
/// comments that quote symbol names on purpose, so it would have been
/// defeated constantly and quietly.
///
/// Deliberately crude: line comments, doc comments and block comments,
/// with no attempt to respect a `//` inside a string literal. A string
/// containing `//` would lose its tail here, which can only make a
/// symbol harder to find — the safe direction for a test that must not
/// cry wolf.
String stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      if (end == -1) break;
      i = end;
    } else if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      if (end == -1) break;
      i = end + 2;
    } else {
      out.write(source[i]);
      i++;
    }
  }
  return out.toString();
}

void main() {
  /// Every `.dart` under `lib/`, by path, with comments stripped.
  Map<String, String> sources() {
    final out = <String, String>{};
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.dart')) {
        out[e.path.replaceAll(r'\', '/')] =
            stripComments(e.readAsStringSync());
      }
    }
    return out;
  }

  test('every imported data branch has a caller outside its own service',
      () {
    final src = sources();
    expect(src.length, greaterThan(100),
        reason: 'test must run from the package root');

    final orphans = <String>[];
    for (final s in _surfaces) {
      expect(src.containsKey(s.owner), isTrue,
          reason: '${s.owner} has moved — update this list with it');
      final callers = <String>[
        for (final e in src.entries)
          if (e.key != s.owner && e.value.contains(s.symbol)) e.key,
      ];
      if (callers.isEmpty) orphans.add('${s.symbol}  — unreachable: ${s.opens}');
    }

    expect(
      orphans,
      isEmpty,
      reason: 'An imported dataset ships in the bundle with no way to '
          'reach it.\nIf that is deliberate, move it to '
          '_knownUnsurfaced with a reason.\nIf it is not, something '
          'stopped pointing at it — or it never did.\n'
          '${orphans.join('\n')}',
    );
  });

  test('the known-unsurfaced list is still telling the truth', () {
    final src = sources();
    final surfaced = <String>[];
    _knownUnsurfaced.forEach((symbol, _) {
      // The defining file is whichever one declares it; a reference
      // anywhere else means it now has a surface.
      final owners = <String>[
        for (final e in src.entries)
          if (e.key.startsWith('lib/services/') && e.value.contains(symbol))
            e.key,
      ];
      final others = <String>[
        for (final e in src.entries)
          if (!owners.contains(e.key) && e.value.contains(symbol)) e.key,
      ];
      if (others.isNotEmpty) surfaced.add('$symbol now used by $others');
    });

    expect(surfaced, isEmpty,
        reason: 'Good news, and the list has to shrink to match: these '
            'were recorded as deliberately unreachable and now have a '
            'caller. Remove them from _knownUnsurfaced (and add the '
            'member to _surfaces if it should stay reachable).\n'
            '${surfaced.join('\n')}');
  });

  // The stripper is load-bearing, so it is pinned rather than trusted.
  test('a symbol named only in a comment is not a caller', () {
    const sample = '''
// ModernConcordanceService.topics() had no caller for a month.
/// See ModernConcordanceService.topics() for the index.
/* ModernConcordanceService.topics() again */
void nothing() {}
''';
    expect(stripComments(sample).contains('ModernConcordanceService.topics'),
        isFalse);
    expect(stripComments(sample).contains('void nothing()'), isTrue);
  });

  // Guards the walk against passing because it found nothing — a typo
  // in a symbol makes every entry look reachable if the search is
  // inverted, and an empty `lib/` scan would make them all look
  // orphaned. Pin one member that is unambiguously live.
  test('the scan actually finds a known-live caller', () {
    final src = sources();
    final callers = <String>[
      for (final e in src.entries)
        if (e.key != 'lib/services/modern_concordance_service.dart' &&
            e.value.contains('ModernConcordanceService.forVerse'))
          e.key,
    ];
    expect(callers, isNotEmpty,
        reason: 'the Topics tab calls forVerse; if this is empty the '
            'scan is broken, not the app');
  });
}
