/// The Resource Summary — bwh10's docked list of everything this app has
/// to say about the verse in focus. `docs/PARITY-BACKLOG.md` §3.4.
///
/// The row's first half — *"sermons get a tab"* — landed on 2026-08-17
/// and the row never came back to say so. What it asked for second is
/// this: *"one 'everything about this verse' summary above the
/// specialised tabs."*
///
/// ## Why a count and not a preview
///
/// Twelve specialised tabs answer twelve questions well. What none of
/// them can tell a reader is **which of the twelve is worth opening for
/// THIS verse** — and that is the whole job BibleWorks gives its
/// Resource Summary. So each row is a number and a name, and tapping it
/// opens the tab that has the material. Previews here would make it a
/// thirteenth answer competing with the twelve.
///
/// ## A zero is printed, not hidden
///
/// A row that vanishes when it has nothing teaches the reader that the
/// resource does not exist. A row that says 0 teaches them that it does
/// and this verse is not in it — which is a fact about the verse, and
/// frequently the interesting one: a verse with no cross-references at
/// all is unusual.
///
/// Counting is deliberately cheap: every source here is already loaded
/// or already indexed by the tab that owns it, so the summary costs a
/// lookup rather than a scan.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart' show AnalysisTab;

/// One line of the summary: a resource, how much of it touches this
/// verse, and the tab that holds it.
class ResourceCount {
  const ResourceCount({
    required this.tab,
    required this.labelKey,
    required this.fallback,
    required this.count,
    this.unknown = false,
  });

  final AnalysisTab tab;
  final String labelKey;
  final String fallback;
  final int count;

  /// True when the count could not be established — an asset that has
  /// not loaded yet. Printed as a dash, never as a zero: "this verse is
  /// in none of them" and "we have not looked" are different facts, and
  /// showing the second as the first is how a summary lies quietly.
  final bool unknown;
}

class ResourceSummaryPane extends StatelessWidget {
  const ResourceSummaryPane({
    super.key,
    required this.reference,
    required this.counts,
    required this.locale,
    this.onOpenTab,
    this.loading = false,
  });

  /// The verse this is about, as the reader sees it.
  final String reference;
  final List<ResourceCount> counts;
  final String locale;
  final void Function(AnalysisTab tab)? onOpenTab;
  final bool loading;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final withSomething = counts.where((r) => !r.unknown && r.count > 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                reference,
                style: TextStyle(
                    fontSize: t.text,
                    color: c.text,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (loading)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                    strokeWidth: 1.4, color: c.mutedText),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _s('resourceSummaryLead', '{n} resources have something here')
              .replaceAll('{n}', '${withSomething.length}'),
          style: TextStyle(fontSize: t.chrome, color: c.mutedText),
        ),
        const SizedBox(height: 8),
        for (final r in counts)
          InkWell(
            onTap: onOpenTab == null || r.unknown || r.count == 0
                ? null
                : () => onOpenTab!(r.tab),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      r.unknown ? '—' : '${r.count}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: t.chrome,
                        color: r.unknown || r.count == 0
                            ? c.mutedText
                            : c.link,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _s(r.labelKey, r.fallback),
                      style: TextStyle(
                        fontSize: t.chrome,
                        color: r.unknown || r.count == 0
                            ? c.mutedText
                            : c.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
