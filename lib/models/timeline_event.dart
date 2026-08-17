/// One row in the Bible timeline. Loaded from
/// `assets/bible_timeline.json`.
class TimelineEvent {
  /// Stable id (kebab/snake-case).
  final String id;

  /// Signed integer year. Negative = BC, positive = AD.
  final int year;

  /// Era key — matches the family-tree era palette
  /// (`antediluvian`, `patriarchs`, `mosaic`, `conquest`,
  /// `monarchy`, `exile`, `intertestamental`, `nt`).
  final String era;

  /// Localized titles + 1-sentence descriptions.
  final String titleEn;
  final String titleZhHans;
  final String titleZhHant;
  final String descEn;
  final String descZhHans;
  final String descZhHant;

  /// Bible verse references (canonical English form). Tap → jump
  /// to verse via the existing `prepareJumpToVerse` plumbing.
  final List<String> refs;

  /// Optional cross-links to family-tree person ids — tappable
  /// chips on the event card that jump to the family tree page
  /// with that person highlighted.
  final List<String> personIds;

  /// What the year rests on. Written by `tools/audit_dates.py`, one of
  /// `scripture` (an interval the text states, counted from the anchor
  /// in `_meta.anchor`), `thiele` (from `hebrew_kings.json`), or
  /// `conventional` (a commonly published reconstruction that nothing
  /// we ship fixes).
  ///
  /// WHY THIS IS ON THE MODEL AND NOT ONLY IN THE ASSET. Check 32
  /// (v1.6.120) put a basis on all 277 people *and* all 98 events, and
  /// the people's half reached the reader — [BiblicalPerson
  /// .displayYears] prefixes "c." for a reconstruction and refuses to
  /// print a birth year for a record that holds an accession year. The
  /// events' half stopped at the JSON: `fromJson` did not read this
  /// field, so 85 of 98 dates printed as flat as the 13 that are
  /// derived. The asset's own `_meta.note` — "nothing here is presented
  /// as a date the text gives unless the text gives it" — was a promise
  /// only the file kept.
  final String basis;

  /// True exactly when [basis] is `conventional`; the asset writes both
  /// and `test/person_dating_test.dart` holds them in step.
  final bool approximate;

  const TimelineEvent({
    required this.id,
    required this.year,
    required this.era,
    required this.titleEn,
    required this.titleZhHans,
    required this.titleZhHant,
    required this.descEn,
    required this.descZhHans,
    required this.descZhHant,
    required this.refs,
    required this.personIds,
    this.basis = 'conventional',
    this.approximate = true,
  });

  String localizedTitle(String locale) {
    if (locale == 'zh-Hant' && titleZhHant.isNotEmpty) return titleZhHant;
    if (locale.startsWith('zh') && titleZhHans.isNotEmpty) return titleZhHans;
    return titleEn;
  }

  String localizedDesc(String locale) {
    if (locale == 'zh-Hant' && descZhHant.isNotEmpty) return descZhHant;
    if (locale.startsWith('zh') && descZhHans.isNotEmpty) return descZhHans;
    return descEn;
  }

  /// Render the year as locale-aware "公元前 1010 年" / "1010 BC"
  /// / "公元 30 年" / "AD 30", hedged when [approximate].
  ///
  /// The hedge is the same one [BiblicalPerson.displayYears] applies, in
  /// the same words and with the same spacing, because the two surfaces
  /// draw on the same generator and a reader moving between the family
  /// tree and the timeline must not have to learn a second vocabulary.
  String displayYear(String locale) {
    final isZh = locale.startsWith('zh');
    final plain = _plainYear(locale, isZh);
    if (!approximate) return plain;
    return isZh ? '约 $plain' : 'c. $plain';
  }

  String _plainYear(String locale, bool isZh) {
    if (year < 0) {
      if (isZh) return '公元前 ${-year} 年';
      return '${-year} BC';
    }
    if (year == 0) {
      if (isZh) return '公元元年';
      return 'AD 1';
    }
    if (isZh) return '公元 $year 年';
    return 'AD $year';
  }

  factory TimelineEvent.fromJson(Map<String, dynamic> j) {
    return TimelineEvent(
      id: j['id'] as String,
      year: (j['year'] as num).toInt(),
      era: j['era'] as String? ?? 'unknown',
      titleEn: j['titleEn'] as String? ?? '',
      titleZhHans: j['titleZhHans'] as String? ?? '',
      titleZhHant: j['titleZhHant'] as String? ?? '',
      descEn: j['descEn'] as String? ?? '',
      descZhHans: j['descZhHans'] as String? ?? '',
      descZhHant: j['descZhHant'] as String? ?? '',
      refs: (j['refs'] as List?)?.cast<String>() ?? const [],
      personIds: (j['personIds'] as List?)?.cast<String>() ?? const [],
      basis: j['basis'] as String? ?? 'conventional',
      approximate: j['approximate'] as bool? ?? true,
    );
  }
}
