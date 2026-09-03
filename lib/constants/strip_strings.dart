/// Strings for the horizontal chronology strip — the scrolling replacement
/// for the radial wheel (`lib/pages/radial_chronology_page.dart`), specified
/// in `docs/strip-painter-spec.md`.
///
/// Shaped exactly like `wheelStrings` (same file, near the top): a
/// `Map<String, Map<String, String>>` keyed by string-key then by locale,
/// every key carrying all three of `zh-Hans`, `zh-Hant` and `en`. Kept in
/// its own file, as `wheelStrings` is, rather than folded into
/// `ui_strings.dart` — this is a page under active construction by more than
/// one agent at once, and a shared file is where two of them collide.
///
/// This file is not wired into any widget. It exists so the page that owns
/// the strip can read strings instead of inventing them while it is built.
///
/// A NOTE ON THE TWO CHINESE COLUMNS, because this has bitten the project
/// before: `zh-Hant` is not `zh-Hans` with the characters swapped one for
/// one where a mechanical swap would do — it is checked word by word, and
/// where a string uses no character that differs between the two scripts
/// (`'事件'`, `'放大'`) the same text appears in both columns on purpose,
/// because forcing a difference where none exists is not more correct, it
/// is noise. Where a character does differ (还/還, 转/轉, 显/顯, 视/視, 与/與,
/// 犹/猶, 侧/側, 处/處, 记/記, 暂/暫, 缩/縮, 图/圖, 机/機) the Traditional
/// column uses the Traditional form throughout, not a copy of Simplified.
const Map<String, Map<String, String>> stripStrings = {
  // ── zoom + navigation ─────────────────────────────────────────────

  /// The time-axis zoom controls. The strip has only one zoom (the wheel
  /// has none at all beyond its shared `InteractiveViewer`) because lane
  /// height is a constant — see `kLaneHeight`'s own doc comment in
  /// `strip_chronology_layout.dart`. These three sit together in the
  /// toolbar the way the wheel's `_zoomControls` do.
  'stripZoomIn': {'zh-Hans': '放大', 'zh-Hant': '放大', 'en': 'Zoom in'},
  'stripZoomOut': {'zh-Hans': '缩小', 'zh-Hant': '縮小', 'en': 'Zoom out'},

  /// `pxPerYearToFit` collapsed to the whole 6226-year axis — the strip's
  /// answer to the wheel's "everything is always on screen" default.
  'stripFitAll': {
    'zh-Hans': '显示全部',
    'zh-Hant': '顯示全部',
    'en': 'Fit all',
  },

  /// Opens whatever control lets a reader type a year and scroll straight
  /// to it — `scrollToCentre`'s reason for existing. The wheel's search
  /// sheet already accepts a bare year (`wheel_search.dart`); this is the
  /// strip's lighter-weight sibling for when a reader just wants a place,
  /// not a record.
  'stripJumpToYear': {
    'zh-Hans': '跳转到年份',
    'zh-Hant': '跳轉到年份',
    'en': 'Jump to year',
  },

  // ── lane-group headings, the sticky left column ─────────────────────
  //
  // One heading per group in `docs/strip-painter-spec.md` §5. Four of the
  // five reuse the wheel's own legend wording verbatim (`wheelLifespans`,
  // `wheelKingsThiele`+kingdom, `wheelMinistries`) so a reader who already
  // knows the wheel's legend recognises the same words on the strip — the
  // two views describe the same underlying layers and should not each
  // invent their own name for one.

  'stripLaneEvents': {'zh-Hans': '事件', 'zh-Hant': '事件', 'en': 'Events'},

  /// Same wording as `wheelStrings['wheelLifespans']` — the Genesis 5/11
  /// lifespan arcs, unchanged in meaning on the strip.
  'stripLaneLifespans': {
    'zh-Hans': '列祖寿数',
    'zh-Hant': '列祖壽數',
    'en': 'Genesis lifespans',
  },

  /// One heading for both kingdoms' reigns, where the wheel gives Judah
  /// and Israel a legend row each (`wheelKingsThiele`, once per
  /// `Kingdom`). The strip groups them under one sticky heading with two
  /// lanes beneath it — the heading names the pair, the lanes keep them
  /// apart, matching how `kingdomArcColor` already keeps their hues apart
  /// within one shared family.
  'stripLaneKings': {
    'zh-Hans': '犹大与以色列列王',
    'zh-Hant': '猶大與以色列列王',
    'en': 'Kings of Judah & Israel',
  },

  /// Same wording as `wheelStrings['wheelMinistries']`.
  'stripLaneMinistries': {
    'zh-Hans': '先知与使徒的年间',
    'zh-Hant': '先知與使徒的年間',
    'en': 'Prophets & apostles',
  },

  /// The 22 nation/institution bands the wheel names individually via
  /// `_paintBandNames`, one per ring. On the strip they sit under a
  /// single collapsible heading instead of 22 separate ones in the
  /// sticky column, because — unlike lifespans, reigns and ministries,
  /// which are three different KINDS of claim about a date — the streams
  /// are homogeneous: every one is "a people or institution's own band,"
  /// differing only in which people. See the wheel's own header comment,
  /// "WHY BANDS AND NOT ONE STREAM OF DATES."
  'stripLaneStreams': {
    'zh-Hans': '民族与机构',
    'zh-Hant': '民族與機構',
    'en': 'Peoples & institutions',
  },

  // ── scroll-edge indicators ───────────────────────────────────────────
  //
  // Two independent axes — see `docs/strip-painter-spec.md` §8. Vertical
  // ones fire per lane group, when `packIntoLanes` needs more rows than
  // the group's clipped height shows. Horizontal ones fire against the
  // hard content bounds (`kStripMinYear`/`kStripMaxYear`). Both exist for
  // the reason `radial_chronology_layout.dart` states for the wheel's own
  // declutter: "a view narrowed its own contents and said nothing" is a
  // defect this project has fixed three times over (#280, #308, #319) and
  // must not reintroduce here by omission.

  'stripMoreAbove': {
    'zh-Hans': '上方还有更多',
    'zh-Hant': '上方還有更多',
    'en': 'More above',
  },
  'stripMoreBelow': {
    'zh-Hans': '下方还有更多',
    'zh-Hant': '下方還有更多',
    'en': 'More below',
  },

  /// Time runs left to right on this axis (`xForYear` is linear from
  /// `kStripMinYear`), so "before" is off the left edge.
  'stripMoreBefore': {
    'zh-Hans': '左侧还有更多',
    'zh-Hant': '左側還有更多',
    'en': 'More before',
  },
  'stripMoreAfter': {
    'zh-Hans': '右侧还有更多',
    'zh-Hant': '右側還有更多',
    'en': 'More after',
  },

  // ── empty state ──────────────────────────────────────────────────────

  /// Printed in place of a lane group's rows when it has nothing to show
  /// — a filter matched nothing, or the layer is genuinely empty for this
  /// corpus. Rule 2 in `strip_chronology_layout.dart`'s own header:
  /// "nothing narrows in silence." A blank gap and an empty group look
  /// the same to a reader; only one of them is true, and this says which.
  'stripEmptyLane': {
    'zh-Hans': '此处暂无记录。',
    'zh-Hant': '此處暫無記錄。',
    'en': 'No records here at the moment.',
  },

  // ── switching between the two chart forms ───────────────────────────

  /// The accessible name / tooltip for whatever control lets a reader
  /// move between the wheel and the strip — a segmented control, a menu
  /// item, or a plain toggle button, left to the page that builds it.
  /// This names the CONTROL, not either option, so it does not commit
  /// this file to a two-way toggle's exact shape before that page exists.
  'stripViewSwitch': {
    'zh-Hans': '图表视图',
    'zh-Hant': '圖表視圖',
    'en': 'Chart view',
  },
};
