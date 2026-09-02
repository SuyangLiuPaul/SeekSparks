/// 2026-08 (SeekSparks): the Browse window's navigation strip —
/// `NAS ▾  Genesis ▾  1 ▾  1 ▾`.
///
/// Reported: "how to toggle verses". There was no answer, which is the
/// bug. Rebuilding Browse as a continuous chapter removed the old
/// prev/next stepper, and what replaced it was "scroll, or type a
/// reference in the command line" — neither of which is a control you
/// can see. BibleWorks puts four dropdowns directly under the Browse
/// title and that is how you move: version, book, chapter, verse.
///
/// The lists are derived from the loaded corpus rather than a static
/// table, so a version with a different canon (an NT-only Chinese
/// edition, say) offers exactly the books it actually has.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show availableVersions;
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/verse.dart';

class BrowseNavStrip extends StatelessWidget {
  const BrowseNavStrip({
    super.key,
    required this.corpus,
    required this.version,
    required this.localBook,
    required this.chapter,
    required this.verse,
    required this.bookLabel,
    required this.onVersion,
    required this.onBook,
    required this.onChapter,
    required this.onVerse,
  });

  /// The loaded Bible, used to enumerate books/chapters/verses.
  final List<Verse> corpus;

  final String version;

  /// Book name as the corpus stores it (localised per version).
  final String? localBook;
  final int? chapter;
  final int verse;

  /// How [localBook] should read in the UI's language.
  final String Function(String localBook) bookLabel;

  final ValueChanged<String> onVersion;
  final ValueChanged<String> onBook;
  final ValueChanged<int> onChapter;
  final ValueChanged<int> onVerse;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);

    // One pass over the corpus answers all three lists. It runs on every
    // build of this strip, which is cheap next to the Browse window's own
    // work and avoids a cache that could go stale on a version switch.
    final books = <String>[];
    final chapters = <int>{};
    final verses = <int>{};
    for (final v in corpus) {
      if (books.isEmpty || books.last != v.book) {
        if (!books.contains(v.book)) books.add(v.book);
      }
      if (v.book != localBook) continue;
      chapters.add(v.chapter);
      if (v.chapter == chapter) verses.add(v.verse);
    }
    final chapterList = chapters.toList()..sort();
    final verseList = verses.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: wb.paneBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Row(
        children: [
          _Dropdown<String>(
            value: version,
            // The reading version — the one whose book names and canon
            // drive the other three lists.
            // `availableVersions`: this dropdown is one of the places a
            // reader CHOOSES the reading version, so a hidden edition
            // must not appear in it (2026-09-02).
            items: [
              for (final v in availableVersions) (v.value, v.shortLabel),
            ],
            onChanged: onVersion,
            minWidth: 62,
          ),
          const SizedBox(width: 4),
          _Dropdown<String>(
            value: localBook,
            items: [for (final b in books) (b, bookLabel(b))],
            onChanged: onBook,
            minWidth: 96,
          ),
          const SizedBox(width: 4),
          _Dropdown<int>(
            value: chapter,
            items: [for (final c in chapterList) (c, '$c')],
            onChanged: onChapter,
            minWidth: 46,
          ),
          const SizedBox(width: 4),
          _Dropdown<int>(
            value: verseList.contains(verse) ? verse : null,
            items: [for (final n in verseList) (n, '$n')],
            onChanged: onVerse,
            minWidth: 46,
          ),
          const Spacer(),
          // Step buttons as well: moving one verse at a time is the most
          // common motion of all, and opening a dropdown for it is a
          // worse deal than a single click.
          _StepButton(
            icon: Icons.keyboard_arrow_up,
            tooltip: 'Previous verse',
            onTap: verse > 1 ? () => onVerse(verse - 1) : null,
          ),
          _StepButton(
            icon: Icons.keyboard_arrow_down,
            tooltip: 'Next verse',
            onTap: verseList.isNotEmpty && verse < verseList.last
                ? () => onVerse(verse + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

/// A compact hairline-bordered dropdown. Material's own `DropdownButton`
/// is far too tall and padded for a 26px strip.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.minWidth,
  });

  final T? value;

  /// `(value, label)` pairs.
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final label = items
        .where((e) => e.$1 == value)
        .map((e) => e.$2)
        .followedBy(const [''])
        .first;

    return PopupMenuButton<T>(
      tooltip: '',
      position: PopupMenuPosition.under,
      color: wb.paneBg,
      elevation: 4,
      // Long lists (66 books, 150 Psalms) need to scroll rather than
      // run off the screen.
      constraints: const BoxConstraints(maxHeight: 420, minWidth: 96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final (v, text) in items)
          PopupMenuItem<T>(
            value: v,
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: v == value ? FontWeight.w700 : FontWeight.w400,
                color: wb.text,
              ),
            ),
          ),
      ],
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
        padding: const EdgeInsets.fromLTRB(6, 2, 3, 2),
        decoration: BoxDecoration(
          color: wb.paneBg,
          border: Border.all(color: wb.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w600,
                  color: wb.text,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: wb.mutedText),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? wb.mutedText.withValues(alpha: 0.4)
                : wb.text,
          ),
        ),
      ),
    );
  }
}
