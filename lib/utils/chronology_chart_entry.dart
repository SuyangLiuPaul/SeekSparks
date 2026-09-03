// The one "open the chronology chart" decision, shared by every entry
// point that used to hardcode `RadialChronologyPage` directly.
//
// THE DECISION THIS FILE STANDS FOR. The wheel and the strip draw the
// same corpus in two shapes — not two charts — so adding the strip
// does not add a second menu item / toolbar icon beside the wheel's.
// `workbench_page.dart`'s "World History Wheel" menu entry and
// `chronology_page.dart`'s wheel icon button both keep their one door;
// what changed is what is behind it: whichever form the reader had
// open last (`AppSettings.chronologyView`), so a reader who has
// switched to the strip is not sent back to the wheel every time they
// come in through that door. The switch that changes the remembered
// form lives inside the pages themselves — see
// `stripStrings['stripViewSwitch']`'s own doc comment for that half.
//
// Centralised here rather than duplicated as a ternary at each call
// site so there is exactly one place that reads `chronologyView`.

import 'package:flutter/widgets.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/pages/strip_chronology_page.dart';

/// The page an "open the chronology chart" entry point should push.
Widget chronologyChartEntryPage(AppSettings settings) =>
    settings.chronologyView == 'strip'
        ? const StripChronologyPage()
        : const RadialChronologyPage();
