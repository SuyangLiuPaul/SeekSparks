/// Construction search — the agreement engine bwh17 is famous for, and
/// the thing `docs/PARITY-BACKLOG.md` §3.2 is explicitly waiting on.
///
/// §3.1's entry named the gap in BibleWorks' own words: *"an adjective
/// agreeing in case, number and gender with the noun two words back" is
/// the class of query BibleWorks is famous for and we cannot express it
/// at all.* §3.2 then rejected the Graphical Search Engine **for now**,
/// with the order stated: *"building the GSE first would be building a
/// steering wheel for an engine that does not turn. The order is engine,
/// then builder."*
///
/// This is the engine. It answers three things a single [MorphQuery]
/// cannot:
///
///   * **Sequence** — two or more forms, in order, within a distance.
///   * **Morphological agreement** — named features that must hold the
///     SAME value across two of those forms, whatever that value is.
///     This is the part a feature filter cannot express: "same gender"
///     is not "masculine", and asking for every gender in turn is a
///     different query that also returns the disagreeing pairs.
///   * **Lemma agreement** — the same Strong's number twice, which is
///     how you find a figura etymologica (`מוֹת תָּמוּת`, "dying you
///     shall die") without naming the root.
///
/// ## The rule that makes it correct on Semitic text
///
/// A Semitic word is a STACK of morphemes — `HC/Vqw3ms/Sp3fs` is
/// conjunction + verb + suffix — and 32% of the Hebrew Bible has more
/// than one. So a term does not match "a word"; it matches a *morpheme
/// of* a word, and the agreement must be read off **that** morpheme.
/// The suffix in the example above is feminine singular while the verb
/// is masculine singular, and a gender agreement that read the word as a
/// whole would answer with whichever it happened to look at first.
///
/// That is why this backtracks over morphemes and not only over
/// positions, and why [MorphQuery.matchAll] exists — its own doc says
/// so: *"the morpheme that answers the query is also the morpheme whose
/// gender and number an agreement test reads, and on a stacked Semitic
/// word the first satisfying morpheme is not always the one that lets
/// the construction agree."* A first-match-wins walk finds Genesis 1:1
/// and misses the verse next door for no reason the reader could ever
/// see.
///
/// ## What this deliberately does not do
///
/// No **context dependency** in bwh17's full sense — "this word's
/// referent is that word's subject" needs a syntactic parse of the
/// original, which is a dataset this repo does not have and cannot
/// derive. Named here rather than left as an absence, because the
/// difference between agreement (morphological, and answerable from the
/// codes we ship) and dependency (syntactic, and not) is exactly the
/// line an honest verdict has to draw.
///
/// Flutter-free: this decides what matches. Running it over the corpus
/// is `MorphSearchService`'s job.
library;

import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/utils/morph_query.dart';
import 'package:seeksparks/utils/morphology.dart';

/// One form in a construction, and how far it may sit from the previous.
///
/// [gapMin] / [gapMax] count the words BETWEEN this term and the one
/// before it — the same convention as the command line's `*n` phrase
/// gap, so a reader who knows one knows the other. Adjacent is `(0, 0)`.
/// The first term's gap is ignored.
class ConstructionTerm {
  const ConstructionTerm({
    required this.query,
    this.gapMin = 0,
    this.gapMax = 0,
  });

  final MorphQuery query;
  final int gapMin;
  final int gapMax;
}

/// Features that must hold the same value across two terms.
///
/// [features] is empty for a pure lemma rule, and [lemma] false for a
/// pure morphological one; both may be set.
class AgreementRule {
  const AgreementRule({
    required this.a,
    required this.b,
    this.features = const <MorphSlot>{},
    this.lemma = false,
  });

  /// Indices into [MorphConstruction.terms].
  final int a;
  final int b;

  /// Slots that must be EQUAL — not equal to a named value. bwh17's
  /// agreement windows are exactly this: case, number, gender, person.
  final Set<MorphSlot> features;

  /// The same Strong's number in both positions.
  final bool lemma;

  bool get isEmpty => features.isEmpty && !lemma;
}

/// An ordered set of forms plus the agreements that must hold between
/// them.
class MorphConstruction {
  const MorphConstruction({
    required this.terms,
    this.agreements = const <AgreementRule>[],
  });

  final List<ConstructionTerm> terms;
  final List<AgreementRule> agreements;

  /// A construction of one term with no agreement is just a
  /// [MorphQuery]; callers use the cheaper path for that.
  bool get isTrivial => terms.length < 2 && agreements.isEmpty;

  /// The widest span in words this construction can occupy, so a caller
  /// can stop scanning a verse that is too short. Counts the terms
  /// themselves plus every maximum gap.
  int get maxSpan {
    var span = terms.length;
    for (var i = 1; i < terms.length; i++) {
      span += terms[i].gapMax;
    }
    return span;
  }
}

/// Where each term landed: the word index in the verse, and WHICH
/// morpheme of that word answered.
///
/// The morpheme is carried because it is the only thing that makes a hit
/// explicable on a stacked Semitic word — and because the agreement was
/// read off it, so a reader checking our work needs the same one.
class ConstructionHit {
  const ConstructionHit({required this.positions, required this.morphemes});

  /// Word index per term, ascending.
  final List<int> positions;

  /// Morpheme index per term, parallel to [positions].
  final List<int> morphemes;
}

/// The first placement of [construction] in [words] that satisfies every
/// term and every agreement, or null.
///
/// Returns the FIRST rather than all of them: a verse either contains the
/// construction or does not, and the result list needs one place to point
/// at. Backtracking is over (position, morpheme) pairs, so a verse where
/// the construction holds only on the second morpheme of a stacked word
/// is found rather than missed.
ConstructionHit? findConstruction(
  MorphConstruction construction,
  List<OriginalWord> words, {
  MorphWord? Function(String? code)? parse,
}) {
  final terms = construction.terms;
  if (terms.isEmpty) return null;
  final parseFn = parse ?? parseMorphology;
  if (words.length < terms.length) return null;

  // Parsed once per word, not once per placement: a 40-word verse with
  // three terms is ~60,000 placements and re-parsing inside that loop is
  // the difference between a scan and a hang.
  final parsed = <MorphWord?>[
    for (final w in words) parseFn(w.morph),
  ];

  final positions = List<int>.filled(terms.length, -1);
  final morphemes = List<int>.filled(terms.length, -1);

  bool agreementsHold(int upTo) {
    for (final rule in construction.agreements) {
      if (rule.a > upTo || rule.b > upTo) continue;
      if (rule.isEmpty) continue;
      final wa = parsed[positions[rule.a]];
      final wb = parsed[positions[rule.b]];
      if (wa == null || wb == null) return false;
      final ma = wa.morphemes[morphemes[rule.a]];
      final mb = wb.morphemes[morphemes[rule.b]];
      for (final f in rule.features) {
        final va = ma.slots[f];
        final vb = mb.slots[f];
        // A feature the code does not state cannot be shown to agree.
        // Treating two absences as a match would make every uninflected
        // pair "agree in gender", which is the failure mode that makes
        // an agreement search look like it works and quietly doubles
        // its hits.
        if (va == null || vb == null || va != vb) return false;
      }
      if (rule.lemma) {
        final sa = words[positions[rule.a]].strongs;
        final sb = words[positions[rule.b]].strongs;
        if (sa.isEmpty || sb.isEmpty || sa != sb) return false;
      }
    }
    return true;
  }

  bool place(int ti, int from) {
    if (ti == terms.length) return true;
    final term = terms[ti];
    final lo = ti == 0 ? from : from + term.gapMin;
    final hi = ti == 0 ? words.length - 1 : from + term.gapMax;
    for (var i = lo; i <= hi && i < words.length; i++) {
      final w = parsed[i];
      if (w == null) continue;
      for (final m in term.query.matchAll(w)) {
        positions[ti] = i;
        morphemes[ti] = m;
        if (!agreementsHold(ti)) continue;
        if (place(ti + 1, i + 1)) return true;
      }
      positions[ti] = -1;
      morphemes[ti] = -1;
    }
    return false;
  }

  if (!place(0, 0)) return null;
  return ConstructionHit(
    positions: List.unmodifiable(positions),
    morphemes: List.unmodifiable(morphemes),
  );
}
