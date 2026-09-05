import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/chronology.dart' show Patriarch;
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/pages/hebrew_kings_page.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show
        LineageCohort,
        kDrawnTradition,
        kMaxYear,
        lineColor,
        streamColor,
        wheelStrings,
        yearLabel;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/date_hedge.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/kings_contemporaries.dart'
    show ContemporaryTally;
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/widgets/person_detail_sheet.dart';
import 'package:seeksparks/widgets/verse_popup_sheet.dart' show showVersePopup;

/// The wheel's detail sheets — [showPerson] through [showStream] — split
/// out of `RadialChronologyPage` so a second, horizontal view of the
/// same data can open the same sheets unchanged. See that class's own
/// comment for what the wheel draws; this file only shows what a tap
/// opens.
///
/// FORM-INDEPENDENT BY CONSTRUCTION. Every method here takes the model
/// object and the locale as PARAMETERS rather than reading them off
/// `State` fields, and the three sheets that let a reader select
/// something from inside the sheet — [showCluster], [showPower],
/// [showStream] — take that ability as a `select` callback parameter,
/// never as an abstract member the mixing-in `State` must implement. A
/// getter would tie this mixin to whichever selection model the FIRST
/// page happens to use, which is exactly the coupling a second,
/// unrelated page must not inherit. `_panTo` and `_reveal` stay on
/// `RadialChronologyPage` for the opposite reason: they pan an
/// `InteractiveViewer` and read wheel-only geometry, so parameterising
/// them would not make them reusable, only awkward — and nothing here
/// needs them.
///
/// PRIVACY FORCED A FEW RENAMES. Dart's `_private` names are scoped to
/// the FILE that declares them, not to the class, so a handful of
/// helpers this mixin shares with `RadialChronologyPage` — `s`, `fill`,
/// `find`, `colorsFor`, `creationYear` here, and the page's own
/// top-level `lineColor` — had to drop their leading underscore to stay
/// callable across the file the split created. Nothing else about them
/// changed: same signatures, same bodies, same behaviour. Helpers only
/// the sheets themselves call — `_readVerse`, `_jump`, `_regionLabel`,
/// `_basisText`, `_refRow`, `_personRow`, `_kAnchorEpoch` — stayed
/// private, because nothing outside this file needs them.
mixin WheelSheets<T extends StatefulWidget> on State<T> {
  String s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? wheelStrings[key]?[locale] ?? fallback;

  String fill(
      String key, String fallback, String locale, Map<String, Object> values) {
    var out = s(key, fallback, locale);
    for (final e in values.entries) {
      out = out.replaceAll('{${e.key}}', '${e.value}');
    }
    return out;
  }

  E? find<E>(List<E> xs, bool Function(E) test) {
    for (final x in xs) {
      if (test(x)) return x;
    }
    return null;
  }

  /// Per-band colours, computed from the FULL stream list rather than
  /// the visible one — hiding a band must not recolour the rest.
  Map<String, Color> colorsFor(WheelHistoryData data) {
    final byLine = <String, List<String>>{};
    for (final s in data.streams) {
      byLine.putIfAbsent(s.line, () => []).add(s.id);
    }
    final out = <String, Color>{};
    for (final s in data.streams) {
      final family = byLine[s.line]!;
      out[s.id] = streamColor(s.line, family.indexOf(s.id), family.length);
    }
    return out;
  }

  /// The creation year, or null when the asset does not carry it.
  ///
  /// One field, read in one place. `TimelineService` has parsed it by
  /// the time any wheel data exists (`WheelHistoryService.load` awaits
  /// it), and a null here means the layer draws nothing — never a
  /// literal. A silent -4000 is the calendar this anchor replaced, and
  /// it would put Methuselah's death four years after the flood spoke.
  int? get creationYear => TimelineService.instance.meta.creation?.year;

  /// Read the verse without leaving the wheel.
  ///
  /// The app already has a verse sheet the rest of the pages use, so
  /// this reuses it rather than inventing a second way to show a
  /// verse: same type, same versions, same behaviour, and nothing new
  /// on screen. A chart that asserts something about scripture should
  /// let the reader check the text in one tap, not send them away and
  /// lose their place on the wheel.
  Future<void> _readVerse(BuildContext context, String raw) async {
    final ref = parseReference(raw);
    if (ref == null) return;
    await showVersePopup(context, ref);
  }

  /// Leave the wheel and open the reader at the verse — the long way,
  /// for when the reader wants the surrounding chapter.
  Future<void> _jump(BuildContext context, String raw) async {
    final ref = parseReference(raw);
    if (ref == null) return;
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    navigateToReader(context);
  }

  // ── detail sheets ──────────────────────────────────────────────────

  Widget buildSheet(BuildContext sheet, List<Widget> children) =>
      ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: children,
        ),
      );

  Widget swatch(WbType t, Color c) =>
      Container(width: t.scaled(10), height: t.scaled(10), color: c);

  /// Tap reads the verse in place; long-press opens the reader at it.
  ///
  /// The reference is STORED in English — that is the form
  /// [parseReference] reads on the way back — and localised only here,
  /// at the print site. So `r` goes to the handlers and
  /// [localizedReferenceLabel] goes on screen; passing the localised
  /// string to either handler would break the tap.
  Widget _refRow(BuildContext context, List<String> refs, WbColors wb, WbType t,
          String locale) =>
      Wrap(spacing: 10, runSpacing: 4, children: [
        for (final r in refs)
          InkWell(
            onTap: () => _readVerse(context, r),
            onLongPress: () => _jump(context, r),
            child: Text(localizedReferenceLabel(r, locale),
                style: TextStyle(color: wb.link, fontSize: t.scaled(11))),
          ),
      ]);

  /// The people a record names, as tappable names in the page's own
  /// idiom — a `Wrap` of plain text, like [_refRow], and not a boxed
  /// chip. Two reasons: `workbench_theme.dart:16` forbids rounded
  /// corners and a copied chip carried two of them into the timeline
  /// page one phase ago; and the sheet already has a reference row that
  /// looks like this, so a second visual language here would suggest a
  /// difference in kind that does not exist.
  ///
  /// They are deliberately NOT [WbColors.link]. On this page that
  /// colour means "this leaves for the reader", which a verse chip does
  /// and a person does not — tapping a person opens their record
  /// without moving the wheel. The underline says tappable; the colour
  /// says where it goes.
  Widget _personRow(BuildContext context, List<WheelPersonLink> people,
          WbColors wb, WbType t, String locale) =>
      Wrap(spacing: 10, runSpacing: 4, children: [
        for (final p in people)
          InkWell(
            onTap: () => showPerson(context, p.id, locale),
            child: Text(
              p.nameFor(locale),
              style: TextStyle(
                color: wb.text,
                fontSize: t.scaled(11),
                decoration: TextDecoration.underline,
                decorationColor: wb.mutedText,
              ),
            ),
          ),
      ]);

  /// Open one person's family-tree record over the wheel.
  ///
  /// The lookup is synchronous and safe here because
  /// [WheelHistoryService.load] awaits the family tree before it
  /// returns any record — a page showing a person link is a page that
  /// is past that await. The null branch is a belt: the merge already
  /// drops an id the tree does not hold, so this row can only name
  /// people who resolve.
  Future<void> showPerson(
      BuildContext context, String personId, String locale) async {
    final person = FamilyTreeService.instance.byId(personId);
    if (person == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => PersonDetailSheet(
          person: person,
          locale: locale,
          scrollController: scrollController,
          onPersonTap: (other) {
            Navigator.of(sheetCtx).maybePop();
            showPerson(context, other.id, locale);
          },
        ),
      ),
    );
  }

  /// The asset's `region` in the reader's language.
  ///
  /// Returns empty for a value this app has no word for, which is the
  /// honest failure: a raw `mesopotamia` printed into a Chinese sheet
  /// would be worse than saying nothing, and
  /// `wheel_history_disclosure_test.dart` pins that every region in the
  /// asset has a label so the empty branch stays unreachable.
  String _regionLabel(String region, String locale) => switch (region) {
        'egypt' => s('wheelRegionEgypt', 'Egypt', locale),
        'mesopotamia' => s('wheelRegionMesopotamia', 'Mesopotamia', locale),
        'anatolia' => s('wheelRegionAnatolia', 'Anatolia', locale),
        'levant' => s('wheelRegionLevant', 'The Levant', locale),
        'persia' => s('wheelRegionPersia', 'Persia', locale),
        'greece' => s('wheelRegionGreece', 'Greece', locale),
        'rome' => s('wheelRegionRome', 'Rome', locale),
        'islamic' => s('wheelRegionIslamic', 'The Islamic world', locale),
        'europe' => s('wheelRegionEurope', 'Europe', locale),
        'asia' => s('wheelRegionAsia', 'Asia', locale),
        'americas' => s('wheelRegionAmericas', 'The Americas', locale),
        'modern' => s('wheelRegionModern', 'The modern world', locale),
        _ => '',
      };

  String _basisText(String basis, String locale) => switch (basis) {
        'scripture' => s('wheelBasisScripture', 'stated in scripture', locale),
        'scripture+thiele' =>
          s('wheelBasisThiele', 'interval from scripture', locale),
        'thiele' => s('wheelBasisThieleOnly', 'year from Thiele', locale),
        _ => s('wheelBasisConventional', 'conventional date', locale),
      };

  void showEvent(BuildContext context, WheelHistoryEvent e,
      WheelHistoryData data, String locale) {
    final wb = WbColors.of(context);
    final stream = data.streams.firstWhere((s) => s.id == e.stream,
        orElse: () => const WheelStream(id: '', line: 'none', names: {}));
    final approx = e.approximate ? approximatePrefix(locale) : '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      // `WbType.of` WATCHES, and a tap handler is not a build — resolving
      // it out here threw before the sheet ever opened, so no detail sheet
      // on this page could be opened in a debug build. Resolved against
      // the sheet's own context instead, which is also what keeps an open
      // sheet responsive to the Font Size slider. `WbColors.of` reads a
      // theme extension and is safe either side of the boundary.
      builder: (sheet) {
        final t = WbType.of(sheet);
        return buildSheet(sheet, [
          Row(children: [
            swatch(t, colorsFor(data)[stream.id] ?? lineColor(stream.line)),
            SizedBox(width: t.scaled(8)),
            Expanded(
              child: Text(e.titleFor(locale),
                  style: TextStyle(
                      color: wb.text,
                      fontSize: t.scaled(15),
                      fontWeight: FontWeight.w600)),
            ),
            Text(stream.nameFor(locale),
                style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          ]),
          SizedBox(height: t.scaled(4)),
          Text('$approx${yearLabel(e.year, locale)}',
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
          if (e.descFor(locale).isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(e.descFor(locale),
                style: TextStyle(color: wb.text, fontSize: t.scaled(12))),
          ],
          if (e.refs.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            _refRow(context, e.refs, wb, t, locale),
          ],
          SizedBox(height: t.scaled(10)),
          Text(
            e.approximate
                ? '${_basisText(e.basis, locale)} · '
                    '${s('wheelApprox', 'approximate', locale)}'
                : _basisText(e.basis, locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
          ),
          // The apparatus the merge left behind, in the timeline page's
          // own words — the same three blocks, the same shared strings,
          // so the two surfaces cannot drift into saying different
          // things about one event.
          if (e.septuagintYear != null) ...[
            SizedBox(height: t.scaled(4)),
            Text(
              s('timelineSeptuagintYear', 'On the Septuagint: {year}.', locale)
                  .replaceFirst('{year}', yearLabel(e.septuagintYear!, locale)),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
            ),
          ],
          // Kept apart from the reference row above and labelled: those
          // are where the event is told, these are where its year was
          // counted from, and on nine of them the two name no chapter
          // in common.
          if (e.datingRefs.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(
              s('timelineDatedBy', 'Dated by', locale),
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(4)),
            _refRow(context, e.datingRefs, wb, t, locale),
          ],
          // The people, under the timeline page's own label, for the
          // same reason the three blocks above reuse its wording: one
          // event, two surfaces, and nothing gained by a second
          // vocabulary. Last of the record's own content and above
          // nothing, because it is the only row here that opens
          // another sheet rather than adding to this one.
          if (e.people.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(
              uiStrings['timelinePeople']?[locale] ??
                  uiStrings['timelinePeople']?['en'] ??
                  'People',
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(4)),
            _personRow(context, e.people, wb, t, locale),
          ],
          // The seam. These eight are not counted back from the Thiele
          // anchor the way everything below Abraham is, and the wheel
          // draws both on one axis — which is the strongest invitation
          // in the app to read them as equally fixed. Disclosed, not
          // repaired: fixing it means fixing a year for the creation.
          if (e.timelineEra == 'antediluvian') ...[
            SizedBox(height: t.scaled(8)),
            Text(
              uiStrings['timelineAntediluvianBasis']?[locale] ??
                  uiStrings['timelineAntediluvianBasis']?['en'] ??
                  '',
              style: TextStyle(
                  color: wb.mutedText, fontSize: t.scaled(11), height: 1.5),
            ),
            SizedBox(height: t.scaled(4)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChronologyPage(),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: wb.link,
                ),
                child: Text(
                  s('timelineOpenChronology', 'Open Bible Chronology', locale),
                  style: TextStyle(
                      fontSize: t.scaled(11.5), fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ]);
      },
    );
  }

  /// The epoch both chains are anchored at.
  ///
  /// Abram leaving Haran is the one year the Masoretic and the
  /// Septuagint reckonings share on this axis — the wheel's own
  /// `abram_called`, from Thiele — so it is what turns the Greek's
  /// Anno Mundi figures into BC years without a second anchor being
  /// invented here: `creationLxx = creationMt + haran.mt - haran.lxx`.
  /// An id, not a figure; the numbers are the asset's.
  static const String _kAnchorEpoch = 'haran';

  /// One life, printed — and printed in BOTH traditions.
  ///
  /// WHY BOTH. The wheel DRAWS the Masoretic, because its axis is
  /// absolute and the Greek chain puts the creation 1,366 years
  /// earlier: carrying it would cost about a fifth of the angular
  /// resolution of all ~665 events for the sake of nineteen arcs, and
  /// would put a second flood 780 years before the first. But a chart
  /// that draws one tradition and never names the other has chosen in
  /// silence, which is the objection this app has answered three times
  /// before. So the ARC is Masoretic and the SHEET is both: each
  /// tradition's own Anno Mundi years, its own total, its own verses,
  /// under its own name out of the asset.
  ///
  /// THE ARC AND THE SPOKE MUST NOT DISAGREE. The birth year here and
  /// the birth year on this man's own event spoke are the same
  /// arithmetic on the same anchor — `_meta.creation.year` plus the
  /// figure — computed from one field, never from two.
  /// A rail mark's sheet: the year, and everybody the tree places in it.
  ///
  /// THE DISCLAIMER COMES FIRST, before the year is even repeated,
  /// because it is the most important thing on the sheet. All 192 of
  /// these people have an EMPTY `datingRefs` in `family_tree.json` —
  /// 191 `conventional`, one `thiele`, and not one resting on a verse.
  /// The year is where the genealogy PLACES them so that a tree can be
  /// drawn, and a reader who takes it for a date has been misled by
  /// this app rather than by the asset, which says so plainly.
  void showCohort(BuildContext context, LineageCohort cohort, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        return buildSheet(sheet, [
          Text(yearLabel(cohort.year, locale),
              style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(16),
                  fontWeight: FontWeight.w600)),
          SizedBox(height: t.scaled(4)),
          Text(
            s('wheelLineageNote', '', locale),
            style: TextStyle(
                color: wb.mutedText, fontSize: t.scaled(11), height: 1.4),
          ),
          SizedBox(height: t.scaled(12)),
          Text(
            fill('wheelLineageCount', '{n} people', locale,
                {'n': cohort.people.length}),
            style: TextStyle(
                color: wb.mutedText,
                fontSize: t.scaled(11),
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: t.scaled(4)),
          for (final p in cohort.people)
            InkWell(
              onTap: () {
                Navigator.of(sheet).pop();
                showPerson(context, p.id, locale);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                child: Row(children: [
                  Expanded(
                    child: Text(p.localizedName(locale),
                        style: TextStyle(
                            color: wb.link, fontSize: t.scaled(12.5))),
                  ),
                  if (p.role != null && p.role!.isNotEmpty)
                    Text(p.role!,
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11))),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  /// A ministry arc's own sheet.
  ///
  /// The note is the point of it. A reign arc can show its years and be
  /// understood; a ministry arc cannot, because the years were REACHED
  /// rather than read, and by a different route for almost every man.
  /// So the note — which says which verse fixed which end, and where
  /// the tighter window would be — is not an extra here, it is the
  /// record. Printed before the references, not after them.
  void showMinistry(
      BuildContext context, WheelMinistry ministry, String locale) {
    final wb = WbColors.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        final note = ministry.noteFor(locale);
        return buildSheet(sheet, [
          Text(ministry.nameFor(locale),
              style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(16),
                  fontWeight: FontWeight.w600)),
          SizedBox(height: t.scaled(4)),
          Text(
            '${yearLabel(ministry.start, locale)} – '
            '${yearLabel(ministry.end, locale)}',
            style: TextStyle(color: wb.text, fontSize: t.scaled(12.5)),
          ),
          SizedBox(height: t.scaled(3)),
          // WHAT THE SPAN RESTS ON, unconditionally and before anything
          // else the sheet says. Twenty-five of the thirty-nine are
          // `conventional`; a reader who is not told cannot tell those
          // from the fourteen the text and Thiele fix between them.
          Text(
            ministry.approximate
                ? '${_basisText(ministry.basis, locale)} · '
                    '${s('wheelApprox', 'approximate', locale)}'
                : _basisText(ministry.basis, locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
          ),
          if (note.isNotEmpty) ...[
            SizedBox(height: t.scaled(10)),
            Text(note,
                style: TextStyle(
                    color: wb.text, fontSize: t.scaled(12), height: 1.45)),
          ],
          if (ministry.refs.isNotEmpty) ...[
            SizedBox(height: t.scaled(12)),
            Text(s('wheelRefs', 'References', locale),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(3)),
            Wrap(
              spacing: t.scaled(6),
              runSpacing: t.scaled(4),
              children: [
                for (final ref in ministry.refs)
                  InkWell(
                    onTap: () {
                      Navigator.of(sheet).pop();
                      _jump(context, ref);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: t.scaled(6), vertical: t.scaled(2)),
                      decoration:
                          BoxDecoration(border: Border.all(color: wb.border)),
                      child: Text(ref,
                          style: TextStyle(
                              color: wb.accent, fontSize: t.scaled(11))),
                    ),
                  ),
              ],
            ),
          ],
          // The reigns the span was reached FROM, named rather than
          // implied. They are not a formula — see `WheelMinistry` — so
          // they are labelled as what they are: the anchors, not the
          // arithmetic.
          if (ministry.anchorKings.isNotEmpty) ...[
            SizedBox(height: t.scaled(10)),
            Text(
              '${s('wheelMinistryAnchors', 'Anchored on the reigns of', locale)}: '
              '${[
                for (final id in ministry.anchorKings)
                  HebrewKingsService.instance.cached
                          ?.byId(id)
                          ?.nameFor(locale) ??
                      id
              ].join(' · ')}',
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
            ),
          ],
        ]);
      },
    );
  }

  /// The sheet for a record that is not on the chart, and says so.
  ///
  /// SHAPED LIKE [showMinistry] AND MISSING ITS SECOND LINE, which is
  /// the whole design. A ministry sheet reads name / years / basis /
  /// note / references; this one reads name / "not drawn, and here is
  /// why not" / note / references. The reader who has just come from
  /// Isaiah's sheet sees the same furniture with the years taken out of
  /// it, which states the difference faster than any sentence could.
  ///
  /// THE REFERENCES ARE THE POINT OF THE SHEET, not an appendix. Every
  /// other claim on this wheel can be checked against a verse; a claim
  /// that a book supplies no anchor can only be checked by reading the
  /// verse that would have supplied one. So Joel 1:1 is tappable here
  /// for exactly the reason Isaiah 1:1 is tappable there — except that
  /// opening it is what proves the record right.
  ///
  /// No basis line, deliberately. `_basisText` answers "what does this
  /// year rest on", and there is no year; printing `conventional` over
  /// a record whose content is that no date can be reached would be the
  /// contradiction this sheet exists to remove.
  void showOmission(
      BuildContext context, WheelOmission omission, String locale) {
    final wb = WbColors.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        final note = omission.noteFor(locale);
        return buildSheet(sheet, [
          Text(omission.nameFor(locale),
              style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(16),
                  fontWeight: FontWeight.w600)),
          SizedBox(height: t.scaled(4)),
          Text(
            s(
                'wheelOmissionNoSpan',
                'Not drawn on this chart: the text gives no year to draw it '
                    'at.',
                locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11.5)),
          ),
          if (note.isNotEmpty) ...[
            SizedBox(height: t.scaled(10)),
            Text(note,
                style: TextStyle(
                    color: wb.text, fontSize: t.scaled(12), height: 1.45)),
          ],
          if (omission.refs.isNotEmpty) ...[
            SizedBox(height: t.scaled(12)),
            Text(s('wheelRefs', 'References', locale),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(3)),
            Wrap(
              spacing: t.scaled(6),
              runSpacing: t.scaled(4),
              children: [
                for (final ref in omission.refs)
                  InkWell(
                    onTap: () {
                      Navigator.of(sheet).pop();
                      _jump(context, ref);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: t.scaled(6), vertical: t.scaled(2)),
                      decoration:
                          BoxDecoration(border: Border.all(color: wb.border)),
                      child: Text(localizedReferenceLabel(ref, locale),
                          style: TextStyle(
                              color: wb.accent, fontSize: t.scaled(11))),
                    ),
                  ),
              ],
            ),
          ],
        ]);
      },
    );
  }

  /// A reign arc's own sheet.
  ///
  /// NOT a push to [HebrewKingsPage]. That page cannot be opened on a
  /// particular king — `showPower` already says so where it lists a
  /// kingdom's kings, and it declines to make its rows tappable for
  /// exactly that reason. A tap that landed the reader at the top of a
  /// 42-king chart would be a worse answer than none, so the arc
  /// answers here and offers the chart as a next step rather than as
  /// the destination.
  ///
  /// The years are `formatReignYears`, shared with that page, so the
  /// wheel and the chart cannot come to word the same reign differently.
  void showKing(BuildContext context, HebrewKing king, String locale) {
    final wb = WbColors.of(context);
    final houseKing = HebrewKingsService.instance.cached?.byId(king.house);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        final alt = king.altNames?[locale];
        final note = king.notes?[locale];

        Widget refRow(String label, String ref) => Padding(
              padding: EdgeInsets.symmetric(vertical: t.scaled(2)),
              child: InkWell(
                onTap: () {
                  Navigator.of(sheet).pop();
                  _jump(context, ref);
                },
                child: Row(children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11))),
                  ),
                  // LOCALISED for the eye, RAW for the jump. This row
                  // printed `ref` straight through, so a Chinese reader
                  // opening a king saw "1 Kings 16:29" — every other
                  // sheet on this page goes through
                  // `localizedReferenceLabel` and this one never did.
                  // It went unseen because the arcs that open these
                  // sheets were mostly too thin to tap; the finger-sized
                  // hit target of 2026-09-03 is what surfaced it.
                  Text(localizedReferenceLabel(ref, locale),
                      style: TextStyle(
                          color: wb.accent, fontSize: t.scaled(11.5))),
                ]),
              ),
            );

        return buildSheet(sheet, [
          Text(king.nameFor(locale),
              style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(16),
                  fontWeight: FontWeight.w600)),
          if (alt != null && alt.isNotEmpty)
            Text(alt,
                style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          SizedBox(height: t.scaled(4)),
          Text(
            [
              kingdomLabel(locale, king.kingdom),
              if (houseKing != null)
                (uiStrings['kingsHouseOf']?[locale] ?? 'House of {name}')
                    .replaceAll('{name}', houseKing.nameFor(locale)),
              formatReignYears(locale, king.reignStart, king.reignEnd),
            ].join(' · '),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11.5)),
          ),
          // THE ARC IS THE HULL, THE SPANS ARE THE REIGN. A co-regency
          // and the sole reign after it are drawn as one arc, because
          // two arcs for one man cannot be read as one man. So the
          // parts are named here — and for the ten kings whose arc is
          // not a single interval, this is the only place the wheel
          // says so. (Ten, counted off the asset: nine with more than
          // one span — the six Judean co-regents, Jeroboam II, and Omri
          // and Pekah, whose rival span precedes a sole one — plus
          // Tibni, whose one span is a rival claim. This comment used
          // to say seven, which is the number of CO-REGENCIES and not a
          // count of compound arcs at all.)
          //
          // The test is `hasCompoundReign` rather than the two clauses
          // written out, because written out here the `||` reached
          // `spans.first` on an empty list — the `StateError` the model
          // guards against one line above `isRival`.
          if (king.hasCompoundReign) ...[
            SizedBox(height: t.scaled(10)),
            Text(s('kingsReign', 'Reign', locale),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(3)),
            for (final span in king.spans)
              Text(
                '${spanKindLabel(locale, span.kind)} · '
                '${formatReignYears(locale, span.start, span.end)}',
                style: TextStyle(color: wb.text, fontSize: t.scaled(12)),
              ),
          ],
          if (note != null && note.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(note,
                style: TextStyle(
                    color: wb.mutedText, fontSize: t.scaled(11), height: 1.4)),
          ],
          SizedBox(height: t.scaled(12)),
          Text(s('kingsPassages', 'Where it is told', locale),
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600)),
          if (king.accessionRef != null)
            refRow(s('kingsAccession', 'Accession synchronism', locale),
                king.accessionRef!),
          if (king.kingsRef != null)
            refRow(s('kingsInKings', 'In Kings', locale), king.kingsRef!),
          if (king.chroniclesRef != null)
            refRow(s('kingsInChronicles', 'In Chronicles', locale),
                king.chroniclesRef!)
          // The absence is information, and the kings page says so in
          // the same words. A northern king with no Chronicles row and
          // no sentence would read as a gap in this app.
          else if (king.kingdom == Kingdom.israel)
            Padding(
              padding: EdgeInsets.only(top: t.scaled(2)),
              child: Text(
                s(
                    'kingsNoChronicles',
                    'Chronicles follows the line of David and gives the '
                        'northern kings no parallel account.',
                    locale),
                style: TextStyle(
                    color: wb.mutedText, fontSize: t.scaled(11), height: 1.4),
              ),
            ),
          // ON THE OTHER THRONE.
          //
          // The synchronism is the reason 1-2 Kings is one book and not
          // two, and it was the one thing this sheet could not say: a
          // reader who tapped Ahab's arc got Ahab's own years and had
          // to leave for the chart to learn that Asa and Jehoshaphat
          // stood opposite him.
          //
          // SAME DERIVATION AS THE CHART'S, not a second one — this
          // calls `contemporariesOf` on the loaded data, which is
          // `utils/kings_contemporaries.dart`, which is
          // `closedIntervalsOverlap`. The tally, the rival mark and the
          // caveat are the chart's own widgets, so the wheel and the
          // chart cannot come to word the same overlap differently.
          //
          // Rows DO open here, unlike the kingdom sheet's — this sheet
          // takes the king as a parameter, so a contemporary can be
          // shown in place rather than pointing at a page that opens on
          // no one in particular.
          //
          // AN EMPTY ANSWER IS PRINTED, NOT DROPPED. Until 2026-09-06
          // this block began `if (contemporaries.isEmpty) return []`,
          // which collapsed two different facts into the same silence:
          // David and Solomon have no other throne to be compared with,
          // and Hezekiah through Zedekiah — eight of the twenty Judean
          // kings, every one after Samaria fell in 722 — had one that
          // was empty. The chart said "· 0" and "No overlapping reign."
          // for those eight while the sheet said nothing, so the two
          // surfaces this comment claims cannot word the same overlap
          // differently were doing exactly that. Only the united
          // monarchy is silent now, and it is silent for a stated
          // reason: `contemporariesOf` returns empty by design there.
          ...(() {
            final data = HebrewKingsService.instance.cached;
            if (data == null) return const <Widget>[];
            if (king.kingdom == Kingdom.united) return const <Widget>[];
            final contemporaries = data.contemporariesOf(king);
            final tally = ContemporaryTally.of(contemporaries);
            final other = king.kingdom == Kingdom.judah
                ? Kingdom.israel
                : Kingdom.judah;
            return <Widget>[
              SizedBox(height: t.scaled(12)),
              Text(
                kingsContemporariesHeading(locale, other, tally.total),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: t.scaled(4)),
              if (contemporaries.isEmpty)
                kingsNoContemporariesLine(sheet, locale, size: t.scaled(11)),
              // The tally lines, the rival note and the basis line all
              // belong to a count that exists; the chart drops the same
              // three when the answer is nobody, and a caveat about how
              // Thiele's years could move an overlap is noise under a
              // reign that overlaps nothing at all.
              if (contemporaries.isNotEmpty) ...[
                kingsTallyLines(sheet, tally, other, locale),
                SizedBox(height: t.scaled(5)),
                for (final c in contemporaries)
                  InkWell(
                    onTap: () {
                      Navigator.of(sheet).pop();
                      showKing(context, c, locale);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                      child: Row(children: [
                        Flexible(
                          child: Text(
                            c.nameFor(locale),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: wb.accent, fontSize: t.scaled(11.5)),
                          ),
                        ),
                        if (c.isRival) ...[
                          SizedBox(width: t.scaled(5)),
                          kingsRivalBadge(sheet, locale, size: t.scaled(10)),
                        ],
                        const Spacer(),
                        Text(
                          formatReignYears(locale, c.reignStart, c.reignEnd),
                          style: TextStyle(
                              color: wb.mutedText, fontSize: t.scaled(11)),
                        ),
                      ]),
                    ),
                  ),
                if (tally.hasRivals) ...[
                  SizedBox(height: t.scaled(6)),
                  kingsRivalExplanation(sheet, locale, size: t.scaled(10.5)),
                ],
                // This sheet has no basis line above it the way the
                // kingdom sheet does, so the count carries its own.
                SizedBox(height: t.scaled(6)),
                kingsChronologyCaveat(sheet, locale, size: t.scaled(10.5)),
              ],
            ];
          })(),
          SizedBox(height: t.scaled(8)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HebrewKingsPage(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // `hebrewKings`, the key the wheel already opens this
              // page under from the power sheet — one label for one
              // destination, in one place.
              child: Text(s('hebrewKings', 'Kings of Judah & Israel', locale)),
            ),
          ),
        ]);
      },
    );
  }

  void showPatriarch(BuildContext context, Patriarch man, String locale) {
    final wb = WbColors.of(context);
    final chron = ChronologyService.instance.cached;
    final creation = creationYear;
    if (chron == null || creation == null) return;
    final anchor = find(chron.epochs, (e) => e.id == _kAnchorEpoch);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        final mt = man.figures[kDrawnTradition];

        /// One tradition's block: its name, the years it counts, the
        /// total it states, and the verses each figure rests on.
        List<Widget> tradition(String id, {required bool drawn}) {
          final f = man.figures[id];
          if (f == null) return const [];
          final name = chron.traditionById(id).nameFor(locale);
          // The BC year only where this app can honestly compute one:
          // the Masoretic from the derived anchor, the Septuagint from
          // the same anchor shifted by the one epoch both chains share.
          final shift = id == kDrawnTradition
              ? 0
              : (anchor == null
                  ? null
                  : (anchor.years[kDrawnTradition] ?? 0) -
                      (anchor.years[id] ?? 0));
          final bc = shift == null ? null : creation + shift + f.birthAm;
          final bcEnd = shift == null ? null : creation + shift + f.deathAm;
          final refs = f.refs.values.toSet().toList();
          return [
            SizedBox(height: t.scaled(8)),
            Text(
              drawn ? '$name · ${s('wheelLifespansNote', '', locale)}' : name,
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(3)),
            Text(
              [
                fill('wheelLifeAm', 'Anno Mundi {a}–{b}', locale,
                    {'a': f.birthAm, 'b': f.deathAm}),
                fill('wheelLifeYears', '{n} years', locale, {'n': f.lifespan}),
                if (bc != null && bcEnd != null)
                  '${yearLabel(bc, locale)} – ${yearLabel(bcEnd, locale)}',
              ].join(' · '),
              style: TextStyle(color: wb.text, fontSize: t.scaled(12)),
            ),
            // NOT `timelineSeptuagintYear`, and the reason is the
            // asset's own. That string's body is about Exodus 12:40 —
            // the Greek counting its 430 years in Egypt AND Canaan,
            // which shifts the exodus block by 215 — and
            // `bible_timeline.json`'s `_meta.septuagintYear` states
            // plainly that the pre-Abraham years are "not this shift
            // but a different number for each of them", and declines
            // to print one under that sentence for exactly this
            // reason. Printing 4193 BC under a paragraph about the
            // sojourn would be a figure the sentence does not
            // describe. So this block says what is actually true of a
            // Genesis 5 figure, and the year in it is derived.
            if (!drawn && bc != null) ...[
              SizedBox(height: t.scaled(3)),
              Text(
                fill('wheelLifeSeptuagintChain', '', locale,
                    {'year': yearLabel(creation + shift!, locale)}),
                style: TextStyle(
                    color: wb.mutedText, fontSize: t.scaled(11), height: 1.4),
              ),
            ],
            if (refs.isNotEmpty) ...[
              SizedBox(height: t.scaled(4)),
              _refRow(context, refs, wb, t, locale),
            ],
          ];
        }

        final person = FamilyTreeService.instance.byId(man.id);
        return buildSheet(sheet, [
          Row(children: [
            swatch(
                t, man.line == 'seth' ? lineColor('none') : lineColor('shem')),
            SizedBox(width: t.scaled(8)),
            Expanded(
              child: Text(man.nameFor(locale),
                  style: TextStyle(
                      color: wb.text,
                      fontSize: t.scaled(15),
                      fontWeight: FontWeight.w600)),
            ),
            Text(s('wheelLifespans', 'Genesis lifespans', locale),
                style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          ]),
          if (mt != null) ...[
            SizedBox(height: t.scaled(4)),
            Text(
              '${yearLabel(creation + mt.birthAm, locale)} – '
              '${yearLabel(creation + mt.deathAm, locale)} · '
              '${fill('wheelLifeYears', '{n} years', locale, {
                    'n': mt.lifespan
                  })}',
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12)),
            ),
          ],
          // The other spelling, when there is one. The reader may have
          // arrived here from the KJV's Genesis 5 and has to be told in
          // as many words that the arc named "Kenan" is the Cainan they
          // were reading about — the app cannot leave them to infer it
          // from four letters in common.
          if (man.nameKjv.isNotEmpty) ...[
            SizedBox(height: t.scaled(2)),
            Text(
              fill('wheelNameKjv', 'King James Version: {name}', locale,
                  {'name': man.nameKjv}),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
            ),
          ],
          SizedBox(height: t.scaled(8)),
          Text(
            s('wheelLifeContemporaries', '', locale),
            style: TextStyle(
                color: wb.mutedText, fontSize: t.scaled(11), height: 1.5),
          ),
          for (final id in [
            kDrawnTradition,
            ...chron.traditions
                .map((x) => x.id)
                .where((x) => x != kDrawnTradition)
          ])
            ...tradition(id, drawn: id == kDrawnTradition),
          SizedBox(height: t.scaled(10)),
          Text(_basisText('scripture+thiele', locale),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          // The whole chain the BC years hang on — 1 Kings 6:1 down to
          // Genesis 5:3 — under the timeline page's own label. Long, and
          // that length is the honest one.
          if (TimelineService
              .instance.meta.creation!.datingRefs.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(
              s('timelineDatedBy', 'Dated by', locale),
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(4)),
            _refRow(context, TimelineService.instance.meta.creation!.datingRefs,
                wb, t, locale),
          ],
          // The family-tree record, when the tree holds this man.
          //
          // FIVE ROWS WERE MISSING HERE AND NOTHING SAID SO. The lookup
          // is by the chart's own id, and the chart used to key five of
          // the twenty-five on the Authorised Version's spelling — enos,
          // cainan, mahalaleel, salah, nahor — while the tree keys them
          // enosh, kenan, mahalalel, shelah, nahor_elder. So those five
          // sheets simply had no "People" row, by the same rule
          // `_personRow` follows, which is to link what resolves and
          // claim nothing about what does not: the rule was right and
          // the key was wrong. The ids are the tree's now and all
          // twenty-five resolve. The null branch stays, because the rule
          // is still the rule — the wheel draws men the tree may not
          // hold — but it is no longer standing in for a defect.
          if (person != null) ...[
            SizedBox(height: t.scaled(8)),
            Text(
              uiStrings['timelinePeople']?[locale] ??
                  uiStrings['timelinePeople']?['en'] ??
                  'People',
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(4)),
            _personRow(
              context,
              [
                WheelPersonLink(id: man.id, names: man.names),
              ],
              wb,
              t,
              locale,
            ),
          ],
          SizedBox(height: t.scaled(4)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChronologyPage(),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: wb.link,
              ),
              child: Text(
                s('timelineOpenChronology', 'Open Bible Chronology', locale),
                style: TextStyle(
                    fontSize: t.scaled(11.5), fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]);
      },
    );
  }

  /// Everything one spoke stands for, when it stands for more than one
  /// event.
  ///
  /// This is the other half of the `+65` badge and the reason the badge
  /// can be told the truth: the events a rim has no room to name are
  /// not lost, they are one tap away, in year order, each opening its
  /// own sheet. Which one the rim names is stated here rather than left
  /// to be inferred — it is the earliest in the stretch, which is an
  /// arbitrary choice among the members and should read as one.
  void showCluster(BuildContext context, List<WheelHistoryEvent> events,
      WheelHistoryData data, String locale, void Function(String) select) {
    final wb = WbColors.of(context);
    final colors = colorsFor(data);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        return buildSheet(sheet, [
          Text(
            '${s('wheelEvents', 'Events', locale)} · ${events.length}',
            style: TextStyle(
                color: wb.text,
                fontSize: t.scaled(15),
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: t.scaled(2)),
          Text(
            '${yearLabel(events.first.year, locale)} – '
            '${yearLabel(events.last.year, locale)}',
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12)),
          ),
          SizedBox(height: t.scaled(6)),
          Text(
            s(
                'wheelClusterNote',
                'The rim has room for one name here. Tap any event to open it.',
                locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
          ),
          SizedBox(height: t.scaled(8)),
          for (final e in events)
            InkWell(
              onTap: () {
                Navigator.of(sheet).pop();
                select(e.id);
                showEvent(context, e, data, locale);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: t.scaled(4)),
                child: Row(children: [
                  swatch(t, colors[e.stream] ?? lineColor('none')),
                  SizedBox(width: t.scaled(8)),
                  Expanded(
                    child: Text(e.titleFor(locale),
                        style:
                            TextStyle(color: wb.text, fontSize: t.scaled(12))),
                  ),
                  SizedBox(width: t.scaled(8)),
                  Text(yearLabel(e.year, locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11))),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  void showPower(BuildContext context, WheelPower p, WheelHistoryData data,
      String locale, void Function(String) select) {
    final wb = WbColors.of(context);
    final stream = data.streams.firstWhere((s) => s.id == p.stream,
        orElse: () => const WheelStream(id: '', line: 'none', names: {}));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        return buildSheet(sheet, [
          Row(children: [
            swatch(t, colorsFor(data)[stream.id] ?? lineColor(stream.line)),
            SizedBox(width: t.scaled(8)),
            Expanded(
              child: Text(p.nameFor(locale),
                  style: TextStyle(
                      color: wb.text,
                      fontSize: t.scaled(15),
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          SizedBox(height: t.scaled(4)),
          Text(
              [
                '${yearLabel(p.start, locale)} – '
                    '${p.ongoing ? s('wheelPresent', 'present', locale) : yearLabel(p.end!, locale)}',
                // The place, beside the years. See `wheelRegion*`.
                if (_regionLabel(p.region, locale) case final where
                    when where.isNotEmpty)
                  where,
              ].join(' · '),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
          if (p.noteFor(locale).isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(p.noteFor(locale),
                style: TextStyle(color: wb.text, fontSize: t.scaled(12))),
          ],
          if (p.refs.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            _refRow(context, p.refs, wb, t, locale),
          ],
          SizedBox(height: t.scaled(10)),
          // Ask the record, do not assume. This line used to be a constant
          // "conventional date, not stated in scripture" — which the three
          // Israelite kingdoms contradict, and whose verses sit two lines
          // above it.
          Text(
            p.approximate
                ? '${_basisText(p.basis, locale)} · '
                    '${s('wheelApprox', 'approximate', locale)}'
                : _basisText(p.basis, locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
          ),
          // WHO REIGNED IN IT.
          //
          // A reader who taps the Kingdom of Judah is asking who, and
          // until now the sheet answered with two names in the note —
          // "from Rehoboam to Zedekiah" — and no way to reach the other
          // eighteen. The app charts all forty-two, on its own page,
          // and nothing on this wheel led there.
          //
          // Read live from `hebrew_kings.json`, never copied into the
          // wheel's asset: that file IS this app's Thiele chart, and a
          // copy would drift from it.
          //
          // The basis line sits directly above and covers these years —
          // for these three powers it already reads "interval from
          // scripture, year from Thiele" — which is why no reign here
          // carries a second disclosure of its own.
          //
          // Rows do not open anything. A king's record lives on a page
          // this sheet cannot select into, and a row that looks
          // tappable and merely closes the sheet is worse than a row
          // that plainly is not. The one tappable thing is the way out.
          ...(() {
            final kingdom = kWheelPowerKingdoms[p.id];
            if (kingdom == null) return const <Widget>[];
            final kings =
                HebrewKingsService.instance.cached?.ofKingdom(kingdom) ??
                    const <HebrewKing>[];
            if (kings.isEmpty) return const <Widget>[];
            return <Widget>[
              SizedBox(height: t.scaled(12)),
              Text(
                fill('wheelKings', 'Kings · {n}', locale, {'n': kings.length}),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: t.scaled(4)),
              for (final k in kings)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        k.spans.length > 1
                            ? '${k.nameFor(locale)} · '
                                '${s('kingsCoregency', 'co-regency', locale)}'
                            : k.nameFor(locale),
                        style:
                            TextStyle(color: wb.text, fontSize: t.scaled(11.5)),
                      ),
                    ),
                    Text(
                      '${yearLabel(k.reignStart, locale)} – '
                      '${yearLabel(k.reignEnd, locale)}',
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                  ]),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HebrewKingsPage(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: wb.link,
                  ),
                  child: Text(
                    s('hebrewKings', 'Kings of Judah & Israel', locale),
                    style: TextStyle(
                        fontSize: t.scaled(11.5), fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ];
          })(),
          // WHAT STOOD AT THE SAME TIME AS IT.
          //
          // The wheel draws a power as an arc and its events as spokes
          // on the same ring, and nothing said the two were related.
          // That relation is the one thing the printed chart carries
          // that this app did not — it nests a reign inside a kingdom
          // inside a people, so the geometry states the parentage.
          // Stated here in a heading instead, which is the form this
          // app has always used for containment (a band's sheet lists
          // its powers; the family tree indents; a book holds its
          // chapters).
          //
          // The heading says SPAN, not ownership, and that wording is
          // load-bearing: an event on this band inside these years is
          // not thereby an event of this power.
          ...(() {
            final end = p.ongoing ? kMaxYear : p.end!;
            final within = data
                .eventsOf(p.stream)
                .where((e) => e.year >= p.start && e.year <= end)
                .toList()
              ..sort((a, b) => a.year.compareTo(b.year));
            if (within.isEmpty) return const <Widget>[];
            return <Widget>[
              SizedBox(height: t.scaled(12)),
              Text(
                fill('wheelWithinSpan', 'Within this span · {n}', locale,
                    {'n': within.length}),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: t.scaled(4)),
              for (final e in within)
                InkWell(
                  onTap: () {
                    Navigator.of(sheet).pop();
                    select(e.id);
                    showEvent(context, e, data, locale);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                    child: Row(children: [
                      Expanded(
                        child: Text(e.titleFor(locale),
                            style: TextStyle(
                                color: wb.text, fontSize: t.scaled(11.5))),
                      ),
                      Text(yearLabel(e.year, locale),
                          style: TextStyle(
                              color: wb.mutedText, fontSize: t.scaled(11))),
                    ]),
                  ),
                ),
            ];
          })(),
        ]);
      },
    );
  }

  /// A band, opened: what it is, whom it descends from in Genesis 10 —
  /// every name a tappable verse — and everything it carries.
  void showStream(BuildContext context, WheelStream stream,
      WheelHistoryData data, String locale, void Function(String) select) {
    final wb = WbColors.of(context);
    final nations = data.nationsOf(stream.id);
    final powers = data.powersOf(stream.id)
      ..sort((a, b) => a.start.compareTo(b.start));
    final events = data.eventsOf(stream.id)
      ..sort((a, b) => a.year.compareTo(b.year));

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        return buildSheet(sheet, [
          Row(children: [
            swatch(t, colorsFor(data)[stream.id] ?? lineColor(stream.line)),
            SizedBox(width: t.scaled(8)),
            Expanded(
              child: Text(stream.nameFor(locale),
                  style: TextStyle(
                      color: wb.text,
                      fontSize: t.scaled(16),
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          if (nations.isNotEmpty) ...[
            SizedBox(height: t.scaled(10)),
            Text(s('wheelDescent', 'Descent in Genesis 10', locale),
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(12),
                    fontWeight: FontWeight.w600)),
            for (final n in nations)
              Padding(
                padding: EdgeInsets.only(top: t.scaled(4)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.nameFor(locale),
                              style: TextStyle(
                                  color: wb.text, fontSize: t.scaled(12))),
                          if (n.noteFor(locale).isNotEmpty)
                            Text(n.noteFor(locale),
                                style: TextStyle(
                                    color: wb.mutedText,
                                    fontSize: t.scaled(11))),
                        ],
                      ),
                    ),
                    SizedBox(width: t.scaled(8)),
                    InkWell(
                      onTap: () => _readVerse(context, n.ref),
                      onLongPress: () => _jump(context, n.ref),
                      child: Text(localizedReferenceLabel(n.ref, locale),
                          style: TextStyle(
                              color: wb.link, fontSize: t.scaled(11))),
                    ),
                  ],
                ),
              ),
          ],
          if (powers.isNotEmpty) ...[
            SizedBox(height: t.scaled(12)),
            Text('${s('wheelPowers', 'Powers', locale)} · ${powers.length}',
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(12),
                    fontWeight: FontWeight.w600)),
            for (final p in powers)
              Padding(
                padding: EdgeInsets.only(top: t.scaled(3)),
                child: Row(children: [
                  Expanded(
                    child: Text(p.nameFor(locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(11.5))),
                  ),
                  Text(
                      '${yearLabel(p.start, locale)} – '
                      '${p.ongoing ? s('wheelPresent', 'present', locale) : yearLabel(p.end!, locale)}',
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11))),
                ]),
              ),
          ],
          if (events.isNotEmpty) ...[
            SizedBox(height: t.scaled(12)),
            Text('${s('wheelEvents', 'Events', locale)} · ${events.length}',
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(12),
                    fontWeight: FontWeight.w600)),
            // These rows open. They did not until 2026-08-25: a stream's
            // sheet named every event on it and offered no way to reach
            // one, so a reader who found what they were looking for here
            // had to go back and hunt the rim for a tick. That is the
            // same defect the `+n` badge exists to end — an event the
            // wheel names and the reader cannot open — and the powers
            // above are left alone precisely because they do NOT have
            // it: a power occupies a band, and tapping the band opens it.
            for (final e in events)
              InkWell(
                onTap: () {
                  Navigator.of(sheet).pop();
                  select(e.id);
                  showEvent(context, e, data, locale);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                  child: Row(children: [
                    Expanded(
                      child: Text(e.titleFor(locale),
                          style: TextStyle(
                              color: wb.text, fontSize: t.scaled(11.5))),
                    ),
                    Text(yearLabel(e.year, locale),
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11))),
                  ]),
                ),
              ),
          ],
        ]);
      },
    );
  }
}
