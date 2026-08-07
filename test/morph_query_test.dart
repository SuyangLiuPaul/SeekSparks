import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/morph_query.dart';
import 'package:seeksparks/utils/morphology.dart';

const _gk = MorphScheme.greek;
const _sem = MorphScheme.semitic;

MorphWord _w(String code) => parseMorphology(code)!;

void main() {
  group('a word matches iff ONE morpheme satisfies EVERY constraint', () {
    // "and you (m.pl.) shall do it (f.sg.)" — a masculine imperative
    // carrying a feminine object suffix.
    final mixed = _w('HC/Vqv2mp/Sp3fs');

    test('constraints are not spread across morphemes', () {
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
        MorphSlot.gender: {'f'},
      });
      // The verb is masculine and the feminine morpheme is not a verb.
      expect(q.match(mixed), -1);
    });

    test('the satisfying morpheme is identified, not just found', () {
      const verb = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
        MorphSlot.gender: {'m'},
      });
      expect(verb.match(mixed), 1);

      const suffix = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'S'},
        MorphSlot.gender: {'f'},
      });
      expect(suffix.match(mixed), 2);
    });

    test('the whole code is not treated as one string', () {
      // A prefixed noun is still a noun; matching must see past the
      // conjunction and the article that precede it.
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'N'},
        MorphSlot.state: {'a'},
      });
      expect(q.match(_w('HC/Td/Ncmpa')), 2);
    });
  });

  group('constraint semantics', () {
    test('values within a slot are alternatives', () {
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
        MorphSlot.stem: {'q', 'p'},
      });
      expect(q.match(_w('HVqp3ms')), 0);
      expect(q.match(_w('HVpp3ms')), 0);
      expect(q.match(_w('HVhp3ms')), -1);
    });

    test('an empty value set is unconstrained, not unsatisfiable', () {
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
        MorphSlot.stem: <String>{},
      });
      expect(q.isEmpty, isFalse);
      expect(q.match(_w('HVhp3ms')), 0);
    });

    test('a slot the morpheme does not carry never matches', () {
      // Greek nouns have no mood; asking for one must exclude them
      // rather than ignoring the constraint.
      const q = MorphQuery(scheme: _gk, constraints: {
        MorphSlot.mood: {'D'},
      });
      expect(q.match(_w('N-----NSM-')), -1);
      expect(q.match(_w('V-2AAD-P--')), 0);
    });

    test('a query only matches its own scheme', () {
      // Both schemes write a verb, and both write 3rd person singular.
      const q = MorphQuery(scheme: _gk, constraints: {
        MorphSlot.person: {'3'},
      });
      expect(q.match(_w('HVqp3ms')), -1);
      expect(q.match(_w('V-3AAI-S--')), 0);
    });

    test('an empty query matches anything of its scheme', () {
      const q = MorphQuery(scheme: _sem);
      expect(q.isEmpty, isTrue);
      expect(q.match(_w('HC/Td/Ncmpa')), 0);
    });
  });

  group('seeding from a clicked word', () {
    test('pins the head morpheme, not the first', () {
      // The reader clicked a prefixed noun; the query should be about
      // the noun, not about the preposition glued to its front.
      final q = MorphQuery.fromWord(_w('HR/Ncfsa'));
      expect(q.valuesFor(MorphSlot.pos), {'N'});
      expect(q.valuesFor(MorphSlot.state), {'a'});
      expect(q.match(_w('HNcfsa')), 0);
    });

    test('carries the Aramaic flag so labels stay right', () {
      final q = MorphQuery.fromWord(_w('AVqp3ms'));
      expect(q.aramaic, isTrue);
      expect(q.describe('en'), contains('Peal'));
    });

    test('an explicit morpheme index overrides the head', () {
      final q = MorphQuery.fromWord(_w('HR/Ncfsa'), morphemeIndex: 0);
      expect(q.valuesFor(MorphSlot.pos), {'R'});
    });
  });

  group('editing', () {
    test('toggling adds then removes', () {
      const q = MorphQuery(scheme: _sem);
      final a = q.toggled(MorphSlot.pos, 'V');
      expect(a.valuesFor(MorphSlot.pos), {'V'});
      expect(a.toggled(MorphSlot.pos, 'V').valuesFor(MorphSlot.pos), isEmpty);
    });

    test('clearing keeps the scheme', () {
      final q = MorphQuery.fromWord(_w('AVqp3ms')).cleared;
      expect(q.isEmpty, isTrue);
      expect(q.scheme, _sem);
      expect(q.aramaic, isTrue);
    });
  });

  group('the slots offered', () {
    test('narrow once a part of speech is chosen', () {
      const any = MorphQuery(scheme: _sem);
      expect(any.activeSlots(), contains(MorphSlot.stem));

      final noun = any.withSlot(MorphSlot.pos, {'N'});
      expect(noun.activeSlots(), isNot(contains(MorphSlot.stem)));
      expect(noun.activeSlots(), contains(MorphSlot.state));
    });

    test('are the union when several parts of speech are chosen', () {
      const q = MorphQuery(scheme: _sem);
      final both = q.withSlot(MorphSlot.pos, {'N', 'V'});
      expect(both.activeSlots(), contains(MorphSlot.stem));
      expect(both.activeSlots(), contains(MorphSlot.subtype));
    });

    test('describe reads as a parse line, or null when empty', () {
      expect(const MorphQuery(scheme: _gk).describe('en'), isNull);
      const q = MorphQuery(scheme: _gk, constraints: {
        MorphSlot.pos: {'V-'},
        MorphSlot.tense: {'A'},
        MorphSlot.mood: {'D'},
      });
      expect(q.describe('en'), 'verb · aorist · imperative');
    });
  });

  group('facet counts', () {
    // Six words: three Qal perfects, two Qal imperfects, one Piel
    // perfect, plus a Greek word that must be ignored entirely.
    final corpus = [
      _w('HVqp3ms'),
      _w('HVqp3fs'),
      _w('HVqp1cs'),
      _w('HVqi3ms'),
      _w('HVqi3fs'),
      _w('HVpp3ms'),
      _w('V-3AAI-S--'),
    ];

    MorphFacets count(MorphQuery q) {
      final f = MorphFacets(q);
      for (final w in corpus) {
        f.add(w);
      }
      return f;
    }

    test('hits are the words matching as the query stands', () {
      final f = count(const MorphQuery(scheme: _sem, constraints: {
        MorphSlot.stem: {'q'},
        MorphSlot.conjugation: {'p'},
      }));
      expect(f.hits, 3);
    });

    test('a slot counts what you would get by changing only that slot',
        () {
      final f = count(const MorphQuery(scheme: _sem, constraints: {
        MorphSlot.stem: {'q'},
        MorphSlot.conjugation: {'p'},
      }));
      // Holding stem=q: 3 perfects and 2 imperfects.
      expect(f.countOf(MorphSlot.conjugation, 'p'), 3);
      expect(f.countOf(MorphSlot.conjugation, 'i'), 2);
      // Holding conjugation=p: 3 Qal and 1 Piel.
      expect(f.countOf(MorphSlot.stem, 'q'), 3);
      expect(f.countOf(MorphSlot.stem, 'p'), 1);
    });

    test('an unconstrained slot counts within the current hits', () {
      final f = count(const MorphQuery(scheme: _sem, constraints: {
        MorphSlot.stem: {'q'},
        MorphSlot.conjugation: {'p'},
      }));
      expect(f.countOf(MorphSlot.gender, 'm'), 1);
      expect(f.countOf(MorphSlot.gender, 'f'), 1);
      expect(f.countOf(MorphSlot.gender, 'c'), 1);
    });

    test('the other scheme is not counted', () {
      final f = count(const MorphQuery(scheme: _sem));
      expect(f.hits, 6);
    });

    test('a word is counted once even when two morphemes agree', () {
      // Verb and suffix are both 3rd person; "3rd person" is one word.
      final f = MorphFacets(const MorphQuery(scheme: _sem))
        ..add(_w('HVqp3ms/Sp3ms'));
      expect(f.countOf(MorphSlot.person, '3'), 1);
    });
  });
}
