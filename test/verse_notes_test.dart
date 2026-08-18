/// 2026-08-18: the User Notes tab (bwh15), and the rules it shares with
/// the modal editor.
///
/// This tab is the only one in the Analysis pane that WRITES, and what
/// it writes is the reader's own prose — the one thing in the app that
/// cannot be regenerated from an asset. `docs/PARITY-BACKLOG.md` §3.4
/// asked for it in those terms: "it touches user data, so it must not
/// lose a keystroke". So the tests below are mostly not about pixels.
/// They are about the four moments a keystroke can be lost — the
/// debounce, the selection moving, the pane being disposed, and a
/// passage note being written to the wrong subset of its range — plus
/// the search that had no implementation anywhere in the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/reader_analysis_request.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/utils/verse_notes.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/verse_notes_pane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const gen1 = Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'a');
  const gen2 = Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'b');
  const gen3 = Verse(book: 'Genesis', chapter: 1, verse: 3, text: 'c');

  group('which note a selection shows', () {
    test('the first annotated verse wins, with its OWN title', () {
      final p = resolveNotePrefill(
        const [gen1, gen2, gen3],
        notes: {'Genesis-1-2': 'the middle one', 'Genesis-1-3': 'and this'},
        titles: {'Genesis-1-2': 'second', 'Genesis-1-3': 'third'},
      );
      expect(p.body, 'the middle one');
      // Pairing a body with another verse's title is the drift this
      // guards: a passage note stores both on every verse, so reading
      // them from different verses can only ever be wrong.
      expect(p.title, 'second');
      expect(p.sourceId, 'Genesis-1-2');
    });

    test('an empty string is not a note', () {
      final p = resolveNotePrefill(
        const [gen1, gen2],
        notes: {'Genesis-1-1': '', 'Genesis-1-2': 'real'},
        titles: const {},
      );
      expect(p.body, 'real');
    });

    test('nothing annotated is an empty editor, not a null', () {
      final p = resolveNotePrefill(const [gen1],
          notes: const {}, titles: const {});
      expect(p.isEmpty, isTrue);
      expect(p.body, '');
      expect(p.sourceId, isNull);
    });
  });

  group('what the range is called', () {
    test('one verse, a range, and a chapter break', () {
      expect(verseNoteRangeLabel(const [gen1]), 'Genesis 1:1');
      expect(verseNoteRangeLabel(const [gen1, gen2, gen3]), 'Genesis 1:1-3');
      expect(
        verseNoteRangeLabel(const [
          Verse(book: 'Genesis', chapter: 1, verse: 31, text: ''),
          Verse(book: 'Genesis', chapter: 2, verse: 1, text: ''),
        ]),
        'Genesis 1:31 – Genesis 2:1',
      );
    });

    test('the label speaks the edition\'s language, not English', () {
      expect(
        verseNoteRangeLabel(const [
          Verse(book: '创世记', chapter: 1, verse: 1, text: ''),
        ]),
        '创世记 1:1',
      );
    });
  });

  group('reading a stored key back', () {
    test('a book with a space, and a label that is not a number', () {
      final p = parseVerseId('1 Samuel-17-4');
      expect(p.book, '1 Samuel');
      expect(p.chapter, 17);
      expect(p.verseLabel, '4');
      // Editions do print `23a`. Parsing it as an int here would merge
      // two different notes onto one reference.
      expect(parseVerseId('Romans-16-23a').verseLabel, '23a');
    });

    test('canonical order, with the unknown book at the end', () {
      final ids = [
        'Revelation-1-1',
        'Genesis-2-1',
        'Genesis-1-10',
        'Genesis-1-2',
        'Enoch-1-1',
      ]..sort(compareVerseIds);
      expect(ids, [
        'Genesis-1-2',
        // 10 after 2: string order would have put it before.
        'Genesis-1-10',
        'Genesis-2-1',
        'Revelation-1-1',
        // A note on an edition we have not loaded is still the
        // reader's note; it just has no place in the canon to claim.
        'Enoch-1-1',
      ]);
    });
  });

  group('searching notes (bwh15)', () {
    final notes = {
      'Genesis-1-1': 'on creation and the beginning',
      'Genesis-1-2': 'a passage note',
      'Genesis-1-3': 'a passage note',
      'Genesis-1-4': 'a passage note',
      'John-1-1': 'the Word, again on CREATION',
    };
    final titles = {'Genesis-1-2': 'Day one', 'John-1-1': 'Prologue'};

    test('an empty query asks for nothing and gets nothing', () {
      expect(searchNotes('  ', notes: notes, titles: titles), isEmpty);
    });

    test('matches either field, ignoring case, in canonical order', () {
      final hits = searchNotes('creation', notes: notes, titles: titles);
      expect(hits.map((h) => h.id), ['Genesis-1-1', 'John-1-1']);
      // The title is where a reader files a note under a theme, so a
      // search that read only the body would miss the notes that were
      // deliberately labelled.
      final byTitle = searchNotes('prologue', notes: notes, titles: titles);
      expect(byTitle.map((h) => h.id), ['John-1-1']);
    });

    test('a passage note answers once, as its range', () {
      final hits = searchNotes('passage', notes: notes, titles: titles);
      expect(hits.length, 1,
          reason: 'the same body on three contiguous verses IS one note');
      expect(hits.single.id, 'Genesis-1-2');
      expect(hits.single.lastId, 'Genesis-1-4');
      expect(hits.single.title, 'Day one');
    });

    test('the snippet carries the match, not the first line', () {
      final long = 'x' * 300;
      final hits = searchNotes(
        'needle',
        notes: {'Genesis-1-1': '$long needle $long'},
        titles: const {},
      );
      expect(hits.single.snippet, contains('needle'));
      expect(hits.single.snippet.length, lessThan(120));
    });
  });

  // ── The tab in the strip ──────────────────────────────────────────

  group('the tab', () {
    test('is appended, because the strip persists the INDEX', () {
      // `workbench.analysisTab` stores an int. Inserting `notes`
      // anywhere but the end moves every reader with a tab open to a
      // different one, silently.
      expect(AnalysisTab.values.last, AnalysisTab.notes);
      expect(AnalysisTab.values.length, 14);
    });

    test('the reader\'s note action routes here, both ways', () {
      expect(analysisTabForRequest(ReaderAnalysisRequest.notes),
          AnalysisTab.notes);
      expect(requestForAnalysisTab(AnalysisTab.notes),
          ReaderAnalysisRequest.notes);
    });

    test('the fourteenth tab does not cost the strip its labels', () {
      // #297's arithmetic. Two rows of seven is what 14 tabs make, and
      // it is exactly what 13 already made — so no width at which the
      // labels fit before this change stops fitting after it.
      const width = 420.0;
      final before = analysisStripLayout(width, 13, minLabelledTabWidth: 58);
      final after = analysisStripLayout(width, 14, minLabelledTabWidth: 58);
      expect(after.perRow, before.perRow);
      expect(after.showLabels, before.showLabels);
      expect(after.perRow, 7);
    });

    test('its label is narrower than the widest the strip already had',
        () {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final labels = analysisTabLabels(locale);
        final withNotes = analysisStripMinLabelledWidth(labels);
        final without = analysisStripMinLabelledWidth(
            labels.where((l) => l != labels.last));
        expect(withNotes, without,
            reason: 'the Notes label ($locale: ${labels.last}) widened the '
                'strip, which would ellipsise every other label');
      }
    });
  });

  // ── The pane: the four ways a keystroke can be lost ───────────────

  /// A stand-in for `MainProvider`: the pane is handed the store as two
  /// maps and hands edits back through callbacks, so the whole autosave
  /// state machine can be driven without SharedPreferences.
  Widget harness(_Store store) => MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => AppSettings())],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 380,
              height: 600,
              child: AnimatedBuilder(
                animation: store,
                builder: (context, _) => VerseNotesPane(
                  verses: store.selection,
                  notes: store.notes,
                  titles: store.titles,
                  locale: 'en',
                  onSave: store.save,
                  onDelete: store.delete,
                  onOpenNote: (id) => store.opened.add(id),
                ),
              ),
            ),
          ),
        ),
      );

  Finder bodyField() => find.byType(TextField).at(1);

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('autoloads the focused verse\'s note — no Load button',
      (tester) async {
    final store = _Store(
      selection: const [gen1],
      notes: {'Genesis-1-1': 'already written'},
      titles: {'Genesis-1-1': 'a heading'},
    );
    await tester.pumpWidget(harness(store));
    await tester.pump();
    expect(find.text('already written'), findsOneWidget);
    expect(find.text('a heading'), findsOneWidget);
    // bwh15's own words: the location the note goes to is printed above
    // the editor "so you always know where notes go".
    expect(find.text('Genesis 1:1'), findsOneWidget);
  });

  testWidgets('typing writes itself, with no Save button to press',
      (tester) async {
    final store = _Store(selection: const [gen1]);
    await tester.pumpWidget(harness(store));
    await tester.enterText(bodyField(), 'a thought');
    await tester.pump();
    expect(store.notes['Genesis-1-1'], isNull,
        reason: 'a write per keystroke would rewrite the whole store and '
            'make the note timestamp meaningless');
    await tester.pump(kNoteAutosaveDelay + const Duration(milliseconds: 50));
    expect(store.notes['Genesis-1-1'], 'a thought');
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('moving the selection flushes to the OLD verse first',
      (tester) async {
    final store = _Store(selection: const [gen1], notes: {'Genesis-1-2': 'two'});
    await tester.pumpWidget(harness(store));
    await tester.enterText(bodyField(), 'one');
    await tester.pump();
    // Straight to the next verse, inside the debounce window — the
    // exact moment bwh15's "saved when the verse changes" exists for.
    store.select(const [gen2]);
    await tester.pump();
    expect(store.notes['Genesis-1-1'], 'one',
        reason: 'the outgoing note must be written before it is replaced');
    expect(find.text('two'), findsOneWidget,
        reason: 'and the incoming one must be loaded');
    await tester.pump(kNoteAutosaveDelay);
  });

  testWidgets('leaving the tab flushes what was typed', (tester) async {
    final store = _Store(selection: const [gen1]);
    await tester.pumpWidget(harness(store));
    await tester.enterText(bodyField(), 'unsaved when it unmounts');
    await tester.pump();
    // The reader taps another tab: the pane is disposed mid-debounce.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(store.notes['Genesis-1-1'], 'unsaved when it unmounts');
  });

  testWidgets('a passage note is written to every verse of the range',
      (tester) async {
    final store = _Store(selection: const [gen1, gen2, gen3]);
    await tester.pumpWidget(harness(store));
    // The header has to SAY this, or a note lands on two verses the
    // reader did not know were selected.
    expect(find.text('Genesis 1:1-3'), findsOneWidget);
    expect(find.textContaining('all 3 selected verses'), findsOneWidget);
    await tester.enterText(bodyField(), 'on the whole passage');
    await tester.pump(kNoteAutosaveDelay + const Duration(milliseconds: 50));
    expect(store.notes['Genesis-1-1'], 'on the whole passage');
    expect(store.notes['Genesis-1-2'], 'on the whole passage');
    expect(store.notes['Genesis-1-3'], 'on the whole passage');
  });

  testWidgets('delete clears the whole range, and only offers itself '
      'when there is something saved', (tester) async {
    final store = _Store(selection: const [gen1, gen2]);
    await tester.pumpWidget(harness(store));
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    store.save(const [gen1, gen2], 'written', '');
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(store.notes, isEmpty);
  });

  testWidgets('search finds a note by its text and hands back the editor',
      (tester) async {
    final store = _Store(
      selection: const [gen1],
      notes: {
        'Genesis-1-1': 'here',
        'John-3-16': 'so loved the world',
      },
    );
    await tester.pumpWidget(harness(store));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'loved');
    await tester.pump();
    expect(find.text('John 3:16'), findsOneWidget);
    expect(find.textContaining('1 found'), findsOneWidget);

    await tester.tap(find.text('John 3:16'));
    await tester.pump();
    expect(store.opened, ['John-3-16']);
    // "Click to load": the result list exists to get back into a note.
    expect(find.byType(TextField), findsNWidgets(2));
  });
}

/// The note store, as much of it as the pane can see.
class _Store extends ChangeNotifier {
  _Store({
    required this.selection,
    Map<String, String>? notes,
    Map<String, String>? titles,
  })  : notes = notes ?? {},
        titles = titles ?? {};

  List<Verse> selection;
  final Map<String, String> notes;
  final Map<String, String> titles;
  final List<String> opened = [];

  void select(List<Verse> verses) {
    selection = verses;
    notifyListeners();
  }

  /// `MainProvider.setVerseNote`'s contract: an empty body removes the
  /// note, its title and its timestamp together.
  void save(List<Verse> verses, String body, String title) {
    for (final v in verses) {
      if (body.trim().isEmpty) {
        notes.remove(v.id);
        titles.remove(v.id);
      } else {
        notes[v.id] = body.trim();
        if (title.trim().isEmpty) {
          titles.remove(v.id);
        } else {
          titles[v.id] = title.trim();
        }
      }
    }
    notifyListeners();
  }

  void delete(List<Verse> verses) {
    for (final v in verses) {
      notes.remove(v.id);
      titles.remove(v.id);
    }
    notifyListeners();
  }
}
