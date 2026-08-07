/// 2026-08 (SeekSparks): morphological search — the matcher.
///
/// BibleWorks' Graphical Search Engine lets you ask for "an aorist
/// imperative anywhere in Paul" without naming a single word, and its
/// help file (bwh17) treats that as the program's centre of gravity.
/// This is that query, minus the graphics: a set of feature constraints
/// evaluated against the codes already shipped in `assets/originals`.
///
/// Deliberately Flutter-free so the whole thing is testable without a
/// widget tester, and so the same object can be handed to an isolate
/// later if the corpus ever outgrows a synchronous scan.
///
/// The one rule that is easy to get wrong: a Semitic word is a STACK of
/// morphemes (`HC/Vqw3ms/Sp3fs` is conjunction + verb + suffix), and a
/// word matches iff at least ONE morpheme satisfies EVERY constraint at
/// once. Testing each constraint against the word as a whole would make
/// "feminine verb" match a masculine verb carrying a feminine suffix.
/// 32% of the Hebrew Bible has more than one morpheme, so this is not an
/// edge case.
library;

import 'morphology.dart';

/// A set of feature constraints. Values within a slot are alternatives
/// (BibleWorks writes these `[qp]`); slots are combined with AND.
///
/// An empty value set means "unconstrained", so callers can keep a slot
/// in the map while the user clears it without special-casing removal.
class MorphQuery {
  const MorphQuery({
    required this.scheme,
    this.aramaic = false,
    this.constraints = const <MorphSlot, Set<String>>{},
  });

  /// Seed a query from a word the reader clicked, pinning every feature
  /// of one morpheme. The expected workflow is to then loosen it — that
  /// is what BibleWorks' "add to command line" does, and starting from a
  /// real parse is far easier than building one from empty dropdowns.
  factory MorphQuery.fromWord(MorphWord word, {int? morphemeIndex}) {
    if (word.morphemes.isEmpty) return MorphQuery(scheme: word.scheme);
    final i = (morphemeIndex ?? word.headIndex).clamp(
      0,
      word.morphemes.length - 1,
    );
    final m = word.morphemes[i];
    return MorphQuery(
      scheme: word.scheme,
      aramaic: word.aramaic,
      constraints: {
        for (final e in m.slots.entries) e.key: {e.value},
      },
    );
  }

  final MorphScheme scheme;

  /// Only affects which labels and option lists are shown; matching
  /// compares raw code letters, which Hebrew and Aramaic share.
  final bool aramaic;

  final Map<MorphSlot, Set<String>> constraints;

  bool get isEmpty => constraints.values.every((v) => v.isEmpty);

  Set<String> valuesFor(MorphSlot slot) =>
      constraints[slot] ?? const <String>{};

  MorphQuery withSlot(MorphSlot slot, Set<String> values) => MorphQuery(
        scheme: scheme,
        aramaic: aramaic,
        constraints: {...constraints, slot: values},
      );

  MorphQuery toggled(MorphSlot slot, String value) {
    final next = {...valuesFor(slot)};
    if (!next.remove(value)) next.add(value);
    return withSlot(slot, next);
  }

  MorphQuery get cleared => MorphQuery(scheme: scheme, aramaic: aramaic);

  /// The index of the first morpheme satisfying every constraint, or -1.
  ///
  /// Returning the index rather than a bool is what lets the result list
  /// point at *which* part of a stacked Hebrew word answered the query;
  /// without it, a hit on `HC/Vqw3ms/Sp3fs` is unexplainable.
  int match(MorphWord word) {
    if (word.scheme != scheme) return -1;
    for (var i = 0; i < word.morphemes.length; i++) {
      if (_satisfies(word.morphemes[i])) return i;
    }
    return -1;
  }

  /// Every morpheme satisfying the query, in order.
  ///
  /// [match] returns the first, which is all a single-word search needs.
  /// A construction search needs them all: the morpheme that answers the
  /// query is also the morpheme whose gender and number an agreement test
  /// reads, and on a stacked Semitic word the first satisfying morpheme
  /// is not always the one that lets the construction agree.
  List<int> matchAll(MorphWord word) {
    if (word.scheme != scheme) return const <int>[];
    final out = <int>[];
    for (var i = 0; i < word.morphemes.length; i++) {
      if (_satisfies(word.morphemes[i])) out.add(i);
    }
    return out;
  }

  bool _satisfies(MorphMorpheme m) {
    for (final e in constraints.entries) {
      if (e.value.isEmpty) continue;
      final v = m.slots[e.key];
      if (v == null || !e.value.contains(v)) return false;
    }
    return true;
  }

  /// Which slots the query surface should offer, given the parts of
  /// speech currently selected. With no part of speech chosen it is the
  /// union over all of them, so the pane opens with everything visible
  /// and narrows as the user commits.
  List<MorphSlot> activeSlots() {
    final chosen = valuesFor(MorphSlot.pos);
    final poss = chosen.isNotEmpty
        ? chosen
        : morphPartsOfSpeech(scheme).toSet();
    final live = <MorphSlot>{};
    for (final p in poss) {
      live.addAll(morphSlotsFor(scheme, p));
    }
    return [
      for (final s in _slotOrder)
        if (live.contains(s)) s,
    ];
  }

  /// A one-line rendering of the query, for the results header.
  /// Returns null when nothing is constrained.
  String? describe(String locale) {
    final parts = <String>[];
    for (final slot in [MorphSlot.pos, ..._slotOrder]) {
      final vs = valuesFor(slot);
      if (vs.isEmpty) continue;
      final labels = [
        for (final v in vs)
          morphSlotLabel(scheme, _anyPos(), slot, v, locale,
                  aramaic: aramaic) ??
              v,
      ]..sort();
      parts.add(labels.join(' / '));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Subtype labels are per part of speech, so a description needs one;
  /// the first selected one is the only sensible choice, and when none is
  /// selected there is no subtype constraint to label either.
  String _anyPos() {
    final p = valuesFor(MorphSlot.pos);
    return p.isEmpty ? '' : (p.toList()..sort()).first;
  }
}

const _slotOrder = <MorphSlot>[
  MorphSlot.subtype,
  MorphSlot.stem,
  MorphSlot.conjugation,
  MorphSlot.tense,
  MorphSlot.voice,
  MorphSlot.mood,
  MorphSlot.person,
  MorphSlot.grammaticalCase,
  MorphSlot.gender,
  MorphSlot.number,
  MorphSlot.state,
  MorphSlot.degree,
];

/// Counts, in a single pass, how many words each *alternative* value
/// would match — the "23" next to "imperative" before you click it.
///
/// The trick is that a facet for slot S is not a separate query. A word
/// belongs in S's tally iff some morpheme of it fails at most S: fail
/// nothing and it is a current hit (and its own S value is the one to
/// count); fail only S and it is what you would get by switching S.
/// Anything failing two slots is invisible however you move S alone.
///
/// One pass, one comparison per constraint, no re-scan per candidate
/// value — which is what makes live counts affordable over a testament.
class MorphFacets {
  MorphFacets(this.query);

  final MorphQuery query;
  final Map<MorphSlot, Map<String, int>> _counts =
      <MorphSlot, Map<String, int>>{};
  int _hits = 0;

  /// Words matching the query as it stands.
  int get hits => _hits;

  int countOf(MorphSlot slot, String value) => _counts[slot]?[value] ?? 0;

  Map<String, int> forSlot(MorphSlot slot) =>
      _counts[slot] ?? const <String, int>{};

  void add(MorphWord word) {
    if (word.scheme != query.scheme) return;

    // Per word, not per morpheme: `HN.../Sp3ms` would otherwise count
    // "masculine" twice for one word and inflate every tally.
    final seen = <MorphSlot, Set<String>>{};
    var matched = false;

    for (final m in word.morphemes) {
      MorphSlot? onlyFailure;
      var failures = 0;
      for (final e in query.constraints.entries) {
        if (e.value.isEmpty) continue;
        final v = m.slots[e.key];
        if (v == null || !e.value.contains(v)) {
          failures++;
          if (failures > 1) break;
          onlyFailure = e.key;
        }
      }
      if (failures > 1) continue;

      if (failures == 0) {
        matched = true;
        for (final s in m.slots.entries) {
          (seen[s.key] ??= <String>{}).add(s.value);
        }
      } else {
        final v = m.slots[onlyFailure!];
        if (v != null) (seen[onlyFailure] ??= <String>{}).add(v);
      }
    }

    if (matched) _hits++;
    for (final e in seen.entries) {
      final tally = _counts[e.key] ??= <String, int>{};
      for (final v in e.value) {
        tally[v] = (tally[v] ?? 0) + 1;
      }
    }
  }
}
