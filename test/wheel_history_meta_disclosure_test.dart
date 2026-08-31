// The wheel's own header — `_meta` in assets/wheel_history.json — carries
// eight fields. `wheel_history_disclosure_test.dart` was written to catch an
// asset field nothing reads, but it iterates the four record lists
// (`streams`, `nations`, `powers`, `events`) and is blind to the header by
// construction. This file guards the header itself (#318 phase 24).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';

/// Strips `//` line comments — copied from
/// `wheel_timeline_field_coverage_test.dart` rather than reinvented.
String _code(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('//');
      return i < 0 ? l : l.substring(0, i);
    })
    .join('\n');

const _locales = ['en', 'zh-Hans', 'zh-Hant'];

void main() {
  final raw =
      json.decode(File('assets/wheel_history.json').readAsStringSync())
          as Map<String, dynamic>;
  final data = WheelHistoryData.fromJson(raw);

  test('the wheel\'s own header parses into the model', () {
    for (final m in [
      data.meta.provenance,
      data.meta.coverage,
      data.meta.scope,
      data.meta.axis,
    ]) {
      expect(m.keys.toSet(), containsAll(_locales));
      for (final l in _locales) {
        expect(m[l], isNotEmpty);
      }
    }
  });

  test('every reader-facing header field reads in all three scripts', () {
    for (final getter in [
      data.meta.provenanceFor,
      data.meta.coverageFor,
      data.meta.scopeFor,
      data.meta.axisFor,
    ]) {
      final en = getter('en');
      expect(en, isNotEmpty);
      for (final l in ['zh-Hans', 'zh-Hant']) {
        final v = getter(l);
        expect(v, isNotEmpty);
        expect(v, isNot(equals(en)),
            reason: 'a Chinese locale fell back to English through _pick — '
                'the translation is missing, not just short');
      }
    }
  });

  test('the header survives the merge that builds the returned data', () {
    final src =
        _code(File('lib/models/wheel_history.dart').readAsStringSync());

    final classStart = src.indexOf('class WheelHistoryData {');
    expect(classStart, greaterThanOrEqualTo(0),
        reason: 'WheelHistoryData class not found');
    final braceStart = src.indexOf('{', classStart);
    var depth = 0;
    var braceEnd = -1;
    for (var i = braceStart; i < src.length; i++) {
      if (src[i] == '{') depth++;
      if (src[i] == '}') {
        depth--;
        if (depth == 0) {
          braceEnd = i;
          break;
        }
      }
    }
    expect(braceEnd, greaterThan(0));
    final classBody = src.substring(braceStart, braceEnd + 1);

    final fields =
        RegExp(r'^\s{2}final\s+[\w<>?, ]+\s+(\w+);', multiLine: true)
            .allMatches(classBody)
            .map((m) => m.group(1)!)
            .toList();

    expect(fields, isNotEmpty,
        reason: 'the field-declaration regex found nothing — every '
            'assertion below would pass vacuously');
    expect(fields,
        containsAll(['streams', 'nations', 'powers', 'events', 'meta']));

    final loadSig = 'Future<WheelHistoryData> load() async {';
    final loadStart = src.indexOf(loadSig);
    expect(loadStart, greaterThanOrEqualTo(0), reason: 'no $loadSig in source');
    final loadBraceStart = loadStart + loadSig.length - 1;
    var ldepth = 0;
    var loadBraceEnd = -1;
    for (var i = loadBraceStart; i < src.length; i++) {
      if (src[i] == '{') ldepth++;
      if (src[i] == '}') {
        ldepth--;
        if (ldepth == 0) {
          loadBraceEnd = i;
          break;
        }
      }
    }
    expect(loadBraceEnd, greaterThan(0));
    final loadBody = src.substring(loadBraceStart, loadBraceEnd + 1);
    final literalStart = loadBody.indexOf('WheelHistoryData(');
    expect(literalStart, greaterThanOrEqualTo(0),
        reason: 'load() no longer builds a WheelHistoryData literal');
    var pdepth = 0;
    var literalEnd = -1;
    for (var i = literalStart + 'WheelHistoryData'.length;
        i < loadBody.length;
        i++) {
      if (loadBody[i] == '(') pdepth++;
      if (loadBody[i] == ')') {
        pdepth--;
        if (pdepth == 0) {
          literalEnd = i;
          break;
        }
      }
    }
    expect(literalEnd, greaterThan(0));
    final literal = loadBody.substring(literalStart, literalEnd + 1);

    for (final f in fields) {
      expect(literal, contains('$f:'),
          reason: 'load()\'s merge literal does not name `$f` — a field '
              'dropped at this call site is invisible to every other '
              'test in the repo');
    }
  });

  test('the About sheet\'s five headings exist in all three scripts', () {
    for (final key in [
      'wheelAbout',
      'wheelAboutProvenance',
      'wheelAboutCoverage',
      'wheelAboutScope',
      'wheelAboutAxis',
    ]) {
      final byLocale = wheelStrings[key];
      expect(byLocale, isNotNull, reason: '$key missing from wheelStrings');
      for (final l in _locales) {
        expect(byLocale![l], isNotEmpty,
            reason: '$key has no $l string in wheelStrings');
      }
    }
  });
}
