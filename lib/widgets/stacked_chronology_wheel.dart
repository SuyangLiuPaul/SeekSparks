import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/chart_symbol_service.dart';
import 'package:seeksparks/utils/chronology_symbols.dart';
import 'package:seeksparks/utils/chronology_depth_view.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/utils/font_catalog.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/wheel_default_streams.dart';
import 'package:seeksparks/utils/wheel_stack_layout.dart';
import 'package:seeksparks/utils/wheel_text_metrics.dart';
import 'package:seeksparks/utils/year_digest.dart';

const double stackedWheelFooterHeight = 88;

/// Countries keep their original concentric rings. Independent lifespan,
/// reign, ministry and genealogy layers occupy the original outer annulus.
class StackedChronologyGroup {
  const StackedChronologyGroup({
    required this.id,
    required this.name,
    required this.color,
    required this.records,
    this.symbol = 1,
    this.outerLane = false,
  });
  final String id;
  final String name;
  final Color color;
  final List<YearDigestItem> records;
  final int symbol;
  final bool outerLane;
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
    'spacing': {'zh-Hans': '层间距', 'zh-Hant': '層間距', 'en': 'Layer spacing'},
    'compact': {'zh-Hans': '紧凑', 'zh-Hant': '緊湊', 'en': 'Compact'},
    'standard': {'zh-Hans': '标准', 'zh-Hant': '標準', 'en': 'Standard'},
    'expanded': {'zh-Hans': '展开', 'zh-Hant': '展開', 'en': 'Expanded'},
    'help': {'zh-Hans': '如何阅读', 'zh-Hant': '如何閱讀', 'en': 'How to read'},
    'explain': {
      'zh-Hans':
          '每个国家保留自己的同心环，角度表示年代。同一时期的记录向上叠放，高度只用来分开记录，不表示地位或强弱。\n\n旋转模式下，左右拖动转动整个轮盘，上下拖动改变俯仰。切换平移模式移动放大的轮盘，两种模式都可以双指缩放。点击色块或完整名称查看年代和出处。',
      'zh-Hant':
          '每個國家保留自己的同心環，角度表示年代。同一時期的記錄向上疊放，高度只用來分開記錄，不表示地位或強弱。\n\n旋轉模式下，左右拖動轉動整個輪盤，上下拖動改變俯仰。切換平移模式移動放大的輪盤，兩種模式都可以雙指縮放。點擊色塊或完整名稱查看年代和出處。',
      'en':
          'Each country keeps its concentric ring; angle represents the year. Records from the same period rise into separate layers. Height does not mean rank or importance.\n\nIn rotate mode, drag sideways to turn the whole wheel and vertically to tilt it. Switch to pan mode to move the enlarged wheel. Pinch to zoom in either mode. Tap a segment or All names for dates and sources.'
    },
    'rotateMode': {'zh-Hans': '旋转', 'zh-Hant': '旋轉', 'en': 'Rotate'},
    'panMode': {'zh-Hans': '平移', 'zh-Hant': '平移', 'en': 'Pan'},
    'tilt': {'zh-Hans': '俯仰', 'zh-Hant': '俯仰', 'en': 'Tilt'},
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

/// Both views can share a controller, but retain their own ground-plane
/// projection. A camera transfer keeps the same year/ring under the centre
/// instead of interpreting a tilted translation as a flat-screen position.
class StackedChronologyWheel extends StatefulWidget {
  const StackedChronologyWheel({
    super.key,
    required this.groups,
    required this.locale,
    required this.label,
    required this.onOpen,
    required this.onFlat,
    this.dateLabel,
    this.selectedId,
    this.revealRevision = 0,
    this.startYear = -4200,
    this.endYear = 2026,
    this.controller,
    this.initialCamera,
    this.onCameraChanged,
    this.initialYaw = 0,
    this.initialTilt = .70,
    this.initialLift = 4,
    this.onLiftChanged,
    this.onAnglesChanged,
    this.onYear,
    this.cursorYear,
  });
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
  final TransformationController? controller;
  final ChronologyDepthCamera? initialCamera;
  final ValueChanged<ChronologyDepthCamera>? onCameraChanged;
  final double initialYaw;
  final double initialTilt;
  final double initialLift;
  final ValueChanged<double>? onLiftChanged;
  final void Function(double yaw, double tilt)? onAnglesChanged;
  final ValueChanged<int>? onYear;
  final int? cursorYear;

  @override
  State<StackedChronologyWheel> createState() => _StackedChronologyWheelState();
}

class _StackedChronologyWheelState extends State<StackedChronologyWheel> {
  late TransformationController _view;
  late bool _ownsController;
  late double _yaw;
  late double _tilt;
  late double _lift;
  bool _panMode = false;
  bool _applyingCamera = false;
  final Set<int> _pointers = {};
  Offset? _dragOrigin;
  bool _dragged = false;
  String? _lastOpenedId;
  bool _revealPending = false;
  Object? _planKey;
  WheelStackPlan? _plan;
  Object? _sceneKey;
  _StackScene? _scene;
  ChronologyDepthCamera? _camera;
  ChronologyDepthCamera? _pendingCamera;
  Size? _size;
  double _screenScale = 1;

  String _s(String key) => stackedWheelText(key, widget.locale);

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _view = widget.controller ?? TransformationController();
    _yaw = widget.initialYaw;
    _tilt = widget.initialTilt.clamp(.35, 1.0);
    _lift = widget.initialLift.clamp(1, 10);
    _pendingCamera = widget.initialCamera;
    _view.addListener(_viewChanged);
  }

  ChronologyDepthCamera? _captureCamera() {
    final scene = _scene;
    final size = _size;
    if (scene == null || size == null) return _camera;
    return ChronologyDepthCamera.capture(
      view: scene.view,
      viewport: Offset.zero & size,
      scale: _view.value.getMaxScaleOnAxis(),
      translation: Offset(_view.value.storage[12], _view.value.storage[13]),
    );
  }

  void _viewChanged() {
    if (_applyingCamera || !mounted) return;
    _camera = _captureCamera();
    if (_camera != null) widget.onCameraChanged?.call(_camera!);
    // Pan changes the inverse visible rectangle as well as zoom. Repaint
    // names against that rectangle so they cannot slide under fixed UI.
    setState(() => _screenScale = _view.value.getMaxScaleOnAxis());
  }

  void _applyCamera(ChronologyDepthCamera camera, _StackScene scene) {
    if (!mounted || !identical(scene, _scene) || _size == null) return;
    final transform =
        camera.restore(view: scene.view, viewport: Offset.zero & _size!);
    _applyingCamera = true;
    _view.value = Matrix4.identity()
      ..translateByDouble(
          transform.translation.dx, transform.translation.dy, 0, 1)
      // InteractiveViewer reads the maximum of all three axes. Keeping z
      // at 1 made a fit below 1 report the wrong zoom and drift on orbit.
      ..scaleByDouble(transform.scale, transform.scale, transform.scale, 1);
    _applyingCamera = false;
    _camera = camera;
    _pendingCamera = null;
    setState(() => _screenScale = transform.scale);
    widget.onCameraChanged?.call(camera);
  }

  @override
  void didUpdateWidget(covariant StackedChronologyWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startYear != widget.startYear ||
        oldWidget.endYear != widget.endYear) {
      _pendingCamera = const ChronologyDepthCamera();
      _sceneKey = null;
    }
    if (oldWidget.controller != widget.controller) {
      _pendingCamera = _pendingCamera ?? _captureCamera();
      _view.removeListener(_viewChanged);
      if (_ownsController) _view.dispose();
      _ownsController = widget.controller == null;
      _view = widget.controller ?? TransformationController();
      _view.addListener(_viewChanged);
      _sceneKey = null;
    }
    final reveal = oldWidget.revealRevision != widget.revealRevision;
    if (widget.selectedId != null &&
        (reveal ||
            (oldWidget.selectedId != widget.selectedId &&
                _lastOpenedId != widget.selectedId))) {
      _revealPending = true;
    }
    _lastOpenedId = null;
  }

  @override
  void dispose() {
    _view.removeListener(_viewChanged);
    if (_ownsController) _view.dispose();
    super.dispose();
  }

  void _changeAngles(double yaw, double tilt) {
    _pendingCamera ??= _captureCamera() ?? const ChronologyDepthCamera();
    setState(() {
      _yaw = yaw;
      _tilt = tilt.clamp(.35, 1.0);
      _sceneKey = null;
    });
    widget.onAnglesChanged?.call(_yaw, _tilt);
  }

  void _reset() {
    _pendingCamera = const ChronologyDepthCamera();
    setState(() {
      _yaw = 0;
      _tilt = .70;
      _sceneKey = null;
    });
    widget.onAnglesChanged?.call(_yaw, _tilt);
  }

  void _zoomBy(double factor) {
    final scene = _scene;
    if (scene == null) return;
    final camera = _captureCamera() ?? const ChronologyDepthCamera();
    _applyCamera(
        ChronologyDepthCamera(
          normalizedGroundCentre: camera.normalizedGroundCentre,
          zoom: (camera.zoom * factor).clamp(.8, 120.0),
        ),
        scene);
  }

  void _open(YearDigestItem record) {
    _lastOpenedId = record.id;
    widget.onYear?.call(record.startYear);
    widget.onOpen(record);
  }

  void _reveal(_StackScene scene) {
    final id = widget.selectedId;
    if (id == null) return;
    final matches = scene.prisms.where((p) => p.id == id);
    if (matches.isEmpty) return;
    final prism = matches.first;
    final zoom = math.max(2.0, (_camera?.zoom ?? 1)).clamp(.8, 120.0);
    final viewport = Offset.zero & _size!;
    final scale = zoom * scene.view.fitScale;
    final top = prism.projection
        .polar(prism.middleRadius, prism.middleAngle, height: prism.topHeight);
    // Search names a visible top, not the ground beneath it. At high
    // zoom, centring the ground lifted that top above the viewport. The
    // usual camera capture keeps the resulting view transferable to flat.
    _applyCamera(
        ChronologyDepthCamera.fromProjection(
          projection: scene.projection,
          groundRadius: scene.radius,
          viewport: viewport,
          scale: scale,
          translation: viewport.center - top * scale,
          fitScale: scene.view.fitScale,
          yaw: scene.rotation,
        ),
        scene);
  }

  WheelStackPlan _tiers() {
    final key = widget.groups
        .map((g) =>
            '${g.id}/${g.outerLane}:${g.records.map((r) => '${r.id}/${r.startYear}/${r.endYear}').join(',')}')
        .join('|');
    if (_planKey == key && _plan != null) return _plan!;
    _planKey = key;
    return _plan = planWheelStackTiers([
      for (final group in widget.groups)
        for (final record in group.records)
          WheelStackInterval(
              id: record.id,
              stream: group.id,
              start: record.startYear,
              end: record.endYear),
    ]);
  }

  void _showNames(List<YearDigestItem> records, WbType type) {
    final groupOf = {
      for (final group in widget.groups)
        for (final record in group.records) record.id: group,
    };
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
                      tooltip: MaterialLocalizations.of(sheet).closeButtonLabel,
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.close)),
                ])),
            Expanded(
                child: ListView.builder(
                    itemCount: records.length + 1,
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return Padding(
                          key: const ValueKey('stackedWheelGroupLegend'),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Wrap(spacing: 12, runSpacing: 10, children: [
                            for (final group in widget.groups)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: group.color,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 5),
                                Text(group.name,
                                    style: TextStyle(
                                        fontSize: type.scaledChrome(12))),
                              ]),
                          ]),
                        );
                      }
                      final record = records[index - 1];
                      final group = groupOf[record.id]!;
                      final dates = widget.dateLabel?.call(record) ??
                          '${chronologyYearLabel(record.startYear, widget.locale)}${record.startYear == record.endYear ? '' : ' — ${chronologyYearLabel(record.endYear, widget.locale)}'}';
                      return ListTile(
                        leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: group.color, shape: BoxShape.circle)),
                        title: Text(widget.label(record)),
                        subtitle: Text('${group.name} · $dates'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(sheet);
                          // A name may belong to a record outside this
                          // zoomed viewport; direct canvas picks already
                          // have a visible target and keep their camera.
                          setState(() => _revealPending = true);
                          _open(record);
                        },
                      );
                    })),
          ])),
    );
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

  void _chooseSpacing() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
            key: const ValueKey('stackedWheelSpacingSheet'),
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                        child: Text(_s('spacing'),
                            style: Theme.of(sheet).textTheme.titleLarge)),
                    IconButton(
                        tooltip:
                            MaterialLocalizations.of(sheet).closeButtonLabel,
                        onPressed: () => Navigator.pop(sheet),
                        icon: const Icon(Icons.close)),
                  ])),
              for (final option in const [
                (key: 'stackedWheelSpacingCompact', text: 'compact', lift: 1.0),
                (
                  key: 'stackedWheelSpacingStandard',
                  text: 'standard',
                  lift: 4.0
                ),
                (
                  key: 'stackedWheelSpacingExpanded',
                  text: 'expanded',
                  lift: 10.0
                ),
              ])
                ListTile(
                  key: ValueKey(option.key),
                  selected: _lift == option.lift,
                  leading: Icon(_lift == option.lift
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
                  title: Text(_s(option.text)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _pendingCamera ??= _captureCamera();
                    setState(() {
                      _lift = option.lift;
                      _sceneKey = null;
                    });
                    widget.onLiftChanged?.call(_lift);
                  },
                ),
            ]),
          ));

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    final plan = _tiers();
    final records = [
      for (final group in widget.groups)
        for (final record in group.records)
          if (record.endYear >= widget.startYear &&
              record.startYear <= widget.endYear)
            record,
    ]..sort((a, b) => a.startYear.compareTo(b.startYear));
    return ColoredBox(
        color: wb.paneBg,
        child: Column(children: [
          Expanded(child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            if (size.width <= 0 || size.height <= 0) {
              return const SizedBox.shrink();
            }
            final key = (
              _planKey,
              size,
              _yaw,
              _tilt,
              _lift,
              widget.startYear,
              widget.endYear
            );
            if (_sceneKey != key) {
              _pendingCamera ??= _camera;
              _sceneKey = key;
              _size = size;
              _scene = _StackScene.build(
                  groups: widget.groups,
                  plan: plan,
                  size: size,
                  yaw: _yaw,
                  tilt: _tilt,
                  lift: _lift,
                  start: widget.startYear,
                  end: widget.endYear);
              final scene = _scene!;
              final camera = _pendingCamera ?? const ChronologyDepthCamera();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !identical(scene, _scene)) return;
                _applyCamera(camera, scene);
                if (_revealPending) {
                  _revealPending = false;
                  _reveal(scene);
                }
              });
            } else if (_revealPending) {
              _revealPending = false;
              final scene = _scene!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && identical(scene, _scene)) _reveal(scene);
              });
            }
            final scene = _scene!;
            final scale = math.max(.001, _screenScale);
            final visible = Rect.fromPoints(
              _view.toScene(const Offset(6, 32)),
              _view.toScene(Offset(size.width - 6, size.height - 4)),
            );
            return Stack(children: [
              // A raised point can have negative scene y while its fitted
              // image is visible. Receive gestures in the viewport, then
              // invert the camera; the child's original hit box excludes it.
              Positioned.fill(
                  child: Listener(
                onPointerDown: (event) {
                  _pointers.add(event.pointer);
                  if (_pointers.length == 1) {
                    _dragOrigin = event.position;
                    _dragged = false;
                  }
                },
                onPointerMove: (event) {
                  if (_dragOrigin != null &&
                      (event.position - _dragOrigin!).distance > 5) {
                    _dragged = true;
                  }
                  if (!_panMode && _pointers.length == 1 && _dragged) {
                    // 2026-09-15: 「我用鼠标旋转wheel都反了」 — and it was.
                    //
                    // `_rotate` is the standard matrix, and screen space
                    // has y DOWN, so a positive angle turns the wheel
                    // CLOCKWISE. Think of a clock face: rotate it
                    // clockwise and the point at six o'clock travels
                    // LEFT. Six o'clock is the near edge of a tilted
                    // wheel — the part under the reader's hand — so
                    // `+dx` sent the thing being dragged in the
                    // opposite direction to the drag.
                    //
                    // A DRAG AND A BUTTON ARE DIFFERENT METAPHORS, which
                    // is why only this line flips. `Icons.rotate_right`
                    // promises "turn it clockwise" and `_yaw + π/12`
                    // delivers exactly that; a drag promises "what is
                    // under my finger follows my finger", and that is
                    // the opposite sign. Both are now true.
                    //
                    // The vertical axis was already right and is left
                    // alone: `_tilt` is a SQUASH (1 = seen from
                    // directly above, .35 = nearly edge-on), so
                    // dragging down raises it, which tips the near edge
                    // toward the reader and lays the wheel flatter —
                    // which is what pulling the front of a turntable
                    // downward does.
                    _changeAngles(_yaw - event.delta.dx * .009,
                        _tilt + event.delta.dy * .003);
                  }
                },
                onPointerUp: (event) => _pointers.remove(event.pointer),
                onPointerCancel: (event) => _pointers.remove(event.pointer),
                child: GestureDetector(
                  key: const ValueKey('stackedChronologyWheel'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (event) {
                    if (_dragged) return;
                    final point = _view.toScene(event.localPosition);
                    for (final callout in scene.callouts.reversed) {
                      if (callout.bounds.inflate(4 / scale).contains(point)) {
                        _open(scene.records[callout.id]!);
                        return;
                      }
                    }
                    final hit = hitWheelStackPrism(scene.prisms, point,
                        pointRadius: 6 / scale);
                    if (hit != null) {
                      _open(scene.records[hit.id]!);
                    } else {
                      final year = chronologyDepthYearAt(
                        point: point,
                        projection: scene.projection,
                        startYear: scene.start,
                        endYear: scene.end,
                        yaw: _yaw,
                        innerRadius: scene.baseInner,
                        outerRadius: scene.radius,
                      );
                      if (year != null) widget.onYear?.call(year);
                    }
                  },
                  child: InteractiveViewer(
                    // A TRACKPAD'S TWO FINGERS ZOOM, like the wheel's.
                    // 2026-09-16 「wheel strip可以鼠标上下滑zoom in out吗
                    // 然后ipad可以两个手指zoom in out这样」. A mouse wheel
                    // already scaled; a trackpad's two-finger scroll
                    // arrives as a pan gesture instead and was panning a
                    // chart nobody wanted to pan. A pinch on a touch
                    // screen was always a scale and is unaffected.
                    trackpadScrollCausesScale: true,
                    transformationController: _view,
                    minScale: scene.view.fitScale * .8,
                    maxScale: scene.view.fitScale * 120,
                    panEnabled: _panMode,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: RepaintBoundary(
                        child: CustomPaint(
                            size: size,
                            painter: _StackedWheelPainter(
                              scene: scene,
                              groups: widget.groups,
                              plan: plan,
                              label: widget.label,
                              locale: widget.locale,
                              wb: wb,
                              fontFamily: type.fontFamily ?? 'Roboto',
                              fontSize: type.scaledChrome(12) *
                                  math.min(1.4, scale / scene.view.fitScale) /
                                  scale,
                              selectedId: widget.selectedId,
                              cursorYear: widget.cursorYear,
                              symbols: ChartSymbolService.instance.cached,
                              zoom: scale,
                              visible: visible,
                            ))),
                  ),
                ),
              )),
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 32,
                  child: AbsorbPointer(
                      child: ColoredBox(
                          key: const ValueKey('stackedWheelReadout'),
                          color: wb.paneBg,
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(children: [
                                Expanded(
                                    child: Text(
                                        '${chronologyYearLabel(chronologyPeriods.first.start, widget.locale)} — ${chronologyYearLabel(chronologyPeriods.first.end, widget.locale)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: type.scaledChrome(11),
                                            color: wb.mutedText))),
                                Text('${records.length} ${_s('records')}',
                                    style: TextStyle(
                                        fontSize: type.scaledChrome(11),
                                        color: wb.mutedText)),
                              ]))))),
              if (records.isEmpty)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_s('empty'), textAlign: TextAlign.center))),
            ]);
          })),
          _footer(records, type, wb),
        ]));
  }

  Widget _footer(List<YearDigestItem> records, WbType type, WbColors wb) =>
      Container(
        key: const ValueKey('stackedWheelFooter'),
        height: stackedWheelFooterHeight,
        foregroundDecoration:
            BoxDecoration(border: Border(top: BorderSide(color: wb.border))),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(children: [
          SizedBox(
              height: 44,
              child: Row(children: [
                Tooltip(
                    message: _s(_panMode ? 'panMode' : 'rotateMode'),
                    child: TextButton.icon(
                      key: const ValueKey('stackedWheelGestureMode'),
                      onPressed: () => setState(() => _panMode = !_panMode),
                      style: TextButton.styleFrom(
                          minimumSize: const Size(82, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 6)),
                      icon: Icon(
                          _panMode
                              ? Icons.pan_tool_outlined
                              : Icons.threed_rotation,
                          size: 19),
                      label: Text(_s(_panMode ? 'panMode' : 'rotateMode'),
                          style: TextStyle(fontSize: type.scaledChrome(11))),
                    )),
                Text(_s('tilt'),
                    style: TextStyle(
                        fontSize: type.scaledChrome(11), color: wb.mutedText)),
                Expanded(
                    child: Slider(
                  key: const ValueKey('stackedWheelTilt'),
                  min: .35,
                  max: 1,
                  value: _tilt,
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()}%',
                  onChanged: (value) => _changeAngles(_yaw, value),
                )),
                _button('stackedWheelExpand', Icons.layers, 'spacing',
                    _chooseSpacing),
                _button('stackedWheelHelp', Icons.help_outline, 'help', _help),
              ])),
          SizedBox(
              height: 44,
              child: Row(children: [
                _button('stackedRotateLeft', Icons.rotate_left, 'rotateLeft',
                    () => _changeAngles(_yaw - math.pi / 12, _tilt)),
                _button('stackedRotateRight', Icons.rotate_right, 'rotateRight',
                    () => _changeAngles(_yaw + math.pi / 12, _tilt)),
                Expanded(
                    child: TextButton(
                  key: const ValueKey('stackedWheelAllNames'),
                  onPressed: () => _showNames(records, type),
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 2)),
                  child: Text(_s('allNames'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: type.scaledChrome(11))),
                )),
                _button('stackedZoomOut', Icons.remove, 'out',
                    () => _zoomBy(1 / 1.4)),
                _button(
                    'stackedReset', Icons.center_focus_strong, 'fit', _reset),
                _button('stackedZoomIn', Icons.add, 'in', () => _zoomBy(1.4)),
              ])),
        ]),
      );

  Widget _button(String key, IconData icon, String tip, VoidCallback go) =>
      SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
            key: ValueKey(key),
            tooltip: _s(tip),
            onPressed: go,
            icon: Icon(icon, size: 20)),
      );
}

class _StackScene {
  _StackScene(
      {required this.prisms,
      required this.records,
      required this.groupOf,
      required this.view,
      required this.rings,
      required this.radius,
      required this.baseInner,
      required this.rotation,
      required this.start,
      required this.end});
  final List<WheelStackPrism> prisms;
  final List<WheelStackCallout> callouts = [];
  final Map<String, YearDigestItem> records;
  final Map<String, StackedChronologyGroup> groupOf;
  final ChronologyDepthView view;
  final List<ChronologyDepthRingLayout> rings;
  WheelStackProjection get projection => view.projection;
  final double radius;
  final double baseInner;
  final double rotation;
  final int start;
  final int end;

  factory _StackScene.build(
      {required List<StackedChronologyGroup> groups,
      required WheelStackPlan plan,
      required Size size,
      required double yaw,
      required double tilt,
      required double lift,
      required int start,
      required int end}) {
    final side = math.min(size.width, size.height);
    final hub = side * .115;
    final bands = side * bandsFractionFor(side);
    final rim = side * rimFractionFor(side);
    final countries = groups.where((g) => !g.outerLane).toList();
    final outer = groups.where((g) => g.outerLane).toList();
    final inputs = [
      ...chronologyDepthRingInputs(
          ringIds: countries.map((g) => g.id).toList(),
          depthByStream: plan.depthByStream,
          hubRadius: hub,
          outerRadius: bands),
      ...chronologyDepthRingInputs(
          ringIds: outer.map((g) => g.id).toList(),
          depthByStream: plan.depthByStream,
          hubRadius: bands,
          outerRadius: rim),
    ];
    final rings = planChronologyDepthRings(inputs, tilt: tilt, lift: lift);
    final maxHeight = rings.fold(0.0, (h, ring) => math.max(h, ring.maxHeight));
    // The fit reserves the fixed top readout and axis text; its origin is
    // the same viewport centre as flat, making a shared matrix safe to use.
    final verticalMargin = math.min(34.0, (size.height - 1) / 2);
    final horizontalMargin = math.min(12.0, (size.width - 1) / 2);
    final content = Rect.fromLTRB(horizontalMargin, verticalMargin,
        size.width - horizontalMargin, size.height - verticalMargin);
    final view = ChronologyDepthView(
      projection:
          WheelStackProjection(centre: size.center(Offset.zero), squash: tilt),
      groundRadius: rim,
      contentArea: content,
      maxHeight: maxHeight,
      yaw: yaw,
    );
    final byId = {for (final ring in rings) ring.id: ring};
    final records = <String, YearDigestItem>{};
    final groupOf = <String, StackedChronologyGroup>{};
    final prisms = <WheelStackPrism>[];
    final axis = chronologyPeriods.first;
    for (final group in groups) {
      final ring = byId[group.id]!;
      for (final record in group.records) {
        if (record.endYear < start || record.startYear > end) continue;
        final tier = plan.tierById[record.id] ?? 0;
        records[record.id] = record;
        groupOf[record.id] = group;
        prisms.add(WheelStackPrism(
          id: record.id,
          projection: view.projection,
          innerRadius: ring.innerRadius,
          outerRadius: ring.outerRadius,
          startAngle:
              angleForSpan(record.startYear, axis.start, axis.end) + yaw,
          endAngle: angleForSpan(record.endYear, axis.start, axis.end) + yaw,
          bottomHeight: ring.bottomHeight(tier),
          topHeight: ring.topHeight(tier),
        ));
      }
    }
    return _StackScene(
        prisms: wheelStackPaintOrder(prisms),
        records: records,
        groupOf: groupOf,
        view: view,
        rings: rings,
        radius: rim,
        baseInner: hub,
        rotation: yaw,
        start: axis.start,
        end: axis.end);
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
      required this.selectedId,
      required this.cursorYear,
      required this.symbols,
      required this.visible});
  final _StackScene scene;
  final List<StackedChronologyGroup> groups;
  final WheelStackPlan plan;
  final String Function(YearDigestItem) label;
  final String locale;
  final WbColors wb;
  final double fontSize;
  final String fontFamily;
  final double zoom;
  final String? selectedId;
  final int? cursorYear;

  /// Decoded silhouettes by asset name; empty until they load.
  final Map<String, ui.Image> symbols;
  final Rect visible;
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
        innerRadius: math.max(0, scene.baseInner - 2),
        outerRadius: scene.radius,
        startAngle: startRad + scene.rotation,
        endAngle: startRad + sweepRad + scene.rotation,
        bottomHeight: 0,
        topHeight: 0);
    canvas.drawPath(base.topPath,
        Paint()..color = Color.lerp(wb.paneBg, wb.mutedText, .07)!);
    if (cursorYear != null) {
      final angle =
          angleForSpan(cursorYear!, scene.start, scene.end) + scene.rotation;
      canvas.drawLine(
          p.polar(scene.baseInner, angle),
          p.polar(scene.radius, angle),
          Paint()
            ..color = wb.accent.withValues(alpha: .50)
            ..strokeWidth = 1.5 / zoom);
    }
    for (final ring in scene.rings) {
      final group = groups.firstWhere((g) => g.id == ring.id);
      final outline = WheelStackPrism(
          id: 'ring:${ring.id}',
          projection: p,
          innerRadius: ring.innerRadius,
          outerRadius: ring.outerRadius,
          startAngle: startRad + scene.rotation,
          endAngle: startRad + sweepRad + scene.rotation,
          bottomHeight: 0,
          topHeight: 0);
      canvas.drawPath(
          outline.topPath, Paint()..color = group.color.withValues(alpha: .06));
      canvas.drawPath(
          outline.topPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .45 / zoom
            ..color = group.color.withValues(alpha: .20));
    }
    for (final prism in scene.prisms) {
      if (prism.sweep != 0 &&
          !prism.bounds.overlaps(visible.inflate(16 / zoom))) {
        continue;
      }
      final group = scene.groupOf[prism.id]!;
      final selected = selectedId == prism.id;
      final tier = plan.tierById[prism.id] ?? 0;
      final color = Color.lerp(group.color, wb.paneBg, .16 + (tier % 3) * .10)!;
      var side = 0;
      for (final wall in prism.sidePaths) {
        canvas.drawPath(
            wall,
            Paint()
              ..color = Color.lerp(
                  color, Colors.black, side++ % 2 == 0 ? .30 : .20)!);
      }
      canvas.drawPath(prism.topPath, Paint()..color = color);
      canvas.drawPath(
          prism.topPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (selected ? 2.2 : .55) / zoom
            ..color = selected ? wb.accent : wb.paneBg.withValues(alpha: .75));
      if (prism.sweep == 0) {
        final point = p.polar(prism.middleRadius, prism.middleAngle,
            height: prism.topHeight);
        canvas.drawCircle(point, (selected ? 4 : 3) / zoom,
            Paint()..color = selected ? wb.accent : group.color);
      }
    }
    _paintGroupSymbols(canvas, p);
    final occupied = <Rect>[];
    _axis(canvas, occupied);
    final style = canvasTextStyle(
            fontSize: fontSize, color: wb.text, fontWeight: FontWeight.w600)
        .copyWith(fontFamily: fontFamily);
    _groupLabels(canvas, style, occupied);
    var admitted = 0;
    // Reject impossible faces before shaping text. All names remain in
    // the sheet and parent digest; dragging must not shape every record.
    final budget = stackLabelBudget(zoom, scene.view.fitScale);
    for (var i = scene.prisms.length - 1; i >= 0 && admitted < budget; i--) {
      final prism = scene.prisms[i];
      if (prism.sweep == 0 || !prism.bounds.overlaps(visible)) continue;
      if ((prism.outerRadius - prism.innerRadius) * scene.projection.squash <
              fontSize * 1.25 ||
          prism.middleRadius * prism.sweep < fontSize * 2) {
        continue;
      }
      final paragraph =
          WheelTextMetrics.paragraphOf(label(scene.records[prism.id]!), style);
      final placement = wheelStackLabelPlacement(
          prism, Size(paragraph.maxIntrinsicWidth, paragraph.height),
          padding: 2 / zoom,
          pointRadius: 3 / zoom,
          occluders: scene.prisms.skip(i + 1),
          occupied: occupied,
          beside: scene.prisms);
      if (placement == null || !_inside(placement.bounds, visible)) continue;
      admitted++;
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
    _callouts(canvas, style, occupied);
  }

  void _callouts(Canvas canvas, TextStyle style, List<Rect> occupied) {
    // A wider bank, and fewer names in it on a narrow canvas.
    //
    // 2026-09-15, from a phone render: seven callouts down both sides
    // squeezed the chart into the middle third, and two of them
    // ('以色列王后…', '西奈山…') were ellipsised — a callout that cannot
    // show the whole name is printing a word that is not the record's
    // name, with a leader line pointing at the record to confirm it.
    final bankWidth = math.min(140 / zoom, visible.width * .26);
    final perSide = visible.width < 520 ? 2 : 4;
    if (bankWidth < fontSize * 2) return;
    // Bounded candidates keep rotate frames cheap. The complete prism list
    // still supplies occlusion; excluded names do not make a wall vanish.
    final candidates = <String>{};
    final perGroup = <String, int>{};
    if (selectedId != null && scene.records.containsKey(selectedId)) {
      candidates.add(selectedId!);
    }
    for (final prism in scene.prisms.reversed) {
      if (candidates.length >= 24) break;
      if (paintedRecordIds.contains(prism.id) ||
          (prism.sweep != 0 && !prism.bounds.overlaps(visible))) {
        continue;
      }
      final group = scene.groupOf[prism.id]!.id;
      if ((perGroup[group] ?? 0) >= 2) continue;
      perGroup[group] = (perGroup[group] ?? 0) + 1;
      candidates.add(prism.id);
    }
    // WHOLE NAME OR NO NAME. This used to binary-search for the longest
    // prefix that fitted and add an ellipsis, which is how 以色列王后耶洗别
    // became 「以色列王后…」 — a leader line pointing confidently at a
    // record whose name it is not showing. A name that will not fit
    // yields its slot to one that will; the record keeps its block, its
    // symbol, its tap and its row in the list below.
    final paragraphs = <String, ui.Paragraph>{};
    final tooWide = <String>{};
    for (final id in candidates) {
      final paragraph =
          WheelTextMetrics.paragraphOf(label(scene.records[id]!), style);
      if (paragraph.maxIntrinsicWidth > bankWidth) {
        tooWide.add(id);
        continue;
      }
      paragraphs[id] = paragraph;
    }
    final callouts = planWheelStackCallouts(
      paintOrder: scene.prisms,
      contentArea: visible,
      bankWidth: bankWidth,
      gap: 7 / zoom,
      leaderGap: 5 / zoom,
      pointRadius: 3 / zoom,
      maxPerSide: perSide,
      measure: (id) =>
          Size(paragraphs[id]!.maxIntrinsicWidth, paragraphs[id]!.height),
      occupied: occupied,
      excludedIds: {
        for (final prism in scene.prisms)
          if (!candidates.contains(prism.id) ||
              tooWide.contains(prism.id) ||
              paintedRecordIds.contains(prism.id))
            prism.id
      },
    );
    scene.callouts.addAll(callouts);
    for (final callout in callouts) {
      final color = scene.groupOf[callout.id]!.color;
      canvas.drawLine(
          callout.anchor,
          callout.leaderEnd,
          Paint()
            ..color = color.withValues(alpha: .65)
            ..strokeWidth = .8 / zoom);
      canvas.drawCircle(callout.anchor, 1.7 / zoom, Paint()..color = color);
      canvas.drawParagraph(paragraphs[callout.id]!, callout.bounds.topLeft);
      paintedLabelBounds.add(callout.bounds);
      paintedRecordIds.add(callout.id);
    }
  }

  void _groupLabels(Canvas canvas, TextStyle style, List<Rect> occupied) {
    final gapAngle = startRad + (sweepRad + 2 * math.pi) / 2 + scene.rotation;
    for (final ring in scene.rings) {
      // Country names occupy the unused date wedge, at their original
      // radius. A narrow fit ring recovers its full name in the sheet's
      // colour legend rather than borrowing another country's label row.
      if ((ring.outerRadius - ring.innerRadius) * scene.projection.squash <
          fontSize * 1.1) {
        continue;
      }
      final group = groups.firstWhere((group) => group.id == ring.id);
      final paragraph = WheelTextMetrics.paragraphOf(group.name, style);
      final centre = scene.projection
          .polar((ring.innerRadius + ring.outerRadius) / 2, gapAngle);
      final rect = Rect.fromCenter(
          center: centre,
          width: paragraph.maxIntrinsicWidth,
          height: paragraph.height);
      if (!_inside(rect, visible) ||
          _occluded(rect) ||
          occupied.any((other) => other.overlaps(rect.inflate(3 / zoom)))) {
        continue;
      }
      occupied.add(rect.inflate(3 / zoom));
      paintedLabelBounds.add(rect);
      canvas.drawParagraph(paragraph, rect.topLeft);
    }
  }

  /// One silhouette per stream, standing on the first block that
  /// stream has.
  ///
  /// THIS IS WHAT THE 3D VIEW WAS MISSING, in the owner's own words:
  /// 「上面也没有写字看不出是什么啊」 — a field of coloured blocks with
  /// nothing on them. The obvious answer is to write the names on the
  /// faces, and it is the wrong one: this view TURNS, so any word put
  /// on it has to choose a bearing and is upside down from half of
  /// them. A silhouette has no bearing. A pyramid seen from behind is
  /// still a pyramid.
  ///
  /// One per stream, on its earliest block, for the same reason the
  /// flat wheel does it that way: the corpus holds 1,039 records, and a
  /// picture on each is the crowding complaint again in another medium.
  ///
  /// Drawn flat to the screen rather than sheared onto the face. The
  /// projection squashes the vertical axis, so a sheared silhouette
  /// would be a squashed silhouette — and legibility is the entire
  /// reason these are here.
  void _paintGroupSymbols(Canvas canvas, WheelStackProjection p) {
    if (symbols.isEmpty) return;
    final firstOf = <String, WheelStackPrism>{};
    for (final prism in scene.prisms) {
      final group = scene.groupOf[prism.id];
      if (group == null) continue;
      final held = firstOf[group.id];
      if (held == null || prism.startAngle < held.startAngle) {
        firstOf[group.id] = prism;
      }
    }
    for (final group in groups) {
      final image = symbols[symbolForStream(group.id)];
      final prism = firstOf[group.id];
      if (image == null || prism == null) continue;
      final centre = p.polar(prism.middleRadius, prism.middleAngle,
          height: prism.topHeight);
      // Off the top face by a little, so the mark reads as standing on
      // the block rather than lying on it, and never larger than it
      // would be at rest.
      final size = math.min(
          (prism.outerRadius - prism.innerRadius) * p.squash * 1.6, 26 / zoom);
      if (size <= 2) continue;
      final at = centre.translate(0, -size * 0.55);
      if (!visible.inflate(size).contains(at)) continue;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: at, width: size, height: size),
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(
              Color.lerp(group.color, wb.text, .25)!, BlendMode.srcIn),
      );
    }
  }

  void _axis(Canvas canvas, List<Rect> occupied) {
    final years = [
      scene.start,
      scene.end,
      for (var year = (scene.start / 1000).ceil() * 1000;
          year < scene.end;
          year += 1000)
        if (year != scene.start) year,
    ];
    for (final year in years) {
      final angle = angleForSpan(year, scene.start, scene.end) + scene.rotation;
      final a = scene.projection.polar(scene.radius, angle);
      final b = scene.projection.polar(scene.radius + 5 / zoom, angle);
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = wb.mutedText.withValues(alpha: .55)
            ..strokeWidth = .8 / zoom);
      final paragraph = WheelTextMetrics.paragraphOf(
          chronologyYearLabel(year, locale),
          canvasTextStyle(fontSize: fontSize * .86, color: wb.mutedText)
              .copyWith(fontFamily: fontFamily));
      final location = scene.projection.polar(scene.radius + 12 / zoom, angle);
      final rect = Rect.fromCenter(
          center: location,
          width: paragraph.maxIntrinsicWidth,
          height: paragraph.height);
      if (!_inside(rect, visible) ||
          occupied.any((r) => r.overlaps(rect.inflate(3 / zoom))) ||
          _occluded(rect)) {
        continue;
      }
      occupied.add(rect);
      paintedLabelBounds.add(rect);
      canvas.drawParagraph(paragraph, rect.topLeft);
    }
  }

  bool _occluded(Rect rect) {
    final path = Path()..addRect(rect);
    return scene.prisms.any((prism) =>
        prism.bounds.overlaps(rect) &&
        !Path.combine(PathOperation.intersect, path, prism.footprint)
            .getBounds()
            .isEmpty);
  }

  bool _inside(Rect rect, Rect outer) =>
      outer.contains(rect.topLeft) && outer.contains(rect.bottomRight);

  @override
  bool shouldRepaint(covariant _StackedWheelPainter old) =>
      old.scene != scene ||
      old.selectedId != selectedId ||
      old.cursorYear != cursorYear ||
      old.wb != wb ||
      old.fontSize != fontSize ||
      old.fontFamily != fontFamily ||
      old.locale != locale ||
      // The symbols arrive after the first frame — a map that changes
      // from empty to twenty images has to repaint, or the blocks stay
      // blank until something else happens to invalidate the painter.
      old.symbols != symbols ||
      old.visible != visible;
}
