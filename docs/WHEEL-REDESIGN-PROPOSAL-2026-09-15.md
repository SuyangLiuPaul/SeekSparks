# The history wheel: what is wrong, and what I propose

2026-09-15. Written after 「那个wheel 3D效果不行 而且那么多看不清楚 感觉设计很不行」.

Nothing here is implemented. It is a proposal, because the honest version
of it deletes a subsystem that was finished this afternoon, and that is
the owner's call and not mine.

---

## The measurement first

The wheel is not badly drawn. It is **over capacity**, and by a lot.

| | |
|---|---|
| Streams in the data | **22** |
| Powers (the arcs on the rings) | **263** |
| Events | **776** |
| Marks if every stream is on | **1,039** |
| Marks with today's default six | **334** |

`wheel_default_streams.dart` already argues — from WCAG's 24 px target
and from the colour literature — that a phone holds about **four** rings
and a desktop about **twelve**, and that a categorical palette stops
being discriminable past **six to eight hues**. Today's default is
twelve rings on a desktop.

**334 marks is still far too many**, and the busiest single ring — the
church — carries **188** of them on its own.

So the first thing to say plainly: no amount of rendering craft fixes
this. A chart that draws a thousand marks is a texture. The design
problem is *what to leave out*, and every hour spent on how the
remaining marks are shaded is spent on the wrong half.

---

## What the 3D mode costs

I think the raised mode should go, and I want to give the reasons rather
than the verdict.

1. **It foreshortens the data axis.** Angle *is* the year. Tilting the
   wheel compresses the far side of the circle — so the same number of
   years occupies fewer pixels at the back than at the front, and the
   reader cannot compare two spans by looking at them. A chart whose
   one quantitative channel is distorted by the view is not a chart with
   a nice effect on it; it is a less accurate chart.
2. **It occludes.** A raised record hides what is behind it. On a wheel
   whose problem is already density, the fix cannot be a mode that
   removes marks from view without telling anyone which.
3. **It adds a second interaction language.** Rotate, tilt, pan, pinch,
   plus a mode toggle to swap between two of them. That is four verbs to
   learn before reading a date, on a surface where the reader's actual
   question is "when was this".
4. **Depth reads as rank.** The help text already has to say 「Height
   does not mean rank or importance」 — which is the tell. A visual
   channel that has to be disclaimed is a channel doing work you do not
   want it to do.

If it stays, it should be a deliberate *secondary* view, not the mode
the density problem is solved in.

---

## What the references say

Generated as design references (Higgsfield / `gpt_image_2_5`), and read
for structure rather than for looks. Both variants independently landed
on the same five things:

1. **Six rings, generously spaced.** Not twelve, not twenty-two.
2. **Flat, straight on.** Neither render used perspective, and neither
   looked worse for it.
3. **One name per ring**, set once near the top, and it reads.
4. **A legend at the side** carries the rest of the naming.
5. **Century ticks and year labels outside the rim**, not inside the
   data.

And one finding worth more than the rest: **the small labels set along
the arc segments are illegible even in an idealised render.** The model
was free to draw anything, and text-on-a-curve still came out as
scribble. Our painter spends a `TextPainter` *per character* on exactly
that (`_charsOnArc`). It is the most expensive thing the wheel does and
it is the thing that does not work.

---

## The proposal

**A. Cap the rings at six, on every device.**
Not "twelve where there is room". Six is the colour ceiling and it is
the reading ceiling. The filter already exists; what changes is that the
reader swaps rings in and out rather than being shown everything.

**B. Take the text off the arcs.**
One name per ring, set horizontally where the ring passes the top. The
identity of an individual arc is delivered by tap, not by typography.
This deletes the per-character layout entirely.

**C. Move the year scale outside the rim.**
Century ticks with labels around the outside. Nothing but data inside.

**D. Give the hub back.**
Title, or the current selection. Not more data.

**E. Six muted hues, fixed per stream.**
Assigned from the priority list so a stream keeps its colour whether or
not its neighbours are on.

**F. Demote or remove the raised mode**, per the four costs above.

---

## What this is worth

Items B and C are the largest single performance win available: the
per-character `TextPainter` work is the wheel's dominant paint cost
(`wheel_paint_cost_test.dart` was written to measure exactly that), and
B removes it rather than caching it.

Items A, D, E are a day's work with tests. F is a deletion.

## What I need from you

- **F is the real question.** GPT-6 built the raised mode today. Do I
  remove it, demote it, or leave it and do A–E around it?
- **A changes what a reader sees by default** — six rings instead of
  twelve on a desktop. That is a visible reduction and you should agree
  to it before I do it.

---

## Decided, 2026-09-15

**A is settled, and tighter than proposed.** The owner's answer was
「filter in的时候我建议一次别超过3~5个 因为那么多在一起都没有用其实」 and
「一次不要load太多」. So the ceiling is **five, not six**, and the wheel
**opens with four**.

The gap between those two numbers is the whole design, and it is not a
rounding of the stated range:

- The opening four are the **spine** — scripture, Israel, Judah, the
  church. That line is what this application is for, so it is never
  what a reader has to go and switch on.
- The fifth slot is **the comparison they came to make**: what Egypt was
  doing then, where Babylon falls against the kings. No free slot makes
  the chart a poster. Two free slots start the colour-matching problem
  the owner described.

The old rule read 4 / 8 / 12 by window width — more room, more rings.
That belief is now deleted, and its deletion is the point: room was
never the binding constraint. `wheel_band_target_test.dart` measures
twenty-two rings clearing this app's 9 px finger target at 1400 px, and
the chart was unreadable there anyway. What runs out first is muted hues
a reader can tell apart around a circle, and a wider window does not
supply more of those. A desktop now spends its room on **thickness**.

**The ceiling binds what is DRAWN, never what exists.** All 22 streams
and all 1,039 records stay reachable through Find and the event list. A
ring that is off is a quieter chart, not a smaller dataset — and that
distinction is the only reason a cap is defensible at all.

**The sheet refuses; it does not swap.** At five, the unticked stream
rows go quiet and the header says why. A swap has to guess which ring
the reader has finished with, and every guessing rule has a bad case:
evict their oldest pick and Egypt vanishes mid-comparison; evict the
lowest priority and the church vanishes while they read Rome. A ring
disappearing on its own is a worse failure than one extra tap.

**The strip keeps all twelve lanes.** Its lanes stack vertically and each
prints its own name, so a reader there is reading labels, not matching
hues. The sheet takes the ceiling as a parameter for exactly this reason.

### What the cap does NOT fix

Said plainly so it is not mistaken for the whole job. Measured off the
shipped asset: **1,039 marks** with everything on; **280** on the four
spine rings alone; **188 of those on the church ring by itself.** Five
rings is fewer than twelve and still not legible. The cap is the first
fix, not the fix. B (text off the arcs), C (scale outside the rim) and
per-ring density still stand.

**F remains open.** The 3D mode is untouched so far; only its drag
direction was corrected (`5016062`).
