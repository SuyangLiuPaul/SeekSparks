/// 2026-09-08 (SeekSparks): BibleWorks' `~` regular expressions, on an
/// engine that cannot hang.
///
/// bwh43i ("Regular Expression Syntax Summary") prints the whole operator
/// table BibleWorks supports, and it is short:
///
///     \  escape        "  quotation      .  any
///     ^  line begin (or character class negation)
///     $  line end      [  -  ]  character class
///     (  )  group      ?  option         *  closure
///     +  positive closure                |  alternation
///
/// That table is the entire specification, and the thing worth noticing
/// about it is what is NOT in it: no `{n,m}` interval, no backreference,
/// no lookaround, no shorthand class (`\d`, `\w`, `\b`). **A pattern
/// language with no backreference describes a regular language**, and a
/// regular language can be matched by simulating an NFA in time
/// proportional to the text — no backtracking, and therefore no
/// catastrophic backtracking, ever.
///
/// That is the whole reason this file exists instead of a call to
/// `RegExp`. Dart's `RegExp` is Irregexp on both targets and it
/// backtracks: `RegExp(r'(a+)+$').hasMatch('a' * 30 + '!')` does not
/// return in any time a reader will wait, it cannot be cancelled, it
/// ignores every timer, and on the web build it takes the browser tab
/// with it. Dart offers no step limit and no timeout on a `RegExp`, so
/// there is nothing to configure; the choice is between an engine that
/// can hang and one that cannot.
///
/// ## What was rejected, and why
///
/// * **A wall-clock check every N verses.** It bounds the SCAN and not
///   the CALL. One `hasMatch` against one 200-character verse is a
///   single uninterruptible call, and `(a+)+$` is exponential inside it,
///   so the clock is never read again. It answers the wrong question.
/// * **Refusing patterns whose shape is known-dangerous.** Nested
///   quantifiers are the famous case and are easy to spot, but they are
///   not the only one: `a*a*a*a*b` has no nesting and is O(n⁴) on a run
///   of a's. Every such rule is a guess about which shapes are safe, and
///   a guess that is wrong hangs the tab. A linear-time engine needs no
///   guess.
/// * **Running the scan in an isolate.** `Isolate.run` does not exist on
///   the web, which is where the failure is worst (a frozen tab has no
///   "stop" button), and this app ships to the web. It would also mean
///   copying a 4.6 MB corpus per search.
///
/// ## What this does NOT protect against
///
/// The bound here is *per character of text examined*, not absolute. A
/// pattern with no literal to prefilter on (`~^[A-Z]`) is examined
/// against every verse, and a large pattern makes each character cost
/// more. That product is bounded before the scan starts rather than
/// during it — see [RegexProgram.stepCeilingFor] and its caller in
/// `command_query.dart` — so an over-budget search is refused by name
/// instead of being started and abandoned half-way, which would return a
/// short list that looks like an answer.
///
/// It also does not make a bad pattern a good search. `~.*` matches
/// every verse and this engine will happily say so.
///
/// ## Deliberate divergences from the table
///
/// * `\` before a letter or a digit is REFUSED rather than read.
///   bwh43i's `\c` means "character c literally", so BibleWorks reads
///   `\d` as the letter `d`; every regular expression written in the
///   last thirty years means "a digit". The two answers are different
///   and both are defensible, which is exactly when guessing is the
///   wrong move. `\.` `\*` `\[` and friends are unambiguous and work.
/// * `{` is refused by name. It is not in the table, so BibleWorks reads
///   it as a literal brace; a reader typing `~go{2,3}d` means an
///   interval. Same argument.
/// * `(?` is refused by name — `(?:`, `(?=` and `(?!` are not in the
///   table, and BibleWorks would read the `?` as a quantifier with
///   nothing in front of it.
/// * A lazy `*?` IS accepted, and is read the way the table reads it:
///   `?` applied to `a*`. Nothing observable turns on it. This engine
///   answers one question — does the verse match anywhere — and greedy
///   and lazy quantifiers never disagree about that.
///
/// Pure Dart. No Flutter, no assets, no SeekSparks types: this file
/// knows about strings and nothing else.
library;

// ── Limits ──────────────────────────────────────────────────────────

/// Largest compiled program accepted, in instructions.
///
/// Each instruction is one NFA state, and the simulation's cost is
/// `states × characters`, so this is half of the cost bound. 400 is far
/// past any pattern a person types into a one-line box — `~And God
/// said` compiles to 13 — and it keeps the two simulation arrays, which
/// are allocated once per search and indexed by state, small enough to
/// stay in cache.
const int kMaxRegexProgram = 400;

// ── Why a pattern was refused ───────────────────────────────────────

/// What is wrong with a `~` pattern.
///
/// Three values and not one, because the three are actionable in
/// different ways: [syntax] means the reader mistyped, [unsupported]
/// means they typed a different dialect's regular expression, and
/// [tooComplex] means the pattern is fine and too big.
enum RegexProblem { syntax, unsupported, tooComplex }

/// A compiled pattern, or the reason there is not one.
typedef RegexCompile = ({RegexProgram? program, RegexProblem? problem});

// ── The compiled program ────────────────────────────────────────────

/// Opcodes. Deliberately flat: the simulation's inner loop switches on
/// this several million times per search.
enum _Op { char, any, klass, split, jump, match, bol, eol }

class _Inst {
  _Inst(this.op, {this.ch = 0, this.x = 0, this.klass});
  final _Op op;

  /// UTF-16 code unit for [_Op.char].
  final int ch;

  /// Jump targets: [_Op.jump] uses [x], [_Op.split] uses both. Filled
  /// in after the fragment they point past has been emitted, which is
  /// why they are not final.
  int x;
  int y = 0;

  final _CharClass? klass;
}

/// `[abc]`, `[a-z]`, `[^aeiou]` — inclusive code-unit ranges.
class _CharClass {
  _CharClass(this.lo, this.hi, this.negated);
  final List<int> lo;
  final List<int> hi;
  final bool negated;

  bool has(int c) {
    var inside = false;
    for (var i = 0; i < lo.length; i++) {
      if (c >= lo[i] && c <= hi[i]) {
        inside = true;
        break;
      }
    }
    return inside != negated;
  }
}

/// A pattern compiled to an NFA, ready to run.
class RegexProgram {
  RegexProgram._(this._insts, this.requiredLiteral, this.source);

  final List<_Inst> _insts;

  /// The pattern exactly as it was handed to [compileBibleworksRegex],
  /// for the echo to quote back.
  final String source;

  /// The longest run of characters every match must contain, or ''.
  ///
  /// Serves the same two jobs as `TokenMatcher.literalCore` in
  /// `command_query.dart`, and is deliberately the same idea so that the
  /// prefilter and the highlighter go on working the way they already
  /// do: it is a *necessary* condition for a match, so a whole-corpus
  /// scan can throw a verse away with one `String.contains` before the
  /// NFA touches it, and it is what the reader sees marked.
  ///
  /// Taken only from a run of plain literal characters in the
  /// TOP-LEVEL concatenation, never from inside an alternation or a
  /// quantifier — `~(cat|dog)s` requires no fixed string at all and
  /// this comes back empty for it rather than wrong. Under-selective
  /// costs time; wrong loses hits in silence.
  final String requiredLiteral;

  /// How many NFA state-steps a scan over [totalCharacters] can cost, at
  /// worst.
  ///
  /// Exact rather than estimated: the simulation adds each state to each
  /// of the two lists at most once per character position, so the work
  /// is bounded above by `states × (characters + positions)`. A caller
  /// that wants a budget compares this against one and refuses BEFORE
  /// the scan, which is the only placement under which the budget is a
  /// promise instead of a hope.
  int stepCeilingFor(int totalCharacters) =>
      _insts.length * (totalCharacters + 1) * 2;

  /// Instructions, i.e. NFA states. Public for the cost arithmetic and
  /// for the tests that pin the compiler's output size.
  int get size => _insts.length;

  // The simulation's scratch, allocated once per program rather than
  // once per verse: a search over 31k verses would otherwise allocate
  // 62k lists to hold at most 400 ints each.
  late final List<int> _seenC = List<int>.filled(_insts.length, -1);
  late final List<int> _seenN = List<int>.filled(_insts.length, -1);
  late final List<int> _clist = List<int>.filled(_insts.length, 0);
  late final List<int> _nlist = List<int>.filled(_insts.length, 0);
  int _cn = 0;
  int _nn = 0;

  /// Whether [text] contains a match anywhere.
  ///
  /// A Pike VM: every position of the text is a possible start, all
  /// live states advance together in lockstep, and a state already
  /// queued for a position is never queued again. That last clause is
  /// what makes the run linear and what makes an epsilon cycle — `(a*)*`
  /// — terminate instead of recursing for ever.
  ///
  /// Returns as soon as an accepting state is reached, so a verse that
  /// matches early costs less than its length.
  bool hasMatch(String text) {
    final n = text.length;
    _cn = 0;
    _nn = 0;
    for (var i = 0; i < _seenC.length; i++) {
      _seenC[i] = -1;
      _seenN[i] = -1;
    }
    for (var sp = 0; sp <= n; sp++) {
      // The unanchored search: a new attempt may begin at any position.
      // `^` is an assertion rather than an anchor on the program, so a
      // pattern that begins with one simply fails these threads instead
      // of the program needing a second, anchored entry point.
      if (_add(false, 0, sp, text, n)) return true;
      _nn = 0;
      final code = sp < n ? text.codeUnitAt(sp) : -1;
      for (var t = 0; t < _cn; t++) {
        final pc = _clist[t];
        final inst = _insts[pc];
        switch (inst.op) {
          case _Op.char:
            if (code == inst.ch && _add(true, pc + 1, sp + 1, text, n)) {
              return true;
            }
          case _Op.any:
            // bwh43i: "Any character but newline". Verse text can carry
            // one — Hebrew poetry is stored with line breaks — so this
            // is a real distinction and not a copied convention.
            if (code >= 0 &&
                code != 0x0A &&
                _add(true, pc + 1, sp + 1, text, n)) {
              return true;
            }
          case _Op.klass:
            if (code >= 0 &&
                inst.klass!.has(code) &&
                _add(true, pc + 1, sp + 1, text, n)) {
              return true;
            }
          // Epsilon instructions are consumed entirely by `_add`, so
          // they are never queued and never reach this loop.
          case _Op.split:
          case _Op.jump:
          case _Op.bol:
          case _Op.eol:
          case _Op.match:
            break;
        }
      }
      // Next position's list becomes this one's. Copied rather than
      // swapped because both arrays are fixed-length fields; the copy is
      // at most `size` ints and keeps the two `_seen` arrays paired with
      // the list they describe.
      for (var i = 0; i < _nn; i++) {
        _clist[i] = _nlist[i];
      }
      _cn = _nn;
      for (var i = 0; i < _seenN.length; i++) {
        _seenC[i] = _seenN[i];
        _seenN[i] = -1;
      }
      // A position with nothing live is not the end of the search: a
      // later start position may still match, and the loop costs one
      // `_add` to find out.
    }
    return false;
  }

  /// Queue [pc] and everything reachable from it without consuming a
  /// character, onto the next position's list when [toNext] and this
  /// one's otherwise. True when an accepting state is among them.
  bool _add(bool toNext, int pc, int sp, String text, int n) {
    final seen = toNext ? _seenN : _seenC;
    if (seen[pc] == sp) return false;
    seen[pc] = sp;
    final inst = _insts[pc];
    switch (inst.op) {
      case _Op.jump:
        return _add(toNext, inst.x, sp, text, n);
      case _Op.split:
        if (_add(toNext, inst.x, sp, text, n)) return true;
        return _add(toNext, inst.y, sp, text, n);
      case _Op.bol:
        if (sp == 0 || text.codeUnitAt(sp - 1) == 0x0A) {
          return _add(toNext, pc + 1, sp, text, n);
        }
        return false;
      case _Op.eol:
        if (sp == n || text.codeUnitAt(sp) == 0x0A) {
          return _add(toNext, pc + 1, sp, text, n);
        }
        return false;
      case _Op.match:
        return true;
      case _Op.char:
      case _Op.any:
      case _Op.klass:
        if (toNext) {
          _nlist[_nn++] = pc;
        } else {
          _clist[_cn++] = pc;
        }
        return false;
    }
  }
}

// ── The syntax tree ─────────────────────────────────────────────────

sealed class _Node {
  const _Node();
}

class _Lit extends _Node {
  const _Lit(this.ch);
  final int ch;
}

class _Any extends _Node {
  const _Any();
}

class _Assert extends _Node {
  const _Assert(this.bol);
  final bool bol;
}

class _Class extends _Node {
  const _Class(this.klass);
  final _CharClass klass;
}

class _Cat extends _Node {
  const _Cat(this.parts);
  final List<_Node> parts;
}

class _Alt extends _Node {
  const _Alt(this.left, this.right);
  final _Node left;
  final _Node right;
}

class _Rep extends _Node {
  const _Rep(this.child, this.min, this.max);
  final _Node child;

  /// 0 for `*` and `?`, 1 for `+`.
  final int min;

  /// 1 for `?`, -1 (unbounded) for `*` and `+`.
  final int max;
}

// ── Compiling ───────────────────────────────────────────────────────

/// Compile one BibleWorks-dialect pattern.
///
/// [source] is the pattern WITHOUT the leading `~`. An empty pattern is
/// a [RegexProblem.syntax]: it matches at every position of every verse,
/// which no reader typed a tilde to ask for.
RegexCompile compileBibleworksRegex(String source) {
  final parser = _Parser(source);
  final _Node root;
  try {
    root = parser.parseAlternation();
  } on _ParseFailure catch (e) {
    return (program: null, problem: e.problem);
  }
  if (parser.pos != source.length) {
    // The only way out of `parseAlternation` with input left is a `)`
    // with no `(` in front of it.
    return (program: null, problem: RegexProblem.syntax);
  }

  final insts = <_Inst>[];
  try {
    _emit(root, insts);
  } on _ParseFailure catch (e) {
    return (program: null, problem: e.problem);
  }
  insts.add(_Inst(_Op.match));
  if (insts.length > kMaxRegexProgram) {
    return (program: null, problem: RegexProblem.tooComplex);
  }
  return (
    program: RegexProgram._(insts, _requiredLiteral(root), source),
    problem: null
  );
}

class _ParseFailure implements Exception {
  _ParseFailure(this.problem);
  final RegexProblem problem;
}

class _Parser {
  _Parser(this.src);
  final String src;
  int pos = 0;

  bool get atEnd => pos >= src.length;
  int get peek => src.codeUnitAt(pos);

  _Node parseAlternation() {
    var left = parseConcat();
    while (!atEnd && peek == 0x7C /* | */) {
      pos++;
      final right = parseConcat();
      left = _Alt(left, right);
    }
    return left;
  }

  _Node parseConcat() {
    final parts = <_Node>[];
    while (!atEnd && peek != 0x7C && peek != 0x29 /* ) */) {
      parts.add(parseRepeat());
    }
    // `a|` and `()` — an empty branch matches the empty string, so the
    // whole pattern matches every verse at every position. Nobody types
    // a tilde to ask for that, and reading it as "all 31,102 verses"
    // would be an answer to a question that was not asked.
    if (parts.isEmpty) throw _ParseFailure(RegexProblem.syntax);
    return parts.length == 1 ? parts.first : _Cat(parts);
  }

  _Node parseRepeat() {
    var node = parseAtom();
    while (!atEnd) {
      final c = peek;
      if (c == 0x2A /* * */) {
        node = _Rep(node, 0, -1);
      } else if (c == 0x2B /* + */) {
        node = _Rep(node, 1, -1);
      } else if (c == 0x3F /* ? */) {
        node = _Rep(node, 0, 1);
      } else {
        break;
      }
      pos++;
    }
    return node;
  }

  _Node parseAtom() {
    if (atEnd) throw _ParseFailure(RegexProblem.syntax);
    final c = peek;
    switch (c) {
      case 0x28: // (
        pos++;
        // `(?:` `(?=` `(?!` — a different dialect's grammar. In
        // bwh43i's the `?` would be a quantifier with nothing in front
        // of it, so this is a syntax error either way; naming it says
        // WHICH mistake it is.
        if (!atEnd && peek == 0x3F) {
          throw _ParseFailure(RegexProblem.unsupported);
        }
        final inner = parseAlternation();
        if (atEnd || peek != 0x29) throw _ParseFailure(RegexProblem.syntax);
        pos++;
        return inner;
      case 0x29: // )
        throw _ParseFailure(RegexProblem.syntax);
      case 0x2A: // *
      case 0x2B: // +
      case 0x3F: // ?
        // A quantifier with nothing to repeat.
        throw _ParseFailure(RegexProblem.syntax);
      case 0x7B: // {
      case 0x7D: // }
        // Not in bwh43i's table. BibleWorks reads a brace as a literal
        // brace; a reader who typed one means `{2,3}`.
        throw _ParseFailure(RegexProblem.unsupported);
      case 0x2E: // .
        pos++;
        return const _Any();
      case 0x5E: // ^
        pos++;
        return const _Assert(true);
      case 0x24: // $
        pos++;
        return const _Assert(false);
      case 0x5B: // [
        return parseClass();
      case 0x5D: // ]
        throw _ParseFailure(RegexProblem.syntax);
      case 0x22: // "
        return parseQuoted();
      case 0x5C: // \
        pos++;
        if (atEnd) throw _ParseFailure(RegexProblem.syntax);
        final e = peek;
        if (_isAlnum(e)) throw _ParseFailure(RegexProblem.unsupported);
        pos++;
        return _Lit(e);
      default:
        pos++;
        return _Lit(c);
    }
  }

  /// `"s"` — every character between the quotes, literally.
  _Node parseQuoted() {
    pos++; // opening "
    final parts = <_Node>[];
    while (!atEnd && peek != 0x22) {
      parts.add(_Lit(peek));
      pos++;
    }
    if (atEnd) throw _ParseFailure(RegexProblem.syntax);
    pos++; // closing "
    if (parts.isEmpty) throw _ParseFailure(RegexProblem.syntax);
    return parts.length == 1 ? parts.first : _Cat(parts);
  }

  /// `[abc]`, `[a-z0-9]`, `[^aeiou]`.
  ///
  /// A `]` in first position is a literal `]`, which is the POSIX
  /// convention and the only way to put one in a class at all —
  /// bwh43i's table lists no alternative and `\]` also works here.
  _Node parseClass() {
    pos++; // [
    var negated = false;
    if (!atEnd && peek == 0x5E) {
      negated = true;
      pos++;
    }
    final lo = <int>[];
    final hi = <int>[];
    var first = true;
    while (true) {
      if (atEnd) throw _ParseFailure(RegexProblem.syntax);
      if (peek == 0x5D && !first) break;
      first = false;
      var c = peek;
      if (c == 0x5C) {
        pos++;
        if (atEnd) throw _ParseFailure(RegexProblem.syntax);
        c = peek;
        if (_isAlnum(c)) throw _ParseFailure(RegexProblem.unsupported);
      }
      pos++;
      // `a-z`. A trailing `-` before the `]` is a literal hyphen, which
      // is how every dialect reads it.
      if (!atEnd &&
          peek == 0x2D &&
          pos + 1 < src.length &&
          src.codeUnitAt(pos + 1) != 0x5D) {
        pos++;
        var end = peek;
        if (end == 0x5C) {
          pos++;
          if (atEnd) throw _ParseFailure(RegexProblem.syntax);
          end = peek;
          if (_isAlnum(end)) throw _ParseFailure(RegexProblem.unsupported);
        }
        pos++;
        if (end < c) throw _ParseFailure(RegexProblem.syntax);
        lo.add(c);
        hi.add(end);
        continue;
      }
      lo.add(c);
      hi.add(c);
    }
    pos++; // ]
    if (lo.isEmpty) throw _ParseFailure(RegexProblem.syntax);
    return _Class(_CharClass(lo, hi, negated));
  }

  static bool _isAlnum(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A);
}

/// Thompson's construction, emitting straight into [out].
///
/// Every fragment leaves the program with exactly one exit, at
/// `out.length`, which is what lets a concatenation be nothing more than
/// two `_emit` calls in a row and a `char` instruction fall through to
/// `pc + 1`.
void _emit(_Node node, List<_Inst> out) {
  if (out.length > kMaxRegexProgram) {
    throw _ParseFailure(RegexProblem.tooComplex);
  }
  switch (node) {
    case _Lit(:final ch):
      out.add(_Inst(_Op.char, ch: ch));
    case _Any():
      out.add(_Inst(_Op.any));
    case _Class(:final klass):
      out.add(_Inst(_Op.klass, klass: klass));
    case _Assert(:final bol):
      out.add(_Inst(bol ? _Op.bol : _Op.eol));
    case _Cat(:final parts):
      for (final p in parts) {
        _emit(p, out);
      }
    case _Alt(:final left, :final right):
      final split = out.length;
      out.add(_Inst(_Op.split));
      out[split].x = out.length;
      _emit(left, out);
      final jump = out.length;
      out.add(_Inst(_Op.jump));
      out[split].y = out.length;
      _emit(right, out);
      out[jump].x = out.length;
    case _Rep(:final child, :final min, :final max):
      if (min == 0 && max == 1) {
        // r?
        final split = out.length;
        out.add(_Inst(_Op.split));
        out[split].x = out.length;
        _emit(child, out);
        out[split].y = out.length;
      } else if (min == 0) {
        // r*
        final split = out.length;
        out.add(_Inst(_Op.split));
        out[split].x = out.length;
        _emit(child, out);
        out.add(_Inst(_Op.jump, x: split));
        out[split].y = out.length;
      } else {
        // r+
        final start = out.length;
        _emit(child, out);
        final split = out.length;
        out.add(_Inst(_Op.split, x: start));
        out[split].y = out.length;
      }
  }
}

// ── The literal every match must contain ────────────────────────────

/// The longest run of fixed characters that every match necessarily
/// contains.
///
/// Only the top-level concatenation is walked, and only [_Lit] nodes
/// extend a run. A quantifier, a class, `.`, an alternation or an
/// assertion ends one — even `a+`, which does contain a fixed `a`,
/// because a run that crossed it would have to reason about whether the
/// repetition can swallow the characters on either side, and this is a
/// filter where being wrong loses hits and being weak only costs time.
///
/// `^` and `$` end a run too, and that one is defensive rather than
/// necessary. A mid-pattern assertion is unsatisfiable in this dialect —
/// `~Go^d` wants the character before `d` to be both `o` and a line
/// break, and neither `.` nor any typeable escape consumes a newline —
/// so a run crossing one could only ever name a literal for a pattern
/// that matches nothing. Breaking anyway costs nothing (a leading or
/// trailing `^`/`$`, which is the only placement anyone writes, still
/// leaves the whole run) and buys the invariant by construction:
/// **the required literal is a substring of every match**, provable from
/// the tree rather than from an argument about which patterns are
/// satisfiable.
String _requiredLiteral(_Node root) {
  var best = StringBuffer();
  var bestLen = 0;
  final run = StringBuffer();
  void flush() {
    if (run.length > bestLen) {
      bestLen = run.length;
      best = StringBuffer(run.toString());
    }
    run.clear();
  }

  void walk(_Node n) {
    switch (n) {
      case _Lit(:final ch):
        run.writeCharCode(ch);
      case _Cat(:final parts):
        for (final p in parts) {
          walk(p);
        }
      case _Assert():
      case _Any():
      case _Class():
      case _Alt():
      case _Rep():
        flush();
    }
  }

  walk(root);
  flush();
  return best.toString();
}
