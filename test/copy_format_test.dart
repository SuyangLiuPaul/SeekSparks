import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/copy_format.dart';
import 'package:seeksparks/utils/verse_list.dart' show VerseRef;

// ── Fakes ───────────────────────────────────────────────────────────

String _book(String english, CopyBookStyle style) => switch (style) {
      CopyBookStyle.full => english,
      CopyBookStyle.abbreviated => switch (english) {
          'Genesis' => 'Gen',
          'Exodus' => 'Exo',
          'John' => 'Jhn',
          _ => english.length >= 3 ? english.substring(0, 3) : english,
        },
    };

String _version(String code) => code.toUpperCase();

VerseRef _r(String book, int c, int v) => VerseRef(book, c, v);

/// A tiny corpus. `bsb` has all of them; `kjv` is deliberately missing
/// John 3:17 so the "version does not carry the verse" path is
/// exercised rather than assumed.
const _corpus = <String, Map<String, String>>{
  'bsb': {
    'John|3|16': 'For God so loved the world<note: Or loved the world in '
        'this way> that He gave His [one and] only Son',
    'John|3|17': 'For God did not send His Son into the world to condemn it',
    'John|3|18': 'Whoever believes in Him is not condemned',
    'Genesis|1|1': 'In the beginning God created the heavens and the earth',
    'Genesis|1|2': 'Now the earth was formless and void',
    'Genesis|2|1': 'Thus the heavens and the earth were completed',
  },
  'kjv': {
    'John|3|16': 'For God so loved the world, that he gave his only Son',
    'John|3|18': 'He that believeth on him is not condemned',
  },
};

String? _text(String code, VerseRef r) =>
    _corpus[code]?['${r.englishBook}|${r.chapter}|${r.verse}'];

String? _rights(String code) => switch (code) {
      'bsb' => 'Public domain.',
      'kjv' => 'Public domain.',
      _ => null,
    };

String _format(Iterable<VerseRef> refs, CopyOptions o) => formatCopy(
      refs,
      o,
      bookName: _book,
      versionName: _version,
      verseText: _text,
      attribution: _rights,
    );

void main() {
  // ── normaliseRefs ───────────────────────────────────────────────
  group('normaliseRefs', () {
    test('sorts canonically and drops duplicates', () {
      final out = normaliseRefs([
        _r('John', 3, 16),
        _r('Genesis', 1, 2),
        _r('Genesis', 1, 1),
        _r('Genesis', 1, 2), // a second search hit in the same verse
      ]);
      expect(out.map((r) => '${r.englishBook} ${r.chapter}:${r.verse}'),
          ['Genesis 1:1', 'Genesis 1:2', 'John 3:16']);
    });

    test('unknown books sort to the end, not to the front', () {
      final out = normaliseRefs([_r('Nowhere', 1, 1), _r('Genesis', 1, 1)]);
      expect(out.first.englishBook, 'Genesis');
    });
  });

  // ── renderRun: the f / ff rule from bwh29 ───────────────────────
  group('renderRun', () {
    const sep = CopySeparators();

    test('a single verse is just the number', () {
      expect(renderRun(5, 1, sep, 0), '5');
      expect(renderRun(5, 1, sep, 3), '5');
    });

    test('threshold 0 never abbreviates — the default', () {
      expect(renderRun(1, 2, sep, 0), '1–2');
      expect(renderRun(1, 9, sep, 0), '1–9');
    });

    test('a run of exactly two becomes f, not ff', () {
      // bwh29: "if this setting is greater than zero and the range only
      // covers two verses, an f will be used instead of an ff."
      expect(renderRun(15, 2, sep, 1), '15f');
    });

    test('a longer run becomes ff', () {
      expect(renderRun(23, 3, sep, 1), '23ff');
      expect(renderRun(23, 40, sep, 1), '23ff');
    });

    test('runs at or below the threshold stay explicit', () {
      expect(renderRun(1, 2, sep, 3), '1–2');
      expect(renderRun(1, 3, sep, 3), '1–3');
      expect(renderRun(1, 4, sep, 3), '1ff');
    });

    test('a large threshold merges without ever abbreviating', () {
      // bwh29's own escape hatch: "enter a large number in the box".
      expect(renderRun(1, 50, sep, 9999), '1–50');
    });

    test('honours a custom range separator', () {
      expect(renderRun(1, 2, sep.copyWith(verseRange: '-'), 0), '1-2');
    });
  });

  // ── renderReferenceList ─────────────────────────────────────────
  group('renderReferenceList', () {
    test('reproduces the example in bwh29 verbatim', () {
      // "a string of references such as Gen 1:1, Gen 1:2, Gen 2:1 would
      // be converted to Gen 1:1-2; 2:1" — with our en-dash default.
      final out = renderReferenceList(
        [_r('Genesis', 1, 1), _r('Genesis', 1, 2), _r('Genesis', 2, 1)],
        const CopyOptions(includeText: false, bookStyle: CopyBookStyle.abbreviated),
        _book,
      );
      expect(out, 'Gen 1:1–2; 2:1');
    });

    test('the book name is printed once per book, then chapters follow', () {
      final out = renderReferenceList(
        [_r('Genesis', 1, 1), _r('Exodus', 3, 4), _r('Exodus', 3, 5)],
        const CopyOptions(bookStyle: CopyBookStyle.abbreviated),
        _book,
      );
      expect(out, 'Gen 1:1; Exo 3:4–5');
    });

    test('non-adjacent verses in one chapter use the verse separator', () {
      final out = renderReferenceList(
        [_r('Genesis', 1, 1), _r('Genesis', 1, 3), _r('Genesis', 1, 7)],
        const CopyOptions(bookStyle: CopyBookStyle.abbreviated),
        _book,
      );
      expect(out, 'Gen 1:1, 3, 7');
    });

    test('merging off repeats the book name on every reference', () {
      final out = renderReferenceList(
        [_r('Genesis', 1, 1), _r('Genesis', 1, 2)],
        const CopyOptions(
            mergeConsecutive: false, bookStyle: CopyBookStyle.abbreviated),
        _book,
      );
      expect(out, 'Gen 1:1; Gen 1:2');
    });

    test('one per line replaces the reference separator', () {
      final out = renderReferenceList(
        [_r('Genesis', 1, 1), _r('Exodus', 3, 4)],
        const CopyOptions(
            refListOnePerLine: true, bookStyle: CopyBookStyle.abbreviated),
        _book,
      );
      expect(out, 'Gen 1:1\nExo 3:4');
    });

    test('European separators — Gen 1,1 with no space after the comma', () {
      final out = renderReferenceList(
        [_r('Genesis', 1, 1)],
        const CopyOptions(
          bookStyle: CopyBookStyle.abbreviated,
          separators: CopySeparators(chapterVerse: ','),
        ),
        _book,
      );
      expect(out, 'Gen 1,1');
    });

    test('an empty list renders as the empty string, not "null"', () {
      expect(renderReferenceList(const [], const CopyOptions(), _book), '');
    });

    test('input order does not matter — the list is canonicalised', () {
      final scrambled = renderReferenceList(
        [_r('Genesis', 2, 1), _r('Genesis', 1, 2), _r('Genesis', 1, 1)],
        const CopyOptions(bookStyle: CopyBookStyle.abbreviated),
        _book,
      );
      expect(scrambled, 'Gen 1:1–2; 2:1');
    });
  });

  // ── renderTemplate ──────────────────────────────────────────────
  group('renderTemplate', () {
    String t(String template, {String version = 'BSB'}) => renderTemplate(
          template,
          ref: 'John 3:16',
          book: 'John',
          chapter: '3',
          verse: '16',
          version: version,
        );

    test('substitutes every supported tag', () {
      expect(t('<ref> (<version>)'), 'John 3:16 (BSB)');
      expect(t('<book> <chapter>:<verse>'), 'John 3:16');
      expect(t('<book><tab><chapter>'), 'John\t3');
      expect(t('<book><p><chapter>'), 'John\n3');
    });

    test('an empty version does not leave a bare pair of parentheses', () {
      expect(t('<ref> (<version>)', version: ''), 'John 3:16');
    });

    test('unknown tags are left alone rather than silently deleted', () {
      // bwh29 lists <b>/<i>/<sup>; we emit plain text and refuse to
      // pretend. Leaving the text visible is the honest failure.
      expect(t('<b><ref></b>'), '<b>John 3:16</b>');
    });
  });

  // ── copyVerseText: the apparatus ────────────────────────────────
  group('copyVerseText', () {
    const raw = 'Now<note: Or "And"> the earth was [was] formless';

    test('drops footnotes and brackets by default', () {
      expect(copyVerseText(raw, const CopyOptions()),
          'Now the earth was was formless');
    });

    test('keeps the brackets when asked', () {
      expect(copyVerseText(raw, const CopyOptions(keepSuppliedBrackets: true)),
          'Now the earth was [was] formless');
    });

    test('parenthesises footnotes when asked', () {
      expect(copyVerseText(raw, const CopyOptions(includeNotes: true)),
          'Now (Or "And") the earth was was formless');
    });

    test('lifting a note does not leave a space before punctuation', () {
      expect(copyVerseText('the beginning<note: x>, and', const CopyOptions()),
          'the beginning, and');
    });

    test('the pilcrow that NASB prints as a paragraph mark is removed', () {
      expect(copyVerseText('¶ In the beginning', const CopyOptions()),
          'In the beginning');
    });
  });

  // ── formatCopy ──────────────────────────────────────────────────
  group('formatCopy', () {
    final john = [_r('John', 3, 16), _r('John', 3, 17), _r('John', 3, 18)];

    test('an empty selection produces nothing at all', () {
      expect(_format(const [], const CopyOptions(versions: ['bsb'])), '');
    });

    test('passage scope: one heading, then running text with numbers', () {
      final out = _format(
        john,
        optionsForPreset(CopyPreset.sermon).copyWith(versions: ['bsb']),
      );
      expect(out, startsWith('John 3:16–18 (BSB)\n'));
      expect(out, contains('16 For God so loved the world that He gave'));
      expect(out, contains('17 For God did not send'));
      // One running paragraph: the verses are not on separate lines.
      expect(out.split('\n')[1], contains('18 Whoever believes'));
    });

    test('citation preset: quoted text, then the reference after it', () {
      final out = _format(
        [_r('John', 3, 16)],
        optionsForPreset(CopyPreset.citation).copyWith(versions: ['bsb']),
      );
      expect(out, startsWith('“For God so loved'));
      expect(out, contains('”\nJohn 3:16 (BSB)'));
      // Supplied words keep their brackets in a paper.
      expect(out, contains('[one and] only Son'));
    });

    test('perVerse scope labels every line and repeats nothing', () {
      final out = _format(
        john,
        const CopyOptions(
          versions: ['bsb'],
          refScope: CopyRefScope.perVerse,
          newlinePerVerse: true,
          includeAttribution: false,
        ),
      );
      final lines = out.split('\n');
      expect(lines[0], startsWith('John 3:16 (BSB) For God so loved'));
      expect(lines[1], startsWith('John 3:17 (BSB) For God did not'));
      expect(lines[2], startsWith('John 3:18 (BSB) Whoever believes'));
    });

    test('none scope is bare prose', () {
      final out = _format(
        [_r('John', 3, 16)],
        optionsForPreset(CopyPreset.plain).copyWith(versions: ['bsb']),
      );
      expect(out, 'For God so loved the world that He gave His one and only Son');
    });

    test('interleaved multi-version names the version on every line', () {
      final out = _format(
        [_r('John', 3, 16), _r('John', 3, 18)],
        const CopyOptions(
          versions: ['bsb', 'kjv'],
          interleave: true,
          refScope: CopyRefScope.none,
          inlineVerseNumbers: true,
          includeAttribution: false,
        ),
      );
      expect(out.split('\n'), [
        'BSB 16 For God so loved the world that He gave His one and only Son',
        'KJV 16 For God so loved the world, that he gave his only Son',
        'BSB 18 Whoever believes in Him is not condemned',
        'KJV 18 He that believeth on him is not condemned',
      ]);
    });

    test('blocked multi-version groups by version under a heading', () {
      final out = _format(
        [_r('John', 3, 16), _r('John', 3, 18)],
        const CopyOptions(
          versions: ['bsb', 'kjv'],
          interleave: false,
          refScope: CopyRefScope.none,
          inlineVerseNumbers: true,
          newlinePerVerse: true,
          includeAttribution: false,
        ),
      );
      final blocks = out.split('\n\n');
      expect(blocks.length, 2);
      expect(blocks[0], startsWith('BSB\n16 For God so loved'));
      expect(blocks[1], startsWith('KJV\n16 For God so loved'));
    });

    test('a version missing a verse is skipped, not reported as an error', () {
      // kjv has no John 3:17 in the fake corpus.
      final out = _format(
        john,
        const CopyOptions(
          versions: ['kjv'],
          refScope: CopyRefScope.none,
          inlineVerseNumbers: true,
          newlinePerVerse: true,
          includeAttribution: false,
        ),
      );
      expect(out.split('\n').length, 2);
      expect(out, isNot(contains('17')));
    });

    test('the passage heading names no version when several are copied', () {
      final out = _format(
        [_r('John', 3, 16)],
        const CopyOptions(
          versions: ['bsb', 'kjv'],
          refScope: CopyRefScope.passage,
          includeAttribution: false,
        ),
      );
      // Naming one of two would be a false citation.
      expect(out.split('\n').first, 'John 3:16');
    });

    test('attribution cites only the versions actually copied', () {
      final out = _format(
        [_r('John', 3, 16)],
        const CopyOptions(versions: ['bsb'], includeAttribution: true),
      );
      expect(out, endsWith('BSB — Public domain.'));
      expect(out, isNot(contains('KJV')));
    });

    test('attribution is suppressible', () {
      final out = _format(
        [_r('John', 3, 16)],
        const CopyOptions(versions: ['bsb'], includeAttribution: false),
      );
      expect(out, isNot(contains('Public domain')));
    });

    test('a reference-only copy still works with no versions selected', () {
      final out = _format(
        [_r('Genesis', 1, 1), _r('Genesis', 1, 2)],
        const CopyOptions(includeText: false, includeAttribution: false),
      );
      expect(out, 'Genesis 1:1–2');
    });

    test('asking for text with no version falls back to the reference', () {
      // Better than returning an empty clipboard, which reads as a
      // failed copy rather than as an unanswerable request.
      final out = _format(
        [_r('Genesis', 1, 1)],
        const CopyOptions(includeText: true, versions: []),
      );
      expect(out, 'Genesis 1:1');
    });
  });

  // ── Presets ─────────────────────────────────────────────────────
  group('presets', () {
    test('every preset round-trips through presetOf', () {
      for (final p in CopyPreset.values) {
        if (p == CopyPreset.custom) continue;
        expect(presetOf(optionsForPreset(p)), p, reason: p.name);
      }
    });

    test('the version list does not change which preset is recognised', () {
      final o = optionsForPreset(CopyPreset.sermon)
          .copyWith(versions: ['bsb', 'kjv']);
      expect(presetOf(o), CopyPreset.sermon);
    });

    test('touching any switch reports custom', () {
      final o = optionsForPreset(CopyPreset.sermon).copyWith(quoteText: true);
      expect(presetOf(o), CopyPreset.custom);
    });
  });

  // ── Persistence ─────────────────────────────────────────────────
  group('CopyOptions JSON', () {
    test('round-trips every field', () {
      const o = CopyOptions(
        includeText: false,
        versions: ['bsb', 'kjv'],
        interleave: false,
        refScope: CopyRefScope.perVerse,
        refPlacement: CopyRefPlacement.after,
        refTemplate: '<book> <chapter>,<verse>',
        bookStyle: CopyBookStyle.abbreviated,
        inlineVerseNumbers: false,
        newlinePerVerse: true,
        quoteText: true,
        includeNotes: true,
        keepSuppliedBrackets: true,
        mergeConsecutive: false,
        ffThreshold: 3,
        refListOnePerLine: true,
        separators: CopySeparators(chapterVerse: ','),
        includeAttribution: false,
      );
      final back = CopyOptions.fromJson(o.toJson());
      expect(back.toJson(), o.toJson());
    });

    test('a blob from an older build keeps its known fields', () {
      // The whole point: adding a field must not reset the reader's
      // other settings to defaults.
      final back = CopyOptions.fromJson({'quoteText': true});
      expect(back.quoteText, isTrue);
      expect(back.refScope, const CopyOptions().refScope);
      expect(back.separators, const CopySeparators());
    });

    test('an unrecognised enum name falls back rather than throwing', () {
      final back = CopyOptions.fromJson({'refScope': 'nonsense'});
      expect(back.refScope, const CopyOptions().refScope);
    });
  });
}
