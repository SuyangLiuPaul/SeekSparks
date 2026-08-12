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

  group('rangeLabelHeads', () {
    test('reads the publisher\'s own range label', () {
      // 路加福音 1, verbatim from assets/biblexg-v2.json: the record
      // numbered 1 is labelled `1-4` because the publisher printed the
      // prologue as one block. 2, 3 and 4 have no record, and are not
      // lost — they are on the page under a number the reader can see.
      expect(rangeLabelHeads({1: '1-4', 5: '5'}), {2: 1, 3: 1, 4: 1});
    });

    test('maps a range that does not start at its own number', () {
      // 使徒行傳 1:18-19 is filed under 18 in one file and the label
      // still spans both, so only 19 is explained.
      expect(rangeLabelHeads({18: '18-19'}), {19: 18});
    });

    test('names the head even when the label is filed elsewhere', () {
      // Nothing in the data guarantees the record holding a `20-21`
      // label is itself numbered 20. The head is the record's number,
      // because that is where the words actually are.
      expect(rangeLabelHeads({20: '20-21'}), {21: 20});
      expect(rangeLabelHeads({21: '20-21'}), {20: 21});
    });

    test('a plain number explains nothing', () {
      expect(rangeLabelHeads({1: '1', 2: '2', 3: ''}), isEmpty);
      expect(rangeLabelHeads(const {}), isEmpty);
    });

    test('ignores a label that is not a forward range', () {
      // Neither a descending pair nor a single-verse "range" says any
      // other reference was printed here.
      expect(rangeLabelHeads({5: '5-5'}), isEmpty);
      expect(rangeLabelHeads({5: '7-5'}), isEmpty);
      expect(rangeLabelHeads({5: '5a'}), isEmpty);
      expect(rangeLabelHeads({5: '5-'}), isEmpty);
      expect(rangeLabelHeads({5: '見上節'}), isEmpty);
    });

    test('never claims a verse that carries its own row', () {
      // 以弗所書 2:20 is labelled `20-21` while 2:21 also exists as its
      // own record — the one contradiction frozen in
      // test/biblexg_verse_boundary_test.dart. This function still
      // reports 21, and it is the CALLER that intersects with the
      // references actually absent. That division matters: if this
      // function suppressed the pair, a future asset where the row
      // really did vanish would go unexplained; if the caller did not
      // intersect, real scripture would be hidden behind a note.
      final heads = rangeLabelHeads({20: '20-21', 21: '21'});
      expect(heads, {21: 20});
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

    group('verses the edition does not have at all', () {
      test('a hole inside the chapter is reported', () {
        expect(absentVerseNumbers({1: 'a', 2: 'b', 4: 'd'}, 4), {3});
      });

      test('the extent comes from the other columns, not this one', () {
        // The Septuagint stops at Jeremiah 33:13 where the English
        // tradition runs to 26. Those thirteen are absences, not the
        // end of the chapter, and they are only visible because another
        // edition on screen has them.
        expect(absentVerseNumbers({1: 'a', 2: 'b'}, 5), {3, 4, 5});
      });

      test('an edition with none of the chapter reports nothing', () {
        // Otherwise a New-Testament-only edition would be told it is
        // "missing" all 1,533 verses of Genesis, one row each.
        expect(absentVerseNumbers({}, 31), isEmpty);
      });

      test('a complete chapter reports nothing', () {
        expect(absentVerseNumbers({1: 'a', 2: 'b', 3: 'c'}, 3), isEmpty);
      });

      test('a placeholder still counts as carried', () {
        // 見上節 and OMIT are records that exist. They already have
        // their own, more specific sentence; this rule must not claim
        // the reference is missing as well.
        expect(absentVerseNumbers({1: 'a', 2: '見上節', 3: 'OMIT'}, 3), isEmpty);
      });
    });

    test('an absence the critical text explains says more than one it does '
        'not', () {
      // The two kinds render in the same slot and differ only in what
      // they claim. `absent` makes the weakest true claim — our file has
      // no verse here. `notInCriticalText` adds the reason, and is only
      // reached when an independently derived table says the original
      // has no words at that reference. If the two sentences ever
      // collapse into one string the distinction is decorative.
      for (final locale in locales) {
        final vague = verseAbsenceNote(VerseAbsence.absent, locale);
        final explained =
            verseAbsenceNote(VerseAbsence.notInCriticalText, locale);
        expect(explained, isNot(equals(vague)), reason: locale);
        expect(explained.trim(), isNotEmpty, reason: locale);
      }
    });

    test('the critical-text sentence differs in script between the two '
        'Chinese locales', () {
      expect(
        verseAbsenceNote(VerseAbsence.notInCriticalText, 'zh-Hans'),
        isNot(equals(
            verseAbsenceNote(VerseAbsence.notInCriticalText, 'zh-Hant'))),
      );
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
