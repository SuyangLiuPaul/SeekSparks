/// 2026-08-11 (#313): what a reader-side action asks to be SHOWN about
/// the verses it has selected.
///
/// The reader names the **subject**, never the surface. Whether the
/// answer belongs in a docked Analysis tab or in a bottom sheet depends
/// on how much room the host has, and the reader — which is mounted
/// both as a standalone page and as the workbench's centre pane — is
/// the wrong place to know that.
///
/// This exists because the two were fused: `BibleReadingPane` opened a
/// modal sheet for content the workbench already had a pane for, so on
/// a three-pane screen selecting a verse and asking for its originals
/// **covered the verse being studied in order to describe it**. The
/// rule this enum encodes, and the one to apply to every surface in the
/// workbench: a modal is for a DECISION (pick a colour, confirm a
/// delete); content that has a pane goes to the pane.
enum ReaderAnalysisRequest {
  /// The interlinear of the selected verses — `AnalysisTab.wordStudy`.
  originals,

  /// TSK / OpenBible references for the focused verse —
  /// `AnalysisTab.crossRefs`.
  crossRefs,

  /// Sermons from the corpus that treat the focused verse —
  /// `AnalysisTab.sermons` since 2026-08-17. BibleWorks answers the
  /// same question from a docked tab (Resource Summary, bwh10), which
  /// is what settled the destination.
  sermons,

  /// A model's explanation of the selected verses. Deliberately NOT a
  /// tab: a docked pane promises to follow the selection, and following
  /// it here would spend a network call per verse and let generated
  /// prose sit in the same frame, at the same weight, as the corpus.
  /// This one is a request the reader makes on purpose.
  aiExplain,
}
