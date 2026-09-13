/// Strings for 投影 — the projection view (`lib/pages/projection_page.dart`),
/// the full-screen passage a church puts on the wall at the front of the
/// room.
///
/// Shaped exactly like `stripStrings` and `wheelStrings`: a
/// `Map<String, Map<String, String>>` keyed by string-key then by locale,
/// every key carrying all three of `zh-Hans`, `zh-Hant` and `en`. Kept in
/// its own file for the reason `strip_strings.dart`'s library doc gives —
/// `ui_strings.dart` is where two agents working at once collide, and a
/// new surface is exactly the kind of thing that adds twenty keys at the
/// bottom of a shared file.
///
/// A NOTE ON THE TWO CHINESE COLUMNS, following the same rule
/// `strip_strings.dart` writes down. Where a string uses no character
/// that differs between the scripts — `'投影'`, `'黑屏'`, `'下一章'` — the
/// same text stands in both columns on purpose; forcing a difference
/// where none exists is noise, not correctness. Where a character does
/// differ (节/節, 复/復, 画/畫, 译/譯, 载/載, 还/還, 开/開, 经/經, 个/個,
/// 换/換, 键/鍵, 单/單, 这/這, 笔/筆, 记/記) the Traditional column takes
/// the Traditional form throughout.
///
/// Two entries go further than a character swap, and deliberately.
/// [projectionOneWindowNote] and [projectionKeysHint] name computer
/// hardware, and the Traditional-reading audience calls a window a 視窗,
/// a screen a 螢幕, a projector a 投影機, a laptop a 筆電 and the space bar
/// the 空白鍵. Transliterating 窗口 / 屏幕 / 投影仪 / 笔记本 / 空格 into
/// Traditional characters would be Simplified vocabulary in a
/// Traditional coat — legible, and not what anyone in the room says.
/// 筆記本 is the sharpest case: converted character by character it is a
/// perfectly good Traditional word that means a paper notepad.
library;

const Map<String, Map<String, String>> projectionStrings = {
  // ── the view itself ────────────────────────────────────────────────

  'projectionTitle': {
    'zh-Hans': '投影',
    'zh-Hant': '投影',
    'en': 'Projection',
  },

  /// Leaving is Esc, and it is the one control that must never be hard
  /// to find: an operator who cannot get out in front of a congregation
  /// is stuck in front of a congregation.
  'projectionLeave': {
    'zh-Hans': '退出投影',
    'zh-Hant': '退出投影',
    'en': 'Leave projection',
  },

  // ── moving through the passage ─────────────────────────────────────

  'projectionNextVerse': {
    'zh-Hans': '下一节',
    'zh-Hant': '下一節',
    'en': 'Next verse',
  },
  'projectionPreviousVerse': {
    'zh-Hans': '上一节',
    'zh-Hant': '上一節',
    'en': 'Previous verse',
  },
  'projectionNextChapter': {
    'zh-Hans': '下一章',
    'zh-Hant': '下一章',
    'en': 'Next chapter',
  },
  'projectionPreviousChapter': {
    'zh-Hans': '上一章',
    'zh-Hant': '上一章',
    'en': 'Previous chapter',
  },

  // ── the blank key ──────────────────────────────────────────────────
  //
  // Two strings rather than one toggle label, because the button says
  // what pressing it WILL DO and those are two different sentences.

  'projectionBlank': {
    'zh-Hans': '黑屏',
    'zh-Hant': '黑屏',
    'en': 'Black out',
  },
  'projectionUnblank': {
    'zh-Hans': '恢复画面',
    'zh-Hant': '恢復畫面',
    'en': 'Show the passage',
  },

  // ── the projection type scale ──────────────────────────────────────
  //
  // Same wording as `stripStrings['stripTypeBigger']` / `stripTypeSmaller`
  // — one app should not have two ways of saying "make the letters
  // bigger". What is different here is WHOSE size it is: the strip's
  // control moves type the reader is reading, this one moves type a
  // room forty feet away is reading, and the two must not be the same
  // number. See `kProjectionTypeSteps`.

  'projectionTypeBigger': {
    'zh-Hans': '字大一点',
    'zh-Hant': '字大一點',
    'en': 'Larger type',
  },
  'projectionTypeSmaller': {
    'zh-Hans': '字小一点',
    'zh-Hant': '字小一點',
    'en': 'Smaller type',
  },

  // ── the second edition ─────────────────────────────────────────────
  //
  // Worded as "a second edition", not "parallel mode": on the wall there
  // are two blocks of text, and the congregation reading the lower one
  // has no idea the app calls its stack a Browse stack.

  'projectionSecondVersionShow': {
    'zh-Hans': '加第二译本',
    'zh-Hant': '加第二譯本',
    'en': 'Add a second edition',
  },
  'projectionSecondVersionHide': {
    'zh-Hans': '只留一个译本',
    'zh-Hant': '只留一個譯本',
    'en': 'One edition only',
  },
  'projectionSecondVersionLoading': {
    'zh-Hans': '正在载入第二译本',
    'zh-Hant': '正在載入第二譯本',
    'en': 'Loading the second edition',
  },

  /// 2026-09-09 — 「两个经文也不能调整」. The switch that adds a second
  /// edition shipped without a way to say WHICH, because the projection
  /// silently borrowed Split View's saved second column. This is the
  /// button that asks the question out loud.
  'projectionSecondVersionPick': {
    'zh-Hans': '选第二译本',
    'zh-Hant': '選第二譯本',
    'en': 'Choose the second edition',
  },

  /// Shown in place of the second block when the edition is on but has
  /// no text for this reference — an NT-only edition under an Old
  /// Testament reading, which the catalog genuinely ships (see
  /// `bible_versions.dart` on the LJK editions). Silence there would
  /// look like a bug in front of a congregation.
  'projectionSecondVersionMissing': {
    'zh-Hans': '这个译本没有这处经文',
    'zh-Hant': '這個譯本沒有這處經文',
    'en': 'This edition has no text here',
  },

  // ── the ground, and the four darks ─────────────────────────────────
  //
  // Named for what the operator SEES, not for the mechanism. 「渐变」 is
  // the exception and is deliberate: a gradient is the one option whose
  // point the name has to carry, because "深蓝" and "暖黑" describe
  // themselves and a two-stop dark does not.
  //
  // The 简/繁 columns differ only where a character does — 选/選, 译/譯,
  // 设/設, 预/預, 删/刪, 键/鍵, 变/變, 个/個 — following the rule this
  // file's library doc writes down.

  'projectionBackground': {
    'zh-Hans': '背景',
    'zh-Hant': '背景',
    'en': 'Background',
  },
  'projectionGroundDeep': {
    'zh-Hans': '深蓝',
    'zh-Hant': '深藍',
    'en': 'Deep navy',
  },
  'projectionGroundBlack': {
    'zh-Hans': '纯黑',
    'zh-Hant': '純黑',
    'en': 'Black',
  },
  'projectionGroundWarm': {
    'zh-Hans': '暖黑',
    'zh-Hant': '暖黑',
    'en': 'Warm dark',
  },
  'projectionGroundVignette': {
    'zh-Hans': '渐变',
    'zh-Hant': '漸變',
    'en': 'Gradient',
  },

  // ── saved setups ───────────────────────────────────────────────────
  //
  // 「预设」 rather than 「模板」 or 「场景」: a preset is what every
  // presentation tool in the room already calls this, and an operator
  // who has driven ProPresenter or PowerPoint knows the word.

  'projectionPresets': {
    'zh-Hans': '预设',
    'zh-Hant': '預設',
    'en': 'Saved setups',
  },
  'projectionPresetSave': {
    'zh-Hans': '保存当前设置',
    'zh-Hant': '儲存目前設定',
    'en': 'Save this setup',
  },
  'projectionPresetSaveTitle': {
    'zh-Hans': '给这套设置起个名字',
    'zh-Hant': '給這套設定取個名字',
    'en': 'Name this setup',
  },
  'projectionPresetDefaultName': {
    'zh-Hans': '主日崇拜',
    'zh-Hant': '主日崇拜',
    'en': 'Sunday service',
  },
  'projectionPresetCancel': {
    'zh-Hans': '取消',
    'zh-Hant': '取消',
    'en': 'Cancel',
  },
  'projectionPresetDelete': {
    'zh-Hans': '删掉这套设置',
    'zh-Hant': '刪掉這套設定',
    'en': 'Delete this setup',
  },
  'projectionPresetNone': {
    'zh-Hans': '还没有保存过设置',
    'zh-Hant': '還沒有儲存過設定',
    'en': 'No saved setups yet',
  },

  // ── the control strip's own two edges ──────────────────────────────
  //
  // Read out loud by a screen reader and by nothing else — the chevrons
  // say the same thing with a glyph. Two strings and not one, for the
  // reason `OverflowHintScroll` records: the two chevrons do opposite
  // things and a reader who cannot see them hears only this.

  'projectionMoreControls': {
    'zh-Hans': '更多控制',
    'zh-Hant': '更多控制',
    'en': 'More controls',
  },
  'projectionPreviousControls': {
    'zh-Hans': '前面的控制',
    'zh-Hant': '前面的控制',
    'en': 'Previous controls',
  },

  // ── the empty state ────────────────────────────────────────────────

  'projectionNoPassage': {
    'zh-Hans': '还没有打开经文',
    'zh-Hant': '還沒有打開經文',
    'en': 'No passage is open',
  },

  // ── the two lines of standing instruction ──────────────────────────

  /// The honest answer to "how do I get this onto the projector and keep
  /// the controls on my laptop", which is the question every operator
  /// asks and which this version answers with "you don't". The full
  /// reasoning is in `projection_page.dart`'s library doc; this is the
  /// one sentence that reaches the person standing at the laptop.
  'projectionOneWindowNote': {
    'zh-Hans': '这是单窗口投影：把这个窗口拖到投影仪那块屏幕上，人站在笔记本前用键盘操作。',
    'zh-Hant': '這是單視窗投影：把這個視窗拖到投影機那塊螢幕上，人站在筆電前用鍵盤操作。',
    'en': 'One window: put this window on the projector display and drive it '
        'from the laptop keyboard.',
  },

  /// 2026-09-09: three keys added — G steps the ground, V opens the
  /// edition strip, R opens the saved setups. Mnemonic in English and
  /// therefore not in Chinese, which is why the line names the LETTER
  /// and then says what it does: an operator reading the 简体 line still
  /// has a QWERTY keyboard under their hands.
  'projectionKeysHint': {
    'zh-Hans': '方向键 / 空格换节 · PgUp PgDn 换章 · B 黑屏 · '
        'G 换背景 · V 选译本 · R 预设 · Esc 退出',
    'zh-Hant': '方向鍵 / 空白鍵換節 · PgUp PgDn 換章 · B 黑屏 · '
        'G 換背景 · V 選譯本 · R 預設 · Esc 退出',
    'en': 'Arrows / Space change verse · PgUp PgDn change chapter · '
        'B blacks out · G changes the ground · V picks the second '
        'edition · R saved setups · Esc leaves',
  },
  // 2026-09-13: the follower window. Web only.
  'projectionOpenStage': {
    'zh-Hans': '打开投影窗口（拖到投影仪屏幕上）',
    'zh-Hant': '開啟投影視窗（拖到投影機螢幕上）',
    'en': 'Open the projector window (drag it to the projector display)',
  },
  // 2026-09-13: the order of service and the countdown. 程序 is what a
  // Chinese-speaking church prints on the sheet; VideoPsalm calls the
  // first of these an agenda.
  'projectionAgenda': {
    'zh-Hans': '程序（聚会顺序）',
    'zh-Hant': '程序（聚會順序）',
    'en': 'Order of service',
  },
  'projectionAgendaNone': {
    'zh-Hans': '还没有程序',
    'zh-Hant': '還沒有程序',
    'en': 'No order of service yet',
  },
  'projectionAgendaAddCurrent': {
    'zh-Hans': '加入墙上这段',
    'zh-Hant': '加入牆上這段',
    'en': 'Add what is on the wall',
  },
  'projectionAgendaAddBlank': {
    'zh-Hans': '加一个黑屏',
    'zh-Hant': '加一個黑屏',
    'en': 'Add a blank',
  },
  'projectionAgendaRemove': {'zh-Hans': '移除', 'zh-Hant': '移除', 'en': 'Remove'},
  'projectionAgendaNext': {
    'zh-Hans': '下一个：{item}',
    'zh-Hant': '下一個：{item}',
    'en': 'Next: {item}',
  },
  'projectionAgendaEnd': {
    'zh-Hans': '程序到此为止',
    'zh-Hant': '程序到此為止',
    'en': 'end of the order',
  },
  'projectionCountdown': {'zh-Hans': '倒计时', 'zh-Hant': '倒數計時', 'en': 'Countdown'},
  'projectionCountdownMinutes': {
    'zh-Hans': '{n} 分钟',
    'zh-Hant': '{n} 分鐘',
    'en': '{n} minutes',
  },
  'projectionCountdownSoon': {
    'zh-Hans': '聚会还有',
    'zh-Hant': '聚會還有',
    'en': 'The service begins in',
  },
  'projectionCountdownNow': {
    'zh-Hans': '就要开始了',
    'zh-Hant': '就要開始了',
    'en': 'We are beginning',
  },
  // The wall's layout — four independent choices, added 2026-09-13
  // when the owner asked for "middle aligned, verse by verse 还是连在
  // 一起, plain text, include ref, devotional format".
  'projectionAlign': {'zh-Hans': '对齐', 'zh-Hant': '對齊', 'en': 'Alignment'},
  'projectionAlignCentre': {
    'zh-Hans': '居中',
    'zh-Hant': '置中',
    'en': 'Centred',
  },
  'projectionAlignStart': {
    // NOT 「靠左」: a Hebrew passage starts on the right.
    'zh-Hans': '顶头对齐',
    'zh-Hant': '頂頭對齊',
    'en': 'From the margin',
  },
  'projectionFlow': {'zh-Hans': '经文排法', 'zh-Hant': '經文排法', 'en': 'Verses'},
  'projectionFlowVerseByVerse': {
    'zh-Hans': '一节一行',
    'zh-Hant': '一節一行',
    'en': 'Verse by verse',
  },
  'projectionFlowContinuous': {
    'zh-Hans': '连成一段',
    'zh-Hant': '連成一段',
    'en': 'Run together',
  },
  'projectionNumbers': {
    'zh-Hans': '显示节号',
    'zh-Hant': '顯示節號',
    'en': 'Verse numbers',
  },
  'projectionReferencePlace': {
    'zh-Hans': '经文出处',
    'zh-Hant': '經文出處',
    'en': 'Reference',
  },
  'projectionReferenceCorner': {
    'zh-Hans': '放在角落',
    'zh-Hant': '放在角落',
    'en': 'In the corner',
  },
  'projectionReferenceUnder': {
    'zh-Hans': '放在经文下方',
    'zh-Hant': '放在經文下方',
    'en': 'Under the passage',
  },
  'projectionReferenceOff': {
    'zh-Hans': '不显示',
    'zh-Hant': '不顯示',
    'en': 'Not shown',
  },
  'projectionLayoutDevotionalHint': {
    'zh-Hans': '连成一段 + 关掉节号 + 出处放下方，就是灵修卡片的排法。',
    'zh-Hant': '連成一段 + 關掉節號 + 出處放下方，就是靈修卡片的排法。',
    'en': 'Run together, numbers off, reference underneath — that is the '
        'devotional setting.',
  },
  'projectionLayoutDevotionalOn': {
    'zh-Hans': '现在就是灵修排法。',
    'zh-Hant': '現在就是靈修排法。',
    'en': 'This is the devotional setting.',
  },
};
