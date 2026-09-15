import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/utils/font_catalog.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/wheel_stack_layout.dart';
import 'package:seeksparks/utils/wheel_text_metrics.dart';
import 'package:seeksparks/utils/year_digest.dart';

/// The same dated records as the flat wheel, grouped before projection.
/// A group gets a whole ring when focused; concurrent intervals get
/// different heights, never thinner shares of the same painted band.
class StackedChronologyGroup {
  const StackedChronologyGroup(
      {required this.id,
      required this.name,
      required this.color,
      required this.records,
      this.symbol = 1});
  final String id;
  final String name;
  final Color color;
  final List<YearDigestItem> records;
  final int symbol;
}

String stackedWheelText(String key, String locale) {
  const words = <String, Map<String, String>>{
    'overview': {
      'zh-Hans': '全部已选图层',
      'zh-Hant': '全部已選圖層',
      'en': 'All selected layers'
    },
    'flat': {'zh-Hans': '平面', 'zh-Hant': '平面', 'en': 'Flat'},
    'stacked': {'zh-Hans': '立体叠层', 'zh-Hant': '立體疊層', 'en': 'Stacked wheel'},
    'expand': {'zh-Hans': '展开各层', 'zh-Hant': '展開各層', 'en': 'Separate layers'},
    'collapse': {
      'zh-Hans': '合拢各层',
      'zh-Hant': '合攏各層',
      'en': 'Bring layers closer'
    },
    'help': {'zh-Hans': '如何阅读', 'zh-Hant': '如何閱讀', 'en': 'How to read'},
    'explain': {
      'zh-Hans':
          '弧长表示时间。同一时期的记录放在不同高度；高度只用来分开记录，不表示地位或强弱。\n\n选择一个图层看得更清楚；展开各层、旋转或放大，可以看到后面的记录。点击色块或下方名称查看完整年代和出处。图标仅为类别示意。',
      'zh-Hant':
          '弧長表示時間。同一時期的記錄放在不同高度；高度只用來分開記錄，不表示地位或強弱。\n\n選擇一個圖層看得更清楚；展開各層、旋轉或放大，可以看到後面的記錄。點擊色塊或下方名稱查看完整年代和出處。圖標僅為類別示意。',
      'en':
          'Arc length represents time. Records from the same period occupy different heights. Height separates records; it does not mean rank or importance.\n\nChoose a layer for a closer look. Separate, rotate or zoom the layers to see behind them. Tap a segment or a name below for its full dates and sources. Icons are symbolic category markers.'
    },
    'hint': {
      'zh-Hans': '点色块查看 · 拖动或双指缩放',
      'zh-Hant': '點色塊查看 · 拖動或雙指縮放',
      'en': 'Tap a segment · drag or pinch to zoom'
    },
    'records': {'zh-Hans': '条记录', 'zh-Hant': '條記錄', 'en': 'records'},
    'levels': {'zh-Hans': '层', 'zh-Hant': '層', 'en': 'levels'},
    'rotateLeft': {'zh-Hans': '向左旋转', 'zh-Hant': '向左旋轉', 'en': 'Rotate left'},
    'rotateRight': {'zh-Hans': '向右旋转', 'zh-Hant': '向右旋轉', 'en': 'Rotate right'},
    'fit': {'zh-Hans': '复位', 'zh-Hant': '復位', 'en': 'Reset view'},
    'in': {'zh-Hans': '放大', 'zh-Hant': '放大', 'en': 'Zoom in'},
    'out': {'zh-Hans': '缩小', 'zh-Hant': '縮小', 'en': 'Zoom out'},
    'empty': {
      'zh-Hans': '此范围没有已选图层的记录',
      'zh-Hant': '此範圍沒有已選圖層的記錄',
      'en': 'No selected records in this range'
    },
    'present': {'zh-Hans': '至今', 'zh-Hant': '至今', 'en': 'present'},
    'details': {'zh-Hans': '查看出处', 'zh-Hant': '查看出處', 'en': 'Dates & sources'},
    'allNames': {'zh-Hans': '完整名称', 'zh-Hant': '完整名稱', 'en': 'All names'},
  };
  return words[key]?[locale] ?? words[key]?['en'] ?? key;
}

/// Native Canvas projection keeps the six-platform build independent of
/// a browser 3D engine. Geometry is shared with hit-testing, and type is
/// admitted only when its complete box clears the surface and other ink.
class StackedChronologyWheel extends StatefulWidget {
  const StackedChronologyWheel(
      {super.key,
      required this.groups,
      required this.locale,
      required this.label,
      required this.onOpen,
      required this.onFlat,
      this.dateLabel,
      this.selectedId,
      this.revealRevision = 0,
      this.startYear = -4200,
      this.endYear = 2026});
  final List<StackedChronologyGroup> groups;
  final String locale;
  final String Function(YearDigestItem) label;
  final String Function(YearDigestItem)? dateLabel;
  final ValueChanged<YearDigestItem> onOpen;
  final VoidCallback onFlat;
  final String? selectedId;
  final int revealRevision;
  final int startYear;
  final int endYear;

  @override
  State<StackedChronologyWheel> createState() => _StackedChronologyWheelState();
}

class _StackedChronologyWheelState extends State<StackedChronologyWheel> {
  final _view = TransformationController();
  final _recordsScroll = ScrollController();
  String? _lastOpenedId;
  String? _groupId;
  bool _expanded = true;
  double _rotation = -.28;
  double _zoom = 1;
  ui.Image? _symbols;
  Object? _planKey;
  WheelStackPlan? _plan;
  _StackScene? _scene;
  Object? _sceneKey;

  String _s(String key) => stackedWheelText(key, widget.locale);

  @override
  void initState() {
    super.initState();
    final preferred = widget.locale.startsWith('zh') ? 'china' : 'egypt';
    _groupId = widget.groups.any((g) => g.id == preferred)
        ? preferred
        : widget.groups.isEmpty
            ? null
            : widget.groups.first.id;
    for (final group in widget.groups) {
      if (group.records.any((r) => r.id == widget.selectedId)) {
        _groupId = group.id;
        break;
      }
    }
    _view.addListener(_viewChanged);
    _loadSymbols();
  }

  Future<void> _loadSymbols() async {
    final bytes =
        await rootBundle.load('assets/chronology/history-symbols.png');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _symbols = frame.image);
  }

  void _viewChanged() {
    final zoom = _view.value.getMaxScaleOnAxis();
    if ((zoom - _zoom).abs() > .03) setState(() => _zoom = zoom);
  }

  @override
  void didUpdateWidget(covariant StackedChronologyWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_groupId != null && !widget.groups.any((g) => g.id == _groupId)) {
      _groupId = null;
    }
    if (oldWidget.startYear != widget.startYear ||
        oldWidget.endYear != widget.endYear) {
      _reset();
    }
    final reveal = oldWidget.revealRevision != widget.revealRevision;
    if ((oldWidget.selectedId != widget.selectedId || reveal) &&
        widget.selectedId != null) {
      for (final group in widget.groups) {
        if (group.records.any((r) => r.id == widget.selectedId)) {
          _groupId = group.id;
          if (reveal || _lastOpenedId != widget.selectedId) _reset();
          _lastOpenedId = null;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _view.removeListener(_viewChanged);
    _view.dispose();
    _recordsScroll.dispose();
    _symbols?.dispose();
    super.dispose();
  }

  void _open(YearDigestItem record) {
    _lastOpenedId = record.id;
    widget.onOpen(record);
  }

  void _reset() {
    _view.value = Matrix4.identity();
  }

  void _zoomBy(double factor, Size size) {
    final scale = (_zoom * factor).clamp(.8, 8.0);
    final ratio = scale / _view.value.getMaxScaleOnAxis();
    final centre = _view.toScene(size.center(Offset.zero));
    _view.value = _view.value.clone()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
  }

  WheelStackPlan _tiers() {
    final key = widget.groups
        .map((g) =>
            '${g.id}:${g.records.map((r) => '${r.id}/${r.startYear}/${r.endYear}').join(',')}')
        .join('|');
    if (_planKey == key && _plan != null) return _plan!;
    _planKey = key;
    return _plan = planWheelStackTiers([
      for (final group in widget.groups)
        for (final r in group.records)
          WheelStackInterval(
              id: r.id, stream: group.id, start: r.startYear, end: r.endYear),
    ]);
  }

  void _showNames(List<YearDigestItem> records, WbType type) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheet) => SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .8,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(children: [
                    Expanded(
                        child: Text('${_s('allNames')} · ${records.length}',
                            style: TextStyle(
                                fontSize: type.scaledChrome(17),
                                fontWeight: FontWeight.w600))),
                    IconButton(
                        tooltip:
                            MaterialLocalizations.of(sheet).closeButtonLabel,
                        onPressed: () => Navigator.pop(sheet),
                        icon: const Icon(Icons.close)),
                  ])),
              Expanded(
                  child: ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (_, index) {
                        final record = records[index];
                        return ListTile(
                            title: Text(widget.label(record)),
                            subtitle: Text(widget.dateLabel?.call(record) ??
                                '${chronologyYearLabel(record.startYear, widget.locale)} — ${chronologyYearLabel(record.endYear, widget.locale)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(sheet);
                              _open(record);
                            });
                      })),
            ])));
  }

  void _help() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(_s('help')),
            content: SingleChildScrollView(child: Text(_s('explain'))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      Text(MaterialLocalizations.of(context).closeButtonLabel))
            ],
          ));

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    final groups = _groupId == null
        ? widget.groups
        : widget.groups.where((g) => g.id == _groupId).toList();
    var displayStart = widget.startYear;
    var displayEnd = widget.endYear;
    if (_groupId != null &&
        widget.startYear == -4200 &&
        widget.endYear == 2026) {
      final spans = groups.expand((g) => g.records).toList();
      if (spans.isNotEmpty) {
        displayStart = spans
            .map((r) => r.startYear)
            .reduce(math.min)
            .clamp(widget.startYear, widget.endYear);
        displayEnd = spans
            .map((r) => r.endYear)
            .reduce(math.max)
            .clamp(widget.startYear, widget.endYear);
        if (displayEnd <= displayStart) {
          displayStart = math.max(-4200, displayStart - 1);
          displayEnd = math.min(2026, displayEnd + 1);
        }
      }
    }
    final records = [
      for (final g in groups)
        for (final r in g.records)
          if (r.endYear >= widget.startYear && r.startYear <= widget.endYear)
            (group: g, record: r)
    ]..sort((a, b) => a.record.startYear.compareTo(b.record.startYear));
    final plan = _tiers();
    return LayoutBuilder(builder: (context, box) {
      final short = box.maxHeight < 340;
      final railHeight = short ? 0.0 : 90.0;
      return ColoredBox(
          color: Color.lerp(wb.paneBg, const Color(0xFFEDE6D8), .20)!,
          child: Column(children: [
            Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: wb.border))),
                child: Row(children: [
                  Expanded(
                      child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                    key: const ValueKey('stackedWheelGroup'),
                    value: _groupId ?? '',
                    isExpanded: true,
                    style: TextStyle(
                        fontFamily: type.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: type.scaledChrome(13),
                        color: wb.text),
                    items: [
                      DropdownMenuItem(
                          value: '',
                          child: Text(_s('overview'),
                              overflow: TextOverflow.ellipsis)),
                      for (final group in widget.groups)
                        DropdownMenuItem(
                            value: group.id,
                            child: Row(children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: group.color,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(group.name,
                                      overflow: TextOverflow.ellipsis)),
                            ]))
                    ],
                    onChanged: (id) {
                      setState(() => _groupId = id == '' ? null : id);
                      _reset();
                    },
                  ))),
                  IconButton(
                      key: const ValueKey('stackedWheelExpand'),
                      isSelected: _expanded,
                      tooltip: _s(_expanded ? 'collapse' : 'expand'),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: const Icon(Icons.layers_outlined),
                      selectedIcon: const Icon(Icons.layers)),
                  TextButton(
                      key: const ValueKey('stackedWheelFlat'),
                      onPressed: widget.onFlat,
                      child: Text(_s('flat'))),
                  IconButton(
                      tooltip: _s('help'),
                      onPressed: _help,
                      icon: const Icon(Icons.info_outline, size: 19)),
                ])),
            Expanded(child: LayoutBuilder(builder: (context, chartBox) {
              final size = Size(chartBox.maxWidth, chartBox.maxHeight);
              final key = (
                _planKey,
                _groupId,
                size,
                _expanded,
                _rotation,
                widget.startYear,
                widget.endYear,
                widget.locale,
                _zoom,
                type.chromeScale
              );
              if (_sceneKey != key) {
                _sceneKey = key;
                _scene = _StackScene.build(
                    groups: groups,
                    plan: plan,
                    size: size,
                    expanded: _expanded,
                    rotation: _rotation,
                    start: displayStart,
                    end: displayEnd);
              }
              final scene = _scene!;
              return Stack(children: [
                Positioned.fill(
                    child: InteractiveViewer(
                        transformationController: _view,
                        minScale: .8,
                        maxScale: 8,
                        boundaryMargin: const EdgeInsets.all(300),
                        child: GestureDetector(
                          key: const ValueKey('stackedChronologyWheel'),
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (event) {
                            // Side names are the recovery path for narrow arcs;
                            // their actual painted boxes must open the same record.
                            for (final callout in scene.callouts.reversed) {
                              if (callout.bounds
                                  .inflate(4 / _zoom)
                                  .contains(event.localPosition)) {
                                _open(scene.records[callout.id]!);
                                return;
                              }
                            }
                            final hit = hitWheelStackPrism(
                                scene.prisms, event.localPosition,
                                pointRadius: 6 / _zoom);
                            if (hit != null) {
                              _open(scene.records[hit.id]!);
                            }
                          },
                          child: RepaintBoundary(
                              child: CustomPaint(
                            size: size,
                            painter: _StackedWheelPainter(
                                scene: scene,
                                groups: groups,
                                plan: plan,
                                label: widget.label,
                                locale: widget.locale,
                                wb: wb,
                                fontFamily: type.fontFamily ?? 'Roboto',
                                fontSize: type.scaledChrome(12) /
                                    math.max(1, _zoom / 1.4),
                                symbols: _symbols,
                                selectedId: widget.selectedId,
                                zoom: _zoom),
                          )),
                        ))),
                Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 32,
                    child: ColoredBox(
                        color: wb.paneBg,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
                            child: IgnorePointer(
                                child: Row(children: [
                              Expanded(
                                  child: Text(
                                      '${chronologyYearLabel(displayStart, widget.locale)} — ${chronologyYearLabel(displayEnd, widget.locale)}',
                                      style: TextStyle(
                                          color: wb.mutedText,
                                          fontSize: type.scaledChrome(11)))),
                              Text('${records.length} ${_s('records')}',
                                  style: TextStyle(
                                      color: wb.mutedText,
                                      fontSize: type.scaledChrome(11))),
                            ]))))),
                if (records.isEmpty)
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child:
                              Text(_s('empty'), textAlign: TextAlign.center))),
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ColoredBox(
                        color: wb.paneBg,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(children: [
                              _button(
                                  'stackedRotateLeft',
                                  Icons.rotate_left,
                                  'rotateLeft',
                                  () =>
                                      setState(() => _rotation -= math.pi / 6)),
                              _button(
                                  'stackedRotateRight',
                                  Icons.rotate_right,
                                  'rotateRight',
                                  () =>
                                      setState(() => _rotation += math.pi / 6)),
                              Expanded(
                                  child: Center(
                                      child: TextButton(
                                          key: const ValueKey(
                                              'stackedWheelAllNames'),
                                          onPressed: () => _showNames(
                                              records
                                                  .map((e) => e.record)
                                                  .toList(),
                                              type),
                                          style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4)),
                                          child: Text(_s('allNames'),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis)))),
                              _button('stackedZoomOut', Icons.remove, 'out',
                                  () => _zoomBy(1 / 1.4, size)),
                              _button('stackedReset', Icons.center_focus_strong,
                                  'fit', _reset),
                              _button('stackedZoomIn', Icons.add, 'in',
                                  () => _zoomBy(1.4, size)),
                            ])))),
              ]);
            })),
            Container(
                height: railHeight,
                decoration: BoxDecoration(
                    color: wb.paneBg,
                    border: Border(top: BorderSide(color: wb.border))),
                child: records.isEmpty || short
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        key: const ValueKey('stackedWheelRecords'),
                        controller: _recordsScroll,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(6),
                        itemCount: records.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final entry = records[index];
                          final record = entry.record;
                          final selected = record.id == widget.selectedId;
                          final tier = (plan.tierById[record.id] ?? 0) + 1;
                          final title = widget.label(record);
                          final years = widget.dateLabel?.call(record) ??
                              '${chronologyYearLabel(record.startYear, widget.locale)}${record.startYear == record.endYear ? '' : ' — ${record.openEnded ? _s('present') : chronologyYearLabel(record.endYear, widget.locale)}'}';
                          return SizedBox(
                              width: short ? 188 : 228,
                              child: Material(
                                  color: selected
                                      ? entry.group.color.withValues(alpha: .12)
                                      : wb.paneBg,
                                  shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                          color: selected
                                              ? entry.group.color
                                              : wb.border),
                                      borderRadius: BorderRadius.circular(
                                          WbMetrics.radiusControl)),
                                  child: InkWell(
                                    key: ValueKey('stackedRecord-${record.id}'),
                                    onTap: () => _open(record),
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                  child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Text(
                                                        widget.locale
                                                                .startsWith(
                                                                    'zh')
                                                            ? '$tier层'
                                                            : 'L$tier',
                                                        style: TextStyle(
                                                            color: entry
                                                                .group.color,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: type
                                                                .scaledChrome(
                                                                    12))),
                                                    const SizedBox(width: 7),
                                                    Expanded(
                                                        child: Text(title,
                                                            maxLines:
                                                                short ? 1 : 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                                color: wb.text,
                                                                fontSize: type
                                                                    .scaledChrome(
                                                                        12),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600))),
                                                  ])),
                                              Text(years,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: wb.mutedText,
                                                      fontSize: type
                                                          .scaledChrome(11))),
                                            ])),
                                  )));
                        },
                      )),
          ]));
    });
  }

  Widget _button(String key, IconData icon, String tip, VoidCallback go) =>
      SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
              key: ValueKey(key),
              tooltip: _s(tip),
              onPressed: go,
              icon: Icon(icon, size: 20)));
}

class _StackScene {
  _StackScene(
      {required this.prisms,
      required this.records,
      required this.groupOf,
      required this.projection,
      required this.radius,
      required this.baseInner,
      required this.rotation,
      required this.start,
      required this.end});
  final List<WheelStackPrism> prisms;
  final List<WheelStackCallout> callouts = [];
  final Map<String, YearDigestItem> records;
  final Map<String, StackedChronologyGroup> groupOf;
  final WheelStackProjection projection;
  final double radius;
  final double baseInner;
  final double rotation;
  final int start;
  final int end;

  factory _StackScene.build(
      {required List<StackedChronologyGroup> groups,
      required WheelStackPlan plan,
      required Size size,
      required bool expanded,
      required double rotation,
      required int start,
      required int end}) {
    final depth = groups.fold<int>(
        1, (d, g) => math.max(d, plan.depthByStream[g.id] ?? 1));
    // At most 38% of the available height goes to elevation. Radius and
    // tier spacing shrink together; a forced minimum radius previously
    // put the eleven-deep lifespan group through the camera controls.
    final usableHeight = math.max(1.0, size.height - 106);
    final tierStep = math.min(
        expanded ? 40.0 : 10.0, usableHeight * .38 / math.max(1, depth));
    final thickness = math.min(8.0, tierStep * .78);
    final stackHeight = (depth - 1) * tierStep + thickness + 5;
    final bankWidth = (size.width * .19).clamp(58.0, 144.0);
    final fit = math.min(math.max(1.0, (size.width - 2 * bankWidth - 30) / 2),
        math.max(1.0, (usableHeight - stackHeight) / 1.28));
    final radius = fit;
    final centre = Offset(size.width / 2, 43 + stackHeight + radius * .64);
    final projection = WheelStackProjection(centre: centre);
    final inner = radius * .38;
    final band = (radius - inner) / math.max(1, groups.length);
    final prisms = <WheelStackPrism>[];
    final records = <String, YearDigestItem>{};
    final groupOf = <String, StackedChronologyGroup>{};
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final outer = radius - i * band;
      for (final record in group.records) {
        if (record.endYear < start || record.startYear > end) continue;
        final tier = plan.tierById[record.id] ?? 0;
        records[record.id] = record;
        groupOf[record.id] = group;
        prisms.add(WheelStackPrism(
            id: record.id,
            projection: projection,
            innerRadius: outer - band * .88,
            outerRadius: outer,
            startAngle: angleForSpan(record.startYear, start, end) + rotation,
            endAngle: angleForSpan(record.endYear, start, end) + rotation,
            bottomHeight: tier * tierStep + 5,
            topHeight: tier * tierStep + 5 + thickness));
      }
    }
    return _StackScene(
        prisms: wheelStackPaintOrder(prisms),
        records: records,
        groupOf: groupOf,
        projection: projection,
        radius: radius,
        baseInner: inner,
        rotation: rotation,
        start: start,
        end: end);
  }
}

class _StackedWheelPainter extends CustomPainter {
  _StackedWheelPainter(
      {required this.scene,
      required this.groups,
      required this.plan,
      required this.label,
      required this.locale,
      required this.wb,
      required this.fontSize,
      required this.fontFamily,
      required this.zoom,
      required this.symbols,
      required this.selectedId});
  final _StackScene scene;
  final List<StackedChronologyGroup> groups;
  final WheelStackPlan plan;
  final String Function(YearDigestItem) label;
  final String locale;
  final WbColors wb;
  final double fontSize;
  final String fontFamily;
  final double zoom;
  final ui.Image? symbols;
  final String? selectedId;

  /// The actual ink boxes retained by the painter, for visibility tests.
  final List<Rect> paintedLabelBounds = [];
  final List<String> paintedRecordIds = [];

  @override
  void paint(Canvas canvas, Size size) {
    paintedLabelBounds.clear();
    paintedRecordIds.clear();
    scene.callouts.clear();
    final p = scene.projection;
    final base = WheelStackPrism(
        id: 'base',
        projection: p,
        innerRadius: math.max(0, scene.baseInner - 3),
        outerRadius: scene.radius + 4,
        startAngle: startRad + scene.rotation,
        endAngle: startRad + sweepRad + scene.rotation,
        bottomHeight: -5,
        topHeight: 0);
    canvas.drawShadow(
        base.topPath, Colors.black.withValues(alpha: .13), 6, false);
    for (final side in base.sidePaths) {
      canvas.drawPath(
          side, Paint()..color = Color.lerp(wb.paneBg, wb.mutedText, .22)!);
    }
    canvas.drawPath(base.topPath,
        Paint()..color = Color.lerp(wb.paneBg, wb.mutedText, .06)!);
    Rect? hubSymbolRect;
    if (symbols != null && groups.length == 1 && scene.radius > 65) {
      final iconSize = math.min(76.0, scene.radius * .34);
      hubSymbolRect = Rect.fromCenter(
          center: p.centre - Offset(0, iconSize * .12),
          width: iconSize,
          height: iconSize);
      _symbol(canvas, groups.first.symbol, hubSymbolRect);
    }
    for (final prism in scene.prisms) {
      final group = scene.groupOf[prism.id]!;
      final selected = selectedId == prism.id;
      final tier = plan.tierById[prism.id] ?? 0;
      final color = Color.lerp(group.color, wb.paneBg, .22 + (tier % 3) * .09)!;
      var sideIndex = 0;
      for (final side in prism.sidePaths) {
        canvas.drawPath(
            side,
            Paint()
              ..color = Color.lerp(
                  color, Colors.black, sideIndex++ % 2 == 0 ? .28 : .15)!);
      }
      canvas.drawPath(
          prism.topPath,
          Paint()
            ..shader = ui.Gradient.linear(
                prism.bounds.topLeft,
                prism.bounds.bottomRight,
                [Color.lerp(color, Colors.white, .2)!, color]));
      canvas.drawPath(
          prism.topPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (selected ? 2.3 : .8) / zoom
            ..color = selected ? wb.accent : wb.paneBg.withValues(alpha: .84));
      if (prism.sweep == 0) {
        final point = p.polar(
            (prism.innerRadius + prism.outerRadius) / 2, prism.startAngle,
            height: prism.topHeight);
        canvas.drawCircle(point, 3 / zoom, Paint()..color = group.color);
      }
    }
    final occupied = <Rect>[];
    if (hubSymbolRect != null) occupied.add(hubSymbolRect);
    if (symbols != null && selectedId != null) {
      for (final prism in scene.prisms) {
        if (prism.id != selectedId) continue;
        final anchor = p.polar((prism.innerRadius + prism.outerRadius) / 2,
            (prism.startAngle + prism.endAngle) / 2,
            height: prism.topHeight);
        final iconSize = 42 / math.max(1, zoom / 1.3);
        final rect = Rect.fromLTWH(
            anchor.dx - iconSize / 2, anchor.dy - iconSize, iconSize, iconSize);
        _symbol(canvas, scene.groupOf[prism.id]!.symbol, rect);
        occupied.add(rect);
      }
    }
    _axis(canvas, size, occupied);
    // Name admission follows front-to-back visibility. A rear label may
    // not float over a nearer prism. Every omitted name remains in the
    // scrollable record cards directly below this same chart.
    for (var i = scene.prisms.length - 1; i >= 0; i--) {
      final prism = scene.prisms[i];
      final record = scene.records[prism.id]!;
      final text = label(record);
      final style = canvasTextStyle(
              fontSize: fontSize, color: wb.text, fontWeight: FontWeight.w600)
          .copyWith(fontFamily: fontFamily);
      final paragraph = WheelTextMetrics.paragraphOf(text, style);
      final placement = wheelStackLabelPlacement(
          prism, Size(paragraph.maxIntrinsicWidth, paragraph.height),
          padding: 3 / zoom,
          pointRadius: 3 / zoom,
          occluders: scene.prisms.skip(i + 1).toList(),
          occupied: occupied);
      if (placement == null) continue;
      occupied.add(placement.bounds.inflate(3 / zoom));
      paintedLabelBounds.add(placement.bounds);
      paintedRecordIds.add(prism.id);
      canvas.save();
      canvas.translate(placement.centre.dx, placement.centre.dy);
      canvas.rotate(placement.rotation);
      canvas.drawParagraph(paragraph,
          Offset(-paragraph.maxIntrinsicWidth / 2, -paragraph.height / 2));
      canvas.restore();
    }
    final bankWidth = (size.width * .19).clamp(58.0, 144.0);
    final calloutStyle = canvasTextStyle(
            fontSize: fontSize, color: wb.text, fontWeight: FontWeight.w600)
        .copyWith(fontFamily: fontFamily);
    final paragraphs = <String, ui.Paragraph>{};
    for (final prism in scene.prisms) {
      if (paintedRecordIds.contains(prism.id)) continue;
      final text = label(scene.records[prism.id]!);
      var paragraph = WheelTextMetrics.paragraphOf(text, calloutStyle);
      if (paragraph.maxIntrinsicWidth > bankWidth) {
        final chars = text.characters.toList();
        var lo = 0;
        var hi = chars.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) ~/ 2;
          final candidate = WheelTextMetrics.paragraphOf(
              '${chars.take(mid).join()}…', calloutStyle);
          if (candidate.maxIntrinsicWidth <= bankWidth) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        paragraph = WheelTextMetrics.paragraphOf(
            '${chars.take(lo).join()}…', calloutStyle);
      }
      paragraphs[prism.id] = paragraph;
    }
    final callouts = planWheelStackCallouts(
        paintOrder: scene.prisms,
        contentArea: Rect.fromLTRB(6, 32, size.width - 6, size.height - 50),
        measure: (id) => Size(paragraphs[id]?.maxIntrinsicWidth ?? 0,
            paragraphs[id]?.height ?? 0),
        bankWidth: bankWidth,
        gap: 8 / zoom,
        maxPerSide: size.height < 240 ? 3 : 5,
        pointRadius: 3 / zoom,
        occupied: occupied,
        excludedIds: paintedRecordIds.toSet());
    scene.callouts.addAll(callouts);
    for (final callout in callouts) {
      final color = scene.groupOf[callout.id]!.color;
      canvas.drawLine(
          callout.anchor,
          callout.leaderEnd,
          Paint()
            ..color = color.withValues(alpha: .58)
            ..strokeWidth = .8 / zoom);
      canvas.drawCircle(callout.anchor, 2 / zoom, Paint()..color = color);
      canvas.drawParagraph(paragraphs[callout.id]!, callout.bounds.topLeft);
      paintedLabelBounds.add(callout.bounds);
      paintedRecordIds.add(callout.id);
    }
  }

  bool _occluded(Rect rect) {
    final path = Path()..addRect(rect);
    return scene.prisms.any((prism) =>
        !Path.combine(PathOperation.intersect, path, prism.footprint)
            .getBounds()
            .isEmpty);
  }

  void _symbol(Canvas canvas, int symbol, Rect target) {
    final atlas = symbols!;
    final cellW = atlas.width / 3;
    final cellH = atlas.height / 2;
    canvas.drawImageRect(
        atlas,
        Rect.fromLTWH(
            (symbol % 3) * cellW, (symbol ~/ 3) * cellH, cellW, cellH),
        target,
        Paint()..filterQuality = FilterQuality.medium);
  }

  void _axis(Canvas canvas, Size size, List<Rect> occupied) {
    for (final part in [0.0, 1.0, .25, .5, .75]) {
      final year = (scene.start + part * (scene.end - scene.start)).round();
      final angle = startRad + part * sweepRad + scene.rotation;
      final a = scene.projection.polar(scene.radius + 7, angle);
      final b = scene.projection.polar(scene.radius + 12, angle);
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = wb.mutedText.withValues(alpha: .5)
            ..strokeWidth = .8 / zoom);
      final location = scene.projection.polar(scene.radius + 24, angle);
      final paragraph = WheelTextMetrics.paragraphOf(
          chronologyYearLabel(year, locale),
          canvasTextStyle(fontSize: fontSize * .86, color: wb.mutedText)
              .copyWith(fontFamily: fontFamily));
      final rect = Rect.fromCenter(
          center: location,
          width: paragraph.maxIntrinsicWidth,
          height: paragraph.height);
      if (!(Offset.zero & size).contains(rect.topLeft) ||
          !(Offset.zero & size).contains(rect.bottomRight) ||
          _occluded(rect) ||
          occupied.any((r) => r.overlaps(rect.inflate(3)))) {
        continue;
      }
      occupied.add(rect);
      paintedLabelBounds.add(rect);
      canvas.drawParagraph(paragraph, rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(covariant _StackedWheelPainter old) =>
      old.scene != scene ||
      old.symbols != symbols ||
      old.selectedId != selectedId ||
      old.wb != wb ||
      old.fontSize != fontSize ||
      old.fontFamily != fontFamily ||
      old.locale != locale;
}
