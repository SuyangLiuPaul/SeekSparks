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
- All enabled countries and layers remain in the same scene. Country rings
  retain their original order and radii; concurrent records rise within
  their own ring. Lifespans, kings, ministries, genealogy and events occupy
  the outer annulus. The calendar keeps its full-axis angle mapping when
  selecting a period. The previous single-country focus and automatic
  country date fit were removed after the owner clarified the requirement.
- Flat / 3D is a shared, named two-choice control above both chart forms.
  Switching depth preserves the range, filters, selection and viewing
  position. Wheel/strip navigation also carries the current depth mode.
  Initial country choices use the existing viewport-sized defaults in
  both wheel modes; switching modes never changes the chosen filters.
- Concurrent records can be separated or brought closer, rotated, panned
  and zoomed. Full names are admitted onto visible top faces when they fit;
  otherwise, bounded side callouts use an ellipsis and a leader to a visible
  part of the record. Names never print over one another. Full names and
  exact records remain accessible through the same-screen All names button,
  search and the year digest, which is now shared by flat and 3D. Single-finger
  rotation changes yaw and tilt; a named pan mode changes position, and
  two-finger zoom works in both modes. A tilt slider, rotation buttons,
  layer-spacing choices (compact, standard and expanded) and reset offer
  explicit alternatives to gestures. Standard is the default; expanded
  makes simultaneous tiers easier to inspect without changing their dates.
  Existing detail sheets retain
  provenance, approximate flags, scripture links and alternate traditions.
- The Higgsfield category atlas from v1.6.284 remains in the assets. The
  whole-ring view currently uses coloured geometry and labels for records;
  it does not put a single civilization's illustration in the hub. See
  `assets/chronology/README.md` for the retained illustration's provenance.
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
- The strip also draws every enabled lane as oblique prisms in 3D mode.
  The front face keeps the exact time extent; the raised top and side are
  hit-tested against the same geometry the painter uses. Event cards gain
  corresponding raised edges. Switching depth retains the same time scale
  and the top visible row with its fractional scroll position.
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

The v1.6.283 flat wheel-page test at 1440 × 900 made 345 cold text layouts and
one initial scene; a repeated paint, cursor move and pan each made zero
additional layouts. These checks live in `wheel_redesign_test.dart` and
`wheel_paint_cost_test.dart`.
The former v1.6.284 single-country view printed 11 China names by remapping
that country's date extent across the circle. The whole-ring view retains
the original global time axis, so that name count is not a comparable
target. Surface labels are admitted only when the actual face is visible;
bounded side labels, All names, the digest and search recover the rest.
The current measurements, using the actual painters, are:

| Case | First frame / full axis | Warm visible frame | Rotation |
| --- | ---: | ---: | ---: |
| China, Europe and Rome, AD 100–1500, 52 records, 1000 × 700, Traditional Chinese | 37 text layouts | 0 | 0 additional layouts |
| China in the same global axis and date window, 11 records | 16 text layouts | 0 | 0 additional layouts |
| 3D strip, 540 actual record/card prisms, Simplified Chinese | 694 full-axis layouts; 6 in the 542 × 427 viewport | 0 | not applicable |

These are work counts rather than device frame rates. The flat page's
current default-capacity case makes 191 cold layouts and zero on warm paint,
cursor movement or pan; its smaller chart after adding the shared mode row
selects fewer default rings, so 345→191 is not a like-for-like speed claim.

The pure geometry functions used by the pages are the same functions tested;
no parallel implementation of the drawing rules is used as an oracle.

## Verification record

Build, suite, and dev visual-verification results are recorded in the release
entry in `HANDOFF.md`. Physical-device performance and native builds are not
inferred from browser screenshots or widget tests.
