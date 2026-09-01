import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/timeline_event.dart';

/// The `basis` values `bible_timeline.json` may carry, mapped to the
/// `ui_strings` sentence that explains each one.
///
/// Hoisted out of [basisText] so a test can hold the asset to it. The
/// fallback below is deliberate (see [basisText]) and stays; what it
/// cannot do is stay SILENT. Falling back reads a year as the weakest of
/// the three, which is right when the basis is unknown and wrong when it
/// is stronger — `tools/audit_dates.py` already emits a fourth value,
/// `scripture`, for `family_tree.json`, and a timeline event carrying it
/// would print "a commonly published reconstruction" over a date the text
/// states. `bible_timeline_about_test.dart` fails the build on the asset
/// before that reaches a reader.
const timelineBasisKeys = <String, String>{
  'scripture+thiele': 'timelineBasisScripture',
  'thiele': 'timelineBasisThiele',
  'conventional': 'timelineBasisConventional',
};

/// One sentence saying what a year rests on, keyed on the asset's own
/// `basis` vocabulary. An unrecognised value reads as the weakest of
/// the three rather than as nothing, so a future basis added to the
/// generator cannot make the app silently confident.
String basisText(TimelineEvent e, String locale) {
  final key = timelineBasisKeys[e.basis] ?? 'timelineBasisConventional';
  return uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? '';
}
