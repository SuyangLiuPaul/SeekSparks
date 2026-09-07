/// The agreement engine — bwh17's "adjective agreeing in case, number
/// and gender with the noun two words back", which
/// `docs/PARITY-BACKLOG.md` §3.1 said "we cannot express at all" and
/// §3.2 named as the thing the Graphical Search Engine is waiting on:
/// *"the order is engine, then builder."*
///
/// The assertions that matter are the ones separating agreement from a
/// feature filter, and the ones about stacked Semitic words — those are
/// the two ways an implementation can look right and be wrong.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/utils/morph_construction.dart';
import 'package:seeksparks/utils/morph_query.dart';
import 'package:seeksparks/utils/morphology.dart';

OriginalWord w(String text, String morph, {String strongs = ''}) =>
    OriginalWord(text: text, strongs: strongs, morph: morph);

// Greek codes, as `assets/originals` writes them: two-letter part of
// speech then person/tense/voice/mood/case/number/gender/degree.
const nounNomSgMasc = 'N-----NSM-';
const nounNomSgFem = 'N-----NSF-';
const adjNomSgMasc = 'A-----NSM-';
const adjNomSgFem = 'A-----NSF-';
const adjAccSgMasc = 'A-----ASM-';

MorphQuery greek(String pos) =>
    MorphQuery(scheme: MorphScheme.greek, constraints: {
      MorphSlot.pos: {pos},
    });

void main() {
  group('sequence', () {
    test('two adjacent forms, in order', () {
      final words = [w('α', nounNomSgMasc), w('β', adjNomSgMasc)];
      final hit = findConstruction(
        MorphConstruction(terms: [
          ConstructionTerm(query: greek('N-')),
          ConstructionTerm(query: greek('A-')),
        ]),
        words,
      );
      expect(hit, isNotNull);
      expect(hit!.positions, [0, 1]);
    });

    test('order is not a set — the reverse is a different query', () {
      final words = [w('α', nounNomSgMasc), w('β', adjNomSgMasc)];
      final hit = findConstruction(
        MorphConstruction(terms: [
          ConstructionTerm(query: greek('A-')),
          ConstructionTerm(query: greek('N-')),
        ]),
        words,
      );
      expect(hit, isNull);
    });

    test('a gap admits words between, up to its width', () {
      final words = [
        w('α', nounNomSgMasc),
        w('x', 'C---------'),
        w('y', 'C---------'),
        w('β', adjNomSgMasc),
      ];
      MorphConstruction c(int max) => MorphConstruction(terms: [
            ConstructionTerm(query: greek('N-')),
            ConstructionTerm(query: greek('A-'), gapMax: max),
          ]);
      expect(findConstruction(c(1), words), isNull,
          reason: 'two words stand between them');
      expect(findConstruction(c(2), words)?.positions, [0, 3]);
    });

    test('a verse shorter than the construction is refused outright', () {
      expect(
        findConstruction(
          MorphConstruction(terms: [
            ConstructionTerm(query: greek('N-')),
            ConstructionTerm(query: greek('A-')),
          ]),
          [w('α', nounNomSgMasc)],
        ),
        isNull,
      );
    });
  });

  group('agreement is not a feature filter', () {
    // The distinction the whole engine exists for. "Same gender" is not
    // "masculine", and running the query once per gender is a different
    // question that also returns the disagreeing pairs.
    final agreeGender = MorphConstruction(
      terms: [
        ConstructionTerm(query: greek('N-')),
        ConstructionTerm(query: greek('A-')),
      ],
      agreements: const [
        AgreementRule(a: 0, b: 1, features: {MorphSlot.gender}),
      ],
    );

    test('a matching pair is found', () {
      expect(
        findConstruction(
            agreeGender, [w('α', nounNomSgMasc), w('β', adjNomSgMasc)]),
        isNotNull,
      );
    });

    test('a pair that disagrees is refused, though both terms match', () {
      // Without the rule this same verse is a hit — which is the point.
      final words = [w('α', nounNomSgMasc), w('β', adjNomSgFem)];
      expect(
        findConstruction(
            MorphConstruction(terms: agreeGender.terms), words),
        isNotNull,
        reason: 'both terms match on their own',
      );
      expect(findConstruction(agreeGender, words), isNull);
    });

    test('it agrees on the VALUE, whatever the value is', () {
      // Feminine + feminine holds under the same rule that held for
      // masculine + masculine. A rule that had quietly been implemented
      // as "= M" would pass the test above and fail this one.
      expect(
        findConstruction(
            agreeGender, [w('α', nounNomSgFem), w('β', adjNomSgFem)]),
        isNotNull,
      );
    });

    test('several features must ALL hold', () {
      final agreeCaseAndGender = MorphConstruction(
        terms: agreeGender.terms,
        agreements: const [
          AgreementRule(a: 0, b: 1, features: {
            MorphSlot.gender,
            MorphSlot.grammaticalCase,
          }),
        ],
      );
      // Gender agrees, case does not.
      expect(
        findConstruction(agreeCaseAndGender,
            [w('α', nounNomSgMasc), w('β', adjAccSgMasc)]),
        isNull,
      );
      expect(
        findConstruction(agreeCaseAndGender,
            [w('α', nounNomSgMasc), w('β', adjNomSgMasc)]),
        isNotNull,
      );
    });

    test('a feature the code does not state cannot be shown to agree', () {
      // Two absences are not a match. Treating them as one makes every
      // uninflected pair "agree in gender", which looks like the feature
      // working and silently doubles its hits.
      final words = [w('α', 'C---------'), w('β', 'C---------')];
      expect(
        findConstruction(
          MorphConstruction(
            terms: [
              ConstructionTerm(query: greek('C-')),
              ConstructionTerm(query: greek('C-')),
            ],
            agreements: const [
              AgreementRule(a: 0, b: 1, features: {MorphSlot.gender}),
            ],
          ),
          words,
        ),
        isNull,
      );
    });

    test('it backtracks rather than taking the first match and giving up',
        () {
      // Two candidates for the second term; only the later one agrees. A
      // first-match-wins walk reports "no" here, and a reader has no way
      // to see why.
      final words = [
        w('α', nounNomSgMasc),
        w('β', adjNomSgFem),
        w('γ', adjNomSgMasc),
      ];
      final hit = findConstruction(
        MorphConstruction(
          terms: [
            ConstructionTerm(query: greek('N-')),
            ConstructionTerm(query: greek('A-'), gapMax: 2),
          ],
          agreements: const [
            AgreementRule(a: 0, b: 1, features: {MorphSlot.gender}),
          ],
        ),
        words,
      );
      expect(hit, isNotNull);
      expect(hit!.positions, [0, 2]);
    });
  });

  group('lemma agreement', () {
    test('the same root twice — the figura etymologica', () {
      // מוֹת תָּמוּת, "dying you shall die": an infinitive absolute and a
      // finite verb of the same root. Found without naming the root,
      // which is the point — there are ~1,400 of these in the Hebrew
      // Bible and they do not share a lemma with each other.
      final words = [
        w('מוֹת', 'HVqa', strongs: 'H4191'),
        w('תָּמוּת', 'HVqi2ms', strongs: 'H4191'),
      ];
      final semitic = MorphQuery(scheme: MorphScheme.semitic, constraints: {
        MorphSlot.pos: {'V'},
      });
      expect(
        findConstruction(
          MorphConstruction(
            terms: [
              ConstructionTerm(query: semitic),
              ConstructionTerm(query: semitic),
            ],
            agreements: const [AgreementRule(a: 0, b: 1, lemma: true)],
          ),
          words,
        ),
        isNotNull,
      );
    });

    test('two different roots are refused', () {
      final words = [
        w('מוֹת', 'HVqa', strongs: 'H4191'),
        w('תֵּלֵךְ', 'HVqi2ms', strongs: 'H1980'),
      ];
      final semitic = MorphQuery(scheme: MorphScheme.semitic, constraints: {
        MorphSlot.pos: {'V'},
      });
      expect(
        findConstruction(
          MorphConstruction(
            terms: [
              ConstructionTerm(query: semitic),
              ConstructionTerm(query: semitic),
            ],
            agreements: const [AgreementRule(a: 0, b: 1, lemma: true)],
          ),
          words,
        ),
        isNull,
      );
    });

    test('a missing Strong\'s number is not agreement with another one',
        () {
      final semitic = MorphQuery(scheme: MorphScheme.semitic, constraints: {
        MorphSlot.pos: {'V'},
      });
      expect(
        findConstruction(
          MorphConstruction(
            terms: [
              ConstructionTerm(query: semitic),
              ConstructionTerm(query: semitic),
            ],
            agreements: const [AgreementRule(a: 0, b: 1, lemma: true)],
          ),
          [w('a', 'HVqa'), w('b', 'HVqi2ms')],
        ),
        isNull,
      );
    });
  });

  group('stacked Semitic words — where a naive engine is wrong', () {
    // `HC/Vqw3ms/Sp3fs` is conjunction + verb + suffix. The verb is
    // masculine singular and the suffix is FEMININE singular, so which
    // morpheme the agreement is read off decides the answer. 32% of the
    // Hebrew Bible has more than one morpheme.
    const stacked = 'HC/Vqw3ms/Sp3fs';

    test('a term matches a morpheme, not a word', () {
      final parsed = parseMorphology(stacked)!;
      expect(parsed.morphemes.length, 3);
      final verb = MorphQuery(scheme: MorphScheme.semitic, constraints: {
        MorphSlot.pos: {'V'},
      });
      expect(verb.matchAll(parsed), [1]);
    });

    test('agreement reads the morpheme that answered, not the word', () {
      // The noun is feminine. It agrees with the SUFFIX of the stacked
      // word, not with its verb — and the engine has to pick the suffix
      // to see it.
      final words = [w('א', 'HNcfsa'), w('ב', stacked)];
      final noun = MorphQuery(scheme: MorphScheme.semitic, constraints: {
        MorphSlot.pos: {'N'},
      });
      final anything = MorphQuery(scheme: MorphScheme.semitic);
      final hit = findConstruction(
        MorphConstruction(
          terms: [
            ConstructionTerm(query: noun),
            ConstructionTerm(query: anything),
          ],
          agreements: const [
            AgreementRule(a: 0, b: 1, features: {MorphSlot.gender}),
          ],
        ),
        words,
      );
      expect(hit, isNotNull,
          reason: 'the feminine suffix agrees; a word-level read would '
              'have looked at the masculine verb and said no');
      expect(hit!.morphemes[1], 2, reason: 'the suffix, not the verb');
    });

    test('and it still says no when NO morpheme agrees', () {
      // The same shape against a stack that has no feminine morpheme at
      // all, so the refusal is a real disagreement rather than an
      // accident of which morpheme was tried first.
      final words = [w('א', 'HNcfsa'), w('ב', 'HC/Vqw3ms')];
      final noun = MorphQuery(scheme: MorphScheme.semitic, constraints: {
        MorphSlot.pos: {'N'},
      });
      final anything = MorphQuery(scheme: MorphScheme.semitic);
      expect(
        findConstruction(
          MorphConstruction(
            terms: [
              ConstructionTerm(query: noun),
              ConstructionTerm(query: anything),
            ],
            agreements: const [
              AgreementRule(a: 0, b: 1, features: {MorphSlot.gender}),
            ],
          ),
          words,
        ),
        isNull,
      );
    });
  });

  group('what the reader is told', () {
    test('every agreement string exists in all three locales', () {
      for (final k in const [
        'morphAgreementSlot',
        'morphAgreeingIn',
        'morphAgreeLemma',
        'morphGapAdjacent',
        'morphGapWithin',
      ]) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          final v = uiStrings[k]?[locale];
          expect(v, isNotNull, reason: '$k [$locale]');
          expect((v as String).trim(), isNotEmpty, reason: '$k [$locale]');
        }
      }
    });

    test('the distance chip carries its placeholder everywhere', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(uiStrings['morphGapWithin']![locale]!, contains('{n}'),
            reason: locale);
      }
    });

    test('every feature the pane offers has a name', () {
      // The pane offers gender, number, case (Greek) and person. A slot
      // with no name would print a Dart identifier next to a Hebrew word.
      for (final f in const [
        MorphSlot.gender,
        MorphSlot.number,
        MorphSlot.grammaticalCase,
        MorphSlot.person,
      ]) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(morphSlotName(f, locale).trim(), isNotEmpty,
              reason: '$f [$locale]');
        }
      }
    });
  });

  group('the pane may only offer an agreement both terms can carry', () {
    // Found on the screen, not in the suite. With `particle` chosen the
    // pane offered `Gender`; choosing it returned "no word in this range
    // has that form" over the whole Hebrew Bible — correctly, because a
    // particle carries no gender and the engine refuses to call two
    // absences an agreement. A chip that can only ever return nothing is
    // a promise the app cannot keep.
    //
    // The pane intersects `morphSlotsFor` across both terms; this pins
    // the fact the intersection relies on, so a table edit that gave
    // particles a gender would fail here rather than reappear as an
    // empty result nobody can explain.
    test('a Hebrew particle carries no gender, number or person', () {
      final slots = morphSlotsFor(MorphScheme.semitic, 'T').toSet();
      expect(slots.contains(MorphSlot.gender), isFalse);
      expect(slots.contains(MorphSlot.number), isFalse);
    });

    test('a Hebrew noun carries gender and number', () {
      final slots = morphSlotsFor(MorphScheme.semitic, 'N').toSet();
      expect(slots, contains(MorphSlot.gender));
      expect(slots, contains(MorphSlot.number));
    });

    test('case is Greek-only, so it can never be offered on Hebrew', () {
      for (final p in morphPartsOfSpeech(MorphScheme.semitic)) {
        expect(morphSlotsFor(MorphScheme.semitic, p),
            isNot(contains(MorphSlot.grammaticalCase)),
            reason: p);
      }
      final greekCarriers = [
        for (final p in morphPartsOfSpeech(MorphScheme.greek))
          if (morphSlotsFor(MorphScheme.greek, p)
              .contains(MorphSlot.grammaticalCase))
            p,
      ];
      expect(greekCarriers, isNotEmpty,
          reason: 'if nothing in Greek took a case the chip would be dead '
              'everywhere and this guard would prove nothing');
    });

    test('and the engine is what makes the offer matter', () {
      // The rule the chip would otherwise promise to apply: a particle
      // and a noun cannot be shown to agree in gender, because the
      // particle states none.
      final particle = MorphQuery(scheme: MorphScheme.semitic, constraints: {
        MorphSlot.pos: {'T'},
      });
      final noun = MorphQuery(scheme: MorphScheme.semitic, constraints: {
        MorphSlot.pos: {'N'},
      });
      expect(
        findConstruction(
          MorphConstruction(
            terms: [
              ConstructionTerm(query: particle),
              ConstructionTerm(query: noun),
            ],
            agreements: const [
              AgreementRule(a: 0, b: 1, features: {MorphSlot.gender}),
            ],
          ),
          [w('א', 'HTd'), w('ב', 'HNcmsa')],
        ),
        isNull,
      );
      // Without the impossible rule, the same pair is a hit.
      expect(
        findConstruction(
          MorphConstruction(terms: [
            ConstructionTerm(query: particle),
            ConstructionTerm(query: noun),
          ]),
          [w('א', 'HTd'), w('ב', 'HNcmsa')],
        ),
        isNotNull,
      );
    });
  });

  group('shape', () {
    test('one term and no agreement is not a construction', () {
      expect(
        MorphConstruction(terms: [ConstructionTerm(query: greek('N-'))])
            .isTrivial,
        isTrue,
      );
    });

    test('maxSpan counts the terms and every gap', () {
      final c = MorphConstruction(terms: [
        ConstructionTerm(query: greek('N-')),
        ConstructionTerm(query: greek('A-'), gapMax: 2),
        ConstructionTerm(query: greek('V-'), gapMax: 3),
      ]);
      expect(c.maxSpan, 8);
    });
  });
}
