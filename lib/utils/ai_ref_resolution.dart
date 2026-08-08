/// Turning the AI's answer — a list of canonical English references —
/// into rows the workbench can show.
///
/// The AI returns references, not verses: `Matthew 5:3-12` and a
/// sentence saying why. Three things can then go wrong, and the reason
/// this is a pure function rather than a loop inside a widget is that
/// all three are worth a test:
///
///   * the reference is outside the reader's current search scope;
///   * the reference names a book or verse the LOADED edition does not
///     carry (an OT reference on an NT-only edition, a versification
///     difference, an apocryphal book);
///   * the reference spans verses, so one row is several [Verse]s.
///
/// The rule the old standalone SearchPage established and this keeps:
/// **every in-scope reference stays on screen even when it resolves to
/// nothing**, marked "reference only". Dropping it would silently edit
/// the AI's answer, and a reader comparing the list against another
/// tool would find passages missing with no explanation.
library;

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/ai_bible_search_service.dart';
import 'package:seeksparks/utils/version_mapper.dart' show toEnglish;

class AiRefResolution {
  const AiRefResolution({
    required this.kept,
    required this.verses,
    required this.unresolvedDisplays,
    required this.outOfScope,
  });

  /// Every reference inside the active scope, in the order the AI gave
  /// them. Includes the ones that did not resolve.
  final List<AiBibleRef> kept;

  /// The verses [kept] resolved to, de-duplicated, in reference order.
  /// This is what feeds the verse list / search-limit plumbing.
  final List<Verse> verses;

  /// `AiBibleRef.display` of every reference that resolved to nothing.
  /// Compared by display string because that is the only stable
  /// identity an [AiBibleRef] has.
  final Set<String> unresolvedDisplays;

  /// How many references the scope removed. Surfaced to the reader —
  /// a narrowed scope that silently deletes answers is the same defect
  /// as a search limit with no banner.
  final int outOfScope;

  bool get isEmpty => kept.isEmpty;
}

/// Resolve [refs] against [verses] (the loaded edition).
///
/// [inScope] is the reader's active search limit, expressed as a
/// predicate rather than a book name so the same function serves both
/// shapes the app has: the old page's single book, and the workbench's
/// `l gen 1-11` verse-key set. Null means the whole corpus.
AiRefResolution resolveAiRefs({
  required List<AiBibleRef> refs,
  required List<Verse> verses,
  bool Function(AiBibleRef ref)? inScope,
}) {
  // One pass over the corpus, not one per reference: a 31k-verse
  // edition times twenty references is a visible pause on a pad.
  final byBookChapter = <String, List<Verse>>{};
  for (final v in verses) {
    final englishBook = toEnglish(v.book) ?? v.book;
    (byBookChapter['$englishBook|${v.chapter}'] ??= []).add(v);
  }

  final kept = <AiBibleRef>[];
  final resolved = <Verse>[];
  final seen = <Verse>{};
  final unresolved = <String>{};
  var outOfScope = 0;

  for (final ref in refs) {
    if (inScope != null && !inScope(ref)) {
      outOfScope += 1;
      continue;
    }
    kept.add(ref);
    final candidates = byBookChapter['${ref.book}|${ref.chapter}'];
    if (candidates == null) {
      unresolved.add(ref.display);
      continue;
    }
    var found = false;
    for (final v in candidates) {
      if (v.verse < ref.verseStart || v.verse > ref.verseEnd) continue;
      if (seen.add(v)) resolved.add(v);
      found = true;
    }
    if (!found) unresolved.add(ref.display);
  }

  return AiRefResolution(
    kept: kept,
    verses: resolved,
    unresolvedDisplays: unresolved,
    outOfScope: outOfScope,
  );
}

/// What the reader is not being shown, and why — or null when the
/// answer arrived whole.
///
/// Two different absences, deliberately worded apart. "Outside your
/// scope" is the reader's own doing and reversible by lifting the
/// limit; "not in your current Bible version" is the edition's doing
/// and reversible by switching it. Collapsing them into one "some
/// results hidden" would leave the reader with no idea which lever to
/// pull.
String? describeAiGaps({
  required String locale,
  required int outOfScope,
  required int unresolved,
  required bool empty,
}) {
  String s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;

  if (empty) {
    return s('aiBibleSearchNoMatches',
        "AI didn't find any matching passages. Try rephrasing.");
  }
  final notes = <String>[];
  if (outOfScope > 0) {
    notes.add(s('aiBibleSearchOutOfScope',
            'Also suggested {n} passages outside your current scope.')
        .replaceAll('{n}', '$outOfScope'));
  }
  if (unresolved > 0) {
    notes.add(s('aiBibleSearchSomeMissing',
            'Also suggested {n} passages not in your current edition.')
        .replaceAll('{n}', '$unresolved'));
  }
  return notes.isEmpty ? null : notes.join('\n');
}
