// Guards for the references that carry no scripture of their own —
// the 和合本's 見上節, 詩篇 63:6's 合和譯本並入上一節, 約翰福音 7:53's
// 見下節, lxxwh's OMIT, and the empty records.
//
// Until v1.6.93 all 233 of them rendered in scripture type: a reader on
// 詩篇 8:8 was shown "见上节" as if it were the verse, could copy it into
// a sermon, and could match it in a text search. These tests pin the
// three decisions that make the fix correct rather than merely present:
// the marker is matched WHOLE (a substring rule would blank real
// scripture), the merge CHAINS (so the head is not `verse - 1`), and an
// unresolvable head is left unnamed rather than guessed at.
//
// The corpus-wide census lives in `data_integrity_test.dart` (check 14).
// This file is the pure unit level and needs no assets.

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/verse_text_absence.dart';

void main() {
  group('verseAbsenceOf', () {
    test('classifies every marker the shipped assets actually store', () {
      // Exact stored forms, read out of the assets rather than guessed:
      // the 和合本 pair ship 詩篇 63:6 and 約翰福音 7:53 wrapped in a note,
      // cuvs-plus ships the first of those bare.
      expect(verseAbsenceOf('见上节'), VerseAbsence.merged);
      expect(verseAbsenceOf('見上節'), VerseAbsence.merged);
      expect(verseAbsenceOf('合和译本并入上一节'), VerseAbsence.merged);
      expect(verseAbsenceOf('<note: 合和译本并入上一节>'), VerseAbsence.merged);
      expect(verseAbsenceOf('<note: 合和譯本並入上一節>'), VerseAbsence.merged);
      expect(verseAbsenceOf('<note: 见下节>'), VerseAbsence.mergedNext);
      expect(verseAbsenceOf('<note: 見下節>'), VerseAbsence.mergedNext);
      expect(verseAbsenceOf('OMIT'), VerseAbsence.omitted);
      expect(verseAbsenceOf(''), VerseAbsence.blank);
      expect(verseAbsenceOf('   '), VerseAbsence.blank);
    });

    test('matches the marker whole, never as a substring', () {
      // The reason this rule is not a `contains`. Each of these is real
      // scripture that a loose rule would blank — 使徒行传 12:3's
      // 除酵节 and the many verses that simply end in 节.
      const scripture = <String>[
        '那时正是除酵节的日子。',
        '除酵节，又名逾越节，近了。',
        '他们说的见上节的话，我并不明白。',
        '见上节之后又见下节。',
        'OMITTED nothing of what he commanded.',
      ];
      for (final s in scripture) {
        expect(verseAbsenceOf(s), isNull, reason: s);
      }
    });

    test('leaves a note-wrapped verse that has words alone', () {
      // Two of the three 和合本 editions store real scripture inside a
      // `<note: …>` (約書亞記 2:6 and fourteen others the Union Version
      // prints as footnotes). Hiding those would be this same defect
      // pointed the other way.
      expect(
        verseAbsenceOf('<note: 原来她带他们上了房顶，将他们藏在那里。>'),
        isNull,
      );
    });

    test('a whole verse of scripture is scripture', () {
      expect(
        verseAbsenceOf('起初，神创造天地。'),
        isNull,
      );
      expect(
        verseAbsenceOf('In the beginning God created the heaven and the '
            'earth.'),
        isNull,
      );
    });
  });

  group('mergedVerseHeads', () {
    test('follows the chain instead of assuming the previous verse', () {
      // 詩篇 8, verbatim from assets/cuvs-yhwh.json: verses 7 AND 8 are
      // both markers, so 8's "verse above" is itself a placeholder. Both
      // resolve to 6. This is the case a `verse - 1` resolver gets wrong,
      // and it is the reason the resolution lives at the loader where the
      // whole chapter is in hand.
      final heads = mergedVerseHeads({
        5: '你叫他比天使<note: 或作神>微小一点',
        6: '你派他管理你手所造的，使万物，就是一切的牛羊、田野的兽、',
        7: '见上节',
        8: '见上节',
        9: '雅伟我们的主啊，你的名在全地何其美！',
      });
      expect(heads, {7: 6, 8: 6});
    });

    test('leaves a marker with nothing before it unmapped', () {
      // Rather than naming a verse that does not exist. The shipped
      // corpus has no such case (asserted corpus-wide in check 14), but
      // a wrong verse number is worse than a vaguer sentence.
      expect(mergedVerseHeads({1: '见上节', 2: '起初，神创造天地。'}), isEmpty);
    });

    test('never resolves a forward merge', () {
      // 見下節's head is the verse that FOLLOWS, and in the one shipped
      // case (約翰福音 7:53) it lives in the next chapter, so it cannot be
      // resolved from this chapter at all.
      final heads = mergedVerseHeads({
        52: '你且去查考，就可知道，加利利没有出过先知。',
        53: '<note: 见下节>',
      });
      expect(heads, isEmpty);
    });

    test('a reference with no scripture cannot be another verse\'s head', () {
      // An OMIT or an empty record holds no words, so it cannot be the
      // place a merged verse was printed. The head must skip back past it.
      expect(
        mergedVerseHeads({
          9: '他医好了他们。',
          10: 'OMIT',
          11: '见上节',
        }),
        {11: 9},
      );
      expect(
        mergedVerseHeads({
          1: '起初，神创造天地。',
          2: '',
          3: '见上节',
        }),
        {3: 1},
      );
    });

    test('a chapter with no markers produces no mapping', () {
      expect(
        mergedVerseHeads({1: '起初，神创造天地。', 2: '地是空虚混沌。'}),
        isEmpty,
      );
      expect(mergedVerseHeads(const {}), isEmpty);
    });
  });

  group('verseAbsenceNote', () {
    const locales = ['en', 'zh-Hans', 'zh-Hant'];

    test('names the head verse when one was resolved', () {
      for (final locale in locales) {
        final note =
            verseAbsenceNote(VerseAbsence.merged, locale, mergedWith: 6);
        expect(note, contains('6'), reason: locale);
        expect(note, isNot(contains('{v}')), reason: locale);
      }
    });

    test('says so vaguely rather than naming a verse it does not know', () {
      for (final locale in locales) {
        final note = verseAbsenceNote(VerseAbsence.merged, locale);
        expect(note, isNot(contains('{v}')), reason: locale);
        expect(note.trim(), isNotEmpty, reason: locale);
      }
    });

    test('every kind has a real sentence in every shipped locale', () {
      for (final kind in VerseAbsence.values) {
        for (final locale in locales) {
          final note = verseAbsenceNote(kind, locale, mergedWith: 6);
          expect(note.trim(), isNotEmpty, reason: '$kind/$locale');
          // The whole point is that the reader is never shown the
          // edition's typographic instruction as if it were the app's
          // explanation, in any language.
          expect(note, isNot(contains('见上节')), reason: '$kind/$locale');
          expect(note, isNot(contains('見上節')), reason: '$kind/$locale');
          expect(note, isNot(contains('OMIT')), reason: '$kind/$locale');
        }
      }
    });

    test('the two Chinese locales differ in script', () {
      // A traditional-script reader must not be handed simplified text.
      // 与/與 is the discriminating character in this string pair.
      final hans = verseAbsenceNote(VerseAbsence.merged, 'zh-Hans',
          mergedWith: 6);
      final hant = verseAbsenceNote(VerseAbsence.merged, 'zh-Hant',
          mergedWith: 6);
      expect(hans, isNot(equals(hant)));
    });
  });
}
