# PROJECT_STATE.md — SeekSparks, the state of the work

The single compact answer to "where is this project right now". Written for
whoever picks the work up next: the unattended loop, another Claude session,
or the owner after a week away.

**This file is maintained by the loop, every iteration, as part of SHIP.**
It is tracked in git, so its history is the project's history. Keep it
SHORT — one line per item. Narrative belongs in `HANDOFF.md`; the long
ticket briefs belong in the loop's `prompt.md` and, once closed, in
`prompt-archive.md`. If this file grows past ~150 lines it has stopped
doing its job.

Last updated: 2026-08-24 (eleventh entry)

---

## Where the build is

| | |
|---|---|
| `pubspec` / dev | **1.6.168** — #315's seventh pass: the frozen sizes inside the two files the ratchet calls `finished`. Built and deployed 2026-08-24 from a **detached worktree at the pushed SHA** (`d18018b`), the shared tree carrying the second writer's untracked `output/`. **Alias and immutable URL both serve `1.6.168`** (`version.json`, cache-busted on each). Deployed although this was only undeployed loop iteration 2 of 3, because #315 is a **human-reported** defect and the standing rule exempts those from the counter. Before it, **1.6.167** — #315's sixth pass: the book label that could not grow past its tile. Built and deployed 2026-08-24 from a **detached worktree at the pushed SHA** (`37c4bb2`), the shared tree carrying the second writer's untracked `output/`. **The alias serves it** — `version.json` reads `1.6.167`, cache-busted. Before it, **1.6.166** — #315's fifth pass: the sermon title that shrank below the sermon. Built and deployed 2026-08-24 from a **detached worktree at the pushed SHA** (`ab7eef7`), the shared tree carrying the second writer's untracked `output/`. **Alias and immutable URL both serve `1.6.166`** (`version.json`, cache-busted on each). Before it, **1.6.165** — #295's grammar audit: three wrong search counts fixed. Built and deployed 2026-08-24 from a **detached worktree at the pushed SHA** (`9384762`), the shared tree carrying the second writer's untracked `output/`. Alias serves it (`version.json` reads 1.6.165), and the deployed `main.dart.js` carries the new `The word gap after` refusal — checked against a control string known to ship, since a bare absence in that bundle proves nothing. Before it, **1.6.164** — released by the **second writer**, not the loop: branding/launcher-icon fixes and the splash download bar (`983c0ea`…`200cfdf`, 13:27–14:22). Its build ran against the shared working tree and so also carries the loop's then-uncommitted #317 work; see the `main` row. Before it, **1.6.161** — #312 item 7: the four phrasing level chips now carry the line count they would draw on this passage, and the chosen one says what it cuts at. Built and deployed 2026-08-24 from a **detached worktree at the pushed SHA** (`ccfafc1`), the second writer having released 1.6.160 from the shared tree twenty minutes earlier. Alias and immutable URL both serve `1.6.161` (`version.json`, cache-busted). Previously: **1.6.159** — #315's fourth mechanism: `workbenchTheme`, the app's only theme, sized every Material role from constants. Built and deployed 2026-08-24 from a **detached worktree at the pushed SHA** (`01b5c80`), because the second writer's 106 modified launcher icons and an untracked `output/` were live in the shared tree and `release_web.sh` builds from the *working tree*. **The alias serves it this time** — unlike v1.6.158, which a second writer's build overwrote 83 seconds later; `version.json` and the in-app status bar both read 1.6.159, checked after a second cache-busting navigation to defeat the service worker |
| prod (seeksparks.netlify.app) | **1.6.136** — 21 versions behind, by design: prod ships only on the owner's word |
| `main` | **3f42bff** — #315's SEVENTH pass, and two more mechanisms: **the frozen sizes were inside the two files the ratchet calls `finished`.** Six passes built three detectors (a literal, a saturating clamp, a correct size in a `FittedBox`); both new mechanisms are invisible to all three, and `originals_sheet.dart` and `word_distribution_table.dart` were carrying them the whole time while the test certified them clean. **Sixth: a design constant wearing a principled name.** `fontSize: WbMetrics.text` names the app's own type scale, so it reviews as the fix, and is exactly as deaf as `fontSize: 12` — `WbMetrics` holds the sizes AT THE DEFAULT, only `WbType` multiplies them. **14 sites; 5 were the workbench's own empty states**, one of them `_analysisHint`, the placeholder for **eleven** analysis tabs called from **thirteen** places — so a reader at 40 pt was told what to tap at 12 px in every tab. **Seventh: a literal on the far side of a question mark.** The regex anchored the number to the colon, so `_st.dense ? _st.body : 13` hid one token away (4 sites in `originals_sheet`, all MODAL, one a **lemma** at exactly `originalFloor`); and the ceiling detector required a NUMERIC offset, so `(fontSize - (compact ? 4 : 2)).clamp(11, 15)` and `(fontSize - (prominent ? 1 : 3)).clamp(10, 16)` were **saturated at the DEFAULT on BOTH branches**. **A third hole:** the clamp test looked for `fontSize` only in the 60 chars *before* the match, so a clamp bound to a local (`final fs = …`, then `fontSize: fs` fifteen lines later) was invisible — that alone hid `confidence_badge.dart`. **All four detectors confirmed to FIRE** by reverting their sites; the three new behaviour tests confirmed to fail pre-fix (contact line **15 px at 40 pt, should be 30**; badge **16, should be 32**; hint **19, should be 12**). The distribution table needed its **geometry** scaled too, not just its font — its numeric cells sit in a `FittedBox`, so a bigger font in an unchanged column is scaled straight back down. Also: `analysisEmptyHint` was rendered **twice at two sizes** (19 inline vs 12 via `_analysisHint`); de-duplicated. **The instrument needed repairing first:** `Text.rich(span)` wraps rather than paints `span`, so `richText.text.style.fontSize` reads the inherited `DefaultTextStyle` — it reported the **already-repaired** `ContactLine` as frozen at 14.0 px at 12, 20 AND 40 pt. Not measured, and said so: the distribution table's services never resolve under `flutter test`, so that change is source-verified only. Residue: **32 ceilings / 12 files + 41 literals / 8 + 9 named constants / 1**. Undeployed loop iterations: **0**. Previously **fffae59** — #317: the Lord's itinerary, as Mark tells it — and **a region's coordinate is a city's**. The wilderness route found a join that fails by succeeding; this is its sibling and it is wrong rather than merely silent. `Judea` is Jerusalem's own point, `Decapolis` is Damascus, `Galilee` is byte-identical to Nazareth, `Dalmanutha` is byte-identical to `Magadan` (Matthew's identification, not Mark's word), `Gethsemane` and `Golgotha` are Jerusalem exactly, and `Jordan` is one point for a 250 km river. Mark names all of them; **eight are omitted** and the `basis` says why. The route is **one evangelist, never a harmony**. Sidon is the single provisional stop because **our own BSB and KJV disagree** about whether 7:31 puts him there. **No sea leg at all** — every Markan crossing touches a place with no usable coordinate — and a test fails the build if one appears. The sixth route also spent the channel `journey_style.dart` had reserved for it since v1.6.134: **`JourneyMark`** (round=Acts, square=Torah, diamond=Gospels), equal-**area** not equal-radius, verified by rasterising and counting pixels; identity is now a (hue, shape) PAIR so Mark reuses slot 0's amber. Two defects fixed on the way: the journeys block grew with the DATA and overflowed a 320×640 pane by 34 px at route six (now capped against the pane); and the straight-line band asserted 500..20000 km, which would have rejected Mark's 478.6 km **for being the right size** — now a pinned total per route. **Not deployed, as a stated decision.** Undeployed loop iterations: **1**. Previously **37c4bb2** — #315's fifth MECHANISM, not a fifth file: a size that is wired correctly and moves at all 29 stops, inside a `FittedBox` inside a grid cell sized from the MENU scale. `book_chapter_picker.dart` wrote `fontSize: settings.fontSize * 1.15` and `Jonah` painted **44.0 px wide at 20 pt and 44.0 px at 40 pt**; **62 of the 156 shipped abbreviations were already at maximum painted size at the DEFAULT** in the 280 px sidebar. Invisible to a source ratchet (nothing is wrong with the source) and to every existing behaviour test (they read the DECLARED size, which is correct); only `tester.getRect`, which resolves through the fit's transform, separates them. Also fixed: `StrutStyle` does not inherit `fontSize` — an unset one is 14, and `forceStrutHeight` pinned the line box there forever. **Deployed as v1.6.167.** Undeployed loop iterations: **0**. Previously **ab7eef7** — #315's fifth pass: `sermon_detail_page.dart` set the sermon's own title to the literal 22 above a body of `settings.fontSize`, so it led the page at the default 20 pt and was **smaller than the sermon it introduces from 23 pt on**. The only true rank inversion in the app — checked rather than assumed, since several other literals looked like one and are not. `strongs_entry_page.dart` also printed a **lemma** two px under `WbMetrics.originalFloor` *at the default*, which is a defect no reach detector can see. 16 literals + 3 ceilings paid; residue **32 ceilings / 12 files + 41 literals / 8**. **Deployed as v1.6.166.** Undeployed loop iterations: **0**. Previously **9384762** — #295's second pass: four command-line syntaxes returned a wrong count and none of them threw. Three fixed (`int.parse` → `tryParse` at three sites; edge apostrophes trimmed on the query side; the silent `*N` clamp replaced by a real 202 ceiling and a named `gapTooLarge`), the fourth — Greek final sigma — a real finding whose fix is **withdrawn**, with both numbers in `docs/SEARCH-AUDIT.md` §5. **Deployed as v1.6.165.** Undeployed loop iterations: **0**. Previously **0a14966** — #317: the wilderness itinerary, and the join that fails by succeeding. **Not deployed by the loop, and for once that is not a skipped build:** dev already serves this code. The second writer ran `release_web.sh` at ~14:22 on 2026-08-24 while the killed run's work was live and *uncommitted* in the shared tree, so **v1.6.164 snapshotted it** — verified on the deployed bundle, which carries all 5 journeys in `bible_journeys.json`, the panel's `stops share a point, in` fallback, and the `(?<=[A-Za-z])E(?=ph)` name repair. The gap this iteration closed was therefore the **commit**, not the deploy: dev was serving a build made from a mid-edit tree that no suite had ever run against. Undeployed loop iterations: **2** (the killed run, and this one) |
| Suite | **3,416 tests**, green; `flutter analyze` exit 0 |
| CI | green (Flutter CI on `main`) |

**Verifying CJK in a deployed bundle needs a control, 2026-08-24.** The
three new distribution labels were checked on the immutable deploy URL,
and the two Chinese ones came back **0 occurrences** — which looked like
a shipped defect and was not. `main.dart.js` escapes CJK as lowercase
`\uXXXX`, so grep for a Han string finds nothing *whatever* the bundle
contains: four strings known to have shipped for months also scored 0.
Only after that control did the real search run, and all three locales
are present (`分布（{unit}）`,
`分佈（{unit}）`, plus the shared `按出现次数` /
`按出現次數`). **Test the join key on something you know ships before
believing an absence.**

**45g deployed from a detached worktree, and that was not optional.** A
second writer was committing to this tree throughout the iteration —
9da199d (22:23) and 0def09c (22:35) — renaming the app's identity across
`ui_strings.dart`, `about_page`, `settings_page`, `web/index.html` and
`manifest.json`, with `macos/Runner.xcodeproj` still uncommitted. Since
`release_web.sh` builds from the **working tree**, deploying in place
would have snapshotted their half-finished rebrand. `git worktree add
--detach /tmp/seeksparks-deploy c49eb05` builds a clean checkout of the
pushed, tested commit instead, and the version bump was then re-applied
to the shared tree **by hand** (never `cp` — it silently reverts their
work). Verified on the immutable deploy URL rather than assumed: the
deployed `assets/tagged/cuvs-yhwh/matthew.json` has **0 hashes**, 太22:44
reads 「主[基督]」 and 太9:28 reads 「耶稣说」.

---

## The queue

Status is one of: **open** · **in progress** · **blocked** (needs the owner) ·
**closed** (body moved to `prompt-archive.md`).

Closing a ticket means three edits in the same iteration: mark it closed
here, move its body out of `prompt.md`, and say so in `HANDOFF.md`.

| # | What it is | Status |
|---|---|---|
| #289 | Bundle an OFL Hebrew face — Hebrew word study still pulls from `fonts.gstatic.com` | **closed** — v1.6.73; `NotoSansHebrew-Sub.ttf` is in `pubspec`, wired at `main.dart:565`/`658`, and `release_web.sh:68` passes `--no-web-resources-cdn` so the gstatic path is not merely unused but unreachable. Pinned by `bundled_font_coverage_test.dart` |
| #292 | Kings of Judah + Israel, synchronised, as a Resource | **blocked** — needs a citable Thiele source |
| #293 | Sermon audio — permission settled, survey done, hosting undecided | **blocked** — needs a hosting decision |
| #295 | Live search audit — drive every syntax through the real box | open — the **grammar** half is done: `docs/SEARCH-AUDIT.md` is the query→count→verdict table, 4 wrong counts found (3 fixed, 1 withdrawn with both numbers), pinned by `command_grammar_audit_test.dart`. §6 names what still needs a human at a browser |
| #296 | Prod crash — root cause found and fixed (`9132a14`) | **blocked** — needs a fresh crash report to confirm |
| #299 | The `?` card teaches syntax you cannot run | closed — v1.6.144 |
| #300 | Map provenance — rights settled, the maps are the owner's own collection | open |
| #301 | Yahwehdehua — re-open the import; the base text matched, the readings did not | open — the lexicon half is **fixed** (v1.6.152, check 44); the readings are not |
| #302 | Build the backlog before the queue empties → `docs/PARITY-BACKLOG.md` | closed — 75 entries |
| #304 | Systematic data-integrity audit — "accuracy is the most critical thing" | open, recurring — check 45 landed 2026-08-23 |
| #307 | Phrasing — open it to translations, indent line one (Pastor Raymond HK) | **closed** — both halves. Translations: `PhrasingSource.translation` is the DEFAULT source (`phrasing_page.dart:192`) with `_translationWords()` behind it, answered for all 1,189 chapters. Line one: v1.6.98 unpinned it from zero — `phrasing_test.dart:636` "the first line indents too", including the clamp and the round-trip |
| #308 | Search stats: "John 27" never says its unit | **closed** — **v1.6.156**, all THREE surfaces. The strip and the Stats tab were fixed when the ticket was filed; `WordDistribution` was found still unlabelled 2026-08-24 and plotting the OTHER unit (its caller feeds `ConcordanceResult.byBook`, the per-book OCCURRENCE map — G25 was 37 in John there and 27 in the strip). `unit` is now required, not defaulted. `search_stats_unit_test.dart` + `word_distribution_unit_label_test.dart` |
| #309 | Matthew series — reconcile our corpus against CDC's 124 messages | **blocked** — CDC site unreachable |
| #312 | Phrasing is not usable yet — redesign, don't patch | open — **but the reason this row gave is stale, and every enumerated item is now shipped.** The row claimed the export work at `PARITY-BACKLOG.md:321`/`:445` was unbuilt; `:445` is the separate **Report Generator (bwh28)** entry, not a #312 item, and rich export *is* built (`exportPhrasingHtml` + `ClipboardHelper.copyRich`, `phrasing_test.dart:908`). The backlog's own list of remaining items at `:361` is "default range = the sentence, richer export, controls that teach" — sentence range shipped (`phrasing_sentence_test.dart`), export shipped, and **controls that teach shipped v1.6.161**. Item 7 was the last: the four chips offered Biblearc's vocabulary and the only way to learn what `+ Verbals` did was to tap it. **`bwh25` has no granularity control of any kind**, so a reader has no model of these levels from any other tool — and measured over 9,982 three-verse windows of the bundled corpus, `+ Verbals` draws the **identical page** in 2,087 (20.9%), `+ Phrases` in 356 and `Clauses` in 236. `availablePhrasingLevels` cannot see any of it: it asks whether the EDITION carries a parse, not whether this PASSAGE has a participle. Each chip now carries its line count and the chosen level names what it cuts at; equal adjacent counts are exact, not a hedge, because the levels are monotone supersets — proven over all **2,679** equal-count cases by comparing line STARTS, not just totals. **A second, unasked-for defect was found and fixed in the same commit**: the header is an unbounded `Column` above an `Expanded` diagram, so at the reader's largest font in a 480 px window it already overflowed by 20 px and left the diagram **0 px tall**; the new note would have taken that to 68 px. Capped at 55% of the pane with an internal scroll, the diagram now floors at ~152 px in every font × height cell, which is *better* than before this feature existed. `phrasing_page_header_test.dart` pumps the real page across that matrix and was confirmed to fail (48.5 px) with the cap removed. **Left open on purpose:** whether a ticket titled "redesign, don't patch" is satisfied is the reporter's judgement (Pastor Raymond HK), not the loop's — the conservative call is to ship the work and let the owner close it |
| #313 | The Reader is a phone app bolted into a workbench | **closed** — 2026-08-24, on re-reading the code rather than the row. Both items audit §7 left outstanding are already implemented: `onChapterSermons` routes through `_requestAnalysis(ReaderAnalysisRequest.sermons, …)` (`bible_reading_pane.dart` ~2020), and the reader's `StatsPage` push is behind `if (!hostChrome)` (~7052). The row was stale, not the code. Item 4 remains settled on paper only, and is **not** a defect — it is a design note carried in audit §7 |
| #314 | Build version printed twice on one screen | **closed** — the menu-bar copy is gone; the surviving one is the status bar's, chosen because it is tappable and opens `AboutPage` where the inert menu text was not. `workbench_version_display_test.dart` is a source ratchet on the call-site count |
| #315 | 269 hardcoded font sizes — #311 fixed the arithmetic, not the reach | open — **and the detector was narrower than the defect.** A literal is only one of two ways to write a size the slider cannot move: `main.dart:578-591` rewires exactly `bodyLarge`, `bodyMedium` and `titleLarge` from `settings.fontSize`, so every other `textTheme` role is a fixed number wearing a name. v1.6.156 added `WbType.scaleRole()`, fixed the 7 sites that existed (4 in `small_screen_advisory.dart`, 3 in `analysis_tabs.dart` — **both files were on the ratchet's `finished` list, promising the setting reached everything on them**), and added a tree-wide zero check for the second mechanism. Residue is now literals only: `sermon_detail_page.dart` 6, `version_picker_sheet.dart` 2, and the budget's larger rows. **v1.6.157 found a THIRD mechanism, and it is the largest of the three:** a clamp. `fontSize: (settings.fontSize - 2).clamp(11.0, 16.0)` reads as wired, compiles as wired and reviews as wired, yet it is deaf from 18 pt up — *below* the app's own default of 20. Tree-wide, **80 text sizes run through such a ceiling and 73 are already saturated at the default**, so on those sites 21 of the slider's 29 stops move nothing; `settings_page.dart` holds 28 of them, the page carrying the slider contradicting its own control. The reader is now repaired end to end (41 literals + 10 ceilings + 1 clamped line height → a private `_ReaderTypeScale`), the other 63 are budgeted, and `reader_font_size_behaviour_test.dart` proves a size *moves* — which no source ratchet can. **v1.6.158 paid `settings_page.dart`, all 28 ceilings and its 5 literals, and the shape of the repair is the finding: a clamp has TWO bounds and only the ceiling was the bug.** The floor was doing real work — a reader who drags Font Size down to 12 wants dense scripture, not a 7.8 px hint under a settings row — so it survives once as `WbMetrics.smallPrintFloor` (= `WbMetrics.chrome`, 11.0) in place of the four different numbers (10, 11, 12, 13) that were in use. `WbType.scaledSmall(atDefault)` also drops the *additive* `fontSize - k` shape, which cannot hold a hierarchy: two sizes 5 pt apart are a ratio of 1.8 at the bottom of the slider and 1.15 at the top, where the design was 1.38 at every stop. The argument is the size the site renders **today at 20 pt**, so a reader who never moved the slider sees nothing change. Which scale the page belongs to was not a judgement call — its card titles were already unbounded `settings.fontSize + 2`, so the clamped sites had fallen off the page's own convention, and leaving them produced an **inverted hierarchy**: at 40 pt a switch row printed its title at 40 px over its own subtitle at 14. `settings_font_size_behaviour_test.dart` measures the real page across the real slider; the Display header was frozen at **22.0 px at 40 pt and is now 36.0**, confirmed by running the new test against `b75ffc6`. Residue, counted from the ratchet's own maps: **35 ceilings over 14 files + 57 literals over 12** (the row's previous "64 literals" never reconciled — 57 + the 5 paid is 62). Known and not fixed: at 320 px / 40 pt the page overflows by 7.3 px, but it measures identically *before* this change and 320 is under the 992 `SmallScreenGate` admits, so it is an unreachable layout, not a shipped defect **v1.6.159 found a FOURTH mechanism, and it is the root of the second.** `workbenchTheme` is the app's ONLY theme — `main.dart` wraps both `theme:` and `darkTheme:` with it — and it builds from a *fresh* `ThemeData.light/dark`, reading exactly two things off the theme handed to it (`brightness`, `fontFamilyFallback`). The three roles `main.dart` rewired from `settings.fontSize` were discarded one line after they were set. Measured on **`b6d9859`**: all fifteen roles, the `Scaffold`'s `DefaultTextStyle` and a bare `Text` are **identical at 12 / 20 / 40 pt** — a `Text()` with no `style:` painted at **12.0 px at both ends of the slider**. No source rule at a call site could see this, which is why three audits missed it. `workbenchTheme` now takes `textScale`, and the scale goes on the **`Typography` geometry, not `base.textTheme`** — at the moment the function runs every role there has a **null** `fontSize`, the numbers arriving later from `ThemeData.localize`. All three script categories are scaled, because **`dense` is the one a Chinese UI resolves to** and an `englishLike`-only fix would have left the Chinese app deaf. **`WbType.scaleRole` is DELETED** with its 7 call sites (it would now square the scale), and the ratchet's mechanism-2 test with it — it forbade `theme.textTheme.bodySmall`, which is now correct. What replaces it guards the seam: `textScale` defaults to 1.0, so all **6** call sites in `lib/` are pinned by source, and **the detector was verified to fire** by removing one. **At the default 20 pt the scale is exactly 1.0 and all fifteen roles are byte-identical to before** (asserted explicitly); the floor is `WbMetrics.smallPrintFloor`, as in v1.6.158. **Two traps, both recorded in the code.** `MaterialApp` wraps its theme in `AnimatedTheme`, so a single `pump()` reads the theme **mid-lerp** — the probe reported a working fix as broken, and the pre-fix baseline had to be re-measured with the corrected probe before the claim was allowed to stand. And the first attempt scaled `base.textTheme`, which multiplied fifteen nulls. `theme_font_size_behaviour_test.dart` measures painted widgets; the ratchet's header claim that *"the defect is invisible to a widget test"* is corrected in place, because this mechanism is the exact converse. **Live on v1.6.159**: the small-screen advisory (whose 4 `scaleRole` sites became bare roles — the riskiest edit) still scales with no regression, and the workbench holds at both slider extremes at 1300 px. A **false negative was caught before being written down**: the File menu does not grow at 40 pt because its items carry `fontSize: t.chrome` (`workbench_chrome.dart:133`) and belong to **Menu Size**, correctly. **Open question, named rather than hidden**: roles now scale *down* too, so a heading frozen at 24 px is 14.4 px at the minimum — symmetric, floored at 11 and hierarchy-preserving, but a visible bottom-of-range change on a ticket that opened about text being too small. Residue is unchanged by this iteration, which paid the root instead of a file: **35 ceilings over 14 files + 57 literals over 12**. **2026-08-24 paid four surfaces and found the ticket's sharpest case, which is not a matter of degree.** On a page that mixes a scaled body with frozen furniture, a literal does not merely fail to grow — it can change **RANK**. `sermon_detail_page.dart:437` set the sermon's own title to the literal 22 above a body of `settings.fontSize`: largest text on the page at the default 20 pt, and **smaller than the sermon it introduces from 23 pt on**, stop 12 of the slider's 29, barely half its size at 40. That is the only true inversion in the app — checked, not assumed; `verse_popup_sheet`'s 18 px label over a 20 px verse is correct subordination, and the other literals distort ratios rather than reverse them. The same page's condensed-sermon notice — the line that tells a reader the transcript is *abridged* — was designed at 1.54× contrast and rendered at 3.08×, i.e. the one sentence a reader who raised the slider most needs was the least readable. `strongs_entry_page.dart` carried a **second, unrelated** defect the reach detector could never see: `_RelatedChip` printed a LEMMA — accented Greek, pointed Hebrew — at 13 px, **two under the app's own `WbMetrics.originalFloor`, at the default setting**; and the headword was `settings.fontSize + 8`, an additive offset that holds no ratio (1.67× the body at 12 pt, 1.20× at 40). Paid: 16 literals over four files (`sermon_detail_page` 6, `strongs_entry_page` 7, `verse_popup_sheet` 2, `note_reference_picker_sheet` 1, all four now on `finished`) plus 3 ceilings (`sidebar_panel` `.clamp(14,18)`, `version_picker_sheet` `.clamp(12,15)` — which answered **26 of 29 stops identically** — and one in `loading_page`). A new `WbSettingsScale on AppSettings` extension (`settings.wbType`) ends the longhand four-argument `WbType.resolve` at the half of call sites that hold settings as a field or build inside a sheet, which is how `fontFamily` came to be passed at some and not others. `sermon_font_size_behaviour_test.dart` **measures** the claim — a source ratchet can prove a size is not a literal, only a pumped page can compare two sizes written in different files — and all three of its tests were confirmed to fail against `f8f927a`, the rank test at exactly 24 pt. **A counting error caught before it was written down:** a narrow regex of mine said "12 ceilings" where the ratchet's own detector says 35; the instrument reported its reach, not the defect. Residue, from the ratchet's maps: **32 ceilings over 12 files + 41 literals over 8** (9 of those 41 are `app_style_preset.dart`'s preset FIELDS, not render sizes). **2026-08-24, a FIFTH mechanism, and it is a different kind of thing from the first four.** Those are all ways of writing a NUMBER the slider cannot move. This is a number that moves perfectly and paints the same pixels: `book_chapter_picker.dart` wrote `fontSize: settings.fontSize * 1.15` — correct shape, passes every ratchet, moves at all 29 stops — inside a `FittedBox` inside a grid cell whose width came from the **MENU** scale, so the painted glyph was `cellWidth / labelEmWidth`, a constant. Measured against `7874e01`: **`Jonah` painted 44.0 px wide at 20 pt and 44.0 px at 40 pt**, and in the 280 px reader sidebar **62 of the 156 shipped abbreviations were already at their maximum painted size at the DEFAULT 20 pt**, with all 156 frozen somewhere inside the slider (at 800 px: 4 at the default, 89 within it). This is the app's **primary navigation surface**. **It needs a third instrument.** A source rule sees nothing, because nothing is wrong with the source; a behaviour test reading `RichText.text.style.fontSize` reads the **declared** size, which under a `FittedBox` is right while the pixels are wrong, and `tester.getSize` agrees with it because it returns the pre-transform size. Only `tester.getRect` — `localToGlobal`, and so through the fit's transform — tells them apart. `test/fitted_label_reach_test.dart`; the ratchet's header now names all three instruments. **A sixth trap in the same widget: `StrutStyle` does not inherit `fontSize`.** An unset strut `fontSize` is **14**, and `forceStrutHeight: true` then pins the line box to 14 px at every setting while the glyph grows past it — 12.35 px of line box for a 23 pt glyph — placing the baseline from a 14 px box so a large letter sat well above its tile's centre. One `StrutStyle(` in `lib/`, now carrying the text's own expression. **The guess this pass started from was refuted by measurement**: Chinese looked like the crowded case and Latin is nearly threefold worse — `Jonah` **2.78 em**, `林前` 2.00, and the shipped Chinese abbreviations are **one ideograph** (`马太福音` → `太`, 1.00 em). Hence measuring the widest label **per grid** rather than assuming a constant, which would have charged every script for `Jonah`. **The floor is capped by the label, not lowered**: the old `.clamp(4, 10)` minimum is the defect, but a flat 2 would have thinned the *Chinese* sidebar from 4 columns to 3 while painting the identical glyph, so the floor stays 4 and is capped by what the label can use, hard bottom 2. Chinese keeps 10 columns at 800 px and 4 in the sidebar, both asserted. **Stated, not hidden**: an *English* grid at 800 px / 20 pt now draws **9 columns instead of 10**, the one place this pass spends default appearance to buy correctness. `stats_page.dart`'s `_NumberGrid` chip (`width: 56` under a label that has scaled since v1.6.159) was the second instance; `version_picker_sheet._languagePill` and `word_distribution_table` were checked and are **not**. **A harness trap that nearly made the suite lie**: the tile asks for `settings.fontFamily` = the CSS token `-apple-system`, and `flutter test` resolves any unregistered family to a stand-in where **every glyph is 1.0 em**, never walking `fontFamilyFallback` because the stand-in has every glyph — so Roboto had to be registered **under `-apple-system`** to reach the widget at all. Without it the Chinese-vs-Latin test returned **zh=10, en=10**, which is exactly what the *unfixed* code returns. Run against `7874e01`, **3 of 4 widget tests fail**; the fourth is the no-regression guard and passes on both. Residue **unchanged** — this pass paid a mechanism, not a file. **2026-08-24, a SIXTH and SEVENTH mechanism, and the finding is where they were: inside the two files the ratchet lists as `finished`.** Sixth is a design constant wearing a principled name — `fontSize: WbMetrics.text` names the app's own type scale and is exactly as deaf as `fontSize: 12`, because `WbMetrics` holds the sizes AT THE DEFAULT and only `WbType` multiplies them; **14 sites, 5 of them the workbench's own empty states**, one being `_analysisHint`, the placeholder for **eleven** analysis tabs. Seventh is a literal on the far side of a question mark: the ratchet's regex anchored the number to the colon, and the ceiling detector required a numeric offset, so `_st.dense ? _st.body : 13` and `(fontSize - (compact ? 4 : 2)).clamp(11, 15)` were both invisible — the latter shape **saturated at the DEFAULT on BOTH branches** in `contact_line.dart` and `confidence_badge.dart`. A third hole was found while widening the second: the clamp test looked for `fontSize` only in the 60 characters *before* the match, so a clamp bound to a local was invisible. All four detectors confirmed to FIRE by reverting their sites; the three new behaviour tests confirmed to fail pre-fix. **The measuring instrument had to be repaired before it could be trusted**: `Text.rich(span)` wraps rather than paints `span`, so `richText.text.style.fontSize` reads the inherited `DefaultTextStyle` and reported the **already-repaired** `ContactLine` as frozen at 14.0 px at 12, 20 AND 40 pt. Residue: **32 ceilings / 12 files + 41 literals / 8 + 9 named constants / 1**. |
| #316 | The rotate advisory argues against itself | **closed** — v1.6.132's □□□ was the last of it: `workbenchTheme` restated only five of fifteen styles with the parent's `fontFamilyFallback`, so `headlineSmall`/`titleMedium` drew Roboto, which has no CJK, with no gstatic fallback to rescue it. `theme_cjk_fallback_test.dart` now asserts *every* style in the theme can render Chinese |
| #317 | Journey routes on the atlas | open — **all three routes the owner named on 2026-08-16 now ship.** `jesus-mark` (`fffae59`) is the third, 主耶稣路线: Mark 1:9–11:11, **one evangelist's own sequence, never a harmony of the four Gospels**, because a harmony is a reconstruction and a reconstruction drawn as a line is what this feature exists not to do. 14 stops, 13 legs, **478.6 km**. It surfaced the sibling of the wilderness route's *join that fails by succeeding*, and this one is **wrong rather than merely silent**: a gazetteer entry for a **region** carries a point and that point is usually some city's. `Judea` = **[31.77, 35.23], Jerusalem's own**; `Decapolis` = **[33.51, 36.31], Damascus**; `Galilee` = **byte-identical to Nazareth**; `Dalmanutha` = **byte-identical to `Magadan`** — *Matthew's* identification, so drawing it would smuggle in the very harmony the route forbids; `Gethsemane`/`Golgotha` = **Jerusalem exactly**; `Jordan` = one point for a 250 km river. Mark names every one; **eight are omitted**, the `basis` names them, and the asset test fails the build if one returns. The two `Sea of Galilee` stops went too — the point is the **lake's centre**, ~7 km offshore, and 1:16 has him walking *beside* it. **No sea leg at all**: every Markan crossing touches a place with no usable coordinate (6:32's solitary place; the Gerasenes of 5:1, absent from the gazetteer and itself a variant our KJV prints as *Gadarenes*), guarded by a test. **Sidon is the one provisional stop because our own two editions disagree** — BSB/LEB/NASB read διὰ Σιδῶνος, the shipped KJV reads *from the coasts of Tyre and Sidon*, which places him at neither. **A refuter was run on the draft and overturned two of my own claims**: Bethsaida 6:45 had been drafted as an `aside` on my inference that the crossing missed it — Mark never says so and 8:22 has them arrive — and `Dalmanutha`/`Magadan` I had not checked at all. **The sixth route spent the channel the palette had reserved for it since v1.6.134** (*"a sixth route should add a channel, not a sixth hue"*): `JourneyMark` — round=Acts, square=Torah, diamond=Gospels, **chosen by body of narrative, not slot arithmetic** — so identity is a **(hue, shape) pair** and Mark reuses slot 0's amber. Shapes are **equal AREA, not equal radius** (a square across the diameter is 27% heavier, an inscribed diamond 36% lighter), verified by **rasterising and counting opaque pixels**; the antialiasing residual scales with perimeter, so the test draws at r=100. The legend swatch draws the silhouette. **The short dash was widened in writing** from *"the text refuses the manner"* (Acts 20:1) to also cover *"the text routes them through a place we cannot locate"* — both promise the reader *this line is not underwritten as a direct journey*. Two defects fixed on the way: the journeys block was sized by the **data**, not the viewport, and overflowed a 320×640 pane by **34 px** at route six (now capped against the pane and scrolling inside it — my first regression test pumped 320×400 and was **rewritten after checking it against the pre-change tree, where it overflowed by 162 px**, i.e. it was a pre-existing limit and not what I had fixed); and `the straight-line totals` asserted a **500..20000 km** band that would have rejected Mark's 478.6 km **for being the right size**, now a **pinned total per route** — which immediately caught that the wilderness figure is **1,638.4 km**, not the 1,841 a naive sum of rows gives, because `straightLineKm` sums the **drawn** segments and a collapsed run contributes once. Luke, Matthew and John are natural further slices and now compose without a palette collision. Earlier: Pauline itineraries drawn (v1.6.134); the **wilderness itinerary** (Numbers 33, all 42 stations) landed 2026-08-24 in `0a14966`. Its order needs no reconstruction — 33:2 says Moses wrote the stages down — so the uncertainty is entirely in the gazetteer, and that surfaced a failure mode the ticket did not anticipate: **a join that fails by succeeding.** An unplaceable stop breaks the line and the panel has said so since v1.6.134; a stop placed ON TOP OF ITS NEIGHBOUR draws perfectly and says nothing. Measured through the app's own parser: **909 of 1,228 located places share a point** (1,228 places on 560 coordinates, 241 carrying more than one), and **27 of Numbers 33's 42 stations fall into 6 runs**, the largest 11 camps (Rissah…Bene-jaakan, badge `17–27`). Drawn stop-by-stop: **37 legs, 21 of them exactly zero km** — eleven badges overprinting into the smudge `ordinalsByPlace`'s own doc comment had warned about since v1.6.134 without the code implementing it. **0 of the 4 Pauline routes have a collapsed run**, which is why a week of shipped routes never revealed it; keying on `markerKeyFor` (the coordinate) is a strict generalisation and no Pauline expectation changed. Runs draw as one marker with a range-compressed badge (en dash, and **only where consecutive** — `8,10` is Lystra visited twice and `8–10` would be a false claim), emit no zero-length leg, and are counted on the panel. **The wording is about the DATA, never the scholarship**: unidentified sites and genuinely adjacent places (Jerusalem's gates) are indistinguishable here, so "share one map point" ships and "location unknown" does not. Doubt sits at a run's ENDS and nowhere else — a leg is provisional when the text does not place the travellers at one of *its two ends*, and a mid-run camp is not an end of anything. Two camps have no coordinate at all (Pi-hahiroth 33:7, Hor-haggidgad 33:32) and **break** the line; they are enumerated by name in `journey_asset_test.dart`, two-sided, because a typo and an unidentified site reach the resolver as the same event. `docs/DATA-INTEGRITY.md` check 48 |
| #318 | Interactive Bible chronology, featured module | open — phases 1–5 shipped, runs to the death of Moses |
| #319 | Atlas filter filters the list but not the map | **closed** — the map now takes the subject filter, and the state that fixed it is documented in place: `atlas_page.dart:142` "Whether the map also draws what the filter left out", with `:149` holding the subject ids while the chip is up. The filter is dismissible by design — an atlas that could only ever show the filtered set is a worse atlas |
| #320 | Place records should show the illustrations we already have | **closed** — `lib/utils/place_illustrations.dart` joins the picture database to the gazetteer. #320 made the feature conditional on measuring the join rate FIRST, and `place_illustrations_test.dart` freezes that measurement rather than quoting it in a commit message: if a plate is added or a caption edited and the join moves, the suite says so |
| #321 | Greek search cannot match accented input (Aunty Rosa, Hong Kong) | closed — v1.6.126; `foldDiacritics` wired into `text_patterns.dart:171`, `command_query.dart`, `search_highlight.dart` |
| #322 | The Browse column does not line up — three render paths | open — v1.6.139. **Read 2026-08-24 and it looks already done, but nobody has looked at it:** `BrowseVerseRow` (`browse_window.dart:889`) is now the single row for all three paths — one `ConstrainedBox(minWidth: referenceWidth)` plus `Expanded(child:)` — and the gap/spacing are single constants (`kBrowseWordGap`, `kBrowseRunSpacing`). The three render paths the ticket names no longer diverge in source. **2026-08-24 measured it instead of reading it, and the column was straight only by luck:** `referenceGutterWidth` modelled the width with no letter spacing while the reference `Text` inherited `bodyMedium`'s 0.25 from the ambient `DefaultTextStyle`, so the painted string ran `runes.length × 0.25` px wider than the box computed for it — absorbed by the 8 px gap, which is a constant covering another constant's mistake. Fixed by naming `kBrowseReferenceLetterSpacing` and passing it to both sides. `browse_reference_real_font_test.dart` is the first test here to lay strings out in the **shipped** faces (`FontLoader` + `rootBundle`; `flutter test` otherwise renders a fixed-width stand-in, which is why every earlier test compared the model only to itself) and sweeps 990 references × 5 sizes with none overflowing. The doc comment's calibration figures were also wrong — measured English +4.19%…+19.57%, Chinese +1.34%…+3.90%; **the CJK margin is 3× thinner and structurally so**, since Han is charged exactly 1.0 em and a Chinese reference's whole slack is its ` 1:1` tail. **Still open:** the complaint was visual, and proof-by-measurement is not visual sign-off |
| #323 | 雅偉繁體: ~700 verses with the wrong Traditional form (owner-reported) | **closed** — re-verified from the asset 2026-08-23: 賽2:16 船隻, 出14:22 走乾地, and the trap verse 賽29:17 still 只有; 0 occurrences of 船只/其余/走幹地/凈 |

**Blocked on the owner, five:** #292 (a citable Thiele source) · #293 (audio
hosting) · #296 (a fresh crash report) · #309 (the CDC site is unreachable) ·
#278 (NASB licence — the modules forbid redistribution; the assets must never
be committed or deployed).

**The closing pass ran 2026-08-24.** The rows above are audited as of that
date. Eight closed on evidence read out of the code in this iteration —
#289, #307, #308, #313, #314, #316, #319, #320 — each carrying in its own
row the file and line that proves it, so the next reader does not have to
re-derive what was already derived.

**Seven of the eight were finished before the pass began.** Only #308
needed work, and only on a surface the ticket never named. The rest had
shipped and nobody wrote it down, which cost more than it sounds: an
unclosed row keeps its body in `prompt.md`, and `prompt.md` is read whole
at the top of every iteration. The queue was paying rent on finished work.

**Grep before picking one — and grep for the reader's verb, not the
technical term.** `PARITY-BACKLOG.md` §8 called two finished items
outstanding because the code is named `selectCommonWith`, not `intersect`.
Two rows here resisted the same way: #319's fix is a doc comment reading
"whether the map also draws what the filter left out", and #313's is the
word `hostChrome`. Neither contains its ticket number.

**What a closing pass may NOT do is close a row because the neighbouring
one closed.** #312 sits beside #307 and covers the same screen. It still
stays open — but for a different reason than when this was written, and
the change is worth reading: the row's stated blocker (unbuilt export)
was **wrong**, and it survived three passes because a `#312` next to a
line number was read as a #312 item when `:445` is the Report Generator's
own entry. Every enumerated item is now shipped; what keeps the row open
is only that a *reporter* decides when "redesign, don't patch" is done.
**A row's reason has to be re-derived, not re-read.** #315 likewise stays open — and it is the row worth reading,
because auditing it twice found two more mechanisms than the detector was
written to police, the second of them larger than the original defect.
The lesson is now a habit: **when a detector's count and a user's report
disagree about scope, the detector is the thing to re-measure.** Both
times the user was right and the instrument was short.

---

## The feeder queue

`docs/PARITY-BACKLOG.md` — **75 entries**, written by the loop under #302 so
the numbered queue above never runs dry. Entries carry `bwh` ids. Recent
ones shipped: bwh26 (Word List compare), bwh34 (Nave's Topical Bible, both
halves), bwh45 (romanised search input), bwh35 (Lexicon Browser).

**§8's shortlist is spent** — items 2–6 are all struck through as of
2026-08-23, and **1a closed the same day it was picked**: the Lexicon
Browser now offers three works (Strong's, English Thayer's, the Chinese
BDB/Thayer module). The live candidates are **1b** (the synopsis display,
parked behind #292) and **1c** (flashcard retention, bwh40). When those go,
pick a `PARTIAL` from §3–§6 whose "what is missing" paragraph fits one
iteration — do not re-pick a struck item.

**§8 item 1 outranks all of them.** Its named next job — the Strong's
Chinese gloss cut at the printed line break, "Next, in order" item 0 —
is **closed by check 44g**: 488 entries repaired, +25,125 characters,
glosses ending on a separator 558 → 0. The scope was **593**, not the
279 the separator test reported, which is the check-43c failure mode a
third time; measure from the source, always.

`docs/DATA-INTEGRITY.md` "Next, in order" leads with the unnumbered item
— `assets/biblexg-v2.json` missing 馬可福音 6:8-11 — which **must not be
taken unattended** (it needs the upstream source or an owner's decision).

*(The second unnumbered item — the 21 reading-text defects — is **closed
by check 46**, 2026-08-23: read individually as instructed, 6 repaired,
15 reported and left, 1 drafted and withdrawn, plus 6 more found by a
new sweep. 38 records written; `audit_tagged_layer.py` 350 → 345.)*

*(The 27 single-character sites check 46 left behind are **read by check
47**, 2026-08-24: 5 repaired, 6 proved to be the sweep's own false
positives, 16 left with their evidence written down. 15 records written;
the sweep reports 27 → 23.)*

**Take the residue check 47 leaves: the 16 sites where two independent
witnesses supply a character our text lacks, but our reading is
grammatical and means the same** (`docs/DATA-INTEGRITY.md` §47c). They
were left because the two witnesses' independence **from each other**
could not be measured — both may be 新标点和合本 digitisations, and
measuring it would need 31,102 one-verse API calls. The honest next move
is to measure that agreement rate on a sample large enough to decide,
**not** to repair 16 verses on two votes that may be one. Can be taken
unattended.

**Do not resolve any of these by majority — four texts have now been
disqualified, and one long-trusted one was our own parent.**
`cuvs-plus` agrees with the reading text on 99.70% of characters, so it
is a descendant. `official_cuv_source` likewise. `bolls.life/CUV`
reproduces seven of our defects *and* carries one we do not have
(以便之後 for 以倫之後, 士師記 12:13). Our own tagged layer is
inadmissible on **word order**: across the 16 pure transpositions check
46 measured, it is the corrupt side in 15. And the **yahwehdehua
sqlite is our parent, not an external witness** — it reads 雅伟 at
申命记 32:19 and 5:5, which corrects check 26's own description of it.

**Two texts are admitted, and admissibility was proved by test.** Run a
candidate against check 46's twelve already-repaired verses and require
it to read the repaired form: ebible.org `cmn-cu89s` (新标点和合本, PD)
reads 11 repaired, 0 defective. 信望愛 fhl.net `unv` is the second. The
fetch-and-parse recipe, and the three ways each API lies, are in the
loop's `research-notes.md` under "Check 47".

*(45d's other two sub-jobs are done: check 45g repaired the 15 verses
printing a literal `#` and the 7 doubling a character against itself.)*

---

## The loop that does the work

| | |
|---|---|
| Script | `~/Library/Application Support/seeksparks-loop/run.sh` |
| Brief | `prompt.md` beside it — **the per-iteration token cost**; closed tickets move to `prompt-archive.md` |
| launchd | `com.seeksparks.parityloop`, **30-minute interval** (owner's call, 2026-08-23 18:49; was 60) |
| **Dead-man switch** | `STOP_AT` in `run.sh` — **2026-09-21 23:00**, then the job `bootout`s itself. Read fresh each invocation, so changing it needs no reload. Owner reset it to 29 days on 2026-08-23 (was 2026-09-09) |
| Model | `claude-opus-5`, `--effort high`, `MAX_RUN` 90 min |
| Lock | `.lock` (hidden — not `lock`), self-healing on a dead owner or age > 70 min |
| Off-peak gate | **REMOVED 2026-08-24** on the owner's instruction — runs around the clock; the rate-limit hold is the only pause. Old gate preserved in `run.sh.bak-gate-0824` |
| Rate limits | 3 retries at 60 s, then a hold to the reset time Claude actually states |

**Known cost problem, 2026-08-23:** the loop spent the entire weekly Claude
allowance in about 3.5 days (~54 iterations, Aug 16–19) and then sat at the
quota wall doing nothing from **Aug 19 17:27 to Aug 23 15:02**. Sustainable
throughput is roughly **7–8 iterations a day**.

The owner was given the choice and chose **30 minutes** (applied 2026-08-23
18:49; `.bak-1h-0823-1849` holds the 60-minute plist). A run takes about
40–45 minutes, and launchd will not stack a tick onto a running job, so 30
minutes does not halve the gap — it removes it, and iterations run
back-to-back at roughly the length of a run. Expect the weekly allowance to
go sooner and the quota hold to last longer; that is the accepted trade, not
a fault to fix. Do not change the interval back without being asked.

---

## Rules that were paid for with real defects

The full text lives in `prompt.md` under "RULES THAT SURVIVED". The ones
that bite most often:

- **Verify by exit code, and verify LAST.** `flutter analyze` exits 1 on an
  info-level lint; an analyze that predates your final edit has verified
  nothing. (`6ae0567`, `82700d4`)
- **`git status --porcelain` must be empty of tracked files after you
  commit.** Your suite reads the working tree; CI reads only what you
  pushed. A new asset directory means a new `pubspec.yaml` entry, and the
  pubspec is part of the change. (`46ed151`, `a7bb0b3` — 201 Nave's files
  shipped, the declaration did not)
- **A human reported it → it goes first.**
- **A key is not an article.** Counting keys said the Chinese lexicons
  covered Strong's 100% in both directions; joining on *content* found 19
  headwords no work defines, and 14 of them had been rendering blank on a
  shipped screen. Any coverage claim must be measured on what is said, not
  on what is addressable. (check 43)
- **A `State`'s `context` sits ABOVE its own `Scaffold`.** Measuring text
  with `DefaultTextStyle.of(state.context)` misses whatever the Scaffold's
  theme adds below it — `bodyMedium`'s 0.25 px `letterSpacing` cost 1.25 px
  over five characters and clipped every Greek row in the Lexicon Browser.
  Measure from a context inside the subtree you are measuring. (`1542a74`)
- **A detector reports its own reach, not the defect's size.** An
  unbalanced-bracket test found 28 truncated etymologies and sounded
  precise; the real figure was 468, because the test can only see a cut
  that lands between a bracket and its partner. A published scope
  measured by a partial instrument is a *different quantity*, not a low
  estimate. Re-measure from the source before believing one. (check 44)
- **A test that asserts two things differ is only as good as the reason
  they differ.** "Picking a work changes the rows" passed for a year
  because the second work's row was showing a truncated KJV fragment.
  Repair the data and the two works agreed — 88.4% of Greek headwords
  carry the same Chinese summary in both. (check 44e)
- **Covering MOST of a set is not explaining it — and a plausible
  explanation is the most dangerous kind.** Check 45d's 372 Chinese
  disagreements had a good editorial story: 〔…〕 marginal notes plus
  orthographic pairs. The story was true of **293 of 372**, so every spot
  check confirmed it, and it was written into the docs as "two editions,
  not a corruption". The other 79 were real, and about twenty of them are
  **wrong words in the text the reader reads**. The refuter caught it.
  When a theory explains most of a residue, subtract what it explains and
  look at what is LEFT — do not round the remainder off. (check 45d)
- **Run the refuter, and run it against your own conclusion.** This
  iteration's central claim was false and the subagent said so. It also
  over-reached in places (it named 13 verses while asserting 15; the true
  set is 15 and includes two it had not listed), so its findings were
  re-measured before any of them was written down. Delegate the search,
  never the verdict — but *do* delegate the search. (check 45d)
- **A coarser comparison is a DIFFERENT question, not a weaker one.**
  `bsb_tagged_layer_test.dart` compares the tagged runs to the printed
  verse strictly and bounds its residue at 248 verses, nearly all
  punctuation. Two of those 248 were not punctuation — Exodus 38:28 drops
  "of silver" and Judges 16:14 drops "it" — and they were invisible
  precisely because the strict test had to tolerate a large residue.
  Reducing until only whole words survive made two dropped words
  separable from 248 dropped commas. Before assuming an existing test
  covers your question, ask what its tolerance is hiding. (check 45)
- **Two artefacts built by different processes witness each other, free.**
  The flat edition and its tagged layer had never been compared; asking
  cost one script and found 21 untagged verses and 4 dropped or doubled
  words. But state the blind spot in the same breath: a shift present in
  BOTH layers passes at 100.0000%, which is exactly how check 40's
  1 Chronicles 22 defect survived. (check 45)
- **When one delimiter carries two meanings, the repair needs a second
  signal from the data.** CBOL uses a bare newline for both a column
  wrap and a deliberate break, so "join the lines" fabricated
  `大祭司在祭司中最大的一` at G749 — a reading in no lexicon, and worse
  than the truncation it replaced. The signal was the entry's OWN widest
  line: the corpus has no global column width, but within one entry a
  wrap is visible. Find that signal before repairing, not after. (44g)
- **Write a Bible asset back in the layout it already had.** The flat
  editions are pretty-printed at indent 2; `cuvs-plus` and everything
  under `assets/tagged/` is minified. Check 46 wrote the flat editions
  minified and its twelve-verse correction arrived as **435,535 deleted
  lines** — nothing lost (155,510 leaves both sides), but unreviewable,
  and `git blame` gone for every verse in both books. Second time this
  has been paid for. Use `write_like()`; minifying saves 1.09 MB raw and
  only **40 KB gzipped**, and these are served compressed. (check 46g)
- **Ask what a witness DESCENDS FROM before counting its vote — and
  prove admissibility by TEST, not by provenance.** Four texts have been
  disqualified for agreeing with us too well or for carrying our defects
  plus one of their own, and a fifth turned out to be our **parent**: the
  yahwehdehua sqlite reads 雅伟, which is our own editorial signature, so
  check 26's description of it as independent was wrong. A shared error
  is evidence of shared ancestry, not of correctness. The test that
  works: run a candidate against verses we have **already repaired** and
  require it to read the repaired form — `cmn-cu89s` scored 11 of 12 and
  was admitted on that, not on its licence page. (checks 26, 45g, 46, 47)
- **An API that does not recognise your parameter may answer anyway.**
  fhl.net ignores an unknown `engs=` and returns 羅馬書: 创世纪 9:11 came
  back as Romans 9:11 — real Chinese scripture, right chapter, right
  verse, wrong book — for 27 consecutive requests with no error. No
  status code, no exception, no empty field. **Assert the response's own
  identity fields equal what you asked for**, on every external fetch.
  (check 47e)
- **A guard can be narrower than the generator it guards.**
  `bundled_font_coverage_test.dart` scans two asset trees;
  `build_font_subsets.py` ingests many. Eleven code points in
  `bible_evidence.json` were therefore rendering as *nothing at all* on
  web — Flutter web draws an uncovered code point as absent text, not
  tofu, so nothing looked wrong. (check 46f)
- **Measure what is measurable; photograph only what is judgement.** A
  screenshot costs ~1.5–2k tokens.
- The three-pane threshold is mirrored in `workbench_fit.dart` **and**
  `workbench_page.dart:132`.
- Book names go through `localeAwareBookName`, always.
- Never ellipsis a CJK label.
- Credit Pastor Eric H.H. Chang 张熙和牧师 **with** the H.H.
- Never invent a date; name the chronological system (Thiele/Albright/Galil).
- **NASB assets must never be committed or deployed** — `assets/nasb-ev.json`,
  `assets/nsn-plus.json`, `assets/tagged/nsn-plus/`.
