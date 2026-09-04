# The handover prompt

Paste this to a new AI that is taking the project over. Kept in the repo
so it survives the chat it was written in.

---

```
You are taking over SeekSparks, a Flutter Bible-study workbench, from
another AI. The repository is at
/Users/pliu0036/Documents/CodingProject/SeekSparks.

Read AGENTS.md first, in full, before touching anything. It is short and
it is the contract: the commands, which document to believe when two
disagree, the rules that are not negotiable, and the three traps that
have cost the most time here. Then read docs/OPEN-ITEMS.md, which is
everything that is not done.

Four things I want you to internalise before your first change:

1. Flutter is not on PATH. It is /Users/pliu0036/flutter/bin/flutter.

2. A green test suite does not mean a legible screen. The two chart
   pages draw on a Canvas, and canvas text has no widget and no
   semantics node — 4254 tests once passed over a lane of solid black
   ink, and an AppBar title that rendered at 0.0 px wide passed a test
   asserting its width was greater than zero. When you change something
   visible, deploy to dev and look at it, or screenshot the device.

3. A build can silently ignore your change. A stale .dart_tool kernel
   has twice produced an artefact containing the old code while the
   build reported success. If a change will not show on a device,
   suspect the build before the code.

4. Measure, do not assert. This codebase's comments carry the numbers
   that justified each decision, and its documents mark whether a claim
   was verified or is carried forward unchecked. Hold yourself to that:
   if you cannot measure something, say you could not, rather than
   writing a number that reads like a fact.

Do not deploy to prod without asking. Do not commit or deploy
assets/nasb-ev.json, assets/nsn-plus.json or assets/tagged/nsn-plus/.
Do not change any URL, route path or package id. Never git add -A or
bare git stash — the checkout is shared. Commit messages carry no
attribution lines of any kind.

To see where things stand right now:
  git log --oneline -20
  /Users/pliu0036/flutter/bin/flutter analyze
  /Users/pliu0036/flutter/bin/flutter test
  curl -s https://sword.yahwehword.com/version.json

Tell me what you have read and what you think the state is, in your own
words, before you propose any work.
```

---

## Why it ends the way it does

The last line is the point of the whole prompt. Asking the new AI to
state the project's condition **in its own words before proposing
anything** is the cheapest way to find out whether it actually read the
documents or merely opened them — and a wrong summary is far cheaper to
correct at that moment than after it has shipped something.
