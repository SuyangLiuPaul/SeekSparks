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

Last updated: 2026-08-23 (fifth entry)

---

## Where the build is

| | |
|---|---|
| `pubspec` / dev | **1.6.153** — check 45g, deployed 2026-08-23 from a detached worktree at c49eb05 |
| prod (seeksparks.netlify.app) | **1.6.136** — 16 versions behind, by design: prod ships only on the owner's word |
| `main` | check 45g — the third witness failed; 22 Chinese verses repaired, 21 reading-text defects named |
| Suite | **3,177 tests**, green; `flutter analyze` exit 0 |
| CI | green (Flutter CI on `main`) |

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
| #289 | Bundle an OFL Hebrew face — Hebrew word study still pulls from `fonts.gstatic.com` | open |
| #292 | Kings of Judah + Israel, synchronised, as a Resource | **blocked** — needs a citable Thiele source |
| #293 | Sermon audio — permission settled, survey done, hosting undecided | **blocked** — needs a hosting decision |
| #295 | Live search audit — drive every syntax through the real box | open |
| #296 | Prod crash — root cause found and fixed (`9132a14`) | **blocked** — needs a fresh crash report to confirm |
| #299 | The `?` card teaches syntax you cannot run | closed — v1.6.144 |
| #300 | Map provenance — rights settled, the maps are the owner's own collection | open |
| #301 | Yahwehdehua — re-open the import; the base text matched, the readings did not | open — the lexicon half is **fixed** (v1.6.152, check 44); the readings are not |
| #302 | Build the backlog before the queue empties → `docs/PARITY-BACKLOG.md` | closed — 75 entries |
| #304 | Systematic data-integrity audit — "accuracy is the most critical thing" | open, recurring — check 45 landed 2026-08-23 |
| #307 | Phrasing — open it to translations, indent line one (Pastor Raymond HK) | open |
| #308 | Search stats: "John 27" never says its unit | open |
| #309 | Matthew series — reconcile our corpus against CDC's 124 messages | **blocked** — CDC site unreachable |
| #312 | Phrasing is not usable yet — redesign, don't patch | open |
| #313 | The Reader is a phone app bolted into a workbench | open — **its headline evidence is stale**: the ticket says the reader has no wire to the Analysis pane, but `bible_reading_pane.dart:144/149` carries `onAnalysisRequest` + `activeAnalysisRequest`. Re-scope before working it |
| #314 | Build version printed twice on one screen | open |
| #315 | 269 hardcoded font sizes — #311 fixed the arithmetic, not the reach | open |
| #316 | The rotate advisory argues against itself | open |
| #317 | Journey routes on the atlas | open — Pauline itineraries drawn (v1.6.134) |
| #318 | Interactive Bible chronology, featured module | open — phases 1–5 shipped, runs to the death of Moses |
| #319 | Atlas filter filters the list but not the map | open |
| #320 | Place records should show the illustrations we already have | open |
| #321 | Greek search cannot match accented input (Aunty Rosa, Hong Kong) | closed — v1.6.126; `foldDiacritics` wired into `text_patterns.dart:171`, `command_query.dart`, `search_highlight.dart` |
| #322 | The Browse column does not line up — three render paths | open — v1.6.139 |
| #323 | 雅偉繁體: ~700 verses with the wrong Traditional form (owner-reported) | **closed** — re-verified from the asset 2026-08-23: 賽2:16 船隻, 出14:22 走乾地, and the trap verse 賽29:17 still 只有; 0 occurrences of 船只/其余/走幹地/凈 |

**Blocked on the owner, five:** #292 (a citable Thiele source) · #293 (audio
hosting) · #296 (a fresh crash report) · #309 (the CDC site is unreachable) ·
#278 (NASB licence — the modules forbid redistribution; the assets must never
be committed or deployed).

**These statuses are NOT audited, 2026-08-23.** #321 was marked open while
shipped, and `PARITY-BACKLOG.md` §8 was calling two finished items
outstanding the same day. Rows carrying a parenthetical version (#317, #318,
#322, #323) mean work landed against a ticket nobody closed; #289, #308,
#314–#316, #319 and #320 are old enough to be suspect. **Grep before picking
one — and grep for the reader's verb, not the technical term**: §8's miss
happened because the code is named `selectCommonWith`, not `intersect`.
Closing the finished rows is worth an iteration of its own.

**Two rows were audited on 2026-08-23**: #323 is now closed on fresh
evidence read out of the asset, and #313's headline evidence is disproved
in its own row. #308, #314, #316, #319 and #320 were spot-checked and
look shipped, but are **left open deliberately** — a spot check is not a
closing pass, and closing a row on a half-remembered grep is the exact
failure this paragraph exists to warn about.

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

**Take the SECOND unnumbered item instead: the 21 word-level defects in
`cuvs-yhwh`'s reading text**, listed verse by verse in check 45g. Isaiah
23:1 has lost the 推 of 推罗 and no longer names Tyre; Judges 12:7 has
lost the 六 of 六年; Lamentations 3:1 carries a 神 the 和合本 lacks. **Can
be taken unattended**, and by the accuracy rule it outranks every feature
below. Regenerate the list with `python3 tools/adjudicate_cuvs_yhwh.py`,
which prints all 21 with the Strong's number each turns on.

*(45d's other two sub-jobs are done: check 45g repaired the 15 verses
printing a literal `#` and the 7 doubling a character against itself, and
`audit_tagged_layer.py` fell 372 → 350 to confirm it.)*

**Read each of the 21 against the 和合本 individually. Do not resolve them
by majority.** 45g measured why: `cuvs-plus` matches the reading text on
**99.70% of characters**, so it is a descendant and not a witness, and a
2-of-3 vote proposed deleting the 六 from Judges 12:7. Of the ten verses
where the tagged layer holds what both flat editions lack, nine go
against the reading text and **one — Job 31:36 — goes the other way**; a
rule applied to all ten damages it.

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
| Off-peak gate | Sat 05:00 → Mon 22:00 continuous; Tue–Fri 05:00–22:00; held overnight |
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
