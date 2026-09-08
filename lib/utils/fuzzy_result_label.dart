/// 2026-09-08 (SeekSparks): the one line of this feature that is NOT
/// portable, kept in its own file so the rest can be lifted out whole.
///
/// `fuzzy_search.dart`, `porter_stemmer.dart`, `chinese_segmentation.dart`
/// and `search_synonyms.dart` know nothing about this app: no Flutter,
/// no assets, no `Verse`, no locale. They are going into the YsWords
/// repository unchanged. This file is where they meet SeekSparks — it
/// knows how a verse becomes a corpus key (`searchCorpusKey`), how a
/// query becomes segments (`plainSearchSegments` under
/// `foldSearchMarks`), which character starts a command line, and which
/// of three locales the reader is in. Every SeekSparks import this
/// feature needs is in this file and in no other, which is what "the
/// rest is portable" has to mean to be worth saying.
///
/// ## Why the label is built from the verse and not carried with it
///
/// `SearchService.scanText` returns a `List<Verse>` and no provenance,
/// and it is not this feature's place to change that signature: six
/// callers pass through it, and a per-verse "how did this match" field
/// would have to be threaded through every one of them to reach the one
/// list that draws rows. Instead the question is asked again, per
/// VISIBLE row, at the moment the row is drawn — the query's expansion
/// is memoized, so the second ask costs one pass over one verse, and a
/// `ListView.builder` never draws more rows than fit on a screen.
///
/// The rule it serves is the one this codebase has fixed three times:
/// a view that changes what it shows must say so. `strip_strings.dart`
/// states it as "nothing narrows in silence" for a filter that
/// subtracted; this is the same rule for a search that ADDED — a reader
/// who sees 约翰福音 1:42 in the results for 磯法 is owed the two
/// characters that say the verse actually spells it 矶法.
library;

import 'package:seeksparks/constants/fuzzy_search_strings.dart';
import 'package:seeksparks/constants/text_patterns.dart' show searchCorpusKey;
import 'package:seeksparks/utils/command_query.dart' show kCommandControls;
import 'package:seeksparks/utils/fuzzy_search.dart';
import 'package:seeksparks/utils/plain_search.dart';
import 'package:seeksparks/utils/search_folding.dart' show foldSearchMarks;

/// The string key naming [match], or null when the row needs no label.
///
/// Null for [FuzzyMatch.literal] — the row holds what the reader typed,
/// and saying so on every row would drown the four rows that need
/// saying. Null for [FuzzyMatch.none] too, which is what a row from a
/// different engine looks like: a Strong's hit and a command-grammar hit
/// never went through the plain matcher, and labelling one "not a match"
/// would be a lie about a verse that is legitimately in the list.
String? fuzzyMatchStringKey(FuzzyMatch match) {
  switch (match) {
    case FuzzyMatch.script:
      return 'fuzzyLabelScript';
    case FuzzyMatch.synonym:
      return 'fuzzyLabelSynonym';
    case FuzzyMatch.stem:
      return 'fuzzyLabelStem';
    case FuzzyMatch.segmented:
      return 'fuzzyLabelSegmented';
    case FuzzyMatch.literal:
    case FuzzyMatch.none:
      return null;
  }
}

/// [reference] as the result row should print it: unchanged for a
/// literal hit, and with the rung's name appended for a broadened one.
///
/// Cheap enough to call from a row builder, and cheapest of all in the
/// case that matters: while `fuzzySearchEnabled` is false this returns
/// [reference] before touching the verse text at all, so a reader who
/// never turned the feature on pays one boolean read per drawn row.
///
/// [scriptureText] must be the same string the search ran over —
/// `Verse.scriptureText`, which is what `SearchService.scanText` scans.
/// Passing the displayed text instead would ask about a different
/// string than the one that matched, and the row would sometimes claim
/// a literal hit for a verse the looser rung found.
String fuzzyLabelledReference(
  String reference, {
  required String query,
  required String scriptureText,
  required String locale,
}) {
  if (!fuzzySearchEnabled) return reference;
  final trimmed = query.trim();
  if (trimmed.isEmpty) return reference;
  // A line with a control character was answered by the command
  // grammar, not by the plain matcher, and this file has no standing to
  // say anything about its rows. Asking anyway would not merely return
  // nothing: `.爱 神` reduces to the segments `.爱` and `神`, whose
  // Han fragments are 爱 and 神, and the loosest rung would then label a
  // command result with a reading it never ran.
  if (kCommandControls.contains(trimmed[0])) return reference;
  final segments = plainSearchSegments(foldSearchMarks(query).toLowerCase());
  if (segments.isEmpty) return reference;
  final kind = plainSearchMatchKind(searchCorpusKey(scriptureText), segments);
  final key = fuzzyMatchStringKey(kind);
  if (key == null) return reference;
  final label = fuzzySearchStrings[key]?[locale] ??
      fuzzySearchStrings[key]?['en'] ??
      '';
  if (label.isEmpty) return reference;
  return '$reference · $label';
}
