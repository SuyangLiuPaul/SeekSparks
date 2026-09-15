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
range and layers. Flat-view fit/reset synchronizes the chart, range menu and
list; the stacked view’s Reset view restores its camera within the chosen period.

## Design decisions

- The default wheel now projects native Flutter paths into a 2.5D view.
  Concurrent intervals occupy stable height tiers; China needs two and
  Europe eight in the actual power corpus. The same paths determine paint,
  occlusion and hit-testing. A zero-year record remains a point, not an
  invented duration. No 3D runtime, package or CDN was added; CanvasKit
  continues to come from the site's own origin through `release_web.sh`.
- One civilization or layer is focused at a time, with an explicit all-layer
  overview. The initial six streams are Israel, Judah, Egypt, China, Church
  and Scripture. Chinese opens on China and English on Egypt. Under "All
  years", a focused layer fits its actual record extent, printed above the
  chart; a selected numerical period keeps that window. The existing flat
  wheel remains available through Flat / 3D and keeps its viewport defaults.
- Concurrent records can be separated or brought closer, rotated, panned
  and zoomed. Full names are admitted onto visible top faces when they fit;
  otherwise, bounded side callouts use an ellipsis and a leader to a visible
  part of the record. Names never print over one another. Full names and
  exact records remain accessible through the same-screen All names button
  and, on taller screens, a scrollable record rail. Short landscape screens
  use the button to leave room for the chart. Existing detail sheets retain
  provenance, approximate flags, scripture links and alternate traditions.
- The six symbolic category icons were generated with Higgsfield and are
  bundled as one 1,003,858-byte PNG atlas. They are category illustrations,
  not portraits or archaeological reconstructions. See
  `assets/chronology/README.md`. Canvas geometry, not the image, carries dates.
- Filtering is transactional in both forms: checkboxes and All/None edit a
  draft; Apply returns one set to the page. Cancel, outside click and Back
  discard that draft. The action row remains visible while options scroll.
- In the flat wheel, event titles are
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
- The strip's event region now groups the complete visible event corpus by
  calendar bins, rather than emitting `+N` independently on every packed
  row. A card shows the true event span, count and density; its connector
  lands at the actual dates, while the card itself does not encode duration.
  Click a multi-year group to fit that period. Same-year groups, and groups
  at the zoom ceiling, open the full event list. Single events wrap their
  complete title and keep their date qualification and source.
- Defaults are applied before scene planning rather than painting all 22
  streams once and reducing them in a second frame.

## Performance verification

`strip_paint_cost_test.dart` invokes the actual painters. With the same
corpus/style/scale, it compares an unrestricted full-axis paint with a
900 px visible interval, then repeats the visible paint with a warm cache:

| Painter case | Full axis layouts | Visible interval layouts | Warm repeat |
| --- | ---: | ---: | ---: |
| Ruler at the highest time zoom | 6,228 | 11 | 0 |
| Event cards from the 880-event merged corpus | 47 | 7 | 0 |

These isolate visibility culling and caching. They are deterministic text
layout counts, not a claim about whole-app FPS or measured physical-device
latency. Calendar-bin membership is computed independently of the pan.
At a 900 px full-axis viewport, the previous 44 event rows and 254 `+N`
badges became two rows containing five dated cards and zero `+N` badges.
At 216 px, 139 rows and 239 badges became three rows with three cards.

The flat wheel-page test at 1440 × 900 made 345 cold text layouts and
one initial scene; a repeated paint, cursor move and pan each made zero
additional layouts. These checks live in `wheel_redesign_test.dart` and
`wheel_paint_cost_test.dart`.
The stacked China page at AD 100–1500 made 16 cold text layouts, zero on
a repeated frame, zero on rotation, and 16 when the text size changed at
higher zoom. The actual painter retained 11 record names, including both
Song and Liao, plus two axis labels. Liao's visible 907–960 segment is
before its old quarter-span anchor (961.5), which was behind Song; the
callout planner now samples multiple angles and radii and still accepts
only an actually visible top-surface point. The record dates were not changed.

The pure geometry functions used by the pages are the same functions tested;
no parallel implementation of the drawing rules is used as an oracle.

## Verification record

Build, suite, and dev visual-verification results are recorded in the release
entry in `HANDOFF.md`. Physical-device performance and native builds are not
inferred from browser screenshots or widget tests.
