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

Last updated: 2026-08-25 (seventeenth entry)

---

## Where the build is

| | |
|---|---|
| `pubspec` / dev | **1.6.182** — #318 phase 17, the Bible's own story merged onto the wheel, plus the `localizedReferenceLabel` extent fix. Cut at `9c930fd`, and **photographed rather than assumed**: the splash reads `v1.6.182`, the hub reads **22 · 62 · 588**, the 1010–931 BC cluster lists David, the Davidic Covenant, Solomon, the Temple and the division alongside the wheel's own Hiram of Tyre and the Bantu expansion, *David Becomes King* prints "year from Thiele's chronology of the kings" (an arm that was a **dead branch** before this merge, so it was a latent claim and not a shipped defect), and Noah's Flood prints **`Genesis 6-9`** / **`创世纪 6-9`** where before the fix it printed `Genesis 6`. |
| `pubspec` / dev (previous) | **1.6.181** — the three defects the *photograph* of v1.6.180 found (see `HANDOFF.md`). Cut at `bfd1ccf`; `version.json` verified on both the alias and the immutable URL, and the find feature re-driven on that build — "Magna Carta" → **1 result** (not "1 results"), the sheet sized to its one row, the English hint no longer advertising a Chinese keyboard. |
| `pubspec` / dev (older) | **1.6.180** — #318 phase 16, find on the wheel, from `4d39385`. Deployed because the counter stood at **3 of 3**. Its Chinese fix was verified in the deployed bundle by the `\uXXXX` trick **with a control**: grep the **escapes**: `\u4e3b\u5f8c` (主後) ×3 *and* `\u4e3b\u540e` (主后) ×3 — both scripts present, which is the whole claim — plus `\u5275\u4e16\u5f8c` (創世後) ×1 and `\u521b\u4e16\u540e` (创世后) ×1. Every **raw Han** form scored 0, as it must: that is the control, not a finding. Driving that build is what produced v1.6.181. |
| prod (seeksparks.netlify.app) | **1.6.136** — dev is at 1.6.182; prod ships only on the owner's word. *(The "21 versions behind" this row carried for weeks was never derivable from either number and is withdrawn rather than replaced with another guess.)* |
| `main` | **9c930fd** — **the wheel drew 491 events of world history and, on the two bands named for God's people, 18 records that between them held neither the Exodus nor David nor the fall of Jerusalem nor a single verse of the New Testament.** `assets/bible_timeline.json` held all of it and `radial_chronology_page.dart` never loaded the file, while `wheel_history.dart`'s own head comment described a division of labour — "the stretch the wheel covers after `bible_timeline.json` ends" — that **was never implemented**. The comment was the only place the join existed. `bibleNarrativeEvents` maps era→stream **at `WheelHistoryService.load()`**, not by copying records into the asset: `bible_timeline.json` is audited by `tools/audit_dates.py` and a second copy would drift out from under it. **588 events, 754 search hits.** **Phase 14 refused this exact injection, and its refutation is retired by measurement rather than argument** — it was true against the *greedy* declutter, which would have drawn 0 of 23 NT events and evicted 17 existing ones; phase 15's `clusterByAngle` drops nothing, and the merged wheel at rest draws **62 spokes, 19 of them named by a Bible event** (43 in Chinese, whose labels are wider). Six events sharing AD 33 is arithmetic — 0.000927 rad per year against a 0.0553 rad label, one name per ~60 years — not a defect. **Rule B was declined on measurement, not taste**: preferring the scripture-citing cluster member gains 3 biblical representatives and *renames 7 of 55 existing clusters*, so the declutter was left alone. Exactly **one** fact is told by both assets (timeline `temple_destroyed` / wheel `jerusalem_destroyed`, AD 70, both `judah`) and is excluded by name. Two mappings were wrong and were caught by **reading the records, not the era key**: Job's trial is set in Uz (→`world`) and the Septuagint is Greek scripture (→`scripture`, where it becomes that band's earliest record). A third refuter finding — `maccabees` (−167) and `temple_rededicated` (−164) as one fact, offered at "high confidence" — **was rejected after reading both records**: the revolt and the rededication are three years apart and both real. `antediluvian`→`world` is **the conservative option and is stated as such**: that band's English label is "Elsewhere", which reads oddly against "Noah's Flood" (photographed), but renaming a band 54 correct events already sit on is a bigger change than this merge. **THE ITERATION'S REAL ACCURACY FIX WAS SOMEWHERE ELSE.** `localizedReferenceLabel` re-rendered from `parseReference` — a **navigation** parser that keeps a landing place and discards the rest — and so printed **79 of 4,999** shipped references NARROWER than they were written (`bible_timeline.json` 35, `family_tree.json` 25, `bible_evidence.json` 19): `Isaiah 1-66`→`Isaiah 1`, `2 Kings 9:2–10:36`→`2 Kings 9:2`, `Luke 1:5-25, 57-80`→`Luke 1:5-25`, and worst, a bare `Leviticus`→`Leviticus 1`, **a chapter the data never claimed**. Pre-existing on the timeline, evidence and family-tree surfaces; this merge would have put it on the wheel rim too. `_extentKeptVerbatim` localises the book and keeps the reader's own tail, detecting narrowing **on the digits alone** so a genuine correction still goes through the ordinary path (`Jude 11`→`Jude 1:11`). 79 → 3, the 3 being one-chapter-book expansions that are right. **The new tests were run against the pre-fix function via `git stash`**: exactly the 5 narrowing cases went red, Jude and `1 Cor 13` stayed green. `wheel_label_legibility_test` was **guarding the wrong corpus** — it read `assets/wheel_history.json` directly and was blind to 97 of the labels it protects — and now reads through the service. **The photograph paid again and its finding is the natural phase 18:** `_paintCenturies` draws its 500-year labels `center: true` at `rRim + 11/22` knowing nothing of `planRadialSpokes`, so a label near a tick **mashes glyph-for-glyph into it** — photographed as `主前的轮式车辆500`. **Pre-existing, not a phase-17 regression**, and the proof is that the photographed instance is a *wheel-native* event: **25 wheel-native** records sit within 8 years of a 500-tick against **10 injected**. English is blind to it by construction, because the rim drops the reference there for want of room and only the more compact CJK labels run far enough out to reach the tick. **Phase 16, one iteration back:** **657 records on the wheel, and no way to ask for one.** Phase 15 made every record reachable by tap; nothing made one *findable*. BibleWorks' Timeline (`bwh39`) has a command line taking a term **or a date** (`-46` is 46 BC), and the date half is exactly what a naive reading of "add search" drops — half the questions a chronology gets are years, not names. Both wildcards, not one (`bwh18`): `*` for any run and **`?` for exactly one character**, which is how a reader asks for Nebuchadnezzar without knowing whether we spell it `-nezzar` or `-rezzar`. Patterns are cached; the matcher runs 657 records × 4 fields per keystroke. **Designed against false absence, the only failure mode that matters here** — a search that says "not found" about a record the app holds is the app stating something untrue. So all four kinds are searched (491 events, 62 powers, 82 nations, 22 streams), all three locales (an English speaker who knows "Magna Carta" finds 《大宪章》), plus descriptions and verse references; a hidden band **MARKS** its results rather than swallowing them; and a bare `586` is not guessable on a chart running 4000 BC to AD 2026, so **both eras** are searched and every row prints its own year. **One deliberate departure from `bwh39`, recorded at `_panTo`:** a date does not scroll the wheel at rest. That timeline is a strip wider than its window; this is a disc with all of it on screen, so panning would move an already-visible target and cost the reader the surrounding centuries. **Selection** does the finding, because it forces the record through the declutter that draws only 55 of 491 labels. **AND THE FEATURE FELL OVER AN ACCURACY DEFECT IN THREE FILES.** Checking that a printed year parses back meant reading `yearLabel`, which chose **主后** for every `zh` locale. 后 is a queen; 後 is "after". Simplified merged them and Traditional did not, so `startsWith('zh')` — true for both — **can never choose**. 382 events, 27 powers and the hub were showing a Traditional reader a Simplified era word. The same slip was in `timeline_event.dart` (the 约 hedge on 75 of 98 events, all 98 of which carry Traditional titles, so it was one Simplified word inside a Traditional sentence) and in `biblical_person.dart` (that hedge, plus 创世后 for Anno Mundi, **two lines above a branch that gets 岁/歲 right**). **THE SWEEP IS THE POINT, NOT THE THREE WORDS:** a fourth site written next year will look like the first three. All three now share `lib/utils/date_hedge.dart`, and a source sweep guards the shape — **and it had to be built three times, once for each way a source matcher can be wrong.** v1 required the flag and the character on one line, which is not what any of the three defects looked like: all three stored the test in a `final isZh` and used it lines later, so it ran **clean over every defect it was written for**. v2 followed the flag but read the line as one string, so the flag `zh` matched inside the literal `'zh-Hant'` and it **accused the one line in the repo that gets this right**. v3 reads the flag in code spans and the character in string-literal spans, and feeds itself verbatim pre-fix source as a fixture so a fourth rewrite cannot quietly go blind again. **Two shipped tests had ENSHRINED the defect:** `person_dating_test` passed `zh-Hant` and expected 约, and asserted that `zh-Hans` and `zh-Hant` produce the *identical* string. Corrected, with a note on what "both scripts" does not mean. **THEN THE PHOTOGRAPH FOUND THREE MORE THAT 3,624 GREEN TESTS COULD NOT** — every assertion in the suite reads text, and on two of the three the text was already right. (1) *A one-hit search reserved half the screen*: the result `ListView` sits in a `Flexible` under a sheet capped at 70% of the viewport, and a `ListView` takes every pixel it is offered — **526 px inside a 630 px allowance with nothing typed**, so a single row sat at the top of an empty half page and the box read as broken. `shrinkWrap` fixes it and is safe under a bounded `maxHeight`. (2) *"1 results"*. English inflects for number and Chinese does not, so one count string cannot serve both — and **no widget test here could ever have seen it**, because they all render the `zh-Hans` default where singular and plural are the same six characters. (3) *The English hint offered a Chinese keyboard*, naming 主前586 to a reader who cannot type it; the parser still accepts every Chinese form in every locale, only the advertisement changed. The height test was **run against the pre-fix source before being kept** — it fails at 526 against a 315 bound, so it fires on the defect it was written for rather than merely passing beside it. |
| `main` (previous) | **d23f1e9** (refined by `b012db1`) — **the wheel drew 55 of 491 events and printed 491 two inches away.** The chronology wheel's declutter was greedy, year-ordered and first-past-the-post; measured through the app's own parser on a 900 px canvas it draws **55 of 491 at rest and 136 at the `InteractiveViewer`'s ceiling of 14x**, so ~72% of the corpus was unreachable at **any** magnification the app permits — and `_handleTap` iterates the **drawn** spokes, so a dropped event had **no hit target at all**. One spoke stood for the **66 events of 1900-1957** and said only *Boxer Uprising Martyrdoms*. **Zoom is not a remedy on a linear axis**, and that is the part worth keeping: angle is a linear function of the year, so the **125 events sharing a year with another** (55 such years) are at identical angles at every zoom, forever — before defending any declutter, compute what the maximum zoom actually shows **and** whether the collisions are zoom-invariant. **The fix is the same rule read the other way:** `clusterByAngle` opens a cluster on exactly the old keep-test and records the losers instead of discarding them, so the representatives are the **identical events at the identical angles** — nothing on screen moves — and each carries a muted `+n` badge plus a tap listing every member in year order, each row opening its own sheet. Selection now *represents* its cluster rather than being drawn beside it, which **shrinks** the collision exception the layout proof rests on. **The badge's cost is on the record in both columns:** reserved before the title and given up last (verse → title → badge), it costs English **nothing** (48/48 at 700 px, 55/55 at 900 px — Latin already cuts at whole words) and costs Chinese, which #297 makes whole-or-nothing, **55→53 titles at 900 px and 38→22 at 700 px**; against that, spokes saying *nothing at all* fell from **10 to 2**. It takes the **verse's** size for hierarchy, not room: shrinking it buys nothing, because Chinese titles are quantised in whole ideographs, and the variant that recovered 7 titles needed a one-space gap as well — a knife-edge on one corpus at one canvas size, not taken. **The comment defending the old design was false three ways:** "half the corpus at 1x, all of it by 3x, nothing is lost" (really 11%/17%, ceiling 27.7%), "189 labels round 320°" (**the corpus size when the comment was written**; it is 491 — a number in a comment is a measurement with an invisible date), and "tappable-adjacent". **Same defect, second surface, also fixed:** a stream's sheet named every event on the stream and offered no way to open one; those rows are now tappable, and the **powers** above them are deliberately left alone because a power occupies a band and tapping the band already opens it. **Two instrument traps, each of which produced a wrong number first — do not re-derive them.** (1) *A lazy list does not put its children in the widget tree*: counting `InkWell` elements returned **22 for a list of 47** and would have returned the same 22 for a genuinely truncated list, so the assertion could not tell the defect from the fix. (2) *And you cannot travel it by dragging*: `tester.drag` on a modal sheet moves nothing — the modal's drag-to-dismiss recogniser takes the gesture and `position.pixels` stays at **0.0**, indistinguishable from a list that has bottomed out; `jumpTo` asks the question the test is actually asking. **A data finding left alone on purpose:** `nero_persecution` and `great_fire_rome` are **two records for one fire** — same year 64, identical title in all three locales, near-identical descriptions, differing only in `era`/`stream` (world/rome vs church/church) — and the **only** title+year collision in the 491 in either language. Which record should exist is an editorial call and no human was available, the rows are already distinguishable on screen by their stream swatch, so the data was untouched and the test keys rows by **position**. |
| `main` (before that) | **576b3be** — **the app gave a reader two years for one event, and nothing could have noticed.** The division of the kingdom is stated **8 times across 3 assets**: `hebrew_kings.json` ×4, `bible_timeline.json` ×1, `wheel_history.json` ×3. Five said **931 BC**, three said **930 BC**, and all three outliers were the wheel's. Resources → Bible Chronology and Resources → World History Wheel therefore gave the same reader two different years for the same event. **This needed no chronologist.** All three wheel records carry `basis: "scripture+thiele"`, which `wheel_history.json`'s own `_meta.basisValues` defines as "the absolute year follows Thiele's reconstruction", and `radial_chronology_page.dart` prints that to the reader as *"interval from scripture, year from Thiele"*; `hebrew_kings.json` **is** this app's Thiele chart (`"system": "thiele"` at its root) and says 931. The label was false **by the file's own definition**, not by any outside authority — which is why the fix does not wait on #292 (a citable Thiele source, still open). A slip and not an editorial choice: the same three records take Thiele's number every other time (722 Samaria, 586 Jerusalem), `kingdom-of-israel`'s own note discloses *"931 or 930"* while the record says 930, and `git log -S` finds the value entering in the bulk authoring commit only. **Corpus measured before reporting, per the brief:** 31 Thiele-claiming records live outside `hebrew_kings.json` (23 timeline, 8 wheel); all but these 3 agree or lie out of reach, `family_tree.json` agrees on all 14 shared reigns, `chronology.json` is AM-only, and no wheel *event* states the division — so 8 is the complete set and 3 is the whole defect. **The reason nothing caught it is structural: none of the three assets shares an id with another, so there was no key to join on.** `test/cross_asset_year_agreement_test.dart` writes the join out by hand — 6 facts, 23 statements, all 3 assets — and its **first** test fails on any path that stops resolving, so a renamed record breaks it loudly instead of quietly shrinking it to nothing. Run against the unfixed assets it fails on exactly this fact and clears the other five. **A guard already existed and swept the wrong carrier:** `wheel_history_asset_test.dart`'s Thiele check promised these datasets "cannot be allowed to drift apart in silence" while iterating `events` only — the `powers` list holding all three offending records was never read. Extended to both carriers, and recorded honestly in check 49 that **it would not have caught this defect either way** (930 sits inside its ±60 slack); it closes a carrier gap, not this gap. **Reported, not fixed** (conservative, stated): `israel-united-monarchy`'s −1050 start is defensible as −1010 (Thiele's David) − 40 (Acts 13:21), though `bible_timeline.json` calls that same year `conventional`; and `hiram_tyre` at −980 falls inside David's reign while its description is about Solomon's temple. |
| deploy | **DEPLOYED at counter 1 of 3, deliberately, as v1.6.182 (`9c930fd`); the counter resets to 0.** The rule was overridden with the reason stated rather than quietly: the 3-of-3 count exists to **batch changes nobody can see** so one photograph pays for several — phases 14 and 15 were three integers and a pure function — and this iteration alters what **six shipped surfaces print** and puts **97 new spokes on the featured page**. Waiting two more rounds would have meant two more rounds of unphotographed visual change on the one page whose whole content is canvas text. The judgement was vindicated in the same session: the photograph found the century-label collision (`主前的轮式车辆500`), which no assertion in a 3,649-green suite reads, and then **measured it back to a pre-existing cause** rather than letting it be filed as this phase's regression. Prod untouched and unasked-for. **Previously:** the 3-of-3 count fired on schedule (phase 14 = 1, phase 15 = 2, phase 16 = 3), so **v1.6.180** went out at `4d39385`. The second deploy was not scheduled, and it is the lesson of this iteration: **the previous version of this row promised that "the 3-of-3 deploy must screenshot the wheel, or this change ships unverified in the only dimension that matters for it" — and honouring that promise found three defects a 3,624-green suite could not**, one of them structurally invisible to *every* widget test in the repo. So **v1.6.181** followed at `bfd1ccf` and the feature was re-driven on the immutable URL. The counter exists to batch visual changes so one photograph pays for several; it is **not** a licence to defer the photograph. Prod untouched and unasked-for. |
| Suite | **3,649 tests** (+23 this iteration — `test/wheel_bible_narrative_test.dart` pins the merge in four dimensions (every curated event arrives and is accounted for; every injected stream is one the wheel actually draws; the two assets agree on their one shared fact; every `basis` reaches the reader as a true sentence, including a **source-level ratchet** that reads `radial_chronology_page.dart` and demands a `_basisText` arm for every non-conventional basis now on the wheel), and `localized_reference_label_test.dart` gains six cases plus a **corpus-wide sweep** over every `ref`/`refs`/`datingRefs`/`reference`/`scriptureReference` in every shipped asset, so a new asset cannot quietly reintroduce the narrowing class.) Green locally; `flutter analyze` exit 0; both run **last** after the final edit and judged by exit code; **CI green on `4006bde` and `9c930fd`, read from `gh run list`, not inferred from the local macOS run.** **Previously: 3,626** (+52 — the wheel's matcher, its date parser and the search itself; `date_hedge` and its three-times-rebuilt source sweep; corrections in `person_dating_test`; and **2 written *after* the photograph**: the result list's height, and the English singular). Green locally; `flutter analyze` exit 0. Both run **last**, after the final edit, and verified by exit code. **The last two exist because the suite could not see what the screenshot saw, and they close that gap from the other side:** the height test asserts a *size*, not a string, and the singular test reads `wheelStrings` directly rather than rendering — because rendering here always renders `zh-Hans`, where the singular and the plural are the same six characters. |
| CI | **green — `success` on `bfd1ccf` (the tip), read back from `gh run view 32864576662` after the run completed, not inferred from the local suite and not written while it was still in progress.** The three commits below it are `success` too — `2799be7` (32864045830), `4d39385` (32862737518), `91f5326` (32862160476) — so every commit this iteration pushed is green on Linux, not just the tip. Phase 15 added text-metric assertions — the exact class that was Linux-only red — so after CI came back green its margins were sized from a **measured** sensitivity sweep rather than left at the count that happened to pass: scaling every width by (1+e) drops English uncut titles 22 → 21 → 19 at e = 0, 1%, 2%, so that floor is now 15, while the Chinese floor holds to e=5% at its existing margin. **Fill this row from `gh run view --json conclusion,headSha`, never from a local run** — the owner's `17d6a6d` records `main` red for **6 consecutive runs over 2.5 hours across 4 loop iterations**, none of which noticed, because the loop reads its own macOS `flutter test` and that failure was Linux-only. The previous "green" written in this row was **wrong**: the owner's `17d6a6d` records `main` red for **6 consecutive runs over 2.5 hours across 4 loop iterations**, none of which noticed, because the loop reads its own macOS `flutter test` and that failure was Linux-only (`f242200`, `6902631`, `300dcfd` all failed — three of them are named in the rows above as if they shipped clean). **Fill this row from `gh run list --json headSha,conclusion`, never from a local run.** |

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
| #318 | Interactive Bible chronology, featured module | open — phases 1–17 shipped. **Phase 17 put the Bible's own narrative on the wheel** — 97 curated events merged at load, taking it to 588 records / 754 search hits, and retiring phase 14's refusal by measuring the *new* declutter instead of the old one. It also fixed a shipped accuracy defect one module over: `localizedReferenceLabel` printed **79 of 4,999** references narrower than they were written, including a bare `Leviticus` as `Leviticus 1`. Full detail, the rejected refuter finding, the conservative `antediluvian`→`world` call and the phase-18 candidate (century labels colliding with rim labels — **pre-existing**, 25 wheel-native instances against 10 injected) are in the `main` row above. **Phase 16 gave the 657 records a way to be asked for, and fell over a script defect in three files on the way** — `主后`/`主後` chosen by `startsWith('zh')`, which is true for both scripts and so can never choose. Full detail, the deliberate `bwh39` departure, the sweep that had to be built three times, and the three defects the *photograph* of v1.6.180 found are in the `main` row above. **Phase 15 fixed what phase 14 predicted: the declutter, not the data.** Phase 14 refuted injecting 89 NT events by measuring that the wheel would draw 0 of them; phase 15 measured the declutter itself and it was worse than the survey said — **55 of 491 drawn at rest on a 900 px canvas, 136 at the viewer's ceiling of 14x**, and a dropped event had **no hit target at all**, because `_handleTap` iterates the drawn spokes. `clusterByAngle` now groups on the same keep-rule read the other way (identical representatives at identical angles, so the wheel does not move), each survivor carries a `+n` badge, and a tap lists every member. Full detail, both columns of the badge's cost, the two instrument traps and the one asset finding left alone are in the `main` row above and in `HANDOFF.md`. **Phases 1–14 below.**  **Phase 14 is the second time running that a refuted feature uncovered an accuracy defect in what already ships, and the pattern is now worth trusting.** The plan was to inject `bible_timeline.json`'s 89 events into the wheel; the mandated refuter measured that the greedy angular declutter (`radial_chronology_page.dart:685`) would draw **0 of 23 NT events at any zoom** — six share the year 33 and the whole NT spans about one `minGap` — while **evicting 17 existing wheel events**. The feature would have shipped the exact absence it existed to fix. **Do not re-derive it; a year-ordered first-past-the-post declutter cannot show a dense cluster, and the fix is a different declutter, not more data.** What the refutation exposed instead: the wheel dated **the division of the kingdom to 930 BC while the other two assets said 931**, under a `scripture+thiele` label the page prints as *"interval from scripture, year from Thiele"* — false by `wheel_history.json`'s own `_meta.basisValues`, since `hebrew_kings.json` **is** this app's Thiele chart and says 931. Three records moved. The structural finding is that **none of the three chronology assets shares an id with another**, so nothing could join them and nothing could see the drift; `test/cross_asset_year_agreement_test.dart` writes that join by hand (6 facts, 23 statements, all 3 assets) and fails first on any path that stops resolving. **Which of 931 and 930 is right is still #292's question and this does not answer it** — the test asks only that the app not state one fact two ways, which is a defect whichever side is correct. **Phase 13 was an accuracy fix that a refuted feature uncovered:** the ledger cited 1 Kings 6:1 for a total the Septuagint states across **two** of its own units (the 440th year in `6:1`, the founding in `6:1c`, both folded into one record because our keys are the Hebrew's numbering). Both are now read from the `<vs:>` markers and disclosed; the Hebrew states both in one clause and correctly carries no disclosure. **The dead end is on the record so nobody re-derives it:** the axis must NOT be extended past Moses to the temple, because one span there asserts the counted interior (530/520) fits inside the stated total (479/439) — the overrun is the finding.  Bars run to the death of Moses; the exodus→temple era is **counted below the chart, never drawn** (MT 530 vs 479, LXX 520 vs 439). Phase 7 disclosed the one-year choice at the flood (Genesis 7:6's cardinal over 7:11's ordinal). Phase 8 gave each dated event a sheet, so the five epoch `note` paragraphs finally render, and localised every citation the page prints. **Three guards now stand on this asset**, each blind to what the others see: a rendered sweep for any Latin run (chart, ledger, Moses' panel, all five sheets), an asset walk over every `zh-Hans`/`zh-Hant` string, and a check that all 85 references localise. Phase 9 rendered the last unreachable block — the six provenance sentences and two counts, now a "How this chart was made" sheet — and fixed the three untrue claims that surfaced when they were read for the first time (a join key that silently skipped 5 of 28 witness rows; "23 Anno Mundi birth years" for 9 comparisons that are intervals; a begetting age claimed for three men who have none). **This module now has no unrendered getter** — every accessor on `lib/models/chronology.dart` was swept for a call site outside the model and all of them have one; the era's gaps, divergence and summary were checked rather than assumed (a first draft of this row claimed they were the next gap and was wrong). Phase 10 took the same defect one module over, to `radial_chronology_page.dart`, and it was worse there than the survey said. The **111** references it printed in English to Chinese readers now route through `localizedReferenceLabel` at all three sites, storage staying English because `parseReference` reads it back. But sweeping the asset for what nothing rendered found **42 more references that were not printed in any language**: `WheelPower` parsed neither `ref` nor `refs` nor `basis`, on the authority of the model's own doc comment — *"Nothing is read out of scripture, so nothing here carries a verse"* — which was false when written and shaped the class. Reading the unread `basis` corrected a **printed falsehood**: `_showPower` hardcoded 通行年份 · 非经文所载, so the three `scripture+thiele` kingdoms denied scripture for spans the asset derives from it. And **no detail sheet on this page could be opened at all in a debug build** — `WbType.of` watches, a tap handler is not a build — a pre-existing crash the whole suite was blind to because *the page at rest shows no reference*, so the sweep guarding it passed by never opening anything. Guards: the sweep now taps 8×16 in polar coordinates and floors on sheets opened **and** references found; a source-derived detector parses `wheel_history.dart` for the `j['…']` literals each class actually reads and makes every unread key **assert its own excuse** (nations' `approximate`/`basis`/`era` are constant across all 82; `region` tracks `stream`; `ongoing` must equal `end == null`); and all 55+82+42 refs are asserted to parse *and* localise before anything renders them. Phase 11 took that next slice — **the wheel's canvas** — and the blindness was hiding a defect, not just a risk. Every rim label was handed a **constant-width box** (`span*0.36` scripture, `span*0.40` conventional, ~40 px at 700 px) whatever it said, then cut two characters at a time. At 900 px and rest **0 of 55 English labels were drawn whole and 46 of 55 Chinese ones were ellipsised**, breaking **#297**: `莫斯…` is not an abbreviation of 莫斯科. The fix moves the *decision* out of the painter into **`planRadialSpokes`**, which returns the resolved strings, so a test can finally read canvas text; a label is now **legible or absent** (Chinese whole-or-nothing, Latin cut only at a space) and the **tick always draws**, so nothing becomes untappable. English went 0→31 whole +24 word-cut, Chinese 9→**55 of 55**, and **the verse on the label 0 of 4 → 3 of 4** — the promise `_radialLabel`'s comment had made and never kept, and the thing BibleWorks' Timeline (`bwh39`) does. The two-zone "scripture baseline" was re-encoded as **anchoring** (scripture out from the bands, conventional in from the rim, both using the whole annulus, provably non-colliding); it is explained nowhere on screen, and only **5 of 491 events** are scripture-dated with **1** visible at rest. `test/wheel_label_legibility_test.dart` loads the real faces and sweeps 3 locales × 2 sizes × 3 zooms. **`stackRadialLabels` is provably unreachable** and is now pinned as such. Phase 11 predicted the next slice would be the band names; **phase 12 measured them and that prediction was wrong.** The band names are sound (0 ink collisions, worst clearance 0.91 units) and were left untouched; the defect was one ring in, in the **arc labels**, where a `.clamp(6.0, 10.0)` bound at its floor and held every power name at 6.00 canvas units — 48 px at 800% zoom, a drawn set that never grew with zoom, and at 700 px **every** drawn label's ink overrunning the 5.41 ring pitch onto the neighbouring stream. `fitArcLabel` reads the floor in screen units, caps at 0.9 of the pitch, and re-measures rather than back-solving; `selectionCovers` separately fixes a band tap dimming the whole wheel. `test/wheel_arc_label_behaviour_test.dart` (18 tests) loads the real faces and measures **ink** by rendering to a `Picture` and scanning alpha, because the line box is not the ink and the line-box reading is what produced the wrong band-name verdict. **Open for the owner:** the arc-label floor stays at 6 px against #315's chrome floor of 11, since 11 would leave the chart unnamed below ~200% zoom. **PHOTOGRAPHED AT LAST, 2026-08-25 on v1.6.180/181, and the claim that stood in this row for four phases is discharged.** The wheel's type had never been seen on a deployed build; it has now, in the shipped faces rather than `flutter test`'s stand-in. The declutter was confirmed in the only place it is visible: typing *Magna Carta*, tapping the one hit, and watching a **Magna Carta… label appear at AD 1215 where a moment earlier there was none** — selection forcing a record through the declutter, on screen, not in an assertion. |
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
