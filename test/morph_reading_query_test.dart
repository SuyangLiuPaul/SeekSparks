/// bwh17's Qere/Kethib **search codes** — asking for one Masoretic
/// reading inside a query, rather than as a mode the whole session sits
/// in. `docs/PARITY-BACKLOG.md` §3.1's remaining Qere/Kethib gap.
///
/// The distinction this file exists to hold is one word: bwh29's two
/// settings **exclude**, and these codes **select**. They therefore
/// disagree about the 436,312 unmarked words, and getting that backwards
/// would make "find me the Qere" return the whole Hebrew Bible.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/ketiv_qere.dart';
import 'package:seeksparks/utils/morph_query.dart';
import 'package:seeksparks/utils/morphology.dart';

void main() {
  const semitic = MorphQuery(scheme: MorphScheme.semitic);

  group('a query that names no reading takes them all', () {
    test('including the unmarked words, which are almost all of them', () {
      for (final kq in const [null, 'k', 'q', 'kx', 'qx']) {
        expect(semitic.admitsReading(kq), isTrue, reason: '$kq');
      }
    });

    test('and it is still an empty query', () {
      // `isEmpty` gates whether the pane runs a search at all. A reading
      // constraint has to count, or choosing one alone would do nothing.
      expect(semitic.isEmpty, isTrue);
      expect(semitic.withReadings({'q'}).isEmpty, isFalse);
    });
  });

  group('a query that names one selects, it does not merely exclude', () {
    test('an ordinary word is NOT a Qere', () {
      // The opposite of `KetivQereSearchScope`, deliberately. Asking for
      // the Qere must not return every word that simply is not a Ketiv.
      final qere = semitic.withReadings({'q'});
      expect(qere.admitsReading(null), isFalse);
      expect(qere.admitsReading('k'), isFalse);
      expect(qere.admitsReading('q'), isTrue);
    });

    test('the settings still admit that same ordinary word', () {
      // Both halves stated together, because the pair is the point.
      const excludeKetiv = KetivQereSearchScope(excludeKetiv: true);
      expect(excludeKetiv.admits(null), isTrue,
          reason: 'a switch that could empty the Hebrew Bible is a switch '
              'nobody wants');
      expect(excludeKetiv.admits('k'), isFalse);
    });

    test('both readings named is not the same as none named', () {
      // Naming both still excludes the unmarked words — the reader has
      // asked for the apparatus, which is 2,509 words, not for the text.
      final both = semitic.withReadings({'k', 'q'});
      expect(both.admitsReading(null), isFalse);
      expect(both.admitsReading('k'), isTrue);
      expect(both.admitsReading('q'), isTrue);
    });
  });

  group('the two rare roles go with their own kind', () {
    test('Ketiv velo Qere is a Ketiv, Qere velo Ketiv is a Qere', () {
      // Six words and eight words. The display layer has printed `kx` as
      // K and `qx` as Q since the roles landed, and a reader asking for
      // the Ketiv wants the six written and marked not to be read — not
      // a fifth category they have never been shown.
      final ketiv = semitic.withReadings({'k'});
      expect(ketiv.admitsReading('kx'), isTrue);
      expect(ketiv.admitsReading('qx'), isFalse);
      final qere = semitic.withReadings({'q'});
      expect(qere.admitsReading('qx'), isTrue);
      expect(qere.admitsReading('kx'), isFalse);
    });

    test('and they agree with the marks the reader already sees', () {
      // The one place this could drift: if `ketivQereMark` ever said
      // something different, the pane would filter on one rule and print
      // another.
      for (final kq in const ['k', 'kx']) {
        expect(ketivQereMark(kq), 'K');
        expect(semitic.withReadings({'k'}).admitsReading(kq), isTrue);
      }
      for (final kq in const ['q', 'qx']) {
        expect(ketivQereMark(kq), 'Q');
        expect(semitic.withReadings({'q'}).admitsReading(kq), isTrue);
      }
    });
  });

  group('it survives the rest of the query being edited', () {
    test('changing a slot keeps the reading', () {
      final q = semitic
          .withReadings({'q'})
          .withSlot(MorphSlot.pos, {'V'});
      expect(q.readings, {'q'});
      expect(q.valuesFor(MorphSlot.pos), {'V'});
      expect(q.toggled(MorphSlot.pos, 'N').readings, {'q'},
          reason: 'toggling a feature must not silently drop the reading');
    });

    test('toggling a reading twice returns to unconstrained', () {
      expect(semitic.toggledReading('k').readings, {'k'});
      expect(semitic.toggledReading('k').toggledReading('k').readings,
          isEmpty);
    });

    test('clearing the query clears it too', () {
      expect(semitic.withReadings({'k'}).cleared.readings, isEmpty);
    });
  });

  test('the row has a label in all three locales', () {
    for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
      final v = uiStrings['morphReadingSlot']?[locale];
      expect(v, isNotNull, reason: locale);
      expect((v as String).trim(), isNotEmpty, reason: locale);
      // And the chips themselves are named by the existing helper, so
      // the row cannot end up labelled in one language and filled in
      // another.
      expect(ketivQereLabel('k', locale), isNotNull);
      expect(ketivQereLabel('q', locale), isNotNull);
    }
  });
}
