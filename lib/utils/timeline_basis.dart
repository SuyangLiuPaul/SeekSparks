import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/timeline_event.dart';

/// One sentence saying what a year rests on, keyed on the asset's own
/// `basis` vocabulary. An unrecognised value reads as the weakest of
/// the three rather than as nothing, so a future basis added to the
/// generator cannot make the app silently confident.
String basisText(TimelineEvent e, String locale) {
  const keys = <String, String>{
    'scripture+thiele': 'timelineBasisScripture',
    'thiele': 'timelineBasisThiele',
    'conventional': 'timelineBasisConventional',
  };
  final key = keys[e.basis] ?? 'timelineBasisConventional';
  return uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? '';
}
