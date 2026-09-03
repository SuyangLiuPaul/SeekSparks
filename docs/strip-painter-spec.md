# The strip's `CustomPainter` — a spec derived from the wheel

Written against `_WorldWheelPainter` (`lib/pages/radial_chronology_page.dart:4520`),
`lib/utils/radial_chronology_layout.dart`, `lib/constants/workbench_theme.dart`
and the (already-committed, unimplemented) `lib/utils/strip_chronology_layout.dart`.
Every number below is either quoted from those files or derived from a constant
that is. Nothing here is invented palette or invented type.

This document does not touch code. It is the contract another agent implements
the strip's painter(s) against, so it is written to be read once and coded from
— every decision states *which wheel element it descends from*, *why the strip
keeps or drops it*, and *the exact colour/size expression*, not just the shape.

## 1. Why three canvases, not one

The wheel is one square `CustomPaint` inside an `InteractiveViewer` that scales
both axes together. A strip cannot do that: `kLaneHeight` is a **constant**
specifically so lane thickness stops being a function of the viewport (see
`strip_chronology_layout.dart:118-128`), which means the lane column and the
time ruler must stay legible while the *content* scrolls under them — a sticky
header and a sticky ruler, neither of which the wheel needed (its "header" is
the always-visible hub caption; its "ruler" is glued to the same canvas as the
data because a circle has no edge to scroll past).

So the strip is **three painters, one shared coordinate contract**:

| Painter | Fixed axis | Scrolls with | Paints |
|---|---|---|---|
| `_StripLanesPainter` | — | horizontal (time) *and* vertical (lane) scroll offset | grooves, bars, ticks, event marks, the rail, the selection cross-hair |
| `_StripRulerPainter` | vertical position (always at the top) | horizontal scroll offset only | century/decade ticks, era-boundary tick, axis-end labels |
| `_StripLaneHeaderPainter` | horizontal position (always at the left) | vertical scroll offset only | lane-group headings, per-lane names, the "empty lane" note |

All three read `xForYear`/`yearForX` from `strip_chronology_layout.dart` and the
same `pxPerYear`; the ruler and header painters simply receive the scroll
offset as a translation and clip to their own strip of the canvas rather than
painting the whole content extent every frame. This is a composition detail
for the page-owning agent, not a new API — flagged here only so nobody reaches
for one `CustomPainter` the way the wheel has one, finds it can't keep a ruler
still while the canvas pans under it, and improvises something inconsistent
with this spec.

**Content px = screen px, always.** Unlike the wheel — whose `InteractiveViewer`
visually magnifies the canvas, forcing every font size to be divided by
`_labelScale(zoom) = sqrt(zoom)` so 800% didn't mean 48 px type — the strip's
"zoom" (`pxPerYear`) only changes how many content pixels a year occupies
(`xForYear`). There is no view transform stretching the canvas; a reader who
opens a century to 24 px/year is looking at more content pixels, painted 1:1,
not a magnified image of fewer. **No strip font size is ever divided by a zoom
factor.** This is a structural simplification worth stating up front because
it removes an entire category of wheel bug (phases 11/16/18 were all
collisions caused by text at a fixed *canvas* size being magnified by the
viewer) before the strip painter is even written.

## 2. Paint order, main canvas (`_StripLanesPainter`)

Mirrors the wheel's order (`paint()`, line 4561) exactly where a wheel element
survives, in the same back-to-front reasoning: furniture first, then the
per-lane tint (a groove, so an empty lane still reads as *that lane* and not
blank paper), then spans, then the annotation layers that must sit *over* a
span's fill (the wheel's own comment at line 4573 — lifespans paint before
titles "the way a printed chart sets its text over its bars"), then points,
then the selection cross-hair last so it always wins the stack.

1. **Lane grooves** — descends from `_paintGrooves` (line 4647).
2. **Span bars** (reigns, ministries, patriarch/king arcs) — descends from `_paintArcs` (line 4663).
3. **Lifespan bars** (Genesis 5/11) — descends from `_paintLifespans` (line 4768).
4. **Genealogy rail ticks** — descends from `_paintRail` (line 4746).
5. **Event ticks + labels** — descends from `_paintSpokes`/`_radialLabel` (lines 4866, 4908).
6. **Selection cross-hair** — descends from the vertical rules at the end of `_paintLifespans` (line 4823-4833).

Dropped entirely, with reasons:

- **`_paintCenturies`'s radial spokes and `_paintAxisEnds`** — these are the
  wheel's ruler, and the ruler is now its own sticky painter (§4). Nothing in
  the main canvas draws tick lines; the ruler owns the axis.
- **`_paintBandNames`** — the wheel prints a stream's own name once, in the
  12-o'clock gap wedge that is empty by construction (line 4844). A strip has
  no such wedge and the name is needed on every visible frame regardless of
  scroll, which is exactly the sticky lane-header column's job (§5). Dropped
  from the main canvas, not dropped from the strip.
- **`_paintRim`, `_paintHub`** — circle furniture with no rectangle analogue.
  The rim is the wheel saying "this is where the data stops and the caption
  starts"; a strip's lanes ARE the data area, full stop, so there is nothing
  to fence off. The hub is the wheel saying "you are here, here is the whole
  range at a glance" while zoomed into a disc that has no edge; the strip's
  edge is the viewport itself, and "here is the whole range" is the ruler's
  job when zoomed out to `kStripZoomSteps.first` (0.15 px/yr fits all 6226
  years in 934 px — the whole axis is visible at rest without a caption
  saying so).

## 3. Element by element

### 3.1 Lane grooves

Direct descendant of `_paintGrooves`. One faint fill per lane, full lane
height, spanning the whole *content* width (not just where a bar happens to
sit) — same purpose as the wheel's comment: "so an empty stretch still reads
as that band rather than as blank paper."

```
color: (colors[lane.streamId] ?? _lineColor(lane.line)).withValues(alpha: 0.06)
```

Identical alpha to the wheel (0.06). This is not a number to re-derive — the
wheel already tuned it against real streams and this file inherits the
finding, not just the constant.

### 3.2 Span bars — reigns, patriarch/king arcs, ministries

Direct descendant of `_paintArcs`. A rounded-cornerless rectangle from
`xForYear(start)` to `xForYear(end)`, vertically centred in its lane, with:

- fill height = 86% of `kLaneHeight` (the wheel's `band.width * 0.86`, line 4683)
- fill alpha = `0.78 * dim` where `dim = (hasSelection && !lit) ? 0.35 : 1.0`,
  `lit` from `selectionCovers` (§6) — same numbers, same function, unchanged
- **edge hairlines** at both ends: `strokeWidth: 0.7`, `color: wb.paneBg.withValues(alpha: 0.85)` — verbatim from line 4687-4694, "so adjacent spans read as separate"
- **selection outline**: when this span is the selected one, a 1 px stroked
  rectangle around the full (not 86%) lane height, `wb.text.withValues(alpha: 0.85)` — verbatim from line 4696-4705

**Rule 1 is load-bearing here and must not be relaxed.** `strip_chronology_layout.dart`'s
own doc (lines 31-37) states it as inherited: a span narrower than a finger
keeps the ink its years bought; it gets a wider *hit target* (`hitTargetFor`)
and, when the fill collapses to nothing, a marker glyph — never a fatter bar.
For a zero-width reign (Zimri, Huldah, Ahaziah of Judah, Jehoahaz of Judah —
named explicitly in the layout file's own header) the bar must render as a
**dot**, not a stretched rectangle, at `xForYear(start)`, using the same
reasoning and the same clamp the wheel uses for a nameless arc (line
4807-4820): `radius: min(1.6, fillHeight * 0.28)`, alpha `(alpha * 2.6).clamp(0.0, 1.0)`.

### 3.3 Lifespan bars (Genesis 5/11)

Direct descendant of `_paintLifespans`. Same shape as 3.2 but its own alpha
ladder, unchanged from the wheel (line 4776):

```
alpha = selected ? 0.85 : (hasSelection ? 0.22 * 0.35 : 0.22)
```

— "0.22 at rest, so spoke titles stay legible over it" (the wheel's own
comment). Tick hairlines at each end use `strokeWidth: selected ? 1.4 : 0.7`
and `color: l.color.withValues(alpha: (alpha * 2).clamp(0.0, 1.0))` — verbatim
from line 4788-4795.

### 3.4 Genealogy rail

Direct descendant of `_paintRail`. The wheel encodes "how many people" as the
**length** of a tangential mark inside its own angular pitch (`half = r.pitch
* 0.5 * fill`); a strip has no angular pitch, so the transfer is: encode it as
the **height** of a vertical tick inside the lane's own `kLaneHeight`, using
the identical fill formula —

```
fill = (0.34 + 0.66 * ((cohort.people.length - 1) / 7)).clamp(0.34, 1.0)
tickHeight = kLaneHeight * fill
```

— so 1 person is a third of the lane, 8+ fills it, exactly as on the wheel.
`strokeWidth: selected ? 1.8 : 1.0`, `color: lineageRailColor().withValues(alpha: alpha)`,
`alpha = selected ? 0.9 : (hasSelection ? 0.30 * 0.35 : 0.30)` — all verbatim
from line 4746-4765. Dashed, grey, because (the wheel's own doc, line
4744-4745) none of these years rest on a verse.

### 3.5 Event ticks and labels

Direct descendant of `_paintSpokes` + `_radialLabel`. A short vertical tick at
`xForYear(event.year)`, then text running **rightward** from the tick along
the lane's own row — the strip's equivalent of "text running outward along
its spoke," for the identical reason stated at line 4896-4907: angular (here,
lane-height) space is scarce and radial (here, horizontal/time) space is
nearly free, so a crowded decade spreads sideways instead of stacking.

Composition, verbatim from `_radialLabel` (lines 4908-4970), just laid out
horizontally instead of along an arc:

1. tick: `strokeWidth: selected ? 1.5 : 0.8`, `color: event.color.withValues(alpha: 0.8 * dim)`
2. title: `wb.text` (full alpha when selected, else `0.95 * dim`), weight `w600` selected / `w400` otherwise
3. `  {ref}` immediately after the title, in `wb.link.withValues(alpha: 0.95 * dim)`, at `0.86×` the title's size (`_kRefSizeRatio`, line 912) — "the reference IS the evidence"
4. `  {badge}` (a cluster's `+n`) after that, in `wb.mutedText.withValues(alpha: 0.95 * dim)`, same `0.86×` size — muted specifically so `+65` "must not look like a title" (line 4919-4923)

**Clustering.** `clusterByX` (already declared in `strip_chronology_layout.dart:226`)
replaces the wheel's angular declutter — but where the wheel's declutter
**drops** the losing events (kept only a representative, silently, until #308/#319
made that the standing defect this whole rebuild is partly repairing), the
strip's clustering is provisional: a cluster too tight *at this zoom* is not a
verdict, because the reader can zoom the time axis and the cluster comes
apart. The badge is what says so — same visual treatment as the wheel's `+n`,
same reason, but on a strip it is a promise ("zoom in and these separate"),
not an apology for data the reader cannot reach.

**Right-edge flip.** The wheel flips a label to run inward when the outward
run would leave the wheel (line 4952-4962, `s.label.flipped`). The strip's
equivalent trigger is the *viewport's* right edge, not the content's: a title
that would run past the visible window should have its anchor pulled left so
it stays on screen rather than clipping, using the same technique
`barLabelX` already specifies for a bar's own name (`strip_chronology_layout.dart:204-211`).
Do not build a second mechanism for this — event-label placement and
bar-label placement are the same problem (keep text inside the viewport) and
should share `barLabelX`.

### 3.6 Selection cross-hair

Direct descendant of the rules at the end of `_paintLifespans` (line
4823-4833). The wheel draws two hairlines from the band ring to the rim at
the selected life's birth and death angles — "the Chronology page's vertical
contemporaries band, read in polar: every arc it crosses is a life that
overlapped his" (the wheel's own comment, line 4734-4737).

On a strip this is *more* honest than the wheel's version, not just a
transliteration: a **full-height vertical rule** at `xForYear(start)` and
`xForYear(end)` of the selected span, running the complete height of the
lane stack (not just the label annulus, because a strip has no separate
annulus — every lane is exactly what the wheel's annulus and bands both
were, at once). `strokeWidth: 0.9`, `color: wb.text.withValues(alpha: 0.5)` —
verbatim from line 4825-4827. This literally *is* the "vertical contemporaries
band" the wheel's comment describes in polar terms — the strip draws it as
what it always conceptually was, a straight line.

## 4. The sticky ruler (`_StripRulerPainter`)

Direct descendant of `_paintCenturies` + `_paintAxisEnds`, merged, because the
wheel only split them in two (`onRing` vs not) to dodge a collision that a
sticky ruler in its own reserved strip does not have — this is a real
simplification, not a loss: **the wheel spent three separate phases (11, 16,
18 — see `HANDOFF.md`) fixing ruler/label collisions that a fixed, dedicated
ruler row makes structurally impossible**, because nothing else is ever
painted in that row.

- Tick step: `rulerStep(pxPerYear, labelPx: 56)` (already specified in
  `strip_chronology_layout.dart:99-106`) — 56 px is a deliberate carry-over
  guess at label width and should be checked against the actual measured
  width of the longest era label (`kMinYear` printed is `4200 BC` / `主前4200`)
  once real faces are available; if it is short, ticks will crowd, which the
  ruler's own "nice ladder" (1/5/10/25/50/100/250/500/1000) will not silently
  fix — it can only pick a coarser *available* step.
- Tick years: `rulerTicks(step)`. **Year 0 never appears** (the file's own
  doc, line 110-111: "1 BC is followed by AD 1"). Where a step boundary would
  fall on it, print the wheel's own era-boundary label instead of skipping in
  silence — reuse `wheelStrings['wheelEraBoundary']` verbatim (`'BC | AD'` /
  `'主前｜主后'` / `'主前｜主後'`, `radial_chronology_page.dart:544-546`), which
  exists precisely because the wheel shipped a real defect here (phase 18: it
  printed `AD 0`, a year the Dionysian calendar does not have) before this
  fix. **Do not re-derive this from scratch; import the fixed answer.**
- Tick colour: minor `wb.border.withValues(alpha: 0.2)` / major (multiples of
  500) `wb.border.withValues(alpha: 0.5)` — verbatim from `_paintCenturies`
  (line 4586-4591).
- Label colour: `wb.mutedText` for interior ticks (matches `_ringLabel`'s
  caller, line 4607); `wb.text` for the two axis-end labels (matches
  `_paintAxisEnds`, line 5071) — the wheel deliberately makes the range ends
  brighter than the interior scale because "these two say what the chart's
  range IS, they are the labels a reader goes to first" (line 5074-5075).
- Label sizing: see §7 — chrome-scaled, not text-scaled (this is the one
  place the strip keeps the wheel's choice rather than departing from it;
  reasoning in §7.3).

## 5. The sticky lane-header column (`_StripLaneHeaderPainter`)

**New. No wheel analogue beyond `_paintBandNames`**, and even that only
partially — the wheel prints a stream's name once in a wedge that never
scrolls past; on a strip every lane must be nameable at all times because the
reader has scrolled the content sideways and the name has to stay put. This
is the sticky-column requirement `strip_chronology_layout.dart`'s intro
argues for structurally (§1 above).

- One row per lane, height `kLaneHeight` (scaled — see §7.1), left-aligned
  text, coloured the same way `_paintBandNames` colours a stream name:
  `(colors[stream.id] ?? _lineColor(stream.line)).withValues(alpha: 0.98)`,
  weight `w600` (line 4850-4854).
- **Lane-group headings** sit above their member lanes as a distinct row —
  not a lane itself, no bar can be painted in it, `wb.text` at full opacity,
  weight `w600`, one size step above the lane names it groups (so a reader
  scanning down the sticky column sees hierarchy, not a flat list). The five
  groups requested for `strip_strings.dart` (§ companion file) are: events,
  lifespans, kings of Judah and Israel, prophetic ministries, and the stream
  group — this maps onto the wheel's own four legend rows (`wheelLifespans`,
  `wheelKingsThiele` × 2 kingdoms, `wheelMinistries`, `wheelLineage`) plus the
  22 stream bands themselves, which the wheel names individually but a strip
  groups under one collapsible heading (streams are homogeneous — kings and
  lifespans are not, which is why they keep separate headings here just as
  they keep separate legend rows on the wheel).
- **Column width**: not specified by any existing constant. Recommend sizing
  it to the longest lane-group heading in the active locale plus one
  `kLaneHeight`-scaled padding unit, clamped to a sane maximum (e.g. 30% of
  viewport width) so a verbose Chinese heading cannot swallow the content
  area — this mirrors the reasoning `WbType.resolve`'s own doc gives for the
  Browse pane's title at 40 pt/1000 px: "truncating a title is the correct
  answer to 'I asked for 40 pt in a 200 px pane'... shrinking it back would be
  the app overruling the setting again." Same principle: clamp the column,
  ellipsise the heading, never silently shrink the font to make it fit.
- **Empty-lane note.** When a lane group has zero spans/events in the current
  data (a filter matched nothing, or a layer is toggled but genuinely empty
  for this corpus), print a single muted line in place of its rows rather
  than leaving a blank gap that reads as a loading state or a bug — `wb.mutedText`,
  same size as a lane name, using the `stripEmptyLane` string (§ companion
  file). This is the strip's answer to the same honesty rule
  `strip_chronology_layout.dart` states twice (rule 2, "nothing narrows in
  silence"): an empty lane must say it is empty, not merely look it.

## 6. Selection and dimming

**Reuse `selectionCovers` (`radial_chronology_layout.dart:770-777`)
unchanged.** It is already pure and radius-agnostic — `selectedId`, `ownId`,
`streamId`, a boolean — nothing about it is polar. Every dimming decision in
§3 (`dim = hasSelection && !lit ? 0.35 : 1.0` for spans, the `0.28` for
events, the `0.22`/`0.85`/`0.22*0.35` ladder for lifespans, the
`0.30`/`0.30*0.35`/`0.9` ladder for the rail) is copied verbatim from the
wheel's own call sites, because the *meaning* — "a tap selects a power, an
event, or a whole stream when it lands on empty band, and everything not
covered by that selection dims" — does not change when the shape holding it
changes from a ring to a row. Do not write a second selection model; import
this function and keep its call sites' constants.

## 7. Type sizes, and the reader's Font Size setting

### 7.1 Lane content (bar labels, event titles, lane names) — `scaledSmall`, not `scaledChrome`

**This is a deliberate departure from the wheel**, and it is forced by
`strip_chronology_layout.dart`'s own doc comment on `kLaneHeight` (line
126-127): *"it is scaled by the reader's Font Size setting at the call site"*
— i.e. `WbType.scaled`/`scaledSmall` (`textScale`), not `WbType.scaledChrome`
(`chromeScale`, the Menu Size slider). The wheel used `scaledChrome` for
every canvas string, rim to hub caption aside — arc labels, band names, axis
ends all read `t.scaledChrome(...)` (lines 1360-1362) — effectively treating
chart annotations as chrome. That is defensible on a fixed-geometry disc
where the geometry itself never moves with Font Size. It is **not**
defensible on the strip, because the layout file has already committed lane
*height* to track Font Size: if the label inside a lane tracked a different
slider (Menu Size), the two could drift apart independently — a reader who
raises Font Size and leaves Menu Size alone would grow the lane but not the
label, or vice versa. Locking both to `textScale` is what keeps them
proportional at every stop.

Target size at the default (`textScale = 1.0`): **12 px**, per the layout
file's own stated intent ("room for a 12 px label and its leading"). Applied
through `WbType.scaledSmall(12)`, which floors at `WbMetrics.smallPrintFloor`
= 11 px (`workbench_theme.dart:95`, `= WbMetrics.chrome`).

**Arithmetic — can the strip afford the 11 px floor the wheel could not?**

The wheel's `kArcLabelFloorPx` (6, `radial_chronology_layout.dart:763`) is
explicitly *below* `smallPrintFloor` because 22 rings must share a radius
that does not grow: at 900 px canvas, the ring pitch is 900 × 0.285 (rBands)
minus the hub, divided by 22 streams ≈ **6.95 canvas units**, and
`kArcLabelPitchFraction` (0.9) caps a label's em at **6.25 units** before it
would reach the neighbouring ring — under 11 regardless of setting. The
wheel's own comment calls this "a product question with a real cost either
way" and ships the lower floor because raising it would blank the wheel
until ~200% zoom.

The strip does not have this constraint, and the reason is structural, not
incidental: `kLaneHeight` is a **constant** independent of lane *count* —
adding a 23rd lane adds scroll height, it does not shrink the other 22. At
the default setting, `kLaneHeight` = 22 px and a 12 px label at
`WbMetrics.lineHeight` (1.32×) line-boxes at **15.84 px**, comfortably inside
22 px with **6.16 px** left for padding and the tick itself. At the floor
(11 px), the line box is **14.52 px** — still comfortably inside a
*default-scale* 22 px lane.

**Where it gets tight: the low end of the Font Size slider.** Both the lane
height and the target label size scale by the same `textScale`, so they stay
proportional everywhere *above* the point where the floor binds — but the
floor, by definition, stops the label from shrinking further while the lane
keeps shrinking. `textScale` ranges 0.6–2.0 (`kFontSizeMin`/`kFontSizeMax`/`kFontSizeDefault`
= 12/40/20, `app_settings.dart:34-36`). The floor binds once `12 × textScale
< 11`, i.e. `textScale < 0.917` (`fontSize` below ≈18.3 pt) — most of the
slider's usable range. Below that point the LABEL holds at 11 px
(line box 14.52 px) while the LANE keeps shrinking as `22 × textScale`. Lane
height falls under the label's line box when `22 × textScale < 14.52`, i.e.
`textScale < 0.66` — **`fontSize` below ≈13.2 pt**, which is 2 of the
slider's ~29 stops (12 and 13 pt) out of a 12–40 range.

**Verdict: yes, the strip can hold the 11 px floor — the wheel's
kArcLabelFloorPx exists to solve a squeeze this layout does not have — but
`kLaneHeight` needs its own floor tied to the same number**, or those two
stops will clip a label into its neighbour. Recommend the lane-height
function (owned by whichever file computes actual pixel row height from
`kLaneHeight`, likely at the call site per the file's own doc) apply:

```
laneHeightPx = max(kLaneHeight * textScale, WbMetrics.smallPrintFloor * WbMetrics.lineHeight)
             = max(kLaneHeight * textScale, 14.52)
```

This costs nothing at the default and above (22 already clears 14.52), and
at the bottom two stops it holds the lane 0.48–1.3 px taller than the bare
`22 × textScale` would give — invisible as layout, but the difference
between a label that fits and one that doesn't. **This one arithmetic fact —
not a general recommendation — is the load-bearing finding of this section.**

### 7.2 Reference and badge text (the `  {ref}` / `  +n` suffix)

Same `0.86×` ratio the wheel uses (`_kRefSizeRatio`, line 912), applied to
whatever the lane's resolved title size is (§7.1) — **not independently
floored.** The wheel does not floor these either; they are explicitly
secondary annotation (`wb.mutedText`, "must not look like a title," line
4919-4923), the same category `WbMetrics.smallPrintFloor`'s own doc
distinguishes from body text ("a 9 px hint is unpleasant and still says what
it says," `workbench_theme.dart:93`).

### 7.3 The ruler — `scaledChrome`, kept from the wheel

Unlike §7.1, the ruler's own type **should** stay on `chromeScale`, matching
the wheel's `endFont`/century-tick treatment (`t.scaledChrome(11)`, line
5070; the same `t.scaledChrome(_kLabelPx)` feeds `_ringLabel`, line 4607).
The reasoning that broke for lane labels does not apply here: the ruler's
row height is not committed to `textScale` by anything (it is genuinely
navigation chrome — closer kin to the wheel's zoom-percentage readout and
axis-end labels than to an event's own name), so there is no proportionality
to preserve and no reason to depart from the wheel's precedent. Target size:
**11 px** at default, matching `endFont`, no floor logic needed since chrome
already sits at its own floor (`WbMetrics.chrome` = 11, i.e. `scaledChrome`'s
un-floored output already equals the floor at the default setting and only
grows from there — `chromeScale` ranges 0.7–1.5, `kMenuScaleMin`/`Max`,
so it never goes below `11 × 0.7 = 7.7`; if that bothers a reviewer, wrap it
in the same `max(x, WbMetrics.smallPrintFloor)` pattern, but the wheel does
not currently do this for `endFont` either, so this spec does not mandate a
new floor the wheel itself ships without).

### 7.4 No size-search — truncate, don't shrink

The wheel's `fitArcLabel` (line 792-828) *searches* for the largest size
that fits an arc's angular sweep, because sweep varies wildly (a five-year
reign and a 400-year empire share the algorithm) and ring pitch is also
tight. The strip's declared `fitBarLabel` (`strip_chronology_layout.dart:188-194`)
takes a **fixed** `size` and returns fitted-or-empty text — it does not
search. This is correct and should not be "improved" into a searching
variant: lane height is constant, so there is no pitch to negotiate, and per
rule 2 the reader can always widen a bar by zooming the time axis (unlike
the wheel, whose disc has nowhere further to zoom for angular room). Shrink
the font, on a strip, would be solving a problem the reader already has a
better tool for.

Truncation itself is unchanged from the wheel's #297 rule (`strip_chronology_layout.dart:179-183`,
quoting it verbatim from the wheel): **Chinese whole or nothing** — every
ideograph is a morpheme, 莫斯 is not an abbreviation of 莫斯科; Latin may fall
back to whole words with an ellipsis. `fitBarLabel` already encodes this in
its own doc; the painter's only job is to call it with `roomPx` = the bar's
visible width (post-`barLabelX` pinning for a bar that runs off both viewport
edges) and to draw nothing (not even the tick's title slot) when it returns
an empty string — falling back to the tick alone, exactly as the wheel's
`_radialLabel` does when `s.title.isEmpty`.

## 8. Scroll edges — two axes, two indicators

The wheel's own doc (`radial_chronology_layout.dart:318-322`) states the
target directly, quoting BibleWorks' Timeline: *"it scrolls the axis both
ways, stacks events into era rows, and puts an explicit indicator on the
toolbar 'when there are more timeline items visible by scrolling up or
down.'"* The wheel could not do this — "our axis cannot scroll: it IS the
whole of history, by design" — and treated that as the honest fallback
(count + tap-to-list). **The strip is the surface that finally gets to do
what bwh39 does**, on both of the axes bwh39 has:

- **Horizontal (time).** Standard scrollable affordance, not a data-density
  signal: a ~24 px fade (`wb.paneBg` → transparent) plus a chevron at
  whichever edge is not at its content extreme. Both `kStripMinYear` and
  `kStripMaxYear` are hard bounds (`stripContentWidth`), so this indicator
  is purely "you have scrolled away from one end," present whenever
  `scrollX > 0` (show left) or `scrollX < maxScrollX` (show right) — it is
  not conditional on density the way the wheel's declutter badge is. Maps to
  the `stripMoreBefore` / `stripMoreAfter` strings.
- **Vertical, per lane group.** This *is* the density signal, and it is the
  literal analogue of bwh39's toolbar indicator: when `packIntoLanes`
  (`strip_chronology_layout.dart:146-148`) returns more sub-lanes for a
  group than its allotted on-screen height shows — the layout file's own
  worked example is 298 events needing "about 30 rows" in the densest
  window — show a small `▲ more` / `▼ more` affordance at the top/bottom of
  that group's clipped region, active only while the group is actually
  clipping content the reader hasn't scrolled to. Maps to `stripMoreAbove` /
  `stripMoreBelow`.

Both indicators are cheap to get wrong in the same way #280/#308/#319 were
wrong on the wheel: don't let the absence of an indicator be ambiguous with
"there is nothing more." An indicator that never appears when it should is
the same defect as a silent drop, just one layer removed.

## 9. What is genuinely new here, summarised

For an implementer scanning for "what do I have to build that has no wheel
precedent to copy":

1. The sticky ruler and sticky lane-header column as **separate painters**
   with their own scroll-offset handling (§1, §4, §5).
2. The lane-height floor arithmetic in §7.1 — a real number to add, not
   optional polish, or two stops of the Font Size slider clip labels.
3. Both scroll-edge indicator families in §8 — the wheel has no equivalent
   because its axis cannot scroll; this is the feature the whole rebuild
   exists to make possible.
4. The empty-lane note (§5) — the wheel never shows an empty stream, it
   drops it from `_visible()`; the strip needs an explicit "empty" state
   because a lane group can be visually present (its heading is on screen)
   while momentarily or permanently carrying nothing.
