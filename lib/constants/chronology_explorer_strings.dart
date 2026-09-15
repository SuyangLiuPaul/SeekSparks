const Map<String, Map<String, String>> chronologyExplorerStrings = {
  'find': {
    'zh-Hans': '查找全部记录',
    'zh-Hant': '查找全部記錄',
    'en': 'Search all records',
  },
  'findHint': {
    'zh-Hans': '名称、经文或年份；搜索包含隐藏的记录',
    'zh-Hant': '名稱、經文或年份；搜尋包含隱藏的記錄',
    'en': 'A name, verse or year; includes hidden records',
  },
  'filter': {'zh-Hans': '图层', 'zh-Hant': '圖層', 'en': 'Layers'},
  'period': {'zh-Hans': '时间范围', 'zh-Hant': '時間範圍', 'en': 'Time range'},
  'all': {'zh-Hans': '全部年代', 'zh-Hant': '全部年代', 'en': 'All years'},
  'early': {
    'zh-Hans': '主前4200 — 主前2000',
    'zh-Hant': '主前4200 — 主前2000',
    'en': '4200 BC — 2000 BC',
  },
  'middle': {
    'zh-Hans': '主前2000 — 主前1000',
    'zh-Hant': '主前2000 — 主前1000',
    'en': '2000 BC — 1000 BC',
  },
  'biblical': {
    'zh-Hans': '主前1000 — 主后100',
    'zh-Hant': '主前1000 — 主後100',
    'en': '1000 BC — AD 100',
  },
  'late': {
    'zh-Hans': '主后100 — 1500',
    'zh-Hant': '主後100 — 1500',
    'en': 'AD 100 — 1500',
  },
  'recent': {
    'zh-Hans': '1500 — 至今',
    'zh-Hant': '1500 — 至今',
    'en': '1500 — Present',
  },
  'events': {'zh-Hans': '事件', 'zh-Hant': '事件', 'en': 'Events'},
  'browse': {
    'zh-Hans': '按时间浏览',
    'zh-Hant': '按時間瀏覽',
    'en': 'Browse the timeline',
  },
  'interaction': {
    'zh-Hans': '拖动图表 · 点事件查看依据',
    'zh-Hant': '拖動圖表 · 點事件查看依據',
    'en': 'Drag the chart · Tap an event for its sources',
  },
  'count': {
    'zh-Hans': '{visible} 条事件',
    'zh-Hant': '{visible} 條事件',
    'en': '{visible} events',
  },
  'countOne': {
    'zh-Hans': '1 条事件',
    'zh-Hant': '1 條事件',
    'en': '1 event',
  },
  'compactCount': {
    'zh-Hans': '{visible} 可见 · {hidden} 隐藏',
    'zh-Hant': '{visible} 可見 · {hidden} 隱藏',
    'en': '{visible} visible · {hidden} hidden',
  },
  'hidden': {
    'zh-Hans': '此范围另有 {hidden} 条被图层筛选隐藏',
    'zh-Hant': '此範圍另有 {hidden} 條被圖層篩選隱藏',
    'en': '{hidden} more in this range hidden by layers',
  },
  'hiddenStreams': {
    'zh-Hans': '已隐藏 {count} 个图层；搜索仍包含全部记录',
    'zh-Hant': '已隱藏 {count} 個圖層；搜尋仍包含全部記錄',
    'en': '{count} layers hidden; search still includes all records',
  },
  'empty': {
    'zh-Hans': '这个范围没有可见事件。调整时间范围或图层，也可以搜索全部记录。',
    'zh-Hant': '這個範圍沒有可見事件。調整時間範圍或圖層，也可以搜尋全部記錄。',
    'en':
        'No visible events here. Change the time range or layers, or search all records.',
  },
  'scripture': {
    'zh-Hans': '经文所载',
    'zh-Hant': '經文所載',
    'en': 'Stated in scripture',
  },
  'scripture+thiele': {
    'zh-Hans': '经文间隔 · 年份按 Thiele',
    'zh-Hant': '經文間隔 · 年份按 Thiele',
    'en': 'Scripture interval · Thiele year',
  },
  'thiele': {
    'zh-Hans': '年份按 Thiele 列王年代',
    'zh-Hant': '年份按 Thiele 列王年代',
    'en': 'Thiele’s chronology of the kings',
  },
  'conventional': {
    'zh-Hans': '通行年份 · 非经文所载',
    'zh-Hant': '通行年份 · 非經文所載',
    'en': 'Conventional date · Not stated in scripture',
  },
  'traditional': {
    'zh-Hans': '传说纪年 · 非信史',
    'zh-Hant': '傳說紀年 · 非信史',
    'en': 'Traditional date · Not established history',
  },
  'close': {'zh-Hans': '关闭', 'zh-Hant': '關閉', 'en': 'Close'},
};

String chronologyExplorerText(String key, String locale) =>
    chronologyExplorerStrings[key]?[locale] ??
    chronologyExplorerStrings[key]?['en'] ??
    key;

String chronologyExplorerEventCount(int count, String locale) =>
    chronologyExplorerText(count == 1 ? 'countOne' : 'count', locale)
        .replaceFirst('{visible}', '$count');
