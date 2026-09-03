import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show packWheelBand;
import 'package:seeksparks/utils/radial_chronology_layout.dart';

void main() {
  test('measure', () {
    final chron = ChronologyData.fromJson(
        jsonDecode(File('assets/chronology.json').readAsStringSync())
            as Map<String, dynamic>);
    final whJson =
        jsonDecode(File('assets/wheel_history.json').readAsStringSync())
            as Map<String, dynamic>;
    final ministries = (whJson['ministries'] as List)
        .cast<Map<String, dynamic>>()
        .map(WheelMinistry.fromJson)
        .toList();
    final kings = ((jsonDecode(
                File('assets/hebrew_kings.json').readAsStringSync())
            as Map<String, dynamic>)['kings'] as List)
        .cast<Map<String, dynamic>>()
        .map(HebrewKing.fromJson)
        .toList();
    const creation = -4114;
    final sets = <(String, List<HebrewKing>, List<WheelMinistry>)>[
      ('patriarchs only', <HebrewKing>[], <WheelMinistry>[]),
      ('plus kings', kings, <WheelMinistry>[]),
      ('plus ministries', kings, ministries),
    ];
    for (final s in sets) {
      final a = packWheelBand(
          chron: chron,
          creationYear: creation,
          kings: s.$2,
          ministries: s.$3);
      // ignore: avoid_print
      print('MEAS ${s.$1}: arcs=${a.length} rings=${lifeArcRingCount(a)}');
      for (final side in [700.0, 900.0, 1400.0]) {
        final inner = scriptureLabelBase(side * 0.285);
        final pitch = ringPitch(lifeArcRingCount(a), inner, side * 0.445);
        // ignore: avoid_print
        print('MEAS    $side px -> pitch ${pitch.toStringAsFixed(2)}');
      }
    }
  });
}
