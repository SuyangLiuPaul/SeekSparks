/// The Modern Concordance assets, checked against the invariants that
/// actually catch a bad build.
///
/// The first version of `tools/build_concordance_assets.py` keyed the
/// join on (topic, section, subsection, part) and looked fine: the topics
/// were right, the headings were right, Genesis-equivalent spot checks
/// passed. What was wrong sat one level down — StrongGk is part of the
/// key, because a subsection covers a word family (G946 BDELUGMA, G947
/// BDELUSSO, G948 BDELUKTOS all live under "Abomination" §1). Keying
/// without it collapsed 7,750 stat rows to 3,883 and piled the whole
/// family's references onto whichever word happened to be last.
///
/// The invariant that catches it: a Greek word's reference list must be
/// exactly as long as its own NT total claims. Under the bad join that
/// ran about three times over. So this file checks counts and totals
/// against each other rather than checking that the files parse.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Directory('assets/concordance');

  test('index carries all 341 topics and its attribution', () {
    final j = jsonDecode(File('${dir.path}/index.json').readAsStringSync())
        as Map<String, dynamic>;
    expect((j['topics'] as List).length, 341);
    // The permission this data ships under is conditional on crediting
    // the source, and the UI reads the credit out of the asset. An empty
    // string here would silently drop the attribution from the pane.
    expect(j['attribution'], contains("Eagle's View"));
    expect(j['attribution'], contains('Modern Concordance'));
    for (final t in j['topics'] as List) {
      expect((t['en'] as String).isNotEmpty || (t['zh'] as String).isNotEmpty,
          isTrue,
          reason: 'topic ${t['id']} has no name in either language');
    }
  });

  test('every Greek word\'s references match its own NT total', () {
    var checked = 0;
    var mismatched = 0;
    for (final f in Directory('${dir.path}/t').listSync().whereType<File>()) {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final s in j['sections'] as List) {
        for (final e in s['subsections'] as List) {
          final refs = e['refs'] as List?;
          final nt = (e['stats']?['totals'] ?? const {})['nt'] as int?;
          if (refs == null || nt == null) continue;
          checked++;
          if (refs.length != nt) mismatched++;
        }
      }
    }
    expect(checked, greaterThan(3000),
        reason: 'too few entries carried both refs and stats — the join '
            'is probably dropping one side again');
    // The source itself disagrees with its own totals in a handful of
    // places, so this is a ceiling rather than zero. The bad join put it
    // in the thousands.
    expect(mismatched, lessThan(20),
        reason: '$mismatched of $checked entries have a reference count '
            'that disagrees with their NT total. A number in the hundreds '
            'or thousands means the join lost StrongGk from its key — see '
            'tools/build_concordance_assets.py.');
  });

  test('the reverse verse index agrees with the forward topic files', () {
    // Matthew 24:15 is the abomination-of-desolation verse and is cited
    // by ten topics; picking a verse with one citation would not prove
    // the index survives a busy verse.
    final mt = jsonDecode(File('${dir.path}/v/matthew.json').readAsStringSync())
        as Map<String, dynamic>;
    final rows = mt['24:15'] as List;
    expect(rows.length, greaterThan(5));

    // Every row must resolve: the topic file exists, and it really does
    // carry that Greek word citing that verse.
    for (final r in rows) {
      final topicId = (r as List)[0] as int;
      final strongs = r[4] as String;
      final tf = File('${dir.path}/t/$topicId.json');
      expect(tf.existsSync(), isTrue, reason: 'topic $topicId has no file');
      final j = jsonDecode(tf.readAsStringSync()) as Map<String, dynamic>;
      final cites = [
        for (final s in j['sections'] as List)
          for (final e in s['subsections'] as List)
            if (e['g'] == strongs)
              for (final ref in (e['refs'] as List?) ?? const [])
                '${(ref as List)[0]} ${ref[1]}:${ref[2]}',
      ];
      expect(cites, contains('Matthew 24:15'),
          reason: 'reverse index says topic $topicId cites Matthew 24:15 '
              'via $strongs, but the topic file does not');
    }
  });

  test('every verse reference points at a real New Testament book', () {
    const nt = {
      'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians',
      '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians', 'Colossians',
      '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
      'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter',
      '1 John', '2 John', '3 John', 'Jude', 'Revelation',
    };
    var refs = 0;
    for (final f in Directory('${dir.path}/t').listSync().whereType<File>()) {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final s in j['sections'] as List) {
        for (final e in s['subsections'] as List) {
          for (final r in (e['refs'] as List?) ?? const []) {
            refs++;
            final book = (r as List)[0] as String;
            expect(nt.contains(book), isTrue, reason: 'unknown book "$book"');
            // A zero chapter or verse renders as a tappable reference
            // that navigates nowhere. The builder drops those; this
            // makes sure it kept doing so.
            expect(r[1] as int, greaterThan(0));
            expect(r[2] as int, greaterThan(0));
          }
        }
      }
    }
    // 63,925 navigable links, less the 88 that name a (subsection, Greek
    // word) pair with no row in the subsections table. Both numbers are
    // printed by tools/build_concordance_assets.py.
    expect(refs, 63837);
  });
}
