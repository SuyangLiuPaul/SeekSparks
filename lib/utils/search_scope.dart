/// 2026-08-08 (SeekSparks): what a search is allowed to look at, held as
/// a DESCRIPTION rather than as a bag of verse keys — task #280.
///
/// bwh29 ("Setting Search Limits") gives BibleWorks three limit modes:
/// none, a tree of book checkboxes with NT/OT/Clear-All shortcuts, and a
/// custom range spec that can name chapters and verses. SeekSparks had
/// the third (the `l` verb) and neither of the others, so the only way
/// to narrow a search was to already know a command. This file is the
/// first mode's model.
///
/// The scope is a BOOK SET, deliberately not the verse-key set the
/// search path actually filters on:
///   * a key set cannot say what it IS — a scope chosen as 摩西五经
///     could only be printed back as five book names;
///   * it cannot be re-edited — reopening the picker needs the boxes
///     that were ticked, and recovering them from 5,852 keys is
///     guesswork;
///   * it is ~31k strings, which is not a thing to hold twice.
/// The keys remain the derived filter; a [LimitSpec] is the intent that
/// produced them, and is what the UI reads back.
///
/// bwh23 supplies the other half, and it is the part a naive reading of
/// "add a scope filter" misses entirely: when limits are set, BibleWorks
/// prints the statistic it found AND, in parentheses, what the number
/// would have been over the whole version. A narrowed count without its
/// denominator is the ambiguity the filter itself creates — "64 处" says
/// nothing about whether 64 is all of them. See [scopedCountLabel].
library;

import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/command_verb.dart' show LimitRange, LimitSpec;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// A named run of books the picker offers as one tap.
///
/// bwh29's tree has only NT / OT / Apoc / Clear All; the traditional
/// sub-corpora below it are SeekSparks' own, because "search the
/// prophets" is a question readers actually ask and ticking seventeen
/// boxes to ask it is not a feature.
class ScopeGroup {
  const ScopeGroup(this.key, this.books);

  /// `uiStrings` key for the group's name.
  final String key;

  /// Canonical English book names, in canonical order.
  final List<String> books;
}

/// The two corpora first, then the traditional groupings within each.
///
/// `oldTestament` / `newTestament` are reused rather than given scope-
/// specific keys: they already read 希伯来圣经 / 希腊圣经, which is the
/// terminology this project uses everywhere a corpus is NAMED.
const kScopeGroups = <ScopeGroup>[
  ScopeGroup('oldTestament', canonicalOtBooks),
  ScopeGroup('newTestament', canonicalNtBooks),
  ScopeGroup('scopePentateuch', otPentateuch),
  ScopeGroup('scopeHistory', otHistory),
  ScopeGroup('scopeWisdom', otWisdom),
  ScopeGroup('scopeProphets', [...otMajorProphets, ...otMinorProphets]),
  ScopeGroup('scopeGospels', ntGospelsActs),
  ScopeGroup('scopePauline', ntPauline),
  ScopeGroup('scopeGeneralEpistles',
      [...ntOtherApostolic, '1 John', '2 John', '3 John']),
];

/// Every book in canonical order, both corpora.
const kScopeAllBooks = <String>[...canonicalOtBooks, ...canonicalNtBooks];

final Map<String, int> _canonicalIndex = {
  for (var i = 0; i < kScopeAllBooks.length; i++) kScopeAllBooks[i]: i,
};

/// [books] in Genesis→Revelation order, with anything unrecognised
/// dropped rather than sorted to an arbitrary end.
List<String> canonicalScopeOrder(Iterable<String> books) {
  final known = [
    for (final b in books)
      if (_canonicalIndex.containsKey(b)) b
  ];
  known.sort((a, b) => _canonicalIndex[a]!.compareTo(_canonicalIndex[b]!));
  return known;
}

/// The `uiStrings` key of the group [books] exactly matches, or null.
///
/// Exact, not "contains": a scope of 摩西五经 plus Joshua is not the
/// Pentateuch, and calling it that in the banner would misreport what
/// the reader is about to search.
String? scopeGroupKeyFor(Set<String> books) {
  for (final g in kScopeGroups) {
    if (g.books.length == books.length && books.containsAll(g.books)) {
      return g.key;
    }
  }
  return null;
}

/// Turn a set of whole books into the [LimitSpec] the search path and
/// the banner both already understand.
///
/// Throws nothing on an empty set — an empty scope is a real (if
/// useless) restriction, and the provider is the layer that refuses to
/// install one, exactly as it already does for `l revelation 30`.
LimitSpec limitSpecForBooks(Iterable<String> books) {
  final ordered = canonicalScopeOrder(books);
  return LimitSpec(
    [for (final b in ordered) LimitRange(b)],
    ordered.join(' · '),
    labelKey: scopeGroupKeyFor(ordered.toSet()),
  );
}

/// The whole books [spec] covers, or null when any of its ranges names
/// chapters.
///
/// Null is the honest answer for `l matt 5-7`: the picker deals in
/// books, so flattening that to "Matthew" would silently widen a scope
/// the reader deliberately narrowed the moment they opened the sheet.
Set<String>? wholeBooksOfSpec(LimitSpec spec) {
  final books = <String>{};
  for (final r in spec.ranges) {
    if (r.firstChapter != null) return null;
    books.add(r.englishBook);
  }
  return books;
}

/// One range's name in the reader's script — `创世记`, `马太福音 5–7`.
///
/// [LimitSpec.label] is built from canonical English at parse time and
/// its own doc says the names are "re-localised where they are
/// displayed"; until now no display site did, so `l 创` put "Genesis"
/// in a Chinese banner. Same defect class as #283.
String localizedRangeLabel(LimitRange r, String locale, [String? version]) {
  final book = localeAwareBookName(r.englishBook, locale, version);
  final first = r.firstChapter;
  if (first == null) return book;
  final last = r.lastChapter;
  if (last == null || last == first) return '$book $first';
  return '$book $first–$last';
}

/// What to call the active scope in a banner, a status field or a
/// result header.
///
/// [fallbackLabel] carries the Verse List Manager's case, where the
/// scope is a saved list of arbitrary verses and has no ranges at all —
/// there the list's own name is the only description there is.
String scopeDisplayName({
  required LimitSpec? spec,
  String? fallbackLabel,
  required String locale,
  String? version,
  int maxNames = 2,
}) {
  if (spec == null) return fallbackLabel ?? '';
  final key = spec.labelKey;
  if (key != null) {
    final named = uiStrings[key]?[locale];
    if (named != null) return named;
  }
  final parts = [
    for (final r in spec.ranges) localizedRangeLabel(r, locale, version)
  ];
  if (parts.isEmpty) return fallbackLabel ?? '';
  if (parts.length <= maxNames) return parts.join(' · ');
  return '${parts.take(maxNames).join(' · ')} +${parts.length - maxNames}';
}

/// A count that carries its denominator — bwh23's parenthesised
/// statistic, in a form that survives a narrow pane.
///
/// BibleWorks writes `*64 (1278)`. The asterisk is a footnote marker
/// with no footnote on screen, which does not travel to a Chinese UI;
/// the slash does, and it reads as "of" in every locale this app has.
/// Returns the bare number whenever the scope did not actually remove
/// anything, so an unlimited search never grows a second figure it does
/// not need.
String scopedCountLabel(int inScope, int? total) {
  if (total == null || total <= inScope) return '$inScope';
  return '$inScope / $total';
}

/// [spec] as a plain set of whole books, or null if it is not one.
///
/// The concordance carries a per-book OCCURRENCE map that is uncapped and
/// exact, and it is addressable only by whole book. So a limit made of
/// whole books can be answered from it — in the same unit as the
/// whole-Bible total, with no reference cap in the way — while a limit
/// that names chapters cannot be, and must fall back to counting listed
/// verses. Returning null is what tells a caller which of those two it
/// is holding (#308).
///
/// Null for a Verse List Manager limit too, which arrives as keys with
/// no spec at all.
Set<String>? wholeBookScope(LimitSpec? spec) {
  if (spec == null || spec.ranges.isEmpty) return null;
  if (spec.ranges.any((r) => r.firstChapter != null)) return null;
  return {for (final r in spec.ranges) r.englishBook};
}
