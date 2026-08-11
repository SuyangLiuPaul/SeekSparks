# Product audit — what each screen is FOR

Task #281, first pass. 2026-08-08, against v1.6.51.

SeekSparks was forked from YsWords, a devotional consumer Bible app, and
inherited its feature set while trying to become a desktop exegesis
workbench. This document asks of each screen: **who opens this in a
BibleWorks-class tool, and why?** — then: does it earn its maintenance
cost, and should it be cut, merged, or kept and improved.

Deletions actually made in this pass, and the items held back for a
human, are in `DELETION-REVIEW.md`. This file is the reasoning.

---

## 1. The test this audit uses, and why it is not "is it devotional?"

The obvious frame — *YsWords inheritance is cruft, BibleWorks features
are real* — is wrong, and the help file says so plainly. BibleWorks 10
ships a **Timeline** (bwh39), **Maps** (bwh33), **vocabulary flashcards**
(bwh40), and **Bagster's Daily Light** (bwh52), *a daily devotional*. A
serious exegesis tool shipped a devotional for twenty years. So
"devotional" cannot be the thing that disqualifies a screen.

What those modules have in common is more specific, and it is the actual
test. Read what BibleWorks says each one does:

- Timeline: *"Jump directly from an event on the timeline to a BibleWorks
  Bible reference or dictionary entry."*
- Daily Light: *"Selecting Export exports to the Search Window the list
  of verses contained in the displayed devotional."*
- bwh03, on the program as a whole: *"Everything is heavily cross-linked
  and cross-referenced."*

Every module in BibleWorks is a **lens on the text**, and every module
**round-trips to the text** — you arrive holding a verse reference, or
you leave holding one. Nothing is a terminal destination.

> **The test.** Does this screen take you to the text, or bring you back
> from it with something in hand? A screen you enter, look at, and leave
> empty-handed has not earned a place in a workbench, however good it is.

This test is worth stating because it produces *different* answers from
taste. It acquits the Timeline and the Trivia catalogue, which a naive
"consumer app leftover" read would cut. It convicts nothing on the
grounds of being pleasant or popular. And it puts the real question where
it belongs: not "is this feature serious?" but "is this feature
connected?"

Two corrections this pass had to make to its own first guesses, both
found by reading the code rather than the file name:

- **`stats_page` is not engagement metrics.** `grep -c "streak\|daysRead"`
  returns 0. It computes top-lemma frequency tables, per-book originals
  distribution, hapax legomena and Strong's lookup off
  `assets/strongs/concordance.json`. That is bwh23 *Search Statistics*
  and bwh26 *Word List Manager* territory — one of the most
  BibleWorks-like things in the app, wearing the name most likely to get
  it cut.
- **`bible_trivia_page` is not a quiz.** It is 68 curated entries on
  textual structure — acrostics, the Tetragrammaton, chapter and verse
  counts, numeric patterns — with four purpose-built diagram renderers.
  Its own doc says *"patterns and hidden structures most readers don't
  notice."* There is no scoring, no timer and no game. The nearest
  BibleWorks analogue is a study guide (bwh06b), not entertainment.

---

## 2. The headline finding: the identity decision was already made, and
##    then not finished

`main.dart` makes `SmallScreenGate(WorkbenchPage)` the app root. The
comment there is explicit about why: *"SeekSparks is a Bible STUDY tool,
not a devotional…"*. That was the right call and it is done.

What was never done is the clean-up behind it. **`DashboardPage` is
referenced by nothing outside itself.** It was the front door; the front
door moved; nobody told the Dashboard. And because the Dashboard was the
only way in to two other pages, they went dark with it:

| Page | Lines | Sole entry point |
|---|---:|---|
| `dashboard_page.dart` | 1,420 | *(none — was the app root)* |
| `family_tree_page.dart` | 2,620 | Dashboard quick-links |
| `feedback_page.dart` | 468 | Dashboard quick-links |
| **Total** | **4,508** | |

Proof is an import-graph walk from `lib/main.dart`; it is now enforced by
`test/page_reachability_test.dart`, so this class of silent orphaning
cannot recur unnoticed. 1,628 tests passed with 4,508 lines unreachable,
because every test that touches those pages constructs them directly —
which is exactly why the invariant had to be written down as a test
rather than as a paragraph.

Three consequences worth naming:

1. **This is one decision, not three.** "Does SeekSparks have a home
   screen?" governs all of it, plus a whole Settings section
   (`_DashboardSectionsCard` — reorder and toggle seven Dashboard
   sections, a live control panel for a page nobody can reach), the
   `DashboardSection` model, and the AppSettings visibility map. Roughly
   6,000 lines hang off one answer.
2. **Nobody has missed them.** No bug report, no handoff entry. That is
   evidence about their value, though not proof.
3. **The audit's job here is to force the question, not to answer it.**
   Whole pages are product decisions. All three are on the review list.

---

## 3. Per-screen verdicts

Sizes are lines of Dart at v1.6.51. "Round trip" is the test from §1.

### Keep and improve — these are the workbench

| Screen | Lines | Round trip | Verdict |
|---|---:|---|---|
| `workbench_page` | 2,268 | — | The app. |
| `search_page` | 2,877 | yes | **Merge candidate.** See §4. |
| `stats_page` | 4,529 → 3,845 | yes | Genuine concordance analysis. **Wants to be Analysis tabs, not a page** — see §4. 684 lines of dead tabs removed this pass. |
| `strongs_entry_page` | 547 | yes | The lexicon browser (bwh35). Core. |
| `word_list_page` | 250 | yes | bwh26. Core. |
| `phrasing_page` | 559 | yes | Ships in place of bwh25's diagrammer. Core. |
| `library_page` | 881 | yes | Notes and bookmarks (bwh13/bwh15). **Holds user data.** Core. |
| `books_page` | 89 | yes | Navigation primitive. |
| `map_viewer_page` | 387 | yes | **Possible duplicate** — see §4. |

### Keep — earns its place, but not on the critical path

| Screen | Lines | Round trip | Verdict |
|---|---:|---|---|
| `bible_timeline_page` | 599 | yes | BibleWorks ships one (bwh39). Round-trips via `resolveAndPrepareJump`. Keep. |
| `bible_trivia_page` | 3,254 | yes | 68 curated structural observations, each jumping to its reference. Not a game. Keep; the *name* is the liability, not the content. |
| `evidence_page` + `_detail` | 2,274 | yes | 225 archaeological/manuscript findings, filterable by the chapter you are reading. No BibleWorks analogue, and that is an argument *for* it. Keep. |
| `sermons_page` + `_detail` | 1,664 | yes | Carries `refs.json`, a reverse index from verse → sermon. That makes it a **commentary index** (bwh49/bwh36 territory), not a media library. Keep. |
| `about_page` | 746 | no | Fails the round-trip test and is kept anyway: CC-BY-NC-SA (CBOL), BSB, LEB and NASB attribution is a **licence obligation**. Not optional. |
| `loading_page` | 1,022 | n/a | Not a splash — a boot error-recovery state machine (bounded retry, 15 s patience escalation, 25 s web Service-Worker hard reload). Length is mostly incident narrative in comments. Keep. |
| `settings_page` | 4,286 | no | bwh29 exists. Keep the screen; see §4 for the size. |

### Review — unreachable, or duplicated (see `DELETION-REVIEW.md`)

| Screen | Lines | Status |
|---|---:|---|
| `dashboard_page` | 1,420 | Unreachable. Product decision. |
| `family_tree_page` | 2,620 | Unreachable via Dashboard only. Genuinely good content (8 eras, a 6-source Adam→Jesus comparison table) with no door. |
| `feedback_page` | 468 | Unreachable. Duplicates the contact route in `about_page`. |
| `profiles_page` + `profile_edit_page` | 596 | Reachable (Settings → Profiles) and working. Flagged only because per-device profiles with avatars are a consumer-app shape; a workbench usually has one user and many *workspaces*. Not a cleanup item. |

---

## 4. The real finding under "redundant": pages that should be panes

The user's report was that screens are *redundant*. Sharpened, the
problem is mostly **modality**, not duplication — and it is the same
defect #276 fixed for the Reader and #284 will fix for 原文逐字.

A workbench's value is that its surfaces are *simultaneous*. The
concordance is worth having open **while** you read; a search result is
worth seeing **beside** the verse it came from. Every one of these is
currently a full-screen push that destroys the workbench to show you
something about the workbench:

- **`stats_page` (3,845 lines).** Word Distribution — occurrences of a
  lemma per book — is precisely what you want next to a KWIC list, and
  you cannot have both. Its three tabs map cleanly onto Analysis tabs.
  This is the strongest candidate in the app for pane-ification.
- **`search_page` (2,877 lines).** The Workbench has a search pane with
  its own command line, and `search_page` is a second, *different* search
  UI with AI mode, recent searches, and a scope banner. Two
  implementations of "search" will drift — and per #280 they already
  have: the scope banner lives here, while the Workbench pane has no
  scope at all. **Merging these is a precondition for #280**, not a
  follow-up to it.
- **`map_viewer_page` (387 lines)** versus the Places tab shipped in
  #277 (v1.6.51). Two map surfaces. Probably one should go; deciding
  which needs the Places tab to have been used in anger first.

**Recommended order**, and the reasoning: `search_page` first, because
#280 is blocked behind it and a scope model built twice is worse than one
built late; then `stats_page` → Analysis tabs, coordinated with #277/#284
since all three want tab strip room the strip does not have; then the map
duplication once Places has been lived with.

### `settings_page`: 4,286 lines is a symptom, not the disease

Eight sections, ~40 controls. It is not padded — it is doing real work
(account and cloud sync, an eight-control display group with a live
preview, notification categories, the Gemini key, export/import). The
count is downstream of `AppSettings` having accumulated a preference for
every past disagreement. Three specific observations:

1. One whole section configures an unreachable page (§2).
2. This pass found three preferences with **no reader at all** — a
   toggle whose only effect was to be remembered. Those are gone.
3. The honest fix is not to reformat this page but to ask, per
   preference, *what breaks if this is a constant?* That is its own
   iteration and it should follow the Dashboard decision, because that
   decision alone removes a section.

---

## 5. What was actually done in this pass

Deletions, all grep-proven unreachable and none user-visible — details
and proofs in `DELETION-REVIEW.md`:

| What | Lines |
|---|---:|
| `stats_page` dead tabs (`_OverviewTab`, `_BooksTab`, `_VocabularyTab`, helpers, `_copyAllStats`) — marked *"safe to remove in a future cleanup pass"* since Round 56 | 684 |
| `lib/widgets/parallel_verse_view.dart` — superseded by `browse_window.dart` | 500 |
| `lib/services/bible_stats_service.dart` — orphaned with the tabs above | 207 |
| `lib/constants/ui_strings.dart` — 28 keys for reading plans (removed v1.2.69) and dead toggles | 139 |
| `lib/models/app_settings.dart` — `pickVerseAfterChapter` end to end, plus two dead accessors | 38 |
| `lib/utils/version_colors.dart` — died with `parallel_verse_view`; its guarantee is preserved by `kVersionTagColors` | 107 |
| `lib/utils/greeting.dart` + its test — no production caller | 39 |
| `pubspec.yaml` — `path_provider`, `crypto` (TTS audio cache, removed v1.3.19) | — |
| **Total** | **~1,714** |

Added: `test/page_reachability_test.dart`, which fails if any page under
`lib/pages/` becomes unreachable from `main.dart` without being recorded
as a deliberate orphan. Its allow-list is the review list made
executable, and shrinking it to empty is the goal.

## 6. Open questions for a human

1. **Does SeekSparks have a home screen?** Governs ~6,000 lines (§2).
   Nothing else in this audit is blocked on it except #279's chrome pass,
   which should not restyle a page that is about to go.
2. **Should `search_page` and the Workbench search pane be one thing?**
   #280 is waiting on the answer (§4).
3. **The bundled NASB licence** — task #278, in `DELETION-REVIEW.md`.
   Unchanged and still shipping; a human decision, not a cleanup.

---

## 7. The modal sweep (#313, item 6) — a verdict per call site

The user's instruction was 「很多你帮我翻一翻都是的」 — the reader's modal
sheets are a *pattern*, not three bugs. This section is that sweep: every
`showModalBottomSheet`, `showDialog` and `pushPage` under `lib/`,
classified by the rule v1.6.108 wrote into
`lib/models/reader_analysis_request.dart`:

> **In the workbench a modal is for a DECISION** — pick a colour, name a
> list, confirm a delete. **Content that has a pane goes to the pane.**
> Content with no pane is a deliberate choice either way, and the choice
> must be written down.

Counted 2026-08-11 at `71931bb`: **46 sheets/dialogs and 43 `pushPage`
calls.** The headline is that the sweep found **far fewer offenders than
the brief assumed**, and the two it did find are not the ones named.

### 7.1 The brief's own two examples do not survive contact

**`verse_list_pane.dart`'s 3 dialogs are not duplicates.** The brief
lists them as "↔ Analysis 经文列表". They *are* the Analysis 经文列表 —
`workbench_page.dart:2139` mounts `VerseListPane` as
`AnalysisTab.verseLists`. The three dialogs are `_promptImportText`
(paste references), `_promptSaveAs` (name a list) and `_pickSavedName`
(choose which list to open). Every one is a DECISION with a typed return
(`bool`, `String?`). **Verdict: keep, all three, unchanged.** They were
filed as duplicates because a count was read as a diagnosis.

**`stats_page.dart`'s 9 sheets are the wrong unit of analysis.** They
break down as 4 pickers returning a value (`pickAndStudy`,
`_openVersePicker`, `_openPicker`, and the book filter) — decisions — and
5 content sheets (`_openBookSheet`, `_openAramaicSheet`,
`_openOriginalsSheetFor`, and two `_resolveAndOpen` results). Rewriting
those 5 would be wasted work, because **the page itself is the
duplicate**: `grep` finds exactly one construction site for `StatsPage`
in the whole app — `bible_reading_pane.dart:6970`, the reader's own
overflow menu — while the workbench answers the same question in
`AnalysisTab.stats`. **Verdict: the duplication is at page level. Retire
the entry point, not the sheets.** Deferred deliberately: `stats_page` is
4,529 lines and is still the only surface for the Aramaic sheet and the
lemma picker, so deleting the entry point before those have a home would
remove working features. Recorded here rather than done blind.

### 7.2 Decisions — correct as modals, no work needed (32 sites)

`settings_page` ×5 (tour, reset, clear cache, export, import) ·
`profiles_page` ×3 (rename ×2, delete confirm) · `verse_list_pane` ×3
(above) · `version_picker_sheet`, `version_stack_sheet` ×2,
`search_scope_sheet`, `note_reference_picker_sheet`, `copy_center_sheet`,
`update_check_tile` · reader `_showFontSizeSheet`, `_showColorPicker`,
`showNoteEditor`, `_showMapPicker` · `stats_page` ×4 pickers ·
`bible_trivia_page` ×2 · `phrasing_page` (source picker) ·
`highlights_page` `_showActions` · `build_verse_content_spans` ×2.
Each returns a value or edits one; none of them shows content a pane
holds.

### 7.3 Content with a pane — the real offenders (2 sites, both in the reader)

Both already have the wire built; neither is connected to it.

| Site | Duplicates | Verdict |
|---|---|---|
| `bible_reading_pane.dart:7450` `_showSynopsisSheet` | nothing exactly — the OT/NT synopsis has no tab, but `AnalysisTab.crossRefs` and `.related` are its neighbours | needs a decision, see 7.4 |
| `bible_reading_pane.dart:3955` `_showChapterSermonsSheet` | `_showRelatedSermonsSheet`, which v1.6.108 routed through `ReaderAnalysisRequest.sermons` | **route it the same way** — it is the chapter-scoped sibling of a request that already exists |

`_showOriginalsSheet` and `_showCrossRefsSheet` were the other two and
are **already routed** (v1.6.108); they now open a sheet only when no
host claims the request, which on web is only below the 992 px gate.

### 7.4 Content with no pane — decided, and written down

* **`_showHighlightsSheet` (5199)** — the reader's highlights browser.
  Stays a sheet. It is a *navigator*: you open it to jump somewhere, and
  it closes when you do. A docked pane promises to follow the selection,
  and this does the opposite — it changes the selection.
* **`_showSynopsisSheet` (7450)** — stays a sheet **for now**, and the
  reason is #292: the Kings/Chronicles parallel is about to acquire a
  Resource of its own, and giving it a 13th Analysis tab first would
  build the wrong home. Re-decide when #292 lands.
* **`originals_sheet.dart:2513` `_showDistributionTable`** — a sheet
  opened *from* a sheet. It draws #290's word distribution, which the
  Stats tab also draws. Not double-counted here as an offender because
  `originals_sheet` is itself the narrow-width fallback; but if #313's
  step 2 ever retires that sheet outright, this goes with it.
* **`verse_popup_sheet`, `atlas_page`, `family_tree_page`,
  `hebrew_kings_page`, `sermons_page` detail sheets** — all inside
  standalone Resources that own their whole window. There is no pane
  beside them to lose, so a sheet is the correct surface, not an
  inherited one.

### 7.5 `pushPage` — 43 sites, and only one class matters

21 are in `workbench_page` itself (shell navigation: Settings, About,
each Resource). Those are correct by construction — opening a Resource
from the workbench **is** the BibleWorks shape. 13 are in the reader,
and those are the ones to watch: they are how a phone-first reader
reaches a full page for something the workbench would dock. The
`StatsPage` push at 6970 is the clearest example and is recorded in 7.1.
The rest (`strongs_entry_page` ×3, `evidence_page` ×3, `open_reader` ×2,
`command_pane` ×2, and seven singletons) open a *different subject*, not
a bigger view of the same one, so they are navigation and not
duplication.

### 7.6 What this sweep changes

Small, and that is the finding. One routing fix (7.3), one entry point to
retire once its orphans have a home (7.1), and **32 modals confirmed
correct** — which is worth as much as a fix, because it means the next
iteration does not re-open them. The inherited-phone-app problem is real
but it is concentrated in `bible_reading_pane.dart` and `stats_page.dart`,
not spread across the app.
