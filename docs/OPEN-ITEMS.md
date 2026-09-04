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

`PROJECT_STATE.md` remains the queue for work being actively scheduled.
This file is the complete picture, including things nobody has scheduled.

---

## Bugs

### The reading pane renders no verses when the book's language and the version's corpus disagree `[carried forward]`

Reported as an open defect on **prod**. When `currentBook` is held in one
language (e.g. a Chinese book key) and the selected version's corpus is
keyed in another (English), the pane renders empty. It blocks the whole
Analysis column, since that column is fed from the pane's selection.

Not verified in this pass. `lib/widgets/bible_reading_pane.dart` around
lines 350–375 is where `currentBook` is resolved and is the place to
start. If it reproduces, the fix belongs in the lookup, not in the pane.

### The verse picker can open on a stale chapter `[carried forward]`

Fixed in the sibling app YsWords (dev v1.4.9) and **never checked here**.
Two causes were found there: the ordering of `pendingJump`, and a
`PageView` sync flag latched before the move completed. If SeekSparks
shares the picker's structure it very likely shares the bug.

### English lane headings truncate on the strip at phone width `[verified 2026-09-04]`

`Genesis lifespans` wants 221 px, which is 59% of a 375 px screen, so no
column share that leaves a chart worth reading can hold it whole. It
ellipsizes to `Genesis life…` — visibly a truncation, not a cut glyph,
which is the safe failure. Both Chinese locales fit with room to spare.
`test/strip_header_column_test.dart` pins all of this.

**Shortening the English heading would fix it properly.** That is a
wording decision and nobody has taken it.

---

## Unfinished features

### Three of the Eagle's View imports have no user interface `[verified 2026-09-04]`

The data and the services landed; the screens did not.

| import | service | UI |
|---|---|---|
| Thayer's lexicon | `lib/services/` — present | **none** |
| Bible names | `lib/services/` — present | **none** |
| Places | present | a widget exists, not reached from any page |

So the assets ship and the reader cannot get to them.

### The Modern Concordance was never imported `[carried forward]`

`tools/import_eaglesview_modern_concordance.py` exists. The other
Eagle's View importers ran; this one did not.

### 462 of the chart's 784 names are still off the wheel `[verified 2026-09-04, see PROJECT_STATE.md]`

41% placed. Israel 80, Americas 56, Christian Church 42, Arabia 19, Rome
19, Greece 19, China 19, India 15, Egypt 14 outstanding. The annulus is
the constraint, and **the 2026-09-04 overlap fix does not help**: it
stops names already drawn from colliding, it does not add ring capacity.

### `main.dart`'s three O4 items — one done, two unverified `[verified 2026-09-04]`

The cold `#/wheel` that only began loading its 131 KB asset at push time
is fixed. The boot-page latch and `_applyHashToState`'s early return on
popstate both still exist as code; neither was confirmed fixed or broken.

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

### The native identity was never rebranded `[verified 2026-09-04]`

The Dart package is `seeksparks`, but the Android `applicationId` and
the iOS bundle id are both still `com.example.yahwehswords`. That is a
fork leftover. It does **not** collide with YsWords (`com.example.yswords`),
so both install side by side — but the id is not what a reader would
expect, and changing it now would orphan every installed copy, since
Android treats a new applicationId as a different app.

### `LICENSE` credits the wrong person for the sermons `[verified 2026-09-04]`

The third-party notice attributes the sermon corpus to Liang Jia-keng,
who is the translator of a **different** bundled asset (梁家铿译本). The
preacher is Eric H.H. Chang (张熙和牧师) — see
`lib/constants/sermon_credit.dart`. The owner has the preacher's
permission for the corpus; the attribution is simply misdirected.

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
