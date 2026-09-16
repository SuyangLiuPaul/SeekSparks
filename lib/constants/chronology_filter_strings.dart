const Map<String, Map<String, String>> chronologyFilterStrings = {
  'draftHint': {
    'zh-Hans': '选好后点「确认应用」，图表才会更新。',
    'zh-Hant': '選好後點「確認套用」，圖表才會更新。',
    'en': 'Choose your layers, then apply to update the chart.',
  },
  // 2026-09-16 「filter那里应该是alphabet order可以标注出来」 — the order
  // is stated, because an order a reader cannot see the rule of is not
  // an order they can use. The four layers above keep their own
  // sequence; only the powers are sorted.
  'sortedByName': {
    'zh-Hans': '下面的列国按名称排序。',
    'zh-Hant': '下面的列國按名稱排序。',
    'en': 'The powers below are listed A–Z.',
  },
  'apply': {
    'zh-Hans': '确认应用',
    'zh-Hant': '確認套用',
    'en': 'Apply filters',
  },
  'cancel': {'zh-Hans': '取消', 'zh-Hant': '取消', 'en': 'Cancel'},
  // Shown once the reader has as many streams on as the wheel allows.
  // It has to say WHY, because a checkbox that will not tick and gives
  // no reason reads as a broken build rather than as a limit.
  'ceilingHint': {
    'zh-Hans': '已经满了。先关掉一条，才能换上别的。',
    'zh-Hant': '已經滿了。先關掉一條，才能換上別的。',
    'en': 'That is the limit. Turn one off to make room.',
  },
};

/// The running count, printed beside the hint.
///
/// A number rather than a sentence: the reader needs to know how much
/// room is left before they start choosing, not after they are refused.
String chronologyFilterCount(String locale, int shown, int ceiling) =>
    switch (locale) {
      'zh-Hans' => '历史线 $shown / 最多 $ceiling',
      'zh-Hant' => '歷史線 $shown / 最多 $ceiling',
      _ => 'Streams $shown of $ceiling',
    };

String chronologyFilterText(String key, String locale) =>
    chronologyFilterStrings[key]?[locale] ??
    chronologyFilterStrings[key]?['en'] ??
    key;
