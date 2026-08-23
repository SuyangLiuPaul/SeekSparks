# PARITY-BACKLOG

What SeekSparks still owes each of the four sources it draws on, and what
it has decided *not* to owe them.

This document exists because the priority queue in the loop prompt is
nearly empty, and when it empties the prompt says "resume ordinary
BibleWorks-parity work" — i.e. an iteration starts choosing its own
subject. For a week that is fine. Over a year it drifts, and drift is
expensive here because **every iteration ships**. This is the thing to
read instead of guessing.

Created 2026-08-12 (#302). Written from the code and the data, not from
memory; where a claim could not be verified it says so.

---

## 1. How to use this

**Pick one entry. Finish it. Ship it.** The entries are sized so that a
`PARTIAL` is usually one iteration and an `ABSENT` is usually two or
three, split at the seams the entry names.

**Before starting anything here, grep the code for it.** This document
will rot; the code will not. Twice already an item has been worked that
was silently already done (`#275` and `#287` were both complete with zero
HANDOFF mentions), and this run found a third and fourth — see §5, where
an item budgeted at "several iterations" turned out to be finished.
Budget one minute for the grep. It has saved whole iterations.

**Accuracy outranks everything in here.** The owner has said it twice:
「accuracy is the most critical and important thing」. If while working an
entry you find the app *stating something untrue about the text* — a
wrong transliteration, lemma, count, reference, date or parsing code —
that jumps the queue, no matter which entry you were on. Then ask "how
many more of these are there?" and measure it across the corpus before
reporting. `#303` looked like one bad row and was 8,030 of them.
`docs/DATA-INTEGRITY.md` is the register for that class and has its own
ranked list; it takes precedence over this file.

**When you finish an entry, edit it here** — change the verdict, and say
what is now true. An entry that says `ABSENT` about something that ships
is worse than no entry.

---

## 2. Verdict vocabulary

| Verdict | Means |
|---|---|
| **HAVE** | Ships, reachable from the UI, does the job the source does. |
| **PARTIAL** | A usable slice ships. The entry names exactly what is missing. |
| **ABSENT** | Nothing ships. |
| **REJECTED** | Deliberately not built. The reason is recorded. Re-open only with *new information*, not with a fresh opinion. |
| **BLOCKED** | Needs a human decision or an input we do not have. Never pick one of these as an iteration's item. |

`REJECTED` carries as much weight as the rest. The Graphical Search
Engine may genuinely not be worth rebuilding, and saying so once beats
re-litigating it every run.

---

## 3. Source 1 — BibleWorks 10

The help is extracted at
`~/Library/Application Support/seeksparks-loop/bibleworks-help/`
(583 files). **Do not mount the ISO.** `bwh00_Contents.htm` is the
feature inventory this section was walked from; grep the directory for
the topic before building anything, because guessing a feature from its
name is how you build the wrong one — `NEAR5` vs BibleWorks' directional
`*n` (bwh17) is the standing example.

Windows-implementation topics in that contents list are out of scope by
construction and are not enumerated below: font remapping, DDE/OLE
automation, keyboard driver installation, network installation, the
Configuration Manager, Cyrillic/Eastern-European font support.

### 3.1 Command line and search

The parser is `lib/utils/command_query.dart` (queries),
`lib/utils/command_verb.dart` (verbs, enum at :218),
`lib/utils/strongs_boolean_search.dart`, `lib/utils/phrase_match.dart`.
`command_verb.dart:55-79` already documents what it deliberately does not
implement and why — that comment block is the model for how this whole
file should read.

- **AND / OR / phrase / linear phrase (`.` `/` `'` `;`)** — **HAVE.**
  bwh16. All four control characters parse, including the Chinese
  one-token-per-Han-character rule.
- **Wildcards `*` `?`, bracket sets `[abc]` `{abc}`** — **HAVE.** bwh16.
- **Word gaps inside phrases (`*`, `*3`)** — **HAVE**, and note this is
  *our* spelling of BibleWorks' proximity. See NEAR below.
- **NOT (`!`)** — **PARTIAL.** Works in AND/OR. bwh16 also documents
  "Using the NOT Operator with Phrase Searches"; ours does not accept it
  inside a phrase. *Done:* `'!the god` slot exclusion parses and is
  covered by a test.
- **Verse context limits for AND (`;10`)** — **HAVE.** bwh16.
- **Proximity** — **PARTIAL, and divergent by choice.** We spell it
  `G25 NEAR5 G26`, unordered. BibleWorks writes `*n` *between* the words
  and it is **directional** — "followed within 9 words"
  (bwh17, bwh20 `('faith *4 love)`). #294 landed the teaching pass
  (operators dim until the line holds a number, hint row, tooltips).
  *Done:* decide deliberately whether to accept `*n` as a parity alias —
  which collides with our wildcard `*` and needs resolving — or to keep
  `NEARn` and **say in the help that we differ**. Directionality is the
  substantive gap, not the spelling: an unordered answer to a directional
  question is a different result set.
- **Regular expressions (`~`)** — **REJECTED**, reason at
  `command_query.dart:67`: user-supplied regex over 31k verses is a
  denial-of-service waiting to happen, and BibleWorks itself calls the
  feature expert-only. The parser detects and *names* it rather than
  failing silently (`:446`). Do not re-open without a plan for the
  runaway-backtrack case.
- **Compound searches with parentheses** — **DONE 2026-08-19**,
  `lib/utils/compound_query.dart`. bwh16 "Doing Compound Searches".
  **This entry described the wrong feature** and the correction is worth
  keeping: it read compound search as boolean *grouping* (`G25 AND G26 OR
  G27`). It is not. Each `( )` is a whole sub-search with its own control
  character and its own `;N`; the separator (`.` `/` `!`) carries a verse
  distance of its own, so `.15` is a proximity JOIN between two result
  sets rather than an intersection; and the LAST group decides which
  verses are listed. Measured on the KJV, the distance is worth 24 → 159
  verses and the group order is worth 159 vs 82 — see research-notes
  2026-08-19. Shipped with the `?` card example, the echo (including an
  "applied left to right" note, since there is no precedence), and
  per-group counts so an empty half can be named.
  *Still open, and genuinely separate:* **grouping inside a Strong's
  expression** (`G25 AND (G26 OR G27)`) in `strongs_boolean_search.dart`,
  and **a Strong's expression as a compound group** — the two engines
  return different types (corpus indices vs concordance refs, one async),
  so joining them needs a reference→index map and a decision about what a
  proximity join means across a tagged layer. The compound parser refuses
  it by name (`CommandIssue.compoundGroupOperator`) rather than guessing.
- **A plain search matches across word boundaries** — **DEFECT, found
  2026-08-19, not yet fixed.** A query with no control character is a
  substring match over the *space-stripped* verse key, so in the KJV
  `forth` lists the **2,542** verses that say "for the", `asa` the
  **1,094** that say "as a", `end` matches "seven days", `oar` matches
  "also a righteous", `heirs` matches "their shoulders". Nothing in
  those rows is markable, so the reader is shown a verse with no visible
  hit. Measured on a 502-word sample of the KJV's 12,546 distinct words
  (every 25th, sorted): **89** produce at least one boundary-spanning
  row. A further 116 are inflated only by matching *inside* one word
  (`walk` → "walked"), which is a different thing and arguably wanted.
  Not fixed on discovery because the substring rule is load-bearing for
  Chinese, which has no spaces to strip — the fix is per-script, not
  global, and it changes result counts for every existing English query.
  *Done:* decide it — word-aware plain search for space-separated
  scripts, or an honest note in the help. Do not "fix" it by stripping
  spaces differently; that is the same bug with new numbers. This is
  also why the romanised-input offer (§3.7) gates on the word-aware
  engine and not on an empty result list.
- **Cross-version searches** — **ABSENT.** bwh16. "Find verses where the
  KJV says X and the LXX says Y." We have every version loaded and a
  parallel view; nothing can query across two at once. *Done:* one
  operator that takes a version tag per term, results listed once per
  verse with both hits shown.
- **Morphological searches (Greek/Hebrew)** — **PARTIAL.**
  `lib/services/morph_search_service.dart` + `lib/widgets/morph_search_pane.dart`
  exist and the Forms tab surfaces them. bwh17 goes considerably further:
  **morphological agreement**, **lemma agreement**, and **context
  dependency** — "an adjective agreeing in case, number and gender with
  the noun two words back" is the class of query BibleWorks is famous for
  and we cannot express it at all. *Done:* an agreement operator, or an
  explicit `REJECTED` saying the GSE-class query is out of scope (see
  3.2) — but decide it, do not leave it accidental.
- **Accents and vowel points in search** — **PARTIAL.** Hebrew points are
  stripped when the query contains Hebrew; Greek accents are not
  stripped. bwh17 makes both a **setting** ("Including Vowel Points in
  Hebrew Searches and Accents in Greek"). Ours is a hardcoded asymmetry.
  *Done:* one setting, honestly labelled, applied to both languages.
- **Qere / Kethib** — **ABSENT.** bwh17 has Qere/Kethib search codes and
  the status bar carries a Qere/Kethib display setting. Grepping `lib/`
  for `Qere|Kethib|Ketiv` returns **nothing**. We do hold the data —
  v1.6.92 recovered 1,235 Hebrew words from the OSHB Qere nesting — so
  this is a surfacing job, not a data job. `docs/DATA-INTEGRITY.md`'s
  open item 2 (four verses printing both forms) is the same seam.
  *Done:* a reader-side setting for which form is shown, and the pair
  visible on demand.
- **Search limits (`l gen`)** — **HAVE**, extended past bwh16 by #280's
  scope model (books, groups, 希伯来圣经/希腊圣经). `l` stops at chapter
  granularity on purpose (`command_verb.dart:71-79`): verse-granular
  scoping is the Verse List Manager's job.
- **Command Line Assistant / Morphology Assistant** — **PARTIAL.** bwh16
  and bwh17 both ship a guided builder that constructs a query for a
  reader who does not know the syntax. #294 and #299 gave us the
  operator strip, per-button tooltips, a context-sensitive hint row and
  a tappable example card — which is most of the *teaching* but none of
  the *building*. *Done:* a picker that assembles a morphology query from
  parts of speech and features without the reader typing a code.
- **Semantic domains (Louw-Nida)** — **ABSENT.** bwh26 loads them in both
  the GSE and the Word List Manager. Grep returns nothing.
  **Licence-gated:** Louw-Nida is UBS copyright. Do not import. Record as
  `REJECTED` unless an openly-licensed domain set turns up.

### 3.2 The Graphical Search Engine — REJECTED, provisionally

bwh18/19/21/22 — four whole help chapters, a visual query builder with
word boxes, merge boxes, ordering/proximity boxes and five kinds of
agreement window. It is BibleWorks' deepest feature and its most-cited
one in reviews.

**Rejected for now, and the reason is honest:** the GSE is a UI for
expressing queries the *engine underneath* can answer. Our engine cannot
answer agreement or context-dependency queries at all (3.1), so building
the GSE first would be building a steering wheel for an engine that does
not turn. The order is engine, then builder.

Re-open when 3.1's agreement work lands. If it never lands, this stays
rejected and that is a defensible product position — most Logos and
Accordance users never touch their equivalents either.

### 3.3 Browse window and version display

- **Parallel versions** — **HAVE.** Browse mode, `d`/`p` verbs, per-line
  version tags.
- **Version display order** — **HAVE** (#288 shipped reorder + confirm).
- **Parallel Versions favourites** — **REJECTED**, reason at
  `command_verb.dart:56-62`: there is no UI to create a named set, and a
  verb that can only fail is worse than no verb; it also removes the
  `d c` ambiguity. Re-open only alongside a favourites UI.
- **Browse modes** — **HAVE.** Browse / reader / split
  (`lib/models/wb_centre_mode.dart`).
- **Multiple synchronised browse windows** — **ABSENT.** bwh12. Two
  independent chapters open side by side, optionally synchronised. Our
  split mode is two *versions* of the **same** chapter. This is a real
  exegetical need (compare Kings with Chronicles) and we hold the data
  for it: `assets/ot_synopsis.json` and `gospel_synopsis.json` already
  align the parallels. *Done:* split mode gains an "independent
  reference" toggle, and the synopsis assets feed a "jump the other pane
  to the parallel" action.
- **Comparing Bible versions (difference highlighting)** — **HAVE**
  (v1.6.147). View ▸ *Highlight version differences*, off by default and
  greyed with a reason when the stack holds no two editions of one
  language. Word-level LCS marks, a rose underline, and a legend naming
  the base of each language group. `lib/utils/version_diff.dart` is a
  pure core with `test/version_diff_test.dart` on it.

  **This entry's citation was wrong and is corrected here.** It said
  bwh37 "Comparing Bible Versions"; bwh37 is *Compiling Version
  Databases* and has nothing to do with colour. The feature is specified
  in **bwh30 "Using Colors" § Comparing Bible Versions**, and reading
  the right topic changed the design three ways a guess from the feature
  NAME would have missed: it is a **same-language** operation (so the
  stack is partitioned by `BibleVersionInfo.language` and Greek is never
  diffed against English), the **first version is the base**, and
  BibleWorks explicitly *cannot* do this for "double-byte languages
  (Chinese, Arabic, Korean, Japanese, Thai, Vietnamese)" — so the
  Chinese comparison, which is the one our readers most need, is a place
  we go past it rather than catch up to it. Measured: `cuvs-plus` vs
  `cuvs-yhwh` differs in 7,892 of 31,102 verses, and in 71.7% of those
  the only characters marked are divine-name characters.

  One departure from BibleWorks, deliberate and measured: the base row
  is marked where it aligns with **no** other row, not where it differs
  from **any**. On the five-English stack, BibleWorks' union rule paints
  58.3% of the base row; the intersection rule paints 0.1%. The two
  rules are identical for two versions. See the library doc.
- **External Links Manager** — **ABSENT**, low priority. bwh12.

### 3.4 The Analysis window

Fourteen tabs today (`lib/widgets/analysis_tabs.dart`, enum order is
load-bearing — it is persisted **by index**, so append, never insert):
Word Study · X-Refs · Stats · KWIC · Related · Lists · Phrases ·
Vocabulary · Forms · Topics · Context · Places · Sermons · Notes.

Mapped against BibleWorks' own tab set (bwh10):

| BibleWorks tab | Ours | Verdict |
|---|---|---|
| Word Analysis | Word Study | **HAVE** |
| Search Statistics (bwh23) | Stats | **HAVE** (#290, #308) |
| Words / wordlist | Word List tool + Vocab | **PARTIAL** — see 3.5 |
| Context (bwh10h) | Context | **HAVE** |
| X-Refs | X-Refs | **HAVE** |
| Resource Summary | — | **PARTIAL** — see below |
| User Notes | Notes | **HAVE** (2026-08-18) — see below |
| Version Info | — | **ABSENT**, small |
| Browse / Verse | centre pane | **HAVE** by another shape |
| Editor | — | **REJECTED** |
| Mss (manuscripts, CNTTS) | — | **REJECTED**, licensed |
| Use / EPUB / AGNT / User Lexicon | — | **REJECTED** |
| Forms | Forms | **HAVE** |
| Leningradensis | — | see §5 |

- **Resource Summary tab** — **PARTIAL.** bwh10's docked list of every
  resource that says something about the focused verse. We answer it in
  pieces (X-Refs, Topics, Places, sermons) but nothing collects them.
  `reader_analysis_request.dart` already records that the verse-keyed
  **sermon list** belongs in a tab for exactly this reason and does not
  have one (`analysis_tabs.dart:89-92`). *Done:* sermons get a tab, and
  consider one "everything about this verse" summary above the
  specialised tabs.
- **User Notes tab** — **HAVE**, 2026-08-18. The Notes tab is the
  fourteenth, `lib/widgets/verse_notes_pane.dart`, over the store the app
  has had since v1.2.59 — no new data model, and the modal editor and the
  Library page still read and write the same keys. It keeps what bwh15
  actually specifies: **autoload** (the note follows the focused verse,
  no Load button), **no Save button** (a 700 ms debounce, plus a flush
  when the selection moves and a flush when the pane is torn down),
  **the destination stated above the editor** — bwh15 prints the notes
  directory "so you always know where notes go", and the store's
  equivalent of a filename is the verse key, so the pane prints the
  reference and says out loud when a passage note will land on more than
  one verse — and **search**, which the app had none of at any depth
  (`searchNotes` in `lib/utils/verse_notes.dart`, title + body, results
  in canonical order, a passage note answering once as its range). The
  strip's icon carries a dot when the focused verse already has a note.
  The keystroke rules are pinned by `test/verse_notes_test.dart`, whose
  widget half exists only to prove the four ways a keystroke can be lost.
  **Deliberately NOT built: bwh15's chapter notes and its verse/chapter
  mode switch.** Every note in this store hangs off a verse, so a chapter
  note means inventing a second shape for data readers have already
  written — not a call to make without the owner. A chapter note can be
  written on the chapter's first verse today. If it is ever wanted, the
  question to answer first is what happens to such a note on export and
  in the Library list, not how to key it.
- **Editor tab** — **REJECTED.** A word processor inside a Bible program
  was a 1990s answer to "how do I get this into my paper". The modern
  answer is the clipboard, and #312 is already making phrasing export
  rich text. Keep the export, refuse the editor.
- **Mss tab / CNTTS apparatus / manuscript images** — **REJECTED**,
  permanently. Licensed data. `HARD CONSTRAINTS` in the loop prompt
  forbids copying BibleWorks' databases, and the manuscript images are
  the clearest case.

### 3.5 The study tools

- **Word List Manager (bwh26)** — **PARTIAL**, and the headline is done.
  `lib/pages/word_list_page.dart` builds a list for the passage in view
  (Tools → Word List, `workbench_page.dart:491`), and since 2026-08-19
  **compares two books** — bwh26's own example, *"find all words that
  occur in John that do not occur anywhere else in the New Testament"*.
  Ours answers the stronger question, *nowhere else in the whole Bible*:
  it adds the two scope counts and compares them with the corpus total in
  `concordance.json`. That is exact rather than approximate because the
  concordance's `n` agrees with a tally of `assets/originals` on all
  14,040 numbers with zero disagreements (DATA-INTEGRITY check 3b), and
  it is only sound because two whole books cannot overlap — which is why
  the pickers are books and not verse ranges. Jude against 2 Peter gives
  exactly three such shared words (συνευωχέω, ὑπέρογκος, ἐμπαίκτης), the
  three the commentaries cite for the relationship between the letters.
  Logic in `lib/utils/word_list_compare.dart`.
  *Still missing:* compiling a list from **a whole version** and from **a
  command-line or GSE query**, and a morphology filter on the list.
- **Verse List Manager (bwh27)** — **PARTIAL.** The Lists tab and
  `verse_list_store.dart` hold and scope lists. bwh27 also **compares two
  verse lists** and offers a book sort order. *Done:* set operations over
  two saved lists (in both, in either, in one only).
- **Related Verses Tool (bwh50)** — **HAVE.** Related tab.
- **Phrase Matching Tool (bwh51)** — **HAVE.** `phrase_match.dart`,
  Phrases tab.
- **KWIC (bwh31)** — **HAVE.**
- **Diagramming module (bwh25)** — **PARTIAL, and diverging on purpose.**
  BibleWorks' Diagrammer is a symbol canvas — you drag connectors and
  boxes. Ours is `lib/pages/phrasing_page.dart`, line-based Biblearc-style
  phrasing, which #307 and #312 have been deepening at the request of a
  real outside user (Pastor Raymond HK). **That is the right divergence**
  — phrasing is practised far more widely than symbol diagramming, and it
  has an actual user asking for it. Track the remaining #312 items
  (default range = the sentence, richer export, controls that teach)
  rather than BibleWorks' symbol set. Note bwh25 ships **pre-made Greek
  New Testament diagrams**; we have no equivalent corpus and should not
  invent one.
- **Parallel-Aligned Hebrew/LXX (bwh30, Tov-Polak)** — **ABSENT.** A
  word-level alignment of the Hebrew Bible against the Septuagint, with
  the Tov-Polak analysis columns. We have both texts (`assets/originals/`,
  `assets/lxxwh.json`) and a 7 KB `assets/strongs/lxx_hebrew_to_greek.json`
  — a Strong's-to-Strong's mapping, **not** a verse-level alignment. The
  Tov-Polak database itself is licensed and must not be copied.
  *Done, conservatively:* a Hebrew↔Greek pane driven by the Strong's
  correspondence we already own, labelled honestly as a lexical
  correspondence and **not** as a scholarly alignment. Do not imply
  Tov-Polak.
- **Vocabulary flashcards (bwh40)** — **PARTIAL.** Vocab tab +
  `vocabulary_store.dart`. bwh40 adds learned/not-learned marking,
  filtering, timed sessions, printing and an **Example Verse Finder**.
  *Done:* pick the two that matter for retention (learned marking,
  example verse) and reject the rest — printing flashcards is a paper-era
  feature.
- **Lexicon Browser (bwh35)** — **HAVE** for Strong's, **PARTIAL** for
  the rest. Shipped 2026-08-23: `lib/pages/lexicon_page.dart` +
  `lib/utils/lexicon_browse.dart`, opened from `Resources`. Both lexicons
  entire (5,523 Greek, 8,674 Hebrew), alphabetical by default with a
  letter strip, Strong's-number order as the alternative, and the two-tier
  search — headwords, then full text over the definitions, which answers
  the "which entries mention 'covenant'" question this entry was written
  for. Rows open the existing `strongs_entry_page.dart`; there is
  deliberately no second entry renderer.
  *What is left:* the browser reads `greek.json` / `hebrew.json` only. The
  deeper `bdb_zh.json` / `thayer_zh.json` are bundled and already served
  by `ChineseLexiconService`, but choosing *which* lexicon to browse is a
  second axis on the page (a lexicon picker, and per-lexicon coverage that
  is not 1:1 with Strong's numbering) and was left out rather than
  half-built. That is the next slice, and it stands on its own.
- **Maps (bwh33)** — **HAVE.** Atlas + 1,192 plates + gazetteer, with
  provenance (#300). bwh33's route/travel-speed tooling is **REJECTED**;
  it is a cartography editor, not a study feature.
- **Timeline (bwh39)** — **HAVE.**
- **Synopsis window (bwh38)** — **PARTIAL.** We hold both synopsis
  assets — 71 gospel events and 139 Old Testament groups — and both are
  now reachable from the reader menu on every book they cover. What
  bwh38 has and we do not is the **display**: an editable SDF verse list
  on top, and below it the parallel passages laid out **side by side,
  one Browse column per passage**, with a "Remove Blanks" toggle. Ours
  is a sheet of tappable chips, so a reader compares two passages by
  jumping between them instead of reading them beside each other, which
  is the whole point of a synopsis. See 3.3's independent-pane item —
  same fix, and `docs/PRODUCT-AUDIT.md` §7.4 says the sheet stays until
  #292 lands.
  *(2026-08-12: this entry previously cited bwh43, which is the
  morphology code tables, and claimed the assets were "surfaced inside
  the reader" — true of the gospel half only. The 139 OT groups had no
  reachable entry point at all. Fixed; see `docs/DATA-INTEGRITY.md`
  check 25.)*
- **TSK / Nave's / Bible Outline (bwh34)** — **PARTIAL.** TSK is in
  `cross_references.json`. **Nave's Topical Bible SHIPPED** (2026-08-19,
  merged undeployed — the release that carries it will bump the version):
  5,322 topics, 29,379 lines, 77,974 references, entered from the verse
  in the Topics tab above the Modern Concordance, which is a different
  work and NT-only. Imported by `tools/import_naves.py` from CCEL's ThML
  edition; see `docs/DATA-INTEGRITY.md` check 42 for the two upstream
  defect classes it had to repair before any of it was true.
  What is still missing is BibleWorks' *browsable* side (bwh36_RWP): the
  entry list, the lookup box and the history list under `Resources |
  X-Refs`. The data is already there and tested — `NavesService.search`
  and `NavesService.topic` — so that is a UI slice, not an import.
  Bible Outline ≈ our `book_introductions.json` +
  `section_titles.json`, **PARTIAL**.
- **Read Text module (bwh53)** — **REJECTED.** Audio reading of the
  biblical text. TTS was built and removed at v1.3.19
  (`ui_strings.dart:4833`, `app_settings.dart:86`). Do not resurrect it
  without the owner asking. Distinct from #293 sermon audio, which is a
  different ask and is BLOCKED on hosting.
- **Bagster's Daily Light (bwh36)** — **REJECTED.** Devotional. Wrong
  product; that is YsWords' job.
- **External Resources Manager / Ermie (bwh32)** — **ABSENT**, low
  priority.
- **Report Generator (bwh28)** — **ABSENT.** Generates a formatted study
  report for a passage: text, lexicon entries for each word, filtered by
  morphology and frequency. This is a genuinely good idea we have all the
  parts for (word list, lexicons, morphology, frequency) and no assembly.
  *Done:* "Report for this passage" producing rich text or HTML that
  survives pasting — coordinate with #312's export work so there is one
  export path, not two.

### 3.6 Notes, copying, export

- **Copy / Copy Center (bwh27b)** — **HAVE**, `copy_center_sheet.dart`.
- **Export options, verse ranges, format choice** — **PARTIAL.** bwh28.
  *Done:* fold into the Report Generator entry above.
- **User notes database** — **HAVE as a docked surface**, 2026-08-18.
  See 3.4. Notes are still exportable in both formats
  (`export_service.dart`), which now reads a verse key through the same
  parser the tab does.

### 3.7 Configuration, extensibility, input

- **Options / settings** — **HAVE**, and then some (`settings_page.dart`,
  3,313 lines; #281 flagged the size, #311/#315 fixed the type controls).
- **Book name abbreviations, version abbreviations** — **HAVE.**
- **Changing book order** — **ABSENT**, low value.
- **Compiling your own version database (bwh47)** — **ABSENT.**
  BibleWorks lets a user compile and install their own Bible text. Ours
  are baked into the bundle. This is how a user brings a translation we
  cannot ship for licence reasons — which makes it the honest answer to
  several licence-blocked items (#278 NASB). *Done:* an import path for a
  user-supplied version file, stored locally, never uploaded. **Sizeable;
  needs a real design pass, and must not become a piracy convenience —
  local only, no sharing.**
- **Custom modules (bwh48)** — **ABSENT.** Same shape as above, for
  reference works rather than Bibles. Lower priority.
- **Greek and Hebrew keyboard layouts (bwh45/bwh24)** — **ANSWERED
  2026-08-19**, by the other road. The entry above used to say
  BibleWorks "ships keyboards so you can type Greek and Hebrew"; read in
  full, `bwh24_UsingGreekHebrewFonts.htm` describes a **font keyboard
  bound to the search version** — the ASCII you type is rendered in
  `Bwgrkl`/`Bwhebb`, so `avga,ph` *is* ἀγάπη — plus an INS key that
  inserts a character by code. It is a typing surface, not a lookup, and
  the key charts in the help are ASCII rendered in a font we do not have,
  so the mapping is not recoverable from the topic at all.
  Two things followed. Typing ἀγάπη already works here — the text scan
  finds it in a Greek edition (#321 fixed the fold that stopped it), so
  the keyboard would only save keystrokes on a device that has no such
  keyboard anyway. What did NOT work was the common case: a reader who
  knows the word `agape` with an English Bible open got "No results
  found" over a corpus containing it 116 times. **Shipped:** a romanised
  index over the 13,964 joined lexicon entries (`romanised_lemma.dart`),
  two-tier so the 1890 spellings (`shâlôwm`, `chêçêd`) are reachable by
  the modern ones; candidates are shown and never auto-resolved (2,757
  of 21,147 typable spellings reach more than one entry); and the offer
  is gated on the word occurring in **no verse of the edition, read as
  a word, at any scope** —
  which is what keeps `bad`→H905 and `dove`→H1679 off the screen. See
  the research note of 2026-08-19 for the measurement, including why the
  obvious gate (an empty result list) was wrong.
  *Still absent, deliberately:* a soft keyboard, and romanised terms
  inside the Strong's boolean grammar.
- **Keyboard shortcuts (bwh44)** — **PARTIAL.** Ctrl+L, Ctrl+Shift+C,
  Esc. bwh44 has a full function-key set. *Done:* a shortcut sheet and
  the handful worth having, plus a discoverable list — a shortcut nobody
  can find is not a feature.

### 3.8 What we will never copy

Stated once so nobody re-derives it: BibleWorks' **Bible texts,
lexicons, morphology databases, manuscript images and apparatus** are
licensed. Studying the interface and reading the help is fine. Shipping
the content is not. Everything bundled here must be public domain or
openly licensed, and the specific exclusions already recorded elsewhere
stand: `assets/nasb-ev.json`, `assets/nsn-plus.json` and
`assets/tagged/nsn-plus/` are Eagle's View NASB, all rights reserved,
and are excluded by `.gitignore:69-71` **deliberately** — they are on
disk, untracked, and undeclared in `pubspec.yaml` **by design**. That is
not a wiring bug, and an audit that reports it as one is wrong.

---

## 4. Source 2 — Eagle's View

**Verdict: fully landed. Nothing is sitting unwired.**

Audited 2026-08-12, three ways (present on disk / declared in
`pubspec.yaml` / referenced from `lib/`). Every asset produced by the six
`tools/import_eaglesview*.py` scripts is declared and reachable:

| Import | Asset | Reached by |
|---|---|---|
| `import_eaglesview.py` | `kjvs.json`, `lxxwh.json`, `cuvs-plus.json` + `assets/tagged/` | `FetchVersesService`, `TaggedTextService` |
| `..._greek_stats.py` | `assets/greek_stats/` | `GreekStatsService` |
| `..._lexicons.py` | `thayer.json`, `bible_names.json` | `ThayerService`, `BibleNamesService` |
| `..._ot_synopsis.py` | `ot_synopsis.json` | `SynopsisService` |
| `..._places.py` | `bible_places.json` | `PlacesService` |
| `..._modern_concordance.py` | writes to `build/restricted/` | Topics tab |

Two things worth carrying forward rather than re-deriving:

- The **Modern Concordance importer writes outside the bundle by
  default** and needs an explicit rights acknowledgement flag. That is
  intentional. Do not "fix" it by pointing it at `assets/`.
- The `nsn-plus` mention in `tagged_text_service.dart:164` is a **stale
  comment** listing a version that was never imported. Harmless, but it
  is what made an automated audit call the gitignored files a live bug.
  Worth deleting the next time that file is open.

The historical failure this axis existed to catch — `bible_names.json`
and `thayer.json` committed but absent from `pubspec.yaml`, so
unreachable — is closed and has not recurred.

---

## 5. Source 3 — Yahwehdehua (#301)

**Verdict: effectively CLOSED. This is the headline finding of this
document, and it retires an item budgeted at "several iterations".**

The export is at `~/Documents/New project/yahwehdehua_bible/output/`
(834 MB; `bible.sqlite`, `manifest.json`, `official_modules/`). #301
listed five layers as new and unimported. Measured against the repo on
2026-08-12, **four are already shipping and the fifth is unavailable**:

1. **BDB + Thayer Chinese lexicon (`bdbthayer.dct`, 14,696 entries)** —
   **ALREADY IMPORTED**, 2026-08-11, by `tools/import_yahweh_modules.py`
   → `assets/strongs/bdb_zh.json` (**8,853** Hebrew entries) and
   `thayer_zh.json` (5,843 Greek). Wired at
   `chinese_lexicon_service.dart:101`, reached from
   `word_analysis_pane.dart:157`. Verified by reading H430, H1254 and
   H7965 out of the shipped asset.
   **Correction to the brief for the record:** it is **not** scholarly
   BDB. It is the widely-circulated abridged/Strong's-tagged BDB in
   Chinese translation — median Hebrew entry 111 characters, longest
   2,695, with KJV gloss-frequency tables and numbered senses. Real
   unabridged BDB runs thousands of words per major entry with cognate
   languages. It is much better than a one-line gloss and it is not BDB
   proper; **do not label it "BDB" in the UI without that qualification.**
   Keys are unpadded (`H430`, not `H0430`) — a trap for anything that
   normalises Strong's numbers.
2. **Strong's + morphology on the Chinese text** — **ALREADY SHIPPING.**
   `assets/tagged/cuvs-yhwh/`, `cuvs-plus/`, `kjvs/`, `lxxwh/` all carry
   a `g` field, and it holds exactly the export's TVM codes — Genesis 1:1
   「创造」 is `{"s":"H1254","g":["H8804"]}` (Qal perfect), 46 distinct
   codes in Genesis alone, top ones H8799/H8804/H8800 matching the
   export's distribution. They are decoded for display by the same
   Chinese lexicon module (the H8675+ TVM pseudo-entries).
   *(`assets/tagged/bsb/` carries no `g` — the only tagged edition
   without grammar codes. Minor, and worth a line in DATA-INTEGRITY
   rather than an entry here.)*
3. **LC — identified: the Leningrad Codex, Hebrew Old Testament**, 23,145
   verses (31,102 − 7,957 WH, i.e. LC and WH partition the canon). The
   site's own metadata says so verbatim: `LC: Leningrad Codex
   希伯来文旧约圣经`. Fully pointed and accented, morpheme-divided.
   **Not worth importing as a text** — we already ship a WLC-family
   Hebrew Bible in `assets/originals/` with **real** morphology, whereas
   every LC morphology code in the export is the null placeholder
   `H9999`. Its one genuine use is as an **independent witness** for
   `docs/DATA-INTEGRITY.md`-style checks on the Hebrew consonantal text
   and its Strong's tagging. That is a cheap, high-value check and is the
   only part of #301 still worth doing.
4. **WH (Westcott-Hort Greek NT, 7,957 verses)** — duplicate. We ship it
   in `lxxwh.json`, accented; the export's copy is lowercase and
   unaccented, i.e. strictly worse.
5. **LEB translator notes (24,245) and supplied-word marks (29,650)** —
   **ALREADY SHIPPING, and the export is not needed.** Measured: those
   layers exist in the export on the **LEB reading only** (all other
   versions hold `[]`), and our `assets/leb.json` already carries the
   same notes inline — `<note: Or "expanse">` at Genesis 1:6, 11,365
   occurrences of "Literally" against the export's 11,189. They came with
   the LEB text itself.
   **And the export is *not* the missing witness DATA-INTEGRITY has been
   waiting for.** Open item 4 there wants a source that preserves the
   LEB's `{…}` idiom braces for 660 imported verses. Checked directly:
   the export's LEB has **0** verses containing an idiom brace in
   `text_clean` (its `{` are `{Note: …}` delimiters), and its Genesis 1:6
   reads "and let it cause a separation between the waters" where ours
   reads "{let it cause a separation between the waters}". **Negative
   result, measured — record it so nobody checks twice.**

**What remains of #301:** run the LC text as a second witness against our
Hebrew (one iteration, accuracy-class work, belongs in DATA-INTEGRITY),
and nothing else. The standing exclusions still hold — do **not** import
吕振中 (香港聖經公會) or HCSB (Holman); site-owner approval cannot cover
third-party texts they do not own.

---

## 6. Source 4 — YsWords

**Method limitation, stated up front:** the YsWords Flutter source is
**not on this machine**. `~/Documents/CodingProject/yswords-apps` is a
static website and `yswords-data` is a data/CDN repo; neither contains a
`pubspec.yaml`. The comparison below is therefore drawn from **this
repo's own history** — SeekSparks' initial commit is the YsWords tree at
v1.3.144, and `655002a` (2026-08-05) ported v1.3.145–v1.4.6. Anything
YsWords has shipped since then is **unknown here**. To do this axis
properly, clone `github.com/SuyangLiuPaul/YsWords` first; if it is
unreachable, say so and skip, exactly as #309 instructs for the CDC site.

**The rule, written down once so it is not re-litigated:** *the workbench
is the app.* YsWords is a phone-first devotional reader and remains an
actively developed sibling, not a competitor and not an archive. A
feature's presence in YsWords is not an argument for its presence here.
Absences that are deliberate:

| Gone from SeekSparks | Why |
|---|---|
| `dashboard_page`, home screen | There is no home screen. The workbench is the entry point. |
| `feedback_page`, `feedback_service` | Removed with the dashboard. |
| Firebase: auth, Firestore, Realtime DB, Google sign-in | #286, one worldwide build. Cross-device sync was traded for reachability in China; the highlights/notes export is the honest migration path and must keep working. |
| `search_page` | Merged into the command pane (#B). One search, not two. |
| `cuv`, `cnv`, `biblexg` v1 | Superseded duplicates. Note the removal caused the prod `FormatException` crash — unknown version codes must fall back, never throw. |
| TTS / 朗读 | Removed v1.3.19. |

**Where YsWords may still be ahead, and worth a look when the source is
available:** anything touching notes and highlights. That subsystem holds
**user data** and YsWords is phone-first, where note-taking is common. The
Notes tab (§3.4) was built on 2026-08-18 **without** inventing anything —
it writes the v1.2.59 keys — so the question is still open and still
cheap: if YsWords has evolved the note model since v1.4.6, we want to know
before either side grows a second one.

Everything original-language — Strong's, concordance, originals,
cross-references, LXX — was already ported and has since been developed
much further here. No study capability is known to have been lost in the
fork.

---

## 7. The fifth axis — UI/UX and detail fine-checks

The owner named this explicitly, and it never appears in a feature
inventory. **It is a standing section, not a list that empties.** Two of
the worst defects found so far were invisible in English and invisible to
a green test suite: #297's CJK label ellipsis (a Latin width constant
applied to full-width glyphs, so Chinese *always* truncated and English
*never* did) and the version-pill glyph collision.

**The standing sweep.** For any surface you touch:

- **Widths:** 1400 (comfortable), 992 (the three-pane gate), and the
  **pane minimum** (256 analysis / 240 search). Overflow hides at the
  minimum.
- **Locales:** EN, 简, **繁** — traditional forms run wider than
  simplified, so 繁 is the one that breaks.
- **Themes:** light and dark.
- **Type:** 12 / 20 / 40 pt and menu scale 0.7 / 1.0 / 1.5, after #311
  and #315 made the controls real. Original-language text has a higher
  floor than Latin — pointed Hebrew loses its diacritics before Latin
  loses legibility, and those diacritics carry meaning.
- **Touch:** the target device is a tablet. **There is no hover.** Any
  teaching that lives only in a `Tooltip` is invisible in practice
  (#299). Any content that lives only in a hover preview is unreachable
  (#312).
- **RTL:** Hebrew flows the other way, and indentation is a flow
  direction.

**Chrome consistency (#279, still open).** The live inventory is the
`_remaining` map in `test/page_chrome_pass_test.dart` — read that, not
any prose count. Spec is `workbench_theme.dart:16`: *square corners, 1 px
hairline borders, no shadows, no cards.* Do not flatten blindly: reading
surfaces may keep generous spacing and larger type. It is the **chrome**
that must match, not the density.

**The rule that produced most of these findings, worth repeating:** *a
screenshot is the verification.* The suite has stayed green through every
visual defect this project has shipped. A widget test that asserts a
`TextStyle` passes happily while the page is illegible.

---

## 8. Picking the next item

In rough order of value, if nothing else is pressing.

**2026-08-23: items 2–6 are now all struck through.** That list was
written 2026-08-12 and it is spent; 1a closed the same day it was
picked, so the live candidates are 1, 1b and 1c below. When those empty too, do not pick from the struck items — go back
to §3–§6 and choose a `PARTIAL` whose "what is missing" paragraph you can
finish in one iteration.

1. **Anything in `docs/DATA-INTEGRITY.md`'s ranked list.** Accuracy
   outranks everything here.
1a. ~~**The Lexicon Browser's second lexicon**~~ — **DONE 2026-08-23**,
   §6, bwh35. Three works over one headword list: Strong's, the English
   Thayer's, and the Chinese module (BDB on the Hebrew side, Thayer on
   the Greek). The picker changes only what is *said* about a word —
   `LexiconId` still decides which words exist, how they are spelled and
   in what order — so the same search returns the same entries whichever
   lexicographer is open.

   This entry's instruction to measure coverage first was right, and the
   answer was not the one it expected. **Holes: 5 in 14,197** — H2775,
   H7418, H7427, H8556 in BDB 中文 and G4191 in Thayer 中文, each a
   headword the module keys and never defines; plus **14 more in
   Strong's own Chinese gloss** (5 Hebrew, 9 Greek), blank on screen
   since the browser shipped the day before. Small enough to offer the
   work and label the row (`lexiconWorkSilent`), and pinned in
   `test/lexicon_browse_test.dart` so a re-import cannot widen the gap
   under a picker that promises coverage.

   The measurement also turned up a live defect it was not looking for:
   two of the English Thayer's 5,799 keys were zero-padded (`G0190`,
   `G0446`), so `lookup('G190')` missed **ἀκολουθέω**, the New
   Testament's verb for following Jesus. The article was in the bundle,
   shipped, and unreachable. Fixed by `ThayerService.canonicalKey`.

   And a defect for #301 rather than this ticket: **28 of the 14,696
   Chinese entries have a truncated `etymology`** (9 in `bdb_zh`, 19 in
   `thayer_zh`), detectable by an unbalanced parenthesis — e.g. H2775
   reads `charcah (khar'- saw`, G1537 stops mid-clause. The importer
   split a field on a delimiter that also occurs inside the parentheses.
   These render today in the entry pane, not only in the browser.
1b. **The synopsis display** (§6, bwh38). We hold both assets and both
   are reachable; what is missing is passages side by side instead of a
   chip sheet. `docs/PRODUCT-AUDIT.md` §7.4 parks this behind #292, so
   check whether #292 is still blocked before picking it.
1c. **Flashcard retention** (§6, bwh40) — learned/not-learned marking and
   the Example Verse Finder. The entry already rejects printing.
2. ~~Version difference highlighting~~ — **DONE v1.6.147**, §3.3.
3. ~~Nave's Topical Bible~~ — **DONE**, both halves. The verse-entered
   half landed 2026-08-19 (§3.5); the browsable side this entry named as
   "what is left" landed 2026-08-22 as `lib/pages/naves_page.dart` under
   `Resources`. The import was not small: it needed two repair passes
   before a single count was true (`docs/DATA-INTEGRITY.md` check 42),
   which is the general lesson for the rest of this list — "public domain
   and openly available" says nothing about whether the data is right.
4. ~~Verse list comparison~~ (§3.5) — **DONE**, both halves. The
   word-list half is `word_list_compare.dart` (2026-08-19). The verse-list
   set operations this entry called "what is left" were already shipped,
   under names a grep for *intersect/union/difference* does not find:
   `VerseList.selectCommonWith` and `selectUniqueTo`
   (`lib/utils/verse_list.dart:285,301`), wired to the Select menu at
   `verse_list_pane.dart:237-239`. Composed with `deleteSelected` and
   `invertSelection` they give intersection, difference and symmetric
   difference, and `test/verse_list_test.dart:165-251` asserts all three.
   Corrected 2026-08-23. This is §1's "grep it first" rule catching a
   fifth case, and it shows the grep has to be for the *reader's* verb:
   the operations are named for what she does — select what is common —
   not for the set algebra underneath.
5. ~~Compound (parenthesised) search~~ — **DONE 2026-08-19**, §3.1. What
   is left of it is Strong's-side grouping, which is a different engine;
   see the corrected §3.1 entry before picking it up.
6. ~~Transliterated Greek/Hebrew search input~~ — **DONE 2026-08-19**,
   §3.7. It was not cheap, and the help topic it cites describes a font
   keyboard rather than transliteration; read the corrected §3.7 entry
   before quoting this list.

~~A User Notes tab (§3.4)~~ — **done 2026-08-18.** It was picked from
this list as the largest gap in the Analysis pane.

Do not pick a `BLOCKED` entry. The current ones: **#278** (NASB licence),
**#293** (sermon-audio hosting cost), **#296** (production deploy
approval), **#309** (the CDC site is unreachable from this machine), and
the LEB-notes rights question if it is ever re-opened.
