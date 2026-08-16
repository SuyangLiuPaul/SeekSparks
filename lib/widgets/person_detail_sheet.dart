import 'dart:async';

import 'package:flutter/material.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/utils/biblical_role.dart' show localizedRole;
import 'package:seeksparks/utils/floating_toast.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/utils/navigate_to_reader.dart';

/// Bottom sheet showing the full record for one [BiblicalPerson].
/// Sections (in render order):
///   - name + life-years header
///   - localized 1-2 sentence summary
///   - parents (chips, tap to navigate to their record)
///   - spouses (chips, tap to navigate)
///   - children (chips, tap to navigate)
///   - patrilineal ancestry trail (collapsed; expand to see lineage)
///   - verse references (chips, tap to jump the reader to the verse)
class PersonDetailSheet extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ScrollController scrollController;

  /// Called when the user taps another person's chip (parent /
  /// spouse / child / ancestor). The host re-opens this same sheet
  /// for the new person, so the user can hop along the lineage.
  final void Function(BiblicalPerson)? onPersonTap;

  const PersonDetailSheet({
    super.key,
    required this.person,
    required this.locale,
    required this.scrollController,
    this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final svc = FamilyTreeService.instance;
    final father = person.fatherId == null ? null : svc.byId(person.fatherId!);
    final mother = person.motherId == null ? null : svc.byId(person.motherId!);
    final spouses = [
      for (final id in person.spouseIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];
    final children = [
      for (final id in person.childIds)
        if (svc.byId(id) != null) svc.byId(id)!,
    ];
    final years = person.displayYears(locale);

    // Logos-style "associated trees" surface — sibling chips plus
    // a chip for the closest tribe / role-tagged ancestor (e.g.
    // for Aaron: Levi (PRIESTLY TRIBE); for Solomon: Judah (ROYAL
    // TRIBE)). These act as one-tap shortcuts to lateral context
    // without the user having to walk back up the chain manually.
    final siblings = _siblingsOf(person, svc);
    final tribeAncestor = _closestTribeAncestor(person, svc);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Drag handle. Square, like everything else — a 2px-rounded
        // 4px-tall bar is a rounded corner nobody can see, so the
        // radius buys nothing and costs the rule.
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            color: wb.border,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.localizedName(locale),
                    style: TextStyle(
                      fontSize: t.scaled(22),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (years.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      years,
                      style: TextStyle(
                        fontSize: t.scaled(13),
                        color: wb.mutedText,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Copy-all button: copies the rendered detail content
            // as plain text to the clipboard. The button is a
            // StatefulWidget so we can flip its icon to a green
            // check-mark for 2 seconds — visible feedback that
            // doesn't depend on the SnackBar showing through the
            // modal sheet's surface.
            _CopyAllButton(
              locale: locale,
              onCopy: () => _copyAll(
                context: context,
                father: father,
                mother: mother,
                spouses: spouses,
                children: children,
                siblings: siblings,
                tribeAncestor: tribeAncestor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          person.localizedSummary(locale),
          style: TextStyle(
            fontSize: t.scaled(14),
            color: wb.text,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 16),
        if (father != null || mother != null)
          _section(
            wb: wb,
            t: t,
            label: uiStrings['familyTreeParents']?[locale] ?? 'Parents',
            children: [
              if (father != null)
                _personChip(context, father, wb,
                    prefix: uiStrings['familyTreeFather']?[locale] ?? 'Father'),
              if (mother != null)
                _personChip(context, mother, wb,
                    prefix: uiStrings['familyTreeMother']?[locale] ?? 'Mother'),
            ],
          ),
        if (spouses.isNotEmpty)
          _section(
            wb: wb,
            t: t,
            label: spouses.length == 1
                ? (uiStrings['familyTreeSpouse']?[locale] ?? 'Spouse')
                : (uiStrings['familyTreeSpouses']?[locale] ?? 'Spouses'),
            children: [
              for (final s in spouses) _personChip(context, s, wb),
            ],
          ),
        if (children.isNotEmpty)
          _section(
            wb: wb,
            t: t,
            label: uiStrings['familyTreeChildren']?[locale] ?? 'Children',
            children: [
              for (final c in children) _personChip(context, c, wb),
            ],
          ),
        if (siblings.isNotEmpty)
          _section(
            wb: wb,
            t: t,
            label: uiStrings['familyTreeSiblings']?[locale] ?? 'Siblings',
            children: [
              for (final s in siblings) _personChip(context, s, wb),
            ],
          ),
        if (tribeAncestor != null)
          _section(
            wb: wb,
            t: t,
            label: uiStrings['familyTreeTribeLine']?[locale] ?? 'Tribe / line',
            children: [
              _personChip(context, tribeAncestor, wb),
            ],
          ),
        if (person.refs.isNotEmpty) ...[
          const SizedBox(height: 4),
          _section(
            wb: wb,
            t: t,
            label: uiStrings['familyTreeReferences']?[locale] ??
                'Verse references',
            children: [
              for (final ref in person.refs) _refChip(context, ref, wb),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _AncestryTrail(person: person, locale: locale),
      ],
    );
  }

  /// Format the visible detail-sheet content as plain text and
  /// copy to the system clipboard. Includes the patrilineal trail
  /// (Adam → … → person) per the user's request. Uses the user's
  /// current locale for all names + summary + section labels.
  Future<bool> _copyAll({
    required BuildContext context,
    required BiblicalPerson? father,
    required BiblicalPerson? mother,
    required List<BiblicalPerson> spouses,
    required List<BiblicalPerson> children,
    required List<BiblicalPerson> siblings,
    required BiblicalPerson? tribeAncestor,
  }) async {
    String namesOf(List<BiblicalPerson> xs) =>
        xs.map((p) => p.localizedName(locale)).join(', ');

    // Read before the first await — after it the element may be gone.
    final version = context.read<MainProvider>().currentVersion;
    final wb = WbColors.of(context);

    // Patrilineal trail Adam → … → person, awaited up-front.
    final svc = FamilyTreeService.instance;
    final trail = await svc.patrilineage(person);

    final years = person.displayYears(locale);
    final buf = StringBuffer();
    buf.writeln(person.localizedName(locale));
    if (years.isNotEmpty) buf.writeln(years);
    if ((person.role ?? '').isNotEmpty) {
      buf.writeln(
          '${uiStrings['familyTreeRole']?[locale] ?? 'Role'}: ${localizedRole(person.role!, locale)}');
    }
    buf.writeln();
    buf.writeln(person.localizedSummary(locale));
    buf.writeln();

    if (father != null || mother != null) {
      final parts = <String>[];
      if (father != null) {
        parts.add(
            '${uiStrings['familyTreeFather']?[locale] ?? 'Father'}: ${father.localizedName(locale)}');
      }
      if (mother != null) {
        parts.add(
            '${uiStrings['familyTreeMother']?[locale] ?? 'Mother'}: ${mother.localizedName(locale)}');
      }
      buf.writeln(
          '${uiStrings['familyTreeParents']?[locale] ?? 'Parents'}: ${parts.join(' · ')}');
    }
    if (spouses.isNotEmpty) {
      final label = spouses.length == 1
          ? (uiStrings['familyTreeSpouse']?[locale] ?? 'Spouse')
          : (uiStrings['familyTreeSpouses']?[locale] ?? 'Spouses');
      buf.writeln('$label: ${namesOf(spouses)}');
    }
    if (children.isNotEmpty) {
      buf.writeln(
          '${uiStrings['familyTreeChildren']?[locale] ?? 'Children'}: ${namesOf(children)}');
    }
    if (siblings.isNotEmpty) {
      buf.writeln(
          '${uiStrings['familyTreeSiblings']?[locale] ?? 'Siblings'}: ${namesOf(siblings)}');
    }
    if (tribeAncestor != null) {
      buf.writeln(
          '${uiStrings['familyTreeTribeLine']?[locale] ?? 'Tribe / line'}: ${tribeAncestor.localizedName(locale)}');
    }

    // Patrilineal ancestry — Adam → … → father → person, top-down.
    if (trail.isNotEmpty) {
      buf.writeln();
      buf.writeln(
          '${uiStrings['familyTreeAncestry']?[locale] ?? 'Patrilineal ancestry'}:');
      final chainTopDown = [
        for (final a in trail.reversed) a.localizedName(locale),
        person.localizedName(locale),
      ];
      buf.writeln('  ${chainTopDown.join(' → ')}');
    }

    if (person.refs.isNotEmpty) {
      buf.writeln();
      buf.writeln(
          '${uiStrings['familyTreeReferences']?[locale] ?? 'Verse references'}:');
      for (final r in person.refs) {
        buf.writeln('  • ${_localizedRef(r, version)}');
      }
    }

    final payload = buf.toString().trim();
    final copied = await ClipboardHelper.copyText(payload);
    if (!copied) {
      if (!context.mounted) return false;
      showFloatingToast(
        context,
        message: uiStrings['familyTreeCopyFailedToast']?[locale] ??
            'Copy failed — clipboard not available',
        icon: Icons.error_outline_rounded,
        background: Theme.of(context).colorScheme.error,
      );
      return false;
    }
    if (!context.mounted) return true;
    showFloatingToast(
      context,
      message:
          uiStrings['familyTreeCopiedToast']?[locale] ?? 'Copied to clipboard',
      icon: Icons.check_circle_rounded,
      background: wb.strongsLexical,
    );
    return true;
  }

  /// People with the same father OR mother as [p], excluding [p].
  /// Walks both parents' childIds + dedupes; preserves ordering.
  List<BiblicalPerson> _siblingsOf(BiblicalPerson p, FamilyTreeService svc) {
    final out = <BiblicalPerson>[];
    final seen = <String>{p.id};
    void addSiblingsFrom(String? parentId) {
      if (parentId == null) return;
      final parent = svc.byId(parentId);
      if (parent == null) return;
      for (final cid in parent.childIds) {
        if (seen.add(cid)) {
          final c = svc.byId(cid);
          if (c != null) out.add(c);
        }
      }
    }

    addSiblingsFrom(p.fatherId);
    addSiblingsFrom(p.motherId);
    return out;
  }

  /// Walk up the father / mother chain and return the closest
  /// ancestor whose [BiblicalPerson.role] contains "TRIBE" — i.e.
  /// the named tribe / line this person belongs to. e.g. Aaron →
  /// Levi (PRIESTLY TRIBE); Solomon → Judah (ROYAL TRIBE). Returns
  /// null when no ancestor is tribe-labelled (Adam → Noah etc.).
  BiblicalPerson? _closestTribeAncestor(
      BiblicalPerson p, FamilyTreeService svc) {
    var cur = p;
    for (var i = 0; i < 200; i++) {
      final pid = cur.fatherId ?? cur.motherId;
      if (pid == null) return null;
      final next = svc.byId(pid);
      if (next == null) return null;
      if ((next.role ?? '').toUpperCase().contains('TRIBE')) {
        return next;
      }
      cur = next;
    }
    return null;
  }

  /// A labelled group of chips.
  ///
  /// The label is muted, not [WbColors.link]: in this workspace the link
  /// hue means "this jumps somewhere", and "Parents" does not. Spending
  /// it on every section heading is what made the one thing here that
  /// IS a link — a verse reference — indistinguishable from furniture.
  Widget _section({
    required WbColors wb,
    required WbType t,
    required String label,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: t.scaled(12),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: wb.mutedText,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: children,
          ),
        ],
      ),
    );
  }

  /// A person you can hop to.
  ///
  /// The `backgroundColor`/`side` overrides are gone: `workbenchTheme`'s
  /// `chipTheme` is already `paneBg` behind a square [WbColors.border]
  /// hairline, and the old `surfaceContainerHighest.withValues(alpha:
  /// 0.6)` was a translucent fill over a sheet — it read as a card.
  Widget _personChip(
    BuildContext context,
    BiblicalPerson p,
    WbColors wb, {
    String? prefix,
  }) {
    final years = p.displayYears(locale);
    final t = WbType.of(context);
    return ActionChip(
      avatar: Icon(Icons.person_outline, size: 14, color: wb.mutedText),
      label: Text(
        prefix == null
            ? '${p.localizedName(locale)}${years.isEmpty ? '' : '  ($years)'}'
            : '$prefix: ${p.localizedName(locale)}',
        style: TextStyle(fontSize: t.scaled(12)),
      ),
      onPressed: () => onPersonTap?.call(p),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  /// A verse reference that jumps the reader.
  ///
  /// This is the one chip on the sheet that leaves the family tree, so
  /// it is the one that gets [WbColors.link] — on the INK, label and
  /// glyph both. The old version put a `primaryContainer` wash behind it
  /// instead, which is a seed pastel the workbench theme does not
  /// override and which vanishes on the paper palette.
  Widget _refChip(BuildContext context, String ref, WbColors wb) {
    final version = context.read<MainProvider>().currentVersion;
    final t = WbType.of(context);
    return ActionChip(
      avatar: Icon(Icons.menu_book_outlined, size: 14, color: wb.link),
      label: Text(
        _localizedRef(ref, version),
        style: TextStyle(fontSize: t.scaled(12), color: wb.link),
      ),
      onPressed: () => _jumpToRef(context, ref),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  /// Render the ref's book name the way the reader will show it.
  ///
  /// [version] is the reading version, and it is not optional detail
  /// (#283): a reference printed 创世记 that opens a page headed 創世記
  /// is the same book spelled two ways in one round-trip. The book name
  /// follows the TEXT, falling back to the UI locale only where the
  /// version has no opinion.
  ///
  /// This delegates rather than re-deriving. The hand-rolled version it
  /// replaces rebuilt the tail with
  /// `parsed.toString().replaceFirst(englishBook, '')`, which is the
  /// same formatting logic spelled a second, more fragile way — it also
  /// dropped everything after the first `;` in a multi-book ref.
  String _localizedRef(String raw, String? version) =>
      localizedReferenceLabel(raw, locale, version);

  Future<void> _jumpToRef(BuildContext context, String raw) async {
    // Take only the first segment of `;`-separated chains so the
    // parser handles e.g. "Genesis 1:26-27" cleanly.
    final ref = parseReference(raw);
    if (ref == null) {
      final msg = (uiStrings['couldNotParseRef']?[locale] ??
              "Couldn't parse reference: {ref}")
          .replaceFirst('{ref}', raw);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    navigateToReader(context);
  }
}

/// Copy-all icon button with built-in success feedback. After a
/// successful copy, the icon flips to a green check-mark for 2
/// seconds — visible feedback that doesn't depend on the toast
/// SnackBar being on top of the bottom sheet.
class _CopyAllButton extends StatefulWidget {
  final String locale;
  final Future<bool> Function() onCopy;
  const _CopyAllButton({
    required this.locale,
    required this.onCopy,
  });

  @override
  State<_CopyAllButton> createState() => _CopyAllButtonState();
}

class _CopyAllButtonState extends State<_CopyAllButton> {
  bool _justCopied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final ok = await widget.onCopy();
    if (!mounted || !ok) return;
    setState(() => _justCopied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return IconButton(
      tooltip: _justCopied
          ? (uiStrings['familyTreeCopiedToast']?[widget.locale] ?? 'Copied')
          : (uiStrings['familyTreeCopyAll']?[widget.locale] ?? 'Copy all info'),
      onPressed: _justCopied ? null : _handleTap,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: _justCopied
            ? Icon(
                Icons.check_circle_rounded,
                key: const ValueKey('check'),
                size: 22,
                // The workbench's green, which is already tuned for all
                // three palettes — including paper, where a raw
                // Colors.green on cream is the one that goes muddy.
                color: wb.strongsLexical,
              )
            : Icon(
                Icons.copy_rounded,
                key: const ValueKey('copy'),
                size: 20,
                color: wb.link,
              ),
      ),
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Collapsible patrilineal trail — Adam → … → person. Useful for
/// orienting where this person sits in the canonical line. Hidden
/// by default to keep the sheet focused on immediate family; the
/// section header is tappable to reveal/hide.
class _AncestryTrail extends StatefulWidget {
  final BiblicalPerson person;
  final String locale;
  const _AncestryTrail({
    required this.person,
    required this.locale,
  });

  @override
  State<_AncestryTrail> createState() => _AncestryTrailState();
}

class _AncestryTrailState extends State<_AncestryTrail> {
  bool _expanded = false;
  List<BiblicalPerson>? _trail;

  @override
  void initState() {
    super.initState();
    FamilyTreeService.instance
        .patrilineage(widget.person)
        .then((t) => mounted ? setState(() => _trail = t) : null);
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final trail = _trail;
    if (trail == null || trail.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: wb.mutedText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    uiStrings['familyTreeAncestry']?[widget.locale] ??
                        'Patrilineal ancestry',
                    style: TextStyle(
                      fontSize: t.scaled(12),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: wb.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            Text(
              // Reverse so the trail reads top-down: Adam → … → father → person.
              [
                for (final a in trail.reversed) a.localizedName(widget.locale),
                widget.person.localizedName(widget.locale),
              ].join(' → '),
              style: TextStyle(
                fontSize: t.scaled(13),
                color: wb.text,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
