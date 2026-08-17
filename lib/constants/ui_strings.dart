const uiStrings = {
  // ====== Search Page ======
  'search': {
    'zh-Hans': '搜索',
    'zh-Hant': '搜尋',
    'en': 'Search',
  },
  'searchResultCount': {
    'zh-Hans': '共 {count} 处，按书统计：',
    'zh-Hant': '共 {count} 處，按書統計：',
    'en': 'Total {count} matches, grouped by book:',
  },
  'viewMoreBooksHint': {
    'zh-Hans': '点击查看更多书卷，右上角筛选可跳转到书卷。',
    'zh-Hant': '點擊查看更多書卷，右上角篩選可跳轉到書卷。',
    'en': 'Tap to view more books; use top-right filter to jump to a book.',
  },
  'noResults': {
    'zh-Hans': '未找到结果',
    'zh-Hant': '找不到結果',
    'en': 'No results found',
  },

  // ====== Search Filters ======
  'searchCurrentBook': {
    'zh-Hans': '搜索当前书卷',
    'zh-Hant': '搜尋當前書卷',
    'en': 'Search Current Book',
  },
  'searchEntireBible': {
    'zh-Hans': '搜索整本圣经',
    'zh-Hant': '搜尋整本聖經',
    'en': 'Search Entire Bible',
  },

  // ====== General Navigation ======
  'back': {
    'zh-Hans': '返回',
    'zh-Hant': '返回',
    'en': 'Back',
  },
  'showMenu': {
    'zh-Hans': '显示菜单',
    'zh-Hant': '顯示選單',
    'en': 'Show menu',
  },

  // ====== Bible Navigation ======
  // Renamed from OT/NT to Hebrew Bible / Greek Bible at the user's
  // request — more accurate to the underlying source languages.
  'oldTestament': {
    'zh-Hans': '希伯来圣经',
    'zh-Hant': '希伯來聖經',
    'en': 'Hebrew Bible',
  },
  'newTestament': {
    'zh-Hans': '希腊圣经',
    'zh-Hant': '希臘聖經',
    'en': 'Greek Bible',
  },
  // Short forms used in narrow toggle buttons where the full name
  // would overflow.
  'oldTestamentShort': {
    'zh-Hans': '希伯来',
    'zh-Hant': '希伯來',
    'en': 'Hebrew',
  },
  'newTestamentShort': {
    'zh-Hans': '希腊',
    'zh-Hant': '希臘',
    'en': 'Greek',
  },
  'previousChapter': {
    'zh-Hans': '上一章',
    'zh-Hant': '上一章',
    'en': 'Previous Chapter',
  },
  'nextChapter': {
    'zh-Hans': '下一章',
    'zh-Hant': '下一章',
    'en': 'Next Chapter',
  },
  'bibleBooks': {
    'zh-Hans': '书卷',
    'zh-Hant': '書卷',
    'en': 'Bible Books',
  },
  'addChapter': {
    'zh-Hans': '添加章节',
    'zh-Hant': '新增章節',
    'en': 'Add chapter',
  },
  'openAnotherChapter': {
    'zh-Hans': '打开另一章',
    'zh-Hant': '開啟另一章',
    'en': 'Open another chapter',
  },
  'openPages': {
    'zh-Hans': '打开的页面',
    'zh-Hant': '開啟的頁面',
    'en': 'Open pages',
  },
  'reader': {
    'zh-Hans': '阅读',
    'zh-Hant': '閱讀',
    'en': 'Reader',
  },
  'currentPage': {
    'zh-Hans': '当前页面',
    'zh-Hant': '目前頁面',
    'en': 'Current page',
  },
  'switchPage': {
    'zh-Hans': '切换页面',
    'zh-Hant': '切換頁面',
    'en': 'Switch page',
  },
  'closePage': {
    'zh-Hans': '关闭页面',
    'zh-Hant': '關閉頁面',
    'en': 'Close page',
  },
  'changeVersion': {
    'zh-Hans': '切换版本',
    'zh-Hant': '切換版本',
    'en': 'Change Version',
  },
  // 2026-06-22: language-grouped version picker. Title + the three
  // language-tab labels (shown in the app's UI language) + the
  // per-language section subtitle.
  'versionPickerTitle': {
    'zh-Hans': '选择圣经版本',
    'zh-Hant': '選擇聖經版本',
    'en': 'Choose a version',
  },
  // 2026-07-21: made these three self-referential / locale-INDEPENDENT
  // — same value in all three locale slots — instead of translating
  // "Traditional"/"Simplified" into whatever the UI language happens
  // to be. A language-name tab should read as that language names
  // itself (this already matches Settings → Interface Language's
  // dropdown, which hardcodes 'English' / '简体中文' / '繁體中文'
  // regardless of the app's current locale — these tabs previously
  // didn't follow that same convention). Also switched from the
  // short 2-char forms (繁體/简体) to the full 4-char language names
  // so English-UI users see 繁體中文/简体中文 rather than the bare
  // English words "Traditional"/"Simplified", which don't actually
  // name a script the way the Chinese terms do.
  'versionLangEnglish': {
    'zh-Hans': 'English',
    'zh-Hant': 'English',
    'en': 'English',
  },
  'versionLangTraditional': {
    'zh-Hans': '繁體中文',
    'zh-Hant': '繁體中文',
    'en': '繁體中文',
  },
  'versionLangSimplified': {
    'zh-Hans': '简体中文',
    'zh-Hant': '简体中文',
    'en': '简体中文',
  },
  // Original-language column (LXX + Westcott-Hort). Named for the
  // language, not the edition, to match the three rows above it.
  'versionLangGreek': {
    'zh-Hans': '希腊文',
    'zh-Hant': '希臘文',
    'en': 'Greek',
  },
  // Eagle's View imports (v1.6.18) — About > Scriptures attribution.
  'aboutVerKjvs': {
    'zh-Hans': "KJV+S（1769 带 Strong's 及时态语态语气）",
    'zh-Hant': "KJV+S（1769 帶 Strong's 及時態語態語氣）",
    'en': "KJV+S (1769 with Strong's + TVM)",
  },
  'aboutVerLxxwh': {
    'zh-Hans': 'LXX+WH（七十士译本 + 韦斯科特-霍特希腊文）',
    'zh-Hant': 'LXX+WH（七十士譯本 + 韋斯科特-霍特希臘文）',
    'en': 'LXX+WH (Septuagint + Westcott-Hort)',
  },
  'aboutVerCuvsPlus': {
    'zh-Hans': "和简+ 和合本+Strong's（简体）",
    'zh-Hant': "和简+ 和合本+Strong's（簡體）",
    'en': "和简+ (Chinese Union Version with Strong's, Simplified)",
  },
  'aboutLicenseEaglesView': {
    'zh-Hans': '经文属公有领域 · 电子版本及编号对照来自 Eagle\'s View。',
    'zh-Hant': '經文屬公有領域 · 電子版本及編號對照來自 Eagle\'s View。',
    'en': "Public domain text \u00b7 electronic edition from Eagle's View.",
  },
  'chapter': {
    'zh-Hans': '第 {n} 章',
    'zh-Hant': '第 {n} 章',
    'en': 'Chapter {n}',
  },
  'versePosition': {
    'zh-Hans': '第 {current} / {total} 节',
    'zh-Hant': '第 {current} / {total} 節',
    'en': 'Verse {current} of {total}',
  },
  'selectedVerses': {
    'zh-Hans': '已选择 {count} 节',
    'zh-Hant': '已選擇 {count} 節',
    'en': '{count} selected',
  },
  'clearSelection': {
    'zh-Hans': '清除选择',
    'zh-Hant': '清除選擇',
    'en': 'Clear selection',
  },
  'copySelection': {
    'zh-Hans': '复制',
    'zh-Hant': '複製',
    'en': 'Copy',
  },
  'highlight': {
    'zh-Hans': '高亮',
    'zh-Hant': '高亮',
    'en': 'Highlight',
  },
  'highlights': {
    'zh-Hans': '高亮',
    'zh-Hant': '高亮',
    'en': 'Highlights',
  },
  'highlightsEmpty': {
    'zh-Hans': '尚无高亮。长按经文，选择颜色即可添加。',
    'zh-Hant': '尚無高亮。長按經文，選擇顏色即可添加。',
    'en': 'No highlights yet. Long-press a verse and pick a color.',
  },
  'highlightsNoMatch': {
    'zh-Hans': '没有符合此筛选的高亮。',
    'zh-Hant': '沒有符合此篩選的高亮。',
    'en': 'No highlights match this filter.',
  },
  'allColors': {
    'zh-Hans': '所有颜色',
    'zh-Hant': '所有顏色',
    'en': 'All',
  },
  'copyAll': {
    'zh-Hans': '复制全部',
    'zh-Hant': '複製全部',
    'en': 'Copy all',
  },
  'share': {
    'zh-Hans': '分享',
    'zh-Hant': '分享',
    'en': 'Share',
  },
  // 2026-08: SeekSparks — this panel is an original-language word
  // study, not the AI exegesis sheet it was called in YsWords. The
  // inherited "Exegesis / 释经" label described the wrong feature.
  'originalText': {
    'zh-Hans': '原文逐字',
    'zh-Hant': '原文逐字',
    'en': 'Original Text',
  },
  'originalHint': {
    'zh-Hans': '点击词语查看 Strong\'s 词条。',
    'zh-Hant': '點擊詞語查看 Strong\'s 詞條。',
    'en': 'Tap a word to see its Strong\'s entry.',
  },
  'originalNotAvailable': {
    'zh-Hans': '此节经文暂未提供原文数据。',
    'zh-Hant': '此節經文暫未提供原文資料。',
    'en': 'Original-language data not available for this verse yet.',
  },
  // Not a gap in our data: the verse is absent from the manuscripts the
  // original-language text is edited from. Saying so is the difference
  // between "we are missing something" and "there is nothing to miss".
  'originalOmitsVerse': {
    'zh-Hans': '此节不见于原文校勘本，故无原文可显示。',
    'zh-Hant': '此節不見於原文校勘本，故無原文可顯示。',
    'en': 'This verse is not in the critical edition of the original, '
        'so there is no original text to show.',
  },
  'strongsNotFound': {
    'zh-Hans': '未找到该 Strong\'s 词条。',
    'zh-Hant': '未找到該 Strong\'s 詞條。',
    'en': 'Lexicon entry not found.',
  },
  'concordanceUsed': {
    'zh-Hans': '出现 {count} 次',
    'zh-Hant': '出現 {count} 次',
    'en': 'Used {count} times',
  },
  'concordanceShowingFirst': {
    'zh-Hans': '显示前 {shown} 条（共 {total} 条）',
    'zh-Hant': '顯示前 {shown} 條（共 {total} 條）',
    'en': 'showing first {shown} of {total}',
  },
  'copyTable': {
    'zh-Hans': '复制词表',
    'zh-Hant': '複製詞表',
    'en': 'Copy word table',
  },
  'copyWordStudy': {
    'zh-Hans': '复制词语研经',
    'zh-Hant': '複製詞語研經',
    'en': 'Copy word study',
  },
  'distributionTable': {
    'zh-Hans': '分布表',
    'zh-Hant': '分佈表',
    'en': 'Distribution Table',
  },
  'crossRefs': {
    'zh-Hans': '相互参照',
    'zh-Hant': '相互參照',
    'en': 'Cross-references',
  },
  'noteAdd': {'zh-Hans': '笔记', 'zh-Hant': '筆記', 'en': 'Note'},
  'noteEdit': {'zh-Hans': '编辑笔记', 'zh-Hant': '編輯筆記', 'en': 'Edit note'},
  'noteHint': {
    'zh-Hans': '为这节经文写下你的笔记…',
    'zh-Hant': '為這節經文寫下你的筆記…',
    'en': 'Type your note for this verse…',
  },
  'noteSave': {'zh-Hans': '保存', 'zh-Hant': '儲存', 'en': 'Save'},
  'noteDelete': {'zh-Hans': '删除', 'zh-Hant': '刪除', 'en': 'Delete'},
  // 2026-05-20 (v1.2.62): WeChat-style fullscreen toggle on the
  // note editor sheet. Compact ↔ fullscreen.
  'noteExpand': {
    'zh-Hans': '全屏',
    'zh-Hant': '全螢幕',
    'en': 'Expand',
  },
  'noteCollapse': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Collapse',
  },
  // 2026-05-19 (v1.2.59): note-editor "+ Verse Reference" button +
  // its book/chapter/verse picker sheet. Tapping a reference in
  // the saved note (Library / wherever displayed) opens the
  // reader at that verse.
  'noteAddReference': {
    'zh-Hans': '+ 经文',
    'zh-Hant': '+ 經文',
    'en': '+ Verse',
  },
  'notePickerPickBook': {
    'zh-Hans': '选择书卷',
    'zh-Hant': '選擇書卷',
    'en': 'Pick a book',
  },
  'notePickerPickChapter': {
    'zh-Hans': '选择章',
    'zh-Hant': '選擇章',
    'en': 'Pick a chapter',
  },
  'notePickerPickVerse': {
    'zh-Hans': '选择经文',
    'zh-Hant': '選擇經文',
    'en': 'Pick verses',
  },
  // 2026-05-19 (v1.2.61): multi-select picker UX strings.
  'notePickerSelectVerses': {
    'zh-Hans': '点击一或多节经文',
    'zh-Hant': '點擊一或多節經文',
    'en': 'Tap one or more verses',
  },
  'notePickerClearSelection': {
    'zh-Hans': '清空选择',
    'zh-Hant': '清空選擇',
    'en': 'Clear selection',
  },
  'notePickerInsert': {
    'zh-Hans': '插入',
    'zh-Hant': '插入',
    'en': 'Insert',
  },
  // 2026-05-20 (v1.2.66): chip-tooltip for the cross-canon fallback
  // indicator on a note-editor ref chip. Surfaces when the ref's
  // book isn't in the user's current Bible version (e.g. they're
  // on LJK2 NT-only but the ref is for Genesis); tapping the chip
  // will trigger `bibleVersionFullCanonFallback` to load CUVS-YHWH.
  'noteChipFallbackTooltip': {
    'zh-Hans': '此书卷不在当前译本中——点击将自动切换到完整的和合本雅伟版',
    'zh-Hant': '此書卷不在當前譯本中——點擊將自動切換到完整的和合本雅偉版',
    'en': "This book isn't in your current version — tapping will "
        "load the full-canon companion",
  },
  // 2026-05-19 (v1.2.61): reference preview sheet (tap a ref in a
  // saved note → bottom sheet shows referenced verses; expand
  // shows whole chapter; open-in-reader navigates fully).
  'notePreviewExpand': {
    'zh-Hans': '展开整章',
    'zh-Hant': '展開整章',
    'en': 'Expand chapter',
  },
  'notePreviewCollapse': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Collapse',
  },
  'notePreviewOpenReader': {
    'zh-Hans': '在阅读器中打开',
    'zh-Hant': '在閱讀器中打開',
    'en': 'Open in Reader',
  },
  'notePreviewMissing': {
    'zh-Hans': '此段经文不在当前的圣经版本中。请在阅读器中打开以切换版本。',
    'zh-Hant': '此段經文不在當前的聖經版本中。請在閱讀器中打開以切換版本。',
    'en': "This passage isn't in your current Bible version. "
        "Open it in the reader to switch versions.",
  },
  // `back` already exists earlier in this map at line ~37 — reused.
  'bookmark': {'zh-Hans': '书签', 'zh-Hant': '書籤', 'en': 'Bookmark'},
  // 2026-05-07 (v11): user feedback -- the previous Chinese
  // rendering "我的标记" (literally "My Markings") collided
  // semantically with "我的高亮" (My Highlights, the colored-
  // highlights page). The Library page actually contains
  // Notes + Bookmarks + Reading Plan, so 标记/markings was
  // misleading. "我的收藏" (My Collection / Saved Items) is
  // broader, matches the Library content, and stays clearly
  // distinct from "我的高亮" (Highlights).
  'library': {'zh-Hans': '我的收藏', 'zh-Hant': '我的收藏', 'en': 'Library'},
  'statistics': {'zh-Hans': '圣经工具', 'zh-Hant': '聖經工具', 'en': 'Bible Tools'},
  'statsOverview':
      {'zh-Hans': '总览', 'zh-Hant': '總覽', 'en': 'Overview'},
  'statsBooks': {'zh-Hans': '书卷', 'zh-Hant': '書卷', 'en': 'Books'},
  // Round 56: replaces the per-book Statistics tab with a
  // Strong's-first lookup tool. Tapping a result opens the full
  // StrongsEntryPage (entry + concordance + word family). Same
  // search vocabulary as the Vocabulary tab — by Strong's #, lemma,
  // transliteration, or gloss in any locale.
  'statsLookup': {
    'zh-Hans': '原文查询',
    'zh-Hant': '原文查詢',
    'en': 'Lookup',
  },
  'statsLookupHint': {
    'zh-Hans': '输入 Strong\'s 编号、原文、音译、字义任一项查找',
    'zh-Hant': '輸入 Strong\'s 編號、原文、音譯、字義任一項查找',
    'en': 'Search by Strong\'s number, lemma, transliteration, or gloss',
  },
  'statsLookupTapHint': {
    'zh-Hans': '点击任一字根查看完整释义、词族、经文索引',
    'zh-Hant': '點擊任一字根查看完整釋義、詞族、經文索引',
    'en': 'Tap any entry for full meaning, word family, and concordance.',
  },
  'statsLookupEmpty': {
    'zh-Hans': '未找到匹配的字根',
    'zh-Hant': '未找到匹配的字根',
    'en': 'No matching entries.',
  },
  // Round 56 (continued — exegesis parity): Lookup tab now leads
  // with a passage-study card so users can start from a verse,
  // matching the in-reader exegesis experience.
  'statsLookupPassageTitle': {
    'zh-Hans': '选经文研读',
    'zh-Hant': '選經文研讀',
    'en': 'Study a passage',
  },
  'statsLookupPassageDesc': {
    'zh-Hans': '选择任一节经文，查看其字字对照原文释经——与阅读时点击经文弹出的完全一致。',
    'zh-Hant': '選擇任一節經文，查看其字字對照原文釋經——與閱讀時點擊經文彈出的完全一致。',
    'en':
        'Pick any verse to see its word-by-word original-language breakdown — same view the reader pops when you tap a verse.',
  },
  'statsLookupPickVerse': {
    'zh-Hans': '选择经文',
    'zh-Hant': '選擇經文',
    'en': 'Pick a verse',
  },
  'statsLookupContinueReading': {
    'zh-Hans': '从阅读继续',
    'zh-Hant': '從閱讀繼續',
    'en': 'Continue from reader',
  },
  'statsLookupStepBook': {
    'zh-Hans': '选择书卷',
    'zh-Hant': '選擇書卷',
    'en': 'Pick a book',
  },
  'statsLookupStepChapter': {
    'zh-Hans': '选择章',
    'zh-Hant': '選擇章',
    'en': 'Pick a chapter',
  },
  'statsLookupStepVerse': {
    'zh-Hans': '选择节',
    'zh-Hant': '選擇節',
    'en': 'Pick a verse',
  },
  'statsLookupNoCurrentReading': {
    'zh-Hans': '请先在阅读页打开一段经文，再回来这里继续。',
    'zh-Hant': '請先在閱讀頁打開一段經文，再回來這裡繼續。',
    'en': 'Open a passage in the reader first to continue here.',
  },
  'statsLookupViewDistribution': {
    'zh-Hans': '在分布表中查看',
    'zh-Hant': '在分布表中查看',
    'en': 'View in Distribution',
  },
  // Round 56: Lookup tab redesign — popular-passages quick picks +
  // features card. Topic descriptors are short factual hints
  // (single phrase) so the user knows what each passage is about
  // before tapping.
  'lookupPopularTitle': {
    'zh-Hans': '近期每日经文',
    'zh-Hant': '近期每日經文',
    'en': 'Recent daily verses',
  },
  'lookupPopularDesc': {
    'zh-Hans': '过去几天的每日经文，点击直接进入释经面板。',
    'zh-Hant': '過去幾天的每日經文，點擊直接進入釋經面板。',
    'en':
        'The past few days of daily verse — tap to study any of them in depth.',
  },
  'lookupPopularEmpty': {
    'zh-Hans': '暂时没有每日经文。',
    'zh-Hant': '暫時沒有每日經文。',
    'en': 'No daily verses available yet.',
  },
  'relativeToday': {
    'zh-Hans': '今天',
    'zh-Hant': '今天',
    'en': 'Today',
  },
  'relativeYesterday': {
    'zh-Hans': '昨天',
    'zh-Hant': '昨天',
    'en': 'Yesterday',
  },
  'relativeDayBeforeYesterday': {
    'zh-Hans': '前天',
    'zh-Hant': '前天',
    'en': '2 days ago',
  },
  'relativeDaysAgo': {
    'zh-Hans': '{days} 天前',
    'zh-Hant': '{days} 天前',
    'en': '{days} days ago',
  },
  // Round 56 (continued — daily verse themes): topical category
  // labels for the 'Recent daily verses' chip row. Keys assigned by
  // themeKeyFor() in lib/services/daily_verse_service.dart based on
  // (book, chapter). Short labels (1-3 chars CJK / 1-2 words EN)
  // chosen so chip text fits on one line at 11pt.
  'verseThemeGeneral': {
    'zh-Hans': '经文',
    'zh-Hant': '經文',
    'en': 'Scripture',
  },
  // ── Famous-chapter themes ────────────────────────────────────
  'verseThemeCreation': {
    'zh-Hans': '创造',
    'zh-Hant': '創造',
    'en': 'Creation',
  },
  'verseThemeFall': {
    'zh-Hans': '堕落',
    'zh-Hant': '墮落',
    'en': 'The Fall',
  },
  'verseThemeCalling': {
    'zh-Hans': '蒙召',
    'zh-Hant': '蒙召',
    'en': 'Calling',
  },
  'verseThemeDeliverance': {
    'zh-Hans': '拯救',
    'zh-Hant': '拯救',
    'en': 'Deliverance',
  },
  'verseThemeCommandments': {
    'zh-Hans': '诫命',
    'zh-Hant': '誡命',
    'en': 'Commandments',
  },
  'verseThemeShema': {
    'zh-Hans': '示玛',
    'zh-Hant': '示瑪',
    'en': 'Shema',
  },
  'verseThemeCourage': {
    'zh-Hans': '刚强壮胆',
    'zh-Hant': '剛強壯膽',
    'en': 'Courage',
  },
  'verseThemeLoyalty': {
    'zh-Hans': '忠贞',
    'zh-Hant': '忠貞',
    'en': 'Loyalty',
  },
  'verseThemeFaith': {
    'zh-Hans': '信心',
    'zh-Hant': '信心',
    'en': 'Faith',
  },
  'verseThemeBlessing': {
    'zh-Hans': '蒙福',
    'zh-Hant': '蒙福',
    'en': 'Blessing',
  },
  'verseThemeRevelation': {
    'zh-Hans': '启示',
    'zh-Hant': '啟示',
    'en': 'Revelation',
  },
  'verseThemeServant': {
    'zh-Hans': '受苦的仆人',
    'zh-Hant': '受苦的僕人',
    'en': 'Servant',
  },
  'verseThemeShepherd': {
    'zh-Hans': '牧人',
    'zh-Hant': '牧人',
    'en': 'Shepherd',
  },
  'verseThemeRefuge': {
    'zh-Hans': '避难所',
    'zh-Hant': '避難所',
    'en': 'Refuge',
  },
  'verseThemeRepentance': {
    'zh-Hans': '悔改',
    'zh-Hant': '悔改',
    'en': 'Repentance',
  },
  'verseThemeWord': {
    'zh-Hans': '神的话',
    'zh-Hant': '神的話',
    'en': "God's Word",
  },
  'verseThemeKnown': {
    'zh-Hans': '被神鉴察',
    'zh-Hant': '被神鑒察',
    'en': 'Known by God',
  },
  'verseThemePraise': {
    'zh-Hans': '赞美',
    'zh-Hant': '讚美',
    'en': 'Praise',
  },
  'verseThemeTrust': {
    'zh-Hans': '信靠',
    'zh-Hant': '信靠',
    'en': 'Trust',
  },
  'verseThemeTime': {
    'zh-Hans': '凡事有时',
    'zh-Hant': '凡事有時',
    'en': 'Times & Seasons',
  },
  'verseThemeMessianic': {
    'zh-Hans': '弥赛亚',
    'zh-Hant': '彌賽亞',
    'en': 'Messianic',
  },
  'verseThemeComfort': {
    'zh-Hans': '安慰',
    'zh-Hant': '安慰',
    'en': 'Comfort',
  },
  'verseThemeInvitation': {
    'zh-Hans': '邀请',
    'zh-Hant': '邀請',
    'en': 'Invitation',
  },
  'verseThemeHope': {
    'zh-Hans': '盼望',
    'zh-Hant': '盼望',
    'en': 'Hope',
  },
  'verseThemeNewCovenant': {
    'zh-Hans': '新约',
    'zh-Hant': '新約',
    'en': 'New Covenant',
  },
  'verseThemeFaithfulness': {
    'zh-Hans': '忠心',
    'zh-Hant': '忠心',
    'en': 'Faithfulness',
  },
  'verseThemeBeatitudes': {
    'zh-Hans': '八福',
    'zh-Hant': '八福',
    'en': 'Beatitudes',
  },
  'verseThemePrayer': {
    'zh-Hans': '祷告',
    'zh-Hant': '禱告',
    'en': 'Prayer',
  },
  'verseThemeNarrowWay': {
    'zh-Hans': '窄路',
    'zh-Hant': '窄路',
    'en': 'Narrow Way',
  },
  'verseThemeCommission': {
    'zh-Hans': '大使命',
    'zh-Hant': '大使命',
    'en': 'Great Commission',
  },
  'verseThemeReturning': {
    'zh-Hans': '回家',
    'zh-Hant': '回家',
    'en': 'Returning',
  },
  'verseThemeResurrection': {
    'zh-Hans': '复活',
    'zh-Hant': '復活',
    'en': 'Resurrection',
  },
  'verseThemeWordIncarnate': {
    'zh-Hans': '道成肉身',
    'zh-Hant': '道成肉身',
    'en': 'The Word',
  },
  'verseThemeBornAgain': {
    'zh-Hans': '重生',
    'zh-Hant': '重生',
    'en': 'Born Again',
  },
  'verseThemeWayTruthLife': {
    'zh-Hans': '道路真理生命',
    'zh-Hant': '道路真理生命',
    'en': 'Way Truth Life',
  },
  'verseThemeAbiding': {
    'zh-Hans': '常在',
    'zh-Hant': '常在',
    'en': 'Abiding',
  },
  'verseThemeUnity': {
    'zh-Hans': '合一',
    'zh-Hant': '合一',
    'en': 'Unity',
  },
  'verseThemeMission': {
    'zh-Hans': '宣教',
    'zh-Hant': '宣教',
    'en': 'Mission',
  },
  'verseThemePentecost': {
    'zh-Hans': '五旬节',
    'zh-Hant': '五旬節',
    'en': 'Pentecost',
  },
  'verseThemeSalvation': {
    'zh-Hans': '救恩',
    'zh-Hant': '救恩',
    'en': 'Salvation',
  },
  'verseThemeReconciliation': {
    'zh-Hans': '和好',
    'zh-Hant': '和好',
    'en': 'Reconciliation',
  },
  'verseThemeAssurance': {
    'zh-Hans': '得胜的确据',
    'zh-Hant': '得勝的確據',
    'en': 'Assurance',
  },
  'verseThemeLivingSacrifice': {
    'zh-Hans': '活祭',
    'zh-Hant': '活祭',
    'en': 'Living Sacrifice',
  },
  'verseThemeLove': {
    'zh-Hans': '爱',
    'zh-Hant': '愛',
    'en': 'Love',
  },
  'verseThemeSpiritFruit': {
    'zh-Hans': '圣灵的果子',
    'zh-Hant': '聖靈的果子',
    'en': 'Fruit of the Spirit',
  },
  'verseThemeGrace': {
    'zh-Hans': '恩典',
    'zh-Hant': '恩典',
    'en': 'Grace',
  },
  'verseThemeArmor': {
    'zh-Hans': '神的全副军装',
    'zh-Hant': '神的全副軍裝',
    'en': 'Armor of God',
  },
  'verseThemeHumility': {
    'zh-Hans': '谦卑',
    'zh-Hant': '謙卑',
    'en': 'Humility',
  },
  'verseThemePeace': {
    'zh-Hans': '平安',
    'zh-Hant': '平安',
    'en': 'Peace',
  },
  'verseThemeNewSelf': {
    'zh-Hans': '新人',
    'zh-Hant': '新人',
    'en': 'New Self',
  },
  'verseThemeContentment': {
    'zh-Hans': '知足',
    'zh-Hant': '知足',
    'en': 'Contentment',
  },
  'verseThemeScripture': {
    'zh-Hans': '圣经的功用',
    'zh-Hant': '聖經的功用',
    'en': 'Scripture',
  },
  'verseThemeRunning': {
    'zh-Hans': '奔跑',
    'zh-Hant': '奔跑',
    'en': 'Running the Race',
  },
  'verseThemeTrials': {
    'zh-Hans': '试炼',
    'zh-Hant': '試煉',
    'en': 'Trials',
  },
  'verseThemeChosen': {
    'zh-Hans': '被拣选',
    'zh-Hant': '被揀選',
    'en': 'Chosen',
  },
  'verseThemeNewCreation': {
    'zh-Hans': '新天新地',
    'zh-Hant': '新天新地',
    'en': 'New Creation',
  },
  'verseThemeReturn': {
    'zh-Hans': '主再来',
    'zh-Hant': '主再來',
    'en': 'Return',
  },
  // ── Book-level themes ────────────────────────────────────────
  'verseThemeBeginnings': {
    'zh-Hans': '起源',
    'zh-Hant': '起源',
    'en': 'Beginnings',
  },
  'verseThemeHoliness': {
    'zh-Hans': '圣洁',
    'zh-Hant': '聖潔',
    'en': 'Holiness',
  },
  'verseThemeWilderness': {
    'zh-Hans': '旷野',
    'zh-Hant': '曠野',
    'en': 'Wilderness',
  },
  'verseThemeCovenant': {
    'zh-Hans': '盟约',
    'zh-Hant': '盟約',
    'en': 'Covenant',
  },
  'verseThemeConquest': {
    'zh-Hans': '得地为业',
    'zh-Hant': '得地為業',
    'en': 'Conquest',
  },
  'verseThemeJudges': {
    'zh-Hans': '士师时代',
    'zh-Hant': '士師時代',
    'en': 'Judges Era',
  },
  'verseThemeKingdom': {
    'zh-Hans': '国度',
    'zh-Hant': '國度',
    'en': 'Kingdom',
  },
  'verseThemeChronicle': {
    'zh-Hans': '史记',
    'zh-Hant': '史記',
    'en': 'Chronicle',
  },
  'verseThemeRebuilding': {
    'zh-Hans': '重建',
    'zh-Hant': '重建',
    'en': 'Rebuilding',
  },
  'verseThemeProvidence': {
    'zh-Hans': '神的护佑',
    'zh-Hant': '神的護佑',
    'en': 'Providence',
  },
  'verseThemeSuffering': {
    'zh-Hans': '苦难',
    'zh-Hant': '苦難',
    'en': 'Suffering',
  },
  'verseThemeWorship': {
    'zh-Hans': '敬拜',
    'zh-Hant': '敬拜',
    'en': 'Worship',
  },
  'verseThemeWisdom': {
    'zh-Hans': '智慧',
    'zh-Hant': '智慧',
    'en': 'Wisdom',
  },
  'verseThemeMeaning': {
    'zh-Hans': '人生意义',
    'zh-Hant': '人生意義',
    'en': 'Meaning',
  },
  'verseThemeProphecy': {
    'zh-Hans': '预言',
    'zh-Hant': '預言',
    'en': 'Prophecy',
  },
  'verseThemeLament': {
    'zh-Hans': '哀歌',
    'zh-Hant': '哀歌',
    'en': 'Lament',
  },
  'verseThemeVision': {
    'zh-Hans': '异象',
    'zh-Hant': '異象',
    'en': 'Vision',
  },
  'verseThemeJustice': {
    'zh-Hans': '公义',
    'zh-Hant': '公義',
    'en': 'Justice',
  },
  'verseThemeMercy': {
    'zh-Hans': '怜悯',
    'zh-Hant': '憐憫',
    'en': 'Mercy',
  },
  'verseThemeLife': {
    'zh-Hans': '生命',
    'zh-Hant': '生命',
    'en': 'Life',
  },
  'verseThemeChurch': {
    'zh-Hans': '教会',
    'zh-Hant': '教會',
    'en': 'Church',
  },
  'verseThemeMinistry': {
    'zh-Hans': '事奉',
    'zh-Hant': '事奉',
    'en': 'Ministry',
  },
  'verseThemeFreedom': {
    'zh-Hans': '自由',
    'zh-Hant': '自由',
    'en': 'Freedom',
  },
  'verseThemeJoy': {
    'zh-Hans': '喜乐',
    'zh-Hant': '喜樂',
    'en': 'Joy',
  },
  'verseThemeChrist': {
    'zh-Hans': '基督',
    'zh-Hant': '基督',
    'en': 'Christ',
  },
  'verseThemePastoral': {
    'zh-Hans': '牧养',
    'zh-Hant': '牧養',
    'en': 'Pastoral',
  },
  'verseThemeForgiveness': {
    'zh-Hans': '饶恕',
    'zh-Hant': '饒恕',
    'en': 'Forgiveness',
  },
  'verseThemeLiving': {
    'zh-Hans': '活出信仰',
    'zh-Hant': '活出信仰',
    'en': 'Living Faith',
  },
  'verseThemePromise': {
    'zh-Hans': '应许',
    'zh-Hant': '應許',
    'en': 'Promise',
  },
  'verseThemeTruth': {
    'zh-Hans': '真理',
    'zh-Hant': '真理',
    'en': 'Truth',
  },
  'verseThemeContending': {
    'zh-Hans': '争辩真道',
    'zh-Hant': '爭辯真道',
    'en': 'Contending',
  },
  'verseThemeFinalHope': {
    'zh-Hans': '终极盼望',
    'zh-Hant': '終極盼望',
    'en': 'Final Hope',
  },
  // Round 56 (continued — bible-languages card): replaces the
  // old stat-block grid in the Overview tab. Three source
  // languages with role + sections + background.
  'languagesCardTitle': {
    'zh-Hans': '圣经的原文',
    'zh-Hant': '聖經的原文',
    'en': 'Original languages of the Bible',
  },
  'languagesCardSubtitle': {
    'zh-Hans': '圣经原本由三种语言写成 —— 看看每一种各自承担哪些经文。',
    'zh-Hant': '聖經原本由三種語言寫成 —— 看看每一種各自承擔哪些經文。',
    'en':
        'The three source languages and where each appears in the canon.',
  },
  'languageWordCount': {
    'zh-Hans': '{n} 词',
    'zh-Hant': '{n} 詞',
    'en': '{n} words',
  },
  'languageLemmaCount': {
    'zh-Hans': '{n} 词条',
    'zh-Hant': '{n} 詞條',
    'en': '{n} lemmas',
  },
  // Hebrew
  'languageHebrewName': {
    'zh-Hans': '希伯来文',
    'zh-Hant': '希伯來文',
    'en': 'Hebrew',
  },
  'languageHebrewRole': {
    'zh-Hans': '旧约绝大部分',
    'zh-Hant': '舊約絕大部分',
    'en': 'Most of the Old Testament',
  },
  'languageHebrewSections': {
    'zh-Hans':
        '旧约 39 卷的绝大部分 —— 摩西五经、历史书、诗歌智慧书、绝大多数先知书。',
    'zh-Hant':
        '舊約 39 卷的絕大部分 —— 摩西五經、歷史書、詩歌智慧書、絕大多數先知書。',
    'en':
        'Nearly all 39 books of the Old Testament — Pentateuch, histories, poetry / wisdom, and almost the entire prophetic corpus.',
  },
  'languageHebrewBackground': {
    'zh-Hans':
        '西北闪族语系，22 个辅音字母，从右向左书写。马所拉抄本所采用的元音点系统是中古时期 (主后 7-10 世纪) 才加入的；圣经成书时只写辅音。',
    'zh-Hant':
        '西北閃族語系，22 個輔音字母，從右向左書寫。馬所拉抄本所採用的元音點系統是中古時期 (主後 7-10 世紀) 才加入的；聖經成書時只寫輔音。',
    'en':
        'Northwest Semitic language with a 22-letter consonantal alphabet, read right-to-left. The vowel-pointing system in the Masoretic manuscripts was a much later addition (7th–10th centuries AD) — when Scripture was first written, only the consonants appeared on the page.',
  },
  // Aramaic
  'languageAramaicName': {
    'zh-Hans': '亚兰文',
    'zh-Hant': '亞蘭文',
    'en': 'Aramaic',
  },
  'languageAramaicRole': {
    'zh-Hans': '旧约若干段落 + 新约几处引文',
    'zh-Hant': '舊約若干段落 + 新約幾處引文',
    'en': 'Pockets of the Old Testament + a few NT quotations',
  },
  'languageAramaicSections': {
    'zh-Hans':
        '但以理 2:4b–7:28、以斯拉 4:8–6:18 与 7:12–26、创世记 31:47 (一处地名)、耶利米书 10:11 (一节)。新约中保留了几句亚兰文原文：「亚巴 父啊」(可 14:36)、「以利以利拉马撒巴各大尼」(可 15:34)、「大利大古米」(可 5:41)、「以法大」(可 7:34)、「玛拉那他」(林前 16:22)。',
    'zh-Hant':
        '但以理 2:4b–7:28、以斯拉 4:8–6:18 與 7:12–26、創世記 31:47 (一處地名)、耶利米書 10:11 (一節)。新約中保留了幾句亞蘭文原文：「亞巴 父啊」(可 14:36)、「以利以利拉馬撒巴各大尼」(可 15:34)、「大利大古米」(可 5:41)、「以法大」(可 7:34)、「瑪拉那他」(林前 16:22)。',
    'en':
        'Daniel 2:4b–7:28, Ezra 4:8–6:18 and 7:12–26, Genesis 31:47 (a place name), Jeremiah 10:11 (one verse). The New Testament preserves several Aramaic phrases on the lips of Jesus and the early church: "abba" (Mark 14:36), "eloi eloi lema sabachthani" (Mark 15:34), "talitha koum" (Mark 5:41), "ephphatha" (Mark 7:34), and "maranatha" (1 Cor 16:22).',
  },
  'languageAramaicBackground': {
    'zh-Hans':
        '与希伯来文同属西北闪族语系，是希伯来文的近亲。亚述、巴比伦、波斯帝国先后扩张后，亚兰文成为近东的通用语，被掳归回时期的犹太人多以亚兰文为日常语言；耶稣时代的加利利与犹太地仍以亚兰文交谈。',
    'zh-Hant':
        '與希伯來文同屬西北閃族語系，是希伯來文的近親。亞述、巴比倫、波斯帝國先後擴張後，亞蘭文成為近東的通用語，被擄歸回時期的猶太人多以亞蘭文為日常語言；耶穌時代的加利利與猶太地仍以亞蘭文交談。',
    'en':
        'Closely related to Hebrew (same Northwest Semitic family). After the Assyrian, Babylonian, and Persian empires successively dominated the region, Aramaic became the everyday lingua franca of the Near East. Returning exiles spoke it as their first language, and it was still the conversational tongue of Galilee and Judea in Jesus\' day.',
  },
  // Greek
  'languageGreekName': {
    'zh-Hans': '希腊文',
    'zh-Hant': '希臘文',
    'en': 'Greek',
  },
  'languageGreekRole': {
    'zh-Hans': '新约全书 + 七十士译本',
    'zh-Hant': '新約全書 + 七十士譯本',
    'en': 'All of the New Testament + LXX',
  },
  'languageGreekSections': {
    'zh-Hans':
        '新约 27 卷全部用希腊文写成 —— 福音书、使徒行传、保罗书信、其他书信、启示录。此外旧约的「七十士译本」(LXX) 也是希腊文，主前 3-2 世纪在亚历山大城翻译完成，是新约作者引用旧约时最常依据的版本。',
    'zh-Hant':
        '新約 27 卷全部用希臘文寫成 —— 福音書、使徒行傳、保羅書信、其他書信、啟示錄。此外舊約的「七十士譯本」(LXX) 也是希臘文，主前 3-2 世紀在亞歷山大城翻譯完成，是新約作者引用舊約時最常依據的版本。',
    'en':
        'All 27 books of the New Testament — Gospels, Acts, Pauline epistles, the catholic letters, and Revelation. Plus the Septuagint (LXX), the Greek translation of the Hebrew Old Testament completed in Alexandria in the 3rd–2nd century BC and the version most often quoted when NT authors cite the OT.',
  },
  'languageGreekBackground': {
    'zh-Hans':
        '通用希腊文 (Koine，「平常的」)，亚历山大大帝东征后，整个地中海与近东世界的共通语言。新约作者刻意采用这种百姓都能听懂的口语形式，而不是雅典文人的古典希腊文，让福音从市井走向万民。',
    'zh-Hant':
        '通用希臘文 (Koine，「平常的」)，亞歷山大大帝東征後，整個地中海與近東世界的共通語言。新約作者刻意採用這種百姓都能聽懂的口語形式，而不是雅典文人的古典希臘文，讓福音從市井走向萬民。',
    'en':
        'Koine ("common") Greek, the everyday register of the Hellenistic Mediterranean after Alexander the Great\'s conquests. The NT authors deliberately wrote in this accessible form — the Greek of the marketplace — rather than the polished Attic of classical literature, so the gospel could travel through ordinary readers to the ends of the empire.',
  },
  // Round 56 (continued — Aramaic highlight): badge label rendered on
  // word chips inside the OriginalsSheet for words detected as
  // Aramaic. Kept short (a single character couplet in Chinese) so it
  // fits inside the 56–140 px chip width without wrapping.
  'aramaicWordBadge': {
    'zh-Hans': '亚兰文',
    'zh-Hant': '亞蘭文',
    'en': 'Aramaic',
  },
  // Round 56 (continued — Aramaic copy): tooltip + toast for the
  // copy-list button on the Aramaic passages sheet.
  'aramCopyTooltip': {
    'zh-Hans': '复制亚兰文经文列表',
    'zh-Hant': '複製亞蘭文經文列表',
    'en': 'Copy Aramaic passage list',
  },
  'aramCopiedToast': {
    'zh-Hans': '亚兰文经文列表已复制',
    'zh-Hant': '亞蘭文經文列表已複製',
    'en': 'Aramaic passage list copied',
  },
  // ── Aramaic sheet (full passage list) ─────────────────────────
  'aramSheetTitle': {
    'zh-Hans': '圣经中的亚兰文',
    'zh-Hant': '聖經中的亞蘭文',
    'en': 'Aramaic in the Bible',
  },
  'aramSheetSubtitle': {
    'zh-Hans': '点击任一段进入释经面板 — 字字对照原文 + Gemini AI 解释。',
    'zh-Hant': '點擊任一段進入釋經面板 — 字字對照原文 + Gemini AI 解釋。',
    'en':
        'Tap any entry to open the verse with word-by-word breakdown and Gemini AI explanation.',
  },
  'aramGroupOt': {
    'zh-Hans': '旧约段落',
    'zh-Hant': '舊約段落',
    'en': 'Old Testament sections',
  },
  'aramGroupNt': {
    'zh-Hans': '新约引用',
    'zh-Hant': '新約引用',
    'en': 'New Testament phrases',
  },
  // OT — full sections written in Aramaic.
  'aramRefGenesis': {
    'zh-Hans': '雅各与拉班立约的亚兰文地名',
    'zh-Hant': '雅各與拉班立約的亞蘭文地名',
    'en': "Jacob and Laban's covenant — Aramaic place name",
  },
  'aramDescGenesis': {
    'zh-Hans':
        '雅各与舅舅拉班立石为约时，拉班用亚兰文称那石堆为「伊迦尔撒哈杜他」(Jegar-sahadutha)，意为「见证之堆」；雅各则用希伯来文称之为「迦累得」(Galeed)。两个名字含义相同 — 圣经特地保留两种语言以反映双方各自的母语。',
    'zh-Hant':
        '雅各與舅舅拉班立石為約時，拉班用亞蘭文稱那石堆為「伊迦爾撒哈杜他」(Jegar-sahadutha)，意為「見證之堆」；雅各則用希伯來文稱之為「迦累得」(Galeed)。兩個名字含義相同 — 聖經特地保留兩種語言以反映雙方各自的母語。',
    'en':
        'When Jacob and his uncle Laban set up a stone witness to their covenant, Laban gives it the Aramaic name "Jegar-sahadutha" ("heap of witness") while Jacob gives it the Hebrew "Galeed" with the same meaning. The text preserves both names — a tiny window into the bilingual world of the patriarchs.',
  },
  'aramRefJeremiah': {
    'zh-Hans': '一节亚兰文：警告偶像必灭亡',
    'zh-Hant': '一節亞蘭文：警告偶像必滅亡',
    'en': 'One Aramaic verse — gods that did not make the heavens',
  },
  'aramDescJeremiah': {
    'zh-Hans':
        '在以希伯来文为主的耶利米书中，第 10 章 11 节突然切换为亚兰文。这是先知给被掳百姓的「应答口诀」 — 当外邦人问他们是否要敬拜列国的偶像时，可以用亚兰文 (当时的国际通用语) 直接回应：「不是创造天地的神必从地上、从天下被除灭。」',
    'zh-Hant':
        '在以希伯來文為主的耶利米書中，第 10 章 11 節突然切換為亞蘭文。這是先知給被擄百姓的「應答口訣」 — 當外邦人問他們是否要敬拜列國的偶像時，可以用亞蘭文 (當時的國際通用語) 直接回應：「不是創造天地的神必從地上、從天下被除滅。」',
    'en':
        'A single Aramaic verse embedded in an otherwise Hebrew chapter. It functions as a ready-made reply for exiles to use against the local idols of their captors — written in Aramaic (the international language of the day) so they could quote it back directly to anyone who pressed them to worship pagan gods.',
  },
  'aramRefDaniel': {
    'zh-Hans': '但以理 2:4–7:28（半本书）',
    'zh-Hant': '但以理 2:4–7:28（半本書）',
    'en': 'Daniel 2:4–7:28 — six chapters in Aramaic',
  },
  'aramDescDaniel': {
    'zh-Hans':
        '从迦勒底术士「用亚兰文对王说话」起 (2:4)，到第 7 章的四兽异象结束，整整六章用亚兰文写成 — 帝国的官方语言。叙事 (尼布甲尼撒梦像、火窑、狮坑) 和异象都集中在这段。1 章、8–12 章则回到希伯来文。',
    'zh-Hant':
        '從迦勒底術士「用亞蘭文對王說話」起 (2:4)，到第 7 章的四獸異象結束，整整六章用亞蘭文寫成 — 帝國的官方語言。敘事 (尼布甲尼撒夢像、火窯、獅坑) 和異象都集中在這段。1 章、8–12 章則回到希伯來文。',
    'en':
        'From the moment the Babylonian wise men reply to the king "in Aramaic" (2:4) through the apocalyptic four-beasts vision of chapter 7, six full chapters of Daniel are written in Aramaic — the language of the empire he served. The famous narratives (Nebuchadnezzar\'s dream, the fiery furnace, the lions\' den) all sit in this section. Chapter 1 and chapters 8–12 return to Hebrew.',
  },
  'aramRefEzraA': {
    'zh-Hans': '以斯拉 4:8–6:18 — 波斯朝廷文书',
    'zh-Hant': '以斯拉 4:8–6:18 — 波斯朝廷文書',
    'en': 'Ezra 4:8–6:18 — Persian court correspondence',
  },
  'aramDescEzraA': {
    'zh-Hans':
        '以斯拉记保留了被掳归回时期，犹太人与波斯朝廷之间往来的奏章、上谕、批文，原文是亚兰文 (帝国的行政通用语)，编者直接照录。重点是关于重建圣殿的辩争 — 反对者上书阻挠，大利乌王查档批准重建。',
    'zh-Hant':
        '以斯拉記保留了被擄歸回時期，猶太人與波斯朝廷之間往來的奏章、上諭、批文，原文是亞蘭文 (帝國的行政通用語)，編者直接照錄。重點是關於重建聖殿的辯爭 — 反對者上書阻撓，大利烏王查檔批准重建。',
    'en':
        'During the post-exile period, official correspondence between the Jewish community and the Persian administration was conducted in Aramaic (the imperial language of record). Ezra preserves the original documents verbatim — including the opponents\' letter trying to halt the rebuilding of the Temple, and Darius\' decree authorising it after the imperial archives were searched.',
  },
  'aramRefEzraB': {
    'zh-Hans': '以斯拉 7:12–26 — 亚达薛西王的谕旨',
    'zh-Hant': '以斯拉 7:12–26 — 亞達薛西王的諭旨',
    'en': "Ezra 7:12–26 — Artaxerxes' decree",
  },
  'aramDescEzraB': {
    'zh-Hans':
        '亚达薛西王亲自颁给以斯拉的谕旨全文，授权他带百姓回耶路撒冷并按照神的律法治理。原文是亚兰文，以斯拉同样照录。这道诏书是以斯拉一切事工的法律根基。',
    'zh-Hant':
        '亞達薛西王親自頒給以斯拉的諭旨全文，授權他帶百姓回耶路撒冷並按照神的律法治理。原文是亞蘭文，以斯拉同樣照錄。這道詔書是以斯拉一切事工的法律根基。',
    'en':
        "The full text of Artaxerxes' decree commissioning Ezra to lead the return to Jerusalem and to govern by the law of his God. Issued in imperial Aramaic and quoted verbatim — the legal charter underwriting Ezra's entire mission.",
  },
  // NT — Aramaic phrases preserved in the Greek text.
  'aramRefRaca': {
    'zh-Hans': '太 5:22 — 「拉加」',
    'zh-Hant': '太 5:22 — 「拉加」',
    'en': 'Matthew 5:22 — "raca"',
  },
  'aramDescRaca': {
    'zh-Hans':
        '亚兰文「ריקא」音译，意为「空头」「废人」 — 当时一种带轻蔑的骂语。耶稣在登山宝训中警告：骂弟兄是拉加的，难免公会的审断。',
    'zh-Hant':
        '亞蘭文「ריקא」音譯，意為「空頭」「廢人」 — 當時一種帶輕蔑的罵語。耶穌在登山寶訓中警告：罵弟兄是拉加的，難免公會的審斷。',
    'en':
        'A transliteration of the Aramaic "raqa" — roughly "empty-head" or "good-for-nothing", a contemptuous slur in Jesus\' day. In the Sermon on the Mount, Jesus warns that calling a brother "raca" makes one liable to the council\'s judgement.',
  },
  'aramRefTalitha': {
    'zh-Hans': '可 5:41 — 「大利大古米」',
    'zh-Hant': '可 5:41 — 「大利大古米」',
    'en': 'Mark 5:41 — "talitha koum"',
  },
  'aramDescTalitha': {
    'zh-Hans':
        '耶稣对睚鲁已死的女儿说的亚兰文原话，意为「闺女，起来」。马可福音保留耶稣的原话，紧接着用希腊文翻译给读者 — 这种「保留 + 翻译」格式是马可福音的标志之一，让读者听见耶稣亲口说的方言。',
    'zh-Hant':
        '耶穌對睚魯已死的女兒說的亞蘭文原話，意為「閨女，起來」。馬可福音保留耶穌的原話，緊接著用希臘文翻譯給讀者 — 這種「保留 + 翻譯」格式是馬可福音的標誌之一，讓讀者聽見耶穌親口說的方言。',
    'en':
        'Jesus\' actual Aramaic words to the dead daughter of Jairus — "Little girl, get up." Mark preserves the Aramaic and immediately glosses it in Greek for his readers; this "quote + translate" pattern is a signature of Mark\'s gospel, letting readers hear Jesus in his own dialect.',
  },
  'aramRefEphphatha': {
    'zh-Hans': '可 7:34 — 「以法大」',
    'zh-Hant': '可 7:34 — 「以法大」',
    'en': 'Mark 7:34 — "ephphatha"',
  },
  'aramDescEphphatha': {
    'zh-Hans':
        '亚兰文，意为「开了吧」。耶稣对一位耳聋舌结的人说话医治时所用的原话。马可同样紧接着翻译给希腊读者听。',
    'zh-Hant':
        '亞蘭文，意為「開了吧」。耶穌對一位耳聾舌結的人說話醫治時所用的原話。馬可同樣緊接著翻譯給希臘讀者聽。',
    'en':
        'Aramaic for "be opened." Spoken by Jesus over a deaf-mute man\'s ears at the moment of healing. Mark again preserves the original word and glosses it in Greek.',
  },
  'aramRefAbba': {
    'zh-Hans': '可 14:36 — 「阿爸，父」',
    'zh-Hant': '可 14:36 — 「阿爸，父」',
    'en': 'Mark 14:36 — "abba"',
  },
  'aramDescAbba': {
    'zh-Hans':
        '亚兰文中孩童对父亲最亲昵的称呼 — 类似「爹」。耶稣在客西马尼园祷告时所用，保罗在罗马书 8:15、加拉太书 4:6 也保留这个亚兰文，强调圣灵使我们能像耶稣那样亲昵地呼喊神为父。',
    'zh-Hant':
        '亞蘭文中孩童對父親最親暱的稱呼 — 類似「爹」。耶穌在客西馬尼園禱告時所用，保羅在羅馬書 8:15、加拉太書 4:6 也保留這個亞蘭文，強調聖靈使我們能像耶穌那樣親暱地呼喊神為父。',
    'en':
        'The Aramaic word a child uses for the father — closer to "papa" than the formal "father". Jesus uses it in Gethsemane, and Paul keeps it in the original in Romans 8:15 and Galatians 4:6, emphasising that the Spirit lets believers call God by the same intimate name Jesus did.',
  },
  'aramRefSabachthani': {
    'zh-Hans': '可 15:34 — 「以利以利拉马撒巴各大尼」',
    'zh-Hant': '可 15:34 — 「以利以利拉馬撒巴各大尼」',
    'en': 'Mark 15:34 — "eloi eloi lema sabachthani"',
  },
  'aramDescSabachthani': {
    'zh-Hans':
        '耶稣在十字架上的呼喊，意为「我的神，我的神，为什么离弃我？」 — 引自诗篇 22:1。马可保留亚兰文版本，马太 27:46 则保留略带希伯来色彩的「以利以利」版本。',
    'zh-Hant':
        '耶穌在十字架上的呼喊，意為「我的神，我的神，為什麼離棄我？」 — 引自詩篇 22:1。馬可保留亞蘭文版本，馬太 27:46 則保留略帶希伯來色彩的「以利以利」版本。',
    'en':
        "Jesus' cry from the cross — \"My God, my God, why have you forsaken me?\" — quoting Psalm 22:1. Mark preserves the Aramaic form (\"eloi\"), Matthew 27:46 the slightly more Hebrew-coloured \"eli eli\".",
  },
  'aramRefMaranatha': {
    'zh-Hans': '林前 16:22 — 「玛拉那他」',
    'zh-Hant': '林前 16:22 — 「瑪拉那他」',
    'en': '1 Corinthians 16:22 — "marana tha"',
  },
  'aramDescMaranatha': {
    'zh-Hans':
        '保罗在哥林多前书末尾用的亚兰文教会问候语 — 「我们的主啊，你来吧」(marana tha)，或拼作 maran atha 时意为「我们的主已经来了」。是早期教会承袭自亚兰语圈的礼仪短语，被保罗原文保留下来。',
    'zh-Hant':
        '保羅在哥林多前書末尾用的亞蘭文教會問候語 — 「我們的主啊，你來吧」(marana tha)，或拼作 maran atha 時意為「我們的主已經來了」。是早期教會承襲自亞蘭語圈的禮儀短語，被保羅原文保留下來。',
    'en':
        "Paul ends 1 Corinthians with this Aramaic liturgical greeting — \"Our Lord, come!\" (marana tha) or, parsed differently, \"Our Lord has come\" (maran atha). An early-church prayer kept in its original Aramaic, a window into the language of the very first Christian gatherings.",
  },
  'lookupTopicCreation': {
    'zh-Hans': '创造',
    'zh-Hant': '創造',
    'en': 'Creation',
  },
  'lookupTopicShepherd': {
    'zh-Hans': '牧人',
    'zh-Hant': '牧人',
    'en': 'The Shepherd',
  },
  'lookupTopicServant': {
    'zh-Hans': '受苦的仆人',
    'zh-Hant': '受苦的僕人',
    'en': 'Suffering Servant',
  },
  'lookupTopicLogos': {
    'zh-Hans': '道',
    'zh-Hant': '道',
    'en': 'The Word',
  },
  'lookupTopicLove': {
    'zh-Hans': '神的爱',
    'zh-Hant': '神的愛',
    'en': "God's love",
  },
  'lookupTopicProvidence': {
    'zh-Hans': '万事互相效力',
    'zh-Hant': '萬事互相效力',
    'en': 'All things together',
  },
  'lookupTopicTriad': {
    'zh-Hans': '信望爱',
    'zh-Hant': '信望愛',
    'en': 'Faith, hope, love',
  },
  'lookupTopicFaith': {
    'zh-Hans': '信',
    'zh-Hant': '信',
    'en': 'Faith',
  },
  'lookupFeaturesTitle': {
    'zh-Hans': '释经面板里你能做什么',
    'zh-Hant': '釋經面板裡你能做什麼',
    'en': 'Inside the exegesis sheet',
  },
  'lookupFeatureWords': {
    'zh-Hans': '字字对照原文（希伯来文 / 希腊文）+ 音译 + 字义',
    'zh-Hant': '字字對照原文（希伯來文 / 希臘文）+ 音譯 + 字義',
    'en':
        'Word-by-word original-language breakdown with transliteration and gloss.',
  },
  'lookupFeatureTap': {
    'zh-Hans': '点击任一原文字，看完整 Strong\'s 词条 — 字义、词源、出现次数',
    'zh-Hant': '點擊任一原文字，看完整 Strong\'s 詞條 — 字義、詞源、出現次數',
    'en':
        "Tap any word for the full Strong's entry — meaning, derivation, occurrence count.",
  },
  'lookupFeatureFamily': {
    'zh-Hans': '词族（亲属词）+ 同义词对比，相关字根一目了然',
    'zh-Hant': '詞族（親屬詞）+ 同義詞對比，相關字根一目了然',
    'en':
        'Word family + synonym comparison — see related lemmas at a glance.',
  },
  'lookupFeatureConcordance': {
    'zh-Hans': '可点击的经文索引（concordance），该字出现的每一节经文一键直达',
    'zh-Hant': '可點擊的經文索引（concordance），該字出現的每一節經文一鍵直達',
    'en':
        'Tappable concordance — every verse the word appears in, one tap to navigate.',
  },
  'lookupFeatureCopy': {
    'zh-Hans': '一键复制原文对照表格，方便讲道预备或笔记',
    'zh-Hant': '一鍵複製原文對照表格，方便講道預備或筆記',
    'en':
        'Copy the interlinear table to clipboard for sermon prep or notes.',
  },
  // Round 56: Word Distribution tab — exposes the
  // WordDistributionTable widget (previously only reachable via
  // tap-a-verse → originals sheet → tap a word → "show
  // distribution") as a standalone tab.
  'statsDistribution': {
    'zh-Hans': '字词分布',
    'zh-Hant': '字詞分布',
    'en': 'Distribution',
  },
  'statsDistributionHint': {
    'zh-Hans': '选择字根查看其在各书卷的分布及词族对照',
    'zh-Hant': '選擇字根查看其在各書卷的分布及詞族對照',
    'en':
        'Pick a Strong\'s word to see its distribution across books, plus word-family + synonym comparison.',
  },
  'statsDistributionPicker': {
    'zh-Hans': '更换字根',
    'zh-Hant': '更換字根',
    'en': 'Change word',
  },
  'statsDistributionEmpty': {
    'zh-Hans': '请选择一个字根',
    'zh-Hant': '請選擇一個字根',
    'en': 'Pick a Strong\'s word to begin.',
  },
  'statsBook': {'zh-Hans': '书卷', 'zh-Hant': '書卷', 'en': 'Book'},
  'statsChapters': {'zh-Hans': '章数', 'zh-Hant': '章數', 'en': 'Chapters'},
  'statsVerses': {'zh-Hans': '节数', 'zh-Hant': '節數', 'en': 'Verses'},
  'statsWords': {'zh-Hans': '字词数', 'zh-Hant': '字詞數', 'en': 'Words'},
  'statsChars':
      {'zh-Hans': '字符数', 'zh-Hant': '字符數', 'en': 'Characters'},
  'statsAvgWordsVerse': {
    'zh-Hans': '平均字词/节',
    'zh-Hant': '平均字詞/節',
    'en': 'Avg w/v',
  },
  'statsTime':
      {'zh-Hans': '阅读时间(分)', 'zh-Hant': '閱讀時間(分)', 'en': 'Time (m)'},
  'statsReadingTime': {
    'zh-Hans': '阅读时间 @ 200 wpm',
    'zh-Hant': '閱讀時間 @ 200 wpm',
    'en': 'Reading time @ 200 wpm',
  },
  'statsLongestShortest': {
    'zh-Hans': '最长与最短书卷',
    'zh-Hant': '最長與最短書卷',
    'en': 'Longest and shortest books',
  },
  'statsLongest': {
    'zh-Hans': '最长(按字词数)',
    'zh-Hant': '最長(按字詞數)',
    'en': 'Longest (by word count)',
  },
  'statsShortest': {
    'zh-Hans': '最短(按字词数)',
    'zh-Hant': '最短(按字詞數)',
    'en': 'Shortest (by word count)',
  },
  'statsVocabulary':
      {'zh-Hans': '词汇', 'zh-Hant': '詞彙', 'en': 'Vocabulary'},
  'statsTopWords': {
    'zh-Hans': '高频字词',
    'zh-Hant': '高頻字詞',
    'en': 'Top words',
  },
  'statsTopWordsSub': {
    'zh-Hans': '出现频次最高的实词(已过滤虚词)。',
    'zh-Hant': '出現頻次最高的實詞(已過濾虛詞)。',
    'en': 'Frequency of content words (function words filtered).',
  },
  'statsHapax': {
    'zh-Hans': '独例字词',
    'zh-Hant': '獨例字詞',
    'en': 'Hapax legomena',
  },
  'statsHapaxSub': {
    'zh-Hans': '在所选范围内仅出现一次的字词。',
    'zh-Hant': '在所選範圍內僅出現一次的字詞。',
    'en': 'Words appearing only once in the selected scope.',
  },
  'statsNoHapax':
      {'zh-Hans': '— 无 —', 'zh-Hant': '— 無 —', 'en': '— none —'},
  'statsScope': {'zh-Hans': '范围:', 'zh-Hant': '範圍:', 'en': 'Scope:'},
  'statsAllCanon': {
    'zh-Hans': '整本圣经',
    'zh-Hant': '整本聖經',
    'en': 'Whole Bible',
  },
  'statsScopeTotal': {
    'zh-Hans': '所选范围总字词数:{n}',
    'zh-Hant': '所選範圍總字詞數:{n}',
    'en': 'Total words in scope: {n}',
  },
  'libraryEmptyNotes': {
    'zh-Hans': '尚无笔记。长按经文,点击笔记图标即可添加。',
    'zh-Hant': '尚無筆記。長按經文,點擊筆記圖標即可添加。',
    'en': 'No notes yet. Long-press a verse and tap the note icon to add one.',
  },
  'libraryEmptyBookmarks': {
    'zh-Hans': '尚无书签。长按经文,点击书签图标即可添加。',
    'zh-Hant': '尚無書籤。長按經文,點擊書籤圖標即可添加。',
    'en': 'No bookmarks yet. Long-press a verse and tap the bookmark icon.',
  },
  'tabNotes': {'zh-Hans': '笔记', 'zh-Hant': '筆記', 'en': 'Notes'},
  'tabBookmarks': {'zh-Hans': '书签', 'zh-Hant': '書籤', 'en': 'Bookmarks'},
  // 2026-05-21 (v1.2.70): Notes scope filter — WeDevote-style.
  'notesScopeAll': {'zh-Hans': '全部', 'zh-Hant': '全部', 'en': 'All'},
  'notesScopeChapter': {
    'zh-Hans': '本章',
    'zh-Hant': '本章',
    'en': 'This chapter',
  },
  'notesScopeBook': {
    'zh-Hans': '本书',
    'zh-Hant': '本書',
    'en': 'This book',
  },
  'notesScopeChapterEmpty': {
    'zh-Hans': '本章还没有笔记。',
    'zh-Hant': '本章還沒有筆記。',
    'en': 'No notes in this chapter yet.',
  },
  'notesScopeBookEmpty': {
    'zh-Hans': '本书还没有笔记。',
    'zh-Hant': '本書還沒有筆記。',
    'en': 'No notes in this book yet.',
  },
  'notesScopeNeedsLocation': {
    'zh-Hans': '请先打开圣经,以查看本章/本书的笔记。',
    'zh-Hant': '請先打開聖經,以查看本章/本書的筆記。',
    'en': 'Open the Bible first to see notes for this chapter / book.',
  },
  // 2026-05-24 (v1.2.91): note editor — optional title field hint.
  // Empty title = falls back to verse reference as the Library
  // tile header (current pre-v1.2.91 behaviour).
  'noteTitleHint': {
    'zh-Hans': '标题（可选）',
    'zh-Hant': '標題（可選）',
    'en': 'Title (optional)',
  },
  // 2026-05-24 (v1.2.91): floating-toast confirmation after the
  // user taps Save or Delete in the note editor. Reassures users
  // who couldn't tell the difference between "tapped Save" and
  // "tapped Cancel/closed the sheet" — both close the sheet, but
  // only the former actually persists.
  'noteSaved': {
    'zh-Hans': '笔记已保存',
    'zh-Hant': '筆記已儲存',
    'en': 'Note saved',
  },
  'noteDeleted': {
    'zh-Hans': '笔记已删除',
    'zh-Hant': '筆記已刪除',
    'en': 'Note deleted',
  },
  // 2026-05-24 (v1.2.91): Library → Notes sort picker. Tooltip + the
  // three sort-mode labels in a PopupMenuButton next to the scope
  // segmented control.
  'notesSortLabel': {'zh-Hans': '排序', 'zh-Hant': '排序', 'en': 'Sort'},
  'notesSortCanonical': {
    'zh-Hans': '按圣经顺序',
    'zh-Hant': '按聖經順序',
    'en': 'Bible order',
  },
  'notesSortRecent': {
    'zh-Hans': '最近更新',
    'zh-Hant': '最近更新',
    'en': 'Recently updated',
  },
  'notesSortOldest': {
    'zh-Hans': '最早创建',
    'zh-Hant': '最早建立',
    'en': 'Oldest first',
  },
  'home': {
    'zh-Hans': '主页',
    'zh-Hant': '主頁',
    'en': 'Home',
  },
  'homeRecentBookmarks': {
    'zh-Hans': '最近书签',
    'zh-Hant': '最近書籤',
    'en': 'Recent bookmarks',
  },
  'continueReading': {
    // The hero CTA on the dashboard. Earlier copy was '继续阅读 /
    // Continue reading' which felt generic for a Bible-first app.
    // '读经' is the natural Chinese phrase for "read scripture";
    // 'Read Bible' is the English equivalent — direct, on-brand,
    // and pairs with the book + chapter line below the CTA without
    // sounding redundant ("Continue reading: Genesis 1" vs "Read
    // Bible: Genesis 1").
    'zh-Hans': '读经',
    'zh-Hant': '讀經',
    'en': 'Read Bible',
  },
  // Companion CTA below the Bible "Read Bible" hero — the "pick up
  // where you left off in your last sermon" card. Wording mirrors
  // the existing "继续阅读 / Resume" idiom for tracked content.
  'resumeSermon': {
    'zh-Hans': '继续讲道',
    'zh-Hant': '繼續講道',
    'en': 'Resume sermon',
  },
  'dailyVerse': {
    'zh-Hans': '每日金句',
    'zh-Hant': '每日金句',
    'en': 'Verse of the Day',
  },
  // Shown beneath the daily-verse citation when the verse text was
  // pulled from a fallback Bible (e.g. user is on LJK1, today's
  // verse is OT, we display the CUVS-YHWH text). {version} is the
  // friendly menuLabel of the fallback bundle.
  'dailyVerseFromFallback': {
    'zh-Hans': '本句显示自《{version}》',
    'zh-Hant': '本句顯示自《{version}》',
    'en': 'Shown from {version}',
  },
  // ── Onboarding tour (Round 34) ──────────────────────────────────
  'skip': {'zh-Hans': '跳过', 'zh-Hant': '跳過', 'en': 'Skip'},
  'next': {'zh-Hans': '下一步', 'zh-Hant': '下一步', 'en': 'Next'},
  'getStarted': {
    'zh-Hans': '开始使用',
    'zh-Hant': '開始使用',
    'en': 'Get started',
  },
  // Onboarding tour copy. Bumped for v2 (Round 55) so the tour
  // covers the full app surface — sermons, family tree, timeline,
  // evidence, news, and the new dashboard customization. Original
  // v1 strings (welcome / plans / library / cloud) are kept above
  // for any localizations downstream that might still reference
  // them.
  'onboardWelcomeTitle': {
    'zh-Hans': '欢迎使用 SeekSparks',
    'zh-Hant': '歡迎使用 SeekSparks',
    'en': 'Welcome to SeekSparks',
  },
  'onboardWelcomeBody': {
    'zh-Hans': '双语圣经阅读应用，14 个译本（英文／简体／繁体）。主页的「读经」卡片会带你回到上次离开的位置。',
    'zh-Hant': '雙語聖經閱讀應用，14 個譯本（英文／簡體／繁體）。主頁的「讀經」卡片會帶你回到上次離開的位置。',
    'en':
        'A bilingual Bible reader with 14 translations across English and Chinese. The "Read Bible" card on Home picks up exactly where you left off.',
  },
  'onboardReadTitle': {
    'zh-Hans': '阅读、高亮、研经',
    'zh-Hant': '閱讀、高亮、研經',
    'en': 'Read, highlight, study',
  },
  'onboardReadBody': {
    'zh-Hans': '长按经文可添加彩色高亮、书签和笔记；点击经文引用即可跳转，点击 Strong\'s 字可查原文。顶部搜索覆盖整本圣经。',
    'zh-Hant': '長按經文可添加彩色高亮、書籤和筆記；點擊經文引用即可跳轉，點擊 Strong\'s 字可查原文。頂部搜索覆蓋整本聖經。',
    'en':
        'Long-press a verse for color highlights, bookmarks, and notes. Tap any reference to jump; tap a Strong\'s word for originals. Search the whole Bible from the header.',
  },
  // 2026-05-09 (v1.2.9): user pointed out the v2 tour didn't even
  // mention AI — now central to v1.2.0–v1.2.8 (search by theme,
  // BDAG-style word study, evidence Q&A, BYOK key-test). New slide
  // sits between "Read" and "Sermons" so the natural reading-flow
  // intro leads into "and here's what AI can do on top of it".
  'onboardAiTitle': {
    'zh-Hans': 'AI 研经助手',
    'zh-Hant': 'AI 研經助手',
    'en': 'AI study helpers',
  },
  'onboardAiBody': {
    'zh-Hans': '按主题搜经文（"爱"、"信心"），点希腊文／希伯来文原文看 BDAG 级深度释义，对考古和手稿提具体问题。AI 由 Gemini 驱动——可在 设置 → SeekSparks AI 粘贴自己的免费密钥（按 Test 验证），用自己的额度跳过共享池。',
    'zh-Hant': '按主題搜經文（「愛」、「信心」），點希臘文／希伯來文原文看 BDAG 級深度釋義，對考古和手稿提具體問題。AI 由 Gemini 驅動——可在 設定 → SeekSparks AI 貼上自己的免費密鑰（按 Test 驗證），用自己的額度跳過共享池。',
    'en':
        'Search the Bible by theme ("love", "faith"), tap any Greek or Hebrew word for a BDAG-style deep dive, or ask questions about archaeology and manuscripts. Powered by Gemini — paste your own free key in Settings → AI (and tap Test to verify) to skip the shared developer pool.',
  },
  'onboardSermonsTitle': {
    'zh-Hans': '讲道',
    'zh-Hant': '講道',
    'en': 'Sermons',
  },
  'onboardSermonsBody': {
    'zh-Hans': '587 篇解经讲道（英／简／繁）。讲道中的经文引用可弹出小窗预览，无需离开。主页有「继续讲道」卡片显示上次进度。',
    'zh-Hant': '587 篇解經講道（英／簡／繁）。講道中的經文引用可彈出小窗預覽，無需離開。主頁有「繼續講道」卡片顯示上次進度。',
    'en':
        '587 expository sermons in EN / 简 / 繁. Verse refs in the body open a popup so you can peek at scripture without leaving. Home shows a "Resume sermon" card with your progress.',
  },
  'onboardDiscoverTitle': {
    'zh-Hans': '探索工具',
    'zh-Hant': '探索工具',
    'en': 'Discover',
  },
  'onboardDiscoverBody': {
    'zh-Hans': '圣经时间轴（97 个事件）、家谱（277 位人物）、圣经证据（225 项考古／抄本／科学发现），都可在主页打开。',
    'zh-Hant': '聖經時間軸（97 個事件）、家譜（277 位人物）、聖經證據（225 項考古／抄本／科學發現），都可在主頁打開。',
    'en':
        'Bible Timeline (97 events), Family Tree (277 people), and Bible Evidence (225 archaeology / manuscript / science finds) — all reachable from Home.',
  },
  'onboardCustomizeTitle': {
    'zh-Hans': '你的数据',
    'zh-Hant': '你的資料',
    'en': 'Your data',
  },
  'onboardCustomizeBody': {
    'zh-Hans': '高亮、笔记、书签都保存在这台设备上——不需要账号，也不上传服务器。要换设备，用「设置 → 导出我的数据」。',
    'zh-Hant': '螢光標記、筆記、書籤都儲存在這台裝置上——不需要帳號，也不上傳伺服器。要換裝置，用「設定 → 匯出我的資料」。',
    'en': 'Highlights, notes and bookmarks are saved on this device — no account, no server. Settings → Export my data moves them to another device.',
  },
  // 2026-08-08 (v1.6.62): the slide above used to pitch Google
  // sign-in for cross-device sync, with China-only variants that
  // told the truth instead. Sync is gone for everyone, so there is
  // one honest version and no variants.

  // Legacy v1 onboarding strings — kept for backward compatibility
  // with any external translation file that still references these
  // keys. The active tour uses the v2 keys above.
  'onboardLibraryTitle': {
    'zh-Hans': '笔记与书签',
    'zh-Hant': '筆記與書籤',
    'en': 'Notes & bookmarks',
  },
  'onboardLibraryBody': {
    'zh-Hans': '长按经文可添加笔记、书签或彩色高亮，可在「我的收藏」和「高亮」中查找。',
    'zh-Hant': '長按經文可添加筆記、書籤或彩色高亮，可在「我的收藏」和「高亮」中查找。',
    'en':
        'Long-press a verse to add a note, bookmark, or color highlight. Find them all in Library and Highlights.',
  },
  // ── Settings section headers (Round 34) ─────────────────────────
  'settingsSectionDisplay': {
    'zh-Hans': '显示',
    'zh-Hant': '顯示',
    'en': 'Display',
  },
  'settingsSectionReading': {
    'zh-Hans': '阅读',
    'zh-Hant': '閱讀',
    'en': 'Reading',
  },
  'settingsSectionApp': {
    'zh-Hans': '应用',
    'zh-Hant': '應用',
    'en': 'App',
  },
  'settingsSectionAccount': {
    'zh-Hans': '账号',
    'zh-Hant': '帳號',
    'en': 'Account',
  },
  'resetToDefault': {
    'zh-Hans': '恢复默认',
    'zh-Hant': '恢復預設',
    'en': 'Reset to default',
  },
  // ── App-level reset (Round 55) ──────────────────────────────────
  // Used by Settings → About → "Reset settings". Wipes visual /
  // preference state back to defaults but preserves user content
  // (bookmarks, notes, highlights, profile, language).
  'resetSettings': {
    'zh-Hans': '恢复设置',
    'zh-Hant': '恢復設定',
    'en': 'Reset settings',
  },
  'resetSettingsConfirm': {
    'zh-Hans': '将恢复字体、主题、颜色、主页布局等所有偏好设置。您的书签、笔记、高亮、账号和语言不会改变。是否继续？',
    'zh-Hant': '將恢復字體、主題、顏色、主頁佈局等所有偏好設定。您的書籤、筆記、高亮、帳號和語言不會改變。是否繼續？',
    'en':
        'This restores fonts, theme, color, dashboard layout, and other preferences. Your bookmarks, notes, highlights, profile, and language stay the same. Continue?',
  },
  'resetSettingsNote': {
    'zh-Hans': '恢复字体、主题、颜色、主页布局等偏好设置。您的书签、笔记、高亮、账号和语言不会改变。',
    'zh-Hant': '恢復字體、主題、顏色、主頁佈局等偏好設定。您的書籤、筆記、高亮、帳號和語言不會改變。',
    'en':
        'Restores fonts, theme, color, dashboard layout, and other preferences. Your bookmarks, notes, highlights, profile, and language are kept.',
  },
  'resetSettingsDone': {
    'zh-Hans': '设置已恢复默认。',
    'zh-Hant': '設定已恢復預設。',
    'en': 'Settings restored to defaults.',
  },
  'showTourAgain': {
    'zh-Hans': '重新查看导览',
    'zh-Hant': '重新查看導覽',
    'en': 'Show tour again',
  },
  // ── Offline Pack (Round 56) ─────────────────────────────────────
  // Bulk pre-fetch UI in Settings → About. Lets the user download
  // every Bible / sermon / tool asset into the browser's HTTP +
  // service-worker cache so the app launches instantly + works
  // without network. Three categories (bibles / sermons / tools)
  // each user-toggleable.
  'offlinePackTitle': {
    'zh-Hans': '离线包',
    'zh-Hant': '離線包',
    'en': 'Offline pack',
  },
  'offlinePackHint': {
    'zh-Hans': '预先下载圣经、讲道与工具数据，应用立即打开，断网也能用。',
    'zh-Hant': '預先下載聖經、講道與工具資料，應用立即打開，斷網也能用。',
    'en':
        'Pre-download Bibles, sermons, and tools so the app launches instantly and works without network.',
  },
  'offlinePackBibles': {
    'zh-Hans': '圣经译本（共 13 部）',
    'zh-Hant': '聖經譯本（共 13 部）',
    'en': 'Bibles (13 translations)',
  },
  // `{name}` is substituted by `withPreacher` from sermon_credit.dart.
  // The count was 587, which is neither the number of sermons nor the
  // number of files: `assets/sermons/index.json` holds 289 records whose
  // `parts` fields sum to 589, and each record ships in up to 3
  // languages for 867 body files. 587 looks like a mis-transcribed part
  // count. 289 is what a reader is choosing to download.
  'offlinePackSermons': {
    'zh-Hans': '{name}讲道（289 篇 ×3 语）',
    'zh-Hant': '{name}講道（289 篇 ×3 語）',
    'en': 'Sermons by {name} (289 × 3 languages)',
  },
  'offlinePackTools': {
    'zh-Hans': '研经工具（家谱 / 时间轴 / 证据 / 互参 / 读经计划等）',
    'zh-Hant': '研經工具（家譜 / 時間軸 / 證據 / 互參 / 讀經計劃等）',
    'en': 'Tools & references (tree / timeline / evidence / refs / plans)',
  },
  // Added 2026-05 — exegesis word study + Bible-history maps were
  // previously not pre-cached, so they silently failed offline.
  'offlinePackOriginals': {
    'zh-Hans': '原文研究（Strong\'s 编号 + 希伯来 / 希腊原文逐字对照）',
    'zh-Hant': '原文研究（Strong\'s 編號 + 希伯來 / 希臘原文逐字對照）',
    'en': "Originals (Strong's lexicon + Hebrew/Greek interlinear)",
  },
  'offlinePackMaps': {
    'zh-Hans': '圣经历史地图（55 张图）',
    'zh-Hant': '聖經歷史地圖（55 張圖）',
    'en': 'Bible-history maps (55 images)',
  },
  // ── AI BYOK + Drive sync (2026-05-06) ────────────────────────
  'settingsSectionAi': {
    'zh-Hans': 'SeekSparks AI 释义',
    'zh-Hant': 'SeekSparks AI 釋義',
    'en': 'SeekSparks AI',
  },
  'aboutSectionAi': {
    'zh-Hans': 'SeekSparks AI（高级 · 可选）',
    'zh-Hant': 'SeekSparks AI（進階 · 可選）',
    'en': 'SeekSparks AI (advanced · optional)',
  },
  // ── Exegesis sheet — proper-noun complementary glosses ────────
  // 2026-05-07: for proper nouns (people, places, deities) the
  // English Strong's lexicon gives etymology while the Chinese CBOL
  // gives biblical identification. Showing only the locale-preferred
  // one made users feel the data was inconsistent. Now both are
  // rendered side-by-side with these labels so the user understands
  // they're complementary, not contradictory.
  'exegesisProperNounBadge': {
    'zh-Hans': '专有名词',
    'zh-Hant': '專有名詞',
    'en': 'Proper noun',
  },
  'exegesisProperNounNote': {
    'zh-Hans': '英文给词源，中文给身份——都是对的，互相补充。',
    'zh-Hant': '英文給詞源，中文給身份——都是對的，互相補充。',
    'en':
        'English gives etymology; Chinese gives biblical identification — '
            'both correct, complementary perspectives.',
  },
  'exegesisProperNounRoleLabel': {
    'zh-Hans': '此处指',
    'zh-Hant': '此處指',
    'en': 'Identification',
  },
  'exegesisProperNounEtymLabel': {
    'zh-Hans': '词源',
    'zh-Hant': '詞源',
    'en': 'Etymology',
  },
  'exegesisProperNounComplDefEn': {
    'zh-Hans': '英文 Strong\'s 完整释义（互补视角）',
    'zh-Hant': '英文 Strong\'s 完整釋義（互補視角）',
    'en': "English Strong's full definition (complementary)",
  },
  'exegesisProperNounComplDefZh': {
    'zh-Hans': '中文 CBOL 释义（互补视角）',
    'zh-Hant': '中文 CBOL 釋義（互補視角）',
    'en': 'Chinese CBOL definition (complementary)',
  },
  // v1.3.x: collapsible header for the English-only material
  // (Strong's etymology / derivation, KJV counts) shown in the
  // Chinese exegesis panel. Collapsed by default so the Chinese
  // reader sees Chinese first; tap to reveal the English reference.
  'englishReference': {
    'zh-Hans': '英文参考',
    'zh-Hant': '英文參考',
    'en': 'English reference',
  },
  // ── AI Bible search (2026-05-07) ─────────────────────────────
  // Triggered from the search page's no-results state. Lets the
  // user ask Gemini for Bible references that match a fuzzy /
  // thematic query when exact-text search returns nothing.
  // 2026-05-07: rebrand. The user prefers the SeekSparks brand to be
  // surfaced rather than a generic "AI" label, with a "for reference
  // only" caveat to set expectations about LLM-generated content.
  // Older "ask AI" wording across the search page maps to the new
  // "search with SeekSparks AI" copy.
  'askAiForVerses': {
    'zh-Hans': '用 SeekSparks AI 智能搜索（仅供参考）',
    'zh-Hant': '用 SeekSparks AI 智慧搜尋（僅供參考）',
    'en': 'Search with SeekSparks AI (reference only)',
  },
  'aiSearching': {
    'zh-Hans': 'SeekSparks 正在搜索…',
    'zh-Hant': 'SeekSparks 正在搜尋…',
    'en': 'SeekSparks AI searching…',
  },
  'aiBibleSearchHeader': {
    'zh-Hans': 'SeekSparks 为「{query}」找到了 {count} 处经文（仅供参考）',
    'zh-Hant': 'SeekSparks 為「{query}」找到了 {count} 處經文（僅供參考）',
    'en': 'SeekSparks AI found {count} passages for "{query}" (reference only)',
  },
  'aiBibleSearchNoMatches': {
    'zh-Hans': 'AI 没有找到相关经文，换个说法再试一下吧。',
    'zh-Hant': 'AI 沒有找到相關經文，換個說法再試一下吧。',
    'en':
        'AI didn\'t find any matching passages. Try rephrasing.',
  },
  // 2026-05-08 (v1.1.5): tag + snackbar for AI ref cards that don't
  // resolve to a verse in the user's currently-loaded Bible version.
  'aiRefOnlyTag': {
    'zh-Hans': '仅参考',
    'zh-Hant': '僅參考',
    'en': 'reference only',
  },
  'aiRefNotInVersion': {
    'zh-Hans': '这段经文不在您当前的圣经版本中。在「设置」里切换版本后即可阅读。',
    'zh-Hant': '這段經文不在您當前的聖經版本中。在「設定」裡切換版本後即可閱讀。',
    'en':
        'This passage isn\'t in your current Bible version. Switch versions in Settings to read it.',
  },
  // 2026-05-08 (v1.1.10): deep-link CTA for the BYOK Gemini key.
  // Shown under the AI error notice when the failure is a quota /
  // not-configured one AND the user hasn't already set up their own
  // key. Tapping navigates to Settings → SeekSparks AI section and
  // scrolls the GeminiKeyCard into view.
  'aiOpenByokSettings': {
    'zh-Hans': '使用您自己的 Gemini Key',
    'zh-Hant': '使用您自己的 Gemini Key',
    'en': 'Set up your own Gemini API key',
  },
  // 2026-05-08 (v1.1.11): client-side fallback strings for the
  // AI services (ai_bible_search_service.dart + ai_search_service.dart).
  // Used only when the Netlify function returns a 429/503 without
  // a parseable `error` body — in normal operation the backend
  // sends a user-locale message that's surfaced directly.
  'aiQuotaExhaustedFallback': {
    'zh-Hans': 'SeekSparks AI 今天的共享配额已用完。明天再试，或在「设置 → '
        'SeekSparks AI」粘贴您自己的 Gemini API Key 用您的配额。',
    'zh-Hant': 'SeekSparks AI 今天的共享配額已用完。明天再試，或在「設定 → '
        'SeekSparks AI」貼上您自己的 Gemini API Key 用您的配額。',
    'en':
        'SeekSparks AI quota for the developer\'s shared key is used up for today. Try again tomorrow, or paste your own Gemini API key in Settings → AI to use your own quota.',
  },
  'aiNotConfiguredFallback': {
    'zh-Hans': 'SeekSparks AI 还没有配置。开发者需要在 Netlify 环境变量里设置 '
        'GEMINI_API_KEY。',
    'zh-Hant': 'SeekSparks AI 還沒有配置。開發者需要在 Netlify 環境變數裡設置 '
        'GEMINI_API_KEY。',
    'en':
        'SeekSparks AI is not configured. The developer needs to set GEMINI_API_KEY in Netlify env.',
  },
  'aiBibleSearchSomeMissing': {
    'zh-Hans': 'SeekSparks AI 还找到 {n} 处经文，但您当前圣经版本中没有匹配（仅供参考）。',
    'zh-Hant': 'SeekSparks AI 還找到 {n} 處經文，但您當前聖經版本中沒有匹配（僅供參考）。',
    'en':
        'SeekSparks AI also suggested {n} passages not in your current '
            'Bible version (reference only).',
  },
  // 2026-05-07 (post-fix v3): AI-result note when the active search
  // filter (e.g. "Search current book") excluded some of the
  // passages SeekSparks returned. Distinct from
  // aiBibleSearchSomeMissing which is for refs not present in the
  // user's loaded Bible version at all.
  'aiBibleSearchOutOfScope': {
    'zh-Hans': 'SeekSparks AI 还推荐了 {n} 处经文，但当前筛选范围之外（仅供参考）。',
    'zh-Hant': 'SeekSparks AI 還推薦了 {n} 處經文，但當前篩選範圍之外（僅供參考）。',
    'en':
        'SeekSparks AI also suggested {n} passages outside your current '
            'filter scope.',
  },
  // 2026-05-07: italic caveat shown directly below the AI search
  // button. v10 wording aligned with the welcome disclaimer:
  // AI is auxiliary; verify against Scripture; the Spirit guides.
  'aiReferenceOnly': {
    'zh-Hans': 'AI 只是辅助，请以经文为准，让圣灵亲自带领你。',
    'zh-Hant': 'AI 只是輔助，請以經文為準，讓聖靈親自帶領你。',
    'en':
        'AI is only an aid — verify against Scripture and let the Spirit guide you.',
  },
  'aiByokTitle': {
    'zh-Hans': '使用我自己的 Gemini API 密钥',
    'zh-Hant': '使用我自己的 Gemini API 金鑰',
    'en': 'Use my own Gemini API key',
  },
  'aiByokBody': {
    // 2026-05-10 (v1.2.17): wording softened from "never synced
    // across devices" to "lives on this device" — the key now
    // syncs via the user's own Firebase project to their other
    // signed-in devices when they're signed in. The new
    // `aiByokSyncedNote` ui-string carries the explicit cloud-sync
    // disclosure and only renders below the input when the
    // condition (signed in + key present + intl build) matches.
    'zh-Hans': '从 Google AI Studio 获取免费密钥并粘贴在这里——之后 AI 功能（原文释义、AI 搜索）'
        '将走您自己的额度（每分钟 15 次，每日 1500 次），而不是与开发者池共享。'
        '密钥保存在本设备本地。',
    'zh-Hant': '從 Google AI Studio 取得免費金鑰並貼在這裡——之後 AI 功能（原文釋義、AI 搜尋）'
        '將走您自己的配額（每分鐘 15 次，每日 1500 次），而不是與開發者池共享。'
        '金鑰保存在本裝置本地。',
    'en':
        'Paste your free Gemini API key from AI Studio so AI features '
            '(word explanations, AI search) use your own quota (15 RPM / '
            '1500 RPD) instead of the shared developer pool. The key '
            'lives on this device.',
  },
  'aiByokGetKey': {
    'zh-Hans': '获取免费密钥',
    'zh-Hant': '取得免費金鑰',
    'en': 'Get free key',
  },
  // 2026-05-10 (v1.2.26): AI model picker — three tiers, mapped to
  // Gemini models on the server.
  //   '快' / 'Fast'      → flash-lite (default; fastest, simplest)
  //   '标准' / 'Standard'→ flash      (balanced)
  //   '深入' / 'Deep'    → pro        (deepest analysis, slower,
  //                                    smaller free-tier quota —
  //                                    BYOK key recommended)
  'aiModelTitle': {
    'zh-Hans': 'AI 响应深度',
    'zh-Hant': 'AI 回應深度',
    'en': 'AI response depth',
  },
  'aiModelBody': {
    'zh-Hans': '选择 AI 回答的速度与详尽度——不同档位对应不同的 Gemini 模型。',
    'zh-Hant': '選擇 AI 回答的速度與詳盡度——不同檔位對應不同的 Gemini 模型。',
    'en':
        'Choose the speed-vs-depth trade-off — each tier maps to a different Gemini model.',
  },
  'aiModelFast': {
    'zh-Hans': '快',
    'zh-Hant': '快',
    'en': 'Fast',
  },
  'aiModelStandard': {
    'zh-Hans': '标准',
    'zh-Hant': '標準',
    'en': 'Standard',
  },
  'aiModelDeep': {
    'zh-Hans': '深入',
    'zh-Hant': '深入',
    'en': 'Deep',
  },
  // 2026-05-10 (v1.2.27): per-tier detail panel — surfaces under
  // the SegmentedButton, updates as the user picks. Tells them
  // (a) which actual Gemini model the tier maps to, (b) which is
  // the default, (c) relative speed vs depth, and (d) free-tier
  // quota reality so they know when to BYOK.
  'aiModelFastDetail': {
    'zh-Hans': '快 (默认) · Gemini 2.5 Flash-Lite。最快、最简明的回答，约 1-3 秒。免费配额最大——开发者共享池基本不会耗尽。适合日常研经、快速查询。',
    'zh-Hant': '快 (預設) · Gemini 2.5 Flash-Lite。最快、最簡明的回答，約 1-3 秒。免費配額最大——開發者共享池基本不會耗盡。適合日常研經、快速查詢。',
    'en':
        'Fast (default) · Gemini 2.5 Flash-Lite. Quickest answers (~1-3 s), brief and direct. Largest free-tier quota — the shared developer pool almost never runs out. Best for everyday study and quick lookups.',
  },
  'aiModelStandardDetail': {
    'zh-Hans': '标准 · Gemini 2.5 Flash。速度和深度的平衡，约 3-6 秒。免费配额中等，平时充足，高峰时段可能耗尽。适合需要稍详细解释的场景。',
    'zh-Hant': '標準 · Gemini 2.5 Flash。速度和深度的平衡,約 3-6 秒。免費配額中等,平時充足,高峰時段可能耗盡。適合需要稍詳細解釋的場景。',
    'en':
        'Standard · Gemini 2.5 Flash. Balanced speed and depth (~3-6 s). Mid-range free-tier quota — usually fine, can run out at peak hours. Best when you want a bit more detail than Fast gives.',
  },
  'aiModelDeepDetail': {
    'zh-Hans': '深入 · Gemini 3 Flash Preview。带"思考"模式的高速推理模型——接近 Pro 级别的释经深度，但速度快得多（约 4-8 秒）。**免费配额可用**：~250 RPD，独立于 Standard / Fast 配额池。Google 在 2026 年 4 月把 gemini-2.5-pro 收费了——所以我们改用这款，免费即可使用，不需要 BYOK。BYOK 仍然推荐用于高频使用（您自己的密钥有独立配额，更稳定）。',
    'zh-Hant': '深入 · Gemini 3 Flash Preview。帶「思考」模式的高速推理模型——接近 Pro 級別的釋經深度，但速度快得多（約 4-8 秒）。**免費配額可用**：~250 RPD，獨立於 Standard / Fast 配額池。Google 在 2026 年 4 月把 gemini-2.5-pro 收費了——所以我們改用這款，免費即可使用，不需要 BYOK。BYOK 仍然推薦用於高頻使用（您自己的密鑰有獨立配額，更穩定）。',
    'en':
        'Deep · Gemini 3 Flash Preview. High-speed thinking model with near-Pro reasoning quality — substantially faster than Pro (~4-8 s). **Free-tier compatible** at ~250 RPD, with quota separate from the Standard / Fast pools. Google moved gemini-2.5-pro behind a paywall in April 2026, so SeekSparks switched Deep to this model — free, no BYOK needed. BYOK still recommended for heavy use (your own key has its own quota pool).',
  },
  // 2026-05-11 (v1.2.42): three short-lived strings were removed
  // here as dead code:
  //   • `aiDeepFellBackToStandard` (v1.2.37) — surfaced when the
  //     backend silently downgraded Pro → Flash for no-BYOK users.
  //     Obsolete after v1.2.40 switched Deep to
  //     `gemini-3-flash-preview` (works on free tier; no silent
  //     downgrade).
  //   • `aiModelDeepDisabledTooltip` (v1.2.39) — tooltip on the
  //     locked Deep segment when BYOK was missing. v1.2.41 reverted
  //     the gating because Deep works without BYOK now.
  //   • `aiModelDeepLockedNote` (v1.2.39) — italic note under the
  //     locked picker. Same reason.
  // 2026-05-09 (v1.2.7): "Test" button + result row in the BYOK
  // card. Lets the user verify their pasted key actually
  // authenticates against Gemini before saving — previously they
  // had to commit, navigate to the search page, run a query, and
  // hope the result wasn't a fallback to the dev's shared pool.
  'aiByokTest': {
    'zh-Hans': '测试',
    'zh-Hant': '測試',
    'en': 'Test',
  },
  'aiByokTesting': {
    'zh-Hans': '测试中…',
    'zh-Hant': '測試中…',
    'en': 'Testing…',
  },
  'aiByokTestOk': {
    'zh-Hans': '密钥可用！AI 功能将使用您的额度。',
    'zh-Hant': '金鑰可用！AI 功能將使用您的配額。',
    'en': 'Key works! AI features will use your quota.',
  },
  'aiByokTestFailed': {
    'zh-Hans': '测试失败。',
    'zh-Hant': '測試失敗。',
    'en': 'Test failed.',
  },
  'aiByokTestInvalidShape': {
    'zh-Hans': '看起来不像 Gemini API 密钥。它应该以 AIza… 开头'
        '（可以从 aistudio.google.com/apikey 复制一个）。',
    'zh-Hant': '看起來不像 Gemini API 金鑰。它應該以 AIza… 開頭'
        '（可以從 aistudio.google.com/apikey 複製一個）。',
    'en':
        "Doesn't look like a Gemini API key. It should start with "
            'AIza… (you can copy one from aistudio.google.com/apikey).',
  },
  'aiByokTestUnexpected': {
    'zh-Hans': 'AI 服务返回了意外的响应。',
    'zh-Hant': 'AI 服務返回了意外的回應。',
    'en': 'Unexpected response from the AI service.',
  },
  'aiByokTestTimeout': {
    'zh-Hans': 'AI 服务响应超时，请稍后再试。',
    'zh-Hant': 'AI 服務回應逾時，請稍後再試。',
    'en': 'The AI service did not respond in time. Try again.',
  },
  'show': {'zh-Hans': '显示', 'zh-Hant': '顯示', 'en': 'Show'},
  'hide': {'zh-Hans': '隐藏', 'zh-Hant': '隱藏', 'en': 'Hide'},
  // 'save' and 'clear' already exist elsewhere in this map; reuse them.
  'saved': {'zh-Hans': '已保存', 'zh-Hant': '已儲存', 'en': 'Saved'},
  // 2026-05-07: improved progress + post-download UX:
  // - "{total} files" makes the unit explicit (was just a bare number)
  // - "{eta}" inserts a localized "~30 sec left" suffix once we have
  //   enough samples
  // - offlinePackRedownload is the new outlined button label that
  //   replaces the prominent "Download" button after a successful
  //   download — no more confusing "why is the button still here?"
  'offlinePackEtaSuffix': {
    'zh-Hans': ' · 剩余约 {eta}',
    'zh-Hant': ' · 剩餘約 {eta}',
    'en': ' · ~{eta} left',
  },
  'offlinePackRedownload': {
    'zh-Hans': '重新下载以刷新',
    'zh-Hant': '重新下載以刷新',
    'en': 'Re-download to refresh',
  },
  'offlinePackNetworkNote': {
    'zh-Hans': '以下功能仍需要网络：AI 释义 / AI 搜索、云端同步登录、新闻实时更新，'
        '以及首次加载非 Roboto 字体（Google Fonts 在线下载，下载后会被浏览器缓存）。',
    'zh-Hant': '以下功能仍需要網路：AI 釋義 / AI 搜尋、雲端同步登入、新聞即時更新，'
        '以及首次載入非 Roboto 字體（Google Fonts 線上下載，下載後會被瀏覽器快取）。',
    'en':
        'Network is still required for: AI explanations / search, '
            'cloud-sync sign-in, live news refresh, and the first load '
            'of any non-Roboto font (Google Fonts download once, then '
            'cache in the browser).',
  },
  'offlinePackDownload': {
    'zh-Hans': '下载',
    'zh-Hant': '下載',
    'en': 'Download',
  },
  'offlinePackPickCategory': {
    'zh-Hans': '请勾选一个类别',
    'zh-Hant': '請勾選一個類別',
    'en': 'Pick a category',
  },
  'offlinePackDownloading': {
    'zh-Hans': '下载中… {done} / {total} 个文件（{pct}%）{eta}',
    'zh-Hant': '下載中… {done} / {total} 個檔案（{pct}%）{eta}',
    'en': 'Downloading… {done}/{total} files ({pct}%){eta}',
  },
  'offlinePackReady': {
    'zh-Hans': '已可离线使用 · {categories}',
    'zh-Hant': '已可離線使用 · {categories}',
    'en': 'Ready offline · {categories}',
  },
  'offlinePackSomeFailed': {
    'zh-Hans': '已跳过 {n} 个文件（下次下载时重试）。',
    'zh-Hant': '已跳過 {n} 個檔案（下次下載時重試）。',
    'en': '{n} files skipped (will retry on next download).',
  },
  'offlinePackClear': {
    'zh-Hans': '清除离线包记录',
    'zh-Hant': '清除離線包記錄',
    'en': 'Clear offline pack',
  },
  'offlinePackDoneToast': {
    'zh-Hans': '✓ 离线包就绪 —— 现在断网也能用了。',
    'zh-Hant': '✓ 離線包就緒 —— 現在斷網也能用了。',
    'en': '✓ Offline pack ready — the app now works without network.',
  },
  // ── Verse picker (Round 56) ─────────────────────────────────────
  // Optional second-step picker shown after the user selects a
  // chapter. Toggle in Settings → Reading "Pick verse after chapter".
  'versePickerTitle': {
    'zh-Hans': '选择经节',
    'zh-Hant': '選擇經節',
    'en': 'Pick a verse',
  },
  'versePickerTop': {
    'zh-Hans': '本章开头',
    'zh-Hant': '本章開頭',
    'en': 'Top',
  },
  // ── Bible Trivia (冷知识) — Round 56 ────────────────────────────
  'bibleTrivia': {
    'zh-Hans': '冷知识',
    'zh-Hant': '冷知識',
    'en': 'Bible Trivia',
  },
  'bibleTriviaIntro': {
    'zh-Hans': '原文中隐藏的离合体、神名暗藏、数字结构和双关——多数读者错过的彩蛋。点击任意条目可在阅读器中查看相关经文。',
    'zh-Hant': '原文中隱藏的離合體、神名暗藏、數字結構和雙關——多數讀者錯過的彩蛋。點擊任意條目可在閱讀器中查看相關經文。',
    'en':
        'Hidden patterns, acrostics, divine-name codes, and numerical structures most readers miss. Tap any entry to read the related passage in the reader.',
  },
  'bibleTriviaOpenRef': {
    'zh-Hans': '在圣经中查看',
    'zh-Hant': '在聖經中查看',
    'en': 'Read in Bible',
  },
  'bibleTriviaNoneForChapter': {
    'zh-Hans': '本章暂无冷知识。',
    'zh-Hant': '本章暫無冷知識。',
    'en': 'No trivia entries for this chapter yet.',
  },
  'bibleTriviaViewAll': {
    'zh-Hans': '查看全部冷知识',
    'zh-Hant': '查看全部冷知識',
    'en': 'View all trivia',
  },
  'bibleTriviaSearchHint': {
    'zh-Hans': '搜索冷知识…',
    'zh-Hant': '搜尋冷知識…',
    'en': 'Search trivia…',
  },
  // ── Trivia diagrams (Round 56 day-3) ──────────────────────────
  // Captions and labels used by the inline schematic diagrams that
  // visualise structural patterns (Hebrew acrostics, broken-acrostic
  // chapter counts, threefold genealogies, numbered word lists).
  'triviaAlphabetCaption': {
    'zh-Hans': '希伯来字母表 22 个字母',
    'zh-Hant': '希伯來字母表 22 個字母',
    'en': 'Hebrew alphabet · 22 letters',
  },
  'triviaChapterCountsCaption': {
    'zh-Hans': '每章节数（红色 = 离合体被打破）',
    'zh-Hant': '每章節數（紅色 = 離合體被打破）',
    'en': 'Verses per chapter (red = acrostic broken)',
  },
  // Genesis 1:1 — seven Hebrew words.
  'triviaGen11Word1': {
    'zh-Hans': '起初',
    'zh-Hant': '起初',
    'en': 'In the beginning',
  },
  'triviaGen11Word2': {
    'zh-Hans': '创造',
    'zh-Hant': '創造',
    'en': 'created',
  },
  'triviaGen11Word3': {
    'zh-Hans': '神（Elohim）',
    'zh-Hant': '神（Elohim）',
    'en': 'God (Elohim)',
  },
  'triviaGen11Word4': {
    'zh-Hans': '（直接宾语标记）',
    'zh-Hant': '（直接賓語標記）',
    'en': '(direct-object marker)',
  },
  'triviaGen11Word5': {
    'zh-Hans': '诸天',
    'zh-Hant': '諸天',
    'en': 'the heavens',
  },
  'triviaGen11Word6': {
    'zh-Hans': '与（直接宾语标记）',
    'zh-Hant': '與（直接賓語標記）',
    'en': 'and (direct-object marker)',
  },
  'triviaGen11Word7': {
    'zh-Hans': '大地',
    'zh-Hant': '大地',
    'en': 'the earth',
  },
  // Matthew 1:17 — three groups of 14 generations.
  'triviaMatt117GroupA': {
    'zh-Hans': '亚伯拉罕 → 大卫',
    'zh-Hant': '亞伯拉罕 → 大衛',
    'en': 'Abraham → David',
  },
  'triviaMatt117GroupB': {
    'zh-Hans': '大卫 → 被掳',
    'zh-Hant': '大衛 → 被擄',
    'en': 'David → Exile',
  },
  'triviaMatt117GroupC': {
    'zh-Hans': '被掳 → 基督',
    'zh-Hant': '被擄 → 基督',
    'en': 'Exile → Christ',
  },
  'triviaMatt117Generations': {
    'zh-Hans': '14 代',
    'zh-Hant': '14 代',
    'en': '14 generations',
  },
  // Round 56: hint shown under expanded font dropdown.
  'loadingVersion': {
    'zh-Hans': '正在切换译本…',
    'zh-Hant': '正在切換譯本…',
    'en': 'Loading version…',
  },
  // ── Originals stats tab (Round 56) ─────────────────────────────
  'statsOriginals': {
    'zh-Hans': '原文',
    'zh-Hant': '原文',
    'en': 'Originals',
  },
  'statsOriginalsHint': {
    'zh-Hans': '希伯来文（旧约）和希腊文（新约）原文中每个 Strong\'s 编号的出现频率。'
        '点击行可查看各书卷分布。',
    'zh-Hant': '希伯來文（舊約）和希臘文（新約）原文中每個 Strong\'s 編號的出現頻率。'
        '點擊行可查看各書卷分佈。',
    'en':
        'Frequency of every Strong\'s number in the original Hebrew (OT) and Greek (NT) text. Tap a row to see book breakdown.',
  },
  'statsOriginalsAll': {
    'zh-Hans': '全部',
    'zh-Hant': '全部',
    'en': 'All',
  },
  'statsOriginalsHideStopwordsTitle': {
    'zh-Hans': '隐藏常用虚词',
    'zh-Hant': '隱藏常用虛詞',
    'en': 'Hide common particles',
  },
  'statsOriginalsScopeAll': {
    'zh-Hans': '全圣经',
    'zh-Hant': '全聖經',
    'en': 'Whole Bible',
  },
  'statsOriginalsScopeBook': {
    'zh-Hans': '当前：{book}',
    'zh-Hant': '當前：{book}',
    'en': 'Showing: {book}',
  },
  'statsOriginalsBookTotalWords': {
    'zh-Hans': '本卷词数',
    'zh-Hant': '本卷詞數',
    'en': 'Total words in book',
  },
  'statsOriginalsBookUniqueLemmas': {
    'zh-Hans': '本卷词条数',
    'zh-Hant': '本卷詞條數',
    'en': 'Unique lemmas in book',
  },
  'statsOriginalsHideStopwordsDesc': {
    'zh-Hans':
        '过滤"the/and/in/of/who/that"等高频虚词与冠词，让真正有意义的圣经词汇浮上来。',
    'zh-Hant':
        '過濾「the/and/in/of/who/that」等高頻虛詞與冠詞，讓真正有意義的聖經詞彙浮上來。',
    'en':
        'Filter out high-frequency function words like the, and, in, of, who, that — surfacing the meaningful content vocabulary instead.',
  },
  'statsOriginalsHebrew': {
    'zh-Hans': '希伯来文',
    'zh-Hant': '希伯來文',
    'en': 'Hebrew',
  },
  'statsOriginalsGreek': {
    'zh-Hans': '希腊文',
    'zh-Hant': '希臘文',
    'en': 'Greek',
  },
  'statsOriginalsSearchHint': {
    'zh-Hans': '按 Strong\'s 编号、原文或释义搜索…',
    'zh-Hant': '按 Strong\'s 編號、原文或釋義搜索…',
    'en': 'Search by Strong\'s, lemma, or gloss…',
  },
  'statsOriginalsByBook': {
    'zh-Hans': '各书卷分布',
    'zh-Hant': '各書卷分佈',
    'en': 'By book',
  },
  'statsOriginalsTotal': {
    'zh-Hans': '共 {total} 个 Strong\'s 编号',
    'zh-Hant': '共 {total} 個 Strong\'s 編號',
    'en': '{total} unique Strong\'s numbers',
  },
  'statsOriginalsMatchCount': {
    'zh-Hans': '找到 {shown} 条',
    'zh-Hant': '找到 {shown} 條',
    'en': '{shown} matches',
  },
  'statsOriginalsShowAll': {
    'zh-Hans': '显示全部 {total} 条',
    'zh-Hant': '顯示全部 {total} 條',
    'en': 'Show all {total} entries',
  },
  'statsOriginalsEmpty': {
    'zh-Hans': '原文数据未加载。',
    'zh-Hant': '原文資料未載入。',
    'en': 'Original-language data not loaded.',
  },
  'statsOriginalsHebrewTotal': {
    'zh-Hans': '希伯来文总字数',
    'zh-Hant': '希伯來文總字數',
    'en': 'Hebrew words',
  },
  'statsOriginalsGreekTotal': {
    'zh-Hans': '希腊文总字数',
    'zh-Hant': '希臘文總字數',
    'en': 'Greek words',
  },
  'statsOriginalsHebrewUnique': {
    'zh-Hans': '希伯来文词条',
    'zh-Hant': '希伯來文詞條',
    'en': 'Hebrew lemmas',
  },
  'statsOriginalsGreekUnique': {
    'zh-Hans': '希腊文词条',
    'zh-Hant': '希臘文詞條',
    'en': 'Greek lemmas',
  },
  'statsOriginalsHapax': {
    'zh-Hans': '仅出现一次的字',
    'zh-Hant': '僅出現一次的字',
    'en': 'Hapax legomena',
  },
  'statsOriginalsBooksCount': {
    'zh-Hans': '涉及书卷数',
    'zh-Hant': '涉及書卷數',
    'en': 'Books covered',
  },
  'statsOriginalsTopHebrew': {
    'zh-Hans': '希伯来文使用最频繁（旧约）',
    'zh-Hant': '希伯來文使用最頻繁（舊約）',
    'en': 'Top Hebrew (OT)',
  },
  'statsOriginalsTopGreek': {
    'zh-Hans': '希腊文使用最频繁（新约）',
    'zh-Hant': '希臘文使用最頻繁（新約）',
    'en': 'Top Greek (NT)',
  },
  'statsOriginalsWordsShort': {
    'zh-Hans': '字',
    'zh-Hant': '字',
    'en': 'words',
  },
  'statsOriginalsLemmasShort': {
    'zh-Hans': '词条',
    'zh-Hant': '詞條',
    'en': 'lemmas',
  },
  // `statsBooksOT` / `statsBooksNT` (旧约 / 新约) removed 2026-08-09:
  // #280 ruled the app names the two corpora 希伯来 / 希腊, and the stats
  // page now shares `oldTestamentShort` / `newTestamentShort` with
  // every other testament toggle.
  // ── Style presets (Round 56) ──────────────────────────────────
  'stylePresetTitle': {
    'zh-Hans': '风格预设',
    'zh-Hant': '風格預設',
    'en': 'Style preset',
  },
  'stylePresetCustom': {
    'zh-Hans': '自定义 —— 手动调整的设置',
    'zh-Hant': '自訂 —— 手動調整的設定',
    'en': 'Custom — manually tuned settings',
  },
  'stylePresetActive': {
    'zh-Hans': '当前：{name}',
    'zh-Hant': '當前：{name}',
    'en': 'Active: {name}',
  },
  'stylePreset_classic_label': {
    'zh-Hans': '经典',
    'zh-Hant': '經典',
    'en': 'Classic',
  },
  'stylePreset_classic_description': {
    'zh-Hans': 'Roboto 无衬线字体，段落模式开启，标准间距 —— 默认外观。',
    'zh-Hant': 'Roboto 無襯線字體，段落模式開啟，標準間距 —— 預設外觀。',
    'en':
        'Roboto sans-serif, paragraph mode on, normal density — the default look.',
  },
  'stylePreset_modern_label': {
    'zh-Hans': '现代',
    'zh-Hant': '現代',
    'en': 'Modern',
  },
  'stylePreset_modern_description': {
    'zh-Hans': '系统无衬线字体，紧凑一些，段落模式开启 —— 类似 Kindle 阅读器风格。',
    'zh-Hant': '系統無襯線字體，緊湊一些，段落模式開啟 —— 類似 Kindle 閱讀器風格。',
    'en':
        'System sans-serif, slightly compact, paragraph mode — like a modern reading app.',
  },
  'stylePreset_reverent_label': {
    'zh-Hans': '虔敬',
    'zh-Hant': '虔敬',
    'en': 'Reverent',
  },
  'stylePreset_reverent_description': {
    'zh-Hans': 'Garamond 衬线字体，宽行距，段落模式 —— 接近印刷版圣经的感觉。',
    'zh-Hant': 'Garamond 襯線字體，寬行距，段落模式 —— 接近印刷版聖經的感覺。',
    'en':
        'Garamond serif, generous line spacing, paragraph mode — feels like a printed Bible.',
  },
  'stylePreset_compact_label': {
    'zh-Hans': '紧凑',
    'zh-Hant': '緊湊',
    'en': 'Compact',
  },
  'stylePreset_compact_description': {
    'zh-Hans': '小字号、低菜单缩放、逐节模式 —— 信息密度最高，适合查考使用。',
    'zh-Hant': '小字號、低選單縮放、逐節模式 —— 資訊密度最高，適合查考使用。',
    'en':
        'Smaller fonts, lower menu scale, verse-by-verse mode — maximum density for reference use.',
  },
  'stylePreset_reader_label': {
    'zh-Hans': '阅读',
    'zh-Hant': '閱讀',
    'en': 'Reader',
  },
  'stylePreset_reader_description': {
    'zh-Hans': 'Georgia 衬线字体，大字号，宽行距，段落模式 —— 长时间阅读最舒适。',
    'zh-Hant': 'Georgia 襯線字體，大字號，寬行距，段落模式 —— 長時間閱讀最舒適。',
    'en':
        'Georgia serif, larger font, wide line spacing, paragraph mode — comfortable for long reading.',
  },
  // 2026-05-08 (v1.1.2): top-of-list preset that pulls the user's
  // system defaults — OS native font, system theme, system locale.
  // The default landing experience for first-time users + reset.
  'stylePreset_systemDefault_label': {
    'zh-Hans': '系统默认',
    'zh-Hant': '系統預設',
    'en': 'System default',
  },
  'stylePreset_systemDefault_description': {
    'zh-Hans': '使用您设备的系统字体（macOS/iOS 用 SF Pro，Windows 用 '
        '雅黑，Android 用 Roboto），跟随系统深浅色和语言。'
        '最适合大多数用户的默认选项。',
    'zh-Hant': '使用您裝置的系統字體（macOS/iOS 用 SF Pro，Windows 用 '
        '雅黑，Android 用 Roboto），跟隨系統深淺色與語言。'
        '最適合大多數使用者的預設選項。',
    'en':
        'Uses your device\'s system font (San Francisco on Apple, Segoe UI on Windows, Roboto on Android, …) and follows the OS theme + language. The default for most users.',
  },
  // 2026-05-08 (v1.1.1): three new style presets — Liquid Glass
  // (Apple WWDC25 frosted glass), Paper (warm sepia flat), Carbon
  // (dark high-contrast).
  'stylePreset_liquidGlass_label': {
    'zh-Hans': '流光玻璃',
    'zh-Hant': '流光玻璃',
    'en': 'Liquid Glass',
  },
  'stylePreset_liquidGlass_description': {
    'zh-Hans': '苹果 WWDC25 风格 —— 半透明毛玻璃磁贴，柔和高光与阴影，'
        '苹果设备上自动使用 SF Pro 字体。',
    'zh-Hant': '蘋果 WWDC25 風格 —— 半透明毛玻璃磁貼，柔和高光與陰影，'
        '蘋果裝置上自動使用 SF Pro 字體。',
    'en':
        'Apple WWDC25 style — translucent frosted-glass tiles with soft specular highlights and shadows. macOS / iOS users get SF Pro automatically.',
  },
  'stylePreset_paper_label': {
    'zh-Hans': '纸本',
    'zh-Hant': '紙本',
    'en': 'Paper',
  },
  'stylePreset_paper_description': {
    'zh-Hans': '温暖米色纸张质感，发丝边框，无阴影，宽松行距 —— '
        '像在读一本印刷的圣经。',
    'zh-Hant': '溫暖米色紙張質感，髮絲邊框，無陰影，寬鬆行距 —— '
        '像在讀一本印刷的聖經。',
    'en':
        'Warm cream paper feel — hairline borders, no shadows, generous line spacing. Reads like a printed Bible.',
  },
  'stylePreset_carbon_label': {
    'zh-Hans': '碳黑',
    'zh-Hant': '碳黑',
    'en': 'Carbon',
  },
  'stylePreset_carbon_description': {
    'zh-Hans': '高对比深色界面，锐利的硬阴影，紧凑布局 —— '
        '面向工具型重度用户。',
    'zh-Hant': '高對比深色界面，銳利的硬陰影，緊湊佈局 —— '
        '面向工具型重度使用者。',
    'en':
        'High-contrast dark surfaces with sharp drop-shadows, compact density — for power-user vibes.',
  },
  // 2026-08-08 (v1.6.62 — one worldwide build): every option in the
  // picker now ships with the app. The old copy promised a dozen
  // Google Fonts "downloaded on first use", which was a promise the
  // app could not keep for a reader behind the GFW — that is the
  // whole reason the download path is gone.
  'fontFamilyHint': {
    'zh-Hans': '所有字体都随应用打包，无需联网下载，离线也能用。'
        '推荐选「系统默认」—— macOS / iOS 用 SF Pro，Windows 用雅黑，'
        'Android 用 Roboto，跟随您设备的系统字体。',
    'zh-Hant': '所有字體都隨應用打包，無需連網下載，離線也能用。'
        '推薦選「系統預設」—— macOS / iOS 用 SF Pro，Windows 用雅黑，'
        'Android 用 Roboto，跟隨您裝置的系統字體。',
    'en':
        'Every font here ships with the app — nothing is downloaded, so the picker works offline. "System default" follows your device: SF Pro on macOS / iOS, Segoe UI on Windows, Roboto on Android.',
  },
  'confirm': {
    'zh-Hans': '确认',
    'zh-Hant': '確認',
    'en': 'Confirm',
  },
  'settingsSectionNotifications': {
    'zh-Hans': '通知',
    'zh-Hant': '通知',
    'en': 'Notifications',
  },
  'settingsShowEvidenceHint': {
    'zh-Hans': '主页"今日证据"卡片与快捷入口。',
    'zh-Hant': '主頁「今日證據」卡片與快捷入口。',
    'en': "Show Today's Evidence card and quick-link tile.",
  },
  'notificationsToggle': {
    'zh-Hans': '启用通知',
    'zh-Hant': '啟用通知',
    'en': 'Enable notifications',
  },
  'notificationsHint': {
    'zh-Hans': '每日经文、读经与新闻的轻提醒。',
    'zh-Hant': '每日經文、讀經與新聞的輕提醒。',
    'en': 'Gentle daily reminders for verse, reading, and news.',
  },
  'notificationsUnsupported': {
    'zh-Hans': '此浏览器不支持通知。',
    'zh-Hant': '此瀏覽器不支援通知。',
    'en': "This browser doesn't support notifications.",
  },
  'notificationsBlocked': {
    'zh-Hans': '浏览器已禁止此站点通知。请到浏览器设置中允许后再开启。',
    'zh-Hant': '瀏覽器已禁止此站點通知。請到瀏覽器設定中允許後再開啟。',
    'en': 'Permission blocked at the browser level. Re-enable in browser settings, then toggle on here.',
  },
  'notificationsDenied': {
    'zh-Hans': '浏览器拒绝了通知权限。',
    'zh-Hant': '瀏覽器拒絕了通知權限。',
    'en': 'Browser denied notification permission.',
  },
  'notificationsEnabledBody': {
    'zh-Hans': '通知已开启。我们会发送轻量的每日提醒。',
    'zh-Hant': '通知已開啟。我們會發送輕量的每日提醒。',
    'en': "Notifications are on. You'll get gentle daily reminders.",
  },
  'notificationsTest': {
    'zh-Hans': '发送测试通知',
    'zh-Hant': '發送測試通知',
    'en': 'Send test notification',
  },
  'notificationsTestBody': {
    'zh-Hans': '这是一条测试通知。',
    'zh-Hant': '這是一條測試通知。',
    'en': 'This is a test notification.',
  },
  'appName': {
    'zh-Hans': 'SeekSparks 寻光',
    'zh-Hant': 'SeekSparks 尋光',
    'en': 'SeekSparks',
  },
  'startReading': {
    // Hero CTA shown when the user has no saved reading position
    // yet (fresh install). Mirrors continueReading's voice but
    // signals "first time".
    'zh-Hans': '开始读经',
    'zh-Hant': '開始讀經',
    'en': 'Read Bible',
  },
  'continueReadingHint': {
    'zh-Hans': '从头开始阅读圣经。',
    'zh-Hant': '從頭開始閱讀聖經。',
    'en': 'Open the Bible from the beginning.',
  },
  'loading': {
    'zh-Hans': '加载中…',
    'zh-Hant': '載入中…',
    'en': 'Loading…',
  },
  'recentSearches': {
    'zh-Hans': '最近搜索',
    'zh-Hant': '最近搜索',
    'en': 'Recent',
  },
  'clear': {'zh-Hans': '清除', 'zh-Hant': '清除', 'en': 'Clear'},
  // 2026-05-07: explicit "clear all" label for the redesigned recent-
  // searches list footer. Distinct from per-item delete (× icon) and
  // from the generic 'clear' (which is reused elsewhere).
  'clearAllRecent': {
    'zh-Hans': '清除全部',
    'zh-Hant': '清除全部',
    'en': 'Clear all',
  },

  // ── Search help (2026-05-07) ─────────────────────────────────────
  // Localized strings for the new "?" help dialog on the search page.
  // Replaces the old undiscoverable feature surface — until now the
  // page accepted Strong's numbers, Bible refs, lemmas, and translit
  // silently, so most users only ever found the plain text-search
  // path. Help icon lives in the AppBar; the empty state also
  // surfaces a "Tip" line plus a small "Search tips" link.
  'searchHelpTooltip': {
    'zh-Hans': '搜索说明',
    'zh-Hant': '搜尋說明',
    'en': 'Search tips',
  },
  'searchHelpTitle': {
    'zh-Hans': '如何搜索',
    'zh-Hant': '如何搜尋',
    'en': 'How to search',
  },
  'searchHelpBasicTitle': {
    'zh-Hans': '基础',
    'zh-Hant': '基礎',
    'en': 'Basic',
  },
  'searchHelpBasicWord': {
    'zh-Hans': '直接输入字词或短句，可在当前圣经版本中查找包含该内容的经文。',
    'zh-Hant': '直接輸入字詞或短句，可在當前聖經版本中查找包含該內容的經文。',
    'en':
        'Type a word or phrase to find every verse that contains it '
            '(in your current Bible version).',
  },
  'searchHelpBasicRef': {
    'zh-Hans': '输入经文位置可直接跳转，例如「约 3:16」「John 3:16」「Rom 12:1-2」。',
    'zh-Hant': '輸入經文位置可直接跳轉，例如「約 3:16」「John 3:16」「Rom 12:1-2」。',
    'en':
        'Type a reference like "John 3:16", "约 3:16", or '
            '"Rom 12:1-2" to jump directly to that verse.',
  },
  'searchHelpBasicRecent': {
    'zh-Hans': '点击上方任一最近搜索可重复查询；点击右侧 × 可单独删除某条记录。',
    'zh-Hant': '點擊上方任一最近搜尋可重複查詢；點擊右側 × 可單獨刪除某條記錄。',
    'en':
        'Tap any recent search above to repeat it. Tap × to remove a '
            'single entry, or "Clear all" to wipe history.',
  },
  'searchHelpAdvancedTitle': {
    'zh-Hans': '进阶',
    'zh-Hant': '進階',
    'en': 'Advanced',
  },
  'searchHelpAdvStrongs': {
    'zh-Hans': '输入 Strong\'s 编号（如「G2316」「H7200」）打开词典与经文索引。',
    'zh-Hant': '輸入 Strong\'s 編號（如「G2316」「H7200」）打開詞典與經文索引。',
    'en':
        'Strong\'s number: type "G2316" / "H7200" to open the lexicon '
            'entry plus every verse that uses that word.',
  },
  // v1.3.91: operator tooltips, reused by the command-line strip (#294).
  'booleanSearchHeader': {
    'zh-Hans': '{query} — 共 {count} 节',
    'zh-Hant': '{query} — 共 {count} 節',
    'en': '{query} — {count} verses',
  },
  // #295: a Strong's result reports BOTH counts, as BibleWorks' status
  // line does — verses and hits differ (G25 is 143 hits in 110 verses).
  'strongsHeaderWithHits': {
    'zh-Hans': '{query} — 共 {count} 节 · {hits} 处',
    'zh-Hant': '{query} — 共 {count} 節 · {hits} 處',
    'en': '{query} — {count} verses · {hits} occurrences',
  },
  // v1.6.96: a wildcard matched more Strong's numbers than the expansion
  // searches, so the verse count is a floor. This string used to describe
  // the per-entry 500-verse cap, which no longer exists.
  'strongsHeaderPartial': {
    'zh-Hans': '{query} — 至少 {count} 节；通配符匹配的词条超出检索上限',
    'zh-Hant': '{query} — 至少 {count} 節；通配符匹配的詞條超出檢索上限',
    'en': '{query} — at least {count} verses; the wildcard matched more '
        'numbers than were searched',
  },
  'searchOpAndTip': {
    'zh-Hans': '同时含两者',
    'zh-Hant': '同時含兩者',
    'en': 'Verses with BOTH',
  },
  'searchOpOrTip': {
    'zh-Hans': '含其中之一',
    'zh-Hant': '含其中之一',
    'en': 'Verses with EITHER',
  },
  'searchOpNotTip': {
    'zh-Hans': '含第一个但不含第二个',
    'zh-Hant': '含第一個但不含第二個',
    'en': 'Verses with the first but not the second',
  },
  // {n} rather than a hard 5: the distance is adjustable from the hint
  // row, and a tooltip that keeps saying 5 while the button says NEAR7 is
  // worse than no tooltip.
  'searchOpNearTip': {
    'zh-Hans': '两者相距 {n} 个词以内，不分先后',
    'zh-Hant': '兩者相距 {n} 個詞以內，不分先後',
    'en': 'Within {n} words of each other, either order',
  },
  'searchOpStarTip': {
    'zh-Hans': '前缀通配符（如 G25✶）',
    'zh-Hant': '前綴萬用字元（如 G25✶）',
    'en': 'Prefix wildcard (e.g. G25✶)',
  },

  // ====== Workbench (BibleWorks-style three-pane pad workspace) ======
  // 2026-08-04: command pane (left), Bible reader (center), live
  // original-language analysis (right). See workbench_page.dart.
  'workbench': {
    'zh-Hans': '研经工作台',
    'zh-Hant': '研經工作台',
    'en': 'Workbench',
  },
  // 2026-08 (SeekSparks): BibleWorks-style parallel Browse.
  'parallelBrowse': {
    'zh-Hans': '并排对照',
    'zh-Hant': '並排對照',
    'en': 'Parallel',
  },
  'parallelEmptyHint': {
    'zh-Hans': '打开一章经文，即可并排比较多个译本与原文。',
    'zh-Hant': '開啟一章經文，即可並排比較多個譯本與原文。',
    'en': 'Open a chapter to compare versions side by side.',
  },
  // #274: the Browse pane's wait used to be a 16 px dot in the middle of
  // a 670 px column, which reads as "empty", not as "working". It now
  // names the editions it is still fetching — on a cold cache those are
  // multi-megabyte downloads, and a reader who knows what the pause is
  // for waits differently from one looking at a blank column.
  'wbBrowseLoadingVersions': {
    'zh-Hans': '正在载入译本',
    'zh-Hant': '正在載入譯本',
    'en': 'Loading editions',
  },
  'wbBrowseLoadingChapter': {
    'zh-Hans': '正在准备本章',
    'zh-Hant': '正在準備本章',
    'en': 'Preparing this chapter',
  },
  'classicReader': {
    'zh-Hans': '经典阅读模式',
    'zh-Hant': '經典閱讀模式',
    'en': 'Classic Reader',
  },
  // ====== Centre pane: split view (bwh38) ======
  'splitView': {
    'zh-Hans': '双栏对读（两个译本并列）',
    'zh-Hant': '雙欄對讀（兩個譯本並列）',
    'en': 'Split (two editions side by side)',
  },
  'splitViewShort': {
    'zh-Hans': '双栏',
    'zh-Hant': '雙欄',
    'en': 'Split',
  },
  'splitNeedsWidth': {
    'zh-Hans': '需更宽的中栏',
    'zh-Hant': '需更寬的中欄',
    'en': 'needs a wider centre',
  },
  'splitLoading': {
    'zh-Hans': '正在打开第二栏…',
    'zh-Hant': '正在打開第二欄…',
    'en': 'Opening the second column…',
  },
  // ====== Command-line query language (bwh16) ======
  'cmdListSeparator': {'zh-Hans': '、', 'zh-Hant': '、', 'en': ', '},
  'cmdPartSeparator': {'zh-Hans': ' · ', 'zh-Hant': ' · ', 'en': ' · '},
  'cmdEchoAll': {
    'zh-Hans': '同时包含：{terms}',
    'zh-Hant': '同時包含：{terms}',
    'en': 'All of: {terms}',
  },
  'cmdEchoAny': {
    'zh-Hans': '包含任一：{terms}',
    'zh-Hant': '包含任一：{terms}',
    'en': 'Any of: {terms}',
  },
  'cmdEchoPhrase': {
    'zh-Hans': '依次出现：{parts}',
    'zh-Hant': '依次出現：{parts}',
    'en': 'In order: {parts}',
  },
  'cmdEchoWithout': {
    'zh-Hans': '不含：{terms}',
    'zh-Hant': '不含：{terms}',
    'en': 'without: {terms}',
  },
  'cmdEchoContext': {
    'zh-Hans': '相隔 {n} 节以内',
    'zh-Hant': '相隔 {n} 節以內',
    'en': 'within {n} verses',
  },
  'cmdEchoGapExact': {
    'zh-Hans': '任意 {n} 个词',
    'zh-Hant': '任意 {n} 個詞',
    'en': 'any {n} words',
  },
  'cmdEchoGapUpTo': {
    'zh-Hans': '至多 {n} 个词',
    'zh-Hant': '至多 {n} 個詞',
    'en': 'any {n} or fewer words',
  },
  'cmdEchoNotWord': {
    'zh-Hans': '除 {w} 以外的任意词',
    'zh-Hant': '除 {w} 以外的任意詞',
    'en': 'any word but {w}',
  },
  'cmdIssueEmpty': {
    'zh-Hans': '请在运算符后输入要搜索的内容。',
    'zh-Hant': '請在運算子後輸入要搜尋的內容。',
    'en': 'Type what to search for after the operator.',
  },
  'cmdIssueCompound': {
    'zh-Hans': '暂不支持 ( ) 复合搜索。',
    'zh-Hant': '暫不支援 ( ) 複合搜尋。',
    'en': 'Compound searches with ( ) are not supported yet.',
  },
  'cmdIssueRegex': {
    'zh-Hans': '不支持正则表达式搜索（~）。',
    'zh-Hant': '不支援正規表達式搜尋（~）。',
    'en': 'Regular expression searches (~) are not supported.',
  },
  'cmdIssueFuzzy': {
    'zh-Hans': '不支持词根模糊搜索（=）。',
    'zh-Hant': '不支援詞根模糊搜尋（=）。',
    'en': 'Fuzzy stemming searches (=) are not supported.',
  },
  'cmdIssueStrongsTag': {
    'zh-Hans': '暂不支持原文编号标记（@），请改用 G25 AND G26。',
    'zh-Hant': '暫不支援原文編號標記（@），請改用 G25 AND G26。',
    'en': "Strong's tags (@) are not supported yet — use G25 AND G26.",
  },
  'cmdIssuePhraseNot': {
    'zh-Hans': '短语搜索中的 ! 只能放在单个词之前。',
    'zh-Hant': '片語搜尋中的 ! 只能放在單個詞之前。',
    'en': 'In a phrase, ! can only stand in front of a single word.',
  },
  'cmdIssueContext': {
    'zh-Hans': '; 后的节数上限为 {max}。',
    'zh-Hant': '; 後的節數上限為 {max}。',
    'en': 'The verse context after ; must be {max} or less.',
  },
  'cmdSyntaxTitle': {
    'zh-Hans': '命令行语法',
    'zh-Hant': '命令行語法',
    'en': 'Command line syntax',
  },
  'cmdSyntaxAnd': {
    'zh-Hans': '.爱 神 — 同一节里两个词都出现',
    'zh-Hant': '.愛 神 — 同一節裡兩個詞都出現',
    'en': '.love god — both words in one verse',
  },
  'cmdSyntaxOr': {
    'zh-Hans': '/信心 行为 — 出现任意一个',
    'zh-Hant': '/信心 行為 — 出現任意一個',
    'en': '/faith works — either word',
  },
  'cmdSyntaxPhrase': {
    'zh-Hans': "'神说要有光 — 按顺序紧挨着出现",
    'zh-Hant': "'神說要有光 — 按順序緊挨著出現",
    'en': "'and god said — the words in that order",
  },
  'cmdSyntaxNot': {
    'zh-Hans': '.耶稣 !基督 — 有前者、没有后者',
    'zh-Hant': '.耶穌 !基督 — 有前者、沒有後者',
    'en': '.jesus !christ — has the first, not the second',
  },
  'cmdSyntaxWild': {
    'zh-Hans': '.faith* — ✶ 代表任意多个字符，? 代表一个',
    'zh-Hant': '.faith* — ✶ 代表任意多個字元，? 代表一個',
    'en': '.faith* — ✶ is any characters, ? is exactly one',
  },
  'cmdSyntaxGap': {
    'zh-Hans': "'信心 *3 基督 — 中间最多隔 3 个词",
    'zh-Hant': "'信心 *3 基督 — 中間最多隔 3 個詞",
    'en': "'faith *3 christ — up to 3 words in between",
  },
  'cmdSyntaxContext': {
    'zh-Hans': '.保罗 西拉;10 — 相隔 10 节以内',
    'zh-Hant': '.保羅 西拉;10 — 相隔 10 節以內',
    'en': '.paul silas;10 — within 10 verses of each other',
  },
  'cmdSyntaxHistory': {
    'zh-Hans': '↑ ↓ 调出上次输入的命令 · Esc 清空',
    'zh-Hant': '↑ ↓ 調出上次輸入的命令 · Esc 清空',
    'en': '↑ ↓ recall earlier commands · Esc clears',
  },
  'cmdSyntaxToggle': {
    'zh-Hans': '语法说明',
    'zh-Hant': '語法說明',
    'en': 'Syntax help',
  },
  // ── Task #294 ─────────────────────────────────────────────────────
  // The strip carries two grammars and the card documented only one of
  // them: a reader who saw a NEAR5 button, pressed `?` and read ten lines
  // about `.love god` had no way left to find out what NEAR5 was. Section
  // headings, because the fact that there ARE two grammars is the thing
  // that was missing, not one more undifferentiated line.
  'cmdSyntaxSectionText': {
    'zh-Hans': '文字',
    'zh-Hant': '文字',
    'en': 'Text',
  },
  'cmdSyntaxSectionStrongs': {
    'zh-Hans': '原文编号',
    'zh-Hant': '原文編號',
    'en': "Strong's numbers",
  },
  'cmdSyntaxSectionCommands': {
    'zh-Hans': '命令',
    'zh-Hant': '命令',
    'en': 'Commands',
  },
  'cmdSyntaxStrongsBool': {
    'zh-Hans': 'G25 AND G26 — 两个编号都出现 · OR 任一 · NOT 有前者没后者',
    'zh-Hant': 'G25 AND G26 — 兩個編號都出現 · OR 任一 · NOT 有前者沒後者',
    'en': 'G25 AND G26 — both numbers · OR either · NOT the first not the second',
  },
  // The number is a word DISTANCE, not a gap: NEAR5 admits four words in
  // between, so it is BibleWorks' `*4` and not its `*5`. Saying so here is
  // cheaper than a reader discovering it from a hit count.
  'cmdSyntaxStrongsNear': {
    'zh-Hans': 'G25 NEAR5 G26 — 相距 5 个词以内，不分先后（中间最多 4 个词）',
    'zh-Hant': 'G25 NEAR5 G26 — 相距 5 個詞以內，不分先後（中間最多 4 個詞）',
    'en': 'G25 NEAR5 G26 — within 5 words, either order (up to 4 words between)',
  },
  'cmdSyntaxStrongsWild': {
    'zh-Hans': 'G25✶ — 所有以 G25 开头的编号 · G25 !G26 与 NOT 相同',
    'zh-Hant': 'G25✶ — 所有以 G25 開頭的編號 · G25 !G26 與 NOT 相同',
    'en': "G25✶ — every number starting G25 · G25 !G26 is the same as NOT",
  },
  // ── Task #299 ─────────────────────────────────────────────────────
  // The card printed `G25 AND G26` without ever saying where a reader is
  // supposed to get a G25. The Word List for the passage in view is the
  // answer, and it is one tap away — so this line is the link, not a
  // description of one.
  'cmdSyntaxFindNumber': {
    'zh-Hans': '编号从哪来？打开本章的原文词表 →',
    'zh-Hant': '編號從哪來？開啟本章的原文詞表 →',
    'en': "Where do the numbers come from? Open this chapter's Word List →",
  },
  // The card's examples are runnable queries, and until #299 the only way
  // to use one was to retype it. Tapping puts it on the line WITHOUT
  // running it: `ai …` leaves the device, and every text example is a
  // guess at what the reader wants that they should get to edit first.
  'cmdSyntaxTapHint': {
    'zh-Hans': '点任意一行，即可把该例子填入命令行。',
    'zh-Hant': '點任一行，即可把該例子填入命令行。',
    'en': 'Tap any line to put that example on the command line.',
  },
  // The one-tap rewrite offered under a line that will not run.
  'cmdDraftUseInstead': {
    'zh-Hans': '改用这个',
    'zh-Hant': '改用這個',
    'en': 'Use this instead',
  },
  'cmdDraftFindNumber': {
    'zh-Hans': '查编号',
    'zh-Hant': '查編號',
    'en': 'Find a number',
  },
  // Operator-button tooltips. The strip had none at all, which is how a
  // word-shaped token like NEAR5 could sit there unexplained.
  'cmdOpTipAll': {
    'zh-Hans': '. 同一节里每个词都出现',
    'zh-Hant': '. 同一節裡每個詞都出現',
    'en': '. every word, one verse',
  },
  'cmdOpTipAny': {
    'zh-Hans': '/ 出现任意一个词',
    'zh-Hant': '/ 出現任意一個詞',
    'en': '/ any of the words',
  },
  'cmdOpTipPhrase': {
    'zh-Hans': "' 按顺序紧挨着出现",
    'zh-Hant': "' 按順序緊挨著出現",
    'en': "' the words in that order",
  },
  'cmdOpTipNot': {
    'zh-Hans': '! 排除紧跟其后的词（原文编号亦可：G25 !G26）',
    'zh-Hant': '! 排除緊跟其後的詞（原文編號亦可：G25 !G26）',
    'en': "! excludes the word it is glued to (also G25 !G26)",
  },
  'cmdOpTipStar': {
    'zh-Hans': '✶ 接在词后是通配符（faith✶、G25✶）；单独一个是词距',
    'zh-Hant': '✶ 接在詞後是萬用字元（faith✶、G25✶）；單獨一個是詞距',
    'en': '✶ after a word it is a wildcard (faith✶, G25✶); alone it is a word gap',
  },
  // Live hints under the strip — the reported failure ("clicked NEAR5,
  // nothing happens") occurs BEFORE there is a query to read back, so the
  // pane's finished-query echo could never have caught it.
  'cmdDraftNeedsSecond': {
    'zh-Hans': '{op} 后面还需要一个原文编号，例如 G26。',
    'zh-Hant': '{op} 後面還需要一個原文編號，例如 G26。',
    'en': "{op} needs a second Strong's number after it, e.g. G26.",
  },
  'cmdDraftNeedsPair': {
    'zh-Hans': '{op} 用来连接两个原文编号：「G25 {op} G26」。请先输入一个编号。',
    'zh-Hant': '{op} 用來連接兩個原文編號：「G25 {op} G26」。請先輸入一個編號。',
    'en': "{op} joins two Strong's numbers — \"G25 {op} G26\". "
        'Type a number first.',
  },
  'cmdDraftNearWindow': {
    'zh-Hans': '相距 {n} 个词以内，不分先后（中间最多 {gap} 个词）。',
    'zh-Hant': '相距 {n} 個詞以內，不分先後（中間最多 {gap} 個詞）。',
    'en': 'Within {n} words of each other, in either order '
        '(up to {gap} words in between).',
  },
  // A combining operator typed between ordinary WORDS. Without these the
  // whole line reached the literal text scan and returned nothing, silently.
  'cmdDraftWordsFix': {
    'zh-Hans': '{op} 只连接原文编号，不连接词。同样意思的词语写法：',
    'zh-Hant': '{op} 只連接原文編號，不連接詞。同樣意思的詞語寫法：',
    'en': "{op} joins two Strong's numbers, not words. "
        'The same search in words:',
  },
  'cmdDraftWordsNearFix': {
    'zh-Hans': '{op} 只连接原文编号，不连接词。词语最接近的写法是按顺序的：',
    'zh-Hant': '{op} 只連接原文編號，不連接詞。詞語最接近的寫法是按順序的：',
    'en': "{op} joins two Strong's numbers, not words. "
        'The closest word form keeps them in order:',
  },
  'cmdDraftWordsNoFix': {
    'zh-Hans': '{op} 只连接原文编号，不连接词。这一行会被当成一整串文字去查。',
    'zh-Hant': '{op} 只連接原文編號，不連接詞。這一行會被當成一整串文字去查。',
    'en': "{op} joins two Strong's numbers, not words. "
        'This line will be searched as one literal string.',
  },
  'cmdDraftNearNoDistance': {
    'zh-Hans': '{op} 后面要写距离，例如 {op}5。相距几个词以内：',
    'zh-Hant': '{op} 後面要寫距離，例如 {op}5。相距幾個詞以內：',
    'en': '{op} needs a distance after it, e.g. {op}5. How many words apart:',
  },
  'cmdDraftNotStrongsShape': {
    'zh-Hans': '这一行不会当作原文编号检索来跑。写法是「G25 AND G26」。',
    'zh-Hant': '這一行不會當作原文編號檢索來跑。寫法是「G25 AND G26」。',
    'en': "This will not run as a Strong's search. The shape is G25 AND G26.",
  },
  'cmdDraftNotStrongsToken': {
    'zh-Hans': '「{token}」不是原文编号，所以整行会被当成文字去查。'
        '编号的样子是 G25 或 H430。',
    'zh-Hant': '「{token}」不是原文編號，所以整行會被當成文字去查。'
        '編號的樣子是 G25 或 H430。',
    'en': '"{token}" is not a Strong\'s number, so this runs as a plain '
        'text search. Numbers look like G25 or H430.',
  },
  'cmdDraftNearFewer': {
    'zh-Hans': '缩小词距',
    'zh-Hant': '縮小詞距',
    'en': 'Narrower window',
  },
  'cmdDraftNearWider': {
    'zh-Hans': '扩大词距',
    'zh-Hant': '擴大詞距',
    'en': 'Wider window',
  },
  // ── Command verbs (bwh44) ─────────────────────────────────────────
  'cmdvNeedsArgument': {
    'zh-Hans': 'd 之后要写版本（d kjv）、语言（d 英文）、'
        '移除（d -kjv），或 c 清空。',
    'zh-Hant': 'd 之後要寫版本（d kjv）、語言（d 英文）、'
        '移除（d -kjv），或 c 清空。',
    'en': 'After d, name an edition (d kjv), a language (d english), '
        'a removal (d -kjv) or c to clear.',
  },
  'cmdvUnknownVersion': {
    'zh-Hans': '没有名为「{x}」的版本。',
    'zh-Hant': '沒有名為「{x}」的版本。',
    'en': 'No edition called "{x}".',
  },
  'cmdvAvailable': {
    'zh-Hans': '现有：{list}',
    'zh-Hant': '現有：{list}',
    'en': 'Available: {list}',
  },
  'cmdvCannotRemoveSearch': {
    'zh-Hans': '{x} 是当前阅读与检索的版本，始终显示。',
    'zh-Hant': '{x} 是目前閱讀與檢索的版本，始終顯示。',
    'en': '{x} is the edition you are reading and searching, '
        'so it is always shown.',
  },
  'cmdvAlreadyDisplayed': {
    'zh-Hans': '{x} 已在对照栏中。',
    'zh-Hant': '{x} 已在對照欄中。',
    'en': '{x} is already in the stack.',
  },
  'cmdvNotDisplayed': {
    'zh-Hans': '{x} 不在对照栏中。',
    'zh-Hant': '{x} 不在對照欄中。',
    'en': '{x} is not in the stack.',
  },
  'cmdvUnknownScope': {
    'zh-Hans': '「{x}」不是书卷、章范围或约。可用：l 创、l 太 5-7、'
        'l 新约，或只输入 l 取消限定。',
    'zh-Hant': '「{x}」不是書卷、章範圍或約。可用：l 創、l 太 5-7、'
        'l 新約，或只輸入 l 取消限定。',
    'en': '"{x}" is not a book, a chapter range or a testament. '
        'Try l gen, l matt 5-7, l nt, or l on its own to clear.',
  },
  'cmdvEmptyScope': {
    'zh-Hans': '当前版本在 {x} 没有经文。',
    'zh-Hant': '目前版本在 {x} 沒有經文。',
    'en': 'This edition has no verses in {x}.',
  },
  'cmdvNoPassage': {
    'zh-Hans': '请先打开一章 — 只输入数字表示当前章的某一节。',
    'zh-Hant': '請先開啟一章 — 只輸入數字表示目前章的某一節。',
    'en': 'Open a chapter first — a bare number is a verse in the chapter '
        'you are reading.',
  },
  'cmdvVlsFile': {
    'zh-Hans': '这里不读经文列表文件。请在「经文列表」页建立列表，'
        '再打开它的限定开关。',
    'zh-Hant': '這裡不讀經文列表檔案。請在「經文列表」頁建立列表，'
        '再開啟它的限定開關。',
    'en': 'Verse-list files are not read here. Build the list in the '
        'Verse Lists tab and switch its filter on.',
  },
  'cmdvStackNow': {
    'zh-Hans': '对照栏：{list}',
    'zh-Hant': '對照欄：{list}',
    'en': 'Browse stack: {list}',
  },

  // ── Search scope (#280) ───────────────────────────────────────────
  // The two corpora are named by `oldTestament` / `newTestament`
  // (希伯来圣经 / 希腊圣经). Nothing on this path prints 旧约 / 新约.
  'scopePentateuch': {
    'zh-Hans': '摩西五经',
    'zh-Hant': '摩西五經',
    'en': 'Pentateuch',
  },
  'scopeHistory': {
    'zh-Hans': '历史书',
    'zh-Hant': '歷史書',
    'en': 'Historical books',
  },
  'scopeWisdom': {
    'zh-Hans': '诗歌智慧书',
    'zh-Hant': '詩歌智慧書',
    'en': 'Poetry & Wisdom',
  },
  'scopeProphets': {
    'zh-Hans': '先知书',
    'zh-Hant': '先知書',
    'en': 'Prophets',
  },
  'scopeGospels': {
    'zh-Hans': '福音书与使徒行传',
    'zh-Hant': '福音書與使徒行傳',
    'en': 'Gospels & Acts',
  },
  'scopePauline': {
    'zh-Hans': '保罗书信',
    'zh-Hant': '保羅書信',
    'en': 'Pauline epistles',
  },
  'scopeGeneralEpistles': {
    'zh-Hans': '普通书信',
    'zh-Hant': '普通書信',
    'en': 'General epistles',
  },
  'scopeTitle': {
    'zh-Hans': '检索范围',
    'zh-Hant': '檢索範圍',
    'en': 'Search scope',
  },
  'scopeMenu': {
    'zh-Hans': '检索范围…',
    'zh-Hant': '檢索範圍…',
    'en': 'Search scope…',
  },
  'scopeStatusField': {
    'zh-Hans': '限定',
    'zh-Hant': '限定',
    'en': 'Limits',
  },
  'scopeWholeBible': {
    'zh-Hans': '全书',
    'zh-Hant': '全書',
    'en': 'Whole Bible',
  },
  'scopeGroupsLabel': {
    'zh-Hans': '常用范围',
    'zh-Hant': '常用範圍',
    'en': 'Common ranges',
  },
  'scopeSelected': {
    'zh-Hans': '已选 {count} 卷',
    'zh-Hant': '已選 {count} 卷',
    'en': '{count} books selected',
  },
  'scopeNoneSelected': {
    'zh-Hans': '未限定 · 检索全书',
    'zh-Hant': '未限定 · 檢索全書',
    'en': 'No limit — the whole Bible',
  },
  'scopeApply': {
    'zh-Hans': '应用',
    'zh-Hant': '套用',
    'en': 'Apply',
  },
  'scopeClearAll': {
    'zh-Hans': '全部清除',
    'zh-Hant': '全部清除',
    'en': 'Clear all',
  },
  // ── Version stack picker (task #288) ──────────────────────────────
  // Which editions the Browse pane shows, and in what order. The order
  // is the half that had no pointer-driven control at all: the command
  // line could say `p bsb kjvs`, the checkbox list could not.
  'versionStackTitle': {
    'zh-Hans': '对照版本',
    'zh-Hant': '對照版本',
    'en': 'Versions displayed',
  },
  'versionStackShown': {
    'zh-Hans': '按显示顺序',
    'zh-Hant': '按顯示順序',
    'en': 'In display order',
  },
  'versionStackAvailable': {
    'zh-Hans': '可加入',
    'zh-Hant': '可加入',
    'en': 'Available',
  },
  // Marks the row that cannot be moved or removed — it is the edition
  // being read, and it is the first column by definition.
  'versionStackReading': {
    'zh-Hans': '正在阅读',
    'zh-Hant': '正在閱讀',
    'en': 'reading',
  },
  'versionStackReorderHint': {
    'zh-Hans': '拖动排序',
    'zh-Hant': '拖動排序',
    'en': 'Drag to reorder',
  },
  'versionStackCount': {
    'zh-Hans': '共 {count} 个版本',
    'zh-Hant': '共 {count} 個版本',
    'en': '{count} versions displayed',
  },
  'versionStackOnlyReading': {
    'zh-Hans': '仅显示正在阅读的版本',
    'zh-Hant': '僅顯示正在閱讀的版本',
    'en': 'Only the edition you are reading',
  },
  'versionStackClear': {
    'zh-Hans': '移除全部对照',
    'zh-Hant': '移除全部對照',
    'en': 'Remove all',
  },
  'versionStackAdd': {
    'zh-Hans': '加入',
    'zh-Hant': '加入',
    'en': 'Add',
  },
  'versionStackRemove': {
    'zh-Hans': '移除',
    'zh-Hant': '移除',
    'en': 'Remove',
  },
  // Shown when the active limit came from the `l` verb with chapters,
  // or from a Verse List. The picker deals in whole books, so it says
  // what it cannot represent rather than quietly widening it.
  'scopeNotBookShaped': {
    'zh-Hans': '当前限定（{name}）不是按卷设定的。在此选择书卷会取代它。',
    'zh-Hant': '目前限定（{name}）不是按卷設定的。在此選擇書卷會取代它。',
    'en': 'The active limit ({name}) is not a whole-book selection. '
        'Choosing books here replaces it.',
  },
  // bwh23: a narrowed statistic is printed beside what it would have
  // been over the whole version, because the narrowing is exactly what
  // makes the bare number unreadable.
  'scopeOfWhole': {
    'zh-Hans': '全书 {total} 处 · 限定 {name}',
    'zh-Hant': '全書 {total} 處 · 限定 {name}',
    'en': '{total} in all — limited to {name}',
  },
  'scopeEmptyHere': {
    'zh-Hans': '限定范围（{name}）内没有结果。全书共 {total} 处。',
    'zh-Hant': '限定範圍（{name}）內沒有結果。全書共 {total} 處。',
    'en': 'Nothing inside the scope ({name}). {total} in the whole Bible.',
  },
  // Replaces analysisStatsHint's "Whole-Bible occurrences" whenever a
  // limit is set, since under one that sentence is simply untrue.
  'scopeStatsHint': {
    'zh-Hans': '范围内 / 全书 出现次数，最罕见在前 · 限定 {name}',
    'zh-Hant': '範圍內 / 全書 出現次數，最罕見在前 · 限定 {name}',
    'en': 'In scope / in all, rarest first — limited to {name}.',
  },
  // …and that one in turn promises a ratio of occurrences, which a
  // chapter-level limit cannot supply: only the verse list can be cut at
  // a chapter, and it counts verses. Say which (#308).
  'scopeStatsHintVerses': {
    'zh-Hans': '范围内含此词的节数（非出现次数），最罕见在前 · 限定 {name}',
    'zh-Hant': '範圍內含此詞的節數（非出現次數），最罕見在前 · 限定 {name}',
    'en': 'Verses in {name} carrying the word, rarest first — not '
        'occurrences.',
  },
  'cmdvBrowseOn': {
    'zh-Hans': '中栏已切换到对照阅读。',
    'zh-Hant': '中欄已切換到對照閱讀。',
    'en': 'The centre pane is now the Browse stack.',
  },
  'cmdSyntaxVerbs': {
    'zh-Hans': 'd kjv / d -kjv / d c 增删对照版本 · p kjv bsb 重排 · '
        'l 创 限定检索范围 · 17 跳到本章第 17 节',
    'zh-Hant': 'd kjv / d -kjv / d c 增刪對照版本 · p kjv bsb 重排 · '
        'l 創 限定檢索範圍 · 17 跳到本章第 17 節',
    'en': 'd kjv / d -kjv / d c stack editions · p kjv bsb restack · '
        'l gen scope the search · 17 verse 17 of this chapter',
  },
  // 2026-08-08: the `ai` verb gets its own line rather than joining the
  // list above — it is the only command that leaves the device, and the
  // reader should be able to see that before typing it.
  'cmdSyntaxAi': {
    'zh-Hans': 'ai 关于焦虑的经文 — 描述你想找什么，AI 给出经文出处（仅供参考）',
    'zh-Hant': 'ai 關於焦慮的經文 — 描述你想找什麼，AI 給出經文出處（僅供參考）',
    'en': 'ai verses about anxiety — describe what you want; '
        'AI answers with references (reference only)',
  },
  'cmdTryAndHint': {
    'zh-Hans': '没有整段匹配。试试 “.{q}”，查找同一节里都出现这些词的经文。',
    'zh-Hant': '沒有整段匹配。試試「.{q}」，尋找同一節裡都出現這些詞的經文。',
    'en': 'No verse has that exact run of words. '
        'Try ".{q}" for verses containing all of them.',
  },
  'commandSearchHint': {
    'zh-Hans': '搜索经文，或原文编号：G25 AND G26',
    'zh-Hant': '搜尋經文，或原文編號：G25 AND G26',
    'en': "Search text, or Strong's: G25 AND G26",
  },
  'commandEmptyState': {
    'zh-Hans': '搜索经文，或组合原文编号：\nG25 AND G26 · G25 NEAR5 G26 · G25✶',
    'zh-Hant': '搜尋經文，或組合原文編號：\nG25 AND G26 · G25 NEAR5 G26 · G25✶',
    'en': "Search the text, or combine Strong's numbers:\n"
        'G25 AND G26 · G25 NEAR5 G26 · G25✶',
  },
  'wordStudyTitle': {
    'zh-Hans': '原文研读',
    'zh-Hant': '原文研讀',
    'en': 'Word Study',
  },
  'analysisEmptyHint': {
    'zh-Hans': '在中间的经文面板点选一节，这里会显示它的原文逐词研读。',
    'zh-Hant': '在中間的經文面板點選一節，這裡會顯示它的原文逐詞研讀。',
    'en': 'Tap a verse in the Bible pane and its original-language '
        'word study appears here.',
  },
  'collapsePanel': {
    'zh-Hans': '收起面板',
    'zh-Hant': '收起面板',
    'en': 'Collapse panel',
  },
  'expandPanel': {
    'zh-Hans': '展开面板',
    'zh-Hant': '展開面板',
    'en': 'Expand panel',
  },
  'searchHelpAdvLemma': {
    'zh-Hans': '直接输入希腊文（ἀγάπη）或希伯来文（אהבה）原文词，匹配后会打开对应的词典条目。',
    'zh-Hant': '直接輸入希臘文（ἀγάπη）或希伯來文（אהבה）原文詞，匹配後會打開對應的詞典條目。',
    'en':
        'Greek / Hebrew: type the original-language word (e.g. ἀγάπη '
            'or אהבה). Matching opens the lexicon entry directly.',
  },
  'searchHelpAdvTranslit': {
    'zh-Hans': '输入音译形式（如「agape」「shalom」「logos」）：完全匹配会直接打开词典；'
        '部分匹配则在搜索结果上方显示「您是否在找…」提示。',
    'zh-Hant': '輸入音譯形式（如「agape」「shalom」「logos」）：完全匹配會直接打開詞典；'
        '部分匹配則在搜尋結果上方顯示「您是否在找…」提示。',
    'en':
        'Transliteration: type "agape", "shalom", "logos". Exact '
            'matches open the lexicon; partial matches surface as a '
            '"Did you mean…" card alongside text results.',
  },
  'searchHelpAdvAi': {
    'zh-Hans': 'SeekSparks AI 搜索：当关键字搜索没有结果时，可以点击「用 SeekSparks AI 智能搜索」'
        '让 AI 帮你查找主题或模糊查询（如「最爱的章节」）。结果仅供参考，使用前请自行核对。',
    'zh-Hant': 'SeekSparks AI 搜尋：當關鍵字搜尋沒有結果時，可以點擊「用 SeekSparks AI 智慧搜尋」'
        '讓 AI 幫你查找主題或模糊查詢（如「最愛的章節」）。結果僅供參考，使用前請自行核對。',
    'en':
        'SeekSparks AI search: when keyword search returns nothing, tap '
            '"Search with SeekSparks AI" for fuzzy or thematic queries '
            '(e.g. "the love chapter"). Results are for reference '
            'only — verify before use.',
  },
  'searchHelpFooter': {
    'zh-Hans': '搜索范围跟随当前阅读的圣经版本，如果结果不符合预期，可在「设置」中切换版本。',
    'zh-Hant': '搜尋範圍跟隨當前閱讀的聖經版本，如果結果不符合預期，可在「設定」中切換版本。',
    'en':
        'Search scans the Bible version you currently have loaded — '
            'change versions in Settings if matches feel off.',
  },
  // Inline tip shown in the no-recents empty state.
  'searchHintQuickList': {
    'zh-Hans': '提示：可输入字词、参考（如「约 3:16」）、Strong\'s 编号「G2316」，或直接输入希腊文 / 希伯来文。',
    'zh-Hant': '提示：可輸入字詞、參考（如「約 3:16」）、Strong\'s 編號「G2316」，或直接輸入希臘文 / 希伯來文。',
    'en':
        'Tip: try a word, a reference like "John 3:16", a Strong\'s '
            'number "G2316", or Greek/Hebrew text directly.',
  },
  // "Did you mean lexicon entry…" card surfaced when a Latin-token
  // query weakly matches a Greek/Hebrew lemma (replaces the previous
  // silent auto-redirect that hijacked common English words).
  'searchLemmaSuggestionTitle': {
    'zh-Hans': '您是否在找词典条目？',
    'zh-Hant': '您是否在找詞典條目？',
    'en': 'Did you mean this lexicon entry?',
  },
  // 2026-05-07 (v5): three search-mode chips below the AppBar.
  // User wanted explicit per-mode entry points instead of a single
  // catch-all Enter handler.
  'searchModeText': {
    'zh-Hans': '经文搜索',
    'zh-Hant': '經文搜尋',
    'en': 'Search',
  },
  'searchModeTextTip': {
    'zh-Hans': '在当前圣经中查找包含这个字词或短句的经节（按 Enter 也可触发）。',
    'zh-Hant': '在當前聖經中查找包含這個字詞或短句的經節（按 Enter 也可觸發）。',
    'en':
        'Find verses containing this word or phrase. Pressing Enter '
            'also triggers this mode.',
  },
  'searchModeWordStudy': {
    'zh-Hans': '原文 / Strong\'s',
    'zh-Hant': '原文 / Strong\'s',
    'en': 'Word study',
  },
  'searchModeWordStudyTip': {
    'zh-Hans': 'Strong\'s 编号（G2316 / H7200）、希腊文 / 希伯来文原文，'
        '或音译形式（agape）。直接跳转到对应词典条目与经文索引。',
    'zh-Hant': 'Strong\'s 編號（G2316 / H7200）、希臘文 / 希伯來文原文，'
        '或音譯形式（agape）。直接跳轉到對應詞典條目與經文索引。',
    'en':
        'Strong\'s numbers (G2316 / H7200), Greek / Hebrew text, or '
            'transliteration (agape). Jumps to the lexicon entry plus '
            'concordance.',
  },
  'searchModeAi': {
    'zh-Hans': 'SeekSparks AI',
    'zh-Hant': 'SeekSparks AI',
    'en': 'SeekSparks AI',
  },
  'searchModeAiTip': {
    'zh-Hans': '通过 SeekSparks AI 进行模糊或主题搜索（如「最爱的章节」）。结果仅供参考，'
        '使用前请自行核对。',
    'zh-Hant': '透過 SeekSparks AI 進行模糊或主題搜尋（如「最愛的章節」）。結果僅供參考，'
        '使用前請自行核對。',
    'en':
        'Fuzzy / thematic search via SeekSparks AI (e.g. "the love '
            'chapter"). Results are reference-only — verify before use.',
  },
  'searchWordStudyNoMatch': {
    'zh-Hans': '没有匹配的词典条目。可以尝试 Strong\'s 编号（G2316 / H7200）、'
        '希腊文 / 希伯来文原文，或精确的音译形式（如「agape」）。',
    'zh-Hant': '沒有匹配的詞典條目。可以嘗試 Strong\'s 編號（G2316 / H7200）、'
        '希臘文 / 希伯來文原文，或精確的音譯形式（如「agape」）。',
    'en':
        'No lexicon entry matched. Try a Strong\'s number '
            '(G2316 / H7200), a Greek / Hebrew word, or an exact '
            'transliteration ("agape").',
  },
  // 2026-05-07 (post-fix): scope banner shown in the no-results
  // state. Helps the user spot when a stuck filter is the reason for
  // 0 results, with a one-tap "widen" affordance.
  'searchScopeWhole': {
    'zh-Hans': '整本圣经',
    'zh-Hant': '整本聖經',
    'en': 'Entire Bible',
  },
  'searchScopeCurrentBook': {
    'zh-Hans': '当前书卷',
    'zh-Hant': '當前書卷',
    'en': 'Current book',
  },
  'searchScopeScanned': {
    'zh-Hans': '已扫描 {n} 节',
    'zh-Hant': '已掃描 {n} 節',
    'en': 'Scanned {n} verses',
  },
  'searchScopeWiden': {
    'zh-Hans': '改为搜索整本圣经',
    'zh-Hant': '改為搜尋整本聖經',
    'en': 'Search entire Bible instead',
  },
  // 2026-05-07 (v10): bulk-copy of search results.
  'copyAllResults': {
    'zh-Hans': '复制全部结果',
    'zh-Hant': '複製全部結果',
    'en': 'Copy all results',
  },
  'copyAllResultsHeader': {
    'zh-Hans': '搜索：「{query}」 · 共 {n} 条结果',
    'zh-Hant': '搜尋：「{query}」 · 共 {n} 條結果',
    'en': 'Search: "{query}" · {n} matches',
  },
  'copyAllResultsToast': {
    'zh-Hans': '已复制 {n} 条结果',
    'zh-Hant': '已複製 {n} 條結果',
    'en': 'Copied {n} matches',
  },
  // 2026-05-07 (post-fix v2): on-demand load states. Surfaced when
  // SearchPage is reached via a refreshed deep-link URL before the
  // app's bootstrap loader has finished parsing the Bible asset.
  'searchLoadingBible': {
    'zh-Hans': '正在加载圣经…',
    'zh-Hant': '正在載入聖經…',
    'en': 'Loading the Bible…',
  },
  'searchLoadBibleFailed': {
    'zh-Hans': '圣经加载失败',
    'zh-Hant': '聖經載入失敗',
    'en': 'Could not load the Bible.',
  },
  // Profile editing (Round 35)
  'profileEditTitle': {
    'zh-Hans': '编辑账号',
    'zh-Hant': '編輯帳號',
    'en': 'Edit profile',
  },
  'displayName': {
    'zh-Hans': '昵称',
    'zh-Hant': '暱稱',
    'en': 'Display name',
  },
  'avatarColor': {
    'zh-Hans': '头像颜色',
    'zh-Hant': '頭像顏色',
    'en': 'Avatar color',
  },
  'save': {'zh-Hans': '保存', 'zh-Hant': '保存', 'en': 'Save'},
  'profileEditNotice': {
    'zh-Hans': '账号名和颜色仅保存在本设备。若已使用 Google 登录，将以 Google 头像优先显示。',
    'zh-Hant': '帳號名和顏色僅保存在本裝置。若已使用 Google 登入，將以 Google 頭像優先顯示。',
    'en':
        'Profile name and color are stored on this device. If you\'re signed in with Google your photo will appear instead of the colored initial.',
  },
  'editProfile': {
    'zh-Hans': '编辑账号',
    'zh-Hant': '編輯帳號',
    'en': 'Edit profile',
  },
  'setPhoto': {
    'zh-Hans': '设置头像',
    'zh-Hant': '設置頭像',
    'en': 'Set photo',
  },
  'changePhoto': {
    'zh-Hans': '更换头像',
    'zh-Hant': '更換頭像',
    'en': 'Change photo',
  },
  'removePhoto': {
    'zh-Hans': '删除头像',
    'zh-Hant': '刪除頭像',
    'en': 'Remove photo',
  },
  // ── Bible Evidence (Round 38) ────────────────────────────────────
  'bibleEvidence': {
    'zh-Hans': '圣经实证',
    'zh-Hant': '聖經實證',
    'en': 'Bible Evidence',
  },
  'bibleEvidenceSubtitle': {
    'zh-Hans': '考古、抄本、科学、历史多角度的实证档案',
    'zh-Hant': '考古、抄本、科學、歷史多角度的實證檔案',
    'en':
        'Archaeological, manuscript, scientific & historical evidence intersecting with the Bible.',
  },
  'evidenceForBook': {
    'zh-Hans': '经文实证 — {book}',
    'zh-Hant': '經文實證 — {book}',
    'en': 'Evidence — {book}',
  },
  'todayEvidence': {
    'zh-Hans': '今日实证',
    'zh-Hant': '今日實證',
    'en': 'Today\'s Evidence',
  },
  'evidenceDescription': {
    'zh-Hans': '详细说明',
    'zh-Hant': '詳細說明',
    'en': 'Description',
  },
  'scripturalCorrelation': {
    'zh-Hans': '经文对应',
    'zh-Hant': '經文對應',
    'en': 'Scriptural correlation',
  },
  'academicSources': {
    'zh-Hans': '学术来源',
    'zh-Hant': '學術來源',
    'en': 'Academic sources',
  },
  'readInBible': {
    'zh-Hans': '阅读经文',
    'zh-Hant': '閱讀經文',
    'en': 'Read',
  },
  'allCategories': {
    'zh-Hans': '全部分类',
    'zh-Hant': '全部分類',
    'en': 'All',
  },
  'resultsCount': {
    'zh-Hans': '共 {n} 条',
    'zh-Hant': '共 {n} 條',
    'en': '{n} results',
  },
  // Evidence scope-disclosure banner (chapter / book / archive).
  // Use {n}, {book}, {chapter} as placeholders; the widget does the
  // .replaceAll so we don't have to format here.
  'evidenceScopeChapter': {
    'zh-Hans': '为 {book} 第 {chapter} 章筛选 {n} 条',
    'zh-Hant': '為 {book} 第 {chapter} 章篩選 {n} 條',
    'en': '{n} entries for {book} {chapter}',
  },
  'evidenceScopeBook': {
    'zh-Hans': '为 {book} 筛选 {n} 条',
    'zh-Hant': '為 {book} 篩選 {n} 條',
    'en': '{n} entries for {book}',
  },
  'evidenceScopeBookFallback': {
    'zh-Hans': '{book} 第 {chapter} 章暂无相关条目 — 显示 {book} 全部 {n} 条',
    'zh-Hant': '{book} 第 {chapter} 章暫無相關條目 — 顯示 {book} 全部 {n} 條',
    'en':
        'No entries for {book} {chapter} — showing all {n} from {book}',
  },
  'evidenceWidenBook': {
    'zh-Hans': '查看 {book} 全部',
    'zh-Hant': '查看 {book} 全部',
    'en': 'Show all in {book}',
  },
  'evidenceWidenArchive': {
    'zh-Hans': '查看完整档案',
    'zh-Hant': '查看完整檔案',
    'en': 'Show full archive',
  },
  // Categories.
  'categoryArchaeology': {
    'zh-Hans': '考古',
    'zh-Hant': '考古',
    'en': 'Archaeology',
  },
  'categoryManuscripts': {
    'zh-Hans': '抄本',
    'zh-Hant': '抄本',
    'en': 'Manuscripts',
  },
  'categoryScience': {
    'zh-Hans': '科学',
    'zh-Hant': '科學',
    'en': 'Science',
  },
  'categoryHistory': {
    'zh-Hans': '历史',
    'zh-Hant': '歷史',
    'en': 'History',
  },
  // Confidence levels.
  'confidenceDefinitive': {
    'zh-Hans': '确证',
    'zh-Hant': '確證',
    'en': 'Definitive',
  },
  'confidenceStrong': {
    'zh-Hans': '强证据',
    'zh-Hant': '強證據',
    'en': 'Strong',
  },
  'confidenceCircumstantial': {
    'zh-Hans': '间接证据',
    'zh-Hant': '間接證據',
    'en': 'Circumstantial',
  },
  // SeekSparks AI search (Round 39, Stage 4 — Cloud Functions Gemini
  // proxy). Used by the Bible Evidence search button. Rebranded
  // 2026-05-07 from "Ask AI" so the SeekSparks brand is in front of the
  // user instead of a generic "AI" label, with reference-only caveat
  // surfaced via the disclaimer strings.
  'askAi': {
    'zh-Hans': '问 SeekSparks',
    'zh-Hant': '問 SeekSparks',
    'en': 'Ask SeekSparks',
  },
  'ask': {
    'zh-Hans': '提问',
    'zh-Hant': '提問',
    'en': 'Ask',
  },
  'askAiHint': {
    'zh-Hans': '例如：出埃及有何证据？',
    'zh-Hant': '例如：出埃及有何證據？',
    'en': 'e.g. What evidence supports the Exodus?',
  },
  'citations': {
    'zh-Hans': '引用条目',
    'zh-Hant': '引用條目',
    'en': 'Citations',
  },
  'keywordMatches': {
    'zh-Hans': '关键词匹配',
    'zh-Hant': '關鍵字匹配',
    'en': 'Keyword matches',
  },
  'settingsSectionAbout': {
    'zh-Hans': '关于',
    'zh-Hant': '關於',
    'en': 'About',
  },
  'appTagline': {
    'zh-Hans': '面向大屏幕的双语圣经解经工具。',
    'zh-Hant': '面向大螢幕的雙語聖經解經工具。',
    'en': 'A bilingual Bible exegesis tool for bigger screens.',
  },
  'contactIntro': {
    'zh-Hans': '作者 Paul Liu',
    'zh-Hant': '作者 Paul Liu',
    'en': 'Made by Paul Liu',
  },
  'contactTail': {
    'zh-Hans': '问题、反馈或其他事宜：',
    'zh-Hant': '問題、反饋或其他事宜：',
    'en': 'Questions, feedback, or anything else:',
  },
  // ── About / Attributions page (Round 56 day-3, 2026-05-06) ────
  // Standalone page reachable from Settings → About → "Attributions
  // & Licensing". Lists every bundled / referenced third-party
  // resource with its licence + rights holder, and surfaces the
  // takedown / copyright contact email prominently. Added in
  // response to a copyright-risk audit — the app bundles content
  // owned by other parties, so being transparent + reachable is
  // the basic mitigation.
  'aboutPageTitle': {
    'zh-Hans': '关于与版权说明',
    'zh-Hant': '關於與版權說明',
    'en': 'About & Attributions',
  },
  // 2026-06-16 (v1.3.88): in-app "check for updates" (GitHub Releases).
  'checkForUpdates': {
    'zh-Hans': '检查更新',
    'zh-Hant': '檢查更新',
    'en': 'Check for updates',
  },
  'updateChecking': {
    'zh-Hans': '检查中…',
    'zh-Hant': '檢查中…',
    'en': 'Checking…',
  },
  'updateUpToDate': {
    'zh-Hans': '已是最新版本 (v{v})',
    'zh-Hant': '已是最新版本 (v{v})',
    'en': "You're on the latest version (v{v})",
  },
  'updateCheckFailed': {
    'zh-Hans': '无法检查更新，请稍后再试',
    'zh-Hant': '無法檢查更新，請稍後再試',
    'en': "Couldn't check for updates — try again later",
  },
  'updateAvailableTitle': {
    'zh-Hans': '有可用更新',
    'zh-Hant': '有可用更新',
    'en': 'Update available',
  },
  'updateAvailableBody': {
    'zh-Hans': '新版本 v{new} 已发布（当前 v{cur}）。从 GitHub 下载后安装：'
        'Android 点开 APK 安装；桌面版解压后运行；iOS 请改用网页版。',
    'zh-Hant': '新版本 v{new} 已發佈（目前 v{cur}）。從 GitHub 下載後安裝：'
        'Android 點開 APK 安裝；桌面版解壓後執行；iOS 請改用網頁版。',
    'en': 'Version v{new} is available (you have v{cur}). Download it from '
        'GitHub, then install: Android opens the APK; desktop unzips and '
        'runs. iOS uses the web app.',
  },
  'updateDownload': {
    'zh-Hans': '下载',
    'zh-Hant': '下載',
    'en': 'Download',
  },
  // 2026-06-18 (v1.3.89): test-notification confirmation. {platform} is
  // filled in with the actual device (iOS/Android/macOS/Windows/Linux/
  // browser) — it used to hardcode "iOS" on every device.
  'notificationsTestSent': {
    'zh-Hans': '测试通知已发送。如果没有看到横幅，请在 {platform} 的通知设置中查看 SeekSparks'
        '（以及系统的专注 / 勿扰模式）。',
    'zh-Hant': '測試通知已發送。如果沒有看到橫幅，請在 {platform} 的通知設定中查看 SeekSparks'
        '（以及系統的專注 / 勿擾模式）。',
    'en': "Test notification sent. If you don't see a banner, check your "
        '{platform} notification settings for SeekSparks (or Focus / Do Not '
        'Disturb).',
  },
  'platformBrowser': {
    'zh-Hans': '浏览器',
    'zh-Hant': '瀏覽器',
    'en': 'browser',
  },
  'platformDevice': {
    'zh-Hans': '设备',
    'zh-Hant': '裝置',
    'en': 'device',
  },
  'aboutOpenButton': {
    'zh-Hans': '版权说明与联系方式',
    'zh-Hant': '版權說明與聯絡方式',
    'en': 'Attributions & licensing',
  },
  'aboutDisclaimer': {
    'zh-Hans': '本应用是非商业的个人 / 教会研经工具。应用代码以 MIT 许可证开源，'
        '但圣经文本、字典数据、讲道文本、地图等资源仍由其各自版权方所有，仅在'
        '研习用途下使用。本应用与下方列出的任何出版社、机构、字体厂商均无附属关系。',
    'zh-Hant': '本應用是非商業的個人 / 教會研經工具。應用代碼以 MIT 授權開源，'
        '但聖經文本、字典資料、講道文本、地圖等資源仍由其各自版權方所有，僅在'
        '研習用途下使用。本應用與下方列出的任何出版社、機構、字體廠商均無附屬關係。',
    'en':
        'This is a non-commercial personal / community Bible-study tool. '
            'The application code is open source under MIT, but bundled '
            'scripture texts, lexicon data, sermons, maps and other '
            'resources remain the copyright of their respective rights '
            'holders and are reproduced under fair-use / personal-study '
            'exemptions. This app is not affiliated with or endorsed by '
            'any publisher, ministry, or font foundry listed below.',
  },
  'aboutContactTitle': {
    'zh-Hans': '联系方式 · 版权下架请求',
    'zh-Hant': '聯絡方式 · 版權下架請求',
    'en': 'Contact · Takedown requests',
  },
  'aboutContactBody': {
    'zh-Hans': '欢迎反馈、提问，或如果您是版权方对本应用中的任何内容有疑义，请通过下方邮箱联系我。'
        '一封邮件即可——我会及时回复并配合处理。',
    'zh-Hant': '歡迎反饋、提問，或如果您是版權方對本應用中的任何內容有疑義，請通過下方郵箱聯絡我。'
        '一封郵件即可——我會及時回覆並配合處理。',
    'en':
        'Feedback and questions are welcome. If you are a rights '
            'holder and have any concern about content included in this '
            'app, a single email is sufficient — I will respond and act '
            'promptly.',
  },
  'aboutContactSla': {
    'zh-Hans': '一般 24 小时内回复 · 如确认下架，72 小时内移除。',
    'zh-Hant': '一般 24 小時內回覆 · 如確認下架，72 小時內移除。',
    'en':
        'Acknowledged within 24 hours · removed within 72 hours when warranted.',
  },
  'aboutSectionScriptures': {
    'zh-Hans': '内置圣经译本',
    'zh-Hant': '內置聖經譯本',
    'en': 'Bundled scripture texts',
  },
  'aboutSectionLexicons': {
    'zh-Hans': '原文资源 · Strong\'s 编号 · 字典',
    'zh-Hant': '原文資源 · Strong\'s 編號 · 字典',
    'en': "Strong's lexicons & original-language data",
  },
  'aboutSectionOther': {
    'zh-Hans': '地图 · 讲道 · 字体 · AI · 其他',
    'zh-Hant': '地圖 · 講道 · 字體 · AI · 其他',
    'en': 'Maps · Sermons · Fonts · AI · Other',
  },
  'aboutSectionAppLicense': {
    'zh-Hans': '应用代码许可证',
    'zh-Hant': '應用程式碼授權',
    'en': 'Application licence',
  },
  // Per-version licence rows.
  'aboutLicensePublicDomain': {
    'zh-Hans': '公有领域 · 无版权限制。',
    'zh-Hant': '公有領域 · 無版權限制。',
    'en': 'Public domain.',
  },
  'aboutVerKjv': {
    'zh-Hans': 'KJV 钦定本（1611 / 1769）',
    'zh-Hant': 'KJV 欽定本（1611 / 1769）',
    'en': 'KJV (1611 / 1769)',
  },
  'aboutVerLeb': {
    'zh-Hans': 'LEB（Lexham 英文圣经）',
    'zh-Hant': 'LEB（Lexham 英文聖經）',
    'en': 'LEB (Lexham English Bible)',
  },
  'aboutLicenseLeb': {
    'zh-Hans': '© Logos Bible Software · 仅限非商业研经使用。',
    'zh-Hant': '© Logos Bible Software · 僅限非商業研經使用。',
    'en': '© Logos Bible Software · non-commercial study only.',
  },
  'wordListTitle': {'zh-Hans': '词汇表', 'zh-Hant': '詞彙表', 'en': 'Word List'},
  'wordListScopeChapter': {
    'zh-Hans': '本章', 'zh-Hant': '本章', 'en': 'This chapter',
  },
  'wordListScopeBook': {
    'zh-Hans': '整卷', 'zh-Hant': '整卷', 'en': 'Whole book',
  },
  'wordListDistinct': {'zh-Hans': '个词', 'zh-Hant': '個詞', 'en': 'distinct'},
  'wordListTotal': {'zh-Hans': '字', 'zh-Hant': '字', 'en': 'words'},
  'wordListHapax': {
    'zh-Hans': '只出现一次', 'zh-Hant': '只出現一次', 'en': 'used once',
  },
  'wordListSortFreq': {'zh-Hans': '按词频', 'zh-Hant': '按詞頻', 'en': 'Frequency'},
  'wordListSortRare': {'zh-Hans': '最罕见', 'zh-Hant': '最罕見', 'en': 'Rarest'},
  'wordListSortNum': {'zh-Hans': '按编号', 'zh-Hant': '按編號', 'en': 'Number'},
  'wordListSortAlpha': {
    'zh-Hans': '按字母', 'zh-Hant': '按字母', 'en': 'Alphabetical',
  },
  'wordListNone': {
    'zh-Hans': '此段没有原文数据。',
    'zh-Hant': '此段沒有原文數據。',
    'en': 'No original-language data for this passage.',
  },
  'searchStatsTop': {'zh-Hans': '最多出现于', 'zh-Hant': '最多出現於', 'en': 'Most in'},
  'searchStatsBooks': {'zh-Hans': '卷书', 'zh-Hant': '卷書', 'en': 'books'},
  // ── What a search-stats number COUNTS (bwh23, task #308) ─────────────
  // bwh23's "What to Plot" dropdown lists verses-with-a-hit and hits as
  // separate entries, and on a common word they differ by a third. So the
  // unit is printed, never implied.
  'hitUnitVerses': {'zh-Hans': '按节', 'zh-Hant': '按節', 'en': 'verses'},
  'hitUnitOccurrences': {
    'zh-Hans': '按出现次数',
    'zh-Hant': '按出現次數',
    'en': 'occurrences',
  },
  'hitUnitTimesSuffix': {'zh-Hans': '×', 'zh-Hant': '×', 'en': '×'},
  'searchStatsTopIn': {
    'zh-Hans': '最多出现于（{unit}）',
    'zh-Hant': '最多出現於（{unit}）',
    'en': 'Most in ({unit})',
  },
  // A distribution drawn from a term that stands for less than it names
  // traces the limit, not the words. Until v1.6.96 the cause was the
  // concordance's own 500-verse cap; now it is only a wildcard whose
  // expansion was stopped, which drops whole words out of the query.
  'searchStatsTruncated': {
    'zh-Hans': '未显示分布图：通配符匹配的词条超出检索上限，图形只会显示上限的位置，而非这些词的实际分布。',
    'zh-Hant': '未顯示分佈圖：通配符匹配的詞條超出檢索上限，圖形只會顯示上限的位置，而非這些詞的實際分佈。',
    'en': 'No distribution: the wildcard matched more numbers than were '
        'searched, so a chart of this result would show the limit rather '
        'than the words.',
  },
  // ── The word-distribution chart (bwh23, task #290) ──────────────────
  // Opened from the strip under each word in the Stats tab.
  'wordChartOpen': {
    'zh-Hans': '查看完整分布图',
    'zh-Hant': '檢視完整分佈圖',
    'en': 'Open the full distribution chart',
  },
  // bwh23 plots seven different quantities and names each one, because
  // "64" means nothing until you know what was counted. Ours is
  // occurrences; BibleWorks' default is verses-containing-a-hit. The two
  // differ whenever a verse carries the word twice, so the chart says
  // which it is rather than borrowing their wording.
  'wordChartUnit': {
    'zh-Hans': '按出现次数统计，非节数——同一节可能出现多次。',
    'zh-Hant': '按出現次數統計，非節數——同一節可能出現多次。',
    'en': 'Counted by occurrence, not by verse — one verse may carry the '
        'word more than once.',
  },
  'wordChartUnitVerses': {
    'zh-Hans': '按节数统计，非出现次数——同一节出现多次只算一次。',
    'zh-Hant': '按節數統計，非出現次數——同一節出現多次只算一次。',
    'en': 'Counted by verse, not by occurrence — a verse carrying the word '
        'twice counts once.',
  },
  'wordChartInBooks': {
    'zh-Hans': '分布于 {total} 卷中的 {n} 卷',
    'zh-Hant': '分佈於 {total} 卷中的 {n} 卷',
    'en': 'In {n} of {total} books',
  },
  'wordChartSortCanonical': {
    'zh-Hans': '正典顺序',
    'zh-Hant': '正典順序',
    'en': 'Canonical',
  },
  'wordChartSortMost': {
    'zh-Hans': '由多到少',
    'zh-Hant': '由多到少',
    'en': 'Most first',
  },
  // The per-book map in the concordance index is whole-Bible and cannot
  // be narrowed, so under a limit the chart says plainly that it is not
  // showing the limited figure — bwh23's parenthesised denominator, in
  // reverse.
  'wordChartWholeBible': {
    'zh-Hans': '全圣经统计，不受当前范围（{name}）限制',
    'zh-Hant': '全聖經統計，不受目前範圍（{name}）限制',
    'en': 'Whole Bible — not narrowed by the active limit ({name})',
  },
  'wordChartCurrentBook': {
    'zh-Hans': '当前阅读',
    'zh-Hant': '目前閱讀',
    'en': 'Currently reading',
  },
  // The rank of this word among the words of that one book — a figure
  // the Eagle's View profile carries and BibleWorks has no equivalent
  // for. Greek only, so the row simply omits it elsewhere.
  'wordChartRankInBook': {
    'zh-Hans': '在该卷中排第 {n} 位',
    'zh-Hant': '在該卷中排第 {n} 位',
    'en': 'Ranked #{n} in that book',
  },
  'analysisTabKwic': {
    'zh-Hans': '上下文',
    'zh-Hant': '上下文',
    'en': 'KWIC',
  },
  'kwicHits': {'zh-Hans': '处', 'zh-Hant': '處', 'en': 'hits'},
  'kwicRefs': {'zh-Hans': '处经文', 'zh-Hant': '處經文', 'en': 'references'},
  'kwicSortRef': {'zh-Hans': '按经卷', 'zh-Hant': '按經卷', 'en': 'Reference'},
  'kwicSortLeft': {'zh-Hans': '按左侧', 'zh-Hant': '按左側', 'en': 'Left'},
  'kwicSortRight': {'zh-Hans': '按右侧', 'zh-Hant': '按右側', 'en': 'Right'},
  'kwicCollocates': {
    'zh-Hans': '常与之搭配',
    'zh-Hant': '常與之搭配',
    'en': 'Occurs with',
  },
  'kwicCopy': {'zh-Hans': '全部复制', 'zh-Hant': '全部複製', 'en': 'Copy all'},
  'kwicCopied': {'zh-Hans': '已复制', 'zh-Hant': '已複製', 'en': 'Copied'},
  'kwicMore': {'zh-Hans': '加载更多', 'zh-Hant': '載入更多', 'en': 'Load more'},
  'kwicAllShown': {'zh-Hans': '共', 'zh-Hant': '共', 'en': 'All'},
  'kwicNoHits': {
    'zh-Hans': '此译本中没有出现。',
    'zh-Hant': '此譯本中沒有出現。',
    'en': 'No occurrences in this version.',
  },
  'kwicUntagged': {
    'zh-Hans': '此译本没有原文编号标注，无法对齐上下文。请切换到 BSB 或和合本雅伟版。',
    'zh-Hant': '此譯本沒有原文編號標註，無法對齊上下文。請切換到 BSB 或和合本雅偉版。',
    'en': 'This translation carries no Strong\'s tagging, so its context '
        'cannot be aligned. Switch to BSB or 和合本雅伟版.',
  },
  'kwicHint': {
    'zh-Hans': '在经文中点选一个带编号的词，这里会列出它在全本圣经中的每一处上下文。',
    'zh-Hant': '在經文中點選一個帶編號的詞，這裡會列出它在全本聖經中的每一處上下文。',
    'en': 'Tap a tagged word in the text to see every place it occurs, '
        'aligned on the word.',
  },
  'analysisTabRelated': {
    'zh-Hans': '相关经文',
    'zh-Hant': '相關經文',
    'en': 'Related',
  },
  'relatedWords': {'zh-Hans': '个词', 'zh-Hant': '個詞', 'en': 'words'},
  'relatedWordsHint': {
    'zh-Hans': '点一下取用或弃用某词，长按加权三倍。',
    'zh-Hant': '點一下取用或棄用某詞，長按加權三倍。',
    'en': 'Tap a word to use it or drop it; hold to weight it ×3.',
  },
  'relatedAddWord': {
    'zh-Hans': '加入本节以外的词…',
    'zh-Hant': '加入本節以外的詞…',
    'en': 'Add a word not in the verse…',
  },
  'relatedThreshold': {'zh-Hans': '至少', 'zh-Hant': '至少', 'en': 'Min'},
  'relatedSortHits': {'zh-Hans': '按词数', 'zh-Hant': '按詞數', 'en': 'Hits'},
  'relatedHitsInVerse': {
    'zh-Hans': '个共用词',
    'zh-Hant': '個共用詞',
    'en': 'shared words',
  },
  'relatedNoWords': {
    'zh-Hans': '此节没有可供比对的词。',
    'zh-Hant': '此節沒有可供比對的詞。',
    'en': 'This verse has no words to match on.',
  },
  'relatedNoHits': {
    'zh-Hans': '没有经文共用这么多词。请调低下限，或多选几个词。',
    'zh-Hant': '沒有經文共用這麼多詞。請調低下限，或多選幾個詞。',
    'en': 'No verse shares that many words. Lower the threshold, or '
        'check more words.',
  },
  'aboutVerBsb': {
    'zh-Hans': 'BSB（Berean 标准译本）',
    'zh-Hant': 'BSB（Berean 標準譯本）',
    'en': 'BSB (Berean Standard Bible)',
  },
  'aboutLicenseBsb': {
    'zh-Hans': '出版方已将本译本释出至公有领域。',
    'zh-Hant': '出版方已將本譯本釋出至公有領域。',
    'en': 'Dedicated to the public domain by the publisher.',
  },
  'aboutVerNasb': {
    'zh-Hans': 'NASB 2020 新美国标准译本',
    'zh-Hant': 'NASB 2020 新美國標準譯本',
    'en': 'NASB 2020',
  },
  'aboutLicenseNasb': {
    'zh-Hans': '© Lockman 基金会 · 在出版方引用规定下使用。',
    'zh-Hant': '© Lockman 基金會 · 在出版方引用規定下使用。',
    'en':
        '© The Lockman Foundation · used under quotation provisions.',
  },
  'aboutVerCuvsYhwh': {
    'zh-Hans': '雅简+ / 雅繁+ 和合本雅伟版（简 / 繁）',
    'zh-Hant': '雅简+ / 雅繁+ 和合本雅偉版（簡 / 繁）',
    'en': '雅简+ / 雅繁+ (和合本雅伟版, simplified / traditional)',
  },
  'aboutLicenseCuvsYhwh': {
    'zh-Hans': '© 雅伟的话事工 · 经授权使用。',
    'zh-Hant': '© 雅偉的話事工 · 經授權使用。',
    'en':
        '© Yahweh De Hua Ministry · used with permission.',
  },
  'aboutVerLjk': {
    'zh-Hans': '梁简 / 梁繁 梁家铿译本（2025年 · 第二版，简 / 繁）',
    'zh-Hant': '梁简 / 梁繁 梁家鏗譯本（2025年 · 第二版，簡 / 繁）',
    'en': '梁简 / 梁繁 — Liang Jiakeng translation (2025, 2nd ed., simplified / traditional)',
  },
  'aboutLicenseLjk': {
    'zh-Hans': '© 圣经释经事工 · 经授权使用。',
    'zh-Hant': '© 聖經釋經事工 · 經授權使用。',
    'en': '© Bible Exegesis Ministry · used with permission.',
  },
  'aboutNivRemovedNote': {
    'zh-Hans': 'NIV（新国际译本）此前曾内置，但已于 2026 年 5 月移除——'
        'Biblica / Zondervan 对全文保有商业版权，未经出版方授权不得再分发完整文本。'
        '需要 NIV 的读者请使用 Bible Gateway / YouVersion 等官方渠道。',
    'zh-Hant': 'NIV（新國際譯本）此前曾內置，但已於 2026 年 5 月移除——'
        'Biblica / Zondervan 對全文保有商業版權，未經出版方授權不得再分發完整文本。'
        '需要 NIV 的讀者請使用 Bible Gateway / YouVersion 等官方渠道。',
    'en':
        'NIV (New International Version) was previously bundled but '
            'removed in 2026-05. Biblica / Zondervan retain commercial '
            'copyright on the full text and we cannot redistribute the '
            'JSON bundle without an explicit publisher licence. Readers '
            'seeking NIV should use Bible Gateway / YouVersion.',
  },
  // Lexicons.
  'aboutLexStrongs': {
    'zh-Hans': 'Strong\'s 希腊文 + 希伯来文编号',
    'zh-Hant': 'Strong\'s 希臘文 + 希伯來文編號',
    'en': "Strong's Greek + Hebrew Concordance",
  },
  'aboutLexCbol': {
    'zh-Hans': 'CBOL 中文释义',
    'zh-Hant': 'CBOL 中文釋義',
    'en': 'CBOL Chinese definitions',
  },
  'aboutLicenseCbol': {
    'zh-Hans': 'CC-BY-NC-SA 4.0 · 仅限非商业 · 衍生作品须沿用相同许可。',
    'zh-Hant': 'CC-BY-NC-SA 4.0 · 僅限非商業 · 衍生作品須沿用相同授權。',
    'en':
        'CC-BY-NC-SA 4.0 · non-commercial only; derivatives must keep the licence.',
  },
  'aboutLexLxx': {
    'zh-Hans': 'LXX 七十士译本 · 旧约↔希腊文对照',
    'zh-Hant': 'LXX 七十士譯本 · 舊約↔希臘文對照',
    'en': 'LXX (Septuagint) cross-references',
  },
  'aboutLexInterlinear': {
    'zh-Hans': '希腊文 + 希伯来文逐字对照（含 Strong\'s 编号）',
    'zh-Hant': '希臘文 + 希伯來文逐字對照（含 Strong\'s 編號）',
    'en': "Greek + Hebrew interlinear (Strong's-tagged)",
  },
  'aboutLicenseInterlinear': {
    'zh-Hans': '基于公有领域形态学数据库。',
    'zh-Hant': '基於公有領域形態學資料庫。',
    'en': 'Public-domain morphological databases.',
  },
  'aboutLexTsk': {
    'zh-Hans': '互参资料库（TSK）',
    'zh-Hant': '互參資料庫（TSK）',
    'en': 'Treasury of Scripture Knowledge (TSK) cross-references',
  },
  // ── Workbench: menu bar, toolbar, status bar ──
  'analysisPinned': {
    'zh-Hans': '已固定',
    'zh-Hant': '已固定',
    'en': 'Pinned',
  },
  'analysisUnpin': {
    'zh-Hans': '取消固定',
    'zh-Hant': '取消固定',
    'en': 'Unpin',
  },
  'analysisUnpinHint': {
    'zh-Hans': '取消固定 — 或按 Esc，或再点一次该词',
    'zh-Hant': '取消固定 — 或按 Esc，或再點一次該詞',
    'en': 'Release the pin — or press Esc, or click the word again',
  },
  'analysisFrozen': {
    'zh-Hans': '已冻结 — Shift',
    'zh-Hant': '已凍結 — Shift',
    'en': 'FROZEN — Shift',
  },
  'analysisMeaning': {
    'zh-Hans': '词义',
    'zh-Hant': '詞義',
    'en': 'Meaning',
  },
  'analysisOrigin': {
    'zh-Hans': '字源',
    'zh-Hant': '字源',
    'en': 'Origin',
  },
  'analysisDefinition': {
    'zh-Hans': '释义',
    'zh-Hant': '釋義',
    'en': 'Definition',
  },
  'analysisFullEntry': {
    'zh-Hans': '完整词条、同源词与经文汇编 →',
    'zh-Hant': '完整詞條、同源詞與經文彙編 →',
    'en': 'Full entry, word family & concordance →',
  },
  'analysisNoEntry': {
    'zh-Hans': '此编号没有词典条目。',
    'zh-Hant': '此編號沒有詞典條目。',
    'en': 'No lexicon entry for this number.',
  },
  'analysisNoParseGreek': {
    'zh-Hans': '无词形分析。希腊文词形取自 SBLGNT，本处经文的部分读法'
        '不见于该底本，故无可依据的分析。',
    'zh-Hant': '無詞形分析。希臘文詞形取自 SBLGNT，本處經文的部分讀法'
        '不見於該底本，故無可依據的分析。',
    'en': 'No parsing. Greek parsing comes from SBLGNT, which does not '
        'carry every reading of the text shown here.',
  },
  'analysisNoParseHebrew': {
    'zh-Hans': '无词形分析。希伯来文词形取自 Open Scriptures（WLC）。',
    'zh-Hant': '無詞形分析。希伯來文詞形取自 Open Scriptures（WLC）。',
    'en': 'No parsing. Hebrew parsing comes from the Open Scriptures '
        'Hebrew Bible (WLC).',
  },
  // ── References that carry no scripture of their own ──────────────
  // See lib/utils/verse_text_absence.dart. Shown in place of the verse
  // text, in the UI language — the sentence is the app explaining the
  // edition's convention, not the edition speaking.
  'verseMergedWith': {
    'zh-Hans': '与第 {v} 节合并印行',
    'zh-Hant': '與第 {v} 節合併印行',
    'en': 'Printed with verse {v}',
  },
  'verseMergedWithEarlier': {
    'zh-Hans': '与前面的经文合并印行',
    'zh-Hant': '與前面的經文合併印行',
    'en': 'Printed with an earlier verse',
  },
  'verseOmittedFromBaseText': {
    'zh-Hans': '此底本不收录本节',
    'zh-Hant': '此底本不收錄本節',
    'en': "Not in this edition's base text",
  },
  'verseTextMissing': {
    'zh-Hans': '本版本此处没有经文',
    'zh-Hant': '本版本此處沒有經文',
    'en': 'This edition has no text here',
  },
  'verseNotInCriticalText': {
    'zh-Hans': '不在多数现代译本依据的校勘本中',
    'zh-Hant': '不在多數現代譯本依據的校勘本中',
    'en': 'Not in the critical text most modern editions follow',
  },
  'verseNotInEdition': {
    'zh-Hans': '本版本没有这一节',
    'zh-Hant': '本版本沒有這一節',
    'en': 'This edition has no verse here',
  },
  'analysisAvUsage': {
    'zh-Hans': '钦定本译法',
    'zh-Hant': '欽定本譯法',
    'en': 'KJV renderings',
  },
  'analysisAvTotal': {
    'zh-Hans': '共 %d 次',
    'zh-Hant': '共 %d 次',
    'en': '%d occurrences',
  },
  'analysisSenses': {
    'zh-Hans': '词义（Thayer）',
    'zh-Hant': '詞義（Thayer）',
    'en': "Senses (Thayer's)",
  },
  'analysisNotes': {
    'zh-Hans': '按语',
    'zh-Hant': '按語',
    'en': 'Notes',
  },
  'analysisSynonyms': {
    'zh-Hans': '同义词条',
    'zh-Hant': '同義詞條',
    'en': 'Synonyms — see entry',
  },
  'analysisNameMeaning': {
    'zh-Hans': '名字含义',
    'zh-Hant': '名字含義',
    'en': 'Name means',
  },
  'analysisSourceThayer': {
    'zh-Hans': 'Thayer',
    'zh-Hant': 'Thayer',
    'en': "Thayer's",
  },
  'analysisSourceHitchcock': {
    'zh-Hans': 'Hitchcock',
    'zh-Hant': 'Hitchcock',
    'en': 'Hitchcock',
  },
  'analysisTdnt': {
    'zh-Hans': 'TDNT（基特尔）',
    'zh-Hant': 'TDNT（基特爾）',
    'en': 'TDNT (Kittel)',
  },
  'analysisNotUsed': {
    'zh-Hans': 'Thayer 未收录此编号。',
    'zh-Hant': 'Thayer 未收錄此編號。',
    'en': "Not treated in Thayer's.",
  },
  'parallelBrowseShort': {
    'zh-Hans': '对照',
    'zh-Hant': '對照',
    'en': 'Browse',
  },
  'classicReaderShort': {
    'zh-Hans': '阅读',
    'zh-Hant': '閱讀',
    'en': 'Reader',
  },
  'menuFile': {
    'zh-Hans': '文件',
    'zh-Hant': '檔案',
    'en': 'File',
  },
  'menuView': {
    'zh-Hans': '视图',
    'zh-Hant': '檢視',
    'en': 'View',
  },
  'menuTools': {
    'zh-Hans': '工具',
    'zh-Hant': '工具',
    'en': 'Tools',
  },
  'menuResources': {
    'zh-Hans': '资源',
    'zh-Hant': '資源',
    'en': 'Resources',
  },
  'menuHelp': {
    'zh-Hans': '帮助',
    'zh-Hant': '說明',
    'en': 'Help',
  },
  'menuClassicReader': {
    'zh-Hans': '退出到阅读器',
    'zh-Hant': '退出到閱讀器',
    'en': 'Exit to reader',
  },
  'menuSearchWindow': {
    'zh-Hans': '搜索窗口',
    'zh-Hant': '搜尋視窗',
    'en': 'Search window',
  },
  'menuAnalysisWindow': {
    'zh-Hans': '分析窗口',
    'zh-Hant': '分析視窗',
    'en': 'Analysis window',
  },
  'menuDarkMode': {
    'zh-Hans': '深色模式',
    'zh-Hant': '深色模式',
    'en': 'Dark mode',
  },
  'menuFocusCommandLine': {
    'zh-Hans': '命令行',
    'zh-Hant': '命令列',
    'en': 'Command line',
  },
  'menuClearResults': {
    'zh-Hans': '清除结果',
    'zh-Hant': '清除結果',
    'en': 'Clear results',
  },
  // The Browse window's inline-Strong's switch. 「原文编号」 is the term
  // yahwehdehua.net uses for these numbers, so a reader who knows that
  // site recognises the control here.
  'analysisLemma': {
    'zh-Hans': '原文',
    'zh-Hant': '原文',
    'en': 'Lemma',
  },
  'analysisUsage': {
    'zh-Hans': '钦定本译法',
    'zh-Hant': '欽定本譯法',
    'en': 'KJV usage',
  },
  'analysisSimplifiedOnly': {
    'zh-Hans': '此词典仅有简体版。',
    'zh-Hant': '此詞典僅發行簡體版，以下為簡體原文。',
    'en': 'This lexicon is published in Simplified Chinese only.',
  },
  'wbShowStrongs': {
    'zh-Hans': '显示原文编号',
    'zh-Hant': '顯示原文編號',
    'en': "Show Strong's numbers",
  },
  'wbHideStrongs': {
    'zh-Hans': '隐藏原文编号',
    'zh-Hant': '隱藏原文編號',
    'en': "Hide Strong's numbers",
  },
  'wbShowStrongsShort': {
    'zh-Hans': '编号',
    'zh-Hant': '編號',
    'en': 'G#',
  },
  'wbHideStrongsShort': {
    'zh-Hans': '编号',
    'zh-Hant': '編號',
    'en': 'G#',
  },
  'parallelPickVersions': {
    'zh-Hans': '选择版本…',
    'zh-Hant': '選擇版本…',
    'en': 'Choose versions…',
  },
  'timeline': {
    'zh-Hans': '时间线',
    'zh-Hant': '時間線',
    'en': 'Timeline',
  },
  'trivia': {
    'zh-Hans': '圣经知识',
    'zh-Hant': '聖經知識',
    'en': 'Trivia',
  },
  'books': {
    'zh-Hans': '跳转书卷…',
    'zh-Hant': '跳轉書卷…',
    'en': 'Go to book…',
  },
  'about': {
    'zh-Hans': '关于与数据来源',
    'zh-Hant': '關於與資料來源',
    'en': 'About & data sources',
  },
  // ── Workbench: Analysis window tabs ──
  'analysisTitle': {
    'zh-Hans': '分析',
    'zh-Hant': '分析',
    'en': 'Analysis',
  },
  'analysisTabCrossRefs': {
    'zh-Hans': '互参',
    'zh-Hant': '互參',
    'en': 'X-Refs',
  },
  'analysisTabStats': {
    'zh-Hans': '统计',
    'zh-Hant': '統計',
    'en': 'Stats',
  },
  'analysisNoCrossRefs': {
    'zh-Hans': '这节经文没有互参资料。',
    'zh-Hant': '這節經文沒有互參資料。',
    'en': 'No cross-references for this verse.',
  },
  'analysisNoStats': {
    'zh-Hans': '这节经文没有原文数据。',
    'zh-Hant': '這節經文沒有原文資料。',
    'en': 'No original-language data for this verse.',
  },
  'analysisStatsHint': {
    'zh-Hans': '全圣经出现次数，由少到多。',
    'zh-Hant': '全聖經出現次數，由少到多。',
    'en': 'Whole-Bible occurrences, rarest first.',
  },
  // The Forms readout — BibleWorks bwh10q. See
  // `widgets/word_forms_section.dart`.
  'formsAmbiguousLemma': {
    'zh-Hans': '这个字形在别处属于另一个字。',
    'zh-Hant': '這個字形在別處屬於另一個字。',
    'en': 'This form is also a different word elsewhere.',
  },
  'formsAmbiguousParse': {
    'zh-Hans': '这个字形在别处有别的解析。',
    'zh-Hant': '這個字形在別處有別的解析。',
    'en': 'This form is parsed more than one way elsewhere.',
  },
  'formsHeader': {
    'zh-Hans': '这个字的各种字形（{n} 种，共 {total} 次）',
    'zh-Hant': '這個字的各種字形（{n} 種，共 {total} 次）',
    'en': 'Forms of this word ({n}, {total}×)',
  },
  'formsSortBy': {
    'zh-Hans': '排序：',
    'zh-Hant': '排序：',
    'en': 'Sort:',
  },
  'formsSortFrequency': {
    'zh-Hans': '次数',
    'zh-Hant': '次數',
    'en': 'frequency',
  },
  'formsSortCode': {
    'zh-Hans': '解析',
    'zh-Hant': '解析',
    'en': 'parsing',
  },
  'formsSortAlpha': {
    'zh-Hans': '字母',
    'zh-Hant': '字母',
    'en': 'a–z',
  },
  'aboutLexCuvsTagged': {
    'zh-Hans': '和合本【雅伟】简体版＋［附原文编号］',
    'zh-Hant': '和合本【雅偉】簡體版＋［附原文編號］',
    'en': 'Chinese Union [YHWH] Version with Strong\'s numbers',
  },
  'aboutLicenseCuvsTagged': {
    'zh-Hans': '修订编辑：孙树民 · 经出版方许可使用（yahwehdehua.net）。',
    'zh-Hant': '修訂編輯：孫樹民 · 經出版方許可使用（yahwehdehua.net）。',
    'en': 'Revised by 孙树民 · used with permission (yahwehdehua.net).',
  },
  'aboutLexBdbThayer': {
    'zh-Hans': 'BDB（希伯来文）+ Thayer（希腊文）词典 中文版',
    'zh-Hant': 'BDB（希伯來文）+ Thayer（希臘文）詞典 中文版',
    'en': 'BDB (Hebrew) + Thayer (Greek) lexicons, Chinese edition',
  },
  'aboutLicenseBdbThayer': {
    'zh-Hans': 'Brown-Driver-Briggs（1906）与 Thayer（1889）原著属公有领域 · '
        '中文版经许可使用（yahwehdehua.net）。',
    'zh-Hant': 'Brown-Driver-Briggs（1906）與 Thayer（1889）原著屬公有領域 · '
        '中文版經許可使用（yahwehdehua.net）。',
    'en': 'Brown-Driver-Briggs (1906) & Thayer (1889) public domain · '
        'Chinese edition used with permission (yahwehdehua.net).',
  },
  'aboutLexMorphGnt': {
    'zh-Hans': '希腊文新约词形分析 — MorphGNT / SBLGNT',
    'zh-Hant': '希臘文新約詞形分析 — MorphGNT / SBLGNT',
    'en': 'Greek NT morphology — MorphGNT / SBLGNT',
  },
  'aboutLicenseMorphGnt': {
    'zh-Hans': 'CC BY-SA 3.0 · James Tauber 等。',
    'zh-Hant': 'CC BY-SA 3.0 · James Tauber 等。',
    'en': 'CC BY-SA 3.0 · James Tauber et al.',
  },
  'aboutLexOshb': {
    'zh-Hans': '希伯来文旧约词形分析 — Open Scriptures（WLC）',
    'zh-Hant': '希伯來文舊約詞形分析 — Open Scriptures（WLC）',
    'en': 'Hebrew OT morphology — Open Scriptures Hebrew Bible (WLC)',
  },
  'aboutLicenseOshb': {
    'zh-Hans': 'CC BY 4.0 · Open Scriptures。',
    'zh-Hant': 'CC BY 4.0 · Open Scriptures。',
    'en': 'CC BY 4.0 · Open Scriptures.',
  },
  // Task #300. The plate viewer prints one of these under every
  // illustration. `mapCreditUnknown` is not a fallback for a lookup that
  // failed — it is the recorded answer for 151 plates whose origin was
  // never written down, and saying nothing there would read exactly like
  // a public-domain plate that needs no credit.
  'mapCreditUnknown': {
    'zh-Hans': '来源未记录',
    'zh-Hant': '來源未記錄',
    'en': 'Source not recorded',
  },
  'mapCreditHeading': {
    'zh-Hans': '图片来源',
    'zh-Hant': '圖片來源',
    'en': 'Image source',
  },
  'aboutIllustrations': {
    'zh-Hans': '插图与地图（1,192 幅）',
    'zh-Hant': '插圖與地圖（1,192 幅）',
    'en': 'Illustrations and maps (1,192 plates)',
  },
  'aboutIllustrationsPd': {
    'zh-Hans': '公有领域 · 迪索、施诺尔、多雷、伦勃朗等（作者逝世逾百年）。',
    'zh-Hant': '公有領域 · 迪索、施諾爾、多雷、林布蘭等（作者逝世逾百年）。',
    'en': 'Public domain · Tissot, Schnorr, Doré, Rembrandt and others '
        '(artists dead over a century).',
  },
  'aboutIllustrationsSweet': {
    'zh-Hans': 'Sweet Publishing 插图（40 幅）',
    'zh-Hant': 'Sweet Publishing 插圖（40 幅）',
    'en': 'Sweet Publishing illustrations (40 plates)',
  },
  'aboutIllustrationsUnknown': {
    'zh-Hans': '来源未记录（151 幅）',
    'zh-Hant': '來源未記錄（151 幅）',
    'en': 'Source not recorded (151 plates)',
  },
  'aboutIllustrationsUnknownNote': {
    'zh-Hans': '经应用拥有者授权使用；原始出处未在收录时记录，因此不能声明其授权条款。',
    'zh-Hant': '經應用擁有者授權使用；原始出處未在收錄時記錄，因此不能聲明其授權條款。',
    'en': 'Used by permission of the app\'s owner; where they were '
        'originally obtained was not recorded, so no licence is claimed.',
  },
  'aboutLicenseTsk': {
    'zh-Hans': '公有领域（R.A. Torrey, 1834）· 与 OpenBible.info 社群投票数据合并（CC-BY）。'
        '共 29,319 条经文索引。',
    'zh-Hant': '公有領域（R.A. Torrey, 1834）· 與 OpenBible.info 社群投票資料合併（CC-BY）。'
        '共 29,319 條經文索引。',
    'en':
        'Public domain (R.A. Torrey, 1834) · merged with '
            'OpenBible.info community votes (CC-BY). 29,319 source '
            'verses indexed.',
  },
  // Other resources.
  // `aboutMaps` / `aboutLicenseMaps` were removed by #300. The second
  // read "Public domain / Creative Commons archives", which covered
  // three different legal situations — including 40 plates under a
  // licence that requires the author be named — with one reassuring
  // sentence. See the `aboutIllustrations*` keys above.
  // `{name}` is substituted by `withPreacher` from sermon_credit.dart —
  // the preacher is spelled in exactly one file, never in this one.
  'aboutSermons': {
    'zh-Hans': '{name}讲道（assets/sermons/）',
    'zh-Hant': '{name}講道（assets/sermons/）',
    'en': 'Sermons by {name} (assets/sermons/)',
  },
  // WHO PREACHED and WHO HOLDS THE RIGHTS are two different facts, and
  // only the first is settled. The sermons are Pastor Eric H.H. Chang's —
  // `scripts/ingest_sermons.py` built the corpus from his sermon tree and
  // every body file is his preaching. This © line names 梁家铿, who is the
  // translator of the biblexg edition, and it has been here since the
  // initial commit with no note explaining the connection. He may well be
  // the publisher who granted permission, which would make both lines
  // correct — but nothing in the repo establishes that. Left as-is rather
  // than rewritten: deleting a rights claim on a guess is worse than
  // carrying an unverified one, and the byline above now states the
  // authorship fact that was missing either way. Needs a human to confirm
  // with the corpus owner.
  'aboutLicenseSermons': {
    'zh-Hans': '© 梁家铿 · 经授权使用。',
    'zh-Hant': '© 梁家鏗 · 經授權使用。',
    'en': '© Liang Jia-keng · used with permission.',
  },
  'aboutFontsBundled': {
    'zh-Hans': '内置字体：Roboto',
    'zh-Hant': '內置字體：Roboto',
    'en': 'Bundled font: Roboto',
  },
  'aboutLicenseRoboto': {
    'zh-Hans': 'Apache 2.0 · Google。',
    'zh-Hant': 'Apache 2.0 · Google。',
    'en': 'Apache 2.0 · Google.',
  },
  'aboutFontsCjk': {
    'zh-Hans': '内置字体：Noto Sans SC（子集）',
    'zh-Hant': '內置字體：Noto Sans SC（子集）',
    'en': 'Bundled font: Noto Sans SC (subset)',
  },
  'aboutLicenseOfl': {
    'zh-Hans': 'SIL OFL · 随应用打包，无需联网下载。',
    'zh-Hant': 'SIL OFL · 隨應用打包，無需連網下載。',
    'en': 'SIL OFL · shipped with the app, not downloaded.',
  },
  'aboutFontsScripts': {
    'zh-Hans': '内置字体：Noto Sans Hebrew / Noto Sans / Noto Sans Symbols 2（子集）',
    'zh-Hant': '內置字體：Noto Sans Hebrew / Noto Sans / Noto Sans Symbols 2（子集）',
    'en': 'Bundled fonts: Noto Sans Hebrew / Noto Sans / Noto Sans Symbols 2 (subsets)',
  },
  'aboutAi': {
    'zh-Hans': 'SeekSparks AI 经文释义（仅供参考）',
    'zh-Hant': 'SeekSparks AI 經文釋義（僅供參考）',
    'en': 'SeekSparks AI explanations (reference only)',
  },
  'aboutLicenseAi': {
    'zh-Hans': 'Google Gemini API · 输出可在 API 条款下重新分发。',
    'zh-Hant': 'Google Gemini API · 輸出可在 API 條款下重新分發。',
    'en':
        'Google Gemini API · output redistribution permitted under API terms.',
  },
  'aboutTrivia': {
    'zh-Hans': '冷知识文本与图示',
    'zh-Hant': '冷知識文本與圖示',
    'en': 'Trivia text + diagrams',
  },
  'aboutLicenseOriginal': {
    'zh-Hans': '本应用原创内容 · MIT（与应用代码同许可）。',
    'zh-Hant': '本應用原創內容 · MIT（與應用程式碼同授權）。',
    'en':
        'Original to this app · MIT (same as application code).',
  },
  'aboutAppLicenseHeading': {
    'zh-Hans': '应用代码：MIT 许可证',
    'zh-Hant': '應用程式碼：MIT 授權',
    'en': 'Application code: MIT licence',
  },
  'aboutAppLicenseBody': {
    'zh-Hans': '本仓库内的 Dart / Flutter 源代码（lib/ 目录及构建配置）以 MIT 许可证开源。'
        '内置的第三方资源不在此 MIT 许可范围内——见上方各表格。',
    'zh-Hant': '本倉庫內的 Dart / Flutter 原始碼（lib/ 目錄及建構設定）以 MIT 授權開源。'
        '內置的第三方資源不在此 MIT 授權範圍內——見上方各表格。',
    'en':
        'The Dart / Flutter source code in this repository (under '
            '`lib/` and the build configuration) is open source under '
            'the MIT licence. Bundled third-party resources are NOT '
            'covered by MIT — see the tables above for each item.',
  },
  'aboutOpenRepo': {
    'zh-Hans': '在 GitHub 查看源代码',
    'zh-Hant': '在 GitHub 查看原始碼',
    'en': 'View source on GitHub',
  },
  // 2026-05-10 (v1.2.20): the date used to be hardcoded in this
  // string ("2026-05-07") and stale-drifted across multiple
  // releases — user noticed at v1.2.19. Now uses a placeholder
  // that the AboutPage footer interpolates with `kAppReleaseTime`
  // from `lib/constants/app_version.dart`. Bumping
  // kAppReleaseTime alongside kAppVersion is the canonical place
  // to keep the footer accurate.
  // 2026-05-10 (v1.2.24): placeholder upgraded `{date}` → `{time}`
  // when kAppReleaseDate became kAppReleaseTime (date+H:M+tz)
  // so back-to-back same-day releases stamp distinct moments.
  'aboutFooterNote': {
    'zh-Hans': '本页最后更新于 {time}。',
    'zh-Hant': '本頁最後更新於 {time}。',
    'en': 'Last updated {time}.',
  },
  // 2026-08 (ported from YsWords v1.3.171/172): Home footer version line.
  'homeFooterUpdated': {
    'zh-Hans': '更新于 {time}',
    'zh-Hant': '更新於 {time}',
    'en': 'Updated {time}',
  },
  'refresh': {
    'zh-Hans': '刷新',
    'zh-Hant': '重新整理',
    'en': 'Refresh',
  },
  // ── Gospel synopsis (Round 27B) ─────────────────────────────────
  'synopsis': {
    'zh-Hans': '福音书对观',
    'zh-Hant': '福音書對觀',
    'en': 'Gospel Synopsis',
  },
  'synopsisOt': {
    'zh-Hans': '平行经文',
    'zh-Hant': '平行經文',
    'en': 'Parallel Passages',
  },
  'synopsisChapterTitle': {
    'zh-Hans': '本章对观条目',
    'zh-Hant': '本章對觀條目',
    'en': 'Parallel passages in this chapter',
  },
  'synopsisNone': {
    'zh-Hans': '本章暂无对观条目。',
    'zh-Hant': '本章暫無對觀條目。',
    'en': 'No parallel passages curated for this chapter.',
  },
  'synopsisOnlyHere': {
    'zh-Hans': '仅记于本福音书',
    'zh-Hant': '僅記於本福音書',
    'en': 'Only in this Gospel',
  },
  // ── Strong's # direct lookup (Round 27C) ─────────────────────────
  'strongsDerivation': {
    'zh-Hans': '词源',
    'zh-Hant': '詞源',
    'en': 'Derivation',
  },
  'strongsFamily': {
    'zh-Hans': '同根词',
    'zh-Hant': '同根詞',
    'en': 'Word family',
  },
  'strongsCompare': {
    'zh-Hans': '相关词',
    'zh-Hant': '相關詞',
    'en': 'Compare',
  },
  'strongsOccurrences': {
    'zh-Hans': '出处',
    'zh-Hant': '出處',
    'en': 'Occurrences',
  },
  // v1.3.90: shown when a Strong's occurrence is tapped but the verse
  // isn't present in the user's currently-loaded Bible version (e.g. a
  // NT Greek word while reading an OT-only version).
  'strongsRefNotInVersion': {
    'zh-Hans': '当前译本中没有这节经文。',
    'zh-Hant': '目前譯本中沒有這節經文。',
    'en': 'This verse isn\'t in your current Bible version.',
  },
  // 2026-05-24 (v1.3.19): all `tts*` keys removed with the 朗读
  // feature. Were: ttsListen, ttsStop, ttsVoiceTitle, ttsVoiceBody,
  // ttsVoiceGender, ttsVoiceGenderFemale/Male, ttsVoiceTier,
  // ttsVoiceTierNeural/Standard, ttsCacheSize/Clear/Cleared.
  // ── Keyboard shortcuts (Round 27E) ──────────────────────────────
  'shortcutsHelp': {
    'zh-Hans': '键盘快捷键',
    'zh-Hant': '鍵盤快捷鍵',
    'en': 'Keyboard shortcuts',
  },
  // ── Profiles / sign-in (Round 28) ──────────────────────────────
  // 2026-08-08 (v1.6.62 — one worldwide build): replaces the old
  // three-way cloud notice. There is no sign-in and no server, so
  // the only honest thing to say is where the data is and how to
  // move it. Naming the export card matters — an "it's local"
  // notice that stops there reads as a dead end.
  'localOnlyDataNotice': {
    'zh-Hans': '高亮、笔记、书签都只保存在这台设备上。要换设备，请用下方的「导出我的数据」。',
    'zh-Hant': '螢光標記、筆記、書籤都只儲存在這台裝置上。要換裝置，請用下方的「匯出我的資料」。',
    'en':
        'Highlights, notes and bookmarks stay on this device. '
            'Use "Export my data" below to move them to another one.',
  },
  'welcomeLocalOnlyNotice': {
    'zh-Hans': '账号仅保存在本设备，不需要密码、不上传服务器。',
    'zh-Hant': '帳號僅保存在本裝置，不需要密碼、不上傳伺服器。',
    'en':
        'Profiles are stored only on this device. No password, no server.',
  },
  'welcomeNameHint': {
    'zh-Hans': '您的姓名',
    'zh-Hant': '您的姓名',
    'en': 'Your name',
  },
  'profileTitle': {
    'zh-Hans': '账号',
    'zh-Hant': '帳號',
    'en': 'Profiles',
  },
  'profileCurrent': {
    'zh-Hans': '当前账号',
    'zh-Hant': '目前帳號',
    'en': 'Active profile',
  },
  'profileSwitchOrAdd': {
    'zh-Hans': '切换或新增账号',
    'zh-Hant': '切換或新增帳號',
    'en': 'Switch or add a profile',
  },
  'profileSwitch': {
    'zh-Hans': '切换到此账号',
    'zh-Hant': '切換到此帳號',
    'en': 'Switch to this profile',
  },
  'profileRename': {
    'zh-Hans': '重命名',
    'zh-Hant': '重新命名',
    'en': 'Rename',
  },
  'profileDelete': {
    'zh-Hans': '删除',
    'zh-Hant': '刪除',
    'en': 'Delete',
  },
  'profileDeleteConfirm': {
    'zh-Hans': '确定要删除「{name}」及其在本设备上的所有笔记、书签、高亮与读经进度吗？',
    'zh-Hant': '確定要刪除「{name}」及其在本裝置上的所有筆記、書籤、高亮與讀經進度嗎？',
    'en':
        'Permanently delete "{name}" and all its notes, bookmarks, highlights and reading-plan progress on this device?',
  },
  'profileCreateTitle': {
    'zh-Hans': '新建账号',
    'zh-Hant': '新建帳號',
    'en': 'Create profile',
  },
  'profileGuestSub': {
    'zh-Hans': '默认账号 — 任何使用本浏览器的人',
    'zh-Hant': '預設帳號 — 任何使用本瀏覽器的人',
    'en': 'Default — anyone using this browser',
  },
  'profileLocalOnly': {
    'zh-Hans': '本地账号',
    'zh-Hant': '本地帳號',
    'en': 'Local profile',
  },
  'cancel': {
    'zh-Hans': '取消',
    'zh-Hant': '取消',
    'en': 'Cancel',
  },
  'cloudSignIn': {
    'zh-Hans': '登录以在多设备同步',
    'zh-Hant': '登入以在多裝置同步',
    'en': 'Sign in to sync across devices',
  },
  'clearCache': {
    'zh-Hans': '清除缓存并重新加载',
    'zh-Hant': '清除快取並重新載入',
    'en': 'Clear cache & reload',
  },
  'clearCacheTitle': {
    'zh-Hans': '清除缓存并重新加载？',
    'zh-Hant': '清除快取並重新載入？',
    'en': 'Clear cache & reload?',
  },
  'clearCacheBody': {
    'zh-Hans': '此操作将注销 Service Worker、删除浏览器缓存并重新加载应用。'
        '您的标记、笔记和书签存储在别处，不会被清除。',
    'zh-Hant': '此操作會註銷 Service Worker、刪除瀏覽器快取並重新載入應用程式。'
        '您的標記、筆記與書籤儲存在他處，不會被清除。',
    'en': 'This will unregister the service worker, delete browser '
        'caches, and reload the app. Your highlights, notes and '
        'bookmarks are stored separately and will not be cleared.',
  },
  'clearCacheNote': {
    'zh-Hans': '清除浏览器缓存与 Service Worker。您的资料（标记、笔记、书签）会保留。',
    'zh-Hant': '清除瀏覽器快取與 Service Worker。您的資料（標記、筆記、書籤）會保留。',
    'en': 'Wipes browser cache + service workers. Your profile data '
        '(highlights, notes, bookmarks) stays put.',
  },
  'showSectionTitles': {
    'zh-Hans': '段落标题',
    'zh-Hant': '段落標題',
    'en': 'Section titles',
  },
  'showSectionTitlesSubtitle': {
    'zh-Hans': '在相应经文上方显示段落主题（如「登山宝训」、「耶稣家谱」等）。',
    'zh-Hant': '在相應經文上方顯示段落主題（如「登山寶訓」、「耶穌家譜」等）。',
    'en': 'Render paragraph headings (e.g. "The Sermon on the Mount") '
        'above the matched verse in the reading pane.',
  },
  'showBookIntro': {
    'zh-Hans': '书卷简介',
    'zh-Hant': '書卷簡介',
    'en': 'Book introductions',
  },
  'showBookIntroSubtitle': {
    'zh-Hans': '在每卷书第一章顶部显示作者、年代、主题与关键经文等背景介绍。',
    'zh-Hant': '在每卷書第一章頂部顯示作者、年代、主題與關鍵經文等背景介紹。',
    'en': 'Show a collapsible card at the top of chapter 1 with the '
        'book\'s author, date, audience, themes, and key passage.',
  },
  // 2026-05-19 (v1.2.55): the v1.2.53 cross-version LEB overlay
  // ui-strings were removed. LEB's own inline notes render via
  // the normal `<note:>` book-icon path; biblexg-v2's notes do
  // the same. No cross-version overlay ui-strings needed.
  'aboutThisBook': {
    'zh-Hans': '关于此卷书',
    'zh-Hant': '關於此卷書',
    'en': 'About this book',
  },
  'sectionContextTooltip': {
    'zh-Hans': '背景说明',
    'zh-Hant': '背景說明',
    'en': 'Background',
  },
  'readMore': {
    'zh-Hans': '展开',
    'zh-Hant': '展開',
    'en': 'Read more',
  },
  'showLess': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Show less',
  },
  'authorLabel': {
    'zh-Hans': '作者',
    'zh-Hant': '作者',
    'en': 'Author',
  },
  'dateLabel': {
    'zh-Hans': '成书年代',
    'zh-Hant': '成書年代',
    'en': 'Date',
  },
  'audienceLabel': {
    'zh-Hans': '原始读者',
    'zh-Hant': '原始讀者',
    'en': 'Audience',
  },
  'themesLabel': {
    'zh-Hans': '主题',
    'zh-Hant': '主題',
    'en': 'Themes',
  },
  'keyPassageLabel': {
    'zh-Hans': '关键经文',
    'zh-Hant': '關鍵經文',
    'en': 'Key passage',
  },
  'crossRefsNone': {
    'zh-Hans': '此节经文暂无人工整理的相互参照。',
    'zh-Hant': '此節經文暫無人工整理的相互參照。',
    'en': 'No curated cross-references for this verse yet.',
  },
  // 2026-08 (ported from YsWords v1.3.156): 护眼纸质阅读主题 — warm
  // sepia background for the Bible reading pane, independent of the
  // app-wide light/dark theme.
  'readingPaperTheme': {
    'zh-Hans': '护眼纸质背景',
    'zh-Hant': '護眼紙質背景',
    'en': 'Paper reading theme',
  },
  'readingPaperThemeSubtitle': {
    'zh-Hans': '阅经页面改用暖色纸质背景与更柔和的配色，长时间阅读更舒适。',
    'zh-Hant': '閱經頁面改用暖色紙質背景與更柔和的配色，長時間閱讀更舒適。',
    'en':
        'Switch the reading pane to a warm, paper-like background for more '
            'comfortable long reading sessions.',
  },
  'boldVerseText': {
    'zh-Hans': '加粗经文',
    'zh-Hant': '加粗經文',
    'en': 'Bold verse text',
  },
  'boldVerseTextSubtitle': {
    'zh-Hans': '将经文正文以半粗体呈现。',
    'zh-Hant': '將經文正文以半粗體呈現。',
    'en': 'Render scripture body text in semi-bold weight.',
  },
  'showStrongsBadge': {
    'zh-Hans': '在词卡显示 Strong\'s 号',
    'zh-Hant': '在詞卡顯示 Strong\'s 號',
    'en': "Show Strong's number on word chips",
  },
  'showStrongsBadgeSubtitle': {
    'zh-Hans': '在释经面板每个希伯来/希腊词卡下方显示 G####/H#### 徽标。',
    'zh-Hant': '在釋經面板每個希伯來/希臘詞卡下方顯示 G####/H#### 徽標。',
    'en': "Display the G#### / H#### badge under each Hebrew/Greek word in the exegesis sheet.",
  },
  'autoExpandFirstRef': {
    'zh-Hans': '自动展开首个经文分组',
    'zh-Hant': '自動展開首個經文分組',
    'en': 'Auto-expand first verse group',
  },
  'autoExpandFirstRefSubtitle': {
    'zh-Hans': '在释经面板自动打开第一处经文分组,免去一次点击。',
    'zh-Hant': '在釋經面板自動打開第一處經文分組,免去一次點擊。',
    'en': "Automatically open the first book group of concordance refs in the exegesis sheet.",
  },
  'zoomIn': {'zh-Hans': '放大', 'zh-Hant': '放大', 'en': 'Zoom in'},
  'zoomOut': {'zh-Hans': '缩小', 'zh-Hant': '縮小', 'en': 'Zoom out'},
  'zoomReset': {'zh-Hans': '重置', 'zh-Hant': '重置', 'en': 'Reset zoom'},
  'summary': {'zh-Hans': '汇总', 'zh-Hant': '匯總', 'en': 'Summary'},
  'statWords': {'zh-Hans': '词数', 'zh-Hant': '詞數', 'en': 'Words'},
  'statTotal': {
    'zh-Hans': '总出现次数',
    'zh-Hant': '總出現次數',
    'en': 'Total occurrences',
  },
  'statTopBook': {
    'zh-Hans': '出现最多的书卷',
    'zh-Hant': '出現最多的書卷',
    'en': 'Most frequent book',
  },
  'statCanon': {'zh-Hans': '正典', 'zh-Hant': '正典', 'en': 'Canon'},
  'colStrongs': {
    'zh-Hans': '编号',
    'zh-Hant': '編號',
    'en': "Strong's",
  },
  'bothTestaments': {
    'zh-Hans': '新旧约对照',
    'zh-Hant': '新舊約對照',
    'en': 'Both Testaments',
  },
  'colTotal': {
    'zh-Hans': '总',
    'zh-Hant': '總',
    'en': 'Total',
  },
  'colGospelsActs': {
    'zh-Hans': '福音+徒',
    'zh-Hant': '福音+徒',
    'en': 'G&A',
  },
  'colPauline': {
    'zh-Hans': '保罗',
    'zh-Hant': '保羅',
    'en': 'Paul',
  },
  'colJohannine': {
    'zh-Hans': '约翰',
    'zh-Hant': '約翰',
    'en': 'John',
  },
  'colOtherApostolic': {
    'zh-Hans': '其他',
    'zh-Hant': '其他',
    'en': 'Other',
  },
  'colPentateuch': {
    'zh-Hans': '律法',
    'zh-Hant': '律法',
    'en': 'Torah',
  },
  'colHistory': {
    'zh-Hans': '历史',
    'zh-Hant': '歷史',
    'en': 'Hist.',
  },
  'colWisdom': {
    'zh-Hans': '智慧',
    'zh-Hant': '智慧',
    'en': 'Wisd.',
  },
  'colMajorProphets': {
    'zh-Hans': '大先知',
    'zh-Hant': '大先知',
    'en': 'Maj.Pr.',
  },
  'colMinorProphets': {
    'zh-Hans': '小先知',
    'zh-Hant': '小先知',
    'en': 'Min.Pr.',
  },
  'lxxEquivalents': {
    'zh-Hans': '七十士译本对应',
    'zh-Hant': '七十士譯本對應',
    'en': 'LXX Equivalents',
  },
  'hebrewSources': {
    'zh-Hans': '希伯来源词',
    'zh-Hant': '希伯來源詞',
    'en': 'Hebrew Sources',
  },
  'fullStudy': {
    'zh-Hans': '完整研经',
    'zh-Hant': '完整研經',
    'en': 'Full study',
  },
  'moreRefs': {
    'zh-Hans': '处更多',
    'zh-Hant': '處更多',
    'en': 'more',
  },
  'collapse': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Collapse',
  },
  'wordFamily': {
    'zh-Hans': '同源词',
    'zh-Hant': '同源詞',
    'en': 'Word Family',
  },
  'synonyms': {
    'zh-Hans': '同义词',
    'zh-Hant': '同義詞',
    'en': 'Synonyms',
  },
  'concordanceBookCount': {
    'zh-Hans': '出现 {count} 次',
    'zh-Hant': '出現 {count} 次',
    'en': '{count} occurrences',
  },
  'concordanceNoMatchInVersion': {
    'zh-Hans': '此版本未找到该经节',
    'zh-Hant': '此版本未找到該經節',
    'en': 'This verse is not available in the current version',
  },
  'removeHighlight': {
    'zh-Hans': '移除高亮',
    'zh-Hant': '移除高亮',
    'en': 'Remove highlight',
  },
  'highlightColor': {
    'zh-Hans': '高亮颜色',
    'zh-Hant': '高亮顏色',
    'en': 'Highlight color',
  },
  'menuScale': {
    'zh-Hans': '菜单大小',
    'zh-Hant': '選單大小',
    'en': 'Menu Size',
  },
  'listView': {
    'zh-Hans': '列表',
    'zh-Hant': '列表',
    'en': 'List',
  },
  'gridView': {
    'zh-Hans': '网格',
    'zh-Hant': '網格',
    'en': 'Grid',
  },

  // ====== Settings Page ======
  'themeMode': {
    'zh-Hans': '主题模式',
    'zh-Hant': '主題模式',
    'en': 'Theme Mode',
  },
  'themeDay': {
    'zh-Hans': '白天模式',
    'zh-Hant': '白天模式',
    'en': 'Light Mode',
  },
  'themeNight': {
    'zh-Hans': '夜间模式',
    'zh-Hant': '夜間模式',
    'en': 'Dark Mode',
  },
  'themeSystem': {
    'zh-Hans': '跟随系统',
    'zh-Hant': '跟隨系統',
    'en': 'System Default',
  },
  'themeLight': {
    'zh-Hans': '亮色模式',
    'zh-Hant': '亮色模式',
    'en': 'Light Mode',
  },
  'themeDark': {
    'zh-Hans': '暗色模式',
    'zh-Hant': '暗色模式',
    'en': 'Dark Mode',
  },
  'settings': {
    'zh-Hans': '设置',
    'zh-Hant': '設定',
    'en': 'Settings',
  },
  // 2026-05-07 (v12): feedback page -- mailto-driven user feedback
  // form. Strings used by the dashboard tile, the page chrome, and
  // the form fields / hints / outcomes.
  'feedback': {
    'zh-Hans': '意见反馈',
    'zh-Hant': '意見回饋',
    'en': 'Feedback',
  },
  'feedbackIntro': {
    'zh-Hans': '点击「发送」即可直接寄到开发者的邮箱。'
        '如果服务暂时不可用，会自动打开您的邮件应用作为备用。',
    'zh-Hant': '點擊「發送」即可直接寄到開發者的信箱。'
        '如果服務暫時不可用，會自動開啟您的郵件應用作為備用。',
    'en':
        'Tap "Send" and your feedback goes straight to the developer\'s '
            'inbox. If the service is temporarily unavailable, your mail '
            'app opens as a fallback.',
  },
  'feedbackCategoryLabel': {
    'zh-Hans': '反馈类别',
    'zh-Hant': '回饋類別',
    'en': 'What is this about?',
  },
  'feedbackCategoryBug': {
    'zh-Hans': 'Bug 报告',
    'zh-Hant': 'Bug 回報',
    'en': 'Bug report',
  },
  'feedbackCategoryFeature': {
    'zh-Hans': '功能建议',
    'zh-Hant': '功能建議',
    'en': 'Feature request',
  },
  'feedbackCategoryGeneral': {
    'zh-Hans': '一般反馈',
    'zh-Hant': '一般回饋',
    'en': 'General feedback',
  },
  'feedbackCategoryContent': {
    'zh-Hans': '内容/翻译问题',
    'zh-Hant': '內容/翻譯問題',
    'en': 'Content / translation',
  },
  'feedbackMessageLabel': {
    'zh-Hans': '反馈内容 *',
    'zh-Hant': '回饋內容 *',
    'en': 'Your message *',
  },
  'feedbackMessageHint': {
    'zh-Hans': '请描述您遇到的问题、想要的功能或想分享的想法。',
    'zh-Hant': '請描述您遇到的問題、想要的功能或想分享的想法。',
    'en': 'Describe the bug, feature, or thought.',
  },
  'feedbackMessageRequired': {
    'zh-Hans': '请先填写反馈内容再发送。',
    'zh-Hant': '請先填寫回饋內容再發送。',
    'en': 'Please write a message before sending.',
  },
  'feedbackNameLabel': {
    'zh-Hans': '您的名字（选填）',
    'zh-Hant': '您的名字（選填）',
    'en': 'Your name (optional)',
  },
  // 2026-05-07 (v16): single optional reply-to field (replaces the
  // v15 "send me a copy" UI, which depended on Resend domain
  // verification that the user opted out of). Pre-filled with the
  // signed-in email; guests start blank.
  'feedbackReplyToLabel': {
    'zh-Hans': '回复邮箱（选填）',
    'zh-Hant': '回覆信箱（選填）',
    'en': 'Reply-to email (optional)',
  },
  'feedbackSend': {
    'zh-Hans': '发送',
    'zh-Hant': '發送',
    'en': 'Send',
  },
  'feedbackSending': {
    'zh-Hans': '正在发送…',
    'zh-Hant': '正在發送…',
    'en': 'Sending…',
  },
  'feedbackSent': {
    'zh-Hans': '反馈已发送，谢谢您！',
    'zh-Hant': '回饋已發送，謝謝您！',
    'en': 'Feedback sent. Thank you!',
  },
  'feedbackErrorPrefix': {
    'zh-Hans': '发送失败：',
    'zh-Hant': '發送失敗：',
    'en': 'Could not send feedback: ',
  },
  'feedbackOpenedMail': {
    'zh-Hans': '已打开邮件应用，请点击发送即可送达。',
    'zh-Hant': '已開啟郵件應用，請點擊發送即可送達。',
    'en': 'Mail app opened. Tap Send to deliver your feedback.',
  },
  'feedbackCopiedFallback': {
    'zh-Hans': '邮件应用不可用，反馈已复制到剪贴板。'
        '请粘贴到您的邮件中发到 paulsyliu@gmail.com。',
    'zh-Hant': '郵件應用不可用，回饋已複製到剪貼簿。'
        '請貼到您的郵件中發到 paulsyliu@gmail.com。',
    'en':
        'Mail app unavailable — feedback copied to clipboard. '
            'Paste it into your email to paulsyliu@gmail.com.',
  },
  'feedbackPrivacyNote': {
    'zh-Hans': '为方便排查问题，发送时会一并附上：界面语言、圣经版本、'
        '当前阅读位置、屏幕尺寸与主题、时区与提交时间、'
        '浏览器与系统信息（IP 由服务器自动记录）。'
        '只用于回复您和定位问题，不会用于其他用途。',
    'zh-Hant': '為方便排查問題，發送時會一併附上：介面語言、聖經版本、'
        '當前閱讀位置、螢幕尺寸與主題、時區與提交時間、'
        '瀏覽器與系統資訊（IP 由伺服器自動記錄）。'
        '只用於回覆您和定位問題，不會用於其他用途。',
    'en':
        'To help debug your report, the submission also includes: '
            'app locale, Bible version, last position, screen size + '
            'theme, timezone + timestamp, browser + OS (IP is logged '
            'server-side). Used only to reply and reproduce — nothing '
            'else.',
  },
  'interfaceLanguage': {
    'zh-Hans': '界面语言',
    'zh-Hant': '介面語言',
    'en': 'Interface Language',
  },
  'fontSize': {
    'zh-Hans': '字体大小',
    'zh-Hant': '字體大小',
    'en': 'Font Size',
  },
  'lineSpacing': {
    'zh-Hans': '行距',
    'zh-Hant': '行距',
    'en': 'Line Spacing',
  },
  'fontFamily': {
    'zh-Hans': '字体',
    'zh-Hant': '字體',
    'en': 'Font Family',
  },
  'primaryColor': {
    'zh-Hans': '主色调',
    'zh-Hant': '主色調',
    'en': 'Primary Colour',
  },
  'samplePreview': {
    'zh-Hans': '预览示范',
    'zh-Hant': '預覽示範',
    'en': 'Sample Preview',
  },
  'copyFormat': {
    'zh-Hans': '复制格式',
    'zh-Hant': '複製格式',
    'en': 'Copy Format',
  },
  'plainText': {
    'zh-Hans': '纯文字',
    'zh-Hant': '純文字',
    'en': 'Plain Text',
  },
  'withReference': {
    'zh-Hans': '包含经文参考',
    'zh-Hant': '包含經文參考',
    'en': 'Include Reference',
  },
  'devotionalFormat': {
    'zh-Hans': '灵修格式',
    'zh-Hant': '靈修格式',
    'en': 'Devotional Format',
  },
  'copyPreview': {
    'zh-Hans': '复制预览',
    'zh-Hant': '複製預覽',
    'en': 'Copy Preview',
  },
  'copied': {
    'zh-Hans': '已复制！',
    'zh-Hant': '已複製！',
    'en': 'Copied!',
  },
  'sendFeedback': {
    'zh-Hans': '发送反馈',
    'zh-Hant': '發送反饋',
    'en': 'Send Feedback',
  },
  'feedbackHint': {
    'zh-Hans': '请输入您的意见或建议（最多500字）...',
    'zh-Hant': '請輸入您的意見或建議（最多500字）...',
    'en': 'Please enter your feedback (up to 500 characters)...',
  },
  'feedbackSuccess': {
    'zh-Hans': '✅ 已成功发送，谢谢反馈！',
    'zh-Hant': '✅ 發送成功，感謝您的反饋！',
    'en': '✅ Feedback sent. Thank you!',
  },
  'feedbackFailure': {
    'zh-Hans': '❌ 发送失败，请稍后重试。',
    'zh-Hant': '❌ 發送失敗，請稍後重試。',
    'en': '❌ Failed to send. Please try again.',
  },
  'ok': {
    'zh-Hans': '确定',
    'zh-Hant': '確定',
    'en': 'OK',
  },

  'feedbackEmpty': {
    'zh-Hans': '❗️发送内容不能为空，请输入反馈内容。',
    'zh-Hant': '❗️發送內容不能為空，請輸入反饋內容。',
    'en': '❗️Feedback content cannot be empty. Please enter your feedback.',
  },
  'feedbackTooLong': {
    'zh-Hans': '❗️内容超过最大长度（500字），请删减后再发送。',
    'zh-Hant': '❗️內容超過最大長度（500字），請刪減後再發送。',
    'en':
        '❗️Content exceeds the maximum length (500 characters). Please shorten it before sending.',
  },
  'feedbackInvalid': {
    'zh-Hans': '❗️内容包含不支持的符号（如表情符号），请移除后再发送。',
    'zh-Hant': '❗️內容包含不支援的符號（如表情符號），請移除後再發送。',
    'en':
        '❗️Content contains unsupported symbols (such as emojis). Please remove them before sending.',
  },
  'note': {
    'zh-Hans': '注释',
    'zh-Hant': '註釋',
    'en': 'Note',
  },
  'close': {
    'zh-Hans': '关闭',
    'zh-Hant': '關閉',
    'en': 'Close',
  },
  'copiedVerse': {
    'zh-Hans': '已复制第{verse}节',
    'zh-Hant': '已複製第{verse}節',
    'en': 'Copied verse {verse}',
  },
  'noVersesAvailable': {
    'zh-Hans': '暂无经文',
    'zh-Hant': '暫無經文',
    'en': 'No verses available',
  },
  'chapterUnavailable': {
    'zh-Hans': '当前版本没有这一章。',
    'zh-Hant': '目前版本沒有這一章。',
    'en': 'This chapter is not available in the current version.',
  },
  // The same message with the chapter NAMED. The reader arrived here by
  // navigating somewhere specific, so which reference the current
  // edition is missing is the whole content of the screen. `{book}` is
  // filled by `localeAwareBookName`, so it follows the READING VERSION's
  // script rather than the UI locale (task #283).
  'chapterUnavailableAt': {
    'zh-Hans': '当前版本没有{book} {n} 章。',
    'zh-Hant': '目前版本沒有{book} {n} 章。',
    'en': '{book} {n} is not available in the current version.',
  },
  // Names the edition to switch to by the badge the app actually prints
  // in the gutter (`雅简+`), never by an internal code. Used only when
  // the catalog can prove a same-language full-canon sibling exists;
  // otherwise `chapterSwitchAny` claims nothing it cannot back up.
  'chapterSwitchTo': {
    'zh-Hans': '请切换到 {version}。',
    'zh-Hant': '請切換到 {version}。',
    'en': 'Switch to {version}.',
  },
  'chapterSwitchAny': {
    'zh-Hans': '请切换到包含此章节的版本。',
    'zh-Hant': '請切換到包含此章節的版本。',
    'en': 'Switch to a version that includes it.',
  },
  // 2026-08-09 (#298): replaces 'endOfBible'. The chapter pager cannot
  // scroll past its own last page, so the placeholder it printed
  // "End of Bible" into was never a canon edge — it was the reader's
  // book list and its verse list disagreeing, and calling that the end
  // of the Bible on Genesis 1 is what kept a dead pane looking normal.
  'chapterTextNotLoaded': {
    'zh-Hans': '本章经文未能载入。请重新载入页面再试。',
    'zh-Hant': '本章經文未能載入。請重新載入頁面再試。',
    'en': 'This chapter’s text did not load. Reload the page and try again.',
  },
  'loadErrorTitle': {
    'zh-Hans': '加载失败',
    'zh-Hant': '載入失敗',
    'en': 'Failed to load',
  },
  // 2026-08-08: shown once when boot opened a DIFFERENT edition from the
  // one asked for, because the requested one has been retired from the
  // catalog. The raw code is quoted rather than a friendly name on
  // purpose — there is no catalog row left to take a name from, and the
  // code is the part the reader can actually see, in their own bookmark
  // or shared link.
  'retiredVersionNotice': {
    'zh-Hans': '所请求的版本（{code}）已不再提供，现显示《{version}》。',
    'zh-Hant': '所請求的版本（{code}）已不再提供，現顯示《{version}》。',
    'en': 'The edition “{code}” is no longer available. '
        'Showing {version} instead.',
  },
  // 2026-05-10 (v1.2.29): localised label for the close-pane
  // IconButton tooltip in `bible_reading_pane.dart` (sibling
  // `back` tooltip was already localised; `close` was not).
  'tooltipClose': {
    'zh-Hans': '关闭',
    'zh-Hant': '關閉',
    'en': 'Close',
  },
  // 2026-05-10 (v1.2.29): generic "Couldn't parse: $x" SnackBar
  // shown when a reference parse fails. Used across 7 surfaces
  // (library / news_detail / evidence / evidence_detail /
  // bible_timeline / dashboard / person_detail_sheet). `{ref}`
  // placeholder gets the raw input that failed.
  'couldNotParseRef': {
    'zh-Hans': '无法解析引用：{ref}',
    'zh-Hant': '無法解析引用：{ref}',
    'en': "Couldn't parse reference: {ref}",
  },
  // 2026-05-10 (v1.2.29): rendered when a sermon's `body.txt` is
  // missing on disk. Keeps zh users from seeing the English
  // fallback string in `sermon_detail_page.dart`.
  'sermonNoBody': {
    'zh-Hans': '本篇讲道没有文字内容。',
    'zh-Hant': '本篇講道沒有文字內容。',
    'en': 'No body text available for this sermon.',
  },
  'loadErrorBody': {
    'zh-Hans': '无法加载圣经经文，请检查网络或重试。',
    'zh-Hant': '無法載入聖經經文，請檢查網絡或重試。',
    'en': 'Could not load Bible verses. Please check your connection and retry.',
  },
  // 2026-05-10 (v1.2.10): in-flight progress strings shown on the
  // splash while FetchVerses.execute() is retrying. Keeps users
  // from thinking the app is frozen during a slow first-load.
  // `{n}` and `{max}` are runtime-replaced with attempt index +
  // max attempts (e.g. "Retrying… (2/3)").
  'loadingVerses': {
    'zh-Hans': '正在加载经文…',
    'zh-Hant': '正在載入經文…',
    'en': 'Loading verses…',
  },
  // 2026-07-21: shown on LoadingPage's friendly "still booting"
  // scaffold — deliberately upbeat rather than a generic "loading",
  // since this replaces what used to be a false-positive "Failed to
  // load" flash on slow connections.
  'bootLoadingMessage': {
    'zh-Hans': '飞快加载中…',
    'zh-Hant': '飛快載入中…',
    'en': 'Loading fast…',
  },
  'retryingAttempt': {
    'zh-Hans': '重试中…（第 {n}/{max} 次）',
    'zh-Hant': '重試中…（第 {n}/{max} 次）',
    'en': 'Retrying… ({n}/{max})',
  },
  // 2026-05-10 (v1.2.18): user opted into eager pre-load of all
  // 13 Bible versions during boot ("反正第一次用才 load version,
  // 就全部 load 吧"). Splash now paints this subtitle while the
  // sequential parse runs — typically ~20–30 s on cold boot, less
  // on warm SW cache. After boot, every version + chapter switch
  // is a cache hit (instant, no overlay) for the rest of the
  // session.
  'loadingVersionsProgress': {
    'zh-Hans': '正在加载译本：{n}/{total}',
    'zh-Hant': '正在載入譯本：{n}/{total}',
    'en': 'Loading versions: {n}/{total}',
  },
  'retry': {
    'zh-Hans': '重试',
    'zh-Hant': '重試',
    'en': 'Retry',
  },
  // 2026-05-10 (v1.2.12): user reported v1.2.10's auto-retry still
  // showed "Failed to load" on first cold-start ("dev still failed
  // load 我重进才 load"). Root cause: Flutter web's rootBundle
  // memoises the in-flight Future per-asset, so v1.2.10's 3
  // retries collapsed into 1 effective fetch. Real fix lives in
  // fetch_verses.dart (rootBundle.clear before each retry +
  // 20 s timeout). The error scaffold below adds a second
  // escape-hatch button — if even the new retry can't recover
  // (e.g. a stale service-worker bundle baked from a prior
  // deploy), one tap nukes all SW + cache buckets and reloads the
  // page, no localStorage touched.
  'hardReloadPage': {
    'zh-Hans': '清除缓存并重新加载',
    'zh-Hant': '清除快取並重新載入',
    'en': 'Reload page (clear cache)',
  },
  'showDetails': {
    'zh-Hans': '显示详情',
    'zh-Hant': '顯示詳情',
    'en': 'Show details',
  },
  // Reload-from-anywhere action — surfaces in the floating-header
  // overflow menu and the empty-reader recovery screen so the user
  // always has a one-tap fix when verses fail to load mid-session
  // (instead of having to relaunch the app).
  'reload': {
    'zh-Hans': '重新加载',
    'zh-Hant': '重新載入',
    'en': 'Reload',
  },
  'reloading': {
    'zh-Hans': '正在重新加载…',
    'zh-Hant': '正在重新載入…',
    'en': 'Reloading…',
  },
  'reloaded': {
    'zh-Hans': '已重新加载',
    'zh-Hant': '已重新載入',
    'en': 'Reloaded',
  },
  // 2026-05-07 (v17): offlineMode / offlineModeSubtitle /
  // checkForUpdates / checkForUpdatesSubtitle / updatesAvailableTitle
  // / updatesAvailableBody were removed when the matching Settings
  // controls were deleted (the toggle was dead, the dialog was
  // theatre). The "Offline pack" card (kept) has its own strings.
  'chapters': {
    'zh-Hans': '章',
    'zh-Hant': '章',
    'en': 'ch',
  },
  'bible': {
    'zh-Hans': '圣经',
    'zh-Hant': '聖經',
    'en': 'Bible',
  },
  'readingMode': {
    'zh-Hans': '阅读模式',
    'zh-Hant': '閱讀模式',
    'en': 'Reading Mode',
  },
  'verseByVerse': {
    'zh-Hans': '逐节显示',
    'zh-Hant': '逐節顯示',
    'en': 'Verse by Verse',
  },
  'paragraphFlow': {
    'zh-Hans': '段落排版',
    'zh-Hant': '段落排版',
    'en': 'Paragraph Flow',
  },

  // ====== Illustrations (formerly "Maps" — now also covers parable
  // scenes, narrative paintings, prophecy imagery, etc.) ======
  'maps': {
    'zh-Hans': '插图',
    'zh-Hant': '插畫',
    'en': 'Illustrations',
  },
  'sermons': {
    'zh-Hans': '讲道',
    'zh-Hant': '講道',
    'en': 'Sermons',
  },
  'sermon': {
    'zh-Hans': '讲道',
    'zh-Hant': '講道',
    'en': 'Sermon',
  },
  // 'sermonsTagline' was removed here. It was the collection byline, it
  // spelled the name a third way ("Pastor Eric Chang"), and grep found no
  // widget that ever rendered it — the library header it was written for
  // showed only "讲道". `sermonLibraryCredit` in sermon_credit.dart is
  // what the header renders now.
  'sermonSearchHint': {
    'zh-Hans': '按标题、经文或编号搜索讲道…',
    'zh-Hant': '按標題、經文或編號搜尋講道…',
    'en': 'Search sermons by title, passage or ID…',
  },
  'sermonCountTemplate': {
    'zh-Hans': '{count} 篇讲道,共 {topics} 个主题',
    'zh-Hant': '{count} 篇講道,共 {topics} 個主題',
    'en': '{count} sermons across {topics} topics',
  },
  'sermonGroupCount': {
    'zh-Hans': '{count} 篇',
    'zh-Hant': '{count} 篇',
    'en': '{count} sermon(s)',
  },
  'relatedSermons': {
    'zh-Hans': '相关讲道',
    'zh-Hant': '相關講道',
    'en': 'Related sermons',
  },
  'noRelatedSermons': {
    'zh-Hans': '没有讲道引用这些经文。',
    'zh-Hant': '沒有講道引用這些經文。',
    'en': 'No sermons reference these verses.',
  },
  'sermonFilterByPassage': {
    'zh-Hans': '按经文筛选',
    'zh-Hant': '按經文篩選',
    'en': 'Filter by passage',
  },
  'aiExplainHeader': {
    'zh-Hans': 'AI 释义',
    'zh-Hant': 'AI 釋義',
    'en': 'AI explanation',
  },
  'aiExplainButton': {
    'zh-Hans': '让 AI 解释此词在这节经文中的含义（仅供参考）',
    'zh-Hant': '讓 AI 解釋此詞在這節經文中的含義（僅供參考）',
    'en':
        'Let AI explain this word in this verse (reference only)',
  },
  // v1.3.x: reading-pane selection-bar AI verse explanation.
  'aiExplainVerse': {
    'zh-Hans': 'AI 解释经文',
    'zh-Hant': 'AI 解釋經文',
    'en': 'AI explain',
  },
  'aiExplainVerseDisclaimer': {
    'zh-Hans': 'AI 生成的解释，仅供参考；请以圣经原文为准。',
    'zh-Hant': 'AI 生成的解釋，僅供參考；請以聖經原文為準。',
    'en':
        'AI-generated; for reference only — let Scripture itself be the authority.',
  },
  'aiExplainError': {
    'zh-Hans': 'AI 解释暂时不可用，请稍后再试。',
    'zh-Hant': 'AI 解釋暫時不可用，請稍後再試。',
    'en': 'AI explanation is not available right now.',
  },
  // v1.3.68: optional "ask a question about this passage" box in the
  // reading-pane AI panel.
  'aiAskQuestionHint': {
    'zh-Hans': '想问关于这段经文的问题？（可选）',
    'zh-Hant': '想問關於這段經文的問題？（可選）',
    'en': 'Ask a question about this passage… (optional)',
  },
  'aiAskSend': {
    'zh-Hans': '提问',
    'zh-Hant': '提問',
    'en': 'Ask',
  },
  'aiAskYourQuestion': {
    'zh-Hans': '你的问题',
    'zh-Hant': '你的問題',
    'en': 'Your question',
  },
  'aiAskAnswering': {
    'zh-Hans': '正在回答你的问题…',
    'zh-Hant': '正在回答你的問題…',
    'en': 'Answering your question…',
  },
  'aiAskClear': {
    'zh-Hans': '返回经文解释',
    'zh-Hant': '返回經文解釋',
    'en': 'Back to explanation',
  },
  'aiExplainScriptureLabel': {
    'zh-Hans': '经文',
    'zh-Hant': '經文',
    'en': 'Scripture',
  },
  // v1.3.71: panel no longer auto-generates on open — the user confirms
  // first (empty question ⇒ explanation, with question ⇒ answer).
  'aiExplainIdleHint': {
    'zh-Hans': '可以直接生成这段经文的解释，或先输入你的问题再确认。',
    'zh-Hant': '可以直接生成這段經文的解釋，或先輸入你的問題再確認。',
    'en':
        'Generate an explanation of this passage, or type a question first and confirm.',
  },
  'aiExplainGenerate': {
    'zh-Hans': '解释这段经文',
    'zh-Hant': '解釋這段經文',
    'en': 'Explain this passage',
  },
  'aiExplainGenerating': {
    'zh-Hans': '正在生成解释…',
    'zh-Hant': '正在生成解釋…',
    'en': 'Generating explanation…',
  },
  // v1.3.73: multi-turn study chat — follow-ups, length controls,
  // save-to-note.
  'aiFollowUpHint': {
    'zh-Hans': '继续追问…',
    'zh-Hant': '繼續追問…',
    'en': 'Ask a follow-up…',
  },
  'aiMoreConcise': {
    'zh-Hans': '更简短',
    'zh-Hant': '更簡短',
    'en': 'More concise',
  },
  'aiMoreDetail': {
    'zh-Hans': '更详细',
    'zh-Hant': '更詳細',
    'en': 'More detail',
  },
  'aiSaveToNote': {
    'zh-Hans': '存入笔记',
    'zh-Hant': '存入筆記',
    'en': 'Save to note',
  },
  'aiNoteAttribution': {
    'zh-Hans': '——SeekSparks AI 生成，仅供参考',
    'zh-Hant': '——SeekSparks AI 生成，僅供參考',
    'en': '— generated by SeekSparks AI, for reference',
  },
  'aiExplainAsking': {
    'zh-Hans': 'AI 正在生成解释…',
    'zh-Hant': 'AI 正在生成解釋…',
    'en': 'AI is generating an explanation…',
  },
  'aiExplainRegenerate': {
    'zh-Hans': '重新生成',
    'zh-Hant': '重新生成',
    'en': 'Regenerate',
  },
  'aiExplainDisclaimer': {
    'zh-Hans': 'AI 生成内容仅供参考，如用于研经或教导请核对原始资料。',
    'zh-Hant': 'AI 生成內容僅供參考，如用於研經或教導請核對原始資料。',
    'en':
        'AI-generated content for reference only — verify with '
            'primary sources before using for study or teaching.',
  },
  'aiExplainTryAgain': {
    'zh-Hans': '重试',
    'zh-Hant': '重試',
    'en': 'Try again',
  },
  'aiExplainCopy': {
    'zh-Hans': '复制',
    'zh-Hant': '複製',
    'en': 'Copy',
  },
  'aiLengthLabel': {
    'zh-Hans': '长度',
    'zh-Hant': '長度',
    'en': 'Length',
  },
  'aiLengthConcise': {
    'zh-Hans': '更简短',
    'zh-Hant': '更簡短',
    'en': 'More concise',
  },
  'aiLengthLonger': {
    'zh-Hans': '更详细',
    'zh-Hant': '更詳細',
    'en': 'More detail',
  },
  'aiScopeLabel': {
    'zh-Hans': '范围',
    'zh-Hant': '範圍',
    'en': 'Scope',
  },
  'aiScopeVerse': {
    'zh-Hans': '本节经文',
    'zh-Hant': '本節經文',
    'en': 'In this verse',
  },
  'aiScopeChapter': {
    'zh-Hans': '本章',
    'zh-Hant': '本章',
    'en': 'In this chapter',
  },
  'aiScopeBook': {
    'zh-Hans': '本书卷',
    'zh-Hant': '本書卷',
    'en': 'In this book',
  },
  'aiScopeOtherChapters': {
    'zh-Hans': '其他章节',
    'zh-Hant': '其他章節',
    'en': 'Other chapters',
  },
  'aiScopeWholeBible': {
    'zh-Hans': '全本圣经',
    'zh-Hant': '全本聖經',
    'en': 'Whole Bible',
  },
  'aiScopeCrossTestament': {
    'zh-Hans': '跨新旧约',
    'zh-Hant': '跨新舊約',
    'en': 'Across testaments',
  },
  'aiScopeCrossTestamentNtToOt': {
    'zh-Hans': '旧约背景',
    'zh-Hant': '舊約背景',
    'en': 'OT background',
  },
  'aiScopeCrossTestamentOtToNt': {
    'zh-Hans': '新约对应',
    'zh-Hant': '新約對應',
    'en': 'NT echoes',
  },
  // 2026-05-07: BDAG-level deep exegesis chip — 5-section structured
  // analysis (lexical core / verse usage / cultural context /
  // canonical pattern / theological weight). Free-tier substitute
  // for what Logos+BDAG charges $200+ for.
  'aiScopeDeepExegesis': {
    'zh-Hans': '深度释经（BDAG 级 · SeekSparks 智能分析，仅供参考）',
    'zh-Hant': '深度釋經（BDAG 級 · SeekSparks 智慧分析，僅供參考）',
    'en': 'Deep exegesis (BDAG-level · SeekSparks AI, reference only)',
  },
  'familyTree': {
    'zh-Hans': '圣经家谱',
    'zh-Hant': '聖經家譜',
    'en': 'Family Tree',
  },
  'hebrewKings': {
    'zh-Hans': '犹大与以色列列王',
    'zh-Hant': '猶大與以色列列王',
    'en': 'Kings of Judah & Israel',
  },
  // The Genesis 5 and 11 lifespans. "年代" rather than "年表" because a
  // 年表 is a list of events and this is a chart of durations, which is
  // the whole difference between it and the Timeline resource.
  'chronology': {
    'zh-Hans': '圣经年代（创世记五、十一章）',
    'zh-Hant': '聖經年代（創世記五、十一章）',
    'en': 'Bible Chronology',
  },
  'chronologyText': {
    'zh-Hans': '经文传统',
    'zh-Hant': '經文傳統',
    'en': 'Text',
  },
  // Anno Mundi. Left untranslated as an abbreviation in English and
  // given its meaning in Chinese, because "AM" tells a Chinese reader
  // nothing and 创世纪年 tells them exactly what the axis counts.
  'chronologyAm': {
    'zh-Hans': '创世纪年',
    'zh-Hant': '創世紀年',
    'en': 'AM',
  },
  'chronologyYears': {
    'zh-Hans': '年',
    'zh-Hant': '年',
    'en': 'years',
  },
  'chronologyBegatAt': {
    'zh-Hans': '生下一代时的年岁',
    'zh-Hant': '生下一代時的年歲',
    'en': 'Fathered the next generation at',
  },
  'chronologyLivedAfter': {
    'zh-Hans': '此后又活了',
    'zh-Hant': '此後又活了',
    'en': 'Lived after that',
  },
  'chronologyLifespan': {
    'zh-Hans': '一生年数',
    'zh-Hant': '一生年數',
    'en': 'Lifespan',
  },
  'chronologyChecked': {
    'zh-Hans': '经文三个数字都有记载，第三个正好核对前两个。',
    'zh-Hant': '經文三個數字都有記載，第三個正好核對前兩個。',
    'en':
        'The text states all three figures, and the third checks the other two.',
  },
  'chronologyDerived': {
    'zh-Hans': '其中一个数字经文没有记载，是从有记载的另外两个算出来的。',
    'zh-Hant': '其中一個數字經文沒有記載，是從有記載的另外兩個算出來的。',
    'en':
        'One of these figures is not stated in the text; it follows from the two that are.',
  },
  'chronologyAllStated': {
    'zh-Hans': '这里的数字都出自经文，没有一个是算出来的。',
    'zh-Hant': '這裡的數字都出自經文，沒有一個是算出來的。',
    'en': 'Every figure here is stated in the text; none of them was derived.',
  },
  'chronologyNarrative': {
    'zh-Hans': '这人只有一生的总年数出自经文，其余是从记叙中别处的岁数推算出来的。',
    'zh-Hant': '這人只有一生的總年數出自經文，其餘是從記敘中別處的歲數推算出來的。',
    'en':
        'Only the total is stated for this man; the other figures were worked out from ages given elsewhere in the narrative.',
  },
  'chronologyNarrativeChecked': {
    'zh-Hans': '这人只有一生的总年数出自经文，其余是从记叙中别处的岁数推算出来的；经文另有一个数字正好核对。',
    'zh-Hant': '這人只有一生的總年數出自經文，其餘是從記敘中別處的歲數推算出來的；經文另有一個數字正好核對。',
    'en':
        'Only the total is stated for this man; the other figures were worked out from ages given elsewhere in the narrative, and the text states a further figure that checks them.',
  },
  'chronologyContemporaries': {
    'zh-Hans': '同时在世的人',
    'zh-Hant': '同時在世的人',
    'en': 'Alive at the same time',
  },
  'chronologyContemporariesNote': {
    'zh-Hans': '经文并未如此说；这是把经文所记的岁数相加得出的。',
    'zh-Hant': '經文並未如此說；這是把經文所記的歲數相加得出的。',
    'en':
        'Not stated anywhere in the text — this follows from adding up the ages it gives.',
  },
  'kingsJudah': {
    'zh-Hans': '犹大',
    'zh-Hant': '猶大',
    'en': 'Judah',
  },
  'kingsIsrael': {
    'zh-Hans': '以色列',
    'zh-Hant': '以色列',
    'en': 'Israel',
  },
  'kingsUnited': {
    'zh-Hans': '统一王国',
    'zh-Hant': '統一王國',
    'en': 'United monarchy',
  },
  'kingsSole': {
    'zh-Hans': '单独执政',
    'zh-Hant': '單獨執政',
    'en': 'Sole reign',
  },
  'kingsCoregency': {
    'zh-Hans': '共同摄政',
    'zh-Hant': '共同攝政',
    'en': 'Co-regency',
  },
  'kingsRival': {
    'zh-Hans': '争位并立',
    'zh-Hant': '爭位並立',
    'en': 'Rival reign',
  },
  'kingsChronology': {
    'zh-Hans': '年代系统',
    'zh-Hant': '年代系統',
    'en': 'Chronology',
  },
  'kingsSystemsDiffer': {
    'zh-Hans': '各年代系统在以尼散月或提斯利月为岁首、登基年的算法、共同摄政以及与亚述、巴比伦的同步年代上有分歧；采用奥尔布赖特或加利尔系统的注释书会给出不同的年份。',
    'zh-Hant': '各年代系統在以尼散月或提斯利月為歲首、登基年的算法、共同攝政以及與亞述、巴比倫的同步年代上有分歧；採用奧爾布賴特或加利爾系統的註釋書會給出不同的年份。',
    'en': 'Chronologies differ over the Nisan or Tishri new year, '
        'accession-year reckoning, co-regencies and the Assyrian and '
        'Babylonian synchronisms; a commentary following Albright or Galil '
        'will give other dates.',
  },
  'kingsSelectHint': {
    'zh-Hans': '选择一位君王，即可看见他在位时另一国的君王，以及《列王纪》与《历代志》中记载他的经文。',
    'zh-Hant': '選擇一位君王，即可看見他在位時另一國的君王，以及《列王紀》與《歷代志》中記載他的經文。',
    'en': 'Select a king to see who held the other throne while he reigned, '
        'and where his reign is told in Kings and in Chronicles.',
  },
  'kingsSources': {
    'zh-Hans': '资料来源',
    'zh-Hant': '資料來源',
    'en': 'Sources',
  },
  'kingsReign': {
    'zh-Hans': '在位',
    'zh-Hant': '在位',
    'en': 'Reign',
  },
  'kingsPassages': {
    'zh-Hans': '记载出处',
    'zh-Hant': '記載出處',
    'en': 'Where it is told',
  },
  'kingsAccession': {
    'zh-Hans': '登基同步经文',
    'zh-Hant': '登基同步經文',
    'en': 'Accession synchronism',
  },
  'kingsInKings': {
    'zh-Hans': '列王纪',
    'zh-Hant': '列王紀',
    'en': 'In Kings',
  },
  'kingsInChronicles': {
    'zh-Hans': '历代志',
    'zh-Hant': '歷代志',
    'en': 'In Chronicles',
  },
  'kingsNoChronicles': {
    'zh-Hans': '《历代志》只追述大卫的家系，没有为北国诸王另作平行的记载。',
    'zh-Hant': '《歷代志》只追述大衛的家系，沒有為北國諸王另作平行的記載。',
    'en': 'Chronicles follows the line of David and gives the northern kings '
        'no parallel account.',
  },
  'kingsContemporaries': {
    'zh-Hans': '同期在另一国的君王',
    'zh-Hant': '同期在另一國的君王',
    'en': 'On the other throne',
  },
  'kingsNoContemporaries': {
    'zh-Hans': '没有在位时间重叠的君王。',
    'zh-Hant': '沒有在位時間重疊的君王。',
    'en': 'No overlapping reign.',
  },
  'kingsHouseOf': {
    'zh-Hans': '{name}家',
    'zh-Hant': '{name}家',
    'en': 'House of {name}',
  },
  'familyTreeSearchHint': {
    'zh-Hans': '按姓名或简介搜索…',
    'zh-Hant': '按姓名或簡介搜尋…',
    'en': 'Search by name or biography…',
  },
  'familyTreeFilterCount': {
    'zh-Hans': '匹配 {count} / 共 {total} 人',
    'zh-Hant': '匹配 {count} / 共 {total} 人',
    'en': '{count} of {total} people',
  },
  'familyTreeTotalCount': {
    'zh-Hans': '共 {total} 位人物',
    'zh-Hant': '共 {total} 位人物',
    'en': '{total} people',
  },
  'familyTreeNoMatches': {
    'zh-Hans': '没有匹配的人物',
    'zh-Hant': '沒有匹配的人物',
    'en': 'No one matches that search.',
  },
  'familyTreeParents': {
    'zh-Hans': '父母',
    'zh-Hant': '父母',
    'en': 'Parents',
  },
  'familyTreeFather': {
    'zh-Hans': '父',
    'zh-Hant': '父',
    'en': 'Father',
  },
  'familyTreeMother': {
    'zh-Hans': '母',
    'zh-Hant': '母',
    'en': 'Mother',
  },
  'familyTreeSpouse': {
    'zh-Hans': '配偶',
    'zh-Hant': '配偶',
    'en': 'Spouse',
  },
  'familyTreeSpouses': {
    'zh-Hans': '配偶',
    'zh-Hant': '配偶',
    'en': 'Spouses',
  },
  'familyTreeChildren': {
    'zh-Hans': '子女',
    'zh-Hant': '子女',
    'en': 'Children',
  },
  'familyTreeReferences': {
    'zh-Hans': '相关经文',
    'zh-Hant': '相關經文',
    'en': 'Verse references',
  },
  'familyTreeAncestry': {
    'zh-Hans': '父系家谱',
    'zh-Hant': '父系家譜',
    'en': 'Patrilineal ancestry',
  },
  'familyTreeViewList': {
    'zh-Hans': '列表视图',
    'zh-Hant': '列表檢視',
    'en': 'List view',
  },
  'familyTreeViewChart': {
    'zh-Hans': '图表视图',
    'zh-Hant': '圖表檢視',
    'en': 'Chart view',
  },
  'familyTreeLongPressRefocus': {
    'zh-Hans': '点击查看详情 · 长按聚焦此人',
    'zh-Hant': '點擊查看詳情 · 長按聚焦此人',
    'en': 'Tap for details · long-press to focus',
  },
  'familyTreeTapRefocus': {
    'zh-Hans': '点击展开此人 · 点击 ⓘ 查看详情',
    'zh-Hant': '點擊展開此人 · 點擊 ⓘ 查看詳情',
    'en': 'Tap to expand · ⓘ for details',
  },
  'familyTreeOpenDetails': {
    'zh-Hans': '查看详情',
    'zh-Hant': '查看詳情',
    'en': 'Details',
  },
  'familyTreeOrphanMatches': {
    'zh-Hans': '其他匹配（不在亚当谱系中）',
    'zh-Hant': '其他匹配（不在亞當譜系中）',
    'en': 'Other matches (not in the Adam lineage)',
  },
  'familyTreePrevMatch': {
    'zh-Hans': '上一个匹配',
    'zh-Hant': '上一個匹配',
    'en': 'Previous match',
  },
  'familyTreeNextMatch': {
    'zh-Hans': '下一个匹配',
    'zh-Hant': '下一個匹配',
    'en': 'Next match',
  },
  'familyTreeSiblings': {
    'zh-Hans': '兄弟姐妹',
    'zh-Hant': '兄弟姐妹',
    'en': 'Siblings',
  },
  'familyTreeTribeLine': {
    'zh-Hans': '所属支派 / 世系',
    'zh-Hant': '所屬支派 / 世系',
    'en': 'Tribe / line',
  },
  'familyTreeJumpAdam': {
    'zh-Hans': '亚当',
    'zh-Hant': '亞當',
    'en': 'Adam',
  },
  'familyTreeJumpNoah': {
    'zh-Hans': '挪亚',
    'zh-Hant': '挪亞',
    'en': 'Noah',
  },
  'familyTreeJumpAbraham': {
    'zh-Hans': '亚伯拉罕',
    'zh-Hant': '亞伯拉罕',
    'en': 'Abraham',
  },
  'familyTreeJumpMoses': {
    'zh-Hans': '摩西',
    'zh-Hant': '摩西',
    'en': 'Moses',
  },
  'familyTreeJumpDavid': {
    'zh-Hans': '大卫',
    'zh-Hant': '大衛',
    'en': 'David',
  },
  'familyTreeJumpExile': {
    'zh-Hans': '被掳',
    'zh-Hant': '被擄',
    'en': 'Exile',
  },
  'familyTreeJumpJesus': {
    'zh-Hans': '耶稣',
    'zh-Hant': '耶穌',
    'en': 'Jesus',
  },
  'familyTreeComparisonTitle': {
    'zh-Hans': '族谱对照表',
    'zh-Hant': '族譜對照表',
    'en': 'Comparison of genealogies',
  },
  'familyTreeComparisonSubtitle': {
    'zh-Hans': '亚当 → 耶稣，按经文出处对照',
    'zh-Hant': '亞當 → 耶穌，按經文出處對照',
    'en': 'Adam → Jesus by canonical Bible source',
  },
  'familyTreeColGen': {
    'zh-Hans': '世代',
    'zh-Hant': '世代',
    'en': 'Gen',
  },
  'familyTreeColName': {
    'zh-Hans': '姓名',
    'zh-Hant': '姓名',
    'en': 'Name',
  },
  'familyTreeColYears': {
    'zh-Hans': '年代',
    'zh-Hant': '年代',
    'en': 'Years',
  },
  'familyTreeColGen5': {
    'zh-Hans': '创 5',
    'zh-Hant': '創 5',
    'en': 'Gen 5',
  },
  'familyTreeColGen11': {
    'zh-Hans': '创 11',
    'zh-Hant': '創 11',
    'en': 'Gen 11',
  },
  'familyTreeColChron1': {
    'zh-Hans': '代上 1',
    'zh-Hant': '代上 1',
    'en': '1 Chr 1',
  },
  'familyTreeColRuth4': {
    'zh-Hans': '得 4',
    'zh-Hant': '得 4',
    'en': 'Ruth 4',
  },
  'familyTreeColMatt1': {
    'zh-Hans': '太 1',
    'zh-Hant': '太 1',
    'en': 'Matt 1',
  },
  'familyTreeColLuke3': {
    'zh-Hans': '路 3',
    'zh-Hant': '路 3',
    'en': 'Luke 3',
  },
  // Era subtitles — one short line of orientation per section
  // (description + date range), shown under the section header.
  'familyTreeEraSubAntediluvian': {
    'en': 'Ten generations from Adam to Noah · AM 0 – 1656',
    'zh-Hans': '从亚当到挪亚十代 · 创世以来 0 – 1656 年',
    'zh-Hant': '從亞當到挪亞十代 · 創世以來 0 – 1656 年',
  },
  'familyTreeEraSubPostFlood': {
    'en': 'Shem to Terah, post-Flood patriarchs · ~BC 2400 – 2000',
    'zh-Hans': '闪到他拉，洪水后的列祖 · 约公元前 2400 – 2000',
    'zh-Hant': '閃到他拉，洪水後的列祖 · 約公元前 2400 – 2000',
  },
  'familyTreeEraSubPatriarchs': {
    'en': 'Abraham, Isaac, Jacob & the twelve tribes · ~BC 2200 – 1700',
    'zh-Hans': '亚伯拉罕、以撒、雅各与十二支派 · 约公元前 2200 – 1700',
    'zh-Hant': '亞伯拉罕、以撒、雅各與十二支派 · 約公元前 2200 – 1700',
  },
  'familyTreeEraSubMosaic': {
    'en': 'Aaron the High Priest, Moses the Lawgiver & Miriam · ~BC 1500 – 1400',
    'zh-Hans': '大祭司亚伦、律法颁布者摩西、米利暗 · 约公元前 1500 – 1400',
    'zh-Hant': '大祭司亞倫、律法頒布者摩西、米利暗 · 約公元前 1500 – 1400',
  },
  'familyTreeEraSubDavidic': {
    'en': 'Perez through Boaz & Ruth to Jesse, father of David · ~BC 1900 – 1050',
    'zh-Hans': '法勒斯经波阿斯和路得到大卫之父耶西 · 约公元前 1900 – 1050',
    'zh-Hant': '法勒斯經波阿斯和路得到大衛之父耶西 · 約公元前 1900 – 1050',
  },
  'familyTreeEraSubKings': {
    'en': 'Kings of Judah from David to Jeconiah · BC 1010 – 586',
    'zh-Hans': '犹大列王，从大卫到耶哥尼雅 · 公元前 1010 – 586',
    'zh-Hant': '猶大列王，從大衛到耶哥尼雅 · 公元前 1010 – 586',
  },
  'familyTreeEraSubExile': {
    'en': 'Shealtiel through Matthan to Joseph (Matthew 1:13–16)',
    'zh-Hans': '撒拉铁经马但到约瑟（马太福音 1:13–16）',
    'zh-Hant': '撒拉鐵經馬但到約瑟（馬太福音 1:13–16）',
  },
  'familyTreeEraSubLukan': {
    'en': "Mary's lineage per Luke 3:23–31 (Nathan → … → Heli → Mary)",
    'zh-Hans': '路加福音 3:23–31 所记马利亚的家谱（拿单 → … → 希里 → 马利亚）',
    'zh-Hant': '路加福音 3:23–31 所記馬利亞的家譜（拿單 → … → 希里 → 馬利亞）',
  },
  'familyTreeEraSubNt': {
    'en': 'The earthly family of Jesus the Messiah · ~BC 5 – AD 30',
    'zh-Hans': '弥赛亚耶稣的地上家庭 · 约公元前 5 – 公元 30',
    'zh-Hant': '彌賽亞耶穌的地上家庭 · 約公元前 5 – 公元 30',
  },
  'familyTreeExpandAll': {
    'en': 'Expand all',
    'zh-Hans': '全部展开',
    'zh-Hant': '全部展開',
  },
  'familyTreeCollapseAll': {
    'en': 'Collapse all',
    'zh-Hans': '全部收起',
    'zh-Hant': '全部收起',
  },
  'familyTreeContinuesWith': {
    'en': 'Continues with',
    'zh-Hans': '下一位',
    'zh-Hant': '下一位',
  },
  'familyTreeCopyAll': {
    'en': 'Copy all info',
    'zh-Hans': '复制全部信息',
    'zh-Hant': '複製全部資訊',
  },
  'familyTreeCopiedToast': {
    'en': 'Copied to clipboard',
    'zh-Hans': '已复制到剪贴板',
    'zh-Hant': '已複製到剪貼簿',
  },
  'familyTreeCopyFailedToast': {
    'en': 'Copy failed — clipboard not available',
    'zh-Hans': '复制失败 — 剪贴板不可用',
    'zh-Hant': '複製失敗 — 剪貼簿不可用',
  },
  'familyTreeRole': {
    'en': 'Role',
    'zh-Hans': '身份',
    'zh-Hant': '身份',
  },
  // Bible timeline page
  'bibleTimeline': {
    'en': 'Bible Timeline',
    'zh-Hans': '圣经时间轴',
    'zh-Hant': '聖經時間軸',
  },
  'bibleTimelineSearchHint': {
    'en': 'Search events…',
    'zh-Hans': '搜索事件…',
    'zh-Hant': '搜尋事件…',
  },
  'bibleTimelineCount': {
    'en': '{count} events',
    'zh-Hans': '{count} 项事件',
    'zh-Hant': '{count} 項事件',
  },
  'bibleTimelineNoMatches': {
    'en': 'No events match.',
    'zh-Hans': '未找到符合的事件。',
    'zh-Hant': '未找到符合的事件。',
  },
  // Share-link toasts (sermons + bible verses)
  'shareLink': {
    'en': 'Share',
    'zh-Hans': '分享',
    'zh-Hant': '分享',
  },
  'shareLinkCopied': {
    'en': 'Share link copied',
    'zh-Hans': '分享链接已复制',
    'zh-Hant': '分享連結已複製',
  },
  'shareLinkFailed': {
    'en': 'Copy failed — clipboard unavailable',
    'zh-Hans': '复制失败 — 剪贴板不可用',
    'zh-Hant': '複製失敗 — 剪貼簿不可用',
  },
  // Sermon copy-all (full body + attribution footer)
  'sermonCopyAll': {
    'en': 'Copy sermon',
    'zh-Hans': '复制讲道',
    'zh-Hant': '複製講道',
  },
  'sermonCopied': {
    'en': 'Sermon copied to clipboard',
    'zh-Hans': '讲道已复制到剪贴板',
    'zh-Hant': '講道已複製到剪貼簿',
  },
  'sermonCopyEmpty': {
    'en': 'Sermon not loaded yet — wait for content to appear',
    'zh-Hans': '讲道尚未加载完成 — 请等待内容显示',
    'zh-Hant': '講道尚未載入完成 — 請等待內容顯示',
  },
  'sermonAttribution': {
    'en': "From SeekSparks (Yahweh's Words) — bilingual Bible app",
    'zh-Hans': '来自 SeekSparks 雅伟之言 — 双语圣经应用',
    'zh-Hant': '來自 SeekSparks 雅偉之言 — 雙語聖經應用',
  },
  // Shown above the body when the text on screen is a condensed summary
  // rather than a transcript. Ten sermons were translated into Chinese at
  // roughly a tenth of their English length and read as ordinary prose, so
  // without this line a reader has no way to know they are not reading the
  // sermon.
  'sermonCondensedNotice': {
    'en': 'This text is a condensed summary, not the full sermon.',
    'zh-Hans': '本篇为内容摘要，并非讲道全文。',
    'zh-Hant': '本篇為內容摘要，並非講道全文。',
  },
  'sermonCondensedFullIn': {
    'en': 'The full text is available in {lang}.',
    'zh-Hans': '完整讲道见{lang}。',
    'zh-Hant': '完整講道見{lang}。',
  },
  'sermonLangEn': {
    'en': 'English',
    'zh-Hans': '英文',
    'zh-Hant': '英文',
  },
  'sermonLangZhCn': {
    'en': 'Simplified Chinese',
    'zh-Hans': '简体中文',
    'zh-Hant': '簡體中文',
  },
  'sermonLangZhTw': {
    'en': 'Traditional Chinese',
    'zh-Hans': '繁体中文',
    'zh-Hant': '繁體中文',
  },
  // Verse popup sheet
  'versePopupExpand': {
    'en': 'Show full chapter',
    'zh-Hans': '展开整章',
    'zh-Hant': '展開整章',
  },
  'versePopupCollapse': {
    'en': 'Show only cited verses',
    'zh-Hans': '只显示引用的经文',
    'zh-Hant': '只顯示引用的經文',
  },
  'versePopupOpenReader': {
    'en': 'Open in reader',
    'zh-Hans': '在阅读器中打开',
    'zh-Hant': '在閱讀器中開啟',
  },
  'versePopupNotFound': {
    'en': 'Verse text not loaded — try "Open in reader".',
    'zh-Hans': '经文未加载 — 请尝试"在阅读器中打开"。',
    'zh-Hant': '經文未載入 — 請嘗試「在閱讀器中開啟」。',
  },
  'familyTreeMatchCount': {
    'zh-Hans': '第 {index}/{total} 个匹配',
    'zh-Hant': '第 {index}/{total} 個匹配',
    'en': 'Match {index} of {total}',
  },
  'familyTreeExpand': {
    'zh-Hans': '展开',
    'zh-Hant': '展開',
    'en': 'Expand',
  },
  'familyTreeCollapse': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Collapse',
  },
  'familyTreeRootLabel': {
    'zh-Hans': '始祖',
    'zh-Hant': '始祖',
    'en': 'ROOT',
  },
  'familyTreeFocusLeaf': {
    'zh-Hans': '此人物在数据集中暂无后裔。',
    'zh-Hant': '此人物在資料集中暫無後裔。',
    'en': 'No descendants in this dataset.',
  },
  'sermonFilterBookLabel': {
    'zh-Hans': '书卷',
    'zh-Hant': '書卷',
    'en': 'Book',
  },
  'sermonFilterChapterLabel': {
    'zh-Hans': '章',
    'zh-Hant': '章',
    'en': 'Chapter',
  },
  'sermonFilterAllChapters': {
    'zh-Hans': '全部章节',
    'zh-Hant': '全部章節',
    'en': 'All chapters',
  },
  'sermonNoMatches': {
    'zh-Hans': '没有讲道符合当前筛选条件。',
    'zh-Hant': '沒有講道符合當前篩選條件。',
    'en': 'No sermons match your filters.',
  },
  'clearFilter': {
    'zh-Hans': '清除',
    'zh-Hant': '清除',
    'en': 'Clear',
  },
  'apply': {
    'zh-Hans': '应用',
    'zh-Hant': '套用',
    'en': 'Apply',
  },
  'viewMap': {
    'zh-Hans': '查看插图',
    'zh-Hant': '查看插畫',
    'en': 'View Illustration',
  },
  'noMapsForChapter': {
    'zh-Hans': '本章暂无插图',
    'zh-Hant': '本章暫無插畫',
    'en': 'No illustrations for this chapter',
  },
  'mapsForThisChapter': {
    'zh-Hans': '本章相关插图',
    'zh-Hant': '本章相關插畫',
    'en': 'For this chapter',
  },
  'mapsForThisBook': {
    'zh-Hans': '本卷相关插图',
    'zh-Hant': '本卷相關插畫',
    'en': 'For this book',
  },
  'mapsAll': {
    'zh-Hans': '全部插图',
    'zh-Hant': '全部插畫',
    'en': 'All illustrations',
  },
  'mapsRelated': {
    'zh-Hans': '相关插图',
    'zh-Hant': '相關插畫',
    'en': 'Related illustrations',
  },
  'mapsBrowseLibrary': {
    'zh-Hans': '浏览全部插图',
    'zh-Hant': '瀏覽全部插畫',
    'en': 'Browse all illustrations',
  },
  'mapsNoneForChapterFallback': {
    'zh-Hans': '本章无专属插图，以下是相关内容：',
    'zh-Hant': '本章無專屬插畫，以下是相關內容：',
    'en': 'No illustration specifically for this chapter — here are related ones:',
  },
  // Per-book group label in the All-illustrations tab. {book} is the
  // localized book name; {n} is the count.
  'illustrationsBookCount': {
    'zh-Hans': '{book}（{n} 张）',
    'zh-Hant': '{book}（{n} 張）',
    'en': '{book} ({n})',
  },
  // 2026-08-09: the Illustrations window under Resources. bwh07 files a
  // picture database there ("Bible Views") and gives it a paragraph of
  // its own; until now this corpus of 1,192 plates could only be reached
  // from a chapter that happened to match one.
  'illustrationsSearchHint': {
    'zh-Hans': '搜索插图标题或说明',
    'zh-Hant': '搜尋插畫標題或說明',
    'en': 'Search titles and captions',
  },
  // {n} carries its denominator when a filter is narrowing — bwh23.
  'illustrationsCount': {
    'zh-Hans': '{n} 张插图',
    'zh-Hant': '{n} 張插畫',
    'en': '{n} illustrations',
  },
  'illustrationsNoMatch': {
    'zh-Hans': '没有符合条件的插图。',
    'zh-Hant': '沒有符合條件的插畫。',
    'en': 'No illustration matches.',
  },
  'illustrationUnavailable': {
    'zh-Hans': '插图无法载入',
    'zh-Hant': '插畫無法載入',
    'en': 'Illustration unavailable',
  },
  'illusKindMap': {'zh-Hans': '地图', 'zh-Hant': '地圖', 'en': 'Maps'},
  'illusKindScene': {'zh-Hans': '场景', 'zh-Hant': '場景', 'en': 'Scenes'},
  'illusKindParable': {'zh-Hans': '比喻', 'zh-Hant': '比喻', 'en': 'Parables'},
  'illusKindTeaching': {'zh-Hans': '教导', 'zh-Hant': '教導', 'en': 'Teaching'},
  'openSplitView': {
    'zh-Hans': '打开分屏阅读',
    'zh-Hant': '打開分屏閱讀',
    'en': 'Open Split View',
  },
  'closeSplitView': {
    'zh-Hans': '关闭分屏阅读',
    'zh-Hant': '關閉分屏閱讀',
    'en': 'Close Split View',
  },
  'searchHint': {
    'zh-Hans': '输入关键字开始搜索',
    'zh-Hant': '輸入關鍵字開始搜索',
    'en': 'Type a word or phrase to search',
  },
  'myHighlights': {
    'zh-Hans': '我的高亮',
    'zh-Hant': '我的高亮',
    'en': 'My Highlights',
  },
  'noHighlights': {
    'zh-Hans': '还没有高亮内容。\n选中经文，点击高亮按钮即可保存。',
    'zh-Hant': '還沒有高亮內容。\n選中經文，點擊高亮按鈕即可儲存。',
    'en': 'No highlights yet.\nSelect a verse and tap the highlight button to save.',
  },
  'highlightsVerseCount': {
    'zh-Hans': '{count} 节',
    'zh-Hant': '{count} 節',
    'en': '{count} verse',
  },
  'more': {
    'zh-Hans': '更多',
    'zh-Hant': '更多',
    'en': 'More',
  },
  'wordDistribution': {
    'zh-Hans': '分布',
    'zh-Hant': '分佈',
    'en': 'Distribution',
  },
  'topBooks': {
    'zh-Hans': '主要出处',
    'zh-Hant': '主要出處',
    'en': 'Top books',
  },
  'searchByStrongs': {
    'zh-Hans': '按 Strong\'s 编号搜索',
    'zh-Hant': '按 Strong\'s 編號搜尋',
    'en': 'Strong\'s number',
  },
  'interlinearHint': {
    'zh-Hans': '原文 · Strong\'s 中文释义',
    'zh-Hant': '原文 · Strong\'s 中文釋義',
    'en': 'Original · Strong\'s gloss',
  },
  // ====== Verse List Manager (BibleWorks bwh27) ======
  'analysisTabVerseLists': {
    'zh-Hans': '经文列表',
    'zh-Hant': '經文列表',
    'en': 'Lists',
  },
  'vlmMain': {'zh-Hans': '主列表', 'zh-Hant': '主列表', 'en': 'Main'},
  'vlmSecondary': {'zh-Hans': '副列表', 'zh-Hant': '副列表', 'en': 'Secondary'},
  'vlmImport': {'zh-Hans': '导入', 'zh-Hant': '匯入', 'en': 'Import'},
  'vlmImportCurrent': {
    'zh-Hans': '当前经文',
    'zh-Hant': '當前經文',
    'en': 'Current verse',
  },
  'vlmImportResults': {
    'zh-Hans': '搜索结果',
    'zh-Hant': '搜尋結果',
    'en': 'Search results',
  },
  'vlmImportText': {
    'zh-Hans': '从文本导入',
    'zh-Hant': '從文字匯入',
    'en': 'Import from text',
  },
  'vlmImportTextHint': {
    'zh-Hans': '粘贴任意文本，其中的经文出处都会被加入。',
    'zh-Hant': '貼上任意文字，其中的經文出處都會被加入。',
    'en': 'Paste any text. Every reference in it is added.',
  },
  'vlmEdit': {'zh-Hans': '编辑', 'zh-Hant': '編輯', 'en': 'Edit'},
  'vlmSortDedupe': {
    'zh-Hans': '排序（并去重）',
    'zh-Hant': '排序（並去重）',
    'en': 'Sort list (removes duplicates)',
  },
  'vlmDeleteSelected': {
    'zh-Hans': '删除已选',
    'zh-Hant': '刪除已選',
    'en': 'Delete selected',
  },
  'vlmCopyToOther': {
    'zh-Hans': '把已选复制到{other}',
    'zh-Hant': '把已選複製到{other}',
    'en': 'Copy selected to {other}',
  },
  'vlmClear': {'zh-Hans': '清空列表', 'zh-Hant': '清空列表', 'en': 'Clear list'},
  'vlmSelect': {'zh-Hans': '选择', 'zh-Hant': '選擇', 'en': 'Select'},
  'vlmSelectAll': {'zh-Hans': '全选', 'zh-Hant': '全選', 'en': 'Select all'},
  'vlmSelectNone': {
    'zh-Hans': '取消全选',
    'zh-Hant': '取消全選',
    'en': 'Unselect all',
  },
  'vlmInvertSelection': {
    'zh-Hans': '反选',
    'zh-Hant': '反選',
    'en': 'Invert selection',
  },
  'vlmSelectCommon': {
    'zh-Hans': '与{other}的共有部分',
    'zh-Hant': '與{other}的共有部分',
    'en': 'Common with {other}',
  },
  'vlmSelectUnique': {
    'zh-Hans': '不在{other}中的',
    'zh-Hant': '不在{other}中的',
    'en': 'Not in {other}',
  },
  'vlmFile': {'zh-Hans': '文件', 'zh-Hant': '檔案', 'en': 'File'},
  'vlmSaveAs': {
    'zh-Hans': '另存列表为',
    'zh-Hant': '另存列表為',
    'en': 'Save list as',
  },
  'vlmOpen': {'zh-Hans': '打开列表', 'zh-Hant': '開啟列表', 'en': 'Open list'},
  'vlmDeleteSaved': {
    'zh-Hans': '删除已存列表',
    'zh-Hant': '刪除已存列表',
    'en': 'Delete saved list',
  },
  'vlmCopyText': {
    'zh-Hans': '复制为文本',
    'zh-Hant': '複製為文字',
    'en': 'Copy as text',
  },
  'vlmListName': {'zh-Hans': '列表名称', 'zh-Hant': '列表名稱', 'en': 'List name'},
  'vlmDescription': {'zh-Hans': '说明', 'zh-Hant': '說明', 'en': 'Description'},
  'vlmSave': {'zh-Hans': '保存', 'zh-Hant': '儲存', 'en': 'Save'},
  'vlmAdd': {'zh-Hans': '加入', 'zh-Hant': '加入', 'en': 'Add'},
  'vlmAddHint': {
    'zh-Hans': '加入经文，例如 弗 2:8-10',
    'zh-Hant': '加入經文，例如 弗 2:8-10',
    'en': 'Add a verse, e.g. Eph 2:8-10',
  },
  'vlmAddedCount': {
    'zh-Hans': '已加入 {count} 处',
    'zh-Hant': '已加入 {count} 處',
    'en': '{count} added',
  },
  'vlmEmptyHint': {
    'zh-Hans': '列表为空。可导入当前经文或搜索结果，也可在下方输入经文出处。',
    'zh-Hant': '列表為空。可匯入當前經文或搜尋結果，也可在下方輸入經文出處。',
    'en': 'Empty. Import the current verse or your search results, '
        'or type a reference below.',
  },
  'vlmNoCurrentVerse': {
    'zh-Hans': '阅读区未选中经文。',
    'zh-Hant': '閱讀區未選中經文。',
    'en': 'No verse is selected in the reader.',
  },
  'vlmNoSearchResults': {
    'zh-Hans': '没有可加入的搜索结果。',
    'zh-Hant': '沒有可加入的搜尋結果。',
    'en': 'No search results to add.',
  },
  'vlmNothingSelected': {
    'zh-Hans': '未选中任何条目。',
    'zh-Hant': '未選中任何條目。',
    'en': 'Nothing is selected.',
  },
  'vlmNoRefsFound': {
    'zh-Hans': '文本中未找到经文出处。',
    'zh-Hant': '文字中未找到經文出處。',
    'en': 'No references found in that text.',
  },
  'vlmNotAReference': {
    'zh-Hans': '不是有效的经文出处。',
    'zh-Hant': '不是有效的經文出處。',
    'en': 'Not a reference.',
  },
  'vlmNoSavedLists': {
    'zh-Hans': '尚无已保存的列表。',
    'zh-Hant': '尚無已儲存的列表。',
    'en': 'No saved lists yet.',
  },
  'vlmListEmpty': {
    'zh-Hans': '该列表为空。',
    'zh-Hant': '該列表為空。',
    'en': 'This list is empty.',
  },
  'vlmSaved': {'zh-Hans': '已保存。', 'zh-Hant': '已儲存。', 'en': 'Saved.'},
  'vlmOpened': {
    'zh-Hans': '已并入当前列表。',
    'zh-Hant': '已併入當前列表。',
    'en': 'Merged into the active list.',
  },
  'vlmCopied': {'zh-Hans': '已复制。', 'zh-Hant': '已複製。', 'en': 'Copied.'},
  'vlmLimitOn': {
    'zh-Hans': '搜索已限定在此列表内',
    'zh-Hant': '搜尋已限定在此列表內',
    'en': 'Searches are limited to this list',
  },
  'vlmLimitOff': {
    'zh-Hans': '把搜索限定在此列表内',
    'zh-Hant': '把搜尋限定在此列表內',
    'en': 'Limit searches to this list',
  },
  'vlmLimitBanner': {
    'zh-Hans': '限定：{name}（{count} 处）',
    'zh-Hant': '限定：{name}（{count} 處）',
    'en': 'Limited to {name} ({count})',
  },

  // ── Phrase Matching (bwh51) ──────────────────────────────────────
  'analysisTabPhrases': {
    'zh-Hans': '短语',
    'zh-Hant': '短語',
    'en': 'Phrases',
  },
  'phraseUnit': {'zh-Hans': '条短语', 'zh-Hant': '條短語', 'en': 'phrases'},
  'phraseHint': {
    'zh-Hans': '点一下取用或弃用某短语。数字是含此短语的经文数。',
    'zh-Hant': '點一下取用或棄用某短語。數字是含此短語的經文數。',
    'en': 'Tap a phrase to use it or drop it. The number is how many '
        'verses contain it.',
  },
  'phraseLength': {'zh-Hans': '词数', 'zh-Hant': '詞數', 'en': 'Len'},
  'phraseGap': {'zh-Hans': '间隔', 'zh-Hant': '間隔', 'en': 'Gap'},
  'phraseSortMatches': {
    'zh-Hans': '匹配数',
    'zh-Hant': '匹配數',
    'en': 'Matches',
  },
  'phraseSortPhrase': {
    'zh-Hans': '按短语',
    'zh-Hant': '按短語',
    'en': 'Phrase',
  },
  'phraseScope': {
    'zh-Hans': '搜索限定',
    'zh-Hant': '搜尋限定',
    'en': 'Search limit',
  },
  'phraseNoHits': {
    'zh-Hans': '没有别的经文重复本节的短语。可缩短词数、放宽间隔，或多选几条短语。',
    'zh-Hant': '沒有別的經文重複本節的短語。可縮短詞數、放寬間隔，或多選幾條短語。',
    'en': 'No other verse repeats a phrase from this one. Shorten the '
        'phrase, widen the gap, or check more phrases.',
  },
  'phraseTooShort': {
    'zh-Hans': '本节比设定的词数还短。请调低词数。',
    'zh-Hant': '本節比設定的詞數還短。請調低詞數。',
    'en': 'This verse is shorter than the phrase length. Lower it.',
  },

  // ── Vocabulary Flashcards (bwh40) ────────────────────────────────
  'analysisTabVocabulary': {
    'zh-Hans': '生词',
    'zh-Hant': '生詞',
    'en': 'Vocab',
  },
  'vocabModeList': {'zh-Hans': '词表', 'zh-Hant': '詞表', 'en': 'Words'},
  'vocabModeDrill': {'zh-Hans': '背诵', 'zh-Hant': '背誦', 'en': 'Drill'},
  'vocabModeRead': {'zh-Hans': '试读', 'zh-Hant': '試讀', 'en': 'Read'},
  'vocabScopeChapter': {'zh-Hans': '本章', 'zh-Hant': '本章', 'en': 'Chapter'},
  'vocabScopeBook': {'zh-Hans': '本卷', 'zh-Hant': '本卷', 'en': 'Book'},
  'vocabScopeCorpus': {'zh-Hans': '全书', 'zh-Hant': '全書', 'en': 'All'},
  'vocabFreqAll': {'zh-Hans': '不限', 'zh-Hant': '不限', 'en': 'All'},
  'vocabSortCorpus': {'zh-Hans': '全书词频', 'zh-Hant': '全書詞頻', 'en': 'Corpus'},
  'vocabSortHere': {'zh-Hans': '此处词频', 'zh-Hant': '此處詞頻', 'en': 'Here'},
  'vocabSortAlpha': {'zh-Hans': '字母序', 'zh-Hant': '字母序', 'en': 'A–Z'},
  'vocabSortShuffle': {'zh-Hans': '随机', 'zh-Hant': '隨機', 'en': 'Shuffle'},
  'vocabParticles': {'zh-Hans': '虚词', 'zh-Hant': '虛詞', 'en': 'Particles'},
  'vocabHideLearned': {
    'zh-Hans': '隐藏已学',
    'zh-Hant': '隱藏已學',
    'en': 'Hide learned',
  },
  'vocabSearch': {'zh-Hans': '查找生词', 'zh-Hant': '查找生詞', 'en': 'Find a word'},
  'vocabHere': {'zh-Hans': '此处', 'zh-Hant': '此處', 'en': 'here'},
  'vocabInAll': {'zh-Hans': '全书', 'zh-Hant': '全書', 'en': 'in all'},
  'vocabEmpty': {
    'zh-Hans': '没有符合的词。可降低词频门槛，或扩大范围。',
    'zh-Hant': '沒有符合的詞。可降低詞頻門檻，或擴大範圍。',
    'en': 'No words match. Lower the frequency floor or widen the scope.',
  },
  'vocabNoOriginals': {
    'zh-Hans': '本卷尚无原文标注文本。',
    'zh-Hant': '本卷尚無原文標註文本。',
    'en': 'No tagged original-language text for this book yet.',
  },
  'vocabCardsToGo': {'zh-Hans': '张待背', 'zh-Hant': '張待背', 'en': 'cards to go'},
  'vocabGlossFirst': {
    'zh-Hans': '先看词义',
    'zh-Hant': '先看詞義',
    'en': 'Gloss first',
  },
  'vocabDrillStart': {'zh-Hans': '开始背诵', 'zh-Hant': '開始背誦', 'en': 'Start drill'},
  'vocabDrillRestart': {'zh-Hans': '再来一轮', 'zh-Hant': '再來一輪', 'en': 'Go again'},
  'vocabDrillKnew': {'zh-Hans': '记得', 'zh-Hant': '記得', 'en': 'Knew it'},
  'vocabDrillMissed': {'zh-Hans': '忘了', 'zh-Hant': '忘了', 'en': 'Missed'},
  'vocabDrillSkip': {'zh-Hans': '跳过', 'zh-Hant': '跳過', 'en': 'Skip'},
  'vocabTapReveal': {'zh-Hans': '点一下看答案', 'zh-Hant': '點一下看答案', 'en': 'Tap to reveal'},
  'vocabMarkLearned': {'zh-Hans': '已学会', 'zh-Hant': '已學會', 'en': 'Learned'},
  'vocabFirstTime': {'zh-Hans': '一次答对', 'zh-Hant': '一次答對', 'en': 'first time'},
  'vocabAllLearned': {
    'zh-Hans': '此词表已全部标为学会。',
    'zh-Hant': '此詞表已全部標為學會。',
    'en': 'Every word in this deck is marked learned.',
  },
  'vocabMinList': {'zh-Hans': '用到', 'zh-Hant': '用到', 'en': 'Uses'},
  'vocabMaxUnknown': {'zh-Hans': '生字', 'zh-Hant': '生字', 'en': 'Unknown'},
  'vocabReadEmpty': {
    'zh-Hans': '本卷暂无可凭此词表通读的经文。可减少「用到」的词数，或容许一两个生字。',
    'zh-Hant': '本卷暫無可憑此詞表通讀的經文。可減少「用到」的詞數，或容許一兩個生字。',
    'en': 'No verse in this book is readable with this deck yet. Ask for '
        'fewer list words, or allow an unknown word or two.',
  },

  // ====== Small-screen advisory ======
  // Shown once, on phone-sized viewports, then dismissible forever.
  // Tone matters here: this is information, not a scolding and not an
  // error. It states what the layout needs and what this screen is,
  // and lets the reader overrule it.
  'fitTitle': {
    'zh-Hans': 'SeekSparks 是研经工作台',
    'zh-Hant': 'SeekSparks 是研經工作檯',
    'en': 'SeekSparks is a study workbench',
  },
  'fitLead': {
    'zh-Hans': '搜索、经文、字词分析三栏并排在同一屏上。这种并排本身就是工具，'
        '不是装饰——把它压成一栏，就只剩一个读经器了。',
    'zh-Hant': '搜尋、經文、字詞分析三欄並排在同一畫面上。這種並排本身就是工具，'
        '不是裝飾——把它壓成一欄，就只剩一個讀經器了。',
    'en': 'Search, the text, and word analysis sit side by side — three '
        'columns on one screen. The side-by-side is the tool, not '
        'decoration; squeezed to one column it is just a reader.',
  },
  'fitNeeds': {
    'zh-Hans': '三栏需要约 {three} px 宽度。这块屏幕是 {w} × {h}。',
    'zh-Hant': '三欄需要約 {three} px 寬度。這塊螢幕是 {w} × {h}。',
    'en': 'Three columns need about {three} px of width. '
        'This screen is {w} × {h}.',
  },
  // 2026-08-17 (#316): says ONE thing, and only what the branch that
  // selects it has already proved.
  //
  // `WorkbenchAdvice.rotate` is returned exclusively when
  // `paneCountFor(height) >= 3` — i.e. the long edge genuinely carries
  // the whole workbench. It is therefore never right to add "and a
  // phone is too narrow anyway, use a tablet" here, which is what the
  // two Chinese strings did until now: rotate and you get three
  // columns, and also go and find another device. In one sentence.
  //
  // It survived because the copy was written for the TWO-column rule
  // and only the English was rewritten when the bar rose to three on
  // 2026-08-07 (46bc7e5). A string that exists three times can be wrong
  // in one language only, and a Mi Pad at 949 × 1375 — a device that
  // works perfectly the moment it is turned — was told to go away.
  'fitRotate': {
    'zh-Hans': '把设备横过来，完整的三栏工作台就会打开。',
    'zh-Hant': '把裝置橫過來，完整的三欄工作檯就會打開。',
    'en': 'Turn the device sideways and the full three-column workbench '
        'opens.',
  },
  // The rotate variant of `fitNeeds`. Same figures, plus the one that
  // settles it: the long edge, which is what the reader gets by
  // turning the device. Proving the claim with the device's own
  // numbers is what the original line does, and the rotate case is
  // exactly where that proof is most worth having.
  'fitRotateNeeds': {
    'zh-Hans': '三栏需要约 {three} px 宽度。这块屏幕是 {w} × {h}，横过来就有 {long} px。',
    'zh-Hant': '三欄需要約 {three} px 寬度。這塊螢幕是 {w} × {h}，橫過來就有 {long} px。',
    'en': 'Three columns need about {three} px of width. This screen is '
        '{w} × {h} — sideways that is {long} px.',
  },
  // The YsWords sentence lives in `fitYsWords` below and is rendered
  // right underneath this line, so repeating it here (as both Chinese
  // variants did) said it twice and left the English saying it once.
  'fitLarger': {
    'zh-Hans': '这块屏幕在任何方向都放不下三栏。SeekSparks 需要平板或电脑。',
    'zh-Hant': '這塊螢幕在任何方向都放不下三欄。SeekSparks 需要平板或電腦。',
    'en': 'This screen does not fit three columns in either direction. '
        'SeekSparks needs a tablet or a laptop.',
  },
  'fitYsWords': {
    'zh-Hans': '若只是在手机上读经，YsWords 正是为此而生——同一家族，手机优先。',
    'zh-Hant': '若只是在手機上讀經，YsWords 正是為此而生——同一家族，手機優先。',
    'en': 'For reading on a phone, YsWords is built for exactly that — same '
        'family, phone-first.',
  },
  // The same recommendation, demoted, for the rotate case. This device
  // is not too small; it is merely held the wrong way round, so
  // "SeekSparks needs a bigger screen than yours" would be false here.
  // What remains true is that reading in portrait is a real preference,
  // and that there is a phone-first reader in the family for it.
  'fitYsWordsAside': {
    'zh-Hans': '若想竖着读，同一家族的 YsWords 是为此而生的手机读经器。',
    'zh-Hant': '若想直向閱讀，同一家族的 YsWords 是為此而生的手機讀經器。',
    'en': 'Prefer to read in portrait? YsWords is the phone-first reader in '
        'the same family.',
  },
  'fitOpenYsWords': {
    'zh-Hans': '打开 YsWords',
    'zh-Hant': '開啟 YsWords',
    'en': 'Open YsWords',
  },
  'fitContinue': {
    'zh-Hans': '仍然继续',
    'zh-Hant': '仍然繼續',
    'en': 'Continue anyway',
  },
  'fitContinueNote': {
    'zh-Hans': '此提示只出现这一次。',
    'zh-Hant': '此提示只會出現這一次。',
    'en': 'This only appears once.',
  },

  // Morphological search (bwh17 / the Graphical Search Engine).
  'analysisTabMorphology': {
    'zh-Hans': '词形',
    'zh-Hant': '詞形',
    'en': 'Forms',
  },
  // 2026-08-07: Eagle's View's Modern Concordance. 主题 rather than
  // 汇编/索引 — the tab answers "what subject does the concordance file
  // this verse under", and 主题 is the word a Chinese reader would use
  // for that, where 索引 would suggest a bare reference list.
  'analysisTabTopics': {
    'zh-Hans': '主题',
    'zh-Hant': '主題',
    'en': 'Topics',
  },

  // ====== Context tab (BibleWorks bwh10h) ======
  // 语境 rather than 上下文: the tab is about the vocabulary of the
  // surrounding passage, which is what 语境 names, where 上下文 would
  // suggest the neighbouring verses themselves.
  'analysisTabContext': {
    'zh-Hans': '语境',
    'zh-Hant': '語境',
    'en': 'Context',
  },
  'contextScopePericope': {
    'zh-Hans': '段落',
    'zh-Hant': '段落',
    'en': 'Pericope',
  },
  'contextScopeChapter': {
    'zh-Hans': '本章',
    'zh-Hant': '本章',
    'en': 'Chapter',
  },
  'contextScopeBook': {
    'zh-Hans': '全卷',
    'zh-Hant': '全卷',
    'en': 'Book',
  },
  'contextSortDistinctive': {
    'zh-Hans': '本段特有',
    'zh-Hant': '本段特有',
    'en': 'Distinctive',
  },
  'contextSortFrequency': {
    'zh-Hans': '最常见',
    'zh-Hant': '最常見',
    'en': 'Frequent',
  },
  'contextSortRarity': {
    'zh-Hans': '最罕见',
    'zh-Hant': '最罕見',
    'en': 'Rare',
  },
  'contextCounts': {
    'zh-Hans': '{verses} 节 · {words} 词 · {distinct} 个不同词',
    'zh-Hant': '{verses} 節 · {words} 詞 · {distinct} 個不同詞',
    'en': '{verses} verses · {words} words · {distinct} distinct',
  },
  'contextIncludeFunction': {
    'zh-Hans': '同时显示虚词（冠词、介词、连词）',
    'zh-Hant': '同時顯示虛詞（冠詞、介詞、連詞）',
    'en': 'Include grammar words (articles, prepositions, conjunctions)',
  },
  'contextOnlyHere': {
    'zh-Hans': '仅此处',
    'zh-Hant': '僅此處',
    'en': 'only here',
  },
  'contextOpenLexicon': {
    'zh-Hans': '原文词条',
    'zh-Hant': '原文詞條',
    'en': 'Lexicon entry',
  },
  'contextNone': {
    'zh-Hans': '本段没有随附的原文经文。',
    'zh-Hant': '本段沒有隨附的原文經文。',
    'en': 'No original-language text is bundled for this passage.',
  },
  'concordanceNoEntries': {
    'zh-Hans': '现代汇编只收录新约；本节没有条目。',
    'zh-Hant': '現代彙編只收錄新約；本節沒有條目。',
    'en': 'The Modern Concordance covers the New Testament; '
        'this verse has no entry.',
  },
  'morphSeed': {'zh-Hans': '此词词形', 'zh-Hant': '此詞詞形', 'en': 'This word'},
  'morphClear': {'zh-Hans': '清除', 'zh-Hant': '清除', 'en': 'Clear'},
  'morphAnyForm': {
    'zh-Hans': '未限定词形 — 选择下方任一条件',
    'zh-Hant': '未限定詞形 — 選擇下方任一條件',
    'en': 'Any form — pick a feature below',
  },
  'morphScopeOt': {'zh-Hans': '旧约', 'zh-Hant': '舊約', 'en': 'OT'},
  'morphScopeNt': {'zh-Hans': '新约', 'zh-Hant': '新約', 'en': 'NT'},
  'morphNoHits': {
    'zh-Hans': '此范围内没有这种词形的词。',
    'zh-Hant': '此範圍內沒有這種詞形的詞。',
    'en': 'No word in this range has that form.',
  },
  'morphMore': {
    'zh-Hans': '仅显示前 {n} 个。',
    'zh-Hant': '僅顯示前 {n} 個。',
    'en': 'Showing the first {n}.',
  },
  'morphNoOriginals': {
    'zh-Hans': '本卷没有原文标注，无法按词形搜索。',
    'zh-Hant': '本卷沒有原文標註，無法按詞形搜尋。',
    'en': 'This book has no tagged original text to search.',
  },
  // ── Phrasing (lib/utils/phrasing.dart, lib/pages/phrasing_page.dart) ──
  'phrasingTitle': {'zh-Hans': '语法分行', 'zh-Hant': '語法分行', 'en': 'Phrasing'},
  'phrasingCopied': {'zh-Hans': '已复制', 'zh-Hant': '已複製', 'en': 'Copied'},
  'phrasingCopiedRich': {
    'zh-Hans': '已复制，格式一并带上',
    'zh-Hant': '已複製，格式一併帶上',
    'en': 'Copied with its formatting',
  },
  'phrasingCopiedPlain': {
    'zh-Hans': '已复制为纯文本 — 缩进与下划线未能保留',
    'zh-Hant': '已複製為純文字 — 縮排與底線未能保留',
    'en': 'Copied as plain text — the indentation was lost',
  },
  'phrasingMember': {
    'zh-Hans': '平行成分 (a) (b)',
    'zh-Hant': '平行成分 (a) (b)',
    'en': 'Parallel member (a) (b)',
  },
  'phrasingMemberHint': {
    'zh-Hans': '同一缩进层上连续的成分按顺序编号。',
    'zh-Hant': '同一縮排層上連續的成分按順序編號。',
    'en': 'Letters run in order down each run of members at the same indent.',
  },
  'phrasingEmphasis': {
    'zh-Hans': '为这一行加下划线',
    'zh-Hant': '為這一行加底線',
    'en': 'Underline this line',
  },
  'phrasingReset': {
    'zh-Hans': '重新开始',
    'zh-Hant': '重新開始',
    'en': 'Start over',
  },
  'phrasingRange': {'zh-Hans': '经节', 'zh-Hant': '經節', 'en': 'Verses'},
  'phrasingSnapSentence': {
    'zh-Hans': '整句',
    'zh-Hant': '整句',
    'en': 'Sentence',
  },
  'phrasingSnapSentenceTip': {
    'zh-Hans': '把范围扩到起始那一节所在的整个句子',
    'zh-Hant': '把範圍擴到起始那一節所在的整個句子',
    'en': 'Widen the window to the whole sentence the first verse is in',
  },
  'phrasingNoStops': {
    'zh-Hans': '这个文本没有句号一类的断句标点，范围无法扩到一节以外。',
    'zh-Hant': '這個文本沒有句號一類的斷句標點，範圍無法擴到一節以外。',
    'en': 'This text prints no sentence punctuation, so the window cannot be '
        'widened past one verse.',
  },
  'phrasingSentenceOwn': {
    'zh-Hans': '第 {a}–{b} 节在 {e} 里是一整句。',
    'zh-Hant': '第 {a}–{b} 節在 {e} 裡是一整句。',
    'en': 'Verses {a}–{b} are one sentence in {e}.',
  },
  'phrasingSentenceBorrowed': {
    'zh-Hans': '第 {a}–{b} 节在 {e} 里是一整句。原文没有断句标点，'
        '这个界线是该译本的判断。',
    'zh-Hant': '第 {a}–{b} 節在 {e} 裡是一整句。原文沒有斷句標點，'
        '這個界線是該譯本的判斷。',
    'en': 'Verses {a}–{b} are one sentence in {e}. The original prints no '
        'stops, so the bounds are that edition’s.',
  },
  'phrasingSentenceLong': {
    'zh-Hans': '第 {v} 节属于 {e} 里一个长达 {n} 节的句子（{a}–{b}）——'
        '这么长通常是名单，不是一句话。',
    'zh-Hant': '第 {v} 節屬於 {e} 裡一個長達 {n} 節的句子（{a}–{b}）——'
        '這麼長通常是名單，不是一句話。',
    'en': 'Verse {v} is inside a {n}-verse sentence in {e} ({a}–{b}) — long '
        'enough that it is a list, not a period.',
  },
  'phrasingSentenceOpenAnyway': {
    'zh-Hans': '仍然打开',
    'zh-Hant': '仍然開啟',
    'en': 'Open it anyway',
  },
  'phrasingNone': {
    'zh-Hans': '本章没有可供分行的经文。若已选「原文」，可改选「译本」。',
    'zh-Hant': '本章沒有可供分行的經文。若已選「原文」，可改選「譯本」。',
    'en': 'No text is available for this chapter. If you chose the original, '
        'try the translation instead.',
  },
  'phrasingSourceVersion': {
    'zh-Hans': '译本',
    'zh-Hant': '譯本',
    'en': 'Translation',
  },
  'phrasingSourceOriginals': {
    'zh-Hans': '原文',
    'zh-Hant': '原文',
    'en': 'Original',
  },
  'phrasingNoTags': {
    'zh-Hans': '此版本没有语法解析，也没有编号，只能按节断行——分行由你决定。'
        '若要语法建议，请改用原文。',
    'zh-Hant': '此版本沒有語法解析，也沒有編號，只能按節斷行——分行由你決定。'
        '若要語法建議，請改用原文。',
    'en': 'This edition carries no grammar and no Strong’s numbers, so only '
        'verse breaks are proposed — the lines are yours to draw. Switch to '
        'the original for a grammatical proposal.',
  },
  'phrasingNoParse': {
    'zh-Hans': '此版本没有语法解析，只能依据编号建议断行。若要分出分词和不定式，请改用原文。',
    'zh-Hant': '此版本沒有語法解析，只能依據編號建議斷行。若要分出分詞和不定式，請改用原文。',
    'en': 'This edition carries no grammatical parse, so only the joints a '
        'Strong’s number can name are proposed. Switch to the original for '
        'participles and infinitives.',
  },
  'phrasingEmptyWindow': {
    'zh-Hans': '此范围内没有经节。',
    'zh-Hant': '此範圍內沒有經節。',
    'en': 'No verses in this range.',
  },
  'phrasingHint': {
    'zh-Hans': '点按一个词，可在它前面另起一行；点按一行的第一个词，可把它并回上一行。'
        '用 ◀ ▶ 调整缩进——缩进的行从属于上面那一行。点按行首的标记按钮，可标注关系、'
        '把这一行标为平行成分，或为它加下划线。长按一个词可查看它的词法解析。',
    'zh-Hant': '點按一個詞，可在它前面另起一行；點按一行的第一個詞，可把它併回上一行。'
        '用 ◀ ▶ 調整縮排——縮排的行從屬於上面那一行。點按行首的標註按鈕，可標註關係、'
        '把這一行標為平行成分，或為它加底線。長按一個詞可檢視它的詞法解析。',
    'en': 'Tap a word to start a new line before it; tap the first word of a '
        'line to join it back up. Use ◀ ▶ to indent — an indented line is '
        'subordinate to the line above it. The label button on a line names '
        'its relation, marks it as a parallel member, or underlines it. '
        'Long-press a word for its full parse.',
  },
  'phrasingRelNone': {'zh-Hans': '不标注', 'zh-Hant': '不標註', 'en': 'No label'},
  'phrasingSuggested': {
    'zh-Hans': '语法建议',
    'zh-Hant': '語法建議',
    'en': 'Suggested by the grammar',
  },
  'phrasingFooterIdle': {
    'zh-Hans': '长按一个词查看词法解析（也可将鼠标指向它）。',
    'zh-Hant': '長按一個詞檢視詞法解析（也可將滑鼠指向它）。',
    'en': 'Long-press a word for its parse — or point at it with a mouse.',
  },
  'phrasingUnpin': {'zh-Hans': '取消', 'zh-Hant': '取消', 'en': 'Release'},
  'phrasingGlossShow': {
    'zh-Hans': '显示对照行',
    'zh-Hant': '顯示對照行',
    'en': 'Show the gloss line',
  },
  'phrasingGlossHide': {
    'zh-Hans': '隐藏对照行',
    'zh-Hant': '隱藏對照行',
    'en': 'Hide the gloss line',
  },
  'phrasingGlossFrom': {
    'zh-Hans': '对照行：%s',
    'zh-Hant': '對照行：%s',
    'en': 'Gloss line: %s',
  },
  'phrasingGlossLexicon': {
    'zh-Hans': '词典中该词条的释义',
    'zh-Hant': '詞典中該詞條的釋義',
    'en': 'the lexicon’s sense for the lemma',
  },
  'phrasingGlossItalic': {
    'zh-Hans': '斜体为%s',
    'zh-Hant': '斜體為%s',
    'en': 'italic is %s',
  },
  'phrasingLevelVerses': {'zh-Hans': '按节', 'zh-Hant': '按節', 'en': 'Verses'},
  'phrasingLevelClauses': {
    'zh-Hans': '按子句',
    'zh-Hant': '按子句',
    'en': 'Clauses',
  },
  'phrasingLevelVerbals': {
    'zh-Hans': '＋分词不定词',
    'zh-Hant': '＋分詞不定詞',
    'en': '+ Verbals',
  },
  'phrasingLevelPhrases': {
    'zh-Hans': '＋介词短语',
    'zh-Hant': '＋介詞片語',
    'en': '+ Phrases',
  },
  // The eighteen relation labels. `phrasingRelationLabel` derives each
  // key as phrasingRel + the enum name capitalised, so renaming an enum
  // value silently drops that label back to English — keep the two
  // lists in step. `phrasing_test.dart` asserts the coverage.
  'phrasingRelSeries': {'zh-Hans': '并列', 'zh-Hant': '並列', 'en': 'series'},
  'phrasingRelProgression': {
    'zh-Hans': '递进',
    'zh-Hant': '遞進',
    'en': 'progression',
  },
  'phrasingRelContrast': {'zh-Hans': '对比', 'zh-Hant': '對比', 'en': 'contrast'},
  'phrasingRelAlternative': {
    'zh-Hans': '选择',
    'zh-Hant': '選擇',
    'en': 'alternative',
  },
  'phrasingRelComparison': {
    'zh-Hans': '比较',
    'zh-Hant': '比較',
    'en': 'comparison',
  },
  'phrasingRelPurpose': {'zh-Hans': '目的', 'zh-Hant': '目的', 'en': 'purpose'},
  'phrasingRelResult': {'zh-Hans': '结果', 'zh-Hant': '結果', 'en': 'result'},
  'phrasingRelGround': {'zh-Hans': '根据', 'zh-Hant': '根據', 'en': 'ground'},
  'phrasingRelInference': {
    'zh-Hans': '推论',
    'zh-Hant': '推論',
    'en': 'inference',
  },
  'phrasingRelMeans': {'zh-Hans': '手段', 'zh-Hant': '手段', 'en': 'means'},
  'phrasingRelManner': {'zh-Hans': '方式', 'zh-Hant': '方式', 'en': 'manner'},
  'phrasingRelCondition': {
    'zh-Hans': '条件',
    'zh-Hant': '條件',
    'en': 'condition',
  },
  'phrasingRelConcession': {
    'zh-Hans': '让步',
    'zh-Hant': '讓步',
    'en': 'concession',
  },
  'phrasingRelTemporal': {'zh-Hans': '时间', 'zh-Hant': '時間', 'en': 'time'},
  'phrasingRelPlace': {'zh-Hans': '地点', 'zh-Hant': '地點', 'en': 'place'},
  'phrasingRelContent': {'zh-Hans': '内容', 'zh-Hant': '內容', 'en': 'content'},
  'phrasingRelApposition': {
    'zh-Hans': '同位',
    'zh-Hant': '同位',
    'en': 'apposition',
  },
  'phrasingRelRelative': {
    'zh-Hans': '关系子句',
    'zh-Hant': '關係子句',
    'en': 'relative',
  },

  // ── Copy Center (BibleWorks bwh28 / bwh29) ────────────────────────
  'copyCenterTitle': {
    'zh-Hans': '复制中心',
    'zh-Hant': '複製中心',
    'en': 'Copy Center',
  },
  'copyCenterMenu': {'zh-Hans': '复制…', 'zh-Hant': '複製…', 'en': 'Copy…'},
  'copyCenterCopy': {'zh-Hans': '复制', 'zh-Hant': '複製', 'en': 'Copy'},
  'copyCenterPreview': {
    'zh-Hans': '输出预览',
    'zh-Hant': '輸出預覽',
    'en': 'Sample output',
  },
  'copyCenterEmpty': {
    'zh-Hans': '没有可复制的内容。',
    'zh-Hant': '沒有可複製的內容。',
    'en': 'Nothing to copy.',
  },
  'copyCenterCount': {
    'zh-Hans': '共 {n} 节',
    'zh-Hant': '共 {n} 節',
    'en': '{n} verses',
  },
  'copyCenterLimited': {
    'zh-Hans': '将复制 {total} 节中的前 {n} 节——受版权译本的引用节数上限所限。',
    'zh-Hant': '將複製 {total} 節中的前 {n} 節——受版權譯本的引用節數上限所限。',
    'en': 'Copying {n} of {total} verses — publisher quotation limit '
        'for a licensed translation.',
  },
  'copyCenterScope': {
    'zh-Hans': '复制范围',
    'zh-Hant': '複製範圍',
    'en': 'What to copy',
  },
  'copyScopeSelection': {
    'zh-Hans': '已选经节',
    'zh-Hant': '已選經節',
    'en': 'Selected verses',
  },
  'copyScopeVerse': {
    'zh-Hans': '当前经节',
    'zh-Hant': '當前經節',
    'en': 'Current verse',
  },
  'copyScopeChapter': {'zh-Hans': '本章', 'zh-Hant': '本章', 'en': 'This chapter'},
  'copyScopeResults': {
    'zh-Hans': '搜索结果',
    'zh-Hant': '搜尋結果',
    'en': 'Search results',
  },
  'copyCenterPreset': {'zh-Hans': '格式', 'zh-Hant': '格式', 'en': 'Format'},
  'copyPresetSermon': {'zh-Hans': '讲义', 'zh-Hant': '講義', 'en': 'Handout'},
  'copyPresetCitation': {'zh-Hans': '引注', 'zh-Hant': '引註', 'en': 'Citation'},
  'copyPresetRefList': {
    'zh-Hans': '仅经文出处',
    'zh-Hant': '僅經文出處',
    'en': 'References only',
  },
  'copyPresetPlain': {'zh-Hans': '纯文字', 'zh-Hant': '純文字', 'en': 'Plain text'},
  'copyPresetCustom': {'zh-Hans': '自定', 'zh-Hant': '自訂', 'en': 'Custom'},
  'copyCenterVersions': {'zh-Hans': '译本', 'zh-Hant': '譯本', 'en': 'Versions'},
  'copyCenterIncludeText': {
    'zh-Hans': '包含经文内容',
    'zh-Hant': '包含經文內容',
    'en': 'Include the verse text',
  },
  'copyCenterReference': {
    'zh-Hans': '经文出处',
    'zh-Hant': '經文出處',
    'en': 'Reference',
  },
  'copyRefPassage': {
    'zh-Hans': '整段只写一次',
    'zh-Hant': '整段只寫一次',
    'en': 'Once, for the whole passage',
  },
  'copyRefPerVerse': {
    'zh-Hans': '每节都写',
    'zh-Hant': '每節都寫',
    'en': 'On every verse',
  },
  'copyRefNone': {
    'zh-Hans': '不写出处',
    'zh-Hant': '不寫出處',
    'en': 'No reference',
  },
  'copyRefBefore': {
    'zh-Hans': '放在经文前',
    'zh-Hant': '放在經文前',
    'en': 'Before the text',
  },
  'copyRefAfter': {
    'zh-Hans': '放在经文后',
    'zh-Hant': '放在經文後',
    'en': 'After the text',
  },
  'copyBookFull': {
    'zh-Hans': '书卷全名',
    'zh-Hant': '書卷全名',
    'en': 'Full book name',
  },
  'copyBookShort': {'zh-Hans': '书卷简称', 'zh-Hant': '書卷簡稱', 'en': 'Abbreviated'},
  'copyCenterTemplate': {
    'zh-Hans': '出处格式',
    'zh-Hant': '出處格式',
    'en': 'Reference format',
  },
  'copyCenterTemplateHelp': {
    'zh-Hans': '可用标记：<ref> <book> <chapter> <verse> <version>',
    'zh-Hant': '可用標記：<ref> <book> <chapter> <verse> <version>',
    'en': 'Tags: <ref> <book> <chapter> <verse> <version>',
  },
  'copyCenterText': {'zh-Hans': '经文', 'zh-Hant': '經文', 'en': 'Text'},
  'copyCenterVerseNumbers': {
    'zh-Hans': '经文中保留节号',
    'zh-Hant': '經文中保留節號',
    'en': 'Verse numbers in the text',
  },
  'copyCenterOnePerLine': {
    'zh-Hans': '每节另起一行',
    'zh-Hant': '每節另起一行',
    'en': 'One verse per line',
  },
  'copyCenterQuote': {
    'zh-Hans': '加上引号',
    'zh-Hant': '加上引號',
    'en': 'Wrap in quotation marks',
  },
  'copyCenterBrackets': {
    'zh-Hans': '保留［补字］的方括号',
    'zh-Hant': '保留［補字］的方括號',
    'en': 'Keep [supplied words] in brackets',
  },
  'copyCenterNotes': {
    'zh-Hans': '包含译者注',
    'zh-Hant': '包含譯者註',
    'en': "Include translators' notes",
  },
  'copyCenterInterleave': {
    'zh-Hans': '按经节分组，而非按译本',
    'zh-Hant': '按經節分組，而非按譯本',
    'en': 'Group by verse, not by version',
  },
  'copyCenterRefList': {
    'zh-Hans': '出处清单',
    'zh-Hant': '出處清單',
    'en': 'Reference list',
  },
  'copyCenterMerge': {
    'zh-Hans': '连续的节合并为范围',
    'zh-Hant': '連續的節合併為範圍',
    'en': 'Merge consecutive verses into ranges',
  },
  'copyCenterRefPerLine': {
    'zh-Hans': '每处出处另起一行',
    'zh-Hant': '每處出處另起一行',
    'en': 'One reference per line',
  },
  'copyCenterAttribution': {
    'zh-Hans': '附上版权说明',
    'zh-Hant': '附上版權說明',
    'en': 'Append the copyright line',
  },

  // ── Places (task #277) ────────────────────────────────────────────
  'analysisTabPlaces': {
    'zh-Hans': '地名',
    'zh-Hant': '地名',
    'en': 'Places',
  },
  'analysisTabSermons': {
    'zh-Hans': '讲道',
    'zh-Hant': '講道',
    'en': 'Sermons',
  },

  // ── The Related Sermons tab (task #313) ──────────────────────────
  // The match is chapter-wide and every string here has to SAY so:
  // measured across the corpus, only 12.3% of the rows this list can
  // produce cite the verse the reader actually selected. A count with
  // no unit and no scope is #308 over again.
  'sermonsOnThisVerse': {
    'zh-Hans': '讲这一节',
    'zh-Hant': '講這一節',
    'en': 'Preaching this verse',
  },
  'sermonsInThisChapter': {
    'zh-Hans': '本章其他经节',
    'zh-Hant': '本章其他經節',
    'en': 'Elsewhere in this chapter',
  },
  // Four shapes of one sentence, because English agrees a verb with each
  // of its two numbers and Chinese agrees with neither — the zh entries
  // are identical on purpose, not by oversight. `sermonCountKey` picks.
  'sermonsCountWithVerse': {
    'zh-Hans': '{chapter} 共 {total} 篇讲道引用，其中 {onVerse} 篇引用 {ref}。',
    'zh-Hant': '{chapter} 共 {total} 篇講道引用，其中 {onVerse} 篇引用 {ref}。',
    'en': '{total} sermons cite {chapter} — {onVerse} of them cite {ref}.',
  },
  'sermonsCountWithVerseOne': {
    'zh-Hans': '{chapter} 共 {total} 篇讲道引用，其中 {onVerse} 篇引用 {ref}。',
    'zh-Hant': '{chapter} 共 {total} 篇講道引用，其中 {onVerse} 篇引用 {ref}。',
    'en': '{total} sermons cite {chapter} — 1 of them cites {ref}.',
  },
  'sermonsCountOnlyOne': {
    'zh-Hans': '{chapter} 共 {total} 篇讲道引用，其中 {onVerse} 篇引用 {ref}。',
    'zh-Hant': '{chapter} 共 {total} 篇講道引用，其中 {onVerse} 篇引用 {ref}。',
    'en': 'One sermon cites {chapter}, and it is on {ref}.',
  },
  'sermonsCountChapter': {
    'zh-Hans': '{chapter} 共 {total} 篇讲道引用。',
    'zh-Hant': '{chapter} 共 {total} 篇講道引用。',
    'en': '{total} sermons cite {chapter}.',
  },
  'sermonsCountChapterOne': {
    'zh-Hans': '{chapter} 共 {total} 篇讲道引用。',
    'zh-Hant': '{chapter} 共 {total} 篇講道引用。',
    'en': 'One sermon cites {chapter}.',
  },
  'sermonsCites': {
    'zh-Hans': '引用第 {verses} 节',
    'zh-Hant': '引用第 {verses} 節',
    'en': 'cites v{verses}',
  },
  'sermonsCitesChapter': {
    'zh-Hans': '只引用整章',
    'zh-Hant': '只引用整章',
    'en': 'cites the chapter, no verse',
  },
  'sermonsNone': {
    'zh-Hans': '讲道集中没有引用 {ref} 的讲道。',
    'zh-Hant': '講道集中沒有引用 {ref} 的講道。',
    'en': 'No sermon in the library cites {ref}.',
  },

  // ── The Analysis strip's names/icons toggle (task #297) ───────────
  // The tooltip names what the tap will DO, so the two states read as
  // one control rather than as a label of the state you are in.
  'analysisTabNamesShow': {
    'zh-Hans': '显示标签名称',
    'zh-Hant': '顯示標籤名稱',
    'en': 'Show tab names',
  },
  'analysisTabNamesAuto': {
    'zh-Hans': '标签名称：自动',
    'zh-Hant': '標籤名稱：自動',
    'en': 'Tab names: automatic',
  },
  'placesInThisVerse': {
    'zh-Hans': '本节地名',
    'zh-Hant': '本節地名',
    'en': 'Named in this verse',
  },
  'placesInThisChapter': {
    'zh-Hans': '本章其他地名',
    'zh-Hant': '本章其他地名',
    'en': 'Elsewhere in this chapter',
  },
  'placesNone': {
    'zh-Hans': '这一章没有提到地名录收录的地名。',
    'zh-Hant': '這一章沒有提到地名錄收錄的地名。',
    'en': 'This chapter names no place in the gazetteer.',
  },
  'placesUnlocated': {
    'zh-Hans': '位置不详',
    'zh-Hant': '位置不詳',
    'en': 'location unknown',
  },
  'placesOccurrences': {
    'zh-Hans': '处',
    'zh-Hant': '處',
    'en': 'refs',
  },
  'placesShowMap': {
    'zh-Hans': '在地图上查看',
    'zh-Hant': '在地圖上檢視',
    'en': 'Show on map',
  },
  'placesMapTitle': {
    'zh-Hans': '地图',
    'zh-Hant': '地圖',
    'en': 'Map',
  },
  'placesMapClose': {
    'zh-Hans': '关闭地图',
    'zh-Hant': '關閉地圖',
    'en': 'Close map',
  },
  'placesMapFit': {
    'zh-Hans': '复位',
    'zh-Hant': '復位',
    'en': 'Fit',
  },
  'placesMapUnlocatedCount': {
    // {n} is substituted. These places are unlocated because nobody
    // knows where they are — Eden, Nod, the Pishon — so the map says so
    // rather than quietly dropping them.
    'zh-Hans': '另有 {n} 个地名位置不详，无法标示',
    'zh-Hant': '另有 {n} 個地名位置不詳，無法標示',
    'en': '{n} more named here have no known location',
  },
  'placesMapDays': {
    'zh-Hans': '约 {n} 天脚程',
    'zh-Hant': '約 {n} 天腳程',
    'en': 'about {n} days on foot',
  },
  'placesMapHint': {
    'zh-Hans': '滚轮缩放，拖动平移，点选地名量距。',
    'zh-Hant': '滾輪縮放，拖曳平移，點選地名量距。',
    'en': 'Scroll to zoom, drag to pan, tap a place to measure.',
  },
  'placesMapShort': {
    'zh-Hans': '地图',
    'zh-Hant': '地圖',
    'en': 'Map',
  },

  // ── The Atlas (task #279 / DELETION-REVIEW §4) ────────────────────
  // Deliberately NOT the existing 'maps' key, which is this app's word
  // for the illustration set (插图) and would collide.
  'atlasTitle': {
    'zh-Hans': '圣经地图集',
    'zh-Hant': '聖經地圖集',
    'en': 'Bible Atlas',
  },
  'atlasSearchHint': {
    // Says "or Chinese" because it is not obvious that an English-only
    // gazetteer can be searched in Chinese, and it can.
    'zh-Hans': '搜索地名（中英文皆可）',
    'zh-Hant': '搜尋地名（中英文皆可）',
    'en': 'Search a place name',
  },
  'atlasSortRefs': {
    'zh-Hans': '按次数',
    'zh-Hant': '按次數',
    'en': 'Refs',
  },
  'atlasSortName': {
    // Sorted on the ENGLISH name in every locale: sorting Han characters
    // by code point produces an order no reader recognises.
    'zh-Hans': '按字母',
    'zh-Hant': '按字母',
    'en': 'A–Z',
  },
  'atlasCount': {
    'zh-Hans': '{n} 个地名',
    'zh-Hant': '{n} 個地名',
    'en': '{n} places',
  },
  'atlasNoMatch': {
    'zh-Hans': '地名录中没有匹配的地名。',
    'zh-Hant': '地名錄中沒有匹配的地名。',
    'en': 'No place in the gazetteer matches.',
  },
  'atlasSubjectFilter': {
    'zh-Hans': '只看 {name}',
    'zh-Hant': '只看 {name}',
    'en': 'Showing {name}',
  },
  'atlasSubjectClear': {
    'zh-Hans': '显示全部地名',
    'zh-Hant': '顯示全部地名',
    'en': 'Show every place',
  },
  'atlasRefsHeader': {
    'zh-Hans': '经文出处 {n} 处',
    'zh-Hant': '經文出處 {n} 處',
    'en': '{n} references',
  },
  // #320. "Naming it" and not "of it" is the measured claim: the plates
  // are joined by a caption match gated on chapter, so what they share
  // with the place is its NAME. Saying "pictures of Bethlehem" would
  // promise a curation the corpus does not carry.
  'atlasIllusHeader': {
    'zh-Hans': '提及此地的插图 {n} 张',
    'zh-Hant': '提及此地的插畫 {n} 張',
    'en': '{n} illustrations naming it',
  },
  // Names the scope rather than calling it "the current scope": a
  // message about a filter that will not say which filter leaves the
  // reader to guess what it was they set (#280).
  'atlasNotNamedInScope': {
    'zh-Hans': '{scope} 中没有提到这个地名。',
    'zh-Hant': '{scope} 中沒有提到這個地名。',
    'en': 'Not named in {scope}.',
  },
  'atlasRefsElsewhere': {
    'zh-Hans': '{scope} 以外另有 {n} 处',
    'zh-Hant': '{scope} 以外另有 {n} 處',
    'en': '{n} more outside {scope}',
  },
  'atlasClearScope': {
    'zh-Hans': '清除筛选',
    'zh-Hant': '清除篩選',
    'en': 'Clear the filter',
  },
  // The map's layer control. Carries the count so it can be read against
  // the index header's own `12 / 1271` and seen to be the same filter.
  'atlasContextShow': {
    'zh-Hans': '显示其余 {n} 处',
    'zh-Hant': '顯示其餘 {n} 處',
    'en': 'Show {n} others',
  },
  'atlasContextHide': {
    'zh-Hans': '隐藏其余 {n} 处',
    'zh-Hant': '隱藏其餘 {n} 處',
    'en': 'Hide {n} others',
  },
  'atlasContextTip': {
    'zh-Hans': '当前筛选之外的 {n} 个地名，浅色显示。',
    'zh-Hant': '目前篩選之外的 {n} 個地名，淺色顯示。',
    'en': '{n} places the current filter leaves out, drawn faint.',
  },
  'atlasUnlocatedNote': {
    'zh-Hans': '圣经提到这个地方，但今址不详。',
    'zh-Hant': '聖經提到這個地方，但今址不詳。',
    'en': 'Scripture names this place but its site is unidentified.',
  },
  // ── Journey overlays (#317) ─────────────────────────────────────────
  'journeysHeader': {
    'zh-Hans': '行程',
    'zh-Hant': '行程',
    'en': 'Journeys',
  },
  // The standing caution, printed wherever a route is. It is the same
  // for every route, which is why it lives here and not in the asset:
  // the asset carries what is particular to one itinerary.
  'journeysCaution': {
    'zh-Hans': '线条只是按经文给出的顺序连接各站，并不是他们走过的路。圣经记的是停留的地点，不是两地之间的道路。',
    'zh-Hant': '線條只是按經文給出的順序連接各站，並不是他們走過的路。聖經記的是停留的地點，不是兩地之間的道路。',
    'en': 'The line joins the stops in the order the text gives them. '
        'It is not the road they took — scripture names the stops, not '
        'the route between them.',
  },
  'journeysKey': {
    'zh-Hans': '实线：陆路。长虚线：水路。短虚线：经文未说明方式。点线：经文没有记他们到过此地。',
    'zh-Hant': '實線：陸路。長虛線：水路。短虛線：經文未說明方式。點線：經文沒有記他們到過此地。',
    'en': 'Solid: by land. Long dash: by sea. Short dash: the text does '
        'not say. Dots: the text does not put them here.',
  },
  'journeyShowTip': {
    'zh-Hans': '在地图上画出这条路线',
    'zh-Hant': '在地圖上畫出這條路線',
    'en': 'Draw this route on the map',
  },
  'journeyStops': {
    'zh-Hans': '{n} 站',
    'zh-Hant': '{n} 站',
    'en': '{n} stops',
  },
  'journeyProvisionalCount': {
    'zh-Hans': '其中 {n} 站为推定',
    'zh-Hant': '其中 {n} 站為推定',
    'en': '{n} provisional',
  },
  'journeyProvisionalTag': {
    'zh-Hans': '推定',
    'zh-Hant': '推定',
    'en': 'Provisional',
  },
  'journeyBasisHeader': {
    'zh-Hans': '这份行程的依据',
    'zh-Hant': '這份行程的依據',
    'en': 'Where this itinerary comes from',
  },
  // Says what the number IS in the same breath as printing it. A total
  // labelled only "km" would be read as the distance travelled, which is
  // the one thing a sum of chords is not.
  'journeyStraightLine': {
    'zh-Hans': '各站之间直线距离合计 {n} 公里；不是实际行程。',
    'zh-Hant': '各站之間直線距離合計 {n} 公里；不是實際行程。',
    'en': '{n} km in straight lines between the stops — not the distance '
        'travelled.',
  },
  'journeyLegLand': {
    'zh-Hans': '走陆路',
    'zh-Hant': '走陸路',
    'en': 'by land',
  },
  'journeyLegSea': {
    'zh-Hans': '走水路',
    'zh-Hant': '走水路',
    'en': 'by sea',
  },
  'journeyLegUnknown': {
    'zh-Hans': '经文未说明方式',
    'zh-Hant': '經文未說明方式',
    'en': 'manner not given',
  },
  'journeyUnresolved': {
    'zh-Hans': '有 {n} 站在地名录中查不到位置，线在那里断开。',
    'zh-Hant': '有 {n} 站在地名錄中查不到位置，線在那裡斷開。',
    'en': '{n} stops have no location in the gazetteer; the line breaks '
        'there.',
  },
  'journeyClose': {
    'zh-Hans': '关闭行程',
    'zh-Hant': '關閉行程',
    'en': 'Close the itinerary',
  },
};
