/// The synopsis laid out side by side — bwh38's display, and the thing
/// `docs/PARITY-BACKLOG.md` §3.5 said we did not have: *"a reader
/// compares two passages by jumping between them instead of reading
/// them beside each other, which is the whole point of a synopsis."*
///
/// The row parked this behind #292; **#292 closed 2026-09-02**, so this
/// is the re-decision `docs/PRODUCT-AUDIT.md` §7.4 asked for, and the
/// answer is a docked pane rather than the sheet.
///
/// Columns, not a table. bwh38 puts one Browse column per passage
/// because the passages do not align verse-for-verse — Matthew tells an
/// event in four verses that Luke tells in eleven — and a table would
/// have to invent a correspondence the sources do not have. Reading them
/// beside each other is exactly the comparison; aligning them would be a
/// claim.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/synopsis_service.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/utils/synopsis_columns.dart';

class SynopsisColumnsPane extends StatefulWidget {
  const SynopsisColumnsPane({
    super.key,
    required this.events,
    required this.verses,
    required this.englishBook,
    required this.locale,
    required this.bookLabel,
    this.onOpenRef,
  });

  /// Every entry covering the focused verse. Usually one.
  final List<SynopsisEvent> events;

  /// The edition the reader is in. Passages are drawn from it, so the
  /// synopsis is read in the translation they chose rather than in one
  /// this pane picked.
  final List<Verse> verses;

  final String englishBook;
  final String locale;

  /// English book name → what the reader should see.
  final String Function(String englishBook) bookLabel;

  final void Function(BibleReference ref)? onOpenRef;

  @override
  State<SynopsisColumnsPane> createState() => _SynopsisColumnsPaneState();
}

class _SynopsisColumnsPaneState extends State<SynopsisColumnsPane> {
  bool _removeBlanks = false;
  int _event = 0;

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  /// The verses of [ref] out of the loaded edition.
  ///
  /// Matched on the ENGLISH book name via the caller's label function's
  /// own corpus, never on the raw string: `Verse.book` carries the name
  /// the edition uses, so a Chinese edition beside an English reference
  /// matches nothing — the seam `chapter_across_editions.dart` exists
  /// to hold.
  List<Verse> _versesFor(BibleReference ref, String displayBook) {
    final start = ref.verseStart ?? 1;
    final endCh = ref.endChapter ?? ref.chapter;
    final endV = ref.endVerse ?? ref.verseEnd ?? 9999;
    return [
      for (final v in widget.verses)
        if (v.book == displayBook &&
            ((v.chapter > ref.chapter && v.chapter < endCh) ||
                (v.chapter == ref.chapter &&
                    v.verse >= start &&
                    (endCh > ref.chapter || v.verse <= endV)) ||
                (endCh > ref.chapter &&
                    v.chapter == endCh &&
                    v.verse <= endV)))
          v,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final comparable =
        widget.events.where(isComparable).toList(growable: false);
    if (comparable.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _s('synopsisNoParallel', 'This passage has no parallel.'),
          style: TextStyle(fontSize: t.text, color: c.mutedText),
        ),
      );
    }
    final event = comparable[_event.clamp(0, comparable.length - 1)];
    final blanks = blankColumnCount(event);
    final columns = synopsisColumns(event,
        removeBlanks: _removeBlanks, keepBook: widget.englishBook);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.localizedTitle(widget.locale),
                style: TextStyle(
                    fontSize: t.text,
                    color: c.text,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Only offered when it would do something. A toggle
                  // that removes nothing teaches the reader it is
                  // broken.
                  if (blanks > 0)
                    _chip(
                      c,
                      t,
                      _s('synopsisRemoveBlanks', 'Hide the {n} silent')
                          .replaceAll('{n}', '$blanks'),
                      _removeBlanks,
                      () => setState(() => _removeBlanks = !_removeBlanks),
                    ),
                  for (var i = 0; i < comparable.length; i++)
                    if (comparable.length > 1)
                      _chip(
                        c,
                        t,
                        comparable[i].localizedTitle(widget.locale),
                        i == _event,
                        () => setState(() => _event = i),
                      ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.border),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final col in columns) _column(c, t, col),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _column(WbColors c, WbType t, SynopsisColumn col) {
    final display = widget.bookLabel(col.book);
    final ref = col.passage.reference;
    final verses = ref == null ? const <Verse>[] : _versesFor(ref, display);
    final isHere = col.book.toLowerCase() == widget.englishBook.toLowerCase();
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isHere ? c.paneAltBg : null,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: ref == null || widget.onOpenRef == null
                ? null
                : () => widget.onOpenRef!(ref),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
              child: Text(
                col.raw,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: ref == null ? c.mutedText : c.link,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: verses.isEmpty
                  ? Text(
                      // Two different silences, said differently. "The
                      // source names no passage here" is a fact about
                      // the event; "this edition does not carry it" is a
                      // fact about the edition, and calling the second
                      // the first would be a small lie about scripture.
                      ref == null
                          ? _s('synopsisSilent', 'No parallel here')
                          : _s('synopsisNotInEdition',
                              'Not in this edition'),
                      style: TextStyle(
                          fontSize: t.chrome,
                          color: c.mutedText,
                          fontStyle: FontStyle.italic),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final v in verses)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: '${v.verse} ',
                                  style: TextStyle(
                                      fontSize: t.chrome,
                                      color: c.mutedText),
                                ),
                                TextSpan(
                                  text: v.scriptureText,
                                  style: TextStyle(
                                      fontSize: t.chrome, color: c.text),
                                ),
                              ]),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
          WbColors c, WbType t, String label, bool on, VoidCallback tap) =>
      InkWell(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: on ? c.selectionBg : null,
            border: Border.all(color: on ? c.link : c.border, width: 0.8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: t.chrome, color: on ? c.link : c.text)),
        ),
      );
}
