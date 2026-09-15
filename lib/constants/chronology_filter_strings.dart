const Map<String, Map<String, String>> chronologyFilterStrings = {
  'draftHint': {
    'zh-Hans': '选好后点「确认应用」，图表才会更新。',
    'zh-Hant': '選好後點「確認套用」，圖表才會更新。',
    'en': 'Choose your layers, then apply to update the chart.',
  },
  'apply': {
    'zh-Hans': '确认应用',
    'zh-Hant': '確認套用',
    'en': 'Apply filters',
  },
  'cancel': {'zh-Hans': '取消', 'zh-Hant': '取消', 'en': 'Cancel'},
};

String chronologyFilterText(String key, String locale) =>
    chronologyFilterStrings[key]?[locale] ??
    chronologyFilterStrings[key]?['en'] ??
    key;
