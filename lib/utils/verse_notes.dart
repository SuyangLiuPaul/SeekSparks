/// 2026-08-18 (SeekSparks): the rules a user note follows — over a
/// SELECTION of verses, and over the whole note store.
///
/// BibleWorks keeps user notes in a docked Analysis tab (help topic
/// bwh15): you select the verse, the note for it loads, you type, and it
/// is written back when the verse changes. SeekSparks had the same data
/// but only a modal editor and a separate Library page for it, so a
/// reader studying a verse had to leave the verse to read their own note
/// on it.
///
/// Adding a docked editor means a SECOND writer over the same store, and
/// two writers that each carry their own idea of "which note does this
/// selection show" and "what is this range called" will drift — quietly,
/// and in user data. So the parts that are decisions rather than pixels
/// live here, pure, and both surfaces call them:
///
///   * [resolveNotePrefill] — which of the selected verses the editor
///     opens on;
///   * [verseNoteRangeLabel] — what the selection is called above it;
///   * [parseVerseId] — how a stored key is read back into a reference;
///   * [searchNotes] — bwh15's "Searching User Notes", which the app had
///     nowhere at all: `library_page.dart` lists notes and filters them
///     by chapter or book, but never by their text.
///
/// Nothing here touches SharedPreferences or a provider. The store is
/// passed in as the two maps `MainProvider` already exposes.
library;

import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/models/verse.dart';

/// A stored note key (`Verse.id`) read back as a reference.
///
/// The key is `'EnglishBook-chapter-verseLabel'` and the book can itself
/// contain the separator, so this walks from the RIGHT. The label stays
/// a string: an edition may print `23a`, and turning that into an int
/// here would silently merge two different notes into one reference.
({String book, int chapter, String verseLabel}) parseVerseId(String id) {
  final lastDash = id.lastIndexOf('-');
  if (lastDash < 0) return (book: id, chapter: 0, verseLabel: '0');
  final verseLabel = id.substring(lastDash + 1);
  final rest = id.substring(0, lastDash);
  final chapDash = rest.lastIndexOf('-');
  if (chapDash < 0) return (book: rest, chapter: 0, verseLabel: verseLabel);
  final chapter = int.tryParse(rest.substring(chapDash + 1)) ?? 0;
  return (
    book: rest.substring(0, chapDash),
    chapter: chapter,
    verseLabel: verseLabel,
  );
}

const List<String> _kCanonicalOrder = [
  ...canonicalOtBooks,
  ...canonicalNtBooks,
];

final Map<String, int> _kBookIndex = {
  for (var i = 0; i < _kCanonicalOrder.length; i++) _kCanonicalOrder[i]: i,
};

/// Genesis→Revelation, then chapter, then verse. An unrecognised book
/// sorts to the end rather than to the front: a note whose edition is
/// not loaded is still the reader's note and must not be dropped, but it
/// has no place in the canon to claim.
int compareVerseIds(String a, String b) {
  final pa = parseVerseId(a);
  final pb = parseVerseId(b);
  final ba = _kBookIndex[pa.book] ?? _kCanonicalOrder.length;
  final bb = _kBookIndex[pb.book] ?? _kCanonicalOrder.length;
  if (ba != bb) return ba.compareTo(bb);
  if (pa.chapter != pb.chapter) return pa.chapter.compareTo(pb.chapter);
  final na = int.tryParse(pa.verseLabel);
  final nb = int.tryParse(pb.verseLabel);
  if (na != null && nb != null && na != nb) return na.compareTo(nb);
  return pa.verseLabel.compareTo(pb.verseLabel);
}

/// What an editor opened on a selection starts with.
class NotePrefill {
  const NotePrefill({this.body = '', this.title = '', this.sourceId});

  final String body;
  final String title;

  /// The `Verse.id` the body and title were read from, or null when the
  /// selection carries no note. Kept so a caller can tell "this note was
  /// already here" from "the reader is starting one" without comparing
  /// strings.
  final String? sourceId;

  bool get isEmpty => body.isEmpty && title.isEmpty;
}

/// The note a selection shows: the first selected verse that already has
/// a non-empty note, with the title from THAT SAME verse.
///
/// Both halves matter. A multi-verse passage note is stored as the same
/// body and title on every verse of the range (see
/// `MainProvider.setVerseNote`), so reading the title from anywhere else
/// would pair one note's body with another's heading. And a selection of
/// three verses where only the middle one is annotated must show that
/// note rather than an empty box, or the reader writes a second note on
/// top of a first they were never shown.
NotePrefill resolveNotePrefill(
  Iterable<Verse> verses, {
  required Map<String, String> notes,
  required Map<String, String> titles,
}) {
  for (final v in verses) {
    final body = notes[v.id];
    if (body != null && body.isNotEmpty) {
      return NotePrefill(
        body: body,
        title: titles[v.id] ?? '',
        sourceId: v.id,
      );
    }
  }
  return const NotePrefill();
}

/// What to call the verses a note is attached to: `Genesis 1:16`,
/// `Genesis 1:16-18`, or `Genesis 1:31 – Genesis 2:2` across a chapter
/// break.
///
/// Book names come from the verses themselves, so the label is in the
/// language of the edition being read — which is what the reader is
/// looking at. [verses] is expected in canonical order, as the reader's
/// selection already is.
String verseNoteRangeLabel(List<Verse> verses) {
  if (verses.isEmpty) return '';
  final first = verses.first;
  if (verses.length == 1) {
    return '${first.book} ${first.chapter}:${first.verseLabel}';
  }
  final last = verses.last;
  if (last.book == first.book && last.chapter == first.chapter) {
    return '${first.book} ${first.chapter}:'
        '${first.verseLabel}-${last.verseLabel}';
  }
  return '${first.book} ${first.chapter}:${first.verseLabel} – '
      '${last.book} ${last.chapter}:${last.verseLabel}';
}

/// One row of a note search: a stored note whose title or body contains
/// the query.
class NoteSearchHit {
  const NoteSearchHit({
    required this.id,
    required this.lastId,
    required this.title,
    required this.body,
    required this.snippet,
  });

  /// The head verse's key — where the reader is sent, and where the
  /// title lives for the whole range.
  final String id;

  /// The last verse of a passage note that runs over several verses,
  /// equal to [id] for a single-verse note. Together they are the range
  /// the hit stands for, so the result reads `Genesis 1:16-18` rather
  /// than printing the same note three times.
  final String lastId;

  final String title;
  final String body;

  /// A window of [body] around the match, so a long note does not have
  /// to be opened to see why it matched.
  final String snippet;
}

/// bwh15's "Searching User Notes", over the note store.
///
/// Case-insensitive substring, over the title and the body both — the
/// title is where a reader files a note under a theme, so a search that
/// ignored it would miss the notes that were deliberately labelled.
/// Chinese needs no folding and gets none; `toLowerCase` is a no-op on
/// it and the substring test is exact.
///
/// Contiguous verses carrying an IDENTICAL body are collapsed into one
/// hit, because that is how this store represents a passage note: the
/// same text written to every verse of the range. Without this a note on
/// Genesis 1:16-18 answers a search three times.
///
/// Results are canonical, not by relevance: a reader searching their own
/// notes is looking for a place in the Bible, and a ranked list of their
/// own prose has no scale on which to rank it.
List<NoteSearchHit> searchNotes(
  String query, {
  required Map<String, String> notes,
  required Map<String, String> titles,
  int snippetRadius = 40,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final ids = notes.keys.toList()..sort(compareVerseIds);
  final hits = <NoteSearchHit>[];
  for (final id in ids) {
    final body = notes[id] ?? '';
    final title = titles[id] ?? '';
    final at = body.toLowerCase().indexOf(needle);
    final inTitle = title.toLowerCase().contains(needle);
    if (at < 0 && !inTitle) continue;

    // Same body, same chapter, next verse: the tail of a passage note
    // already listed. Extend that hit instead of opening a new one.
    if (hits.isNotEmpty) {
      final last = hits.last;
      if (last.body == body && _isNextVerse(last.lastId, id)) {
        hits[hits.length - 1] = NoteSearchHit(
          id: last.id,
          lastId: id,
          title: last.title,
          body: last.body,
          snippet: last.snippet,
        );
        continue;
      }
    }

    hits.add(NoteSearchHit(
      id: id,
      lastId: id,
      title: title,
      body: body,
      snippet: at < 0
          ? _snippet(body, 0, needle.length, snippetRadius)
          : _snippet(body, at, needle.length, snippetRadius),
    ));
  }
  return hits;
}

/// Whether [next] is the verse immediately after [id] in the same
/// chapter of the same book. Non-numeric labels (`23a`) answer false,
/// which merely lists them separately.
bool _isNextVerse(String id, String next) {
  final a = parseVerseId(id);
  final b = parseVerseId(next);
  if (a.book != b.book || a.chapter != b.chapter) return false;
  final na = int.tryParse(a.verseLabel);
  final nb = int.tryParse(b.verseLabel);
  if (na == null || nb == null) return false;
  return nb == na + 1;
}

String _snippet(String body, int at, int length, int radius) {
  if (body.length <= radius * 2 + length) return body;
  final start = (at - radius).clamp(0, body.length);
  final end = (at + length + radius).clamp(0, body.length);
  final core = body.substring(start, end).replaceAll('\n', ' ');
  return '${start > 0 ? '…' : ''}$core${end < body.length ? '…' : ''}';
}
