import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/services/error_reporter.dart';
import 'package:seeksparks/services/profile_service.dart';

/// The set of Strong's numbers you have marked as learned.
///
/// ── Why this is the only thing that persists ──
///
/// bwh40 keeps a lot of state: the filter, the sort, the current card,
/// the drill position. Only the learned set is worth surviving a reload,
/// because it is the only part you cannot rebuild in two taps and the
/// only part that represents work you did. A drill is a sitting; losing
/// your place in one costs a swipe. Losing four months of "I know this
/// one" costs four months.
///
/// Stored as a flat list of Strong's numbers rather than per-word
/// records with dates. Dates would only matter if we scheduled reviews
/// across days, and [DrillQueue] deliberately does not — see
/// `utils/vocabulary.dart`. Storing a timestamp we never read would be
/// a schema we then have to migrate.
///
/// Profile-scoped, and local only for the same reason verse lists are:
/// the sync layer merges last-writer-wins per key, and silently dropping
/// a word you learned on another device is worse than not syncing at all.
class VocabularyStore {
  VocabularyStore._();

  static const _learnedKey = 'workbench.vocabulary.learned';

  /// A ceiling on how much a corrupt or hostile blob can cost us at
  /// startup. The whole tagged corpus is 14,039 Strong's numbers, so
  /// this cannot bite a real user.
  static const maxLearned = 20000;

  static Future<Set<String>> loadLearned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(ProfileService.instance.scopedKey(_learnedKey));
      if (raw == null) return <String>{};
      final json = jsonDecode(raw);
      if (json is! List) return <String>{};
      return <String>{
        for (final v in json.take(maxLearned))
          if (v is String && v.isNotEmpty) v,
      };
    } catch (e, s) {
      ErrorReporter.report(e, s, source: 'VocabularyStore.loadLearned');
      return <String>{};
    }
  }

  static Future<void> saveLearned(Set<String> learned) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Sorted so the stored blob is stable between saves — an unstable
      // one would churn any future sync diff for no reason.
      final list = learned.toList()..sort();
      await prefs.setString(
        ProfileService.instance.scopedKey(_learnedKey),
        jsonEncode(list.take(maxLearned).toList()),
      );
    } catch (e, s) {
      ErrorReporter.report(e, s, source: 'VocabularyStore.saveLearned');
    }
  }
}
