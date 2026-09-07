/// The Command Line Assistant — bwh16, `docs/PARITY-BACKLOG.md` §3.1.
///
/// The assertions that matter run the builder's output back through the
/// REAL parser. A builder that emitted a line the command line refuses
/// would be worse than no builder: the reader would be shown a syntax
/// error for a query they did not type, produced by the thing that was
/// supposed to teach them the syntax.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/command_builder.dart';
import 'package:seeksparks/utils/command_query.dart';

/// Every shape the builder can produce must parse.
void expectParses(BuiltQuery q) {
  final parse = parseCommandQuery(q.line);
  expect(parse.query, isNotNull,
      reason: '"${q.line}" was refused: ${parse.issue}');
}

void main() {
  const empty = BuiltQuery();

  group('everything it builds, the parser accepts', () {
    test('AND', () {
      final q = empty.withTerm('love').withTerm('god');
      expect(q.line, '.love god');
      expectParses(q);
    });

    test('OR', () {
      final q = empty
          .withKind(BuiltQueryKind.or)
          .withTerm('charity')
          .withTerm('love');
      expect(q.line, '/charity love');
      expectParses(q);
    });

    test('phrase', () {
      final q = empty
          .withKind(BuiltQueryKind.phrase)
          .withTerm('in')
          .withTerm('the')
          .withTerm('beginning');
      expect(q.line, "'in the beginning");
      expectParses(q);
    });

    test('linear phrase', () {
      final q = empty
          .withKind(BuiltQueryKind.linearPhrase)
          .withTerm('and')
          .withTerm('god');
      expect(q.line, ';and god');
      expectParses(q);
    });

    test('AND with a verse context', () {
      final q = empty
          .withTerm('paul')
          .withTerm('silas')
          .withVerseContext(10);
      expect(q.line, '.paul silas;10');
      expectParses(q);
    });
  });

  group('the rules the reader does not know', () {
    test('the builder invents no rule the grammar does not have', () {
      // Written first with a "a phrase needs two words" guard, on the
      // assumption that `CommandIssue.phraseNotMultiToken` refused a
      // one-token phrase. It does not — that issue is about a NEGATED
      // multi-token term — and `'love` parses. The guard came out: a
      // builder that refuses what the command line accepts teaches a
      // grammar the app does not have.
      final q = empty.withKind(BuiltQueryKind.phrase).withTerm('love');
      expect(q.isRunnable, isTrue);
      expect(q.blockedReasonKey, isNull);
      expectParses(q);
    });

    test('a verse context cannot ride on a phrase', () {
      // `;N` is a VERSE context. On a phrase it means something else, so
      // switching to a phrase DROPS it rather than carrying it into a
      // shape where the reader would misread it.
      final q = empty
          .withTerm('paul')
          .withTerm('silas')
          .withVerseContext(10)
          .withKind(BuiltQueryKind.phrase);
      expect(q.verseContext, isNull);
      expect(q.line, "'paul silas");
    });

    test('and it cannot be set on one either', () {
      final q = empty
          .withKind(BuiltQueryKind.phrase)
          .withTerm('a')
          .withTerm('b')
          .withVerseContext(5);
      expect(q.verseContext, isNull);
    });

    test('a term with a space is two terms, as the grammar says', () {
      // Accepting it whole would produce a line meaning something the
      // reader did not type — the space is the term separator.
      final q = empty.withTerm('love  god');
      expect(q.terms, ['love', 'god']);
      expect(q.line, '.love god');
      expectParses(q);
    });

    test('blank input adds nothing', () {
      expect(empty.withTerm('   ').terms, isEmpty);
      expect(empty.withTerm('').line, '');
    });
  });

  group('nothing assembled is an empty line, not a bare operator', () {
    test('because the parser refuses a control character alone', () {
      expect(empty.line, '');
      expect(empty.withKind(BuiltQueryKind.or).line, '');
      expect(empty.isRunnable, isFalse);
      expect(empty.blockedReasonKey, 'builderNeedsTerm');
      // The line the builder is careful NOT to emit.
      expect(parseCommandQuery('.').query, isNull);
    });
  });

  group('editing', () {
    test('a term can be taken back out', () {
      final q = empty.withTerm('a').withTerm('b').removeTerm(0);
      expect(q.terms, ['b']);
    });

    test('an out-of-range removal changes nothing', () {
      final q = empty.withTerm('a');
      expect(q.removeTerm(9).terms, ['a']);
      expect(q.removeTerm(-1).terms, ['a']);
    });

    test('switching shape keeps the terms', () {
      // The reader has done the typing; changing their mind about AND
      // versus OR must not cost them it.
      final q = empty.withTerm('a').withTerm('b').withKind(BuiltQueryKind.or);
      expect(q.terms, ['a', 'b']);
    });
  });

  test('every reason the builder can give has a string', () {
    for (final k in const ['builderNeedsTerm']) {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final v = uiStrings[k]?[locale];
        expect(v, isNotNull, reason: '$k [$locale]');
        expect((v as String).trim(), isNotEmpty, reason: '$k [$locale]');
      }
    }
  });
}
