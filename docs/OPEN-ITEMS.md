# OPEN-ITEMS.md — what is not done

One register for everything outstanding: bugs, unfinished work, decisions
waiting on the owner, and operational landmines. Written 2026-09-04 for a
handover, because the answer to "is all of it written down?" was **no** —
several items below appeared in no document in this repository at all.

**Every item carries a verification status.** `[verified 2026-09-04]`
means it was checked against the tree on that date. `[carried forward]`
means it comes from an earlier note and the check has NOT been redone —
treat those as leads, not facts, and verify before acting. Nothing here
is asserted more strongly than it was checked.

**A `[verified]` tag is a claim like any other.** A 2026-09-05 re-read
found two entries listing shipped work as open — one of them carrying a
`[verified 2026-09-04]` tag it had not earned. Both are struck, with
their evidence, under *Withdrawn* at the foot of this file. Every other
`[verified 2026-09-04]` tag here was re-checked against the tree on
2026-09-05 and still holds; the dates are left as first checked.

**That last sentence did not survive the afternoon, and the way it
failed is the more useful lesson.** A second 2026-09-05 pass found two
more entries wrong. The `main.dart` O4 items were re-checked *against
the tree* and passed, because the code they name does still exist — what
had changed was that it had been reworked on 2026-09-02/03 under
different names, and re-reading the entry alongside the code would have
caught what re-grepping for its nouns could not. The strip lane-heading
entry passed because its supporting test passed, and the test was
measuring the **Flutter test font**, in which every glyph is a full em
box: the 221 px it reported was 17 characters × 13 px, roughly double
the truth for Latin, and it named the one English heading with room to
spare. **A green test is not a measurement of the shipped app**, and
`[verified]` should say what instrument was used.

`PROJECT_STATE.md` remains the queue for work being actively scheduled.
This file is the complete picture, including things nobody has scheduled.

---

## Bugs

### The reading pane renders no verses when the book's language and the version's corpus disagree `[CLOSED 2026-09-05 — every path walked]`

The register kept this as a lead with the note "not verified in this
pass". It was verified on 2026-09-05, by walking every writer of
`currentVersion` and `currentBook` rather than by reading the pane. The
pane was never the place: `bible_reading_pane.dart` filters by
`currentBook` and is right to: what could be wrong is whoever set it.

| path that can cross a language boundary | how it is answered | since |
|---|---|---|
| the version menu, cold path | `setVersion` → `_realignBookTo` | pre-existing |
| the version menu, warm cache | `translateBookName(prevEn, version)` before `setCurrentChapter` (`bible_reading_pane.dart`) | pre-existing |
| a shared link with `?v=` | `_applyHashToState` swaps the version FIRST, then translates and verifies the chapter exists | v1.3.61 |
| boot, restoring a saved book | `_realignBookTo(currentVersion)` **after** the saved book lands | 2026-09-05 |
| the workbench's second column | `_followPrimary`, matched through English | v1.6.47 |
| **Split View's second column (`home_page.dart`)** | **it did not** — see below | fixed 2026-09-05 |

The boot row is the one that made this reproducible without touching a
version menu at all: `_realignBookTo` used to be called inside
`restoreState`'s `savedVersion != null` branch, where `currentBook` is
still null, so its own first line returned every time and the boot path
realigned nothing. An `en`-locale reader carrying the old default
(`cuvs-yhwh`, books keyed 创世纪) through the v1.3.46 migration got
`bsb` with 创世纪 still in hand, and `versesInChapter('创世纪', 1)`
matches nothing in a corpus keyed on Genesis — a blank pane on the first
frame after an upgrade.

The last row is the same defect one surface further out, found the same
day and not previously written down anywhere. `_activateSplitView`
seeded the second column with `sp.verses.firstWhere((v) => v.book ==
primary.currentBook && …, orElse: () => sp.verses.first)` — a RAW
comparison between two editions' book names. Measured on the shipped
assets, `cuvs-yhwh.json` keys 31,102 verses on 创世纪 / 约翰福音 and
`bsb.json` (31,086), `kjv.json` (31,102) and `leb.json` (31,199) key
theirs on Genesis / John, so it matched nothing whenever the columns
were in different languages — which is the case Split View is FOR — and
the `orElse` then answered Genesis 1. A reader on 约翰福音 3 got a second
column on Genesis 1, scrolled to Genesis 1:16 by the verse-number
restore. The rule now lives in `lib/utils/chapter_across_editions.dart`
and both split surfaces call it;
`test/chapter_across_editions_test.dart` pins the rule. It also reads
both pages' source, and on 2026-09-06 that half was measured against
the defect restored with its operands reversed (`pb == v.book`) and one
mention of the shared function left in a comment: **all three
assertions passed**. That sentence — "pins the rule and the wiring" —
is what let the group go unexamined, which is why it is quoted here
rather than deleted.

Rewritten: comments are stripped before matching, each call is anchored
in an assignment, and `isNot(contains('<exact old text>'))` is now
disallowed outright in that file — it is a blacklist of one item from
an infinite set, defeated by reordering operands, renaming a local, or
running the formatter.

It still cannot prove behaviour. The real pin is a test that drives
`_activateSplitView` — SharedPreferences plus two parsed corpora plus a
layout pass — and it does not exist. A repo-wide `grep -n "isNot(contains" test/`
is a cheap follow-up: only the two files touched that day were swept.

Not shown on a device. Everything above is read from the tree and from
the assets, and the *symptom* was reported on prod; if it recurs, the
list of paths above is what to re-walk.

### The verse picker can open on a stale chapter `[CLOSED 2026-09-05]`

It did share the bug, and it was neither of the two causes YsWords
found. `currentVerse` is the workspace cursor and the reading pane's
header opens the picker at `currentVerse.book` / `.chapter`, not at
`currentBook` / `currentChapter`. Every in-app caller of
`setCurrentChapter` pairs it with `updateCurrentVerse`; one did not —
`url_sync_service_web.dart` moves the reference from a hash and touches
the cursor only when the link carried a `:verse`. So a chapter-only
link, and browser Back or Forward onto a chapter-only history entry,
moved the reference and left the cursor behind, and the reader's own
`PageView` could not repair it because `onPageChanged`'s
`if (idx == currentChapterPageIdx) return` gate fires against a provider
that has already moved.

Fixed in the provider rather than at either end, so no future caller can
perform half the move: `MainProvider._settleCursorInCurrentChapter`,
pinned by `test/chapter_cursor_settle_test.dart`.

### Two English lane headings truncated on the strip at phone width `[FIXED 2026-09-05 — and the old entry was wrong]`

**The 2026-09-04 entry named the wrong heading and its number was an
artefact.** It said `Genesis lifespans` "wants 221 px, which is 59% of a
375 px screen". 221 is 17 characters × 13 px: it was measured under the
**Flutter test font**, in which every glyph — Latin or Han — is a full em
box. That is correct for Han, which really is one em per glyph, so the
Chinese half of `test/strip_header_column_test.dart` was sound by
accident; it is roughly double the truth for Latin, and the test's
English assertion was a false witness that passed.

Re-measured 2026-09-05 in the bundled Roboto at the size and weight the
painter actually draws (`headingFontPx` = 12 × 1.15 = 13.8,
`FontWeight.w600`), against the 134 px a heading gets inside the 150 px
column at 375 px:

| heading | width | verdict |
|---|---|---|
| `Events` | 41.3 | fits |
| `Genesis lifespans` | 109.6 | fits, 24 px spare — **the entry's example was the one heading with room** |
| `Prophets & apostles` | 124.7 | fits |
| `Peoples & institutions` | 135.5 | **over by 1.5** |
| `Kings of Judah & Israel` | 142.9 | **over by 8.9** |

So it was two headings, and neither of them the one on record.

**The wording decision the entry was waiting on has been taken** (ruling
by Fable 5.1, 2026-09-05, on the measurements above):

> At default type on a 375 px phone the sticky lane column gives a
> heading 134 px, and measured in the bundled Roboto face two English
> headings overflow it: "Kings of Judah & Israel" (142.9 px) and
> "Peoples & institutions" (135.5 px); the earlier claim that "Genesis
> lifespans" truncated came from the Flutter test font and was wrong.
> The kings heading becomes "Judah & Israel kings" (125.3 px) because
> the kingdom names are drawn nowhere else on the strip — the two
> sub-lanes differ only by hue — while "Judah & Israel" alone would
> duplicate two band names in the streams group directly below. The
> streams heading becomes "Peoples" because no wording containing
> "institutions" fits with margin, "powers" would be false for the
> Scripture and Elsewhere bands, and the three non-people bands carry
> their own names in the lane, so the dropped word is recoverable in
> place. Chinese strings and the other three English headings fit and
> are unchanged; candidates under ~8 px of Roboto margin were rejected
> because the default font is the system face, and the ellipsis remains
> the backstop for reader-chosen wider fonts.

Applied in `lib/constants/strip_strings.dart`.
`test/strip_header_column_test.dart` now loads the faces this app ships
(Roboto, Noto Sans SC) and requires 8 px of clearance rather than
asserting a truncation.

**Still open, small:** the ruling notes the kings heading clears by 8.7
px in Roboto, which is at the threshold, and asks for one re-measure in
San Francisco before this is called finished. No test can do that — the
system face is not a file in this repo — so it needs a screenshot of the
strip on the iPhone at 375 px.

---

## Unfinished features

### The chart index is closed — 786 headwords, not 784, and none undispositioned `[measured 2026-09-05]`

**Neither number in the old entry reproduces**, and the per-section
figures it listed (Israel 80, Americas 56, …) do not reproduce against
any file in the audit either.

The index has **786** distinct headwords — `extract/index.merged.tsv`,
885 rows → 833 non-`?` → 786 distinct, the same under case-folding and
NFKC, and the audit's own `DRAWN-LAYER.md` says 786 too (its `README.md`
says 794, also wrong). Every one is covered, placed, or refused with a
stated reason across the five index passes, and **196 of the 197 records
those passes proposed had already shipped**; the one that had not (the
judges era as a band) shipped 2026-09-05.

**How the number got here matters more than the number.** The 462 was
written at 2026-09-03 08:25. Three of the passes that closed it ran
*later the same day* — 15:41, 15:59, 19:04. This register was created the
next morning and carried the figure forward under `[verified 2026-09-04]`.
The tag was false: the number was copied, not re-measured. That is the
failure mode this whole file exists to prevent, and it happened on the
day the file was written.

**What is actually open is the annulus, and it now has a price.** The
Sirach prologue (132 BC, the earliest witness to a threefold Hebrew
canon) was fully researched and written and is deliberately NOT on the
wheel: adding it takes `wheel_label_legibility_test.dart` to **61 whole
Chinese names at 900 px against a floor of 62**, and dropping either
modern 2026-09-05 addition instead does not recover it — the crowding is
at 132 BC. Its absence is now an assertion in
`test/wheel_coverage_2026_09_05_test.dart`. The floor is what has to move
first, and `wheel_label_legibility_test.dart` says so in its own words.

### The wheel was drawing four events twice `[verified 2026-09-05]`

Found by the same pass, all four shipped and all four green under 4,470
tests: `einstein_relativity`/`special_relativity` (both 1905, on
different rings), `wright_first_flight`/`powered_flight` (both 1903
Kitty Hawk), `movable_type_china` 1040 / `bi_sheng_movable_type` 1045
(**same ring**, and 1040 falls outside the 1041–1048 window Shen Kuo —
the only source either cites — actually gives), and a record titled
"Columbus Reaches the Americas" whose id and description say Columbian
Exchange, dated to a round 1500 that no reference states.

De-duplicated: events 747 → 745, powers 226 → 231. **This is the "a green
suite is not a legible screen" trap in its data form** — no test can see
that two records describe one event, and none did.

### `main.dart`'s three O4 items — all three answered `[re-checked 2026-09-05]`

The cold `#/wheel` that only began loading its 131 KB asset at push time
is fixed. **The other two were re-checked on 2026-09-05 and the entry
above them was stale**: both had been reworked on 2026-09-02/03, and the
reason a grep for them came back empty is that neither lives under the
name this entry gave it.

- **The boot-page latch is gone, deliberately.** `_applyHashToState`
  used to record the boot path so `main()` could re-open the page after
  the splash. A page path is an INITIAL ROUTE now
  (`appGenerateRoute`), created by the Navigator once per document at
  the first frame, and the recording API was deleted along with the
  post-splash push — so a cold-open push cannot quietly come back
  without someone re-adding it.
- **The early return on popstate still exists, and is now the
  documented rule rather than an accident.** It is
  `urlMayDriveReader(path:, isBoot:, claimedPath:)` in
  `lib/utils/url_claim.dart`, a pure function with two stated reasons
  to refuse a hash (it names a page, not a passage; or a page owns the
  address bar, which is what browser Back off the wheel delivers) and
  an explicit exemption for boot, which is the one apply that must not
  be droppable. `test/url_claim_test.dart` covers it.

Nothing here is open. Left in the file rather than struck, because
"O4 item 2 and 3" is how these are referred to elsewhere and a reader
who finds the old phrasing needs to land somewhere.

---

## Decisions waiting on the owner

- **The NASB.** Shipped in the assets but hidden — `disabledVersions` is
  `{nasb}` and nothing else. The text is FROZEN: a defect in it gets
  reported, never corrected. Whether it can be shown at all is a
  licensing question nobody has answered. `[verified 2026-09-04]`
- **Whether the Reader becomes a workbench mode** rather than a separate
  surface. `[carried forward]`
- **Shortening the English strip lane headings** (above).

---

## Operational landmines

### The iOS provisioning profile expires weekly `[verified 2026-09-04]`

Free tier. The profile for `com.example.yahwehswords` was issued
2026-09-04 and expires **2026-09-10T23:44:06Z** (2026-09-11 AEST). When
it lapses the app stops launching on the iPhone and iPad and needs
`tools/release_native.sh` run again. Device registration itself persists.

### `tools/yswords-ios-reinstall.sh` builds the wrong app `[verified 2026-09-04]`

A fork leftover. Its `PROJECT=` is hardcoded to
`/Users/pliu0036/Documents/yswords`, so running it from this repository
builds and installs **YsWords**. Nothing invokes it — every other
mention of the filename is a comment. Delete it or repoint it; leaving
it is the hazard.

**Re-checked 2026-09-06, and it is worse than "wrong app".** Nothing
invokes it; **no launchd job anywhere points into this repo**; and the
copy here is 414 lines against the parent's current 1218 — a stale
snapshot rather than a script missing a footnote. There is also no test
guarding it: the `test/apk_freshness_guard_test.dart` that was believed
to lift functions out of it **does not exist and never has**
(`git log --all` finds nothing), so it is entirely free to change or
delete.

Ruled: delete. Repointing it would create a second hand-run install path
beside `tools/release_native.sh`, which already derives its project root
from its own location and cannot have this bug — and the TCC constraint
above means this file could never become the scheduled artifact anyway.
**Awaiting the owner's call**, because deleting a tool is a product
decision rather than a bug fix.

### ~~The native identity was never rebranded~~ `[REFUTED 2026-09-06]`

It was rebranded, on 2026-08-23, in `0def09c` — whose subject line says
so: *"feat: plain 'AI' labels + standalone native identity (Yahweh's
Swords)"*. That commit moved `com.example.yswords` to
`com.example.yahwehswords` across Android (namespace and applicationId),
iOS (six places) and macOS (xcconfig and both entitlements), and moved
`MainActivity.kt` between package directories.

Three ids, verified in each tree, no collision: Sword
`com.example.yahwehswords`, Words `com.example.yswords`, World
`com.yswords.yahwehsworld`. `README.md:126` is wrong twice about this —
it calls `com.example.yahwehswords` "YsWords' own app identity", which it
is not, and says the no-collision claim "was never actually true", which
it is. The display name is not a leftover either: `brand_marks_test.dart`
records SeekSparks as the RETIRED mark deliberately.

The only genuine residue is the `com.example.` template prefix, and it
must stay — Android treats a new applicationId as a different app and
changing it would orphan every installed copy.

### The English iOS home screen said "Yahweh's Swords" for twelve days `[FIXED 2026-09-06]`

Found while refuting the entry above, which is the useful part: the
rename to the singular (`8613b3a`, 2026-08-25, *"owner-requested,
singular"*) touched 11 files and **zero `.lproj` files**.

`ios/Runner/en.lproj/InfoPlist.strings` kept `"Yahweh's Swords"`. It
ships — `en` is in `knownRegions` and the file is in the
`InfoPlist.strings` variant group in the Resources phase — and on iOS a
localized `InfoPlist.strings` **overrides `Info.plist`**. So for twelve
days an English iPhone showed the plural on its home screen while the
Android phone beside it showed the singular.

This is the same failure class `brand_marks_test.dart` was written for,
one layer below where that test looks. `test/native_display_name_test.dart`
now guards all seven carriers, and restoring the plural fails two of them.

### No scheduled iOS reinstall for this app `[verified 2026-09-06]`

Both sibling apps have a daily launchd job; this one has none, and the
provisioning profile lapses every seven days — so the two items are the
same problem seen from two ends.

If one is ever set up, the script must live under
`~/.config/seeksparks/scripts/`, **not in this repo**: a plist comment in
the siblings records that launchd is TCC-blocked from reading
`~/Documents`, which is why both of them run copies from `~/.config/`.

### `LICENSE` states the sermons' rights but not their authorship `[revised 2026-09-05]`

**This entry overstated the problem and is corrected here.** It said the
notice "credits the wrong person". It does not: `© Liang Jia-keng, used
with permission` is a *rights* claim, and the comment above
`aboutLicenseSermons` (`lib/constants/ui_strings.dart:5030`) already
reasons this through — who preached and who holds the rights are two
different facts, and only the first is settled. Liang Jia-keng may well
be the party who granted permission, which would make the © line
correct. Nothing in the repo establishes it either way, and deleting a
rights claim on a guess is worse than carrying an unverified one.

What the notice was actually missing is the settled fact: the corpus was
built by `scripts/ingest_sermons.py` from Pastor Eric H.H. Chang's
(张熙和牧师) sermon tree, and every body file is his preaching — see
`lib/constants/sermon_credit.dart`. **Done 2026-09-05:** `LICENSE` now
states the authorship alongside the unchanged © line, and points at the
`ui_strings.dart` note.

**Still open, and needs the corpus owner, not a developer:** confirm
whether Liang Jia-keng is the rights holder / permission grantor for the
sermons. If he is not, both the `LICENSE` line and `aboutLicenseSermons`
(which is user-visible, in three locales) are wrong together and must
change together.

### ~~A scratch harness is committed into the test suite~~ `[CLOSED 2026-09-06]`

`test/zz_measure_test.dart` — 51 lines, zero `expect(`, two `print(`,
running on every CI job and unable to fail — is deleted (staged with
`git rm`, not committed).

Deleted rather than converted, because converting would have duplicated a
test that already exists: `wheel_lifespans_test.dart` asserts every
number this harness printed, as legibility FLOORS with reasons rather
than as a census. Floors are properties and survive data changes; a
census pinned to `hebrew_kings.json` would have collided with the kings
work landing the same day. Mutating `ringPitch` fails three of those
floors, which is the proof that deleting the harness lost nothing.

### `output/` is somebody else's work, sitting in this checkout `[verified 2026-09-05]`

3.7 MB in two files — `output/pdf/神要开道路_G调和弦版.pdf` and
`output/imagegen/神要开道路_G调和弦版.png` — a Chinese worship song's
chord chart. It is **not** this project's: the PDF names ReportLab as
its producer and stamps `D:20260811144203+10'00'`, matching both files'
mtimes, and `reportlab`, `imagegen` and the song title appear nowhere in
this repository. Some other tool ran with this checkout as its working
directory and left its output behind.

It was untracked **and unignored**, which in a shared checkout is one
careless `git add` from being committed. `.gitignore` now covers
`output/`, with the same explanation. Nothing was deleted or moved —
it is the owner's document. **Move it somewhere it belongs and delete
the `.gitignore` entry with it.**

### The chart audit lives outside this repository `[carried forward]`

Roughly 25 unresolved judgement calls from the printed-chart audit are
in `~/Documents/CodingProject/SeekSparks-chart-audit/`, which is **not
under git**. It is not backed up by anything this repository does. The
source chart is under active copyright: it is used as a coverage
checklist only, every fact is re-sourced independently, and its wording
is never copied or quoted.

---

## Tickets

`#301`, `#304`, `#309`, `#312`, `#317`, `#318` are referenced throughout
`PROJECT_STATE.md` and `HANDOFF.md` with their current state. `#309` (124
CDC sermon titles) is the one least narrated in either file. This
register does not duplicate them — search those two files by number.

---

## Withdrawn — items this file wrongly listed as open

Kept as a record so nobody re-adds them from an old copy. Both were
removed on 2026-09-05 after re-reading the tree; each line below names
the code and the commit that closes it.

### "Three of the Eagle's View imports have no user interface"

Listed 2026-09-04 as `[verified]`; **false**, and two of the three
already had UI when the tag was written, so the tag was never earned.

| import | where the reader reaches it | landed |
|---|---|---|
| Thayer's lexicon | `lib/widgets/word_analysis_pane.dart:38` (`ThayerService`), plus its own screen `lib/pages/lexicon_page.dart`, pushed from `lib/pages/workbench_page.dart:614` | `70bd2ae` 2026-08-07; the Lexicon Browser `1542a74` / `1db3890` 2026-08-23 |
| Bible names (Hitchcock) | inline in `lib/widgets/word_analysis_pane.dart` — lookup `:184`, render `:518`, attribution `:619` | `70bd2ae` 2026-08-07 |
| Places | `lib/widgets/places_pane.dart` is an analysis tab (`workbench_page.dart:2540`); `lib/pages/atlas_page.dart` is pushed from `workbench_page.dart:332`, `:597` and `:2551` | pane `55772db` 2026-08-08, atlas `4f4858a` 2026-08-09, journeys `80ca89d` 2026-09-01 |

### "The Modern Concordance was never imported"

Carried forward unchecked; **false**. It was imported in two deliberate
stages, which is why a single-script check missed it:

1. `tools/import_eaglesview_modern_concordance.py` writes to
   `build/restricted/` and *refuses* to write under `assets/` without
   `--acknowledge-rights` (script lines 197-200). Landed `790edba`
   2026-08-07.
2. `tools/build_concordance_assets.py` joins that blob into
   `assets/concordance/`. Landed `34bef43` 2026-08-07, together with
   the assets and the service.

370 files under `assets/concordance/` are tracked in git, declared at
`pubspec.yaml:148-150`, read by `lib/services/modern_concordance_service.dart`,
and surfaced as the Topics tab (`lib/widgets/analysis_tabs.dart:306`,
`:1202`).

---

### Both withdrawals above are correct. The instrument behind them was not. `[2026-09-05]`

They were checked the way `docs/PARITY-BACKLOG.md` checks this axis — on
disk / declared in `pubspec.yaml` / referenced from `lib/` — and **that
stops at the service boundary**. A service can be referenced while a
whole public branch of it is dead.

Re-checked per MEMBER, three Eagle's View data branches had **no caller
anywhere in `lib/`**:

| orphan | what the reader lost |
|---|---|
| `ModernConcordanceService.topics()` | the entire 341-topic index — no entry by topic name, dead since `34bef43` |
| `GreekStatsService.books()` + `BookVocabulary` | the 27-book profile, **and the AOSurvey attribution**, which is assigned nowhere else |
| `SynopsisService.byVerse` | verse-level OT parallels — found by the new ratchet on the day it was written |

So "three of the Eagle's View imports have no user interface" was **false
as written and pointing at something real one level down**. The count was
right by accident.

The second one is a rights defect rather than a cosmetic gap: four of the
five Eagle's View reference imports render their credit, and the fifth —
**the one that is permission-granted rather than public domain** — had
the empty string.

Disposition: the concordance index is closed by
`lib/pages/modern_concordance_page.dart`; the 27-book table is DECLINED
with reasons (`stats_page.dart` already prints per-book running words and
distinct lemmas for all 66 books from the app's own tagged text, so a
second table would restate two columns with *different* numbers); the
verse-level synopsis stays open. All three are recorded in
`test/data_surface_reachability_test.dart`, which fails if any regresses.

**One measurement worth keeping**: 239 of the 341 concordance names are
compounds (`Catch - Seize - Steal`), so Nave's whole-headword prefix rule
answers `seize` with **zero**. Matching had to be per-segment and
bilingual — `爱` reaches 3 topics no English query finds.
