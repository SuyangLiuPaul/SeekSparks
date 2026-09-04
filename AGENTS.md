# AGENTS.md — start here

This file is the entry point for anyone, human or AI, picking this
project up. Read it before touching anything. It is deliberately short;
everything it points at is longer.

SeekSparks is a Flutter Bible-study workbench. One international build,
three locales (`zh-Hans`, `zh-Hant`, `en`), shipping to two web sites and
three physical devices.

---

## The five minutes that save you a day

**Flutter is not on PATH.** It lives at `/Users/pliu0036/flutter/bin/flutter`
(3.44.2 stable). Every command below spells it out.

```bash
/Users/pliu0036/flutter/bin/flutter analyze     # must be clean
/Users/pliu0036/flutter/bin/flutter test        # ~70s, 4298 tests as of 1.6.236
tools/release_web.sh                            # bump + build + deploy dev
tools/release_web.sh --no-bump --include-prod   # also prod — ASK FIRST
tools/release_native.sh                         # iPhone + iPad + Mi Pad
```

`tools/release_web.sh` is the ONLY thing that starts a release cycle: it
owns the version bump. `tools/release_native.sh` deliberately does not
bump, so web and native ship the same X.Y.Z instead of drifting a patch
apart.

**Where truth lives, and what each document is for:**

| file | what it is |
|---|---|
| `AGENTS.md` | this file — the contract |
| `PROJECT_STATE.md` | the queue, and what version is where |
| `docs/OPEN-ITEMS.md` | **everything not done** — bugs, unfinished work, decisions waiting on the owner, landmines. Each item says whether it was verified or is carried forward unchecked |
| `HANDOFF.md` | append-only log, newest on top, one entry per ship |
| `README.md` | GitHub-facing: what the app is, how to run it, licensing |
| `docs/DATA-INTEGRITY.md` | every data check ever run, numbered |
| `docs/WHEEL-PROVENANCE.md` | where every date on the history wheel came from |
| `docs/PARITY-BACKLOG.md` | what the parent app has that this one does not |

`HANDOFF.md` is canonical for *what happened*; `README.md` is allowed to
drift and is the least trustworthy of the four. When two documents
disagree, the tree wins, then `HANDOFF.md`.

---

## Rules that are not negotiable

These are not style preferences. Each one is here because breaking it
cost something real.

**Never commit or deploy `assets/nasb-ev.json`, `assets/nsn-plus.json`,
or `assets/tagged/nsn-plus/`.** They are untracked on purpose. Check
with `git ls-files`, `pubspec.yaml` and `build/web` if you touch asset
wiring. The NASB text is frozen: a defect in it gets **reported, not
corrected**.

**Do not change any URL, route path, package id, Netlify site or export
schema id.** Links that exist must keep resolving. `kWheelUrlPath` must
keep its exact value.

**Never `git add -A`.** This checkout is shared with other sessions.
Stage the files you changed, by name. Never bare `git stash` / `git stash
pop` — the stash stack is shared too; make a WIP commit instead.

**Commit messages carry no attribution lines** — no `Co-Authored-By`, no
tool credit, nothing.

**Never invent a date, a number, a commit SHA, or a scripture
reference.** If you cannot measure it, say you could not.

**Before "fixing" scripture text, `git log -S` the asset first.** A
five-witness "correction" once reverted a deliberate edit by the owner.
Cross-check assets can tell you two files differ; they cannot tell you
which one is wrong.

**Secrets never get printed or committed.** They live in
`~/.config/yswords/secrets/` (mirrored to `~/Documents/secure-keys-backup/`):
the Android release keystore, its properties file, API keys. Losing the
keystore is unrecoverable — Android refuses an update signed with a
different key, and this app has no cloud sync to restore from.

---

## The three traps that have cost the most time

### 1. A green test suite is not a legible screen

The wheel and the strip are drawn on a `Canvas`. Canvas text leaves **no
widget and no semantics node**, so a test can verify geometry and routing
and prove nothing about whether a human can read the result.

This has bitten three times in one week:

- the strip shipped with its events lane as a lane of solid black ink
  while 4254 tests passed, because the label gate was transposed from the
  wheel, where a label runs along the *radius* and needs a line-height,
  to the strip, where it runs along the *axis* and needs a *width*;
- 17 pairs of power names printed on top of each other on the wheel;
- the AppBar title rendered at **0.0 px wide** on a phone while a test
  asserting `getSize(title).width > 0` passed — `AppBar` gives the title
  a `Flexible`, so Flutter lays the `Text` out at its natural size and
  then *clips* it. `getSize` reported the full 71 px of a title with no
  pixels on screen.

**So: look at the built page.** Deploy to dev and open it, or screenshot
the device. And write assertions about what is *visible* — "the title is
at least as wide as the text wants, and ends before the next control
begins" — not about what merely exists.

### 2. A build can silently ignore your change

A committed, analyze-clean, tested change can fail to appear in the built
app, because a stale `.dart_tool` kernel gets reused. Gradle reports
success and writes a fresh artefact containing the *old* code.

This has happened twice, most recently within a single invocation: the
iOS framework carried the new version and the APK built minutes later
from the same defines did not.

**If a change will not show on a device, suspect the build before the
code.** `tools/release_native.sh` now checks the built binary for the
version string and runs `flutter clean` + rebuild once if it is missing —
but the general lesson stands for any change, not just versions.

### 3. Documents go stale silently, and a stale document is worse than none

A note in the strip's About sheet said the genealogy rail was not drawn,
written truthfully and made false an hour later by the agent adding the
rail. Left standing, it sends a reader elsewhere to look for 217 people
who are on the screen in front of them.

**When you make a document false, fix it in the same commit.**

---

## How this codebase writes comments

Comments state **why**, with measured numbers, in full sentences, and
often name what was tried and failed. They are the project's memory.

```dart
// A LABEL BELONGS TO ITS OWN TICK, AND MAY NOT REACH THE NEXT.
```

```dart
/// NO SUB-RINGING. [_buildLifespans] resolves ITS overlaps by adding
/// rings, and the first instinct here is the same move. It does not
/// scale: 22 streams already share about 153 canvas units at 900 px,
/// one ring is 6.95, and europe's worst overlap depth is 8 — eight
/// sub-rings of a 6.95-unit ring are 0.87 units each, under a hairline
/// and under any finger.
```

Do not write comments that restate the code. Do write down the number
that made you choose, and the alternative you rejected. Match the density
of the file you are editing.

A recurring pattern worth knowing: when something cannot fit, the code
declares an **order of sacrifice** and drops cheapest-first, rather than
clipping or shrinking silently — see `fitRadialLabel`, `fitArcLabel`,
`fitBarLabel`, and the wheel's hub caption. Anything dropped must be
recoverable somewhere else on the same screen, and the comment must say
where.

---

## Layout

```
lib/
  constants/   strings (3 locales), theme, app_version.dart
  models/      parsed asset shapes
  pages/       screens; the two chart forms are radial_chronology_page
               and strip_chronology_page, sharing wheel_sheets.dart
  providers/   app-wide state
  services/    asset loading and caching
  utils/       PURE geometry and parsing — this is where testable logic
               belongs, and where a painter's arithmetic should be moved
               so a test can drive the same function the app does
  widgets/     shared UI
```

The `utils/` rule matters. When a test needs to check what a painter
draws, extract the decision into a pure function in `utils/` and have
**both** the page and the test call it. Do not let a test re-implement
the algorithm — it will pass over a copy while the shipped code is wrong.

---

## Deploying

Netlify sites: dev `94de1ce4-b58e-4368-84f4-34165e7f6be5`
(`seeksparks-dev.netlify.app`), prod `7ae9dbe7-c297-4240-817e-a8e7f8cf6cfc`
(`sword.yahwehword.com`). The `netlify` CLI is borrowed from
`~/Documents/CodingProject/SmartHome/node_modules/.bin/netlify`.

**Deploy to dev freely. Ask before prod.**

Devices, by hardware udid — not the Identifier column `xcrun devicectl
list devices` prints, which is a CoreDevice UUID no provisioning profile
contains:

| device | id |
|---|---|
| iPhone 16 Pro Max | `00008140-000C5D6910E3C01C` |
| iPad Pro 11-inch | `00008103-000A24441131001E` |
| Mi Pad (Android) | `0907E41001A00540` |

The iOS provisioning profile is free-tier and **expires seven days after
it is issued**. When it lapses the app stops launching and needs
`tools/release_native.sh` again. If an install fails with `0xe8008012`,
the profile does not carry that device — register it once:

```bash
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'id=<hardware-udid>' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

`tools/yswords-ios-reinstall.sh` is a fork leftover whose `PROJECT=`
still points at the parent app. **Running it from here builds and
installs YsWords instead.** Nothing references it.

---

## Working with the owner

The owner writes in Chinese and English, often briefly. Some things that
are settled and should not be relitigated:

- Answer in the language the owner used.
- A number beats an adjective. "17 pairs of labels overlapped at 900 px"
  is worth more than "several labels overlapped".
- Report what is not done as plainly as what is. If a fix is partial,
  say which part.
- The owner will often say "顺手修一下" (fix it in passing) — that is
  real scope, not a throwaway.
- Parallel Sonnet agents are welcome for fan-out work. Partition writes
  by file, restate the hard rules above in every prompt, and verify
  every substantive claim an agent reports rather than accepting it.
