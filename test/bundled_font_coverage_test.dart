/// Guards the bundled font subsets against the failure that is
/// invisible to every other test in this suite.
///
/// Flutter web's CanvasKit draws only glyphs that are in its Skia font
/// registry. When a code point is covered by no registered font the
/// ENGINE fetches a Noto face from `fontFallbackBaseUrl`
/// (fonts.gstatic.com), which is unreachable from mainland China — and
/// a font it could not fetch renders as ABSENT TEXT, not as tofu. So
/// the Hebrew of Genesis 1:1 simply is not there, and no widget test
/// notices, because no widget test loads a font either.
///
/// This test therefore reads the actual cmap tables out of
/// assets/fonts/ and asserts that every character the app's own data
/// contains, in the scripts we claim to bundle, has a glyph. It is the
/// regression guard for the specific way this broke before: the old
/// generator (tools/build_cjk_font_subset.sh) scanned the fork PARENT
/// repo, so 384 characters that appear only in SeekSparks assets were
/// silently missing from the bundle for months.
///
/// Regenerate the subsets with `python3 tools/build_font_subsets.py`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/font_catalog.dart';

/// Code points with a non-zero glyph id in [bytes], an sfnt font.
Set<int> cmapOf(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  final numTables = d.getUint16(4);
  int? cmapOffset;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    if (tag == 'cmap') cmapOffset = d.getUint32(rec + 8);
  }
  if (cmapOffset == null) return {};

  final out = <int>{};
  final subCount = d.getUint16(cmapOffset + 2);
  final seen = <int>{};
  for (var i = 0; i < subCount; i++) {
    final rec = cmapOffset + 4 + i * 8;
    final sub = cmapOffset + d.getUint32(rec + 4);
    if (!seen.add(sub)) continue;
    switch (d.getUint16(sub)) {
      case 4:
        final segX2 = d.getUint16(sub + 6);
        final endAt = sub + 14;
        final startAt = endAt + segX2 + 2;
        final deltaAt = startAt + segX2;
        final rangeAt = deltaAt + segX2;
        for (var s = 0; s < segX2 ~/ 2; s++) {
          final end = d.getUint16(endAt + s * 2);
          final start = d.getUint16(startAt + s * 2);
          if (start > end) continue;
          final delta = d.getInt16(deltaAt + s * 2);
          final rangeOffset = d.getUint16(rangeAt + s * 2);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            int gid;
            if (rangeOffset == 0) {
              gid = (c + delta) & 0xFFFF;
            } else {
              final at = rangeAt + s * 2 + rangeOffset + (c - start) * 2;
              if (at + 1 >= bytes.length) continue;
              gid = d.getUint16(at);
              if (gid != 0) gid = (gid + delta) & 0xFFFF;
            }
            if (gid != 0) out.add(c);
          }
        }
      case 12:
        final groups = d.getUint32(sub + 12);
        for (var g = 0; g < groups; g++) {
          final at = sub + 16 + g * 12;
          final start = d.getUint32(at);
          final end = d.getUint32(at + 4);
          final startGid = d.getUint32(at + 8);
          if (startGid == 0 && start == 0) continue;
          for (var c = start; c <= end; c++) {
            out.add(c);
          }
        }
      case 6:
        final first = d.getUint16(sub + 6);
        final count = d.getUint16(sub + 8);
        for (var k = 0; k < count; k++) {
          if (d.getUint16(sub + 10 + k * 2) != 0) out.add(first + k);
        }
    }
  }
  return out;
}

/// The scripts these subsets claim. Anything outside is deliberately
/// left to the platform — chiefly colour emoji, which iOS and macOS
/// draw better than a bundled monochrome symbol face would, and the
/// three Syriac letters in the stats page's Aramaic script badge.
const _claimed = <List<int>>[
  [0x0020, 0x007E], // ASCII
  [0x00A0, 0x024F], // Latin-1 + Extended-A/B
  [0x0250, 0x02FF], // IPA + spacing modifiers (ʾ ʿ)
  [0x0300, 0x036F], // combining marks
  [0x0370, 0x03FF], // Greek
  [0x0590, 0x05FF], // Hebrew
  [0x1D00, 0x1D7F], // phonetic extensions
  [0x1E00, 0x1EFF], // Latin Extended Additional (ḥ ṣ ṭ)
  [0x1F00, 0x1FFF], // Greek Extended — polytonic
  [0x2000, 0x206F], // general punctuation
  [0x2E80, 0x9FFF], // CJK radicals through Unified
  [0xAC00, 0xD7AF], // Hangul
  [0xF900, 0xFAFF], // CJK compatibility ideographs
  [0xFB1D, 0xFB4F], // Hebrew presentation forms
  [0xFF00, 0xFFEF], // halfwidth + fullwidth
  [0x20000, 0x2FA1F], // CJK Extension B and beyond
];

bool _isClaimed(int c) {
  for (final r in _claimed) {
    if (c >= r[0] && c <= r[1]) return true;
  }
  return false;
}

void main() {
  final fontsDir = Directory('assets/fonts');
  late Set<int> covered;

  setUpAll(() {
    covered = <int>{};
    for (final f in fontsDir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.ttf') && !f.path.endsWith('.otf')) continue;
      covered.addAll(cmapOf(f.readAsBytesSync()));
    }
  });

  test('the four subsets and their licence are on disk', () {
    for (final name in const [
      'Roboto-VariableFont_wdth,wght.ttf',
      'NotoSansSC-Sub.otf',
      'NotoSansHebrew-Sub.ttf',
      'NotoSansExt-Sub.ttf',
      'NotoSansSymbols2-Sub.ttf',
      'OFL.txt',
    ]) {
      expect(File('assets/fonts/$name').existsSync(), isTrue,
          reason: '$name is missing; run tools/build_font_subsets.py');
    }
  });

  test('every family is declared in pubspec.yaml', () {
    // A font asset that is not declared under `fonts:` is never
    // registered with CanvasKit, so it may as well not be shipped.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final family in const [
      'NotoSansSC-Sub',
      'NotoSansHebrew-Sub',
      'NotoSansExt-Sub',
      'NotoSansSymbols2-Sub',
    ]) {
      expect(pubspec, contains('family: $family'));
    }
  });

  test('every family is reachable from both fallback chains', () {
    // Registration alone is not enough: the engine only consults a
    // face that some style's fontFamilyFallback names.
    final main = File('lib/main.dart').readAsStringSync();
    for (final family in const [
      'NotoSansSC-Sub',
      'NotoSansHebrew-Sub',
      'NotoSansExt-Sub',
      'NotoSansSymbols2-Sub',
    ]) {
      expect(kCjkFontFallback, contains(family));
      // Light theme and dark theme each carry their own list.
      expect("'$family',".allMatches(main).length, greaterThanOrEqualTo(2),
          reason: '$family missing from a theme in main.dart');
    }
  });

  test('the parser reads real cmaps, so the assertions below can fail', () {
    // Without this, a parser bug that returned "everything" would make
    // every coverage test in this file pass vacuously. Roboto is the
    // control: 922 code points, Latin/Cyrillic/monotonic-Greek only.
    final roboto =
        cmapOf(File('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')
            .readAsBytesSync());
    expect(roboto.length, 922);
    expect(roboto, contains(0x0041)); // A
    expect(roboto, isNot(contains(0x05D0))); // א
    expect(roboto, isNot(contains(0x1F00))); // ἀ
  });

  test('the Hebrew alphabet, niqqud and cantillation all have glyphs', () {
    // By range, not by what the assets contain: a reader can TYPE
    // Hebrew into the command line, and a scan-derived subset would
    // blank on the first form no asset happens to hold.
    final missing = <int>[];
    for (var c = 0x05B0; c <= 0x05F4; c++) {
      if (!covered.contains(c)) missing.add(c);
    }
    // U+05C8-05CF and U+05EB-05EE are unassigned in Unicode.
    missing.removeWhere((c) =>
        (c >= 0x05C8 && c <= 0x05CF) || (c >= 0x05EB && c <= 0x05EE));
    expect(missing, isEmpty,
        reason: missing.map((c) => 'U+${c.toRadixString(16)}').join(' '));
  });

  test('polytonic Greek has glyphs', () {
    // Greek Extended is where every breathing mark and accent in the
    // Westcott-Hort NT and the LXX lives. Roboto stops at monotonic.
    for (final s in const ['ἀ', 'ἁ', 'ᾳ', 'ῥ', 'ὥ', 'ῆ', 'ῷ', 'ἐ', 'ὑ']) {
      expect(covered, contains(s.runes.first), reason: s);
    }
  });

  test('the transliteration diacritics have glyphs', () {
    for (final s in const ['ḥ', 'ṣ', 'ṭ', 'ḵ', 'ḇ', 'ʾ', 'ʿ', 'ā', 'ě']) {
      expect(covered, contains(s.runes.first), reason: s);
    }
  });

  test('every character in the app data is covered, in the scripts we claim',
      () {
    // This is the assertion that would have caught the fork-parent bug.
    // Scans the original-language texts and the lexicons — where a gap
    // costs a reader an actual word — rather than all 475 MB.
    final seen = <int>{};
    for (final dir in const ['assets/originals', 'assets/strongs']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        seen.addAll(utf8.decode(f.readAsBytesSync()).runes);
      }
    }
    for (final f in const [
      'assets/lxxwh.json',
      'assets/cuvs-plus.json',
      'assets/cuvs-yhwh.json',
      'assets/bible_names.json',
      'assets/family_tree.json',
    ]) {
      seen.addAll(utf8.decode(File(f).readAsBytesSync()).runes);
    }

    // The scan finding nothing would also pass; say so out loud.
    expect(seen.length, greaterThan(5000),
        reason: 'the scan read almost nothing — did the asset paths move?');

    final missing = seen.where((c) => _isClaimed(c) && !covered.contains(c));
    expect(missing, isEmpty,
        reason: 'run tools/build_font_subsets.py — missing '
            '${missing.map((c) => 'U+${c.toRadixString(16).toUpperCase()}').take(20).join(' ')}');
  });
}
