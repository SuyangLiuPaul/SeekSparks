import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `uiStrings['key']` / `s('key', …)` in `lib/` must resolve to a
/// key that is actually DEFINED, in all three languages.
///
/// 2026-08-24, owner-reported ("很多地方都没有 语言改变一起变化").
/// The failure mode this guards is silent by construction: every
/// lookup in this codebase is written
///
///     uiStrings['someKey']?[locale] ?? 'English fallback'
///
/// so a key that was never defined does not crash, does not warn, and
/// does not even look wrong at the call site — it just prints the
/// English literal in every language, for ever. Seven keys were in
/// that state when this test was written (`lemma`, `gloss`, `noData`,
/// `verseMode`, `paragraphMode`, `verseMergedWithNext`,
/// `concordanceNoResults`).
///
/// Definitions are collected from ALL of `lib/`, not just
/// `ui_strings.dart`, because some screens legitimately keep a local
/// map (`radial_chronology_page.dart` is one) — those are localized
/// too, and flagging them would train the reader to ignore this test.
void main() {
  /// Key → the languages it defines. Brace-matched rather than
  /// regex-bounded: translations contain `{n}`-style placeholders, and
  /// a `[^{}]*` body pattern silently truncates at the first one —
  /// which is exactly how an earlier version of this audit produced
  /// 138 false positives.
  Map<String, Set<String>> definitionsIn(String src) {
    final out = <String, Set<String>>{};
    final start = RegExp(r"'([A-Za-z0-9_]+)'\s*:\s*\{");
    for (final m in start.allMatches(src)) {
      var i = m.end - 1;
      var depth = 0;
      String? inString;
      while (i < src.length) {
        final c = src[i];
        if (inString != null) {
          if (c == r'\') {
            i += 2;
            continue;
          }
          if (c == inString) inString = null;
        } else if (c == "'" || c == '"') {
          inString = c;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) break;
        }
        i++;
      }
      final body = src.substring(m.end, i.clamp(0, src.length));
      if (!body.contains("'en'") && !body.contains("'zh-Hans'")) continue;
      final langs = RegExp(r"'(zh-Hans|zh-Hant|en)'\s*:")
          .allMatches(body)
          .map((l) => l.group(1)!)
          .toSet();
      (out[m.group(1)!] ??= <String>{}).addAll(langs);
    }
    return out;
  }

  late Map<String, Set<String>> defined;
  late Map<String, String> usedAt; // key -> "file:line" of first use

  setUpAll(() {
    defined = <String, Set<String>>{};
    usedAt = <String, String>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final use = RegExp(
        r"\b_?s\(\s*'([A-Za-z0-9_]+)'|uiStrings\[\s*'([A-Za-z0-9_]+)'\s*\]");

    for (final f in files) {
      final src = f.readAsStringSync();
      definitionsIn(src).forEach((k, v) => (defined[k] ??= <String>{}).addAll(v));
      if (f.path.endsWith('ui_strings.dart')) continue;
      for (final m in use.allMatches(src)) {
        final k = m.group(1) ?? m.group(2)!;
        usedAt.putIfAbsent(
            k, () => '${f.path}:${'\n'.allMatches(src.substring(0, m.start)).length + 1}');
      }
    }
  });

  test('no lookup references a key that is defined nowhere', () {
    final missing = usedAt.keys.where((k) => !defined.containsKey(k)).toList()
      ..sort();
    expect(missing, isEmpty,
        reason: 'these keys fall through to their English literal in every '
            'language:\n${missing.map((k) => '  $k  (${usedAt[k]})').join('\n')}');
  });

  test('every key the UI uses carries both Chinese scripts', () {
    final partial = <String>[];
    for (final k in usedAt.keys) {
      final langs = defined[k];
      if (langs == null) continue; // covered by the test above
      for (final want in const ['zh-Hans', 'zh-Hant', 'en']) {
        if (!langs.contains(want)) {
          partial.add('  $k is missing $want  (${usedAt[k]})');
        }
      }
    }
    expect(partial, isEmpty, reason: partial.join('\n'));
  });
}
