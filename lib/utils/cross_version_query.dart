/// A conjunction ACROSS editions — `.kjv:propitiation csb:atoning`.
///
/// `docs/PARITY-BACKLOG.md` §3.1 opened this entry after the
/// cross-version *broadcast* (bwh16) turned out to be a different
/// feature from the one the old row described: *"Find verses where the
/// KJV says X and the LXX says Y … a version tag per term."* BibleWorks
/// reaches that only through the Graphical Search Engine, so this is
/// ours rather than a port, and the row records why it is worth having:
/// adjudicating the CSB's divine name on 2026-09-07 needed exactly this
/// query three times in one day, and each time it was run by hand in
/// Python against the raw assets.
///
/// ## What it is, and what it is not
///
/// **Not** the broadcast. `cross_version_search.dart` runs ONE query
/// against SEVERAL editions and reports each one's hits separately;
/// this runs a DIFFERENT query against each edition and returns the
/// verses where all of them hold at once. One asks "who else says it",
/// the other asks "where do these two disagree".
///
/// ## The grammar, and why it is this shape
///
/// The control character keeps its job — it is still the first thing on
/// the line and still says what kind of search this is — and a term may
/// now carry a `code:` prefix naming the edition it applies to:
///
///     .kjv:propitiation csb:atoning     both, same verse
///     /kjv:charity kjv:love             either (one edition, still fine)
///     .love csb:atoning                 an untagged term uses the
///                                       reading version
///
/// **A prefix is only a prefix when it names an edition this build can
/// load.** That is what keeps the grammar unambiguous: `H1254:` is not a
/// version, so it stays a search term, and no reader loses a colon they
/// meant literally. It also means the feature cannot silently widen when
/// somebody adds a version whose code collides with a word — the check
/// is against the catalog, at parse time, every time.
///
/// A term with no prefix belongs to the reading version, so the shortest
/// useful form of this query is one tagged term beside an ordinary one.
///
/// Flutter-free: this parses. Running it needs the corpora, which is
/// `WorkbenchProvider`'s job.
library;

import 'package:seeksparks/constants/bible_versions.dart'
    show loadableVersions;

/// One edition and what must be true of it.
class VersionTerm {
  const VersionTerm({required this.version, required this.query});

  /// A loadable version code, already normalised.
  final String version;

  /// The command line to run against it — control character included,
  /// so each side is an ordinary query the existing engine can run.
  final String query;
}

/// A parsed cross-version conjunction.
class CrossVersionQuery {
  const CrossVersionQuery({required this.terms, required this.all});

  /// One entry per edition named, in the order the reader wrote them.
  /// The reading version, when an untagged term put it there, comes
  /// first.
  final List<VersionTerm> terms;

  /// True for `.` (every edition must match), false for `/` (any).
  final bool all;

  /// Two or more editions is what makes it cross-version; one is an
  /// ordinary search and the caller should run it as one.
  bool get isCrossVersion => terms.length > 1;
}

final RegExp _tagged = RegExp(r'^([A-Za-z][A-Za-z0-9-]*):(.+)$');

/// Parse [raw] as a cross-version conjunction, or return null when it is
/// not one — which is the ordinary case and must stay cheap.
///
/// [reading] is the edition an untagged term belongs to.
CrossVersionQuery? parseCrossVersionQuery(String raw, String reading) {
  final line = raw.trim();
  if (line.length < 2) return null;
  final control = line[0];
  if (control != '.' && control != '/') return null;
  if (!line.contains(':')) return null;

  final read = loadableVersions([reading]);
  final readingCode = read.isEmpty ? null : read.first;

  // Only `.` and `/` — the two forms whose terms are independent of one
  // another. The phrase forms (`'`, `;`) are deliberately absent: a
  // phrase is an ORDER over adjacent tokens, and splitting it per
  // edition would cut it in half and run each piece as its own term.
  // Refusing here lets the line fall through to the ordinary parser and
  // get its usual treatment rather than a mangled one.
  final body = line.substring(1).trim();
  if (body.isEmpty) return null;

  final byVersion = <String, List<String>>{};
  final order = <String>[];
  var sawTag = false;

  for (final token in body.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    // `kjv:` with nothing after it names an edition and asks nothing of
    // it. Refuse the whole line rather than quietly searching the
    // reading version for the literal string "kjv:" — a typo in a
    // grammar this new should stop, not answer a different question.
    if (token.endsWith(':') &&
        loadableVersions([token.substring(0, token.length - 1)]).isNotEmpty) {
      return null;
    }
    final m = _tagged.firstMatch(token);
    String? code;
    String term = token;
    if (m != null) {
      final candidate = loadableVersions([m.group(1)!]);
      if (candidate.isNotEmpty) {
        code = candidate.first;
        term = m.group(2)!;
        sawTag = true;
      }
    }
    final target = code ?? readingCode;
    // No reading version and no tag: there is no edition to run this
    // term against, and guessing one would answer a question nobody
    // asked.
    if (target == null) return null;
    if (term.isEmpty) return null;
    if (!byVersion.containsKey(target)) order.add(target);
    byVersion.putIfAbsent(target, () => <String>[]).add(term);
  }

  if (!sawTag) return null;
  if (order.length < 2) return null;

  return CrossVersionQuery(
    terms: [
      for (final code in order)
        VersionTerm(
          version: code,
          // Each side is rebuilt as an ordinary command line, so the
          // existing parser and matcher run it unchanged — the whole
          // reason this file only parses.
          query: '$control${byVersion[code]!.join(' ')}',
        ),
    ],
    all: control == '.',
  );
}

/// Combine per-edition verse-id sets into the answer.
///
/// Ids and not indices: the editions are separate corpora and a verse's
/// position in one says nothing about its position in another. Every
/// shipped edition is keyed `BBBCCCVVV` against the same canon, which is
/// what makes the intersection meaningful at all — and what
/// `test/csb_asset_test.dart` and its siblings check per edition.
Set<String> combineCrossVersion(
    List<Set<String>> perVersion, {required bool all}) {
  if (perVersion.isEmpty) return <String>{};
  if (!all) {
    final out = <String>{};
    for (final s in perVersion) {
      out.addAll(s);
    }
    return out;
  }
  var out = perVersion.first;
  for (final s in perVersion.skip(1)) {
    out = out.intersection(s);
    if (out.isEmpty) break;
  }
  return {...out};
}
