/// The readout under a chronology cursor: which year, and what happened
/// in it.
///
/// ONE BAR, TWO FORMS. The wheel and the strip draw the same 851 events
/// and the same reigns, lifespans and bands; when the owner asked for a
/// year line — 「没有线根本不知道哪一年，然后那一年也要显示当年发生什么
/// 事情」 — the answer had to be the same on both, or the two views
/// would start telling a reader two different things about one year.
/// So the readout is a widget, not a method on either page: the pages
/// own the CURSOR (an x on a strip, an angle on a wheel are not the
/// same gesture) and share the ANSWER.
///
/// A ROW OF THE LAYOUT, NOT AN OVERLAY. The reader put the cursor on a
/// year in order to look at that part of the chart, and a panel that
/// covers the part just pointed at is the crosshair defect in a second
/// form — the same reason `_placeCursor` deliberately does not scroll.
/// Both pages give it its own height in a `Column`.
///
/// AND IT IS ALWAYS THERE, EVEN WITH NO CURSOR. The first cut rendered
/// this only once a year had been picked, and that was the SAME defect
/// wearing a different hat: appearing took ~90 px out of the chart, so
/// the wheel — whose `side` is `min(width, height)` — rescaled by about
/// a tenth the instant you pointed at it, moving everything you had
/// just pointed at. Two existing wheel tests caught it by tapping a
/// computed point twice. So the row is permanent and its collapsed
/// height is fixed: with no cursor it holds [hint] and an empty chip
/// lane of exactly the height the chips will occupy. The cost is a
/// strip of chrome the reader always pays for; what it buys is a chart
/// that never moves under them, and an affordance that says the chart
/// can be asked about a year before anyone has guessed that it can.
///
/// IT NAMES NOTHING ITSELF. Every label comes back through [label] and
/// every tap goes out through [onOpen], because resolving an id to a
/// name is exactly where the two forms already differ (one has kings in
/// a lane, the other on an annulus) and is exactly where they must not
/// drift. The bar holds the shape; the page holds the vocabulary.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/strip_lanes.dart' show StripLaneKind;
import 'package:seeksparks/utils/year_digest.dart';

class YearDigestBar extends StatefulWidget {
  const YearDigestBar({
    super.key,
    required this.digest,
    required this.yearText,
    required this.hint,
    required this.label,
    required this.onOpen,
    required this.onClear,
    required this.s,
    required this.fill,
    this.onYear,
    this.minYear,
    this.maxYear,
  });

  /// Null before the reader has placed a cursor — the bar still draws,
  /// at exactly the same height, showing [hint].
  final YearDigest? digest;

  /// The year, already written the way this app writes years — the
  /// pages' shared `yearLabel`, passed in rather than called here so
  /// this file needs nothing from either page.
  final String yearText;

  /// What the bar says with no cursor placed.
  final String hint;

  final String Function(YearDigestItem item) label;
  final void Function(YearDigestItem item) onOpen;
  final VoidCallback onClear;

  final String Function(String key, String fallback) s;
  final String Function(String key, String fallback, Map<String, Object> values)
      fill;

  /// Sweep the cursor across the whole axis, or null for no scrubber.
  ///
  /// yswords' chronology chart has had one of these since it shipped,
  /// and it is the control that makes a cursor a READING instrument
  /// rather than a pointing one: you drag and watch the readout change,
  /// which is how you find the year something started without knowing
  /// where on the chart to look.
  ///
  /// It is COARSE on purpose and cannot be otherwise — 6226 years
  /// across a 1000 px bar is six years a pixel — so it is the second
  /// control, not the only one: pointing at the chart is the fine one,
  /// and both write the same [YearDigest.year].
  final void Function(int year)? onYear;
  final int? minYear;
  final int? maxYear;

  @override
  State<YearDigestBar> createState() => _YearDigestBarState();
}

class _YearDigestBarState extends State<YearDigestBar> {
  /// Collapsed to start. A reader who has just placed a cursor wants
  /// the year and the headline; the seven hundred lifespans that were
  /// merely in progress are context, and context that opens itself is
  /// how a readout becomes a wall.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final digest = widget.digest;
    final happened = digest?.happened ?? const <YearDigestItem>[];
    final ongoing = digest?.ongoing ?? const <YearDigestItem>[];
    final onLives = digest?.ongoingOf(StripLaneKind.lives) ?? 0;
    final onKings = digest?.ongoingOf(StripLaneKind.kings) ?? 0;
    final onOther = ongoing.length - onLives - onKings;

    final summary = [
      if (onLives > 0)
        widget.fill('chronoYearAlive', '{n} alive', {'n': onLives}),
      if (onKings > 0)
        widget.fill('chronoYearReigning', '{n} reigning', {'n': onKings}),
      if (onOther > 0)
        widget.fill('chronoYearUnderWay', '{n} under way', {'n': onOther}),
    ].join(' · ');

    // The one number every other height in this widget is measured
    // against — see the class doc on why the collapsed bar may not
    // change height when a cursor appears.
    final chipLaneH = t.scaled(30);

    return Container(
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(top: BorderSide(color: wb.border)),
      ),
      // TIGHT ON PURPOSE. Every pixel this row takes comes out of the
      // chart above it, and on the wheel that is not a crop but a
      // RESCALE — `side` is `min(width, height)`, and the sub-rings are
      // already the wheel's weakest target at about 8.7 px. So the
      // buttons lose their 48 px Material slot, the scrubber gets the
      // height of its own thumb, and nothing here is padded twice.
      // The home indicator sits over this row otherwise. Found by
      // running the wheel on an iPhone 17 simulator: the chip lane is
      // the bottom-most thing on the page, so `viewPadding.bottom` is
      // the difference between a tappable chip and one under the bar
      // the OS draws. `viewPadding`, not `padding` — the latter is zero
      // once something else in the tree has consumed the inset, and
      // this widget is the last row of a `Column`, not inside a
      // `Scaffold` body that already ate it.
      padding: EdgeInsets.fromLTRB(t.scaled(12), t.scaled(2), t.scaled(4),
          t.scaled(4) + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (digest == null)
              Expanded(
                child: Text(
                  widget.hint,
                  key: const ValueKey('chronoYearHint'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12)),
                ),
              )
            else ...[
              Text(
                widget.yearText,
                key: const ValueKey('chronoYearReadout'),
                style: TextStyle(
                  color: wb.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: t.scaled(14),
                ),
              ),
              SizedBox(width: t.scaled(10)),
              Expanded(
                child: Text(
                  summary.isEmpty
                      ? widget.s('chronoYearNothing', 'nothing dated here')
                      : summary,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
                ),
              ),
            ],
            // Both buttons keep their SLOT whatever the state, so the
            // row cannot change height or reflow when a cursor lands.
            _slot(
              t,
              digest == null || digest.isEmpty
                  ? null
                  : IconButton(
                      iconSize: t.scaled(17),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: _expanded
                          ? widget.s('chronoYearCollapse', 'Less')
                          : widget.s('chronoYearExpand', 'More'),
                      icon: Icon(
                          _expanded ? Icons.expand_more : Icons.expand_less,
                          color: wb.mutedText),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
            ),
            _slot(
              t,
              digest == null
                  ? null
                  : IconButton(
                      iconSize: t.scaled(17),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip:
                          widget.s('chronoYearClear', 'Clear the year line'),
                      icon: Icon(Icons.close, color: wb.mutedText),
                      onPressed: widget.onClear,
                    ),
            ),
          ]),
          if (widget.onYear case final void Function(int) onYear)
            if (widget.minYear case final int lo)
              if (widget.maxYear case final int hi)
                SizedBox(
                  height: t.scaled(16),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: t.scaled(5)),
                      overlayShape:
                          RoundSliderOverlayShape(overlayRadius: t.scaled(10)),
                    ),
                    child: Slider(
                      key: const ValueKey('chronoYearScrubber'),
                      // With no cursor the thumb sits at the start of
                      // the axis and moving it IS how you place one —
                      // the scrubber is a way in, not only a way to
                      // move one you already have.
                      value: (digest?.year ?? lo).toDouble().clamp(
                            lo.toDouble(),
                            hi.toDouble(),
                          ),
                      min: lo.toDouble(),
                      max: hi.toDouble(),
                      onChanged: (v) => onYear(v.round()),
                    ),
                  ),
                ),
          if (digest == null)
            SizedBox(height: chipLaneH)
          else if (digest.isEmpty)
            SizedBox(
              height: chipLaneH,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  // NOT "nothing happened that year". The corpus is a
                  // selection, and a chart may not claim history was
                  // empty because its own asset is.
                  widget.s('chronoYearEmpty',
                      'No record in this chart is dated to this year.'),
                  style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _expanded
                    ? MediaQuery.sizeOf(context).height * 0.28
                    : chipLaneH,
              ),
              child: _expanded
                  ? ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (happened.isNotEmpty) ...[
                          _heading(widget.s('chronoYearHappened', 'This year'),
                              wb, t),
                          Wrap(children: [
                            for (final i in happened) _chip(i, wb, t)
                          ]),
                        ],
                        if (ongoing.isNotEmpty) ...[
                          _heading(widget.s('chronoYearOngoing', 'Under way'),
                              wb, t),
                          Wrap(children: [
                            for (final i in ongoing) _chip(i, wb, t)
                          ]),
                        ],
                      ],
                    )
                  // Collapsed still SHOWS the records rather than only
                  // counting them: what happened first, then as much of
                  // the context as the row holds. A one-line readout
                  // that only said "3 · 12 · 45" would be the silent
                  // narrowing this chart's rule 2 forbids.
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final i in happened) _chip(i, wb, t),
                        for (final i in ongoing) _chip(i, wb, t),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  /// A fixed-width, fixed-height home for a button that is not always
  /// there, so the header row cannot change height or reflow when a
  /// cursor lands.
  Widget _slot(WbType t, Widget? child) => SizedBox(
        width: t.scaled(30),
        height: t.scaled(24),
        child: child,
      );

  Widget _heading(String text, WbColors wb, WbType t) => Padding(
        padding: EdgeInsets.only(top: t.scaled(4), bottom: t.scaled(3)),
        child: Text(text,
            style: TextStyle(
                color: wb.mutedText,
                fontSize: t.scaledChrome(11),
                fontWeight: FontWeight.w600)),
      );

  Widget _chip(YearDigestItem item, WbColors wb, WbType t) {
    // A beginning and an end are marked, and the long middle is not:
    // the mark is the thing the year IS to this record, so putting one
    // on every chip would say nothing.
    final mark = switch (item.moment) {
      YearMoment.began => widget.s('chronoYearBegins', 'begins'),
      YearMoment.ended => widget.s('chronoYearEnds', 'ends'),
      _ => null,
    };
    final name = widget.label(item);
    return Padding(
      padding: EdgeInsets.only(right: t.scaled(6), bottom: t.scaled(4)),
      child: InkWell(
        onTap: () => widget.onOpen(item),
        borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: t.scaled(8), vertical: t.scaled(2)),
          decoration: BoxDecoration(
            color: item.moment == YearMoment.ongoing ? wb.paneBg : wb.paneAltBg,
            border: Border.all(
                color: item.moment == YearMoment.ongoing
                    ? wb.border
                    : wb.accent.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
          ),
          child: Text(
            mark == null ? name : '$name · $mark',
            maxLines: 1,
            style: TextStyle(color: wb.text, fontSize: t.scaledSmall(12)),
          ),
        ),
      ),
    );
  }
}
