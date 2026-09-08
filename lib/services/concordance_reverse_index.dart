/// 2026-09-08 (SeekSparks): Eagle's View's Modern Concordance, read
/// backwards — from a Strong's number to where the concordance files it.
///
/// The forward direction has shipped since v1.6.x: pick a topic, read
/// its Greek words and their verses (`ModernConcordanceService`,
/// `modern_concordance_page.dart`), or sit on a verse and be told which
/// topics cite it (`forVerse`). The one direction nobody could travel
/// was the one a reader on a lexicon entry actually wants: *this word —
/// what subjects is it filed under, and which other Greek words sit
/// beside it there?*
///
/// **What the shipped asset does and does not carry.** `index.json`
/// declares a `wordTypes` vocabulary of five relations — R1 synonym /
/// related, R2 biological relation or person's name, R3 geographical
/// relation or place name, R4 antonym, WF word family. Those labels are
/// declared and never used: `greek.json` gives all 5,175 Greek words the
/// type id `RX`, which is not one of the five, and no row under `t/` or
/// `v/` carries a type at all. So there is no typed edge in this data to
/// surface, and this file does not invent one. If a future asset build
/// starts carrying them, `test/concordance_reverse_index_test.dart`
/// fails and says so.
///
/// **What it does carry is co-membership, at two levels**, and the levels
/// mean different things because the hierarchy does:
///
///   * A SECTION is a Greek word family, named for its lead word —
///     "Abomination: BDELUGMA" holds G946 BDELUGMA, G947 BDELUSSO and
///     G948 BDELUKTOS; "Man, men - People: ANTHROPOS" holds G444 with
///     G441, G442, G443, G5363 and G5364.
///   * A SUBSECTION heading is one sense of that family — "The love of
///     God - For others" — and the rows under it name every word of the
///     family that carries that sense.
///
/// So two words sharing a heading are [ConcordanceRelation.sameSense],
/// and two words sharing only the section are
/// [ConcordanceRelation.sameFamily]. Both are the concordance's own
/// editorial judgement, restated rather than inferred. Neither is a
/// semantic-domain classification and neither should be presented as one.
///
/// **Why the join key is (subsection id, part) and not the heading text.**
/// Both were tried. 45 of 3,886 heading groups disagree with themselves
/// on capitalisation ("the Beloved" / "The Beloved"), so grouping on the
/// text splits three synonyms into two groups for no reason a reader
/// could see. The id/part pair is what the source keys on and what
/// `tools/build_concordance_assets.py` preserved; the text is a label.
///
/// **Why this reads the topic files itself** rather than going through
/// `ModernConcordanceService.sections()`: that loader drops the
/// subsection id and part on the floor, because the browse page has no
/// use for them. They are exactly the join key the neighbour relation
/// needs, so a second reader of the same asset is the honest fix — not
/// widening a model the browse page would then carry for nothing.
///
/// **Why the whole set is scanned instead of a new index asset.** There
/// is no Strong's -> topic index in `assets/concordance/`, and building
/// one offline would mean a 342nd file for a question answerable from
/// the 341 already there. Measured on this data: reading and decoding
/// all 341 topic files costs 29 ms for 2.6 MB (18 ms of it file reads).
/// That is once per session, on a deliberate tap, and it is not worth an
/// asset. What is kept afterwards is only which topics mention which
/// word — 6,022 integers. The 58,466 neighbour records are rebuilt per
/// lookup from the 1.16 topic files an average word needs, because
/// holding them would cost megabytes to save a tenth of a millisecond.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/services/modern_concordance_service.dart';

/// How a neighbour sits beside the word being looked up.
///
/// Deliberately NOT the `wordTypes` vocabulary the index declares — see
/// the library doc. These two are structural facts about where the
/// concordance put each word, and they are the strongest claim the
/// shipped data supports.
enum ConcordanceRelation {
  /// Filed under the same subsection heading: the concordance reads the
  /// two words as carrying the same sense here.
  sameSense,

  /// Same section, different heading: the same Greek word family, used
  /// in a different sense of the topic.
  sameFamily,
}

/// One other Strong's number sitting beside the looked-up word.
@immutable
class ConcordanceNeighbour {
  const ConcordanceNeighbour({required this.strongs, required this.relation});

  final String strongs;
  final ConcordanceRelation relation;

  @override
  bool operator ==(Object other) =>
      other is ConcordanceNeighbour &&
      other.strongs == strongs &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(strongs, relation);

  @override
  String toString() => '$strongs(${relation.name})';
}

/// One place the concordance files a Strong's number: a topic, one of
/// its sections, and everything the word does there.
///
/// Collapsed to one per (topic, section) on purpose. G444 ANTHROPOS
/// carries nine separate senses inside "Man, men - People: ANTHROPOS",
/// and nine rows with identical neighbours read as a bug rather than as
/// nine senses. The senses survive as [headings]; the neighbours are
/// stated once.
@immutable
class ConcordanceFiling {
  const ConcordanceFiling({
    required this.topicId,
    required this.topicEn,
    required this.topicZh,
    required this.sectionId,
    required this.sectionEn,
    required this.sectionZh,
    required this.headings,
    required this.occurrences,
    required this.neighbours,
  });

  final int topicId;
  final String topicEn;
  final String topicZh;

  /// Section number WITHIN the topic — the pair (topicId, sectionId) is
  /// what identifies a section, not the id alone.
  final int sectionId;
  final String sectionEn;
  final String sectionZh;

  /// The subsection headings this word carries here, in file order, as
  /// (English, Chinese) pairs. Either half can be empty: 1,901 of the
  /// 7,758 rows have no English heading and 1,939 have no Chinese one.
  final List<(String, String)> headings;

  /// Verse links this word has under this section. Used to order the
  /// filings, so the topic where the word does most of its work is the
  /// one a reader sees first — G444 leads with "Man - People - Woman"
  /// (449 links), not with "Son - Daughter" (81).
  final int occurrences;

  /// Everything else filed in this section, [ConcordanceRelation.sameSense]
  /// first, each group in Strong's-number order.
  final List<ConcordanceNeighbour> neighbours;

  /// The reading-language name, on the same rule as
  /// [ConcordanceTopic.label]: Chinese covers both scripts, because the
  /// source is Simplified and a 繁體 reader is better served by that than
  /// by falling back to English.
  String topicLabel(String locale) =>
      locale.startsWith('zh') && topicZh.isNotEmpty ? topicZh : topicEn;

  String sectionLabel(String locale) =>
      locale.startsWith('zh') && sectionZh.isNotEmpty ? sectionZh : sectionEn;

  /// The senses this word carries here, in the reading language, with
  /// the empty ones dropped rather than rendered as blank bullets.
  List<String> headingLabels(String locale) {
    final zh = locale.startsWith('zh');
    final out = <String>[];
    for (final (en, hanzi) in headings) {
      final label = zh && hanzi.isNotEmpty ? hanzi : en;
      if (label.isNotEmpty && !out.contains(label)) out.add(label);
    }
    return out;
  }
}

/// Where [strongs] is filed inside ONE decoded topic file.
///
/// Pure: takes the decoded `assets/concordance/t/<id>.json` map and
/// returns filings. No asset loading, no caching, no ordering across
/// topics — that is [ConcordanceReverseIndex]'s job, and keeping it out
/// of here is what makes the relation itself testable against a literal.
List<ConcordanceFiling> filingsInTopic(
  Map<String, dynamic> topic,
  String strongs,
) {
  final topicId = (topic['id'] as num?)?.toInt() ?? 0;
  final topicEn = (topic['en'] ?? '') as String;
  final topicZh = (topic['zh'] ?? '') as String;
  final out = <ConcordanceFiling>[];

  for (final rawSection in (topic['sections'] as List? ?? const [])) {
    final section = rawSection as Map<String, dynamic>;
    final rows = (section['subsections'] as List? ?? const []);

    // The headings THIS word carries here, and how much work it does.
    // `id` is absent on 2,752 rows because the builder drops zeros to
    // halve the payload, so absent means 0 and not "unknown".
    final mine = <String>{};
    final headings = <(String, String)>[];
    var occurrences = 0;
    for (final rawRow in rows) {
      final row = rawRow as Map<String, dynamic>;
      if (row['g'] != strongs) continue;
      mine.add('${row['id'] ?? 0}/${row['part'] ?? 0}');
      occurrences += ((row['refs'] as List?) ?? const []).length;
      headings.add(((row['en'] ?? '') as String, (row['zh'] ?? '') as String));
    }
    if (mine.isEmpty) continue;

    final sense = <String>{};
    final everyone = <String>{};
    for (final rawRow in rows) {
      final row = rawRow as Map<String, dynamic>;
      final g = (row['g'] ?? '') as String;
      if (g.isEmpty) continue;
      everyone.add(g);
      if (mine.contains('${row['id'] ?? 0}/${row['part'] ?? 0}')) sense.add(g);
    }
    sense.remove(strongs);
    everyone.remove(strongs);

    out.add(ConcordanceFiling(
      topicId: topicId,
      topicEn: topicEn,
      topicZh: topicZh,
      sectionId: (section['id'] as num?)?.toInt() ?? 0,
      sectionEn: (section['en'] ?? '') as String,
      sectionZh: (section['zh'] ?? '') as String,
      headings: headings,
      occurrences: occurrences,
      neighbours: [
        for (final g in _byNumber(sense))
          ConcordanceNeighbour(
              strongs: g, relation: ConcordanceRelation.sameSense),
        for (final g in _byNumber(everyone.difference(sense)))
          ConcordanceNeighbour(
              strongs: g, relation: ConcordanceRelation.sameFamily),
      ],
    ));
  }
  return out;
}

/// Strong's numbers in NUMERIC order. Lexicographic order puts G5364
/// before G946, which reads as an unsorted list to anyone who knows the
/// numbering.
List<String> _byNumber(Iterable<String> numbers) {
  int value(String g) => int.tryParse(g.replaceAll(RegExp(r'\D'), '')) ?? 0;
  return numbers.toList()
    ..sort((a, b) {
      final c = value(a).compareTo(value(b));
      return c != 0 ? c : a.compareTo(b);
    });
}

/// Strong's number -> where the Modern Concordance files it.
///
/// Greek only, and that is the data speaking rather than a limitation
/// being papered over: the Modern Concordance is a New Testament Greek
/// concordance, so a Hebrew number has no answer here and gets an empty
/// list without touching a single asset. That also keeps this off the
/// path of every widget test that mounts a Hebrew entry.
class ConcordanceReverseIndex {
  static const _base = 'assets/concordance';

  /// Strong's number -> the topic ids whose file mentions it. Built
  /// once; see the library doc for why only this much is kept.
  static Map<String, List<int>>? _topics;
  static Future<Map<String, List<int>>>? _building;

  /// The source statement to show wherever this data is displayed. Comes
  /// out of `index.json` via [ModernConcordanceService] rather than
  /// being written again here — the permission is conditional on the
  /// credit, and two copies of a credit is one copy that can drift.
  static String get attribution => ModernConcordanceService.attribution;

  /// Every filing for [strongs], busiest topic first.
  ///
  /// Empty — never an error — for a Hebrew number, for a Greek number
  /// the concordance does not carry (449 of the numbers below G5624 are
  /// absent), and for a build without the concordance assets.
  static Future<List<ConcordanceFiling>> filings(String strongs) async {
    if (!strongs.startsWith('G')) return const [];
    final index = _topics ??= await (_building ??= _build());
    final ids = index[strongs];
    if (ids == null || ids.isEmpty) return const [];

    final out = <ConcordanceFiling>[];
    for (final id in ids) {
      final topic = await _topicJson(id);
      if (topic != null) out.addAll(filingsInTopic(topic, strongs));
    }
    out.sort((a, b) {
      final c = b.occurrences.compareTo(a.occurrences);
      if (c != 0) return c;
      final t = a.topicEn.compareTo(b.topicEn);
      return t != 0 ? t : a.sectionId.compareTo(b.sectionId);
    });
    return out;
  }

  static Future<Map<String, dynamic>?> _topicJson(int id) async {
    try {
      return json.decode(await rootBundle.loadString('$_base/t/$id.json'))
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, List<int>>> _build() async {
    final out = <String, List<int>>{};
    for (final topic in await ModernConcordanceService.topics()) {
      final j = await _topicJson(topic.id);
      if (j == null) continue;
      // A word appears many times inside one topic — G444 has ten rows
      // under "Man - People - Woman" alone. The index answers "which
      // FILES do I have to open", so it wants the topic once.
      final seen = <String>{};
      for (final rawSection in (j['sections'] as List? ?? const [])) {
        for (final rawRow
            in ((rawSection as Map)['subsections'] as List? ?? const [])) {
          final g = ((rawRow as Map)['g'] ?? '') as String;
          if (g.isEmpty || !seen.add(g)) continue;
          (out[g] ??= <int>[]).add(topic.id);
        }
      }
    }
    return out;
  }

  @visibleForTesting
  static void resetForTest() {
    _topics = null;
    _building = null;
  }
}
