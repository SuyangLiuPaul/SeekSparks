/// The one word in front of a date nobody can settle, and the shape of
/// the mistake that put the wrong script in three files.
///
/// 后 is a queen. 後 is "after". Simplified merged them and Traditional
/// did not, so `locale.startsWith('zh')` — true for BOTH Chinese
/// locales — can never choose between them, and this repo made that
/// exact call three times:
///
///   * `radial_chronology_page.dart`, on the wheel's 161 approximate
///     events and its 382 AD year labels — 168 approximate as the
///     asset stands today, 161 when this was written;
///   * `timeline_event.dart`, on 71 of the Bible timeline's 105 events,
///     all 105 of which carry Traditional titles — so the hedge was the
///     one Simplified word in a Traditional sentence;
///   * `biblical_person.dart`, on the family tree, which printed
///     创世后 ("the queen of creation") where 創世後 was meant, two
///     lines above a branch that gets 岁 / 歲 right.
///
/// THE SWEEP IS THE POINT, not the three words. A fourth site written
/// next year will look exactly like the first three and no test naming
/// a file can see it.
///
/// AND THE SWEEP HAD TO BE BUILT THREE TIMES, once for each way a
/// source matcher can be wrong:
///
///   1. It matched a line holding both `startsWith('zh')` and a
///      divergent character — which is not what any of the three
///      defects looked like. All three stored the test in a
///      `final isZh` and used it lines later, so the matcher ran clean
///      over every one of them. A detector that cannot see the defect
///      it was written for is a green light.
///   2. Following the flag, it then read the whole line as one string,
///      so the flag `zh` matched inside the literal `'zh-Hant'` and it
///      accused `yearLabel` — the one line in the repo that gets this
///      distinction right. It now reads the flag in code and the
///      character in string literals, which is where each can mean
///      anything.
///
/// `finds the shape it was written for` feeds it the real pre-fix
/// source, so a fourth rewrite cannot quietly repeat (1).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/date_hedge.dart';

/// Characters that differ between the scripts AND appear in a date this
/// app prints. Deliberately short: a general Simplified detector over a
/// repo whose data is mostly Simplified fires on every line and gets
/// turned off within the week.
const _divergent = {
  '约': '約',
  '后': '後',
  '岁': '歲',
  '纪': '紀',
  '历': '曆',
};

/// Comments are not shipped, and this repo's comments are full of 约 —
/// 约翰 is John and 新约 is the New Testament. A sweep that reads them
/// reports six files that print nothing at all, and then gets ignored.
bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

/// A line split into the parts outside string literals and the parts
/// inside them.
///
/// Both halves are needed and neither alone will do. The flag is an
/// identifier, so it only counts in code — reading the raw line instead
/// makes the flag `zh` match inside the literal `'zh-Hant'`, which is
/// the one line in the repo that gets the distinction RIGHT. The
/// divergent character is only ever printed, so it only counts in a
/// string; a `后` in an identifier would be a variable name.
({String code, String text}) _split(String line) {
  final code = StringBuffer();
  final text = StringBuffer();
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
        continue;
      }
      if (c == quote) {
        quote = null;
        continue;
      }
      text.write(c);
    } else if (c == "'" || c == '"') {
      quote = c;
    } else {
      code.write(c);
    }
  }
  return (code: code.toString(), text: text.toString());
}

/// Every place [source] lets a `startsWith('zh')` decide a character the
/// two scripts spell differently.
///
/// Follows the flag rather than the line: `final isZh = ...` on one line
/// and `isZh ? '约 …' : 'c. …'` forty lines later is the shape all three
/// real defects had.
List<String> guessedScriptSites(String path, String source) {
  final lines = source.split('\n');
  final flags = <String>{};
  final flagDecl = RegExp(r'(?:final|var|bool)\s+(\w+)\s*=\s*'
      r'locale\.startsWith\(.zh.\)');
  for (final line in lines) {
    if (_isComment(line)) continue;
    final m = flagDecl.firstMatch(line);
    if (m != null) flags.add(m.group(1)!);
  }

  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_isComment(line)) continue;
    final parts = _split(line);
    final decidesOnZh = line.contains("startsWith('zh')") ||
        flags.any((f) => RegExp('\\b$f\\b').hasMatch(parts.code));
    if (!decidesOnZh) continue;
    for (final entry in _divergent.entries) {
      if (parts.text.contains(entry.key)) {
        out.add('$path:${i + 1} lets a startsWith(\'zh\') choose '
            '"${entry.key}" (Traditional "${entry.value}")');
      }
    }
  }
  return out;
}

void main() {
  test('the hedge is in the reader\'s own script, with its own spacing', () {
    expect(approximatePrefix('en'), 'c. ');
    expect(approximatePrefix('zh-Hans'), '约 ');
    expect(approximatePrefix('zh-Hant'), '約 ');
    // A locale nobody configures still has to produce something a
    // reader can read, rather than an empty string that silently drops
    // the caveat and states an unsettled date as fact.
    expect(approximatePrefix('fr'), 'c. ');
    expect(approximatePrefix(''), 'c. ');
  });

  test('Anno Mundi says "after creation", not "queen of creation"', () {
    expect(annoMundiLabel(1656, 'en'), 'AM 1656');
    expect(annoMundiLabel(1656, 'zh-Hans'), '创世后 1656 年');
    expect(annoMundiLabel(1656, 'zh-Hant'), '創世後 1656 年');
  });

  /// The detector, checked against the code it was written to catch.
  /// Verbatim from `timeline_event.dart` and `biblical_person.dart` as
  /// they stood at 1e0d802 — a fixture rather than a paraphrase,
  /// because a paraphrase of the bug is not the bug.
  test('the sweep finds the shape it was written for', () {
    const beforeTimeline = '''
  String displayYear(String locale) {
    final isZh = locale.startsWith('zh');
    final plain = _plainYear(year, isZh);
    if (!approximate) return plain;
    return isZh ? '约 \$plain' : 'c. \$plain';
  }
''';
    const beforePerson = '''
  String displayYears(String locale) {
    final am = yearSystem == 'am';
    final isZh = locale.startsWith('zh');
    String fmt(int? y) {
      if (am) {
        if (isZh) return '创世后 \$y 年';
        return 'AM \$y';
      }
      return '';
    }
    if (datingKind == 'approximate') {
      range = isZh ? '约 \$range' : 'c. \$range';
    }
    return range;
  }
''';
    expect(guessedScriptSites('before_timeline', beforeTimeline), hasLength(1));
    expect(guessedScriptSites('before_person', beforePerson), hasLength(2));

    // And it does not fire on a branch that only chooses between
    // Chinese and English, which is the whole legitimate use.
    const fine = '''
    final isZh = locale.startsWith('zh');
    return isZh ? '公元前 \$y 年' : '\$y BC';
''';
    expect(guessedScriptSites('fine', fine), isEmpty);
  });

  test('no source file lets startsWith choose a Chinese date form', () {
    // The sweep walks the source rather than the running app because
    // the defect is invisible at runtime unless you are reading Chinese
    // in the Traditional locale with an approximate record on screen —
    // which is how it survived three files and a release.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      // The one file allowed to hold both forms is the one whose job is
      // to tell them apart.
      if (f.path.endsWith('utils/date_hedge.dart')) continue;
      offenders.addAll(guessedScriptSites(f.path, f.readAsStringSync()));
    }
    expect(offenders, isEmpty,
        reason: 'a Traditional reader is being shown a Simplified date:\n'
            '${offenders.join('\n')}');
  });

  /// The same question from the other end, because `startsWith('zh')` is
  /// not the only way to write the bug — a `locale == 'zh-Hans'` arm
  /// with no `zh-Hant` one does it too, and that shape has no keyword to
  /// grep for.
  ///
  /// Only the ERA words, and 约 is deliberately not among them. In this
  /// repo 约 is overwhelmingly 约翰 (John) and 新约 (the New Testament),
  /// where the Traditional counterpart is a different word rather than a
  /// different rendering of this one, so pairing it here would report
  /// the book-name tables forever. The hedge is covered exactly, one
  /// test up, at the line it is chosen on.
  test('no file prints a Simplified era word without its counterpart', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final code =
          f.readAsLinesSync().where((l) => !_isComment(l)).join('\n');
      // Not every 后 in the app — 王后 is a queen, and is 王后 in both
      // scripts.
      for (final pair in const [
        ('创世后', '創世後'),
        ('主后', '主後'),
        ('公元后', '公元後'),
      ]) {
        if (code.contains(pair.$1) && !code.contains(pair.$2)) {
          offenders.add('${f.path} prints "${pair.$1}" and never '
              '"${pair.$2}"');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'one script is being printed to readers of both:\n'
            '${offenders.join('\n')}');
  });
}
