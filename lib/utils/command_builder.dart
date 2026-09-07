/// The Command Line Assistant — bwh16, `docs/PARITY-BACKLOG.md` §3.1.
///
/// The row separated the teaching from the building: *"#294 and #299
/// gave the operator strip, per-button tooltips, a context-sensitive
/// hint row and a tappable example card, which is the teaching. Done: a
/// builder that composes the line from parts — pick AND/OR/phrase, add
/// terms, set the verse context — and writes it into the command line so
/// the reader can see the syntax it produced."*
///
/// That last clause is the design. The builder does not RUN anything: it
/// writes a line into the box the reader already has, so the next time
/// they want that query they can type it. An assistant that ran the
/// search itself would teach nothing and would have to be reopened every
/// time; one that leaves its work on the command line is a lesson the
/// reader can edit.
///
/// ## Why composing is not string concatenation
///
/// Every shape has a rule the reader does not know, and getting one
/// wrong produces a line that parses as something else:
///
///   * the builder adds NO rule of its own. It was written with a
///     "a phrase needs two words" guard, on the assumption that
///     `CommandIssue.phraseNotMultiToken` refused a one-token phrase.
///     It does not — that issue is about a NEGATED multi-token term
///     (`'!爱神 世人`) — and `'love` parses fine. The guard was removed
///     rather than kept as a house style, because a builder that
///     refuses what the command line accepts teaches the reader a
///     grammar the app does not have. Caught by running every shape
///     back through the real parser, which is what the test does;
///   * `;N` is a VERSE context and BibleWorks forbids it on a lexical
///     phrase; ours accepts it, but it means something different there,
///     so it is only offered where it means what the reader will read
///     it to mean;
///   * a term with a space in it is two terms, silently. The builder
///     takes terms one at a time for exactly this reason.
///
/// So this file builds the line and `command_query.dart` remains the one
/// authority on what it means — the builder's output is checked by
/// running it back through the real parser, which is what
/// `test/command_builder_test.dart` does for every shape.
///
/// Flutter-free.
library;

/// The four shapes bwh16's control characters name.
enum BuiltQueryKind {
  /// `.` — every term, same verse.
  and,

  /// `/` — any term.
  or,

  /// `'` — the terms adjacent, in order.
  phrase,

  /// `;` — the same, scanned across verse boundaries.
  linearPhrase,
}

extension BuiltQueryKindControl on BuiltQueryKind {
  String get control => switch (this) {
        BuiltQueryKind.and => '.',
        BuiltQueryKind.or => '/',
        BuiltQueryKind.phrase => "'",
        BuiltQueryKind.linearPhrase => ';',
      };

  /// True for the two shapes whose terms are independent, which is where
  /// a `;N` verse context means "within N verses of each other".
  bool get takesVerseContext =>
      this == BuiltQueryKind.and || this == BuiltQueryKind.or;

}

/// What the reader has assembled so far.
class BuiltQuery {
  const BuiltQuery({
    this.kind = BuiltQueryKind.and,
    this.terms = const <String>[],
    this.verseContext,
  });

  final BuiltQueryKind kind;

  /// In order. Order matters for the phrase shapes and not for the
  /// others, which is itself worth showing the reader.
  final List<String> terms;

  /// `;N`. Null for none.
  final int? verseContext;

  BuiltQuery withKind(BuiltQueryKind next) => BuiltQuery(
        kind: next,
        terms: terms,
        // A verse context on a phrase would mean something else, so it
        // is dropped rather than carried into a shape it does not
        // belong to — silently keeping it would produce a line the
        // reader did not build.
        verseContext: next.takesVerseContext ? verseContext : null,
      );

  BuiltQuery withTerm(String term) {
    final t = term.trim();
    if (t.isEmpty) return this;
    // Split on whitespace: a term with a space in it is two terms in
    // this grammar, and accepting it whole would produce a line that
    // means something the reader did not type.
    final parts = t.split(RegExp(r'\s+'));
    return BuiltQuery(
        kind: kind, terms: [...terms, ...parts], verseContext: verseContext);
  }

  BuiltQuery removeTerm(int index) {
    if (index < 0 || index >= terms.length) return this;
    final next = [...terms]..removeAt(index);
    return BuiltQuery(kind: kind, terms: next, verseContext: verseContext);
  }

  BuiltQuery withVerseContext(int? n) => BuiltQuery(
        kind: kind,
        terms: terms,
        verseContext: kind.takesVerseContext ? n : null,
      );

  /// True when [line] is something the command line can run.
  ///
  /// One condition, and it is the parser's: a control character with no
  /// body is refused. Everything else the grammar accepts, the builder
  /// offers.
  bool get isRunnable => terms.isNotEmpty;

  /// Why it is not runnable yet, for the reader. Null when it is.
  String? get blockedReasonKey =>
      terms.isEmpty ? 'builderNeedsTerm' : null;

  /// The command line this assembles to.
  ///
  /// Empty string when nothing has been assembled — the caller writes it
  /// into the box, and writing a bare control character there would be a
  /// line the parser rejects.
  String get line {
    if (terms.isEmpty) return '';
    final body = terms.join(' ');
    final ctx = kind.takesVerseContext && verseContext != null
        ? ';$verseContext'
        : '';
    return '${kind.control}$body$ctx';
  }
}
