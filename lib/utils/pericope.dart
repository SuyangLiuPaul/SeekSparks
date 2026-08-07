/// 2026-08-07 (SeekSparks): the pericope a verse falls in.
///
/// BibleWorks' Context tab (`bwh10h`) counts words over three nested
/// scopes — pericope, chapter, book — and is explicit that "the pericope
/// content is determined by the Bible outline file". The pericope is the
/// interesting one: chapter divisions are medieval and land mid-thought,
/// whereas a pericope is the unit an author actually wrote.
///
/// SeekSparks already ships an outline: `assets/section_titles.json`,
/// 1443 headings per set. It had only ever been used to print a heading
/// above a verse. Here it becomes a RANGE — from a heading to the verse
/// before the next one.
///
/// Two things this has to get right that a naive reading misses:
///
///   * **A pericope crosses chapter boundaries.** If the next heading is
///     at 2:1 the current one ends at the last verse of chapter 1, which
///     means the caller must supply how long each chapter is; the
///     heading list alone cannot say.
///   * **A verse can precede the book's first heading.** Then the
///     pericope runs from 1:1 and has no title. Returning null there
///     would blank the pane on Genesis 1:1 in outlines that open their
///     first heading later.
library;

import 'package:flutter/foundation.dart';

/// One outline heading, located at the verse it stands above.
@immutable
class BookHeading {
  const BookHeading({
    required this.chapter,
    required this.verse,
    required this.title,
  });

  final int chapter;
  final int verse;
  final String title;

  /// Ascending by (chapter, verse) — the order [pericopeAt] requires.
  static int compare(BookHeading a, BookHeading b) {
    final c = a.chapter.compareTo(b.chapter);
    return c != 0 ? c : a.verse.compareTo(b.verse);
  }
}

/// A half-open-free, fully inclusive verse span within one book.
@immutable
class PericopeRange {
  const PericopeRange({
    required this.startChapter,
    required this.startVerse,
    required this.endChapter,
    required this.endVerse,
    this.title,
  });

  final int startChapter;
  final int startVerse;
  final int endChapter;
  final int endVerse;

  /// The outline heading, or null when the span precedes the book's
  /// first heading.
  final String? title;

  bool contains(int chapter, int verse) {
    if (chapter < startChapter || chapter > endChapter) return false;
    if (chapter == startChapter && verse < startVerse) return false;
    if (chapter == endChapter && verse > endVerse) return false;
    return true;
  }

  bool get spansChapters => startChapter != endChapter;

  /// `1:1-18`, or `1:1-2:11` when the span crosses a chapter.
  String get label => spansChapters
      ? '$startChapter:$startVerse-$endChapter:$endVerse'
      : '$startChapter:$startVerse-$endVerse';

  @override
  bool operator ==(Object other) =>
      other is PericopeRange &&
      other.startChapter == startChapter &&
      other.startVerse == startVerse &&
      other.endChapter == endChapter &&
      other.endVerse == endVerse &&
      other.title == title;

  @override
  int get hashCode =>
      Object.hash(startChapter, startVerse, endChapter, endVerse, title);
}

/// The pericope containing (`chapter`, `verse`).
///
/// [headings] must be sorted with [BookHeading.compare] and contain only
/// this book. [lastVerseByChapter] gives each chapter's final verse,
/// which is how a span that ends at a chapter boundary finds its end;
/// derive it from the text actually loaded, not from a table, so a book
/// with a partial canon still bounds correctly.
///
/// Returns null only when there is nothing to work with — no headings,
/// or no chapter lengths.
PericopeRange? pericopeAt({
  required List<BookHeading> headings,
  required int chapter,
  required int verse,
  required Map<int, int> lastVerseByChapter,
}) {
  if (headings.isEmpty || lastVerseByChapter.isEmpty) return null;

  // The last heading at or before the target verse.
  var idx = -1;
  for (var i = 0; i < headings.length; i++) {
    final h = headings[i];
    if (h.chapter < chapter || (h.chapter == chapter && h.verse <= verse)) {
      idx = i;
    } else {
      break;
    }
  }

  final int startChapter;
  final int startVerse;
  final String? title;
  if (idx < 0) {
    // Before the first heading: the span opens the book, untitled.
    startChapter = 1;
    startVerse = 1;
    title = null;
  } else {
    startChapter = headings[idx].chapter;
    startVerse = headings[idx].verse;
    title = headings[idx].title;
  }

  final nextIdx = idx + 1;
  if (nextIdx >= headings.length) {
    final lastChapter =
        lastVerseByChapter.keys.reduce((a, b) => a > b ? a : b);
    return PericopeRange(
      startChapter: startChapter,
      startVerse: startVerse,
      endChapter: lastChapter,
      endVerse: lastVerseByChapter[lastChapter] ?? 1,
      title: title,
    );
  }

  final next = headings[nextIdx];
  if (next.verse > 1) {
    return PericopeRange(
      startChapter: startChapter,
      startVerse: startVerse,
      endChapter: next.chapter,
      endVerse: next.verse - 1,
      title: title,
    );
  }

  // The next heading opens a chapter, so this span ends at the end of
  // the previous chapter that actually exists in the text.
  var prev = next.chapter - 1;
  while (prev >= 1 && !lastVerseByChapter.containsKey(prev)) {
    prev--;
  }
  if (prev < startChapter) {
    // Degenerate: two headings at consecutive chapter openings with no
    // text between. Fall back to the single verse we know is there.
    return PericopeRange(
      startChapter: startChapter,
      startVerse: startVerse,
      endChapter: startChapter,
      endVerse: lastVerseByChapter[startChapter] ?? startVerse,
      title: title,
    );
  }
  return PericopeRange(
    startChapter: startChapter,
    startVerse: startVerse,
    endChapter: prev,
    endVerse: lastVerseByChapter[prev] ?? 1,
    title: title,
  );
}
