/// The teachings of the Lord Jesus, and what the app already knows about
/// each one.
///
/// The data is built by `scripts/build_jesus_teachings.py`, which holds
/// the whole argument for how the list is arranged and what it may
/// claim. Two points matter enough to repeat here, because they decide
/// what this page is allowed to SAY:
///
///   * THE ARRANGEMENT IS EDITORIAL. There is no canonical enumeration
///     of Jesus' teachings. The parables are a stable category; the
///     discourses are not, and every published list is somebody's
///     scheme. The page tells the reader so.
///   * A CROSS-REFERENCE IS NOT A DERIVATION. The Treasury of Scripture
///     Knowledge asserts that two passages are RELATED. It does not
///     assert that one rests on the other, and nothing in this file
///     upgrades that. The only links that carry a claim of dependence
///     are those where an apostle says so himself — [TeachingLink.lordsWord]
///     — and there are five places in the New Testament like that.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One reference span, as the generator emitted it.
class TeachingRef {
  const TeachingRef({
    required this.book,
    required this.chapter,
    required this.start,
    required this.end,
  });

  factory TeachingRef.fromJson(Map<String, dynamic> j) => TeachingRef(
        book: j['book'] as String,
        chapter: j['chapter'] as int,
        start: j['start'] as int,
        end: j['end'] as int,
      );

  final String book;
  final int chapter;
  final int start;
  final int end;

  /// What `parseReference` expects, and what a reader would write.
  String get label =>
      end > start ? '$book $chapter:$start-$end' : '$book $chapter:$start';
}

/// One apostolic passage related to a teaching.
class TeachingLink {
  const TeachingLink({required this.ref, this.lordsWord});

  factory TeachingLink.fromJson(Map<String, dynamic> j) => TeachingLink(
        ref: j['ref'] as String,
        lordsWord: j['lordsWord'] as String?,
      );

  final String ref;

  /// Non-null only where the apostle himself says he is passing on the
  /// Lord's own word — "received of the Lord", "the Lord commanded".
  /// This is the one place on the page where a link asserts dependence
  /// rather than relation, and it is scripture making the assertion.
  final String? lordsWord;
}

/// One sermon from the bundled corpus that expounds a teaching.
class TeachingSermon {
  const TeachingSermon({
    required this.id,
    required this.title,
    required this.date,
    required this.topic,
  });

  factory TeachingSermon.fromJson(Map<String, dynamic> j) => TeachingSermon(
        id: j['id'] as String,
        title: Map<String, String>.from(
            (j['title'] as Map).map((k, v) => MapEntry('$k', '$v'))),
        date: j['date'] as String? ?? '',
        topic: j['topic'] as String? ?? '',
      );

  final String id;

  /// Keyed `en` / `zh-CN` / `zh-TW`, as the sermon corpus keys them.
  final Map<String, String> title;
  final String date;
  final String topic;

  String titleFor(String locale) =>
      title[locale == 'zh-Hant' ? 'zh-TW' : locale == 'zh-Hans' ? 'zh-CN' : 'en'] ??
      title['en'] ??
      '';
}

class JesusTeaching {
  const JesusTeaching({
    required this.id,
    required this.title,
    required this.refs,
    required this.label,
    required this.origins,
    required this.partOf,
    required this.sermons,
    required this.oldTestament,
    required this.apostles,
    required this.plates,
  });

  factory JesusTeaching.fromJson(Map<String, dynamic> j) => JesusTeaching(
        id: j['id'] as String,
        title: Map<String, String>.from(
            (j['title'] as Map).map((k, v) => MapEntry('$k', '$v'))),
        refs: [
          for (final r in (j['refs'] as List))
            TeachingRef.fromJson(r as Map<String, dynamic>)
        ],
        label: j['label'] as String? ?? '',
        origins: [for (final o in (j['origins'] as List? ?? [])) '$o'],
        partOf: j['partOf'] as String?,
        sermons: [
          for (final s in (j['sermons'] as List? ?? []))
            TeachingSermon.fromJson(s as Map<String, dynamic>)
        ],
        oldTestament: [for (final r in (j['oldTestament'] as List? ?? [])) '$r'],
        apostles: [
          for (final a in (j['apostles'] as List? ?? []))
            TeachingLink.fromJson(a as Map<String, dynamic>)
        ],
        plates: [for (final p in (j['plates'] as List? ?? [])) '$p'],
      );

  final String id;
  final Map<String, String> title;
  final List<TeachingRef> refs;

  /// The refs as one printable string, built once by the generator so
  /// the page and any test read the same words.
  final String label;

  /// Where this entry came from: `structure`, `sermon`, `nave`. Shown
  /// to the reader, because an editorial arrangement that will not say
  /// which parts are editorial is not being honest about itself.
  final List<String> origins;

  /// The discourse this teaching sits inside, if any. The Sermon on the
  /// Mount contains the Beatitudes contains a sermon on a single verse;
  /// this is what lets the page show that rather than flatten it.
  final String? partOf;

  final List<TeachingSermon> sermons;
  final List<String> oldTestament;
  final List<TeachingLink> apostles;
  final List<String> plates;

  bool get isDiscourse => origins.contains('structure');

  String titleFor(String locale) =>
      title[locale] ?? title['en'] ?? title.values.first;
}

class JesusTeachingsData {
  const JesusTeachingsData({required this.teachings, required this.claims});

  final List<JesusTeaching> teachings;

  /// `_meta.claims` — what the page is allowed to say about its links,
  /// carried out of the data rather than retyped in the UI so the two
  /// cannot drift.
  final String claims;

  /// The parts of a discourse, in canonical order.
  List<JesusTeaching> partsOf(String id) =>
      [for (final t in teachings) if (t.partOf == id) t];

  /// Everything a reader meets at the top level: the discourses, and
  /// the teachings that belong to none of them.
  List<JesusTeaching> get topLevel =>
      [for (final t in teachings) if (t.partOf == null) t];
}

class JesusTeachingsService {
  JesusTeachingsService._();

  static final JesusTeachingsService instance = JesusTeachingsService._();

  JesusTeachingsData? _cache;
  Future<JesusTeachingsData>? _inFlight;

  JesusTeachingsData? get cached => _cache;

  Future<JesusTeachingsData> load() =>
      _inFlight ??= _load().then((value) => _cache = value);

  Future<JesusTeachingsData> _load() async {
    final raw = await rootBundle.loadString('assets/jesus_teachings.json');
    final doc = json.decode(raw) as Map<String, dynamic>;
    return JesusTeachingsData(
      teachings: [
        for (final t in (doc['teachings'] as List))
          JesusTeaching.fromJson(t as Map<String, dynamic>)
      ],
      claims: (doc['_meta'] as Map?)?['claims'] as String? ?? '',
    );
  }
}
