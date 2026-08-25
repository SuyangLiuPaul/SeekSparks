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

Last updated: 2026-08-25 (sixteenth entry)

---

## Where the build is

| | |
|---|---|
| `pubspec` / dev | **1.6.179** — #315 closed: the tenth way a size escapes the Font Size slider, and a clipped number on the app's primary navigation surface. Deployed 2026-08-25 by the loop **from a detached worktree at the pushed SHA `6d9ced0`**, because the owner had pushed 20 minutes earlier and was live in the tree. Verified rather than assumed: `version.json` reads `1.6.179` on **both** the alias and the immutable URL `6a8d648d8436220a9cd0f832--seeksparks-dev.netlify.app` (they agree, so this is not the overwrite-by-the-other-writer case), and the deployed `main.dart.js` carries the corrected offline note (`refreshing the news digest`, ×2 — the string and its fallback) and **zero** occurrences of the withdrawn `Google photo` claim. |
| `pubspec` / dev (previous) | **1.6.178** — #322 closed: the ratchet on the Browse pane's three render paths plus the visual sign-off. Cut from a worktree at `f242200`. Two claims written into this row at the time were false and are withdrawn: it was not the first worktree deploy (check 45g's was, at `c49eb05`), and a worktree does **not** ship a bundle without the NASB — `assets/nasb.json` is tracked and listed at `pubspec.yaml:85`, so the licensed files hand-copied into that worktree never needed to be there and must not be again. |
| prod (seeksparks.netlify.app) | **1.6.136** — 21 versions behind, by design: prod ships only on the owner's word |
| `main` | **6d9ced0** — #315 closed (release bump `d4d12f7`). **Two mechanisms, neither visible to the nine already documented.** The tenth is a clamp that *travels* and is still dead: `(fontSize - 2).clamp(12, 20)` gives 18 at 20 pt and 20 at 40 pt, so the ratchet's ceiling rule passed it — yet it is identical at **19 of the slider's 29 stops**. The rule is now strictly stronger (dead if the last two stops agree, not if the whole range does); measuring the tree found **exactly four** such sites, three text and one padding, and the padding was a false positive, so the heuristic now asks what the expression **binds to** before asking whether it is a size — budgeting it would have filed a real defect beside a non-defect and stopped both being read. The second is not a size at all: the chapter grids grow the label with the font but not the box, so past a threshold the label does not shrink, it **CLIPS**, and a clipped number is a *plausible wrong number* — Psalm 119's `176` reads `17`, chapter `150` reads `15`. **No source ratchet can see this, because the source is correct.** It needed a fourth instrument: lay the label out unconstrained with a `TextPainter` in the style read back off the pumped `RichText`, and compare against the width the tile actually granted (`tester.getSize`). INTRINSIC > GRANTED is a clip whatever the style says. The two views got different repairs because they have different freedoms — the grid trades a column (`columnsThatFit`), the list grows the box (`math.max` against the breakpoint). **The list-view case is NOT invisible at the default**, unlike every other repair on this ticket: measured against `300dcfd`, `150` wanted 54.8 px in a 52.0 px tile **at 20 pt**, so it has been clipping for every reader since it shipped. The magnitude is instrument-dependent (Roboto here vs the shipped `-apple-system`); the sign is not. Also three **untrue strings**, blast radius measured rather than assumed: the offline note promised a font download bundled since v1.6.73 and a cloud sign-in that no longer exists, and the profile notice described a Google photo overriding the local one — 2 rendered strings, 3 claims, 1 dead key (`cloudSignIn`, deleted rather than corrected, because there is nothing to correct it *to*), 2 `??` fallbacks repeating them, 1 stale source comment. 6 of the 8 new assertions were run against `300dcfd` and fail there. |
| `main` (previous) | **17d6a6d** — the OWNER's CI fix, not the loop's: the chronology wheel's fit-count assertions had **zero** margin, so `main` was red on CI for 6 consecutive runs across 4 loop iterations that never noticed, because the loop's local `flutter test` runs on macOS and this is a Linux-only text-metrics gap. **Standing lesson for the loop: a green local suite is not a green CI.** Before that, `f242200` — #322 closed. |
| deploy | **done — v1.6.179 to dev.** The undeployed counter stood at **1 of 3**, so the trigger was the other one: **#315 is human-reported and it is now fixed.** Prod untouched and unasked-for. Cut from `git worktree add /tmp/ss-deploy 6d9ced0 --detach` — the tracked tree was clean and the 2026-08-25 rule permits an in-place build in that case, but the owner had pushed 20 minutes earlier, so a build racing his next edit was the avoidable risk and the worktree costs only one cold build. **Nothing was copied into the worktree**, per the correction in the row above. Worktree removed after. Next undeployed iteration is **1 of 3**. |
| Suite | **3,560 tests** (+8 this iteration), green locally; `flutter analyze` exit 0, run last, verified by exit code. **Re-run after rebasing onto the owner's `17d6a6d`, not just before** — the tree that was verified must be the tree that ships. Note his commit: local green ≠ CI green. |
| CI | **green on `6d9ced0`, read from `gh run list` rather than inferred** (`d4d12f7`, the release bump, was still in progress at the time of writing). The previous "green" written in this row was **wrong**: the owner's `17d6a6d` records `main` red for **6 consecutive runs over 2.5 hours across 4 loop iterations**, none of which noticed, because the loop reads its own macOS `flutter test` and that failure was Linux-only (`f242200`, `6902631`, `300dcfd` all failed — three of them are named in the rows above as if they shipped clean). **Fill this row from `gh run list --json headSha,conclusion`, never from a local run.** |

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
| #315 | 269 hardcoded font sizes — #311 fixed the arithmetic, not the reach | **closed** — v1.6.179, on **ten** documented mechanisms, the last two found this iteration (a clamp that travels but is dead at 19 of 29 stops; and clipping, which no source ratchet can see because the source is correct). Residue is **10 sites, all documented non-defects**: 9 preset FIELDS in `app_style_preset.dart` and 1 monogram sized to its own `CircleAvatar`. The ticket closes on written exceptions rather than on zero, because a rule with no exceptions written down grows them silently. Two guards keep it shut: `test/font_size_reach_ratchet_test.dart` (source) and `test/book_chapter_picker_font_size_behaviour_test.dart` (behaviour + intrinsic-vs-granted). **Left for the owner:** the list and grid chapter tiles size differently for the same label, which is a design question the code cannot answer. |
| #316 | The rotate advisory argues against itself | **closed** — v1.6.132's □□□ was the last of it: `workbenchTheme` restated only five of fifteen styles with the parent's `fontFamilyFallback`, so `headlineSmall`/`titleMedium` drew Roboto, which has no CJK, with no gstatic fallback to rescue it. `theme_cjk_fallback_test.dart` now asserts *every* style in the theme can render Chinese |
| #317 | Journey routes on the atlas | open — **all three routes the owner named on 2026-08-16 now ship.** `jesus-mark` (`fffae59`) is the third, 主耶稣路线: Mark 1:9–11:11, **one evangelist's own sequence, never a harmony of the four Gospels**, because a harmony is a reconstruction and a reconstruction drawn as a line is what this feature exists not to do. 14 stops, 13 legs, **478.6 km**. It surfaced the sibling of the wilderness route's *join that fails by succeeding*, and this one is **wrong rather than merely silent**: a gazetteer entry for a **region** carries a point and that point is usually some city's. `Judea` = **[31.77, 35.23], Jerusalem's own**; `Decapolis` = **[33.51, 36.31], Damascus**; `Galilee` = **byte-identical to Nazareth**; `Dalmanutha` = **byte-identical to `Magadan`** — *Matthew's* identification, so drawing it would smuggle in the very harmony the route forbids; `Gethsemane`/`Golgotha` = **Jerusalem exactly**; `Jordan` = one point for a 250 km river. Mark names every one; **eight are omitted**, the `basis` names them, and the asset test fails the build if one returns. The two `Sea of Galilee` stops went too — the point is the **lake's centre**, ~7 km offshore, and 1:16 has him walking *beside* it. **No sea leg at all**: every Markan crossing touches a place with no usable coordinate (6:32's solitary place; the Gerasenes of 5:1, absent from the gazetteer and itself a variant our KJV prints as *Gadarenes*), guarded by a test. **Sidon is the one provisional stop because our own two editions disagree** — BSB/LEB/NASB read διὰ Σιδῶνος, the shipped KJV reads *from the coasts of Tyre and Sidon*, which places him at neither. **A refuter was run on the draft and overturned two of my own claims**: Bethsaida 6:45 had been drafted as an `aside` on my inference that the crossing missed it — Mark never says so and 8:22 has them arrive — and `Dalmanutha`/`Magadan` I had not checked at all. **The sixth route spent the channel the palette had reserved for it since v1.6.134** (*"a sixth route should add a channel, not a sixth hue"*): `JourneyMark` — round=Acts, square=Torah, diamond=Gospels, **chosen by body of narrative, not slot arithmetic** — so identity is a **(hue, shape) pair** and Mark reuses slot 0's amber. Shapes are **equal AREA, not equal radius** (a square across the diameter is 27% heavier, an inscribed diamond 36% lighter), verified by **rasterising and counting opaque pixels**; the antialiasing residual scales with perimeter, so the test draws at r=100. The legend swatch draws the silhouette. **The short dash was widened in writing** from *"the text refuses the manner"* (Acts 20:1) to also cover *"the text routes them through a place we cannot locate"* — both promise the reader *this line is not underwritten as a direct journey*. Two defects fixed on the way: the journeys block was sized by the **data**, not the viewport, and overflowed a 320×640 pane by **34 px** at route six (now capped against the pane and scrolling inside it — my first regression test pumped 320×400 and was **rewritten after checking it against the pre-change tree, where it overflowed by 162 px**, i.e. it was a pre-existing limit and not what I had fixed); and `the straight-line totals` asserted a **500..20000 km** band that would have rejected Mark's 478.6 km **for being the right size**, now a **pinned total per route** — which immediately caught that the wilderness figure is **1,638.4 km**, not the 1,841 a naive sum of rows gives, because `straightLineKm` sums the **drawn** segments and a collapsed run contributes once. Luke, Matthew and John are natural further slices and now compose without a palette collision. Earlier: Pauline itineraries drawn (v1.6.134); the **wilderness itinerary** (Numbers 33, all 42 stations) landed 2026-08-24 in `0a14966`. Its order needs no reconstruction — 33:2 says Moses wrote the stages down — so the uncertainty is entirely in the gazetteer, and that surfaced a failure mode the ticket did not anticipate: **a join that fails by succeeding.** An unplaceable stop breaks the line and the panel has said so since v1.6.134; a stop placed ON TOP OF ITS NEIGHBOUR draws perfectly and says nothing. Measured through the app's own parser: **909 of 1,228 located places share a point** (1,228 places on 560 coordinates, 241 carrying more than one), and **27 of Numbers 33's 42 stations fall into 6 runs**, the largest 11 camps (Rissah…Bene-jaakan, badge `17–27`). Drawn stop-by-stop: **37 legs, 21 of them exactly zero km** — eleven badges overprinting into the smudge `ordinalsByPlace`'s own doc comment had warned about since v1.6.134 without the code implementing it. **0 of the 4 Pauline routes have a collapsed run**, which is why a week of shipped routes never revealed it; keying on `markerKeyFor` (the coordinate) is a strict generalisation and no Pauline expectation changed. Runs draw as one marker with a range-compressed badge (en dash, and **only where consecutive** — `8,10` is Lystra visited twice and `8–10` would be a false claim), emit no zero-length leg, and are counted on the panel. **The wording is about the DATA, never the scholarship**: unidentified sites and genuinely adjacent places (Jerusalem's gates) are indistinguishable here, so "share one map point" ships and "location unknown" does not. Doubt sits at a run's ENDS and nowhere else — a leg is provisional when the text does not place the travellers at one of *its two ends*, and a mid-run camp is not an end of anything. Two camps have no coordinate at all (Pi-hahiroth 33:7, Hor-haggidgad 33:32) and **break** the line; they are enumerated by name in `journey_asset_test.dart`, two-sided, because a typo and an unidentified site reach the resolver as the same event. `docs/DATA-INTEGRITY.md` check 48 |
| #318 | Interactive Bible chronology, featured module | open — phases 1–13 shipped. **Phase 13 was an accuracy fix that a refuted feature uncovered:** the ledger cited 1 Kings 6:1 for a total the Septuagint states across **two** of its own units (the 440th year in `6:1`, the founding in `6:1c`, both folded into one record because our keys are the Hebrew's numbering). Both are now read from the `<vs:>` markers and disclosed; the Hebrew states both in one clause and correctly carries no disclosure. **The dead end is on the record so nobody re-derives it:** the axis must NOT be extended past Moses to the temple, because one span there asserts the counted interior (530/520) fits inside the stated total (479/439) — the overrun is the finding.  Bars run to the death of Moses; the exodus→temple era is **counted below the chart, never drawn** (MT 530 vs 479, LXX 520 vs 439). Phase 7 disclosed the one-year choice at the flood (Genesis 7:6's cardinal over 7:11's ordinal). Phase 8 gave each dated event a sheet, so the five epoch `note` paragraphs finally render, and localised every citation the page prints. **Three guards now stand on this asset**, each blind to what the others see: a rendered sweep for any Latin run (chart, ledger, Moses' panel, all five sheets), an asset walk over every `zh-Hans`/`zh-Hant` string, and a check that all 85 references localise. Phase 9 rendered the last unreachable block — the six provenance sentences and two counts, now a "How this chart was made" sheet — and fixed the three untrue claims that surfaced when they were read for the first time (a join key that silently skipped 5 of 28 witness rows; "23 Anno Mundi birth years" for 9 comparisons that are intervals; a begetting age claimed for three men who have none). **This module now has no unrendered getter** — every accessor on `lib/models/chronology.dart` was swept for a call site outside the model and all of them have one; the era's gaps, divergence and summary were checked rather than assumed (a first draft of this row claimed they were the next gap and was wrong). Phase 10 took the same defect one module over, to `radial_chronology_page.dart`, and it was worse there than the survey said. The **111** references it printed in English to Chinese readers now route through `localizedReferenceLabel` at all three sites, storage staying English because `parseReference` reads it back. But sweeping the asset for what nothing rendered found **42 more references that were not printed in any language**: `WheelPower` parsed neither `ref` nor `refs` nor `basis`, on the authority of the model's own doc comment — *"Nothing is read out of scripture, so nothing here carries a verse"* — which was false when written and shaped the class. Reading the unread `basis` corrected a **printed falsehood**: `_showPower` hardcoded 通行年份 · 非经文所载, so the three `scripture+thiele` kingdoms denied scripture for spans the asset derives from it. And **no detail sheet on this page could be opened at all in a debug build** — `WbType.of` watches, a tap handler is not a build — a pre-existing crash the whole suite was blind to because *the page at rest shows no reference*, so the sweep guarding it passed by never opening anything. Guards: the sweep now taps 8×16 in polar coordinates and floors on sheets opened **and** references found; a source-derived detector parses `wheel_history.dart` for the `j['…']` literals each class actually reads and makes every unread key **assert its own excuse** (nations' `approximate`/`basis`/`era` are constant across all 82; `region` tracks `stream`; `ongoing` must equal `end == null`); and all 55+82+42 refs are asserted to parse *and* localise before anything renders them. Phase 11 took that next slice — **the wheel's canvas** — and the blindness was hiding a defect, not just a risk. Every rim label was handed a **constant-width box** (`span*0.36` scripture, `span*0.40` conventional, ~40 px at 700 px) whatever it said, then cut two characters at a time. At 900 px and rest **0 of 55 English labels were drawn whole and 46 of 55 Chinese ones were ellipsised**, breaking **#297**: `莫斯…` is not an abbreviation of 莫斯科. The fix moves the *decision* out of the painter into **`planRadialSpokes`**, which returns the resolved strings, so a test can finally read canvas text; a label is now **legible or absent** (Chinese whole-or-nothing, Latin cut only at a space) and the **tick always draws**, so nothing becomes untappable. English went 0→31 whole +24 word-cut, Chinese 9→**55 of 55**, and **the verse on the label 0 of 4 → 3 of 4** — the promise `_radialLabel`'s comment had made and never kept, and the thing BibleWorks' Timeline (`bwh39`) does. The two-zone "scripture baseline" was re-encoded as **anchoring** (scripture out from the bands, conventional in from the rim, both using the whole annulus, provably non-colliding); it is explained nowhere on screen, and only **5 of 491 events** are scripture-dated with **1** visible at rest. `test/wheel_label_legibility_test.dart` loads the real faces and sweeps 3 locales × 2 sizes × 3 zooms. **`stackRadialLabels` is provably unreachable** and is now pinned as such. Phase 11 predicted the next slice would be the band names; **phase 12 measured them and that prediction was wrong.** The band names are sound (0 ink collisions, worst clearance 0.91 units) and were left untouched; the defect was one ring in, in the **arc labels**, where a `.clamp(6.0, 10.0)` bound at its floor and held every power name at 6.00 canvas units — 48 px at 800% zoom, a drawn set that never grew with zoom, and at 700 px **every** drawn label's ink overrunning the 5.41 ring pitch onto the neighbouring stream. `fitArcLabel` reads the floor in screen units, caps at 0.9 of the pitch, and re-measures rather than back-solving; `selectionCovers` separately fixes a band tap dimming the whole wheel. `test/wheel_arc_label_behaviour_test.dart` (18 tests) loads the real faces and measures **ink** by rendering to a `Picture` and scanning alpha, because the line box is not the ink and the line-box reading is what produced the wrong band-name verdict. **Open for the owner:** the arc-label floor stays at 6 px against #315's chrome floor of 11, since 11 would leave the chart unnamed below ~200% zoom. **Still unphotographed:** the wheel's type has never been seen on a deployed build — `flutter test` substitutes a stand-in face, so glyph appearance remains unverified, though sizes and ink extents are now measured in the shipped faces. |
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
  screenshot costs ~1.5–2k tokens.
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
