/// 2026-08-08 (task #280): the scope model, which is the part of the
/// search limit that has to be right before any pane can show it.
///
/// The picker, the status bar, the command line and the two analysis
/// result lists all read the scope through these functions, so a wrong
/// answer here is wrong in five places at once.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/command_verb.dart'
    show
        CommandVerbParse,
        LimitRange,
        LimitSpec,
        VerbContext,
        VerbVersion,
        parseCommandVerb;
import 'package:seeksparks/utils/search_scope.dart';

/// A stand-in registry, as in `command_verb_test` — these tests pin the
/// scope model, not the shipping list of editions.
const _versions = [
  VerbVersion(code: 'bsb', label: 'BSB', language: 'en'),
  VerbVersion(code: 'cuvs-yhwh', label: 'CUVS(简)', language: 'zh-Hans'),
];

CommandVerbParse _p(String input) => parseCommandVerb(
      input,
      const VerbContext(
        versions: _versions,
        searchVersion: 'bsb',
        displayVersions: ['bsb'],
        currentEnglishBook: 'John',
        currentChapter: 3,
      ),
    );

void main() {
  group('canonical order', () {
    test('books come back Genesis→Revelation, whatever order they went in', () {
      expect(
        canonicalScopeOrder({'Revelation', 'Genesis', 'Matthew', 'Malachi'}),
        ['Genesis', 'Malachi', 'Matthew', 'Revelation'],
      );
    });

    test('an unknown name is dropped, not sorted to an arbitrary end', () {
      expect(canonicalScopeOrder({'Genesis', 'Enoch'}), ['Genesis']);
    });
  });

  group('group naming', () {
    test('an exact set is named', () {
      expect(scopeGroupKeyFor(otPentateuch.toSet()), 'scopePentateuch');
      expect(scopeGroupKeyFor(canonicalNtBooks.toSet()), 'newTestament');
    });

    test('the Pentateuch plus Joshua is NOT the Pentateuch', () {
      expect(scopeGroupKeyFor({...otPentateuch, 'Joshua'}), isNull);
    });

    test('a subset of a group is not the group', () {
      final short = {...otPentateuch}..remove('Genesis');
      expect(scopeGroupKeyFor(short), isNull);
    });

    test('every group names books the canon actually has', () {
      for (final g in kScopeGroups) {
        expect(canonicalScopeOrder(g.books).length, g.books.length,
            reason: g.key);
        expect(uiStrings[g.key], isNotNull, reason: g.key);
      }
    });
  });

  group('books → LimitSpec', () {
    test('ranges are whole books, in canonical order', () {
      final spec = limitSpecForBooks({'Matthew', 'Genesis'});
      expect(
          [for (final r in spec.ranges) r.englishBook], ['Genesis', 'Matthew']);
      expect(spec.ranges.every((r) => r.firstChapter == null), isTrue);
    });

    test('a recognised set carries its group key', () {
      expect(limitSpecForBooks(otPentateuch).labelKey, 'scopePentateuch');
      expect(limitSpecForBooks({'Ruth'}).labelKey, isNull);
    });

    test('the spec covers what it names and nothing else', () {
      final spec = limitSpecForBooks({'Ruth'});
      expect(spec.covers('Ruth', 1), isTrue);
      expect(spec.covers('Judges', 1), isFalse);
    });
  });

  group('spec → books', () {
    test('whole books round-trip through the picker', () {
      final books = {'Genesis', 'Ruth', 'John'};
      expect(wholeBooksOfSpec(limitSpecForBooks(books)), books);
    });

    test('a chapter range is not book-shaped, so it refuses to flatten', () {
      // `l matt 5-7` must not reopen the picker as "all of Matthew" —
      // that would silently widen a scope the reader narrowed.
      final spec = _p('l matt 5-7').verb!.limit!;
      expect(wholeBooksOfSpec(spec), isNull);
    });
  });

  group('display name', () {
    test('a named group wins over listing its books', () {
      expect(
        scopeDisplayName(
            spec: limitSpecForBooks(canonicalOtBooks), locale: 'zh-Hans'),
        '希伯来圣经',
      );
    });

    test('book names follow the reading version, not the UI locale (#283)', () {
      // The defect this replaced: `l 创` put "Genesis" in a Chinese banner
      // because the spec's own label is canonical English.
      final spec = limitSpecForBooks({'Genesis'});
      expect(spec.label, 'Genesis');
      expect(
        scopeDisplayName(spec: spec, locale: 'en', version: 'cuvs-yhwh'),
        '创世纪',
      );
      expect(
        scopeDisplayName(spec: spec, locale: 'zh-Hans', version: 'bsb'),
        'Genesis',
      );
    });

    test('chapters survive localisation', () {
      final spec = LimitSpec(
          [LimitRange('Matthew', firstChapter: 5, lastChapter: 7)],
          'Matthew 5-7');
      expect(scopeDisplayName(spec: spec, locale: 'zh-Hans'), '马太福音 5–7');
    });

    test('a long list is truncated with a count, never silently cut', () {
      final spec = limitSpecForBooks({'Genesis', 'Exodus', 'Ruth', 'John'});
      expect(scopeDisplayName(spec: spec, locale: 'en', maxNames: 2),
          'Genesis · Exodus +2');
    });

    test('a verse list has no ranges, so its own name is the description', () {
      expect(
        scopeDisplayName(spec: null, fallbackLabel: '受苦仆人', locale: 'zh-Hans'),
        '受苦仆人',
      );
    });
  });

  group('scoped count', () {
    test('no scope prints one number', () {
      expect(scopedCountLabel(64, 64), '64');
      expect(scopedCountLabel(64, null), '64');
    });

    test('a narrowed count carries its denominator (bwh23)', () {
      expect(scopedCountLabel(64, 1278), '64 / 1278');
      expect(scopedCountLabel(0, 1278), '0 / 1278');
    });

    test('a total that is somehow smaller is not printed as nonsense', () {
      expect(scopedCountLabel(64, 3), '64');
    });
  });

  group('terminology', () {
    // #280: the corpora are 希伯来圣经 / 希腊圣经. A supersessionist pair of
    // names is not a thing to reintroduce by copying a nearby string.
    test('no scope-path name says 旧约 or 新约', () {
      final keys = <String>[
        for (final g in kScopeGroups) g.key,
        'scopeTitle',
        'scopeMenu',
        'scopeStatusField',
        'scopeWholeBible',
        'scopeGroupsLabel',
        'scopeSelected',
        'scopeNoneSelected',
        'scopeOfWhole',
        'scopeEmptyHere',
        'scopeStatsHint',
      ];
      for (final key in keys) {
        final entry = uiStrings[key];
        expect(entry, isNotNull, reason: key);
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          final value = entry![locale];
          expect(value, isNotNull, reason: '$key/$locale');
          expect(value, isNot(contains('旧约')), reason: '$key/$locale');
          expect(value, isNot(contains('新约')), reason: '$key/$locale');
          expect(value, isNot(contains('舊約')), reason: '$key/$locale');
          expect(value, isNot(contains('新約')), reason: '$key/$locale');
        }
      }
    });

    test('the command line still accepts what readers already type', () {
      for (final input in const ['l ot', 'l 旧约', 'l 希伯来圣经']) {
        expect(_p(input).verb!.limit!.labelKey, 'oldTestament', reason: input);
      }
      for (final input in const ['l nt', 'l 新约', 'l 希腊圣经']) {
        expect(_p(input).verb!.limit!.labelKey, 'newTestament', reason: input);
      }
    });
  });
}
