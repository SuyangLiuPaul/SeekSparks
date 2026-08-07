/// What the Workbench centre pane is showing.
///
/// This used to be a single `bool parallelMode`, which was honest while
/// there were exactly two answers. There are three, and BibleWorks keeps
/// all three because they answer different questions:
///
///   * [WbCentreMode.reader] — one edition, the whole chapter, running
///     continuously. BibleWorks calls this Single Version Browse Mode
///     (bwh11). It is what you use to *read*.
///   * [WbCentreMode.browse] — one verse at a time, every selected
///     edition printed under it. BibleWorks' Multiple-Version Mode. It
///     is what you use to compare *wording*.
///   * [WbCentreMode.split] — two editions side by side, each running
///     continuously, each scrolling on its own. BibleWorks ships this as
///     a whole separate window (the Parallel Versions Window, bwh38).
///
/// The third is not a variation on the second. Interleaving assumes the
/// editions agree about where verse boundaries are, and bwh11 admits in
/// as many words that they do not: "there is not always a one-to-one
/// mapping between verses in different versions. One verse in a
/// particular version may correspond to two or more verses in another."
/// Hebrew psalm superscriptions carry a verse number that English
/// editions fold into a heading, so the whole psalm sits one verse out;
/// the LXX numbers Jeremiah differently again. In [WbCentreMode.browse]
/// that divergence is a stack of misaligned rows. In [WbCentreMode.split]
/// it is simply two columns, and the reader's eye does the aligning —
/// which is the only thing that works when the texts genuinely disagree.
library;

/// The three things the centre pane can be.
enum WbCentreMode { reader, browse, split }

/// Storage key for [WbCentreMode]. `v1` because the value it replaces
/// (`workbench.browseMode.v2`) was a bool and cannot hold three states.
const String kWorkbenchCentreModeKey = 'workbench.centreMode.v1';

/// Persisted form. Written by name rather than by index so that adding a
/// fourth mode later cannot silently re-point saved preferences.
String centreModeToStorage(WbCentreMode mode) => mode.name;

/// Read the centre mode back, falling through to the bool this replaced.
///
/// [legacyParallel] is `workbench.browseMode.v2`. A reader who set the
/// centre to the chapter reader before this existed should still find it
/// there afterwards, so the bool is honoured exactly once — the next
/// write lands under [kWorkbenchCentreModeKey] and the bool stops being
/// consulted.
WbCentreMode resolveCentreMode({String? stored, bool? legacyParallel}) {
  for (final mode in WbCentreMode.values) {
    if (mode.name == stored) return mode;
  }
  if (legacyParallel == false) return WbCentreMode.reader;
  return WbCentreMode.browse;
}

/// The divider between the two split columns. Matches the width of the
/// dividers between the Workbench's own panes so the centre does not
/// introduce a second rhythm.
const double kSplitDividerWidth = 16.0;

/// Narrowest centre pane that can hold two reading columns.
///
/// Derived, not chosen: `ResponsiveBreakpoints.minReadingPaneWidth` is
/// 480 — the app's existing answer to "narrowest a reading column can get
/// and still read as prose rather than a stack of fragments" — and split
/// mode needs two of them with a divider between. Inventing a smaller
/// number here would mean asserting that a reading column is narrower
/// inside the Workbench than outside it, which is not true: the split
/// columns are the same [BibleReadingPane] at the same type size.
const double kMinCentreWidthForSplit = 480.0 * 2 + kSplitDividerWidth;

/// Whether two reading columns fit in a centre pane [centreWidth] wide.
///
/// The Workbench's side panes are collapsible, so a "no" here is a
/// statement about the *current arrangement*, not about the display —
/// closing the Analysis pane is usually enough. Callers surface that
/// rather than just grey the control.
bool splitFitsIn(double centreWidth) =>
    centreWidth >= kMinCentreWidthForSplit;

/// The mode the centre pane can actually render, given the room it has.
///
/// A persisted preference is a wish, not an instruction. Browse needs the
/// three-pane width before three editions of a verse stop reading as
/// fragments; split needs two reading columns. Where neither holds, the
/// chapter reader always does, and it is what the pane falls back to —
/// the reader keeps their saved preference for the next screen that can
/// honour it.
WbCentreMode effectiveCentreMode({
  required WbCentreMode preferred,
  required double centreWidth,
  required bool threePane,
}) =>
    switch (preferred) {
      WbCentreMode.reader => WbCentreMode.reader,
      WbCentreMode.browse =>
        threePane ? WbCentreMode.browse : WbCentreMode.reader,
      WbCentreMode.split =>
        splitFitsIn(centreWidth) ? WbCentreMode.split : WbCentreMode.reader,
    };
