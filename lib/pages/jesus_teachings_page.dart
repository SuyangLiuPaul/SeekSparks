/// 主耶稣的教导 — the teachings of the Lord Jesus, and what the app
/// already knows about each of them.
///
/// WHAT THIS PAGE MAY SAY, which is the whole design problem.
///
/// The owner's request was for a page where the apostles' letters are
/// shown as resting on Jesus' teaching, and the Old Testament under it.
/// That conviction is not in dispute here. The difficulty is that the
/// data which can link the passages — the Treasury of Scripture
/// Knowledge, merged with OpenBible.info votes — asserts only that two
/// passages are RELATED. "Rests on" is a directional claim TSK does not
/// make.
///
/// So the conviction goes in the PREFACE, in the owner's voice, with the
/// texts that ground it; and the column headings stay neutral —
/// 「在使徒书信中」, not 「以此为根基」. A reader who holds the conviction
/// sees exactly what they came for; the page never asserts more than its
/// sources carry.
///
/// The one exception is [TeachingLink.lordsWord]: five places where an
/// apostle says outright that he is handing on the Lord's own word
/// (1 Cor 7:10-11, 9:14, 11:23-25; 1 Thess 4:15; Acts 20:35). Those are
/// marked, because there scripture itself makes the claim.
///
/// The arrangement is editorial and the page says so rather than hoping
/// nobody asks — `scripts/build_jesus_teachings.py` carries the reasons.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/map_viewer_page.dart';
import 'package:seeksparks/pages/sermon_detail_page.dart';
import 'package:seeksparks/services/jesus_teachings_service.dart';
import 'package:seeksparks/services/map_service.dart';
import 'package:seeksparks/services/sermon_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/reference_parser.dart' show parseReference;
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/verse_popup_sheet.dart' show showVersePopup;

const Map<String, String> kJesusTeachingsTitle = {
  'zh-Hans': '主耶稣的教导',
  'zh-Hant': '主耶穌的教導',
  'en': 'The Teachings of the Lord Jesus',
};

const Map<String, Map<String, String>> _s = {
  // The owner's own conviction, with the texts that ground it. It is
  // stated here, once, so the column headings can stay neutral.
  'preface': {
    'zh-Hans': '使徒所传的，是从主领受的（约14:26；林前11:23；15:3）。'
        '下面列出每一项教导：主耶稣所说的经文、讲道、旧约中相关的经文，'
        '以及使徒书信中接续它的地方。',
    'zh-Hant': '使徒所傳的，是從主領受的（約14:26；林前11:23；15:3）。'
        '下面列出每一項教導：主耶穌所說的經文、講道、舊約中相關的經文，'
        '以及使徒書信中接續它的地方。',
    'en': 'The apostles taught what they received from the Lord '
        '(Jn 14:26; 1 Cor 11:23; 15:3). For each teaching below: the '
        'passage, the sermons on it, related Old Testament passages, and '
        'where the apostles\' letters take it up.',
  },
  'scripture': {'zh-Hans': '经文', 'zh-Hant': '經文', 'en': 'Passage'},
  'sermons': {'zh-Hans': '讲道', 'zh-Hant': '講道', 'en': 'Sermons'},
  'ot': {
    'zh-Hans': '旧约中相关的经文',
    'zh-Hant': '舊約中相關的經文',
    'en': 'Related in the Old Testament',
  },
  'apostles': {
    'zh-Hans': '在使徒书信中',
    'zh-Hant': '在使徒書信中',
    'en': 'In the apostles\' letters',
  },
  'plates': {'zh-Hans': '图画', 'zh-Hant': '圖畫', 'en': 'Illustrations'},
  'lordsWord': {
    'zh-Hans': '使徒自述为主的话',
    'zh-Hant': '使徒自述為主的話',
    'en': 'the apostle says this is the Lord\'s own word',
  },
  'count': {'zh-Hans': '项教导', 'zh-Hant': '項教導', 'en': 'teachings'},
};

String _t(String key, String locale) =>
    _s[key]?[locale] ?? _s[key]?['en'] ?? key;

class JesusTeachingsPage extends StatefulWidget {
  const JesusTeachingsPage({super.key});

  @override
  State<JesusTeachingsPage> createState() => _JesusTeachingsPageState();
}

class _JesusTeachingsPageState extends State<JesusTeachingsPage> {
  Future<JesusTeachingsData>? _future;
  final Set<String> _open = {};

  @override
  void initState() {
    super.initState();
    _future = JesusTeachingsService.instance.load();
  }

  Future<void> _read(String raw) async {
    final ref = parseReference(raw);
    if (ref == null || !mounted) return;
    await showVersePopup(context, ref);
  }

  Future<void> _openSermon(String id) async {
    final all = await SermonService.instance.loadIndex();
    final match = all.where((s) => s.id == id);
    if (match.isEmpty || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SermonDetailPage(sermon: match.first)));
  }

  Future<void> _openPlate(String id, String locale) async {
    final maps = await MapService.loadMaps();
    final match = maps.where((m) => m.id == id);
    if (match.isEmpty || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MapViewerPage(map: match.first, locale: locale)));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Scaffold(
      backgroundColor: wb.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(kJesusTeachingsTitle[locale] ?? kJesusTeachingsTitle['en']!),
      ),
      body: FutureBuilder<JesusTeachingsData>(
        future: _future,
        // Already-decoded data goes straight in rather than through a
        // frame of spinner. It also makes the page testable: a
        // `rootBundle` read never completes inside a widget test's
        // fake-async zone, so a page that can only arrive via the
        // future can only ever be tested as a spinner.
        initialData: JesusTeachingsService.instance.cached,
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final top = data.topLevel;
          return ListView.builder(
            key: const ValueKey('jesusTeachingsList'),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: top.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _preface(data, locale, wb, t);
              final teaching = top[i - 1];
              final parts = data.partsOf(teaching.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(teaching, locale, wb, t, indented: false),
                  for (final part in parts)
                    _row(part, locale, wb, t, indented: true),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _preface(
      JesusTeachingsData data, String locale, WbColors wb, WbType t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_t('preface', locale),
              style: TextStyle(
                color: wb.text,
                fontFamily: t.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: t.scaled(12.5),
                height: 1.5,
              )),
          const SizedBox(height: 8),
          // The page's own limits, carried out of the dataset rather
          // than retyped here so the two cannot drift apart.
          Text('${data.teachings.length} ${_t('count', locale)} · '
              '${data.claims}',
              style: TextStyle(
                color: wb.mutedText,
                fontFamily: t.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: _atLeast(t.scaledSmall(11), WbMetrics.smallPrintFloor),
                height: 1.45,
              )),
        ],
      ),
    );
  }

  Widget _row(JesusTeaching teaching, String locale, WbColors wb, WbType t,
      {required bool indented}) {
    final open = _open.contains(teaching.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('teaching-${teaching.id}'),
          onTap: () => setState(
              () => open ? _open.remove(teaching.id) : _open.add(teaching.id)),
          child: Container(
            padding: EdgeInsets.fromLTRB(indented ? 30 : 16, 10, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: wb.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teaching.titleFor(locale),
                        style: TextStyle(
                          color: wb.text,
                          fontFamily: t.fontFamily,
                          fontFamilyFallback: kCjkFontFallback,
                          fontSize: t.scaled(teaching.isDiscourse ? 14 : 12.5),
                          fontWeight: teaching.isDiscourse
                              ? FontWeight.w700
                              : FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(teaching.label,
                          style: TextStyle(
                            color: wb.mutedText,
                            fontFamily: t.fontFamily,
                            fontFamilyFallback: kCjkFontFallback,
                            fontSize: _atLeast(
                                t.scaledSmall(11), WbMetrics.smallPrintFloor),
                            height: 1.35,
                          )),
                    ],
                  ),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more,
                    size: t.scaledChrome(18), color: wb.mutedText),
              ],
            ),
          ),
        ),
        if (open) _detail(teaching, locale, wb, t, indented),
      ],
    );
  }

  Widget _detail(JesusTeaching teaching, String locale, WbColors wb, WbType t,
      bool indented) {
    Widget section(String key, List<Widget> chips) {
      if (chips.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(key, locale),
                style: TextStyle(
                  color: wb.mutedText,
                  fontFamily: t.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize:
                      _atLeast(t.scaledSmall(11), WbMetrics.smallPrintFloor),
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 5),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ),
      );
    }

    Widget chip(String label, VoidCallback onTap, {String? note}) => InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: wb.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      color: wb.link,
                      fontFamily: t.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: _atLeast(
                          t.scaledSmall(11.5), WbMetrics.smallPrintFloor),
                    )),
                if (note != null)
                  Text(note,
                      style: TextStyle(
                        color: wb.accent,
                        fontFamily: t.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        // 11, not 10. `font_size_reach_ratchet_test`
                        // catches a DESIGN size under the app's floor
                        // even when a helper clamps it at runtime —
                        // and it is right to: flooring a 10 makes this
                        // note the same size as the label above it at
                        // the bottom of the slider, which inverts their
                        // rank exactly where legibility is tightest.
                        fontSize: _atLeast(
                            t.scaledSmall(11), WbMetrics.smallPrintFloor),
                      )),
              ],
            ),
          ),
        );

    return Container(
      padding: EdgeInsets.fromLTRB(indented ? 30 : 16, 10, 16, 6),
      decoration: BoxDecoration(
        color: wb.paneAltBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('scripture', [
            for (final r in teaching.refs)
              chip(r.label, () => _read(r.label)),
          ]),
          section('sermons', [
            for (final s in teaching.sermons)
              chip('${s.titleFor(locale)}${s.date.contains('-') && !s.date.contains('mm') ? '  ${s.date}' : ''}',
                  () => _openSermon(s.id)),
          ]),
          section('ot', [
            for (final r in teaching.oldTestament) chip(r, () => _read(r)),
          ]),
          section('apostles', [
            for (final a in teaching.apostles)
              chip(a.ref, () => _read(a.ref),
                  note: a.lordsWord == null ? null : _t('lordsWord', locale)),
          ]),
          section('plates', [
            for (final p in teaching.plates)
              chip(p, () => _openPlate(p, locale)),
          ]),
        ],
      ),
    );
  }
}

/// Never under the app's own small-print floor — the same rule the rest
/// of the app is held to, and the one the chronology charts were found
/// breaking a day earlier by multiplying a size without clamping it.
double _atLeast(double a, double b) => a > b ? a : b;
