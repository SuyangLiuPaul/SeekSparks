/// The horizontal chronology strip — the wheel's second form.
///
/// WHY THERE ARE TWO FORMS. The wheel is a good poster and a poor
/// instrument, and the reason is geometric rather than aesthetic: its
/// cross axis is bounded by the viewport, so the 22 stream rings get
/// `side x 0.17` between them — **3.01 px each on a 390 px phone**
/// against a 9 px finger — and `InteractiveViewer` scales both axes at
/// once, so magnifying a seven-day reign magnifies Methuselah's 969
/// years off the screen with it. Seven spans on that band are 0.00 px
/// wide at every canvas and every zoom. None of that is a parameter
/// anybody can move.
///
/// This page unbinds the two axes. Time scrolls horizontally and is
/// zoomed on its own (`pxPerYear`); lanes have a height chosen in
/// pixels and scroll vertically. The measurements behind the decision
/// are in `WHEEL-UX-REDESIGN.md`; the geometry is in
/// `strip_chronology_layout.dart`; the paint order is specified in
/// `docs/strip-painter-spec.md`.
///
/// THE DETAIL SHEETS ARE THE WHEEL'S OWN. `WheelSheets` was extracted
/// so this page opens the identical sheet a reader gets from the wheel
/// — same words, same verse links, same behaviour. A second view of one
/// corpus must not grow a second vocabulary for it.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/pages/wheel_sheets.dart';

/// The address this page owns, in the same shape as `kWheelUrlPath`.
///
/// Named here rather than in `page_links.dart` so the routing table
/// depends on the page and not the other way round — the wheel's own
/// path is declared the same way.
const String kStripUrlPath = '/strip';

class StripChronologyPage extends StatefulWidget {
  const StripChronologyPage({super.key});

  @override
  State<StripChronologyPage> createState() => _StripChronologyPageState();
}

class _StripChronologyPageState extends State<StripChronologyPage>
    with WheelSheets<StripChronologyPage> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
