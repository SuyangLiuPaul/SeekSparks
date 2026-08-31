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

Last updated: 2026-08-31 (twenty-seventh entry)

---

## Where the build is

| | |
|---|---|
| `pubspec` / dev | **1.6.194** — `db79c5e`, prod+dev release (one app name on the splash, a CI floor CI can meet), shipped 2026-08-31 by a concurrent session outside this loop; corrected here from the stale 1.6.191 this row read. This restarted the deploy counter below. |
| `pubspec` / dev (previous) | **1.6.186** — #317: the atlas ruler's tooltip always cited `kBandOnFoot`'s fixed "20–30 km a day" sentence under a figure computed at whichever band the reader had actually chosen — a source vouching for an arithmetic it did not make. `travelBandBasis()` already existed for the journey panel; the ruler now calls it too, and appends `travelBandNotOurs()` on a non-default band. Added one visible footer line (`travelBandLabel()`, key `places-map-band`) for the non-default case, since the band picker lives in the journey panel and a tooltip is a hover — unreachable on a tablet, and unreachable at all once the panel is closed while `travelBand` still reaches the map unconditionally. +4 tests (19 in the file), 3,746 green, analyze exit 0. Deployed to dev at counter 3 of 3. Cut at `230f91e`/`1569a8a`. |
| `pubspec` / dev (previous) | **1.6.184** — closed the join gap in #317: `assets/bible_journeys.json`'s 127 stops each carry a verse, but nothing checked the verse actually names the stop. New `test/journey_verse_join_test.dart` hand-joins all 127 against the three shipped English editions; found 3 unnamed (1 gazetteer spelling, 1 already-disclosed inference, 1 real gap — Paul's second-journey departure marker cited Acts 15:40, which names no city, now disclosed with 15:35/14:26). Also noted the Red Sea marker as standing for a whole-sea gazetteer point. Fixing the notes' added height then exposed `atlas_page_test.dart`'s wilderness-route test relying on an unstated instrument limit — a lazy `ListView` mounts only what fits the viewport, and its 1000 px height had never mounted the whole 42-station list; raised to the measured saturation height (4000 px) with an explicit reach assertion. Deployed to dev at counter 3 of 3. Cut at `1e23b80`/`70e7912`. |
| `pubspec` / dev (older) | **1.6.183** — #318 phase 20, the timeline's 88 person links rendered and the Moses disagreement repaired. Cut at `82a6cee`. |
| `pubspec` / dev (oldest) | **1.6.182** — #318 phase 17, the Bible's own story merged onto the wheel, plus the `localizedReferenceLabel` extent fix. Cut at `9c930fd`, and **photographed rather than assumed**: the splash reads `v1.6.182`, the hub reads **22 · 62 · 588**, the 1010–931 BC cluster lists David, the Davidic Covenant, Solomon, the Temple and the division alongside the wheel's own Hiram of Tyre and the Bantu expansion, *David Becomes King* prints "year from Thiele's chronology of the kings" (an arm that was a **dead branch** before this merge, so it was a latent claim and not a shipped defect), and Noah's Flood prints **`Genesis 6-9`** / **`创世纪 6-9`** where before the fix it printed `Genesis 6`. |
| prod (seeksparks.netlify.app) | **1.6.136** — dev is at 1.6.186; prod ships only on the owner's word. *(The "21 versions behind" this row carried for weeks was never derivable from either number and is withdrawn rather than replaced with another guess.)* |
| `main` | **b2a2c50** — #318 phase 24: `wheel_history.json`'s `_meta` carried eight fields and `WheelHistoryData` parsed none — the chart's own provenance (that no date came from a copyrighted chart) and two statements of absence (Lot's line stopping at Gen 11, the axis stopping at 4000 BC) shipped unreachable, and the disclosure test written for exactly this class iterates the four record lists, so the header was outside its reach by construction. Promoted `provenance`/`coverage`/`axis` to trilingual maps (`scope` already was), added `WheelHistoryMeta`, wired it through `fromJson` and the `load()` merge literal (now `required`, so a dropped wire is a compile error, not a silent loss — confirmed: omitting it before the fix failed to compile), and surfaced it from a new "About this chart" AppBar action, resolving `WbType.of` inside the sheet's own `FutureBuilder` builder rather than the tap handler. +4 tests in a new `wheel_history_meta_disclosure_test.dart`, +1 in the existing disclosure test, +1 widget test. Full suite 3,814 green, analyze exit 0. NOT deployed — plan-mandated counter 1 of 3 (`db79c5e` released v1.6.194 prod+dev on 2026-08-31 outside this loop and restarted the count). |
| `main` (previous) | **2c45a9e** — #304, check 50: the two 和合本雅伟版 editions (`cuvs-yhwh.json`/`-tr.json`) were regenerated together in one commit and nothing had ever asked them to agree; deriving a traditional→simplified character map from the corpus itself found 7 disagreements in 31,102 verses. Repaired 2 singletons — a stray Traditional 說 inside the Simplified Bible (038001003) against 9,538 说, and a doubled 的/dropped 千 in the Traditional Bible (040025020, 那另外的的五來→那另外的五千來) — and left 5 as the Traditional edition's own 凋/雕 orthography (systematic, 83 against 5). New `tools/repair_cuvs_yhwh_editions.py` (idempotent) and `test/edition_script_purity_test.dart` (+3 tests) ratchet both classes; also struck 馬太福音 25:20 from DATA-INTEGRITY §47c's stale row (resolved upstream by `49af9be`, 16→15 sites left) and recorded that `bible.fhl.net`'s `qb.php` serves a whole chapter when `sec` is omitted (1,189 requests, not 31,102, for the independence measurement §47c still needs). Full suite 3,802 green (was 3,799), analyze exit 0. NOT deployed — plan-mandated counter 1 of 3 (`41ccde4` released v1.6.192 and restarted the count). |
| `main` (previous) | **cf2fc76** — #304, two `DATA-INTEGRITY.md` "Next, in order" entries. Commit A (`a47e83b`): the KWIC footer printed `_totalRefs` — references *fetched* — not what was drawn; `KwicTally` now reports drawn lines and drawn references plus a disclosure line, and the header's "hits" (a verse count over a per-occurrence list) is now "references". Commit B (`cf2fc76`): the font-coverage guard scanned 8 hand-picked paths against a generator that walks all of `assets/`+`lib/`; #317/#318 had shipped 44 Han characters with no glyph in `NotoSansSC-Sub` (`wheel_history.json` 41, `chronology.json` 2, `bible_journeys.json` 1) — silent absent text on web, invisible to every other test. Guard now walks all `assets/**/*.json` with pinned floors (1,200 files, 5,600 code points); fonts rebuilt via `tools/build_font_subsets.py`. A concurrent session's unrelated commit (`2220cb0`, marking-highlight fix) landed between the two. +7 tests. |
| `main` (older) | **0b209f0** — #318 phase 23: the linear chronology axis had no CJK face either — same class phase 22 fixed on the wheel, recurring because a `TextPainter` inherits no theme per call site. `chronology_page.dart`'s epoch labels (`nameFor(locale)`, 洪水/出埃及/摩西去世 in the default zh-Hans) and its axis-height probe (the string `'年0'`) both drew/measured through a bare `TextStyle`; the probe measuring a CJK glyph in a font that cannot render it triples the axis-strip shortfall via `axisStripHeight`. Also converted the year tick and `place_map.dart`'s journey-ordinal badge (both digits-only today, latent rather than shipped) so the guard can say "all of them". Widened `canvas_cjk_fallback_ratchet_test.dart`'s window from a forward-only 15 lines scoped to one file (11 offenders repo-wide, 7 false) to `[i-30,i+20)` over all of `lib/` (exactly the 4 real sites), added a pinned 18-painter census, an enumerated 2-site `.merge` exception list, and a widget test proving the ambient `DefaultTextStyle` actually carries the CJK chain. Full suite 3,789 green (includes a concurrent session's unrelated `copy marking` commit, `cf57c3c`, landed mid-run), analyze exit 0. NOT deployed — plan-mandated counter 1 of 3. |
| `main` (previous) | **f7778d2** — #318 phase 22: the wheel's own canvas text (ribbon names, spoke titles, verse refs, count badges, both measure helpers) had no CJK fallback. Added `canvasTextStyle()` to `font_catalog.dart`, converted the wheel's 8 inline canvas `TextStyle(` sites. +4 tests, 3,764 green, analyze exit 0. NOT deployed — counter 1 of 3 at the time. |
| `main` (before that) | **fce19c7** — #315 residue, second pass: closed the last deferred field, `word_study_style.dart`'s dense-column `translit`/`micro`. +4 tests, 3,751 green, analyze exit 0. |
| `main` (earlier) | **f3cac03** — #315 residue, landed the killed prior run's small-print-floor repair: all 52 `fontSize: t.chrome - N` sites raised to `t.chrome`. +1 test, 3,747 green, analyze exit 0. |
| deploy | **Skipped this iteration — plan-mandated counter 1 of 3.** Last deploy was `db79c5e` (v1.6.194, prod+dev, 2026-08-31, by a concurrent session); it carried everything up to that point, so the deploy counter restarted here. `./tools/release_web.sh` not run; no `pubspec.yaml` bump. |
| Suite | **Full run: 3,814 passed, 0 failed.** `flutter analyze` exit 0, run last after the final edit. |
| CI | Not re-checked this run. |

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
| #292 | Kings of Judah + Israel, synchronised, as a Resource | **this row was stale and is corrected here, 2026-08-26.** It read *"blocked — needs a citable Thiele source"*, and the feature is built and reachable: `assets/hebrew_kings.json` holds **42 kings and 4 epochs** with `_meta.sources` citing **Thiele, *The Mysterious Numbers of the Hebrew Kings*, 3rd ed. (1983)**, **McFall, *BibSac* 148 (1991): 3–45** for the co-regency years, and the Wikipedia Thiele columns; `lib/pages/hebrew_kings_page.dart` is 1,105 lines with `contemporariesOf`, kingdom columns, epoch markers and co-regency spans, pushed from `workbench_page.dart:593`. **The stated blocker is resolved — whether the ticket CLOSES is an owner call and this does not make it.** Verified by reading the asset and the call site, not by grep alone. |
| #293 | Sermon audio — permission settled, survey done, hosting undecided | **blocked** — needs a hosting decision |
| #295 | Live search audit — drive every syntax through the real box | open — the **grammar** half is done: `docs/SEARCH-AUDIT.md` is the query→count→verdict table, 4 wrong counts found (3 fixed, 1 withdrawn with both numbers), pinned by `command_grammar_audit_test.dart`. §6 names what still needs a human at a browser |
| #296 | Prod crash — root cause found and fixed (`9132a14`) | **blocked** — needs a fresh crash report to confirm |
| #299 | The `?` card teaches syntax you cannot run | closed — v1.6.144 |
| #300 | Map provenance — rights settled, the maps are the owner's own collection | **built and wired — closing is an owner call.** `assets/maps_provenance.json` (9 collections), `lib/models/map_provenance.dart`, `MapService.provenanceOf`, `mapCreditLine`, the per-plate credit bar (`map_viewer_page.dart:195`) and the About-page credits (`about_page.dart:639-656`) all exist and are wired; all three thumbnail surfaces (`atlas_page.dart:1476`, `illustrations_page.dart:417`, `bible_reading_pane.dart:5669`) push `MapViewerPage`; the CC-BY-SA Sweet collection carries `attributionRequired: true` with a rendered credit — verified 2026-08-31. Only item (5) of the ticket (asking the owner which sites/books the collection came from) is genuinely outstanding |
| #301 | Yahwehdehua — re-open the import; the base text matched, the readings did not | open — the lexicon half is **fixed** (v1.6.152, check 44); the readings are not |
| #302 | Build the backlog before the queue empties → `docs/PARITY-BACKLOG.md` | closed — 75 entries |
| #304 | Systematic data-integrity audit — "accuracy is the most critical thing" | open, recurring — check 45 landed 2026-08-23 |
| #307 | Phrasing — open it to translations, indent line one (Pastor Raymond HK) | **closed** — both halves. Translations: `PhrasingSource.translation` is the DEFAULT source (`phrasing_page.dart:192`) with `_translationWords()` behind it, answered for all 1,189 chapters. Line one: v1.6.98 unpinned it from zero — `phrasing_test.dart:636` "the first line indents too", including the clamp and the round-trip |
| #308 | Search stats: "John 27" never says its unit | **closed** — **v1.6.156**, all THREE surfaces. The strip and the Stats tab were fixed when the ticket was filed; `WordDistribution` was found still unlabelled 2026-08-24 and plotting the OTHER unit (its caller feeds `ConcordanceResult.byBook`, the per-book OCCURRENCE map — G25 was 37 in John there and 27 in the strip). `unit` is now required, not defaulted. `search_stats_unit_test.dart` + `word_distribution_unit_label_test.dart` |
| #309 | Matthew series — reconcile our corpus against CDC's 124 messages | **blocked** — CDC site unreachable |
| #312 | Phrasing is not usable yet — redesign, don't patch | open — **but the reason this row gave is stale, and every enumerated item is now shipped.** The row claimed the export work at `PARITY-BACKLOG.md:321`/`:445` was unbuilt; `:445` is the separate **Report Generator (bwh28)** entry, not a #312 item, and rich export *is* built (`exportPhrasingHtml` + `ClipboardHelper.copyRich`, `phrasing_test.dart:908`). The backlog's own list of remaining items at `:361` is "default range = the sentence, richer export, controls that teach" — sentence range shipped (`phrasing_sentence_test.dart`), export shipped, and **controls that teach shipped v1.6.161**. Item 7 was the last: the four chips offered Biblearc's vocabulary and the only way to learn what `+ Verbals` did was to tap it. **`bwh25` has no granularity control of any kind**, so a reader has no model of these levels from any other tool — and measured over 9,982 three-verse windows of the bundled corpus, `+ Verbals` draws the **identical page** in 2,087 (20.9%), `+ Phrases` in 356 and `Clauses` in 236. `availablePhrasingLevels` cannot see any of it: it asks whether the EDITION carries a parse, not whether this PASSAGE has a participle. Each chip now carries its line count and the chosen level names what it cuts at; equal adjacent counts are exact, not a hedge, because the levels are monotone supersets — proven over all **2,679** equal-count cases by comparing line STARTS, not just totals. **A second, unasked-for defect was found and fixed in the same commit**: the header is an unbounded `Column` above an `Expanded` diagram, so at the reader's largest font in a 480 px window it already overflowed by 20 px and left the diagram **0 px tall**; the new note would have taken that to 68 px. Capped at 55% of the pane with an internal scroll, the diagram now floors at ~152 px in every font × height cell, which is *better* than before this feature existed. `phrasing_page_header_test.dart` pumps the real page across that matrix and was confirmed to fail (48.5 px) with the cap removed. **Left open on purpose:** whether a ticket titled "redesign, don't patch" is satisfied is the reporter's judgement (Pastor Raymond HK), not the loop's — the conservative call is to ship the work and let the owner close it |
| #313 | The Reader is a phone app bolted into a workbench | **closed** — 2026-08-24, on re-reading the code rather than the row. Both items audit §7 left outstanding are already implemented: `onChapterSermons` routes through `_requestAnalysis(ReaderAnalysisRequest.sermons, …)` (`bible_reading_pane.dart` ~2020), and the reader's `StatsPage` push is behind `if (!hostChrome)` (~7052). The row was stale, not the code. Item 4 remains settled on paper only, and is **not** a defect — it is a design note carried in audit §7 |
| #314 | Build version printed twice on one screen | **closed** — the menu-bar copy is gone; the surviving one is the status bar's, chosen because it is tappable and opens `AboutPage` where the inert menu text was not. `workbench_version_display_test.dart` is a source ratchet on the call-site count |
| #315 | 269 hardcoded font sizes — #311 fixed the arithmetic, not the reach | **closed** — v1.6.179, on **ten** documented mechanisms, the last two found this iteration (a clamp that travels but is dead at 19 of 29 stops; and clipping, which no source ratchet can see because the source is correct). Residue is **10 sites, all documented non-defects**: 9 preset FIELDS in `app_style_preset.dart` and 1 monogram sized to its own `CircleAvatar`. The ticket closes on written exceptions rather than on zero, because a rule with no exceptions written down grows them silently. Two guards keep it shut: `test/font_size_reach_ratchet_test.dart` (source) and `test/book_chapter_picker_font_size_behaviour_test.dart` (behaviour + intrinsic-vs-granted). **Left for the owner:** the list and grid chapter tiles size differently for the same label, which is a design question the code cannot answer. |
| #316 | The rotate advisory argues against itself | **closed** — v1.6.132's □□□ was the last of it: `workbenchTheme` restated only five of fifteen styles with the parent's `fontFamilyFallback`, so `headlineSmall`/`titleMedium` drew Roboto, which has no CJK, with no gstatic fallback to rescue it. `theme_cjk_fallback_test.dart` now asserts *every* style in the theme can render Chinese |
| #317 | Journey routes on the atlas | open — **2026-08-31, `230f91e`: the ruler's own tooltip cited `kBandOnFoot`'s fixed sentence ("20–30 km a day") no matter which band the days above it were computed at, so a reader who picked carts or a vehicle got a number its own citation did not vouch for — `travelBandBasis()` already existed for the journey panel and the ruler simply never called it; it does now, appending `travelBandNotOurs()` on a non-default band exactly as the panel does. Because the band picker lives in that panel and a tooltip is a hover — unreachable on a tablet, and unreachable at all once the panel is closed while `travelBand` still reaches the map unconditionally (#312's finding) — a non-default band also now prints one visible footer line (`travelBandLabel()`, key `places-map-band`). +4 tests, 3,746 green, analyze exit 0. Deployed to dev v1.6.186.** — **2026-08-30/31, `841c0d4`: the ticket's one knowingly-unpaid item — the band was not reader-configurable, where bwh33's Travel Speed Window is — is now closed.** Three `TravelBand`s (12–20 / 20–30 / 30–36 km/day, ORBIS's own adjacent pairs, never a free-form speed) are offered from a `_bandPicker` in the journey panel, reaching both the panel's estimate and the map ruler through one shared `_band`; a non-default choice states `travelBandNotOurs`, whose own arithmetic (244.3 km, 13–21/9–13/7–9) is asserted against the shipped gazetteer. +7 tests, 3,742 green, analyze exit 0. NOT deployed, counter 2 of 3. — **2026-08-30, `ccdf1e6`: the atlas ruler's co-location abstention sentence (shipped uncommitted by the prior run) was ungrammatical in the 63.8% case it usually meets** — one co-located name rendered through the plural template as "Dung Gate — 1 in all — sit on the same map point", and the list join hardcoded the ideographic comma for English readers too. `samePointSentence()` now picks a singular/plural `ui_strings` key and a locale-aware separator; +7 tests. NOT deployed, counter 1 of 3. — **a travel-time estimate now ships, sourced, per-mode, and refusing where a chord cannot carry it (`b188a0d`).** BibleWorks' Ruler and Travel Speed Window (bwh33) turns a drawn distance into a **min and a max**; we had nothing like it on the routes, and the Atlas ruler footer meanwhile printed one confident `ceil(km / 32)` between two arbitrary gazetteer points — **estimating where the app knew least and refusing where it knew most**. The band is ORBIS's 20–30 km/day, both ends from one sentence, and the choice against ISBE's 32–40 was **decided by Deuteronomy 1:2**: 244.3 km for eleven days, which ISBE makes 7–8 (contradicting the verse) and ORBIS makes 9–13 (containing it). Sea and unstated legs get **no number and a stated reason**. **This gap is now closed** — see the `841c0d4` entry at the top of this row and the `main` row above. **all three routes the owner named on 2026-08-16 now ship.** `jesus-mark` (`fffae59`) is the third, 主耶稣路线: Mark 1:9–11:11, **one evangelist's own sequence, never a harmony of the four Gospels**, because a harmony is a reconstruction and a reconstruction drawn as a line is what this feature exists not to do. 14 stops, 13 legs, **478.6 km**. It surfaced the sibling of the wilderness route's *join that fails by succeeding*, and this one is **wrong rather than merely silent**: a gazetteer entry for a **region** carries a point and that point is usually some city's. `Judea` = **[31.77, 35.23], Jerusalem's own**; `Decapolis` = **[33.51, 36.31], Damascus**; `Galilee` = **byte-identical to Nazareth**; `Dalmanutha` = **byte-identical to `Magadan`** — *Matthew's* identification, so drawing it would smuggle in the very harmony the route forbids; `Gethsemane`/`Golgotha` = **Jerusalem exactly**; `Jordan` = one point for a 250 km river. Mark names every one; **eight are omitted**, the `basis` names them, and the asset test fails the build if one returns. The two `Sea of Galilee` stops went too — the point is the **lake's centre**, ~7 km offshore, and 1:16 has him walking *beside* it. **No sea leg at all**: every Markan crossing touches a place with no usable coordinate (6:32's solitary place; the Gerasenes of 5:1, absent from the gazetteer and itself a variant our KJV prints as *Gadarenes*), guarded by a test. **Sidon is the one provisional stop because our own two editions disagree** — BSB/LEB/NASB read διὰ Σιδῶνος, the shipped KJV reads *from the coasts of Tyre and Sidon*, which places him at neither. **A refuter was run on the draft and overturned two of my own claims**: Bethsaida 6:45 had been drafted as an `aside` on my inference that the crossing missed it — Mark never says so and 8:22 has them arrive — and `Dalmanutha`/`Magadan` I had not checked at all. **The sixth route spent the channel the palette had reserved for it since v1.6.134** (*"a sixth route should add a channel, not a sixth hue"*): `JourneyMark` — round=Acts, square=Torah, diamond=Gospels, **chosen by body of narrative, not slot arithmetic** — so identity is a **(hue, shape) pair** and Mark reuses slot 0's amber. Shapes are **equal AREA, not equal radius** (a square across the diameter is 27% heavier, an inscribed diamond 36% lighter), verified by **rasterising and counting opaque pixels**; the antialiasing residual scales with perimeter, so the test draws at r=100. The legend swatch draws the silhouette. **The short dash was widened in writing** from *"the text refuses the manner"* (Acts 20:1) to also cover *"the text routes them through a place we cannot locate"* — both promise the reader *this line is not underwritten as a direct journey*. Two defects fixed on the way: the journeys block was sized by the **data**, not the viewport, and overflowed a 320×640 pane by **34 px** at route six (now capped against the pane and scrolling inside it — my first regression test pumped 320×400 and was **rewritten after checking it against the pre-change tree, where it overflowed by 162 px**, i.e. it was a pre-existing limit and not what I had fixed); and `the straight-line totals` asserted a **500..20000 km** band that would have rejected Mark's 478.6 km **for being the right size**, now a **pinned total per route** — which immediately caught that the wilderness figure is **1,638.4 km**, not the 1,841 a naive sum of rows gives, because `straightLineKm` sums the **drawn** segments and a collapsed run contributes once. Luke, Matthew and John are natural further slices and now compose without a palette collision. Earlier: Pauline itineraries drawn (v1.6.134); the **wilderness itinerary** (Numbers 33, all 42 stations) landed 2026-08-24 in `0a14966`. Its order needs no reconstruction — 33:2 says Moses wrote the stages down — so the uncertainty is entirely in the gazetteer, and that surfaced a failure mode the ticket did not anticipate: **a join that fails by succeeding.** An unplaceable stop breaks the line and the panel has said so since v1.6.134; a stop placed ON TOP OF ITS NEIGHBOUR draws perfectly and says nothing. Measured through the app's own parser: **909 of 1,228 located places share a point** (1,228 places on 560 coordinates, 241 carrying more than one), and **27 of Numbers 33's 42 stations fall into 6 runs**, the largest 11 camps (Rissah…Bene-jaakan, badge `17–27`). Drawn stop-by-stop: **37 legs, 21 of them exactly zero km** — eleven badges overprinting into the smudge `ordinalsByPlace`'s own doc comment had warned about since v1.6.134 without the code implementing it. **0 of the 4 Pauline routes have a collapsed run**, which is why a week of shipped routes never revealed it; keying on `markerKeyFor` (the coordinate) is a strict generalisation and no Pauline expectation changed. Runs draw as one marker with a range-compressed badge (en dash, and **only where consecutive** — `8,10` is Lystra visited twice and `8–10` would be a false claim), emit no zero-length leg, and are counted on the panel. **The wording is about the DATA, never the scholarship**: unidentified sites and genuinely adjacent places (Jerusalem's gates) are indistinguishable here, so "share one map point" ships and "location unknown" does not. Doubt sits at a run's ENDS and nowhere else — a leg is provisional when the text does not place the travellers at one of *its two ends*, and a mid-run camp is not an end of anything. Two camps have no coordinate at all (Pi-hahiroth 33:7, Hor-haggidgad 33:32) and **break** the line; they are enumerated by name in `journey_asset_test.dart`, two-sided, because a typo and an unidentified site reach the resolver as the same event. `docs/DATA-INTEGRITY.md` check 48 |
| #318 | Interactive Bible chronology, featured module | open — **phases 1–24 shipped.** **Phase 24 disclosed the chart's own header.** `wheel_history.json`'s `_meta` carried eight fields and `WheelHistoryData` parsed none of them — the provenance defence (no date taken from a copyrighted chart) and two statements of absence shipped unreachable, invisible to the disclosure test written for exactly this class because it iterates the four record lists, not the header. `provenance`/`coverage`/`axis` promoted to trilingual maps, `WheelHistoryMeta` added and wired through the `load()` merge literal that dropped fields in phases 19/21 (now a `required` param, so a missed wire is a compile error), surfaced via a new "About this chart" AppBar action. +6 tests, 3,814 green, analyze exit 0. Deploy SKIPPED at counter 1 of 3. Full detail in the `main` row above. **Phase 23 found the same CJK-canvas defect recurring one page over from phase 22.** `chronology_page.dart`'s linear axis draws its five epoch names and measures its own strip height through bare `TextStyle`s, same as the wheel did — the axis-height probe is sharper still, since its string is literally `'年0'` with a comment naming it as the tallest glyph the strip must hold, measured in a font that cannot render it. The ratchet from phase 22 was itself too narrow (forward-only 15-line window, one file) to have caught this; widened to `[i-30,i+20)` over all of `lib/`, with a pinned per-file census and an enumerated `.merge`-exception list so the hole cannot reopen silently. Deploy SKIPPED at counter 1 of 3. Full detail in the `main` row above. **Phase 22 fixed the same defect class as #316, recurring on the canvas path #316 never reached: the wheel's `TextPainter`-drawn text (ribbon names, spoke titles, verse refs, badges, the two measure helpers) had no CJK fallback, so Chinese drew blank on the web build in the app's default locale, zero fallbacks in the file against 32 of 36 on the comparable atlas page.** A `TextPainter` inherits no theme, so #316's theme-level fix never reached it. New `canvasTextStyle()` helper in `font_catalog.dart`; the wheel's 8 inline canvas `TextStyle(` sites converted to it, the 51 theme-inherited `Text`-widget styles left alone. New source-ratchet `test/canvas_cjk_fallback_ratchet_test.dart`, confirmed failing on the unmodified tree before the fix. `chronology_page.dart`, `bible_timeline_page.dart` and `place_map.dart` carry the same class, measured and deliberately deferred to a future run. +4 tests, 3,764 green, analyze exit 0. Deploy SKIPPED at counter 1 of 3. Full detail in the `main` row above. **Phase 21 closed the last field the merge dropped, and named the defect CLASS rather than the instance.** `bibleNarrativeEvents` drops any `TimelineEvent` field `WheelHistoryEvent` has no constructor parameter for, silently and invisibly to every test in the repo; it has done so three times — `basis`, then `datingRefs`/`septuagintYear`/`era`, then `personIds`. **37 people across 61 of 98 events, 88 links**, and **five names the wheel answered “no results” for in all three scripts**. Four were true absences (Aaron, Amram, Jochebed, Miriam); **Jeconiah was a naming mismatch, not an absence** — the wheel carries him as Jehoiachin / 约雅斤 — and the claim is hedged rather than dropped. `wheel_timeline_field_coverage_test.dart` now reads both class declarations out of the source, with its own measured blind spot (`era`, read for a decision while its value went nowhere) written into it. **Twelve family-tree ids are also wheel record ids** and are pinned. Deploy SKIPPED at counter 1 of 3; one photograph owed. Full detail in the `main` row above. **Phase 20 found that the chronology and the family tree name the same people and had never compared notes.** `bible_timeline.json` carries `personIds` on 61 of 98 events — 88 links naming 37 people — and the field appeared at exactly three lines in all of `lib/`, all three inside the model: **a field with no call site is a field with no audit**. They disagreed about Moses by one year in both directions, with **both files stating it exactly, on the same basis, citing the same two verses** — one derivation written twice with one copy contradicting its own arithmetic — so `family_tree` was repaired and `corrections` records it. The durable output is the **decision rule**: both sides exact → repair; either side hedged → name it and leave it. Jesus and Ishmael are named and left. The field is now rendered as person chips opening `PersonDetailSheet`, and the render exposed a **false absence** in search (耶哥尼雅 appears in no event text anywhere in the asset). Deployed v1.6.183. **Phase 19 shipped the apparatus the wheel had inherited the Bible's dates without:** phase 17 carried 97 timeline records onto the wheel and carried only their *years*, so `datingRefs`, `septuagintYear` and the era key were dropped **at the constructor** with nothing failing — 18 records lost the verses their year was counted along, 8 lost the Septuagint alternative, 8 antediluvian records arrived with no trace of the seam. No new wording was minted; the four existing `uiStrings` keys were reused so the two surfaces cannot drift into saying different things about one event.  **Phase 18 found that the wheel's SCALE had never been guarded, and that it was printing a year that never existed.** Three of the page's four families of words had a guard; the fourth — twelve 500-year ticks and two axis ends — had none, because every audit of this page had audited what the **data** says and the scale is not data. Placed by constants (`rRim + 11`/`+ 22`, `+ 17`) that knew nothing of the strings they positioned, **210 of 504 labels reached inside the rim, 113 pairs of ink actually overlapped event titles, and `AD 1000` was clipped off the canvas at 700 px**. A constant cannot work there: a horizontal label is not rotated with its ray, so its reach inward is the support function `w/2·|cos a| + h/2·|sin a|`. The century labels now lie **along the ring**, the two ends are placed by the support function itself, and **the origin tick no longer says `AD 0`** — it says `BC | AD` / `主前｜主后` / `主前｜主後`, a boundary rather than a year the reckoning does not have. The new 14-test guard was **run against the pre-fix placement first and 6 of its 14 assertions went red**, which is how two of the three defects were discovered. Full detail, the refuter's verdict on year 0, the bwh39 finding (BibleWorks makes axis label spacing a *user* setting) and the stated reason the deploy was skipped are in the `main` row above. **Phase 17 put the Bible's own narrative on the wheel** — 97 curated events merged at load, taking it to 588 records / 754 search hits, and retiring phase 14's refusal by measuring the *new* declutter instead of the old one. It also fixed a shipped accuracy defect one module over: `localizedReferenceLabel` printed **79 of 4,999** references narrower than they were written, including a bare `Leviticus` as `Leviticus 1`. Full detail, the rejected refuter finding, the conservative `antediluvian`→`world` call and the phase-18 candidate (century labels colliding with rim labels — **pre-existing**, 25 wheel-native instances against 10 injected) are in the `main` row above. **Phase 16 gave the 657 records a way to be asked for, and fell over a script defect in three files on the way** — `主后`/`主後` chosen by `startsWith('zh')`, which is true for both scripts and so can never choose. Full detail, the deliberate `bwh39` departure, the sweep that had to be built three times, and the three defects the *photograph* of v1.6.180 found are in the `main` row above. **Phase 15 fixed what phase 14 predicted: the declutter, not the data.** Phase 14 refuted injecting 89 NT events by measuring that the wheel would draw 0 of them; phase 15 measured the declutter itself and it was worse than the survey said — **55 of 491 drawn at rest on a 900 px canvas, 136 at the viewer's ceiling of 14x**, and a dropped event had **no hit target at all**, because `_handleTap` iterates the drawn spokes. `clusterByAngle` now groups on the same keep-rule read the other way (identical representatives at identical angles, so the wheel does not move), each survivor carries a `+n` badge, and a tap lists every member. Full detail, both columns of the badge's cost, the two instrument traps and the one asset finding left alone are in the `main` row above and in `HANDOFF.md`. **Phases 1–14 below.**  **Phase 14 is the second time running that a refuted feature uncovered an accuracy defect in what already ships, and the pattern is now worth trusting.** The plan was to inject `bible_timeline.json`'s 89 events into the wheel; the mandated refuter measured that the greedy angular declutter (`radial_chronology_page.dart:685`) would draw **0 of 23 NT events at any zoom** — six share the year 33 and the whole NT spans about one `minGap` — while **evicting 17 existing wheel events**. The feature would have shipped the exact absence it existed to fix. **Do not re-derive it; a year-ordered first-past-the-post declutter cannot show a dense cluster, and the fix is a different declutter, not more data.** What the refutation exposed instead: the wheel dated **the division of the kingdom to 930 BC while the other two assets said 931**, under a `scripture+thiele` label the page prints as *"interval from scripture, year from Thiele"* — false by `wheel_history.json`'s own `_meta.basisValues`, since `hebrew_kings.json` **is** this app's Thiele chart and says 931. Three records moved. The structural finding is that **none of the three chronology assets shares an id with another**, so nothing could join them and nothing could see the drift; `test/cross_asset_year_agreement_test.dart` writes that join by hand (6 facts, 23 statements, all 3 assets) and fails first on any path that stops resolving. **Which of 931 and 930 is right is still #292's question and this does not answer it** — the test asks only that the app not state one fact two ways, which is a defect whichever side is correct. **Phase 13 was an accuracy fix that a refuted feature uncovered:** the ledger cited 1 Kings 6:1 for a total the Septuagint states across **two** of its own units (the 440th year in `6:1`, the founding in `6:1c`, both folded into one record because our keys are the Hebrew's numbering). Both are now read from the `<vs:>` markers and disclosed; the Hebrew states both in one clause and correctly carries no disclosure. **The dead end is on the record so nobody re-derives it:** the axis must NOT be extended past Moses to the temple, because one span there asserts the counted interior (530/520) fits inside the stated total (479/439) — the overrun is the finding.  Bars run to the death of Moses; the exodus→temple era is **counted below the chart, never drawn** (MT 530 vs 479, LXX 520 vs 439). Phase 7 disclosed the one-year choice at the flood (Genesis 7:6's cardinal over 7:11's ordinal). Phase 8 gave each dated event a sheet, so the five epoch `note` paragraphs finally render, and localised every citation the page prints. **Three guards now stand on this asset**, each blind to what the others see: a rendered sweep for any Latin run (chart, ledger, Moses' panel, all five sheets), an asset walk over every `zh-Hans`/`zh-Hant` string, and a check that all 85 references localise. Phase 9 rendered the last unreachable block — the six provenance sentences and two counts, now a "How this chart was made" sheet — and fixed the three untrue claims that surfaced when they were read for the first time (a join key that silently skipped 5 of 28 witness rows; "23 Anno Mundi birth years" for 9 comparisons that are intervals; a begetting age claimed for three men who have none). **This module now has no unrendered getter** — every accessor on `lib/models/chronology.dart` was swept for a call site outside the model and all of them have one; the era's gaps, divergence and summary were checked rather than assumed (a first draft of this row claimed they were the next gap and was wrong). Phase 10 took the same defect one module over, to `radial_chronology_page.dart`, and it was worse there than the survey said. The **111** references it printed in English to Chinese readers now route through `localizedReferenceLabel` at all three sites, storage staying English because `parseReference` reads it back. But sweeping the asset for what nothing rendered found **42 more references that were not printed in any language**: `WheelPower` parsed neither `ref` nor `refs` nor `basis`, on the authority of the model's own doc comment — *"Nothing is read out of scripture, so nothing here carries a verse"* — which was false when written and shaped the class. Reading the unread `basis` corrected a **printed falsehood**: `_showPower` hardcoded 通行年份 · 非经文所载, so the three `scripture+thiele` kingdoms denied scripture for spans the asset derives from it. And **no detail sheet on this page could be opened at all in a debug build** — `WbType.of` watches, a tap handler is not a build — a pre-existing crash the whole suite was blind to because *the page at rest shows no reference*, so the sweep guarding it passed by never opening anything. Guards: the sweep now taps 8×16 in polar coordinates and floors on sheets opened **and** references found; a source-derived detector parses `wheel_history.dart` for the `j['…']` literals each class actually reads and makes every unread key **assert its own excuse** (nations' `approximate`/`basis`/`era` are constant across all 82; `region` tracks `stream`; `ongoing` must equal `end == null`); and all 55+82+42 refs are asserted to parse *and* localise before anything renders them. Phase 11 took that next slice — **the wheel's canvas** — and the blindness was hiding a defect, not just a risk. Every rim label was handed a **constant-width box** (`span*0.36` scripture, `span*0.40` conventional, ~40 px at 700 px) whatever it said, then cut two characters at a time. At 900 px and rest **0 of 55 English labels were drawn whole and 46 of 55 Chinese ones were ellipsised**, breaking **#297**: `莫斯…` is not an abbreviation of 莫斯科. The fix moves the *decision* out of the painter into **`planRadialSpokes`**, which returns the resolved strings, so a test can finally read canvas text; a label is now **legible or absent** (Chinese whole-or-nothing, Latin cut only at a space) and the **tick always draws**, so nothing becomes untappable. English went 0→31 whole +24 word-cut, Chinese 9→**55 of 55**, and **the verse on the label 0 of 4 → 3 of 4** — the promise `_radialLabel`'s comment had made and never kept, and the thing BibleWorks' Timeline (`bwh39`) does. The two-zone "scripture baseline" was re-encoded as **anchoring** (scripture out from the bands, conventional in from the rim, both using the whole annulus, provably non-colliding); it is explained nowhere on screen, and only **5 of 491 events** are scripture-dated with **1** visible at rest. `test/wheel_label_legibility_test.dart` loads the real faces and sweeps 3 locales × 2 sizes × 3 zooms. **`stackRadialLabels` is provably unreachable** and is now pinned as such. Phase 11 predicted the next slice would be the band names; **phase 12 measured them and that prediction was wrong.** The band names are sound (0 ink collisions, worst clearance 0.91 units) and were left untouched; the defect was one ring in, in the **arc labels**, where a `.clamp(6.0, 10.0)` bound at its floor and held every power name at 6.00 canvas units — 48 px at 800% zoom, a drawn set that never grew with zoom, and at 700 px **every** drawn label's ink overrunning the 5.41 ring pitch onto the neighbouring stream. `fitArcLabel` reads the floor in screen units, caps at 0.9 of the pitch, and re-measures rather than back-solving; `selectionCovers` separately fixes a band tap dimming the whole wheel. `test/wheel_arc_label_behaviour_test.dart` (18 tests) loads the real faces and measures **ink** by rendering to a `Picture` and scanning alpha, because the line box is not the ink and the line-box reading is what produced the wrong band-name verdict. **Open for the owner:** the arc-label floor stays at 6 px against #315's chrome floor of 11, since 11 would leave the chart unnamed below ~200% zoom. **PHOTOGRAPHED AT LAST, 2026-08-25 on v1.6.180/181, and the claim that stood in this row for four phases is discharged.** The wheel's type had never been seen on a deployed build; it has now, in the shipped faces rather than `flutter test`'s stand-in. The declutter was confirmed in the only place it is visible: typing *Magna Carta*, tapping the one hit, and watching a **Magna Carta… label appear at AD 1215 where a moment earlier there was none** — selection forcing a record through the declutter, on screen, not in an assertion. |
| #319 | Atlas filter filters the list but not the map | **closed** — the map now takes the subject filter, and the state that fixed it is documented in place: `atlas_page.dart:142` "Whether the map also draws what the filter left out", with `:149` holding the subject ids while the chip is up. The filter is dismissible by design — an atlas that could only ever show the filtered set is a worse atlas |
| #320 | Place records should show the illustrations we already have | **closed** — `lib/utils/place_illustrations.dart` joins the picture database to the gazetteer. #320 made the feature conditional on measuring the join rate FIRST, and `place_illustrations_test.dart` freezes that measurement rather than quoting it in a commit message: if a plate is added or a caption edited and the join moves, the suite says so |
| #321 | Greek search cannot match accented input (Aunty Rosa, Hong Kong) | closed — v1.6.126; `foldDiacritics` wired into `text_patterns.dart:171`, `command_query.dart`, `search_highlight.dart` |
| #322 | The Browse column does not line up — three render paths | **closed** — v1.6.178, on the visual sign-off that was the only thing left. Read 2026-08-24 and it looks already done, but nobody has looked at it:** `BrowseVerseRow` (`browse_window.dart:889`) is now the single row for all three paths — one `ConstrainedBox(minWidth: referenceWidth)` plus `Expanded(child:)` — and the gap/spacing are single constants (`kBrowseWordGap`, `kBrowseRunSpacing`). The three render paths the ticket names no longer diverge in source. **2026-08-24 measured it instead of reading it, and the column was straight only by luck:** `referenceGutterWidth` modelled the width with no letter spacing while the reference `Text` inherited `bodyMedium`'s 0.25 from the ambient `DefaultTextStyle`, so the painted string ran `runes.length × 0.25` px wider than the box computed for it — absorbed by the 8 px gap, which is a constant covering another constant's mistake. Fixed by naming `kBrowseReferenceLetterSpacing` and passing it to both sides. `browse_reference_real_font_test.dart` is the first test here to lay strings out in the **shipped** faces (`FontLoader` + `rootBundle`; `flutter test` otherwise renders a fixed-width stand-in, which is why every earlier test compared the model only to itself) and sweeps 990 references × 5 sizes with none overflowing. The doc comment's calibration figures were also wrong — measured English +4.19%…+19.57%, Chinese +1.34%…+3.90%; **the CJK margin is 3× thinner and structurally so**, since Han is charged exactly 1.0 em and a Chinese reference's whole slack is its ` 1:1` tail. **2026-08-25 looked at it, on the deployed dev build, and picked the case the measurements say is worst.** The reference's script follows `versionCodes.first`, not the UI locale (`browse_window.dart:576` → `bookScriptFor`), so a `雅繁+`-first stack prints a Traditional reference under an English browser — which is how the thin-margin case was reached without touching the locale. Photographed at 1400×900, default 20 pt: **帖撒羅尼迦後書 1:1**, the canon's longest book name at 7 Han characters, across 雅繁+ · BSB · NASB · KJV · BGT — five rows, every reference ending on the same x, un-ellipsised, every verse text and every WRAPPED line starting on the same x. Then Lamentations 1, which puts the thinnest margin and the RTL case on one row: **耶利米哀歌 1:1** for 雅繁+ · BSB · NASB · KJV · **WTT**, the Hebrew right-aligned inside its cell with its reference still at the left, outside the `Directionality` scope. The ticket's four requirements are met on screen, not only in a test. **A ratchet now holds the shape the ticket was about**, because neither fix had a test and a widget test cannot supply one — `FetchVerses.loadVerseList` does not resolve under `flutter test`, so `browse_window_tagged_test.dart` never leaves its spinner. `browse_render_paths_ratchet_test.dart` (7 tests) pins: exactly ONE `BrowseVerseRow` construction for all three paths, the reference never interpolated or spanned into the verse line, each fixed column measured exactly once, `kBrowseReferenceLetterSpacing` named on BOTH the measure and the paint side with no literal `letterSpacing:` anywhere in code, the superscription indented by the same `referenceWidth`, and the one row built by `_RowView` above every `TextDirection.rtl`. **Sized against the commits before each fix rather than asserted**: at `72a618f^` (before the unification) **5 of 7 fail**, including the interpolated-reference guard; at `440084e^` (unified, measured without the tracking) **exactly 2 fail** — the identity guard and the measure/paint pair. Each assertion catches the fix that names it |
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
  screenshot costs ~1.5–2k tokens. **But a suite that renders one locale is
  blind to the others by construction, and that is not a judgement call — it
  is a hole.** Every widget test here renders the `zh-Hans` default, and
  Chinese does not inflect for number, so **"1 results" shipped and nothing
  in 3,624 tests could have seen it**. When a string varies by count, gender
  or script, assert it **off the string table**, not off a render. And a
  `ListView` in a `Flexible` takes every pixel the sheet is allowed whatever
  it holds — a *height* is not something reading rows can see either. (phase
  16, v1.6.180 → v1.6.181)
- **A layout that fits its text to the room reaches a different distance in
  each locale, so photograph the locale whose text is *densest*, not the one
  you read.** `planRadialSpokes` drops a label's reference when it will not
  fit; English titles are long, so English dropped it and the label stopped
  short of the rim. Chinese titles are compact, the reference survived, the
  label ran further out — and collided with the century tick. **The defect
  was there in English too and was structurally invisible there.** (phase 17)
- **A navigation parser is not a label formatter.** `parseReference` answers
  "where does this land?" and discards everything it does not need to get
  there — range ends, second ranges, and a bare book's missing chapter, which
  it *invents* as 1. Re-rendering a printed reference from it printed 79
  shipped references narrower than they were written. If you print a
  reference the user wrote, keep the user's own extent. (phase 17)
- The three-pane threshold is mirrored in `workbench_fit.dart` **and**
  `workbench_page.dart:132`.
- Book names go through `localeAwareBookName`, always.
- Never ellipsis a CJK label.
- Credit Pastor Eric H.H. Chang 张熙和牧师 **with** the H.H.
- Never invent a date; name the chronological system (Thiele/Albright/Galil).
- **NASB assets must never be committed or deployed** — `assets/nasb-ev.json`,
  `assets/nsn-plus.json`, `assets/tagged/nsn-plus/`. They are `.gitignore`d
  **and** absent from `pubspec.yaml`, so no build can pick them up; do not
  "restore" them into a worktree or a build tree. The NASB the reader sees is
  the separate, tracked, bundled `assets/nasb.json` (`pubspec.yaml:85`).
