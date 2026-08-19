/// 2026-08-19: Nave's Topical Bible (1896).
///
/// Nave's is not a dictionary and not a concordance. A concordance finds a
/// WORD; Nave's finds what a verse is ABOUT. Its entry for AARON does not
/// define Aaron — it assembles him out of the text, one assertion at a
/// time, each with the verses that carry it: "Lineage of", "Marriage of",
/// "Rod of, buds", "Murmured against, by the people". Fourteen years of
/// one man reading the KJV and filing every verse under what it says.
///
/// So the unit here is the LINE, not the topic, and the lines nest three
/// deep. That is why [NaveCitation] carries [ancestors]: under MINISTER a
/// line reading ".Paul" means nothing until you can see it sits beneath
/// "–Called of God". A pane that showed only the headword would throw
/// away the part Nave actually wrote.
///
/// It is also why this is entered from the VERSE. The reader sitting on
/// 2 Chronicles 34:20 wants to be told that Nave files this verse under
/// MICAH and under MESSENGER; asking them to go and look it up is the
/// same mistake the Modern Concordance pane was built to avoid.
///
/// **Citations are of two kinds and the difference is not cosmetic.**
/// 75,804 of Nave's references name a verse or a verse range; 2,170 name
/// a WHOLE CHAPTER ("Rod of, buds — Nu 17"). A chapter citation is not
/// evidence that Nave filed verse 8 under that line, so it is indexed at
/// the chapter and reaches the reader marked as [chapterLevel]. Expanding
/// it would have manufactured 57,493 verse-level claims Nave never made,
/// and they would have looked exactly like the real ones.
///
/// The electronic text needed repairing before any of that was true. Its
/// tagger cannot read a one-chapter book: it filed all 250 references to
/// Obadiah, Philemon, 2 John, 3 John and Jude at verse 1 of the book and
/// left the real verse in the prose behind the link, so Jude 1:1 carried
/// 115 topics and Jude 1:14 carried none. See `tools/import_naves.py`.
///
/// Loading mirrors [ModernConcordanceService]: a 90 KB index held from
/// first use, one 1.8 MB-total verse file per book, and topics in shards
/// of 40. The whole set is 4.3 MB and must never be loaded eagerly.
///
/// Rights: the work is public domain (1896). The electronic text is
/// CCEL's ThML edition, which the SWORD project also distributes as
/// public domain; [attribution] carries that statement out of the asset
/// so a UI showing this data shows its source with it.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../constants/book_names.dart';
import '../utils/naves_browse.dart' show matchHeadwords;
import '../utils/version_mapper.dart' show localeAwareBookName;

/// A reference as Nave printed it, at the granularity he printed it.
@immutable
class NaveRef {
  const NaveRef({
    required this.book,
    required this.chapter,
    this.verse,
    this.endVerse,
  });

  /// `"13.6.3-15"` — book index into [standardBookOrder], chapter, verse,
  /// optional end verse. A code with no verse is a whole chapter.
  static NaveRef? parse(String code) {
    final parts = code.split('.');
    if (parts.length < 2) return null;
    final b = int.tryParse(parts[0]);
    final c = int.tryParse(parts[1]);
    if (b == null || c == null || b < 1 || b > standardBookOrder.length) {
      return null;
    }
    if (parts.length == 2) {
      return NaveRef(book: standardBookOrder[b - 1], chapter: c);
    }
    final span = parts[2].split('-');
    final v = int.tryParse(span.first);
    if (v == null) return null;
    return NaveRef(
      book: standardBookOrder[b - 1],
      chapter: c,
      verse: v,
      endVerse: span.length > 1 ? int.tryParse(span[1]) : null,
    );
  }

  final String book;
  final int chapter;
  final int? verse;
  final int? endVerse;

  bool get isChapter => verse == null;

  /// Whether this reference covers a given verse. A chapter reference
  /// covers the chapter, which is a weaker claim — see [chapterLevel].
  bool covers(String book, int chapter, int verse) {
    if (this.book != book || this.chapter != chapter) return false;
    if (this.verse == null) return true;
    return verse >= this.verse! && verse <= (endVerse ?? this.verse!);
  }

  /// `Genesis 1:1-5`, in the reading language's book name.
  String label(String locale) {
    final name = localeAwareBookName(book, locale);
    if (verse == null) return '$name $chapter';
    if (endVerse != null) return '$name $chapter:$verse-$endVerse';
    return '$name $chapter:$verse';
  }
}

/// One line of a topic — the assertion Nave wrote, its depth, its
/// references, and any "See ALSO" it hands off to.
@immutable
class NaveLine {
  const NaveLine({
    required this.depth,
    required this.text,
    required this.refs,
    required this.see,
  });

  factory NaveLine.fromJson(Map<String, dynamic> j) => NaveLine(
        depth: (j['d'] ?? 0) as int,
        text: (j['t'] ?? '') as String,
        refs: [
          for (final r in (j['r'] as List? ?? const []))
            if (NaveRef.parse(r as String) case final ref?) ref,
        ],
        see: [
          for (final s in (j['s'] as List? ?? const []))
            NaveSee(
              name: ((s as List).first ?? '') as String,
              topicId: s.length > 1 ? s[1] as int? : null,
            ),
        ],
      );

  /// 1, 2 or 3 — Nave's own indentation, carried as data.
  final int depth;
  final String text;
  final List<NaveRef> refs;
  final List<NaveSee> see;
}

/// "See PRIEST, HIGH". [topicId] is null when the target is named in a
/// form that is not one of our headwords — 1,047 of 4,368 are, because
/// the electronic edition keys them by its own index rather than by the
/// printed headword. Those still print; they just do not pretend to be
/// tappable.
@immutable
class NaveSee {
  const NaveSee({required this.name, required this.topicId});
  final String name;
  final int? topicId;
}

@immutable
class NaveTopic {
  const NaveTopic({
    required this.id,
    required this.head,
    required this.lines,
  });

  final int id;
  final String head;
  final List<NaveLine> lines;

  /// The lines a given line hangs beneath, outermost first. A depth-3
  /// line is a fragment without them.
  ///
  /// Any line shallower than the one being sought closes the subtree, so
  /// it is the ancestor even when it skips a level. Matching only on the
  /// exact depth would step over it and keep walking into the PREVIOUS
  /// topic branch, which files the reader's verse under a heading Nave
  /// put something else beneath.
  List<NaveLine> ancestorsOf(int index) {
    if (index < 0 || index >= lines.length) return const [];
    final out = <NaveLine>[];
    var want = lines[index].depth - 1;
    for (var i = index - 1; i >= 0 && want > 0; i--) {
      if (lines[i].depth <= want) {
        out.insert(0, lines[i]);
        want = lines[i].depth - 1;
      }
    }
    return out;
  }
}

/// A topic that cites the verse in view, resolved far enough to render.
@immutable
class NaveCitation {
  const NaveCitation({
    required this.topicId,
    required this.head,
    required this.lineIndex,
    required this.line,
    required this.ancestors,
    required this.chapterLevel,
  });

  final int topicId;
  final String head;
  final int lineIndex;
  final NaveLine line;

  /// The lines this one sits under, outermost first.
  final List<NaveLine> ancestors;

  /// True when Nave cited the whole chapter rather than this verse. The
  /// citation is real; the claim is weaker, and the pane says so.
  final bool chapterLevel;

  /// `AARON › Priesthood of` — the path a reader needs to read the line.
  String get path => [head, ...ancestors.map((a) => a.text)].join(' › ');
}

class NavesService {
  static const _base = 'assets/nave';

  static List<String>? _heads;
  static List<int> _lineCounts = const [];
  static List<int> _refCounts = const [];
  static int _perShard = 40;
  static String _attribution = '';
  static Map<int, List<String>>? _lineTexts;

  static final Map<int, Map<int, NaveTopic>> _shardCache = {};
  static final Map<String, Map<String, dynamic>> _verseCache = {};

  /// The source statement to show wherever this data is displayed.
  static String get attribution => _attribution;

  /// Headwords by topic id. Loads the 90 KB index once and holds it.
  static Future<List<String>> heads() async {
    final cached = _heads;
    if (cached != null) return cached;
    try {
      final j = json.decode(await rootBundle.loadString('$_base/index.json'))
          as Map<String, dynamic>;
      _attribution = (j['attribution'] ?? '') as String;
      _perShard = (j['topicsPerShard'] ?? 40) as int;
      final rows = (j['topics'] as List? ?? const []);
      _lineCounts = [for (final r in rows) ((r as List)[1] ?? 0) as int];
      _refCounts = [for (final r in rows) ((r as List)[2] ?? 0) as int];
      return _heads = [for (final r in rows) ((r as List).first ?? '') as String];
    } catch (_) {
      // An optional asset set. A build without it renders an empty
      // section, not an exception into the pane.
      _lineCounts = const [];
      _refCounts = const [];
      return _heads = const [];
    }
  }

  /// How many references a topic carries — the only honest measure of
  /// how much of Nave's work sits behind a headword.
  static int refCountOf(int topicId) =>
      topicId >= 0 && topicId < _refCounts.length ? _refCounts[topicId] : 0;

  static int lineCountOf(int topicId) =>
      topicId >= 0 && topicId < _lineCounts.length ? _lineCounts[topicId] : 0;

  /// One topic, with every line in Nave's order.
  static Future<NaveTopic?> topic(int id) async {
    await heads();
    final shardId = id ~/ _perShard;
    var shard = _shardCache[shardId];
    if (shard == null) {
      try {
        final j =
            json.decode(await rootBundle.loadString('$_base/t/$shardId.json'))
                as Map<String, dynamic>;
        shard = {
          for (final e in j.entries)
            int.parse(e.key): NaveTopic(
              id: int.parse(e.key),
              head: ((e.value as Map<String, dynamic>)['h'] ?? '') as String,
              lines: [
                for (final l in (e.value['l'] as List? ?? const []))
                  NaveLine.fromJson(l as Map<String, dynamic>),
              ],
            ),
        };
      } catch (_) {
        shard = const {};
      }
      _shardCache[shardId] = shard;
    }
    return shard[id];
  }

  /// Every topic line that cites this verse.
  ///
  /// Verse-level citations come first and chapter-level ones after, which
  /// is the order of how much they claim. Within each, topics are ordered
  /// by how much Nave wrote about them — a verse that MESSENGER cites in
  /// passing and MICAH is built on should lead with MICAH.
  static Future<List<NaveCitation>> forVerse({
    required String englishBook,
    required int chapter,
    required int verse,
  }) async {
    await heads();
    if (_heads?.isEmpty ?? true) return const [];
    final file = englishBook.toLowerCase().replaceAll(' ', '_');
    var book = _verseCache[file];
    if (book == null) {
      try {
        book = json.decode(await rootBundle.loadString('$_base/v/$file.json'))
            as Map<String, dynamic>;
      } catch (_) {
        book = const {};
      }
      _verseCache[file] = book;
    }
    final ch = book['$chapter'] as Map<String, dynamic>?;
    if (ch == null) return const [];

    final out = <NaveCitation>[];
    for (final (key, chapterLevel) in [('$verse', false), ('0', true)]) {
      final hits = ch[key] as List? ?? const [];
      final rows = <NaveCitation>[];
      for (final hit in hits) {
        final topicId = (hit as List)[0] as int;
        final lineIndex = hit[1] as int;
        final t = await topic(topicId);
        if (t == null || lineIndex >= t.lines.length) continue;
        rows.add(NaveCitation(
          topicId: topicId,
          head: t.head,
          lineIndex: lineIndex,
          line: t.lines[lineIndex],
          ancestors: t.ancestorsOf(lineIndex),
          chapterLevel: chapterLevel,
        ));
      }
      rows.sort((a, b) {
        final c = refCountOf(b.topicId).compareTo(refCountOf(a.topicId));
        return c != 0 ? c : a.head.compareTo(b.head);
      });
      out.addAll(rows);
    }
    return out;
  }

  /// Headword search for the topic index. Ranking lives in
  /// `utils/naves_browse.dart`, where it is testable without a bundle.
  static Future<List<int>> search(String query, {int limit = 60}) async {
    final all = await heads();
    return [
      for (final hit in matchHeadwords(all, query).take(limit)) hit.topicId,
    ];
  }

  /// The text of every line in the work, topic id → lines in Nave's
  /// order, for searching what the entries SAY rather than what they
  /// are called.
  ///
  /// One 790 KB file (270 KB over the wire) rather than the 134 shard
  /// requests the same query would otherwise cost, and loaded only when
  /// a reader asks for it — the headword tier answers most questions off
  /// the 90 KB index and never touches this.
  static Future<Map<int, List<String>>> lineTexts() async {
    final cached = _lineTexts;
    if (cached != null) return cached;
    try {
      final j = json.decode(await rootBundle.loadString('$_base/lines.json'))
          as Map<String, dynamic>;
      final rows = (j['lines'] as Map<String, dynamic>? ?? const {});
      return _lineTexts = {
        for (final e in rows.entries)
          int.parse(e.key): [
            for (final t in (e.value as List? ?? const [])) t as String,
          ],
      };
    } catch (_) {
      return _lineTexts = const {};
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _heads = null;
    _lineCounts = const [];
    _refCounts = const [];
    _attribution = '';
    _lineTexts = null;
    _shardCache.clear();
    _verseCache.clear();
  }
}
