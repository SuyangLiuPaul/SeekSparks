/// One synopsis entry as a reader sees it — the event's title and a
/// chip per parallel passage — extracted so the three surfaces that
/// print it render the SAME row.
///
/// It was private to `bible_reading_pane.dart` while the chapter sheet
/// was the only surface. `SynopsisService.byVerse` gaining a caller in
/// the Analysis window (`CrossRefsPane`) made that a second host, and
/// the phone's cross-references sheet a third; a copy per host is the
/// defect `AGENTS.md` names for tests and it is no better in widgets —
/// `_shortLabel` below is exactly the kind of arithmetic that was
/// wrong once already (splitting at the first space turned
/// "2 Chronicles 26:3-15" into "Chronicles 26:3-15" for the thirteen
/// numbered books the OT groups name) and must not be re-derived.
///
/// Sizing goes through `WbType` rather than the reading pane's private
/// `context.textSize` extension, which is the same arithmetic —
/// `textSize(x)` is `WbType.resolve(...).scaled(x)` — reached by a
/// route a widget outside that file can use.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/synopsis_service.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/utils/short_book_name.dart';

class SynopsisRow extends StatelessWidget {
  const SynopsisRow({
    super.key,
    required this.event,
    required this.currentBook,
    required this.locale,
    required this.version,
    required this.fontFamily,
    required this.onNavigate,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  final SynopsisEvent event;
  final String currentBook;
  final String locale;
  final String version;

  /// Nullable because `WbType.fontFamily` is — the Analysis pane reads
  /// it from there, while the sheet passes `AppSettings.fontFamily`.
  final String? fontFamily;
  final void Function(BibleReference) onNavigate;

  /// The sheet gives a row the full 16 px gutter it uses everywhere;
  /// the Analysis pane is 320–560 px wide and pays that twice, so it
  /// passes a tighter one. The row itself takes no view on which.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = WbType.of(context);
    // Every passage, in source order. An Old Testament group names any
    // books it likes and may name one of them twice, so this cannot be
    // a lookup by Gospel name the way it was.
    final present = event.passages;
    final isUnique = event.isGospelHarmony && present.length == 1;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.localizedTitle(locale),
            style: TextStyle(
              fontSize: t.scaled(14),
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in present)
                SynopsisRefChip(
                  label: _shortLabel(p.book, p.raw),
                  isCurrentGospel: p.book == currentBook,
                  onTap: () {
                    final ref = p.reference;
                    if (ref != null) onNavigate(ref);
                  },
                ),
              if (isUnique)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    uiStrings['synopsisOnlyHere']?[locale] ??
                        'Only in this Gospel',
                    style: TextStyle(
                      fontSize: t.scaled(11),
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact chip label like "Mat 5:1-12" or "太 5:1-12". Strips the
  /// English book name off the raw reference and prepends the
  /// abbreviation for the reading version's script.
  ///
  /// Splitting at the first space, which is what this did, turned
  /// "2 Chronicles 26:3-15" into "Chronicles 26:3-15" — harmless while
  /// only the four Gospels reached here, wrong for the thirteen
  /// numbered books the OT groups name.
  String _shortLabel(String englishBook, String raw) {
    if (!raw.startsWith(englishBook)) return raw;
    final tail = raw.substring(englishBook.length).trim();
    return '${shortBookName(englishBook, locale, version)} $tail';
  }
}

class SynopsisRefChip extends StatelessWidget {
  const SynopsisRefChip({
    super.key,
    required this.label,
    required this.isCurrentGospel,
    required this.onTap,
  });

  final String label;
  final bool isCurrentGospel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = WbType.of(context);
    final bg = isCurrentGospel
        ? scheme.primary.withValues(alpha: 0.20)
        : scheme.primary.withValues(alpha: 0.08);
    final fg = isCurrentGospel ? scheme.primary : scheme.onSurface;
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: t.scaled(12.5),
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
