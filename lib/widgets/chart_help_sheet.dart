import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/constants/workbench_theme.dart';
import 'package:yahwehs_sword/models/app_settings.dart';

/// HOW TO USE THE TWO CHARTS, said once, on the way in.
///
/// 2026-09-17 「可不可以有类似于popup windows 第一次打开的话 教人们怎么
/// 使用strip和wheel ... 在不同devices上怎么用」.
///
/// Both charts are direct-manipulation surfaces with no visible verbs:
/// a reader who does not already know that the pointer NAMES a record
/// and a tap OPENS it, or that two fingers are how you get closer, is
/// left guessing at a wheel of coloured bands. Every affordance this
/// page has is invisible until it is used, which is exactly the case
/// where a first-run card earns its interruption.
///
/// It is shown ONCE per device and reachable forever after from the
/// question mark in the toolbar, the same bargain [OnboardingDialog]
/// strikes. The seen flag is stored globally so switching charts, or
/// profiles, does not show it again.
class ChartHelp {
  const ChartHelp._();

  /// Bump the version to show it again to everyone — and spend that
  /// only when there is something new to say, not when the wording
  /// changed.
  static const seenKey = 'chartHelp.seen.v1';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
  }
}

/// Open the card. Marks it seen, so the automatic first-run call and a
/// reader who opened it themselves both spend the same flag.
///
/// It takes no locale ON PURPOSE. The first-run call happens in
/// `initState`, and [AppSettings] starts at its compile-time default
/// (zh-Hans) until `loadSettings()` has run — so a locale captured then
/// and frozen into the card showed an English reader a Chinese card,
/// which is what the first deploy of this did. The card watches the
/// settings instead, and follows a locale that arrives after it opens.
Future<void> showChartHelp(BuildContext context) async {
  await ChartHelp.markSeen();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => const _ChartHelpCard(),
  );
}

String _s(String key, String locale) =>
    chartHelpStrings[key]?[locale] ?? chartHelpStrings[key]?['en'] ?? '';

/// Which pointing device the reader most likely has in their hand.
///
/// The card shows every row — a laptop with a touch screen has all
/// three, and a reader who is told only about one of them learns less
/// than one who sees the list. What the platform decides is the ORDER,
/// so the first line a phone reader reads is about fingers.
bool _touchFirst() =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

class _ChartHelpCard extends StatelessWidget {
  const _ChartHelpCard();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final devices = [
      ('helpMouse', Icons.mouse_outlined),
      ('helpTrackpad', Icons.touch_app_outlined),
      ('helpTouch', Icons.swipe_outlined),
    ];
    if (_touchFirst()) {
      devices.insert(0, devices.removeLast());
    }

    Widget heading(String key) => Padding(
          padding: EdgeInsets.only(top: t.scaled(14), bottom: t.scaled(4)),
          child: Text(
            _s(key, locale),
            style: TextStyle(
              color: wb.text,
              fontSize: t.scaled(13),
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    Widget body(String key) => Padding(
          padding: EdgeInsets.only(bottom: t.scaled(2)),
          child: Text(
            _s(key, locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12.5)),
          ),
        );

    Widget device(String key, IconData icon) => Padding(
          padding: EdgeInsets.only(top: t.scaled(6)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: t.scaled(2), right: t.scaled(8)),
                child: Icon(icon, size: t.scaled(15), color: wb.mutedText),
              ),
              Expanded(
                child: Text(
                  _s(key, locale),
                  style: TextStyle(
                      color: wb.mutedText, fontSize: t.scaled(12.5)),
                ),
              ),
            ],
          ),
        );

    return Dialog(
      backgroundColor: wb.paneBg,
      insetPadding: EdgeInsets.all(t.scaled(20)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WbMetrics.radiusSurface),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  t.scaled(20), t.scaled(18), t.scaled(12), 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _s('helpTitle', locale),
                      style: TextStyle(
                        color: wb.text,
                        fontSize: t.scaled(16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: t.scaled(18),
                    visualDensity: VisualDensity.compact,
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    icon: Icon(Icons.close, color: wb.mutedText),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                key: const ValueKey('chartHelpBody'),
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(
                    t.scaled(20), 0, t.scaled(20), t.scaled(8)),
                children: [
                  body('helpLead'),
                  heading('helpWheelTitle'),
                  body('helpWheelBody'),
                  heading('helpStripTitle'),
                  body('helpStripBody'),
                  heading('helpDevicesTitle'),
                  for (final d in devices) device(d.$1, d.$2),
                  heading('helpLayersTitle'),
                  body('helpLayersBody'),
                  heading('helpListTitle'),
                  body('helpListBody'),
                  heading('helpZoomTitle'),
                  body('helpZoomBody'),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  t.scaled(20), 0, t.scaled(12), t.scaled(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _s('helpAgain', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11.5)),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('chartHelpDone'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(_s('helpDone', locale)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's own words, in the three locales this app ships.
///
/// They live here rather than in `wheelStrings` because they are about
/// the CHARTS AS INSTRUMENTS — pointer, fingers, zoom — and nothing
/// else in that table is. Keeping them together is what stops the
/// wheel's copy and the strip's copy from drifting into describing two
/// different gestures for the same pinch.
const Map<String, Map<String, String>> chartHelpStrings = {
  'helpTitle': {
    'zh-Hans': '怎么看这两张图',
    'zh-Hant': '怎麼看這兩張圖',
    'en': 'How to read these charts',
  },
  'helpLead': {
    'zh-Hans': '同一批记录，两种画法。右上角可以随时切换。',
    'zh-Hant': '同一批記錄，兩種畫法。右上角可以隨時切換。',
    'en': 'One body of records, drawn two ways. The switch is in the '
        'toolbar.',
  },
  'helpWheelTitle': {
    'zh-Hans': '轮盘',
    'zh-Hant': '輪盤',
    'en': 'The wheel',
  },
  'helpWheelBody': {
    'zh-Hans': '绕一圈是从创造到今天。每一圈是一条线索 —— 犹大、教会、圣经、'
        '全世界 —— 同一条半径上的记录，是同一年发生的。',
    'zh-Hant': '繞一圈是從創造到今天。每一圈是一條線索 —— 猶大、教會、聖經、'
        '全世界 —— 同一條半徑上的記錄，是同一年發生的。',
    'en': 'One turn is creation to today. Each ring is one thread — Judah, '
        'the church, the Bible, the world — and whatever lies along the '
        'same spoke happened in the same year.',
  },
  'helpStripTitle': {
    'zh-Hans': '长条',
    'zh-Hant': '長條',
    'en': 'The strip',
  },
  'helpStripBody': {
    'zh-Hans': '同样的记录摊平：左右是年代，每一行是一条线索。长的国和短的'
        '王并排，长度就是它持续了多久。',
    'zh-Hant': '同樣的記錄攤平：左右是年代，每一行是一條線索。長的國和短的'
        '王並排，長度就是它持續了多久。',
    'en': 'The same records laid flat: years run left to right, one thread '
        'per row. A bar’s length is how long it lasted.',
  },
  'helpDevicesTitle': {
    'zh-Hans': '在你手上的设备上',
    'zh-Hant': '在你手上的裝置上',
    'en': 'On the device in your hand',
  },
  'helpMouse': {
    'zh-Hans': '鼠标：滚轮放大缩小，按住拖动平移。指针停在一条记录上会浮出'
        '它的名字，点一下打开它。',
    'zh-Hant': '滑鼠：滾輪放大縮小，按住拖動平移。指標停在一條記錄上會浮出'
        '它的名字，點一下打開它。',
    'en': 'Mouse: the wheel zooms, drag to move. Rest the pointer on a '
        'record and it names itself; click to open it.',
  },
  'helpTrackpad': {
    'zh-Hans': '触控板：双指推移平移，双指捏合或按住 Ctrl 滚动放大缩小。',
    'zh-Hant': '觸控板：雙指推移平移，雙指捏合或按住 Ctrl 捲動放大縮小。',
    'en': 'Trackpad: two fingers to move, pinch (or Ctrl-scroll) to zoom.',
  },
  'helpTouch': {
    'zh-Hans': '触屏：两指捏合放大缩小，一指拖动平移，轻点一条记录打开它。',
    'zh-Hant': '觸控螢幕：兩指捏合放大縮小，一指拖動平移，輕點一條記錄打開它。',
    'en': 'Touch: pinch to zoom, drag with one finger to move, tap a record '
        'to open it.',
  },
  // 2026-09-17 「是不是很多世界上发生的你都没有包含进去」, asked of a chart
  // showing four rings while the line above it said 769 more records
  // were hidden. They are not missing; they are switched off, because a
  // ring has to stay thick enough to read and twenty-two of them on a
  // phone is a barcode. The card says so, with the numbers.
  'helpLayersTitle': {
    'zh-Hans': '没看到的那些',
    'zh-Hant': '沒看到的那些',
    'en': 'What you are not seeing',
  },
  'helpLayersBody': {
    'zh-Hans': '这张图有 22 条线索、780 多条记录。一开始只打开其中四条 —— '
        '圈太多就细到看不清 —— 其余的在「图层」里随时打开。图上方那一行会'
        '告诉你，这个年代范围里还有多少条被图层收着。',
    'zh-Hant': '這張圖有 22 條線索、780 多條記錄。一開始只打開其中四條 —— '
        '圈太多就細到看不清 —— 其餘的在「圖層」裡隨時打開。圖上方那一行會'
        '告訴你，這個年代範圍裡還有多少條被圖層收著。',
    'en': 'The chart holds 22 threads and more than 780 records. Four are '
        'open to begin with — more rings than that and none of them is '
        'thick enough to read — and the rest are one tap away under '
        'Layers. The line above the chart says how many the layers are '
        'holding back in the years you are looking at.',
  },
  'helpListTitle': {
    'zh-Hans': '旁边那一列',
    'zh-Hant': '旁邊那一列',
    'en': 'The list beside it',
  },
  'helpListBody': {
    'zh-Hans': '是同一批记录，按年份排好，跟着图上的位置走。它有自己的搜索框；'
        '点一行，图上就走到那一年。',
    'zh-Hant': '是同一批記錄，按年份排好，跟著圖上的位置走。它有自己的搜尋框；'
        '點一行，圖上就走到那一年。',
    'en': 'The same records in year order, following where you are on the '
        'chart. It has its own search box, and a row takes the chart to '
        'that year.',
  },
  'helpZoomTitle': {
    'zh-Hans': '放大以后',
    'zh-Hant': '放大以後',
    'en': 'Once you are close in',
  },
  'helpZoomBody': {
    'zh-Hans': '图上不会写出每一个名字 —— 一屏写得下多少就写多少，其余的留给'
        '指针和旁边那一列。想知道某一条是什么，把指针停在它上面。',
    'zh-Hant': '圖上不會寫出每一個名字 —— 一屏寫得下多少就寫多少，其餘的留給'
        '指標和旁邊那一列。想知道某一條是什麼，把指標停在它上面。',
    'en': 'Not every record is named on the chart — a screen carries as '
        'many names as it can hold and no more. For the rest, rest the '
        'pointer on one, or find it in the list.',
  },
  'helpAgain': {
    'zh-Hans': '以后想再看：工具栏里的问号。',
    'zh-Hant': '以後想再看：工具列裡的問號。',
    'en': 'To see this again: the question mark in the toolbar.',
  },
  'helpDone': {
    'zh-Hans': '知道了',
    'zh-Hant': '知道了',
    'en': 'Got it',
  },
};
