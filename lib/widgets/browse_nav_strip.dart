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
import 'package:seeksparks/constants/book_groups.dart' show kBibleDivisions;
import 'package:seeksparks/utils/version_mapper.dart' show toEnglish;
import 'package:seeksparks/constants/ui_strings.dart';
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
    required this.locale,
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

  /// The reader's language, for the division headers.
  final String locale;

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
          _BookMenu(
            value: localBook,
            books: books,
            bookLabel: bookLabel,
            locale: locale,
            onChanged: onBook,
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

/// The popup every menu in this strip opens — the four dropdowns and
/// the book menu.
///
/// One function so the surface is described ONCE. The visible reason is
/// that two menus side by side must not disagree about their shadow;
/// the enforcing reason is `page_chrome_pass_test.dart`, whose per-file
/// ceiling counts each literal `elevation:` — and which caught the book
/// menu on 2026-09-14 the moment it was written as a second copy.
///
/// ⚠️ The elevation stays a LITERAL here on purpose. Hoisting it to a
/// named constant takes the file to zero offences and reads as "the
/// chrome pass finished this file", when nothing about the surface would
/// have changed. Passing that test by renaming the thing it counts is
/// worse than the shadow.
PopupMenuButton<T> _menu<T>({
  required WbColors wb,
  required BoxConstraints constraints,
  required ValueChanged<T> onSelected,
  required List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder,
  required Widget child,
}) {
  return PopupMenuButton<T>(
    tooltip: '',
    position: PopupMenuPosition.under,
    color: wb.paneBg,
    elevation: 4,
    constraints: constraints,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: BorderSide(color: wb.border),
    ),
    onSelected: onSelected,
    itemBuilder: itemBuilder,
    child: child,
  );
}

/// The book menu, laid out as two standing columns.
///
/// 2026-09-13 the owner asked for a table of contents here —
/// 「为什么这个不是两行新约旧约」— and got one: division headers
/// inserted into the single scrolling list. 2026-09-14 they looked at
/// the result and said 「这个sword很难看的 能不能就清晰两竖行新约旧约
/// 分开」. The headers were the right information in the wrong shape.
/// A 96px column of 66 rows plus 10 headers is 1,300px of list seen
/// through a 420px window: to reach 啟示錄 from 創世記 you scroll past
/// the whole canon, and at no point can you see where you are in it.
///
/// Two columns show the entire canon at once. That is the point — the
/// menu stops being a list you traverse and becomes a page you look at,
/// which is what a table of contents is for.
///
/// ON THE COLUMN HEADINGS: they read 希伯来圣经 / 希腊圣经, not 旧约 /
/// 新约, although the request said 新约旧约. That is the standing
/// terminological ruling from #280, recorded in `bible_trivia_page.dart`
/// as "terminological, not per-screen" — 「旧约」 carries a
/// supersessionist implication this project does not intend, and the
/// search strip, the distribution chart and the trivia filter all
/// already say 希伯来 / 希腊. A fourth surface disagreeing with them is
/// exactly the inconsistency that ruling exists to end. The SPLIT the
/// owner asked for is the thing being delivered; its label follows the
/// name already in use.
class _BookMenu extends StatelessWidget {
  const _BookMenu({
    required this.value,
    required this.books,
    required this.bookLabel,
    required this.locale,
    required this.onChanged,
  });

  /// Null before a book is chosen — no row is marked, and the button
  /// prints nothing rather than a book the reader is not on.
  final String? value;

  /// As the corpus spells them, in canonical order.
  final List<String> books;
  final String Function(String) bookLabel;
  final String locale;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final columns = _splitCanon(books);
    // What the popup is actually allowed to occupy. `PopupMenuButton`'s
    // own constraint is a ceiling, not a promise — on a short window the
    // screen is the real limit, and it is the screen that decides how
    // many sub-columns a group needs.
    final room = MediaQuery.of(context).size.height - 120;
    // An NT-only edition (梁家铿译本) has nothing in the left column, and
    // a two-column menu with one empty column is worse than one column.
    final live = columns.where((c) => c.books.isNotEmpty).toList();

    return _menu<String>(
      wb: wb,
      // Tall enough for the longer column — 39 books and their five
      // division headers — and it scrolls when the window is shorter
      // than that, which is the case the single list was ALWAYS in.
      constraints: BoxConstraints(maxHeight: room.clamp(240, 900)),
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          // The whole canon is ONE item: the row a reader clicks is
          // inside it, so this item must never be selectable itself.
          enabled: false,
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < live.length; i++) ...[
                if (i > 0)
                  Container(
                      width: 1,
                      height: room.clamp(240, 900) - 24,
                      color: wb.border),
                _CanonColumnView(
                  column: live[i],
                  current: value,
                  bookLabel: bookLabel,
                  locale: locale,
                  maxHeight: room.clamp(240, 900),
                  onPick: (book) {
                    Navigator.pop(context);
                    onChanged(book);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
      child: _MenuButton(
          label: value == null ? '' : bookLabel(value!),
          minWidth: 96,
          wb: wb,
          t: t),
    );
  }
}

/// One column of the book menu: a heading, then the divisions under it.
class _CanonColumn {
  const _CanonColumn._(this.headingId, this.books, this.headerBefore);

  final String headingId;

  /// As the corpus spells them, in canonical order.
  final List<String> books;

  /// Book → the division header drawn immediately above it.
  final Map<String, String> headerBefore;
}

/// Split the corpus into the Hebrew column and the Greek column.
///
/// Assignment goes through `toEnglish` and `kBibleDivisions`, the same
/// table and the same matcher `book_chapter_picker.dart` uses, so one
/// answer to "where does this book sit" serves every edition and locale.
///
/// A book the table does not recognise keeps its place and follows the
/// last book that WAS recognised, under no division header. A menu that
/// silently drops a book is worse than an ugly one, and an imported
/// edition with a book title nothing here has seen is the ordinary case
/// this has to survive.
List<_CanonColumn> _splitCanon(List<String> books) {
  final hebrew = <String>[];
  final greek = <String>[];
  final headers = <String, String>{};
  final seenDivision = <String>{};
  var inHebrew = true;

  for (final book in books) {
    final english = toEnglish(book) ?? book;
    for (final division in kBibleDivisions) {
      if (!division.books.contains(english)) continue;
      inHebrew = division.oldTestament;
      // Only the first member of a division present in this corpus
      // carries the header.
      if (seenDivision.add(division.id)) headers[book] = division.id;
      break;
    }
    (inHebrew ? hebrew : greek).add(book);
  }

  return [
    _CanonColumn._('oldTestamentShort', hebrew, headers),
    _CanonColumn._('newTestamentShort', greek, headers),
  ];
}

/// Draws one column: its heading, its division headers and its books.
class _CanonColumnView extends StatelessWidget {
  const _CanonColumnView({
    required this.column,
    required this.current,
    required this.bookLabel,
    required this.locale,
    required this.maxHeight,
    required this.onPick,
  });

  final _CanonColumn column;
  final String? current;
  final String Function(String) bookLabel;
  final String locale;

  /// How tall the menu is allowed to be. A group taller than this is
  /// laid out in as many equal sub-columns as it takes to fit.
  final double maxHeight;

  final ValueChanged<String> onPick;

  // Measured against `_BookRow`'s 24px minimum and the header paddings
  // below. Approximate on purpose: being one row out puts one book in
  // the next sub-column, which is a layout no reader can tell from the
  // intended one. Being out by a factor of two would not be, which is
  // what a guessed constant risks and a derived one does not.
  static const double _kRow = 24;
  static const double _kHeader = 20;
  static const double _kHeading = 22;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);

    // Height this group would take as ONE column, then the number of
    // sub-columns that makes it fit.
    //
    // The 希伯来聖經 side is 39 books and five division headers — about
    // 1,030px, which no window is. Two columns that both run off the
    // bottom is the SAME defect the single list had; the point of the
    // menu is that you can see the canon without scrolling, so a group
    // that cannot fit in one column takes two.
    final rows = column.books.length;
    final headers = column.books.where(column.headerBefore.containsKey).length;
    final tall = _kHeading + rows * _kRow + headers * _kHeader;
    final room = (maxHeight - 16).clamp(_kRow * 4, double.infinity);
    final parts = (tall / room).ceil().clamp(1, 4);
    final perPart = (rows / parts).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Text(
              uiStrings[column.headingId]?[locale] ?? column.headingId,
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: wb.text,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < parts; i++)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final book in column.books
                        .skip(i * perPart)
                        .take(perPart)) ...[
                      if (column.headerBefore[book] case final id?)
                        _DivisionHeader(id: id, locale: locale),
                      _BookRow(
                        label: bookLabel(book),
                        selected: book == current,
                        onTap: () => onPick(book),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 律法書 / 歷史書 / 福音書 … — the division a run of books belongs to.
class _DivisionHeader extends StatelessWidget {
  const _DivisionHeader({required this.id, required this.locale});

  final String id;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 1),
      child: Text(
        uiStrings[id]?[locale] ?? id,
        style: TextStyle(
          fontSize: t.chrome * 0.85,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: wb.mutedText,
        ),
      ),
    );
  }
}

/// One book. Its own tap target, because the menu item that contains the
/// whole canon is `enabled: false` and cannot carry a selection.
class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 112,
        // 24px is the WCAG 2.5.8 minimum target, and a table of contents
        // whose rows are 18px tall is a table of contents you mis-click.
        constraints: const BoxConstraints(minHeight: 24),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: selected ? wb.hoverBg : null,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: wb.text,
          ),
        ),
      ),
    );
  }
}

/// The hairline button the dropdowns and the book menu share.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.minWidth,
    required this.wb,
    required this.t,
  });

  final String label;
  final double minWidth;
  final WbColors wb;
  final WbType t;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    this.headerBefore = const {},
  });

  /// A section header to draw above the item with this value. Empty for
  /// the menus that are one list — versions, chapters, verses.

  final T? value;

  /// `(value, label)` pairs.
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final double minWidth;
  final Map<T, String> headerBefore;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final label = items
        .where((e) => e.$1 == value)
        .map((e) => e.$2)
        .followedBy(const [''])
        .first;

    return _menu<T>(
      wb: wb,
      // Long lists (150 Psalms) need to scroll rather than run off the
      // screen. The 66-book list does not come through here any more —
      // it has its own two-column menu above.
      constraints: const BoxConstraints(maxHeight: 420, minWidth: 96),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final (v, text) in items) ...[
          // `enabled: false` so the header cannot be chosen — it is a
          // label, and a menu row that closes the menu and changes
          // nothing is a trap.
          if (headerBefore[v] case final header?)
            PopupMenuItem<T>(
              enabled: false,
              height: 20,
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              child: Text(
                header,
                style: TextStyle(
                  fontSize: t.chrome * 0.85,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: wb.mutedText,
                ),
              ),
            ),
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
