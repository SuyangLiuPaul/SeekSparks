import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/models/timeline_event.dart';

/// The `_meta` block of `assets/bible_timeline.json`, written by
/// `tools/audit_dates.py`.
///
/// Only the two READER-FACING fields are modelled. `basis` and
/// `septuagintYear` are deliberately absent: `ui_strings.dart` already
/// owns the reader's wording of both — `timelineBasisScripture` and
/// friends via [basisText], and `timelineSeptuagintYear` — and both
/// already render on every expanded row. Modelling the asset's copies
/// would put two wordings of one fact in one app. The asset keeps them
/// as its own audit log.
class TimelineMeta {
  const TimelineMeta({
    required this.anchor,
    required this.note,
    required this.counts,
  });

  /// Trilingual: `en` / `zh-Hans` / `zh-Hant`.
  final Map<String, String> anchor;
  final Map<String, String> note;

  /// `{'conventional': 75, 'scripture+thiele': 18, 'thiele': 5}` — the
  /// asset's own tally, pinned against the records by
  /// `bible_timeline_about_test.dart`.
  final Map<String, int> counts;

  static const empty = TimelineMeta(anchor: {}, note: {}, counts: {});

  String anchorFor(String locale) => _pick(anchor, locale);
  String noteFor(String locale) => _pick(note, locale);

  static String _pick(Map<String, String> m, String locale) =>
      m[locale] ?? m['en'] ?? '';

  /// Tolerates the OLD shape, where these were bare English `String`s —
  /// a stale cached asset must not throw.
  static Map<String, String> _localized(dynamic v) {
    if (v is String) return {'en': v};
    if (v is Map) {
      return {
        for (final e in v.entries)
          if (e.value is String) e.key.toString(): e.value as String,
      };
    }
    return const {};
  }

  static TimelineMeta fromJson(Map<String, dynamic>? m) => TimelineMeta(
        anchor: _localized(m?['anchor']),
        note: _localized(m?['note']),
        counts: {
          for (final e in ((m?['counts'] as Map?) ?? const {}).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
        },
      );
}

/// Loads the curated `assets/bible_timeline.json` dataset and
/// caches it for the process lifetime.
class TimelineService {
  TimelineService._();
  static final TimelineService instance = TimelineService._();

  List<TimelineEvent>? _cache;
  TimelineMeta? _meta;

  /// Loads & sorts events chronologically (oldest first).
  Future<List<TimelineEvent>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/bible_timeline.json');
    final j = json.decode(raw) as Map<String, dynamic>;
    final entries = (j['events'] as List?) ?? const [];
    final list = entries
        .whereType<Map<String, dynamic>>()
        .map(TimelineEvent.fromJson)
        .toList();
    list.sort((a, b) => a.year.compareTo(b.year));
    _cache = list;
    _meta = TimelineMeta.fromJson((j['_meta'] as Map?)?.cast<String, dynamic>());
    return list;
  }

  List<TimelineEvent> allOrEmpty() => _cache ?? const [];

  /// The asset's `_meta`. [TimelineMeta.empty] until [loadAll] has
  /// completed at least once.
  TimelineMeta get meta => _meta ?? TimelineMeta.empty;
}
