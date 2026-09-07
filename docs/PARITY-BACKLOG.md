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
- **NOT (`!`)** — **HAVE.** *(Corrected 2026-09-07. The row said
  PARTIAL, "ours does not accept it inside a phrase", and named a *Done*
  that was already done when it was written.)* `TokenElement.negated`
  and `_matchFrom`'s `matches(...) == negated` implement the slot
  inversion, `parseCommandQuery` accepts a `!` on a single-token term
  inside a phrase and refuses it on a multi-token one
  (`CommandIssue.phraseNotMultiToken`), and
  `test/command_query_test.dart:131-156, 229-235, 336, 377` covers
  `'!the god`, the Chinese refusal, the echo string, **and BibleWorks'
  own forum failure case** `'!your *5 house`. Seventh confirmed case of
  §1's "grep it first".
- **Verse context limits for AND (`;10`)** — **HAVE.** bwh16.
- **Proximity** — **HAVE, and divergent in spelling by choice.**
  *(Updated 2026-09-05.)* We spell it `G25 NEAR5 G26`, unordered, and
  **`G25 BEFORE5 G26`**, directional — which is the query BibleWorks
  writes `*n` *between* the words (bwh17, bwh20 `('faith *4 love)`).
  #294 landed the teaching pass (operators dim until the line holds a
  number, hint row, tooltips).
  This row used to say the directional half was the substantive gap and
  the spelling was not, and that reading held: `BEFOREn` and `NEARn`
  return different verses over the same pair, and `NEARn` returns
  exactly what it always did —
  `test/strongs_directional_proximity_test.dart` asserts both, in that
  order, because a directional operator that agrees with the unordered
  one everywhere has not been implemented.
  The spelling stays ours, and the difference is now *taught* rather
  than merely declared: `suggestTextEquivalent` in `command_draft.dart`
  translates `yahweh BEFORE5 god` into the phrase grammar's `'yahweh *4
  god`, which is the first EXACT translation between the two grammars
  it has ever been able to make — same words, same order, same window
  (`NEARn` could only ever be half of one, because a phrase is ordered
  and `NEARn` is not). The distance drops by one on the way across:
  `NEARn`/`BEFOREn` are a word distance, `*n` is the count of words in
  between.
  *Still deliberately absent:* `*n` itself as an input alias, which
  collides with our wildcard `*` and needs that resolved before it can
  be accepted rather than around it.
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
- **A plain search matches across word boundaries** — **FIXED
  2026-09-05**, `lib/utils/plain_search.dart`, pinned by
  `test/plain_search_boundary_test.dart` against the real editions. The
  defect and its measurement are kept below, unedited, because the
  numbers are how the fix was checked to be the same bug: KJV `forth`
  went 3,419 → 877 and `asa` 1,301 → 207, and the 2,542 and 1,094 rows
  that difference removes are exactly the counts this entry recorded in
  August. Two things the entry did not anticipate. The rule is stated on
  the CHARACTERS, not on a locale or a mode: whitespace in the verse may
  be stepped over only where Han characters stand on both sides of it,
  so there is no Chinese branch to get wrong, and a verse mixing 和合本
  text with a Latin proper name gets the Latin rule at the Latin. And
  the old rule over-counted in the direction nobody expects — stripping
  spaces let a query that HAS a space match text that does not, so
  `for the` was 9 verses too many as well. Nine Chinese probes across
  both Chinese editions and four Greek probes over `lxxwh` return
  identical counts before and after; the 14 verses of stray spaces
  inside Han runs in `cuvs-yhwh.json` (玛拉基书 2:1 「这 诫命」,
  历代志上 21:20 「就和他 四个儿子」) are what makes the Han exception
  load-bearing rather than theoretical, and they are stepped over in
  the search layer because the scripture text is frozen.

  *The original entry, for the record:* A query with no control character is a
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

  *And that last sentence needed remeasuring rather than deleting.* The
  §3.7 gate is still necessary and is now necessary for a different
  reason. `test/romanised_gate_corpus_test.dart` measured five romanised
  probes against the KJV at 4, 3, 1, 1, 26 plain hits; after the fix four
  of the five are **0**, because those hits were the word gaps. `shalom`
  is still 3 — Judges 6:24 `Jehovahshalom` and 1 Kings 15:2 and 15:10
  `Abishalom` — and those are matches INSIDE a word, which the boundary
  rule keeps deliberately, because they are markable and a reader can
  see why the verse is there. So an `isEmpty` gate would still be wrong
  for שָׁלוֹם. The fix narrowed the gate's necessity from five words to
  two; it did not remove it.
- **Cross-version searches** — **HAVE, 2026-09-07, and this entry was
  wrong about what the feature is.** It read: *"Find verses where the KJV
  says X and the LXX says Y … one operator that takes a version tag per
  term."* bwh16 offers no such operator. What it ships is a **mode**, set
  from `Search | Cross Versions Search Mode`, which runs the one query
  the reader typed against **several editions of the same language** and
  reports the hits per version — its own stated use case is looking for a
  phrase "that occurs in some version but you don't remember which one".
  Building the entry as written would have shipped a cross-language
  conjunction under the name of a same-language broadcast and left the
  actual feature missing. §3's warning about guessing a feature from its
  name, second confirmed instance after `NEAR5`.
  `lib/utils/cross_version_search.dart` (which editions),
  `WorkbenchProvider._measureCrossVersion` (running them),
  `lib/widgets/cross_version_strip.dart` (the report),
  `AppSettings.crossVersionSearchMode` (the mode, persisted by name).
  Three of BibleWorks' four modes; the fourth is rejected below.
  Two deliberate divergences, both recorded in the library comment:
  **"same language" means the same script** (简体 and 繁體 are one
  language and two corpora — 雅伟 is not a substring of 雅偉, so
  broadcasting across the boundary would report zeros that say nothing
  about the text), and the pass runs **after** the reading version's
  results are on screen rather than before, because the other editions
  are several MB each and cannot change the answer already showing.
  *Text shapes only, on purpose:* a Strong's search is answered from the
  shared concordance and the tagged layer rather than from an edition's
  text, so "the same search in the LEB" is not a question it can be
  asked. The pass declines and the strip draws nothing.
- **Cross-version searches — the PRUNE mode** — **REJECTED 2026-09-07.**
  bwh16's fourth option removes editions with no hits from the display
  list. Its value is "show me only the versions that hit", and the strip
  already answers that by printing the count for every edition searched,
  zeros included. The Browse stack is an ordered list the reader
  arranges by hand — #288 made the order first-class — and a search is a
  question, not an instruction to redecorate. Re-open only if a reader
  asks for it.
- **A cross-VERSION conjunction (`kjv:X . lxx:Y`)** — **HAVE,
  2026-09-07.** Not bwh16 — this is what the old cross-version row
  described, and BibleWorks reaches it only through the GSE, so it is
  ours rather than a port. It earned its place: adjudicating the CSB's
  divine name that same morning needed exactly this query three times,
  and each time it was run by hand in Python against the raw assets.
  `lib/utils/cross_version_query.dart` parses,
  `WorkbenchProvider._runCrossVersionConjunction` runs it, and the `?`
  card teaches it with a worked example that really does return verses —
  `.kjv:propitiation csb:atoning`, the KJV having it three times and the
  CSB rendering it "atoning sacrifice".
  The control character keeps its job and a term may carry a `code:`
  prefix. **A prefix is only a prefix when it names an edition this
  build can load**, which is the whole ambiguity defence: `H1254:` is
  not a version, so it stays a search term and no reader loses a colon
  they meant literally. The phrase forms (`'`, `;`) are refused rather
  than split, because a phrase is an ORDER over adjacent tokens and
  cutting it per edition would run each half as its own term and quietly
  return the wrong verses.
  Combined by verse ID, never by index — the editions are separate
  corpora and a verse's position in one says nothing about its position
  in another. An edition that will not load makes the query EMPTY rather
  than dropping its condition: "the KJV says X and the CSB says Y" minus
  the CSB is a different question with more answers.
- **Morphological searches (Greek/Hebrew)** — **HAVE, 2026-09-07.** The
  row asked for a decision — "an agreement operator, or an explicit
  REJECTED … but decide it, do not leave it accidental". Decided by
  building it.
  `lib/utils/morph_construction.dart` is the engine: **sequence** (two
  or more forms, in order, within a distance), **morphological
  agreement** (named features that must hold the SAME value across two
  forms, whatever that value is), and **lemma agreement** (the same
  Strong's twice — a figura etymologica, `מוֹת תָּמוּת`, without naming
  the root). `MorphSearchService.runConstruction` runs it; the
  morphology pane's "With a second word … agreeing in …" row reaches it.
  **The two ways this can look right and be wrong**, both mutation-
  checked in `test/morph_construction_test.dart`:
  *Agreement is not a feature filter.* "Same gender" is not "masculine",
  and running the query once per gender is a different question that
  also returns the disagreeing pairs. A feature the code does not state
  therefore cannot be shown to agree — treating two absences as a match
  makes every uninflected pair "agree in gender", which looks like the
  feature working and silently doubles the hits.
  *A term matches a MORPHEME, not a word.* `HC/Vqw3ms/Sp3fs` is
  conjunction + verb + suffix, its verb is masculine and its suffix
  feminine, and 32% of the Hebrew Bible has more than one morpheme, so
  which one the agreement is read off decides the answer. The engine
  backtracks over (position, morpheme) pairs — which is what
  `MorphQuery.matchAll` was written for, and its own doc said so before
  this landed.
  *Still out of scope, and named rather than left as an absence:*
  bwh17's **context dependency** in the full sense — "this word's
  referent is that word's subject" — needs a syntactic parse of the
  original, which is a dataset this repo does not have and cannot
  derive. Morphological agreement is answerable from the codes we ship;
  syntactic dependency is not, and the difference is the line an honest
  verdict has to draw.
- **Accents and vowel points in search** — **HAVE, 2026-09-07.** This
  row was half wrong when it was read. It said "Hebrew points are
  stripped … Greek accents are not stripped … a hardcoded asymmetry",
  which was true on 2026-08-12 and stopped being true on 2026-08-16:
  **#321 folded both**, on both sides of the comparison, because Aunty
  Rosa searched `ὁ θεός` against a corpus spelled `ο θεος` and got a
  blank page. Sixth confirmed case of §1's "grep it first".
  What was genuinely missing is the half the row mentioned in passing —
  bwh17's **setting**. Shipped as `searchIgnoresPointing` (default ON,
  which is what the app has done since #321), the switch itself in
  `lib/utils/search_folding.dart`, persisted by `AppSettings`, in
  Settings beside bwh29's two Masoretic switches because all three are
  about how the Hebrew and Greek are read.
  **Why a switch and not a threaded parameter**, since the shape will
  look wrong to the next reader: six sites fold and they must agree —
  the corpus key, the plain scan's query, `TokenMatcher`'s compile, the
  command matcher's verse tokens, and both halves of the highlighter.
  Two of them run inside `parseCommandQuery`, which is deliberately
  Flutter-free and has no settings in scope. The failure mode of getting
  it wrong is not a crash but a **silent asymmetry** — fold one side and
  not the other and the search finds nothing, which is the exact defect
  #321 existed to fix — so one switch that cannot be half-applied beats
  six parameters that can. `test/search_folding_test.dart` mutation-
  checks precisely that: making the corpus key ignore the switch turns
  three of its assertions red.
  Anything that caches folded text must invalidate on
  `searchFoldingGeneration`. `MainProvider.searchKeys` is the only such
  cache and does.
- **Qere / Kethib** — **HAVE.** *(Corrected 2026-09-05. This row
  said `ABSENT` on the strength of "grepping `lib/` for
  `Qere|Kethib|Ketiv` returns nothing", which was true when written on
  2026-08-12 and stopped being true six days later. It is exactly the
  failure §1 warns about — re-grep before starting.)*
  `lib/utils/ketiv_qere.dart` landed `c82a823` 2026-08-18. All four
  Masoretic roles are modelled (`k`, `q`, `kx` *Ketiv velo Qere*, `qx`
  *Qere velo Ketiv*) on `OriginalWord.ketivQere`
  (`lib/models/original_word.dart:17`), and the pair is **displayed**:
  the inline `K`/`Q` mark and its note in `browse_window.dart:1695`,
  `:1700`, `:1857`, in `word_analysis_pane.dart:353`, `:371`, and in
  `originals_sheet.dart:940`, `:1310`. `test/ketiv_qere_test.dart` pins
  it. Counts include both readings, which is BibleWorks' own default.
  What is genuinely missing is the **setting**: bwh29's two switches for
  excluding either reading from searches, and bwh17's Qere/Kethib search
  codes — grep finds nothing for either in the query or settings layer.
  `docs/DATA-INTEGRITY.md`'s open item 2 (four verses printing both
  forms) is the same seam.

  **The setting shipped 2026-09-05** and this row is now the same
  `PARTIAL` for a smaller reason. bwh29's two switches are
  `excludeKetivFromSearch` / `excludeQereFromSearch` in
  `app_settings.dart`, reachable in Settings, carried to both engines as
  one value object (`KetivQereSearchScope` — two booleans threaded
  separately is how a caller reads one and forgets the other), honoured
  by `search_service.dart`, `morph_search_service.dart` and
  `workbench_provider.dart`, and **defaulting to `both`**, which is
  BibleWorks' own default and what this app has always done, so a reader
  who never opens the control sees no change. Pinned by
  `test/ketiv_qere_search_setting_test.dart`.
  **The search codes shipped 2026-09-07 and this row is now HAVE.**
  bwh17's Qere/Kethib codes — asking for one reading *inside* a query
  rather than as a mode the whole session sits in — are
  `MorphQuery.readings`, a row of their own in the morphology pane
  (Semitic only; the Masoretic apparatus has nothing to say about
  Greek), honoured by `MorphSearchService`.
  Two decisions worth reading before changing anything here:
  **it is not a `MorphSlot`**, because every slot is parsed out of the
  morphology CODE and the reading is a property of the WORD
  (`OriginalWord.ketivQere`) — BibleWorks can treat them alike because
  its WTM codes end in `Rk`/`Rq`/`Rx` and ours do not, and inventing a
  code character to parse back out would be pretending; and **the codes
  SELECT while bwh29's switches EXCLUDE**, so they disagree about the
  436,312 unmarked words. Getting that backwards makes "find me the
  Qere" return the whole Hebrew Bible, which is what
  `test/morph_reading_query_test.dart` mutation-checks. When a query
  names a reading it overrides the session setting, because otherwise a
  reader who once turned the Qere off gets nothing and no explanation.
- **Search limits (`l gen`)** — **HAVE**, extended past bwh16 by #280's
  scope model (books, groups, 希伯来圣经/希腊圣经). `l` stops at chapter
  granularity on purpose (`command_verb.dart:71-79`): verse-granular
  scoping is the Verse List Manager's job.
- **Morphology Assistant (bwh17)** — **HAVE, and it always was.**
  *(Split out of the row below and corrected 2026-09-07.)* That row said
  "none of the *building*" and set as its *Done* "a picker that
  assembles a morphology query from parts of speech and features without
  the reader typing a code". `lib/widgets/morph_search_pane.dart` is
  that picker and it landed `c033f75` on **2026-08-07, five days before
  the row was written** — its commit message is "a Graphical Search
  Engine, not just a parse line". It renders a chip row per `MorphSlot`
  (pos, tense, voice, mood, case, degree, subtype, stem, conjugation,
  state, person, gender, number), each value carrying the number of
  words choosing it would return, narrowing as the reader commits, and
  seedable from a word they clicked (`MorphQuery.fromWord`). Reachable
  as the Analysis pane's Morphology tab. Eighth "grep it first" case,
  and the one that should sharpen §3.2: a GSE-class *builder* ships
  here; what is rejected there is the GSE's diagram, not its power.
- **Command Line Assistant (bwh16)** — **HAVE, 2026-09-07.** The row
  separated the teaching from the building and asked for the second:
  *"a builder that composes the line from parts — pick AND/OR/phrase,
  add terms, set the verse context — and writes it into the command line
  so the reader can see the syntax it produced."*
  `lib/utils/command_builder.dart` composes,
  `lib/widgets/command_builder_sheet.dart` is the sheet, on the operator
  strip beside the `?`. **It writes the line and does not run it**, which
  is the design: an assistant that ran the search teaches nothing and has
  to be reopened every time, where one that leaves its work in the box
  gives the reader a line they can read, edit and type themselves next
  time. The line is visible the whole way through, so the syntax appears
  as they answer questions about MEANING — the shapes are named "all of
  them, same verse", never "AND (`.`)", because the reader who needs this
  sheet is the one who does not know what `.` means.
  **It invents no rule the grammar does not have**, and that took a
  correction. It was written with a "a phrase needs two words" guard, on
  the assumption that `CommandIssue.phraseNotMultiToken` refused a
  one-token phrase. It does not — that issue is about a NEGATED
  multi-token term — and `'love` parses. The guard came out: a builder
  that refuses what the command line accepts teaches a grammar the app
  does not have. Caught because `test/command_builder_test.dart` runs
  every shape it can produce back through the real parser, which is the
  only way a builder can be checked against the thing it is a front for.
  `;N` is offered only on the two shapes where it means what the reader
  will read it to mean, and switching to a phrase DROPS it rather than
  carrying it into a shape where it means something else.
- **Semantic domains (Louw-Nida)** — **REJECTED 2026-09-07, on licence,
  and this is the documented form the golden task asks for.**
  *What the feature is:* the *Greek-English Lexicon of the New Testament
  Based on Semantic Domains* (Louw & Nida, UBS, 1988) files every NT
  Greek lexeme under 93 numbered domains and their sub-domains, so a
  reader can ask for a MEANING rather than a word — every term in domain
  25, "Attitudes and Emotions", regardless of which lexeme carries it.
  bwh26 loads that index into the GSE and the Word List Manager, and it
  is the single most distinctive thing BibleWorks can do that a
  concordance cannot: it is the difference between "where does ἀγάπη
  occur" and "where is love spoken of".
  *What it would take:* the lexeme→domain mapping (~5,000 entries over
  ~5,600 headwords) plus the domain names and their tree. The domain
  NUMBERS attached to a word are arguably facts; the domain scheme, its
  wording and the assignment of a word to a domain are the authors'
  analysis, and that is the whole work.
  *Why not:* UBS holds it and licenses it commercially. Nothing in this
  repo may carry it, and there is no complete openly-licensed substitute
  — the nearest, UBS's own *Semantic Dictionary of Biblical Hebrew*, is
  the same rightsholder and covers the other testament.
  *Re-open only on new information:* an openly-licensed domain set, or a
  licence. Not on a fresh opinion about how useful it would be — its
  usefulness was never the question.

### 3.2 The Graphical Search Engine — re-decided 2026-09-07: the DIAGRAM is REJECTED, the power is not

bwh18/19/21/22 — four whole help chapters, a visual query builder with
word boxes, merge boxes, ordering/proximity boxes and five kinds of
agreement window. It is BibleWorks' deepest feature and its most-cited
one in reviews.

This section said: *"the GSE is a UI for expressing queries the engine
underneath can answer. Our engine cannot answer agreement or
context-dependency queries at all (3.1), so building the GSE first would
be building a steering wheel for an engine that does not turn. The order
is engine, then builder. **Re-open when 3.1's agreement work lands.**"*

**It landed** (`morph_construction.dart`, §3.1). So this is re-opened
and re-decided, and the answer splits in two:

* **The power ships.** Sequence, distance, morphological agreement and
  lemma agreement are exactly the queries the GSE's ordering, proximity
  and agreement boxes express, and they are reachable from the
  morphology pane. What the pane cannot yet build is a construction of
  more than two terms or one whose second term is constrained past its
  part of speech; the engine takes both, so that is a UI ceiling and not
  an engine one.
* **The diagram stays rejected**, and now for a reason about the reader
  rather than about the engine. The GSE is a canvas of boxes joined by
  lines, on a Windows desktop, built for a mouse. This app's target
  device is a tablet with no hover (§7), and a query canvas is the one
  surface where a drag that misses by four pixels changes the question
  being asked. The sentence-shaped row that shipped instead — "With a
  second word … agreeing in … next to it" — says the same thing in the
  space of three chip rows, and a reader can tell what it asks without
  being taught a diagram.

Re-open the DIAGRAM only if a reader asks for a query the sentence form
cannot express. The engine will already answer it.

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
- **Multiple synchronised browse windows** — **HAVE, 2026-09-07.**
  bwh12. The row asked for two things and the first has landed.
  *Independent reference — DONE.* The workbench's second column followed
  the primary unconditionally (`_followPrimary`, wired to the primary's
  listener), which is what made the row's "two versions of the same
  chapter" true. `View → Second column: independent` now stops it
  following, and turning following back on re-aims the column at once
  rather than waiting for the next page turn. Default stays FOLLOWING,
  deliberately and against bwh12's own default: this column lives in a
  workbench where the usual question is "what does the other edition say
  HERE", and a column that wandered off on every page turn would have to
  be re-aimed constantly.
  *A finding worth carrying:* the two surfaces did not agree. The
  workbench column follows by listener; `home_page.dart`'s Split View
  seeds its second pane once at activation and installs no listener, so
  it was ALREADY independent. Two behaviours under one name, which is
  the shape of defect `chapter_across_editions.dart` was extracted to
  stop.
  *The second half is answered, differently and better, 2026-09-07.*
  The row wanted the synopsis to "jump the OTHER pane to the parallel".
  bwh38's own answer turned out to be stronger and is what shipped: the
  `Parallels` tab lays every passage of the entry side by side in one
  pane (see §3.5). A reader comparing Kings with Chronicles now reads
  them beside each other instead of aiming a second column at one of
  them — which is the exegetical need this row was written for, and it
  works for a three- or four-way parallel that two panes could not hold
  at all.
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
- **External Links Manager** — **REJECTED 2026-09-07.** bwh12. It maps a
  verse or a word to a URL on a Windows box — the reader clicks and a
  browser opens someone else's site. Two reasons it is not for this app,
  and the second is the real one: it is a **desktop shell integration**,
  and this app's surfaces are a browser tab and a tablet where "launch
  an external program" is not a thing that happens; and what it links
  OUT to is what this app is trying to BE — a reader who has to leave
  for the lexicon, the atlas, the concordance or the topical index is a
  reader we have failed, and all four are already here. Re-open only if
  a reader names a resource they want that this app will never carry.

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

- **Resource Summary tab** — **HAVE, 2026-09-07.** The row asked for two
  things. **Sermons got their tab on 2026-08-17** and the row never came
  back to say so — tenth confirmed case of §1's "grep it first". The
  second is now built: a `Summary` tab that prints, for the focused
  verse, how much each verse-keyed resource has to say about it —
  cross-references, topics (Modern Concordance + Nave's), places,
  sermons, synopsis parallels — each row tapping through to the tab that
  holds it.
  **A count, not a preview**, because twelve tabs already answer twelve
  questions well and none of them can tell a reader WHICH of the twelve
  is worth opening for this verse, which is the whole job bwh10 gives
  its Resource Summary. **A zero is printed, not hidden**: a row that
  vanishes teaches the reader the resource does not exist, where a 0
  teaches them it does and this verse is not in it — frequently the
  interesting fact. An asset that fails to load gets a dash and its own
  caught failure, so it costs its row rather than the other five.
  Every lookup is the same call the owning tab makes, so the number and
  the list it points at cannot disagree.
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
- **Verse List Manager (bwh27)** — **HAVE.** *(Corrected 2026-09-07.
  This row asked for what §8's item 4 recorded as already shipped on
  2026-08-23 and then never came back to change here — the exact rot §1
  warns about, and the ninth confirmed case.)*
  Both halves are there. **Comparing two lists**: `selectCommonWith` and
  `selectUniqueTo` (`verse_list.dart:285,301`), wired to the Select menu
  at `verse_list_pane.dart:237,239`, and composed with `deleteSelected`
  and `invertSelection` they give intersection, difference and symmetric
  difference; `test/verse_list_test.dart:165-251` asserts all three.
  **Book sort order**: `sortedAndDeduped()` on the Edit menu, ordering by
  `canonicalBookIndex` — the canon, not the alphabet.
  §8 already noted why a grep missed this: the operations are named for
  what the READER does — select what is common — not for the set algebra
  underneath, so searching for *intersect/union/difference* finds
  nothing.
- **Related Verses Tool (bwh50)** — **HAVE.** Related tab.
- **Phrase Matching Tool (bwh51)** — **HAVE.** `phrase_match.dart`,
  Phrases tab.
- **KWIC (bwh31)** — **HAVE.**
- **Diagramming module (bwh25)** — **REJECTED as BibleWorks builds it,
  2026-09-07, and the divergence is the decision rather than a gap.**
  BibleWorks' Diagrammer is a symbol canvas — you drag connectors and
  boxes. Ours is `lib/pages/phrasing_page.dart`, line-based
  Biblearc-style phrasing, which #307 and #312 have been deepening **at
  the request of a real outside user** (Pastor Raymond HK). That is the
  right divergence twice over: phrasing is practised far more widely
  than symbol diagramming, and it has somebody asking for it where the
  symbol canvas has nobody.
  This row stays REJECTED rather than PARTIAL because keeping it open
  implied we owed the symbol set, and we do not — the phrasing work is
  tracked as #312 (default range = the sentence, richer export, controls
  that teach) and belongs there, not under a BibleWorks feature it is
  not trying to be.
  bwh25 also ships **pre-made Greek New Testament diagrams**. We have no
  equivalent corpus, and should not invent one: a diagram is an
  interpretation, and shipping ours as if it were the text would be the
  same error as printing a paraphrase in a parallel column.
- **Parallel-Aligned Hebrew/LXX (bwh30, Tov-Polak)** — **REJECTED on
  licence 2026-09-07, with the two halves separated.** The row read
  ABSENT and proposed a conservative build; checked against the code,
  what it proposed already ships and what is left is the licensed part.
  *What bwh30 is:* a **word-level** alignment of the Hebrew Bible
  against the Septuagint, with the Tov-Polak columns saying how each
  Greek word renders its Hebrew — added, omitted, transposed, a
  different Vorlage. The scholarship IS the alignment; the two texts are
  public domain and the pairing is not.
  *The verse-level parallel already ships.* Both texts are here — the
  Hebrew as the Browse window's `WTT` row, the Septuagint as the
  `LXX+WH` catalog edition — and the ordered version stack (#288) puts
  them in adjacent columns. Verified on seeksparks-dev 2026-09-07: WTT
  displayed beside KJV / BSB / KJV+S, LXX+WH offered in the picker.
  *The lexical correspondence already ships too, and is already labelled
  honestly.* `assets/strongs/lxx_hebrew_to_greek.json` is 214 curated
  Hebrew→Greek Strong's correspondences, CC0, reached by `LxxService`
  from `word_distribution_table.dart` and `originals_sheet.dart`. That
  is what this row proposed building; it was built before the row was
  written. It is **not** an alignment and claims not to be — 214 of
  8,674 Hebrew numbers, chosen for theological weight.
  *So what remains is exactly the licensed part*, which makes this
  REJECTED rather than ABSENT: a word-level alignment of the whole
  Hebrew Bible cannot be derived from a 214-entry lexical table, and the
  database that has it belongs to someone else. Re-open on an
  openly-licensed alignment — CATSS is the candidate, and reading its
  terms is the first move, not importing it.
- **Vocabulary flashcards (bwh40)** — **HAVE.** *(Corrected 2026-09-07.
  Eleventh "grep it first" case: the row asked for the two that matter
  for retention and both were already shipping.)*
  **Learned marking** is `VocabularyStore` — a persisted set of Strong's
  numbers, deliberately NOT synced, because a device disagreeing with
  another about what you have learned is worse than not syncing at all —
  and the pane filters on it (`vocabulary_pane.dart:74,134,188`).
  **The Example Verse Finder** is `findExampleVerses` /
  `ExampleVerse`, drawn per card with its own count
  (`vocabulary_pane.dart:101,218,724,752`).
  *Rejected, as the row itself proposed:* **printing** is a paper-era
  feature, and timed drill sessions are a study app inside a study app —
  neither is worth the surface. Re-open only on a reader asking.
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
- **Synopsis window (bwh38)** — **HAVE, 2026-09-07.** The row named the
  defect exactly — *"ours is a sheet of tappable chips, so a reader
  compares two passages by jumping between them instead of reading them
  beside each other, which is the whole point of a synopsis"* — and
  parked the fix behind #292. **#292 closed 2026-09-02**, so the gate
  came off and this is the re-decision `docs/PRODUCT-AUDIT.md` §7.4
  asked for: a docked `Parallels` tab, one column per passage, drawn
  from the reader's OWN edition so the synopsis is read in the
  translation they chose.
  **Columns, not a table**, and that is a claim about the sources: the
  passages do not align verse-for-verse — Matthew tells in four verses
  what Luke tells in eleven — so a table would have to invent a
  correspondence the evangelists do not have. Reading them beside each
  other IS the comparison; aligning them would be an argument.
  **bwh38's "Remove Blanks" is here and is off by default**, because
  silence is a finding: "only in Matthew and Luke" is a fact about the
  passage, so the blank columns are removable rather than removed. The
  count is printed on the toggle so a reader sees what it costs, and the
  book they are standing in is never dropped — a synopsis that hid the
  passage the reader is IN would be answering about somewhere else.
  **Two silences, worded differently**, which is the thing a synopsis
  can most easily lie about: "no parallel here" is a fact about the
  EVENT and "not in this edition" is a fact about the EDITION, and
  blurring them would make an argument from silence out of a missing
  asset. An unresolvable reference still gets its column, because the
  source said that book records the event and hiding it on our parser's
  limitation would narrow the reader's synopsis for our reasons.
- **TSK / Nave's / Bible Outline (bwh34)** — **HAVE.** *(Corrected
  2026-09-07 — twelfth "grep it first" case, and §8 had already recorded
  the answer on 2026-08-22 without editing this row.)*
  TSK is `cross_references.json`. **Nave's Topical Bible** ships —
  5,322 topics, 29,379 lines, 77,974 references, imported by
  `tools/import_naves.py` from CCEL's ThML edition after two repair
  passes (`docs/DATA-INTEGRITY.md` check 42). Both halves are reachable:
  **verse-entered** in the Topics tab, and **browsable** as
  `lib/pages/naves_page.dart` under Resources (`workbench_page.dart:671`)
  with the entry list, the lookup box and the topic view bwh36_RWP
  describes. Bible Outline is `book_introductions.json` +
  `section_titles.json`.
  The general lesson this row is the second instance of: *"public domain
  and openly available" says nothing about whether the data is right.*
- **Read Text module (bwh53)** — **REJECTED.** Audio reading of the
  biblical text. TTS was built and removed at v1.3.19
  (`ui_strings.dart:4833`, `app_settings.dart:86`). Do not resurrect it
  without the owner asking. Distinct from #293 sermon audio, which is a
  different ask and is BLOCKED on hosting.
- **Bagster's Daily Light (bwh36)** — **REJECTED.** Devotional. Wrong
  product; that is YsWords' job.
- **External Resources Manager / Ermie (bwh32)** — **REJECTED
  2026-09-07**, and for the same reason as the External Links Manager in
  §3.3. Ermie indexes the PDFs, Word files and saved pages a scholar
  keeps OUTSIDE BibleWorks and makes them searchable from inside it.
  That is a **desktop file-system feature**: a browser tab cannot read
  the reader's disk and a tablet has no folder of PDFs to index. What
  this app has instead is the sermon library — 1,147 transcripts,
  searchable and reference-indexed — which is the same need answered
  with material we ship rather than material we point at. Re-open if a
  desktop build ever has readers who ask for it.
- **Report Generator (bwh28)** — **HAVE, 2026-09-07.** The row was right
  that we had "all the parts … and no assembly"; this is the assembly.
  `lib/utils/passage_report.dart` shapes and renders (Flutter-free, so
  the renderers are testable without assets),
  `lib/services/passage_report_service.dart` gathers, and
  `lib/widgets/passage_report_sheet.dart` is the surface, on the Tools
  menu beside Word List and Phrasing — bwh07's split, since a report
  OPERATES on the text in front of the reader.
  **One export path, as the row asked**: it leaves by
  `ClipboardHelper.copyRichWithFeedback`, an HTML flavour beside a
  Markdown one, and says honestly which of the two landed rather than
  claiming a formatting the reader will not find in the document.
  Markdown and not plain text because a report set with tabs looks
  assembled until the first proportional font.
  **The filters are the feature, and the default is one.** bwh28 filters
  by morphology and by frequency for the same reason: a report on
  Romans 8 that prints a lexicon entry for every καί is a phone book, so
  the sheet opens on words the corpus uses 50 times or fewer and
  "every word" is one chip away. A filtered report SAYS how many of how
  many, in both renderings — a short list must not read as a short
  passage.
  **It invents nothing.** Surface and parse from `assets/originals`,
  gloss from the Strong's lexicon in the reader's own language, count
  from the bundled concordance; a number the lexicon does not know
  prints no gloss rather than borrowing its neighbour's, and a word the
  concordance cannot count is KEPT by a frequency filter, because
  dropping it would answer a different question silently. The edition's
  licence line travels with the report.

### 3.6 Notes, copying, export

- **Copy / Copy Center (bwh27b)** — **HAVE**, `copy_center_sheet.dart`.
- **Export options, verse ranges, format choice** — **HAVE, 2026-09-07**,
  folded into the Report Generator above exactly as this row asked.
  The Copy Center (`copy_center_sheet.dart`) already held bwh28's ranges
  and bwh29's Output Format Options and already put a `text/html`
  flavour on the clipboard beside the plain one; what it did not have
  was a document worth that formatting. The report is that document, and
  both exits now run through `ClipboardHelper` — one path, which is what
  made this row a dependency of the other rather than a feature of its
  own.
- **User notes database** — **HAVE as a docked surface**, 2026-08-18.
  See 3.4. Notes are still exportable in both formats
  (`export_service.dart`), which now reads a verse key through the same
  parser the tab does.

### 3.7 Configuration, extensibility, input

- **Options / settings** — **HAVE**, and then some (`settings_page.dart`,
  3,313 lines; #281 flagged the size, #311/#315 fixed the type controls).
- **Book name abbreviations, version abbreviations** — **HAVE.**
- **Changing book order** — **REJECTED 2026-09-07.** bwh29 lets a reader
  reorder the canon. Two of the three reasons anyone does that are
  already answered here by something better: the Hebrew-Bible and
  Greek-Bible groupings are a first-class SEARCH SCOPE (#280's scope
  model, 希伯来圣经 / 希腊圣经), and version display order — the one
  ordering readers actually rearrange — is its own settled feature
  (#288, `version_stack.dart`).
  The third reason is real and is the only thing that would re-open
  this: the **Tanakh order** (Torah / Nevi'im / Ketuvim), which is not a
  preference but a different canon shape, and in which Chronicles ends
  the Bible. That is a canon variant rather than a drag-to-reorder list,
  it changes what "the next chapter" means at 24 seams, and it belongs
  with versification rather than with a settings row. Re-open it as
  *that*, with a reader asking for it, not as bwh29's list widget.
- **Compiling your own version database (bwh47)** — **PARTIAL,
  2026-09-07. The owner answered the question this was blocked on** —
  「做纯本地导入器」 — so it is being built, and the two things this row
  warned about are handled in code rather than left to the reader.
  *Landed:* `lib/utils/imported_version.dart` — the file format, the
  validator, and the two invariants. **A `user-` prefix on every
  imported code**, so an import called "KJV" becomes `user-kjv` and
  cannot shadow the bundled KJV; `bundledCodesAvoidImportedPrefix()` and
  its test keep the namespace clean. **A disclaimer, never a licence**:
  `aboutLicenseUserSupplied` says in all three locales that the reader
  supplied the text and this app has not verified its source or rights,
  which is the only honest thing it can say — and an imported code is
  kept out of `unrestrictedCopyVersions`, so the 500-verse copy ceiling
  applies to it as it does to the licensed editions.
  Validation is the substance and it refuses far more than it accepts:
  a bad shape, a book outside the canon (English or Chinese), a
  non-string text field, a chapter or verse that is not a positive
  number, a duplicate reference, a file larger than any Bible. It
  returns REASONS with the offending row or name, because the reader
  chose this file on purpose. 18 tests, including one that asserts the
  validator's canon still agrees with the app's own — the drift that
  would otherwise accept an import and then leave it unreachable.
  *What is left:* the STORE and the catalog wiring. The app has
  `shared_preferences` and nothing else, which on web is localStorage at
  roughly 5 MB — a New Testament or a single book fits, a whole Bible
  does not, and a store that failed silently at the quota would be worse
  than no store. So the remaining work is a persistence tier
  (IndexedDB through `package:web`, which is already a dependency and
  which `fetch_helper.dart`'s conditional-export pattern shows how to
  reach), plus making `bibleVersions` / `isKnownVersion` /
  `loadableVersions` admit a code that is not a compile-time constant.
  *Local only remains absolute*: no upload, no share, no sync, and
  nothing in the shipped half could add one.
- **Custom modules (bwh48)** — **ABSENT, following bwh47.** Same shape,
  for reference works rather than Bibles, and it inherits the same
  question — a commentary or a dictionary is copyrighted the same way a
  translation is, and the app's own bundled ones (BDB, Thayer, JFB) are
  public-domain or permissioned for exactly that reason. Whatever bwh47
  is answered with, this follows it; there is nothing separate to decide
  and no reason to decide it twice.
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
- **Keyboard shortcuts (bwh44)** — **HAVE, 2026-09-07.** *(The row also
  claimed Ctrl+L; there was no Ctrl+L. Only Ctrl+Shift+C and Esc
  existed.)*
  `lib/utils/keyboard_shortcuts.dart` is the table, and it is the SAME
  table the handler dispatches from and the sheet prints — including the
  key names, which `WbShortcut.label` builds rather than anyone typing
  them twice. A sheet maintained beside the handler starts true and
  stops being true the first time somebody adds a key, and the reader is
  the last to know. `WbShortcutId` is an enum so the handler's switch is
  exhaustive: adding a row does not compile until something answers it.
  Four chords — jump to the command line, Copy Center, passage report,
  and F1 for the list itself — on Help and on F1, which is what
  *"a shortcut nobody can find is not a feature"* asked for.
  **Not bwh44's function-key set, deliberately.** F1–F12 is a
  Windows-desktop idiom; F3/F5/F6/F11/F12 belong to the browser and this
  app's device is a tablet with no function row. F1 survives because
  help is what F1 means everywhere. Plain Ctrl+C stays the browser's,
  and Esc is documented on the sheet but NOT in the table — it unpins
  without consuming the key, so a dialog, a text field and the browser
  all keep their own.

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

**Verdict: every asset is declared, and every SERVICE is reached. That is
what this audit established, and on 2026-09-05 it turned out not to be
enough.**

Audited 2026-08-12, three ways (present on disk / declared in
`pubspec.yaml` / referenced from `lib/`). Those three checks stop at the
service boundary: a service can be referenced from `lib/` while a whole
public branch of it has no caller. Re-checked per MEMBER on 2026-09-05,
three did — `ModernConcordanceService.topics()` (the entire 341-topic
index), `GreekStatsService.books()` and with it the AOSurvey attribution,
which is assigned nowhere else, and `SynopsisService.byVerse`.

The old verdict line read "fully landed, nothing is sitting unwired". It
was true of assets and false of the reader's experience, and the table
below cannot tell those apart — **re-run
`test/data_surface_reachability_test.dart` rather than re-deriving this
table**, because that test audits the axis this one is blind to.

Every asset produced by the six `tools/import_eaglesview*.py` scripts is
declared and its service reached:

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
- ~~The `nsn-plus` mention in `tagged_text_service.dart:164` is a
  **stale comment**~~ — **removed 2026-09-05**, next time that file was
  open, as this entry asked. It was in a "measured over the shipped
  assets" list, and nsn-plus is not shipped: the tagged editions tracked
  in git and declared in `pubspec.yaml` are bsb, cuvs-plus, cuvs-yhwh,
  kjvs and lxxwh, and nothing else. Struck rather than re-measured, and
  the comment says so.

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

**2026-09-07 — the owner made this document the GOLDEN TASK.** His
words: 「sword包含eaglesview和BibleWorks所有的功能,涉及license的不用抄但是
可以学并且Document住,一旦完成这个任务,这两个APP就可以free掉放在T7里面」and
「这个作为golden task先high priority做完」.

Three things follow, and they change how this file is used:

* **§3 is the register of the whole task**, and finishing it is what
  releases both applications to the T7. §4 (Eagle's View) is closed.
* **Licence-gated entries are still deliverables** — the instruction is
  *不用抄但是可以学并且Document住*. Mark them `REJECTED`, write down what
  the feature is and what it would take, and that entry is done. Nothing
  from the ISO is imported; the extracted help is a specification, which
  is what makes this lawful. Louw-Nida, HALOT, BDAG, TDNT, CNTTS and
  Tov-Polak stay out.
* **An entry is finished when the verdict here is honest**, not when
  something ships under its name. Correcting an entry that describes the
  wrong feature is worth more than building it — see §3.1 Cross-version
  searches, where the recorded *Done* criterion was a feature BibleWorks
  does not have.

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

   And a defect for #301 rather than this ticket: **truncated
   `etymology` fields in the Chinese module** — H2775 reads
   `charcah (khar'- saw`, G1537 stops mid-clause.

   ~~28 of the 14,696 entries, detectable by an unbalanced parenthesis;
   the importer split a field on a delimiter that also occurs inside the
   parentheses.~~ — **FIXED 2026-08-23, and both halves of that sentence
   were wrong.** The module stores one `<p>` per *visual line*, so any
   field that wrapped was cut wherever the printed page broke; the
   parenthesis test could only see the few breaks that happened to land
   between a bracket and its partner. Real scope: **468 etymologies and
   1,635 usage fields**, and 468 entries were serving the missing half of
   an etymology to the reader as a numbered sense. `split_entry` in
   `tools/import_yahweh_modules.py`; `docs/DATA-INTEGRITY.md` check 44.
   *An instrument that can only reach 0.2% of a defect will report 0.2%
   and sound precise.*
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
