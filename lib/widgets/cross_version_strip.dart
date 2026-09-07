/// The per-version report of a cross-version search — BibleWorks bwh16,
/// "Cross Version Searches".
///
/// BibleWorks shows this in a popup menu. A popup is wrong here for the
/// reason `search_stats_strip.dart` gives about its own subject: on a
/// pad, a result you want to read *alongside* the hits must not be a
/// surface that covers them. So it is a strip under the count, in the
/// same place and the same idiom as the distribution bars.
///
/// What it has to say, and the order it says it in:
///
///   * the edition being read, always first and always present, even at
///     zero — bwh16 never drops the search version, and a report that
///     could omit the column the reader is looking at would be answering
///     a different question;
///   * every other edition searched, with its count;
///   * an edition that could not be read at all, marked as such rather
///     than shown as a zero. "This edition does not say it" and "we
///     could not read this edition" are different facts.
///
/// Tapping a row switches the reading version to that edition, which is
/// the action the report is for: the point of learning that the BSB has
/// eleven of these and the KJV none is to go and look at the eleven.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show shortBibleVersionLabel;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/cross_version_search.dart';

class CrossVersionStrip extends StatelessWidget {
  const CrossVersionStrip({
    super.key,
    required this.hits,
    required this.locale,
    this.searching = false,
    this.onVersionTap,
  });

  final CrossVersionHits hits;
  final String locale;
  final bool searching;

  /// Null disables the tap — used where switching the reading version
  /// would be wrong or is not wired.
  final void Function(String version)? onVersionTap;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    if (!hits.isBroadcast) return const SizedBox.shrink();
    final c = WbColors.of(context);
    // Sizes come off WbType, never off a literal: a hardcoded fontSize
    // is one the reader's Font Size setting cannot move, and this strip
    // is chrome, so it scales with the frame rather than with the
    // reading text.
    final t = WbType.of(context);
    final hitting = hits.hitting.length;
    // Named in full rather than as "3/5": the strip exists because the
    // reader did not know which edition had it, and a fraction does not
    // answer that.
    final summary = _s('crossVersionSummary',
            'Found in {hit} of {total} editions')
        .replaceAll('{hit}', '$hitting')
        .replaceAll('{total}', '${hits.perVersion.length}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(summary,
                  style: TextStyle(
                      fontSize: t.chrome,
                      color: c.mutedText,
                      fontWeight: FontWeight.w600)),
              if (searching) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.4, color: c.mutedText),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final row in hits.perVersion)
                _VersionChip(
                  row: row,
                  isReading: row.version == hits.reading,
                  locale: locale,
                  onTap: onVersionTap == null || row.version == hits.reading
                      ? null
                      : () => onVersionTap!(row.version),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.row,
    required this.isReading,
    required this.locale,
    this.onTap,
  });

  final VersionHits row;
  final bool isReading;
  final String locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final label = shortBibleVersionLabel(row.version);
    // Three states, three appearances, and none of them relies on colour
    // alone: the count is the signal, the colour is the reinforcement.
    final unread = !row.searched;
    final zero = row.isEmpty;
    final fg = unread
        ? c.mutedText
        : zero
            ? c.mutedText
            : c.text;
    final unreadLabel =
        uiStrings['crossVersionUnread']?[locale] ?? 'Could not be read';
    final tooltip = unread ? '$label · $unreadLabel' : '$label · ${row.count}';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: onTap != null,
        label: tooltip,
        // Square, per the #279 chrome pass: this is workbench chrome
        // beside the distribution bars, not a Material chip.
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isReading ? c.selectionBg : Colors.transparent,
              border: Border.all(
                  color: zero || unread ? c.border : c.link, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: t.chrome,
                        color: fg,
                        fontWeight:
                            isReading ? FontWeight.w700 : FontWeight.w500)),
                const SizedBox(width: 4),
                Text(
                  // An em dash, not a 0: the edition was read and does
                  // not have it, which is a different answer from the
                  // one an unread edition gives.
                  unread ? '—' : '${row.count}',
                  style: TextStyle(
                      fontSize: t.chrome,
                      color: fg,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
