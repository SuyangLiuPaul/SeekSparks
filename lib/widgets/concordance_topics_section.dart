/// 2026-09-08 (SeekSparks): the Modern Concordance section on a Strong's
/// entry.
///
/// Lives beside "Word family" and "Compare" on `strongs_entry_page.dart`
/// and is deliberately their sibling rather than a new species of panel:
/// those two answer "what else is this word related to" out of the
/// lexicon, and this answers the same question out of a concordance that
/// grouped the vocabulary by subject. A reader should be able to move
/// between the three without noticing a change of surface, so the chips
/// are the PAGE's chips — passed in as [chipFor] — and not a lookalike
/// written here that would drift from them.
///
/// What this file must never do is describe the data as a semantic-domain
/// lexicon. Eagle's View's Modern Concordance follows *Modern Concordance
/// to the New Testament* (Darton, Longman & Todd, 1976); it is a topical
/// concordance whose groupings are one editor's judgement, and the two
/// relations shown here are read off where it put each word (see
/// `ConcordanceRelation`). Louw-Nida is a different work under a licence
/// this app does not hold, and nothing on this surface may suggest
/// otherwise. [attribution] is not optional decoration either — the
/// permission the data ships under is conditional on it — so it is drawn
/// from the asset, unedited, at the foot of the section.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/concordance_reverse_index.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

class ConcordanceTopicsSection extends StatelessWidget {
  const ConcordanceTopicsSection({
    super.key,
    required this.title,
    required this.filings,
    required this.attribution,
    required this.locale,
    required this.chipFor,
    required this.onOpenTopic,
    this.maxNeighbours = 12,
  });

  /// The page's own section heading widget, so this block carries the
  /// same title style as "Word family" without restating it.
  final Widget title;

  final List<ConcordanceFiling> filings;

  /// `ConcordanceReverseIndex.attribution`, passed in so this widget can
  /// be built against a literal in a test without warming the service.
  final String attribution;

  final String locale;

  /// The page's related-word chip for a Strong's number, or null when
  /// the lexicon has no entry for it — 5,175 numbers are in the
  /// concordance and not all of them are in every lexicon build, and a
  /// neighbour the reader cannot open is still a neighbour worth naming.
  final Widget? Function(String strongs) chipFor;

  final void Function(int topicId) onOpenTopic;

  /// Neighbours drawn per filing before the row is summarised. One
  /// section runs to 94 of them ("Beget, be the father of - Bear, give
  /// birth to - Born: GENNAO"), which is a wall of chips rather than an
  /// answer; the count that follows says what was left off, the same way
  /// the Occurrences list says it.
  final int maxNeighbours;

  @override
  Widget build(BuildContext context) {
    if (filings.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final t = settings.wbType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 4),
        Text(
          uiStrings['strongsConcordanceNote']?[locale] ??
              'Where the Modern Concordance files this word, and which '
                  'Greek words it puts beside it.',
          style: TextStyle(
            fontSize: t.scaledSmall(11),
            color: scheme.onSurfaceVariant,
            height: 1.35,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
        const SizedBox(height: 8),
        for (final f in filings) ...[
          _Filing(
            filing: f,
            locale: locale,
            chipFor: chipFor,
            onOpenTopic: onOpenTopic,
            maxNeighbours: maxNeighbours,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          attribution,
          style: TextStyle(
            fontSize: t.scaledSmall(11),
            height: 1.35,
            color: scheme.onSurfaceVariant,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      ],
    );
  }
}

class _Filing extends StatelessWidget {
  const _Filing({
    required this.filing,
    required this.locale,
    required this.chipFor,
    required this.onOpenTopic,
    required this.maxNeighbours,
  });

  final ConcordanceFiling filing;
  final String locale;
  final Widget? Function(String strongs) chipFor;
  final void Function(int topicId) onOpenTopic;
  final int maxNeighbours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final t = settings.wbType;
    final senses = filing.headingLabels(locale);

    // Same sense first and the two never merged: a word that shares this
    // word's heading is a stronger statement than one that only shares
    // the section, and a single undifferentiated row of chips throws
    // away the only relation this data actually carries.
    final grouped = <ConcordanceRelation, List<String>>{};
    for (final n in filing.neighbours) {
      (grouped[n.relation] ??= <String>[]).add(n.strongs);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(WbMetrics.radiusSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onOpenTopic(filing.topicId),
            child: Text(
              filing.topicLabel(locale),
              style: TextStyle(
                fontSize: settings.fontSize - 1,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
                decoration: TextDecoration.underline,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            filing.sectionLabel(locale),
            style: TextStyle(
              fontSize: t.scaledSmall(12),
              color: scheme.onSurface,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          if (senses.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              // Interpunct rather than a bulleted list: nine senses down
              // the page pushes the neighbours — the reason the block
              // exists — below the fold on a phone.
              senses.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.scaledSmall(11),
                color: scheme.onSurfaceVariant,
                height: 1.35,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ],
          for (final relation in ConcordanceRelation.values)
            if ((grouped[relation] ?? const []).isNotEmpty)
              _NeighbourGroup(
                relation: relation,
                strongs: grouped[relation]!,
                locale: locale,
                chipFor: chipFor,
                maxNeighbours: maxNeighbours,
              ),
        ],
      ),
    );
  }
}

class _NeighbourGroup extends StatelessWidget {
  const _NeighbourGroup({
    required this.relation,
    required this.strongs,
    required this.locale,
    required this.chipFor,
    required this.maxNeighbours,
  });

  final ConcordanceRelation relation;
  final List<String> strongs;
  final String locale;
  final Widget? Function(String strongs) chipFor;
  final int maxNeighbours;

  static const _labels = <ConcordanceRelation, (String, String)>{
    ConcordanceRelation.sameSense: (
      'strongsConcordanceSameSense',
      'Same sense',
    ),
    ConcordanceRelation.sameFamily: (
      'strongsConcordanceSameFamily',
      'Same word family',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = context.watch<AppSettings>().wbType;
    final (key, fallback) = _labels[relation]!;
    final shown = strongs.take(maxNeighbours).toList();
    final hidden = strongs.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings[key]?[locale] ?? fallback,
            style: TextStyle(
              fontSize: t.scaledSmall(11),
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in shown) chipFor(g) ?? _NumberChip(strongs: g),
              if (hidden > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '… +$hidden',
                    style: TextStyle(
                      fontSize: t.scaledSmall(11),
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A neighbour the lexicon cannot open, drawn as the number alone.
///
/// The alternative was to drop it, which would make the concordance look
/// like it files fewer words than it does — and the number is still the
/// answer to "which other Strong's numbers sit beside it".
class _NumberChip extends StatelessWidget {
  const _NumberChip({required this.strongs});

  final String strongs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = context.watch<AppSettings>().wbType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WbMetrics.radiusSurface),
      ),
      child: Text(
        strongs,
        style: TextStyle(
          fontSize: t.scaledOriginal(WbMetrics.originalFloor),
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
