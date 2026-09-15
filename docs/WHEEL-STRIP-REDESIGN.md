# History chart redesign

## Scope

The wheel and strip remain two views of one corpus, behind the existing
chronology entry and existing `/wheel` and `/strip` routes. The redesign
changes presentation and navigation; it does not edit historical or biblical
records, their dates, or their provenance.

Both views now have an ordinary readable event browser, a visible full-corpus
search entry, layer controls, and numerical time windows. At wide widths the
browser sits beside the chart; on a portrait phone it sits underneath. Short
landscape windows at least 720 px wide put both controls and the event list
in the side panel, leaving the chart the body's full height. Narrower short
windows open the same list in a sheet. Canvas labels that cannot
fit are recoverable in the browser and the existing search/detail sheets.
Date qualifications and the distinction between a scripture reference and a
source for the date remain visible. Switching forms carries the selected
range and layers. Fit/reset synchronizes the chart, range menu and list.

## Design decisions

- Use native Flutter drawing and ordinary widgets. Perspective would shorten
  the available label and touch space; no 3D engine, external images, runtime
  CDN, or new package is needed for this redesign. CanvasKit still comes
  from the site's own origin through `release_web.sh`.
- At rest, the wheel shows its streams and time structure. Event titles are
  read horizontally in the browser; selecting an event or zooming in reveals
  canvas titles. Person, reign and ministry names follow the same rule,
  with names recoverable through the year digest, search and arc details.
  The full legend is behind a named button; it and all three wheel zoom
  buttons have at least 44 px touch targets. Their own 48 px footer keeps
  those targets off the axis: enlarging the former corner overlays covered
  the bottom year labels in the real phone preview.
- The wheel's radii now fit its square. At 360 px, the old rim radius was
  `360 × .60 = 216 px`, beyond the 180 px half-width before any axis text.
  The new rim is capped at 148 px, reserving 32 px for the outer axis.
  Fitting within the screen is only half the check: secondary axis labels
  also yield to the range endpoints whenever their actual text boxes
  cannot keep a 4 px gap. The year ticks and cursor remain available.
- Wheel text grows through 4× zoom, then stays at twice its resting size.
  The old square-root rule made a 10.5 px label about 115 px on screen at
  120×. The new cap is 21 px for that same base size.
- The strip starts with its complete axis fitted to the actual time viewport.
  Fit uses an exact ratio instead of rounding to the old 0.15 px/year floor,
  which required 933.9 px even on a phone. Time zoom retains the fractional
  year at the viewport centre. Type and time still have separate controls.
- Strip lanes are at least 32 px high, with pale bars and restrained group
  headings. Painted width still means duration; short reigns are never
  widened to create a false duration. Controls occupy their own row.
- Defaults are applied before scene planning rather than painting all 22
  streams once and reducing them in a second frame.

## Performance verification

`strip_paint_cost_test.dart` invokes the actual painters. With the same
corpus/style/scale, it compares an unrestricted full-axis paint with a
900 px visible interval, then repeats the visible paint with a warm cache:

| Painter case | Full axis layouts | Visible interval layouts | Warm repeat |
| --- | ---: | ---: | ---: |
| Ruler at the highest time zoom | 6,228 | 11 | 0 |
| Events from the 880-event merged corpus | 412 | 73 | 0 |

These isolate visibility culling and caching. They are deterministic text
layout counts, not a claim about whole-app FPS or measured physical-device
latency. The event clusters are still computed against their full lanes so
panning does not change the membership of a `+N` marker.

The real wheel-page test at 1440 × 900 made 345 cold text layouts and
one initial scene; a repeated paint, cursor move and pan each made zero
additional layouts. These checks live in `wheel_redesign_test.dart` and
`wheel_paint_cost_test.dart`.
The pure geometry functions used by the pages are the same functions tested;
no parallel implementation of the drawing rules is used as an oracle.

## Verification record

Build, suite, and dev visual-verification results are recorded in the release
entry in `HANDOFF.md`. Physical-device performance and native builds are not
inferred from browser screenshots or widget tests.
