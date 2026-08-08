import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/command_verb.dart';

/// A stand-in registry. Deliberately NOT the real `bibleVersions`: these
/// tests pin the grammar, and they should not start failing the day an
/// edition is added or renamed.
const _versions = [
  VerbVersion(code: 'kjv', label: 'KJV', language: 'en'),
  VerbVersion(code: 'nasb', label: 'NASB', language: 'en'),
  VerbVersion(code: 'bsb', label: 'BSB', language: 'en'),
  VerbVersion(code: 'cuvs-yhwh', label: 'CUVS(简)', language: 'zh-Hans'),
  VerbVersion(code: 'cuvs-yhwh-tr', label: 'CUVS(繁)', language: 'zh-Hant'),
  VerbVersion(code: 'lxxwh', label: 'LXX/WH', language: 'grc'),
];

VerbContext _ctx({
  String search = 'kjv',
  List<String> display = const ['kjv', 'nasb'],
  String? book = 'John',
  int? chapter = 3,
}) =>
    VerbContext(
      versions: _versions,
      searchVersion: search,
      displayVersions: display,
      currentEnglishBook: book,
      currentChapter: chapter,
    );

CommandVerbParse _p(String input, [VerbContext? ctx]) =>
    parseCommandVerb(input, ctx ?? _ctx());

void main() {
  group('not a verb — the fall-through must stay wide', () {
    // Everything the command line could already do has to keep working.
    // A verb parser that swallows one of these is a regression that no
    // amount of new capability pays for.
    for (final input in const [
      '',
      '   ',
      'love',
      'dog',
      'lord',
      'peace',
      'Gen 1:1',
      'John 3',
      '约 3:16',
      '.love god',
      "'in the beginning",
      '/faith works',
      ';paul silas;10',
      'G25 AND G26',
      'H157',
      'kjv',
      'NASB',
      'd.love', // no space after the letter — a word, not a verb
      'lord of hosts',
    ]) {
      test('"$input" is not a verb', () {
        expect(_p(input).isVerb, isFalse, reason: input);
      });
    }
  });

  group('d — the display set editor', () {
    test('bare d asks for an argument rather than searching for "d"', () {
      final r = _p('d');
      expect(r.issue, CommandVerbIssue.displayNeedsArgument);
    });

    test('d bsb adds', () {
      final r = _p('d bsb');
      expect(r.verb!.kind, CommandVerbKind.displayAdd);
      expect(r.verb!.versions, ['bsb']);
    });

    test('short label and code are both accepted, any case', () {
      expect(_p('d BSB').verb!.versions, ['bsb']);
      expect(_p('d Bsb').verb!.versions, ['bsb']);
    });

    test('d on something already stacked says so instead of no-opping', () {
      final r = _p('d nasb');
      expect(r.issue, CommandVerbIssue.alreadyDisplayed);
      expect(r.detail, 'NASB');
    });

    test('the search version counts as displayed', () {
      expect(_p('d kjv').issue, CommandVerbIssue.alreadyDisplayed);
    });

    test('d niv names the token rather than silently searching', () {
      final r = _p('d niv');
      expect(r.issue, CommandVerbIssue.unknownVersion);
      expect(r.detail, 'niv');
    });

    test('d -nasb removes', () {
      final r = _p('d -nasb');
      expect(r.verb!.kind, CommandVerbKind.displayRemove);
      expect(r.verb!.versions, ['nasb']);
    });

    // The invariant BibleWorks states as "all versions except the search
    // version": the frame re-adds it, so a naive removal would look like
    // it worked and change nothing.
    test('the search version cannot be removed', () {
      final r = _p('d -kjv');
      expect(r.issue, CommandVerbIssue.cannotRemoveSearchVersion);
      expect(r.detail, 'KJV');
    });

    test('removing something absent says so', () {
      expect(_p('d -bsb').issue, CommandVerbIssue.notDisplayed);
    });

    test('a line may not mix adding and removing', () {
      expect(_p('d bsb -nasb').issue, CommandVerbIssue.unknownVersion);
      expect(_p('d -nasb bsb').issue, CommandVerbIssue.unknownVersion);
    });

    test('d c clears, in any case, and is not a version lookup', () {
      for (final input in const ['d c', 'd C']) {
        final r = _p(input);
        expect(r.verb!.kind, CommandVerbKind.displayClear, reason: input);
      }
    });

    test('d english adds every English edition not already stacked', () {
      final r = _p('d english');
      expect(r.verb!.kind, CommandVerbKind.displayAdd);
      expect(r.verb!.versions, ['bsb']); // kjv + nasb are already there
    });

    test('a language with nothing new to add is reported, not run', () {
      final r = _p('d english', _ctx(display: ['kjv', 'nasb', 'bsb']));
      expect(r.issue, CommandVerbIssue.alreadyDisplayed);
    });

    test('Chinese language names work, both scripts', () {
      expect(_p('d 简体').verb!.versions, ['cuvs-yhwh']);
      expect(_p('d 繁體').verb!.versions, ['cuvs-yhwh-tr']);
      expect(_p('d traditional').verb!.versions, ['cuvs-yhwh-tr']);
    });

    // `zh` says Chinese without saying which script, and half this app's
    // readers use each. Refusing beats picking one for them.
    test('bare "zh" is refused as ambiguous', () {
      expect(_p('d zh').issue, CommandVerbIssue.unknownVersion);
    });

    test('several editions in one line', () {
      final r = _p('d bsb lxxwh');
      expect(r.verb!.versions, ['bsb', 'lxxwh']);
    });

    test('duplicates within one line collapse', () {
      expect(_p('d bsb bsb BSB').verb!.versions, ['bsb']);
    });
  });

  group('p — replace the stack, in order', () {
    test('bare p switches to Browse without restacking', () {
      expect(_p('p').verb!.kind, CommandVerbKind.browseOn);
    });

    test('p a b c keeps the order the reader typed', () {
      final r = _p('p lxxwh bsb kjv');
      expect(r.verb!.kind, CommandVerbKind.displaySet);
      expect(r.verb!.versions, ['lxxwh', 'bsb', 'kjv']);
    });

    // p replaces, so unlike d it must NOT complain that a version is
    // already stacked — restating the current stack is a legal way to
    // reorder it.
    test('p accepts editions that are already displayed', () {
      expect(_p('p kjv nasb').verb!.kind, CommandVerbKind.displaySet);
    });

    test('p rejects an unknown edition by name', () {
      final r = _p('p bsb niv');
      expect(r.issue, CommandVerbIssue.unknownVersion);
      expect(r.detail, 'niv');
    });
  });

  group('ai — describe the passages you want', () {
    test('ai takes everything after it as the question, verbatim', () {
      final verb = _p('ai 关于焦虑的经文').verb!;
      expect(verb.kind, CommandVerbKind.askAi);
      expect(verb.aiQuery, '关于焦虑的经文');
    });

    test('the question keeps its own punctuation and casing', () {
      expect(_p('AI  What does Paul say about grace?').verb!.aiQuery,
          'What does Paul say about grace?');
    });

    test('a bare ai is NOT a verb — Ai is a city in Joshua', () {
      // It has to fall through to the text search, or Joshua 7:2
      // becomes unreachable from the command line.
      expect(_p('ai').isVerb, isFalse);
      expect(_p('AI').isVerb, isFalse);
    });

    test('a word merely starting with "ai" is not the verb', () {
      expect(_p('airplane').isVerb, isFalse);
    });
  });

  group('l — search scope at book and chapter granularity', () {
    test('bare l lifts the limit', () {
      expect(_p('l').verb!.kind, CommandVerbKind.limitClear);
    });

    test('l gen is the whole book', () {
      final spec = _p('l gen').verb!.limit!;
      expect(spec.covers('Genesis', 1), isTrue);
      expect(spec.covers('Genesis', 50), isTrue);
      expect(spec.covers('Exodus', 1), isFalse);
      expect(spec.label, 'Genesis');
    });

    test('a chapter range covers its ends and nothing outside', () {
      final spec = _p('l matt 5-7').verb!.limit!;
      expect(spec.covers('Matthew', 4), isFalse);
      expect(spec.covers('Matthew', 5), isTrue);
      expect(spec.covers('Matthew', 7), isTrue);
      expect(spec.covers('Matthew', 8), isFalse);
      expect(spec.label, 'Matthew 5–7');
    });

    test('a single chapter', () {
      final spec = _p('l ps 119').verb!.limit!;
      expect(spec.covers('Psalms', 119), isTrue);
      expect(spec.covers('Psalms', 118), isFalse);
      expect(spec.label, 'Psalms 119');
    });

    // The whole-book branch runs first for exactly this pair: "1 John"
    // ends in no digit, but "1 Kings" BEGINS with one, so running the
    // book-plus-chapter regex first turns `1 john` into chapter 1 of a
    // nameless book.
    test('numbered books are not mistaken for a chapter', () {
      expect(_p('l 1 john').verb!.limit!.covers('1 John', 5), isTrue);
      expect(_p('l 1john').verb!.limit!.covers('1 John', 1), isTrue);
      expect(_p('l 1 kings 3').verb!.limit!.covers('1 Kings', 3), isTrue);
      expect(_p('l 1 kings 3').verb!.limit!.covers('1 Kings', 4), isFalse);
    });

    test('Chinese book names', () {
      expect(_p('l 创世记').verb!.limit!.covers('Genesis', 1), isTrue);
      expect(_p('l 约翰福音 3').verb!.limit!.covers('John', 3), isTrue);
    });

    test('testaments', () {
      final ot = _p('l ot').verb!.limit!;
      expect(ot.covers('Genesis', 1), isTrue);
      expect(ot.covers('Malachi', 4), isTrue);
      expect(ot.covers('Matthew', 1), isFalse);
      expect(ot.labelKey, 'cmdvScopeOt');

      final nt = _p('l nt').verb!.limit!;
      expect(nt.covers('Matthew', 1), isTrue);
      expect(nt.covers('Revelation', 22), isTrue);
      expect(nt.covers('Genesis', 1), isFalse);
      expect(nt.labelKey, 'cmdvScopeNt');
    });

    test('Chinese testament names', () {
      expect(_p('l 旧约').verb!.limit!.covers('Genesis', 1), isTrue);
      expect(_p('l 新約').verb!.limit!.covers('Matthew', 1), isTrue);
    });

    test('comma-separated scopes union, ASCII or CJK comma', () {
      for (final input in const ['l gen, exo', 'l gen，exo', 'l gen、exo']) {
        final spec = _p(input).verb!.limit!;
        expect(spec.covers('Genesis', 1), isTrue, reason: input);
        expect(spec.covers('Exodus', 1), isTrue, reason: input);
        expect(spec.covers('Leviticus', 1), isFalse, reason: input);
      }
      expect(_p('l gen, exo').verb!.limit!.label, 'Genesis · Exodus');
    });

    // Only the two testament shorthands get a localisable key, and only
    // when they stand alone — "Old Testament · Matthew" has no single
    // translated name.
    test('a mixed list has no localisable label key', () {
      expect(_p('l ot, matt').verb!.limit!.labelKey, isNull);
    });

    test('a verse-list file points at the Verse List Manager', () {
      final r = _p('l notes.vls');
      expect(r.issue, CommandVerbIssue.verseListFileUnsupported);
    });

    test('an unresolvable scope names the piece that failed', () {
      final r = _p('l gen, wibble');
      expect(r.issue, CommandVerbIssue.unknownScope);
      expect(r.detail, 'wibble');
    });

    test('a backwards chapter range is refused', () {
      expect(_p('l matt 7-5').issue, CommandVerbIssue.unknownScope);
    });
  });

  group('relative references', () {
    test('a bare number is a VERSE in the current chapter', () {
      final ref = _p('17').verb!.reference!;
      expect(ref.englishBook, 'John');
      expect(ref.chapter, 3);
      expect(ref.verseStart, 17);
    });

    test('chapter:verse keeps the current book', () {
      final ref = _p('1:1').verb!.reference!;
      expect(ref.englishBook, 'John');
      expect(ref.chapter, 1);
      expect(ref.verseStart, 1);
    });

    test('a range is preserved', () {
      final ref = _p('3:16-18').verb!.reference!;
      expect(ref.verseStart, 16);
      expect(ref.verseEnd, 18);
    });

    test('the CJK full-width colon works', () {
      expect(_p('3：16').verb!.reference!.verseStart, 16);
    });

    test('with nothing open, it says what to do', () {
      expect(_p('17', _ctx(book: null, chapter: null)).issue,
          CommandVerbIssue.noCurrentPassage);
    });

    test('a chapter:verse needs only the book, not the chapter', () {
      expect(_p('3:16', _ctx(chapter: null)).verb!.reference!.chapter, 3);
    });

    // Four digits is not a verse number anywhere in the Bible; leaving
    // it alone keeps the door open for it to mean something else and
    // stops "1611" navigating instead of searching.
    test('four digits is not a relative reference', () {
      expect(_p('1611').isVerb, isFalse);
      expect(_p('0').isVerb, isFalse);
    });
  });

  group('applyDisplayVerb — what you end up looking at', () {
    List<String> apply(String input, List<String> current,
        {String search = 'kjv'}) {
      final r = _p(input, _ctx(search: search, display: current));
      return applyDisplayVerb(r.verb!, current, search);
    }

    test('add appends and keeps order', () {
      expect(apply('d bsb', ['kjv', 'nasb']), ['kjv', 'nasb', 'bsb']);
    });

    test('remove drops it', () {
      expect(apply('d -nasb', ['kjv', 'nasb', 'bsb']), ['kjv', 'bsb']);
    });

    test('clear leaves the search version alone', () {
      expect(apply('d c', ['kjv', 'nasb', 'bsb']), ['kjv']);
    });

    test('p replaces rather than appending', () {
      expect(apply('p bsb lxxwh', ['kjv', 'nasb']), ['kjv', 'bsb', 'lxxwh']);
    });

    // BibleWorks' rule, and the reason `d c` is worded the way it is:
    // the search version is part of the display by definition, so `p`
    // naming three other editions still shows four.
    test('the search version is always first, even if not asked for', () {
      expect(apply('p bsb', ['kjv'], search: 'cuvs-yhwh'),
          ['cuvs-yhwh', 'bsb']);
    });

    test('the stack never contains a duplicate', () {
      expect(apply('p kjv bsb kjv', ['kjv']), ['kjv', 'bsb']);
    });

    test('browseOn leaves the stack untouched', () {
      expect(apply('p', ['kjv', 'nasb']), ['kjv', 'nasb']);
    });
  });

  group('messages', () {
    test('every refusal has real text in all three locales', () {
      for (final issue in CommandVerbIssue.values) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          final text = describeVerbIssue(issue, 'X', locale);
          expect(text.trim(), isNotEmpty, reason: '$issue / $locale');
          expect(text, isNot(contains('{')), reason: '$issue / $locale');
        }
      }
    });

    test('the unknown-edition message lists what there is', () {
      final text = describeVerbIssue(
          CommandVerbIssue.unknownVersion, 'niv', 'en',
          available: ['KJV', 'NASB']);
      expect(text, contains('niv'));
      expect(text, contains('KJV'));
      expect(text, contains('NASB'));
    });

    test('the stack echo lists the stack in all three locales', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final text = describeDisplayStack(['KJV', 'BSB'], locale);
        expect(text, contains('KJV · BSB'), reason: locale);
        expect(text, isNot(contains('{')), reason: locale);
      }
    });
  });
}
