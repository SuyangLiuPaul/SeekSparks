/// Decodes the chronology symbols once, so the painters can draw them.
///
/// A `CustomPainter` cannot await anything, and `ui.Image` is the only
/// form `Canvas.drawImageRect` accepts — so the decode has to happen
/// before the first frame that wants one, and the result has to be a
/// plain synchronous map. That is this file's whole job.
///
/// Modelled on `WheelHistoryService`: one instance, one in-flight
/// future, a cache the page can read without awaiting. A page that
/// draws before the load completes simply draws no symbols, which is
/// the correct degradation — the rings, the marks and the year scale
/// are the chart, and the symbols are an aid to reading it.
library;

import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import 'package:yahwehs_sword/utils/chronology_symbols.dart';

class ChartSymbolService {
  ChartSymbolService._();

  static final ChartSymbolService instance = ChartSymbolService._();

  Map<String, ui.Image>? _cache;
  Future<Map<String, ui.Image>>? _inFlight;

  /// What the painters read. Empty until [load] has completed, and
  /// deliberately never null: a painter must not have to ask whether
  /// the symbols arrived, only whether this one is in the map.
  Map<String, ui.Image> get cached => _cache ?? const <String, ui.Image>{};

  Future<Map<String, ui.Image>> load() =>
      _inFlight ??= _load().then((value) => _cache = value);

  Future<Map<String, ui.Image>> _load() async {
    final out = <String, ui.Image>{};
    for (final name in kChartSymbolAssets) {
      final data = await rootBundle.load('assets/chart_icons/$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      out[name] = (await codec.getNextFrame()).image;
    }
    return out;
  }

  /// Tests only. The images are owned for the life of the process
  /// otherwise — twenty 96 px silhouettes, decoded once.
  void resetForTest() {
    _cache = null;
    _inFlight = null;
  }
}
