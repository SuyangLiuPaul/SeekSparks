// 2026-09-02 (#295): an empty single-Strong's-number result must say WHICH
// kind of empty it is.
//
// The concordance never carries an empty entry — 0 of 14,040 entries have
// an empty `r` — so a null lookup is a sufficient signal for "absent from
// the corpus" and no lexicon load is needed to word this.
//
// The ceilings below are MEASURED off the two lexicons this app ships:
// `assets/strongs/greek.json` tops out at G5624 (5,523 entries, 101
// unfilled numbers below the ceiling) and `assets/strongs/hebrew.json` at
// H8674 (8,674 entries, no gaps).
//
// Deliberately NOT `kMaxGreekStrongs`/`kMaxHebrewStrongs` from
// `strongs_boolean_search.dart` (5700/8700). Those two are loose on
// purpose — their own comment says they exist "to stop plain text like
// `H1 will` masquerading as an expression, not to adjudicate what a real
// Strong's number is". Here we ARE adjudicating, so the number has to be
// the real one.
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/strongs_result_counts.dart' show groupThousands;

const int kGreekStrongsCeiling = 5624;
const int kHebrewStrongsCeiling = 8674;

/// Why a single Strong's number came back with nothing to show.
enum StrongsAbsence {
  /// Outside Strong's own numbering — there is no such number.
  unknownNumber,

  /// A number inside the range, which nothing in the tagged text uses.
  notInCorpus,

  /// It occurs, but the `l` search limit excluded every occurrence.
  outsideScope,
}

/// Which kind of empty this is, or null when there is nothing to say.
///
/// [label] is `strongsQueryLabel` — a bare number for this path, but a
/// whole expression (`G25 AND G26`) on the boolean path, which is why
/// anything that is not a bare number returns null rather than guessing.
/// [corpusVerses] is the entry's whole-Bible verse count BEFORE the search
/// limit, and null when the concordance has no entry at all.
StrongsAbsence? classifyStrongsAbsence({
  required String label,
  required int? corpusVerses,
  required int shownVerses,
  required bool scoped,
}) {
  if (shownVerses > 0) return null;
  final m = RegExp(r'^([GH])0*(\d{1,4})$').firstMatch(label.trim().toUpperCase());
  if (m == null) return null;
  final n = int.parse(m.group(2)!);
  if (corpusVerses != null && corpusVerses > 0) {
    // It occurs somewhere, and nothing but the limit can have removed it.
    // Unscoped-and-empty is unreachable; say nothing rather than pick one
    // of two sentences that would both be false.
    return scoped ? StrongsAbsence.outsideScope : null;
  }
  final ceiling = m.group(1) == 'G' ? kGreekStrongsCeiling : kHebrewStrongsCeiling;
  return (n < 1 || n > ceiling)
      ? StrongsAbsence.unknownNumber
      : StrongsAbsence.notInCorpus;
}

/// Describes [absence] in [locale], or null when it lacks a number it
/// would have to print — a missing count can never become a wrong count.
String? describeStrongsAbsence(
  StrongsAbsence absence,
  String locale, {
  required String label,
  int? corpusVerses,
  int? corpusOccurrences,
  String? scopeLabel,
}) {
  String s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;
  final n = label.trim().toUpperCase();
  final greek = n.startsWith('G');
  final range = greek ? 'G1–G$kGreekStrongsCeiling' : 'H1–H$kHebrewStrongsCeiling';
  switch (absence) {
    case StrongsAbsence.unknownNumber:
      return s('strongsAbsenceUnknown', "{n} is outside Strong's numbering "
              '({range}), and no word in the texts SeekSparks carries is '
              'tagged with it.')
          .replaceAll('{n}', n)
          .replaceAll('{range}', range);
    case StrongsAbsence.notInCorpus:
      return s('strongsAbsenceNotInCorpus',
              "{n} is inside Strong's numbering ({range}), but no word in "
              'the tagged texts SeekSparks carries uses it.')
          .replaceAll('{n}', n)
          .replaceAll('{range}', range);
    case StrongsAbsence.outsideScope:
      if (corpusVerses == null || corpusOccurrences == null) return null;
      final scope = (scopeLabel == null || scopeLabel.trim().isEmpty)
          ? s('strongsAbsenceScopeFallback', 'the current search limit')
          : scopeLabel.trim();
      return s('strongsAbsenceOutsideScope',
              '{n} occurs {occ} times in {verses} verses, none of them in '
              '{scope}.')
          .replaceAll('{n}', n)
          .replaceAll('{occ}', groupThousands(corpusOccurrences))
          .replaceAll('{verses}', groupThousands(corpusVerses))
          .replaceAll('{scope}', scope);
  }
}
