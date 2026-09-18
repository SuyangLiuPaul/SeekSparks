/// The chronology symbols: the table, the assets, and the decode.
///
/// 2026-09-15 「需要的话可以在这些上面生成象征性的东西标志 人物 建筑」.
///
/// Three ways this can rot silently, and one test each:
///
///   * the TABLE names an asset that is not in the folder — the symbol
///     simply never draws, on a chart that looks fine otherwise;
///   * the FOLDER carries an asset nothing names — dead weight in every
///     build, on every device, forever;
///   * the TABLE names a stream the corpus does not have — a symbol
///     that can never appear, which reads as "this stream has none".
///
/// None of the three produces an error at runtime. All three are cheap
/// to catch here.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_sword/services/chart_symbol_service.dart';
import 'package:yahwehs_sword/utils/chronology_symbols.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Set<String> assetsOnDisk() => Directory('assets/chart_icons')
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.endsWith('.png'))
      .map((n) => n.substring(0, n.length - 4))
      .toSet();

  test('every symbol the table names is on disk', () {
    final disk = assetsOnDisk();
    for (final entry in kStreamSymbols.entries) {
      expect(disk, contains(entry.value),
          reason: '${entry.key} points at ${entry.value}.png, which is not '
              'in assets/chart_icons — it would silently never draw');
    }
  });

  test('every asset on disk is named by the table', () {
    // The other direction, and the one that costs bytes rather than
    // pixels. `tablets.png` was cut on the day these were made for
    // exactly this reason: nothing in the table asked for it.
    expect(assetsOnDisk().difference(kStreamSymbols.values.toSet()), isEmpty,
        reason: 'assets nothing references are shipped to every device');
  });

  test('the assets are declared to the bundler', () async {
    // A folder that exists in the repo and not in `pubspec.yaml` loads
    // fine from `dart:io` in a test and throws on a device.
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('assets/chart_icons/'));
  });

  test('every stream the table names is a stream the corpus has', () {
    final raw = json.decode(File('assets/wheel_history.json').readAsStringSync())
        as Map<String, dynamic>;
    final ids = {
      for (final s in (raw['streams'] as List).cast<Map<String, dynamic>>())
        s['id'] as String
    };
    for (final id in kStreamSymbols.keys) {
      expect(ids, contains(id), reason: '$id is not a stream in the corpus');
    }
  });

  test('the streams without a symbol are without one on purpose', () {
    // Anatolia, Philistia and Arabia. Pinned so that a later edit which
    // gives them an arbitrary mark has to come through here and say
    // why: a symbol a reader has to be taught is worse than none,
    // because they will read it as meaning something.
    final raw = json.decode(File('assets/wheel_history.json').readAsStringSync())
        as Map<String, dynamic>;
    final ids = {
      for (final s in (raw['streams'] as List).cast<Map<String, dynamic>>())
        s['id'] as String
    };
    expect(ids.difference(kStreamSymbols.keys.toSet()),
        {'anatolia', 'philistia', 'arabia'});
  });

  testWidgets('the service decodes all of them, once', (tester) async {
    ChartSymbolService.instance.resetForTest();
    addTearDown(ChartSymbolService.instance.resetForTest);
    expect(ChartSymbolService.instance.cached, isEmpty,
        reason: 'the painters must be able to read this before it loads');

    late Map<String, Object?> loaded;
    await tester.runAsync(() async {
      loaded = {...await ChartSymbolService.instance.load()};
    });
    expect(loaded.keys.toSet(), kChartSymbolAssets.toSet());
    expect(ChartSymbolService.instance.cached.length, kChartSymbolAssets.length);

    // Square, and big enough that a 22 px draw at 3x is not upscaled.
    for (final entry in ChartSymbolService.instance.cached.entries) {
      final image = entry.value;
      expect(image.width, image.height, reason: '${entry.key} is not square');
      expect(image.width, greaterThanOrEqualTo(96),
          reason: '${entry.key} is ${image.width} px and will soften');
    }
  });

  testWidgets('the silhouettes are white-on-transparent, so the palette '
      'tints them', (tester) async {
    await tester.runAsync(() async {
    // The whole reason `BlendMode.srcIn` works. If a future asset ships
    // with its own colour baked in, it will ignore the theme and sit on
    // a night ground in a daylight hue.
    for (final name in kChartSymbolAssets) {
      final data = await rootBundle.load('assets/chart_icons/$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData();
      var opaque = 0;
      var coloured = 0;
      for (var i = 0; i < bytes!.lengthInBytes; i += 4) {
        if (bytes.getUint8(i + 3) < 250) continue;
        opaque++;
        if (bytes.getUint8(i) < 250 ||
            bytes.getUint8(i + 1) < 250 ||
            bytes.getUint8(i + 2) < 250) {
          coloured++;
        }
      }
      expect(opaque, greaterThan(200), reason: '$name is nearly empty');
      expect(coloured, 0,
          reason: '$name carries its own colour in $coloured opaque pixels, '
              'so the theme cannot tint it');
    }
    });
  });
}
