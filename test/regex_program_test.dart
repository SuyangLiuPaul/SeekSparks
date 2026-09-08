import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/regex_program.dart';

/// bwh43i's operator table, driven once each, plus the one property the
/// whole file exists for: this engine cannot be made to hang.
void main() {
  RegexProgram compile(String src) {
    final r = compileBibleworksRegex(src);
    expect(r.program, isNotNull, reason: '"$src" was refused: ${r.problem}');
    return r.program!;
  }

  RegexProblem? problem(String src) => compileBibleworksRegex(src).problem;

  bool hits(String pattern, String text) => compile(pattern).hasMatch(text);

  group('every operator bwh43i lists', () {
    test('a bare string matches the letters it spells, and only those', () {
      expect(hits('And God said', 'And God said, Let there be light'), isTrue);
      expect(hits('And God said', 'and god said, Let there be light'), isFalse);
    });

    test('a dot matches one character and stops at a line break', () {
      expect(hits('a.b', 'axb'), isTrue);
      expect(hits('a.b', 'ab'), isFalse);
      // bwh43i says "any character but newline", and verse text carries
      // them: Hebrew poetry is stored with the line breaks in it.
      expect(hits('a.b', 'a\nb'), isFalse);
    });

    test('the anchors mean the beginning and end of a line', () {
      expect(hits(r'^God', 'God saw'), isTrue);
      expect(hits(r'^God', 'And God saw'), isFalse);
      expect(hits(r'light$', 'let there be light'), isTrue);
      expect(hits(r'light$', 'light was good'), isFalse);
      // A verse with an internal break has two lines, and both of them
      // begin.
      expect(hits(r'^God', 'The heavens\nGod made'), isTrue);
    });

    test('a character class matches any one of its members', () {
      expect(hits('[Gg]od', 'God'), isTrue);
      expect(hits('[Gg]od', 'god'), isTrue);
      expect(hits('[Gg]od', 'Lod'), isFalse);
      expect(hits('[a-f]x', 'cx'), isTrue);
      expect(hits('[a-f]x', 'gx'), isFalse);
      expect(hits('[^aeiou]nd', 'and'), isFalse);
      expect(hits('[^aeiou]nd', 'end'), isFalse);
      expect(hits('[^aeiou]nd', 'bnd'), isTrue);
    });

    test('a hyphen at either end of a class is a literal hyphen', () {
      expect(hits('[a-]x', '-x'), isTrue);
      expect(hits('[a-]x', 'ax'), isTrue);
      expect(hits('[a-]x', 'bx'), isFalse);
    });

    test('the three quantifiers count what bwh43i says they count', () {
      expect(hits('ab*c', 'ac'), isTrue);
      expect(hits('ab*c', 'abbbc'), isTrue);
      expect(hits('ab+c', 'ac'), isFalse);
      expect(hits('ab+c', 'abc'), isTrue);
      expect(hits('ab?c', 'ac'), isTrue);
      expect(hits('ab?c', 'abc'), isTrue);
      expect(hits('ab?c', 'abbc'), isFalse);
    });

    test('alternation and grouping', () {
      expect(hits('cat|dog', 'a dog'), isTrue);
      expect(hits('cat|dog', 'a cow'), isFalse);
      expect(hits('(cat|dog)s', 'dogs'), isTrue);
      expect(hits('(cat|dog)s', 'dog'), isFalse);
    });

    test('a backslash makes a metacharacter ordinary', () {
      expect(hits(r'a\*b', 'a*b'), isTrue);
      expect(hits(r'a\*b', 'aab'), isFalse);
      expect(hits(r'\[x\]', '[x]'), isTrue);
    });

    test('a quoted string is every character inside it, literally', () {
      expect(hits('"**"', 'a ** b'), isTrue);
      expect(hits('"**"', 'ab'), isFalse);
      expect(hits('"a.b"', 'a.b'), isTrue);
      expect(hits('"a.b"', 'axb'), isFalse);
    });
  });

  group('Han text, which BibleWorks says it cannot search', () {
    // BibleWorks' own limit is that its engine indexes whitespace-
    // delimited words; ours matches the verse string, so the script has
    // no say in it. Every Han character in the shipped editions is one
    // UTF-16 code unit, so `.` counts characters the way a reader does.
    test('a dot counts one Han character', () {
      expect(hits('神.说', '神就说'), isTrue);
      expect(hits('神.说', '神说'), isFalse);
      expect(hits('神.*说', '神的灵运行在水面上就说'), isTrue);
    });

    test('a class and an alternation both work over Han', () {
      expect(hits('[神主]的', '主的道'), isTrue);
      expect(hits('[神主]的', '人的道'), isFalse);
      expect(hits('爱|恨', '恨恶'), isTrue);
    });
  });

  group('what is refused, and by which name', () {
    test('a dialect this table has no entry for is named unsupported', () {
      // bwh43i's `\c` means "the character c", so `\d` would be the
      // letter d here and a digit anywhere else. Both readings are
      // defensible, which is when guessing is the wrong move.
      expect(problem(r'\d+'), RegexProblem.unsupported);
      expect(problem(r'\w'), RegexProblem.unsupported);
      expect(problem('go{2,3}d'), RegexProblem.unsupported);
      expect(problem('(?:ab)'), RegexProblem.unsupported);
      expect(problem('(?=ab)'), RegexProblem.unsupported);
    });

    test('a mistyped pattern is named as a mistyped pattern', () {
      expect(problem('(ab'), RegexProblem.syntax);
      expect(problem('ab)'), RegexProblem.syntax);
      expect(problem('[abc'), RegexProblem.syntax);
      expect(problem('*ab'), RegexProblem.syntax);
      expect(problem(r'ab\'), RegexProblem.syntax);
      expect(problem('"ab'), RegexProblem.syntax);
      expect(problem('[z-a]'), RegexProblem.syntax);
    });

    test('an empty branch is refused rather than read as every verse', () {
      // `a|` and `()` match the empty string, so they match every verse
      // at every position. Returning the whole Bible is a worse answer
      // than saying the pattern is malformed.
      expect(problem(''), RegexProblem.syntax);
      expect(problem('a|'), RegexProblem.syntax);
      expect(problem('()'), RegexProblem.syntax);
    });

    test('a pattern too big for the program ceiling is named, not cut', () {
      expect(problem('a' * (kMaxRegexProgram + 1)), RegexProblem.tooComplex);
      expect(problem('a' * (kMaxRegexProgram - 10)), isNull);
    });
  });

  group('the required literal, which drives the prefilter and the marks', () {
    test('it is the longest fixed run of the top-level concatenation', () {
      expect(compile('And God said').requiredLiteral, 'And God said');
      expect(compile('a.beginning').requiredLiteral, 'beginning');
      expect(compile(r'^In the beginning$').requiredLiteral,
          'In the beginning');
    });

    test('an assertion ends a run, so the literal is never a fiction', () {
      // A mid-pattern `^` is unsatisfiable here — `Go^d` wants the
      // character before `d` to be both `o` and a line break — so a run
      // that crossed it would name "God" as required by a pattern that
      // matches nothing at all. Breaking the run makes "every match
      // contains the required literal" true of the tree rather than true
      // of an argument about satisfiability.
      expect(compile(r'Go^d').requiredLiteral, 'Go');
      expect(hits(r'Go^d', 'God'), isFalse);
      expect(hits(r'Go^d', 'Go\nd'), isFalse);
      // A leading or trailing assertion still leaves the whole run,
      // which is the only placement anyone writes.
      expect(compile(r'^In the beginning$').requiredLiteral,
          'In the beginning');
    });

    test('a run never crosses a quantifier, a class or an alternation', () {
      // `~(cat|dog)s` requires no fixed string longer than "s": a filter
      // that guessed "cats" would silently lose every dog.
      expect(compile('(cat|dog)s').requiredLiteral, 's');
      expect(compile('grac*e').requiredLiteral, 'gra');
      expect(compile('[Gg]od').requiredLiteral, 'od');
    });

    test('a pattern with nothing fixed in it says so', () {
      expect(compile('[a-z]+').requiredLiteral, '');
      expect(compile('.*').requiredLiteral, '');
    });
  });

  group('the bound this engine exists for', () {
    test('the classic catastrophic backtracker returns at once', () {
      // `RegExp(r'(a+)+$').hasMatch('a' * 40 + '!')` does not return in
      // any time a reader will wait, cannot be cancelled, and on the web
      // build takes the browser tab with it. The same pattern here is
      // linear in the text, so this test finishes rather than hanging
      // the suite — which is the whole claim of `regex_program.dart`,
      // and the only way to state it is to run it.
      final p = compile(r'(a+)+$');
      final watch = Stopwatch()..start();
      expect(p.hasMatch('${'a' * 4000}!'), isFalse);
      watch.stop();
      expect(watch.elapsedMilliseconds, lessThan(2000),
          reason: 'a backtracking engine would not have reached this line');
    });

    test('the other two shapes that hang a backtracker also return', () {
      expect(compile(r'(a|a)+$').hasMatch('${'a' * 2000}!'), isFalse);
      expect(compile('a*a*a*a*a*a*b').hasMatch('a' * 2000), isFalse);
    });

    test('the step ceiling is the product it claims to be', () {
      final p = compile('God');
      // Three chars plus the accepting state; each state can be queued
      // on each of the two lists once per position.
      expect(p.size, 4);
      expect(p.stepCeilingFor(100), 4 * 101 * 2);
    });
  });
}
