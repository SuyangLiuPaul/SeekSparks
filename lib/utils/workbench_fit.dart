/// How many workbench columns a viewport can actually carry, and what
/// to tell the reader when the answer is "one".
///
/// SeekSparks is a fork of YsWords, which IS the phone Bible reader.
/// When the workbench collapses to its centre pane it becomes a worse
/// copy of its own parent — a single column of verses under a menu bar.
/// Silently degrading into the thing you are not is worse than saying
/// "not here", so below the phone threshold the app says so once and
/// then gets out of the way.
///
/// The pane numbers are read off `workbench_page.dart` and
/// `ResponsiveBreakpoints`; they are duplicated here as named
/// constants so the advisory copy can quote a figure that is actually
/// the layout's, not a round number someone liked.
///
/// Flutter-free on purpose — every branch below is a unit test.
library;

enum WorkbenchAdvice {
  /// The viewport carries the workbench, or the reader has already
  /// said they do not want to be told again.
  none,

  /// Portrait, and the long edge is wide enough that turning the
  /// device sideways genuinely buys a second column. Only offered
  /// when it is true: on a 360x640 phone the landscape width is 640,
  /// which clears the app's 600px side-pane gate but leaves the
  /// reading column at 384 — under [readingPaneMin] — so rotating
  /// there is a promise the layout cannot keep.
  rotate,

  /// No orientation of this display reaches two usable columns.
  largerDisplay,
}

class WorkbenchFit {
  /// Minimum widths of the three columns, from `workbench_page.dart`.
  ///
  /// 2026-08-07: search 240->224 and analysis 320->288, trimming 48 px so
  /// the three-column minimum lands on 1024 — the width of a landscape
  /// 1024x768 iPad, which the three-column gate had otherwise excluded by
  /// 48 px. Reading stays at 480 deliberately: it carries the verse text
  /// and is the column a narrower setting would actually hurt. Search
  /// holds a query field and a hit list, analysis holds lemma, parsing
  /// and glosses; both take the cut better than running text does.
  ///
  /// 2026-08-08: analysis 288->256, so the threshold is 992 rather than
  /// 1024. Landing the gate *exactly* on the classic iPad's 1024 pt meant
  /// it qualified only because the comparison is inclusive — Split View, a
  /// zoomed display setting or a browser scrollbar shaves a point and the
  /// device is blocked. 32 pt of slack, taken from analysis again for the
  /// same reason as before.
  ///
  /// 992 is also deliberately ABOVE 980, the layout viewport Chrome for
  /// Android uses in "Request desktop site" mode. Any threshold at or
  /// below 980 would let a 6" phone through the gate by toggling one
  /// menu item, and it would render three columns at an unreadable scale.
  ///
  /// Do NOT go below 256 without a device to judge on. Owner's call
  /// 2026-08-08 on foldables: an unfolded Pixel 10 Pro Fold reports
  /// 852 x 720, and reaching that would mean cutting a further 140 px out
  /// of three columns that are already at their minimums. Foldables are
  /// blocked on purpose, not by oversight.
  static const double searchPaneMin = 224;
  static const double readingPaneMin = 480;
  static const double analysisPaneMin = 256;

  /// Each draggable divider between panes.
  static const double dividerWidth = 16;

  static const double twoPaneMinWidth =
      searchPaneMin + dividerWidth + readingPaneMin; // 720

  static const double threePaneMinWidth =
      twoPaneMinWidth + dividerWidth + analysisPaneMin; // 992

  /// Three panes at their *default* widths (320 search, 420 analysis)
  /// rather than their minimums — the width at which the workbench
  /// stops being squeezed.
  static const double comfortableWidth = 1252;

  /// Menu bar (22) + toolbar (26) + status bar (20). Height the panes
  /// never get, at any width.
  static const double chromeHeight = 68;

  static int paneCountFor(double width) {
    if (width >= threePaneMinWidth) return 3;
    if (width >= twoPaneMinWidth) return 2;
    return 1;
  }

  /// The whole decision, as one pure function of the viewport and one
  /// persisted bit.
  ///
  /// [dismissed] wins over everything: a reminder that will not take
  /// no for an answer is a nag.
  static WorkbenchAdvice adviceFor({
    required double width,
    required double height,
    required bool dismissed,
  }) {
    if (dismissed) return WorkbenchAdvice.none;

    // 2026-08-07: gate on the CURRENT width, not the shortest side.
    //
    // This used to bail out when `min(width, height) >= 480`, on the
    // reasoning that "a phone is a phone in either orientation". That
    // reasoning is sound about hardware and wrong about layout, and the
    // two contradicted each other on screen: a phone's short edge does
    // not change when it rotates, so the advisory offered rotation as
    // the fix in portrait and then, once rotated, told the reader "this
    // screen does not reach two columns in EITHER direction" — while
    // printing "two need about 736. This screen is 844 x 390". 844 > 736.
    // It argued against itself using its own numbers.
    //
    // 2026-08-07, second pass — the bar is all THREE columns, not two.
    // Owner's call: 「手机不能打开三个栅栏，而我们的App是有三个Column…
    // 不能打开三个的，全部都把它显示让他用我的另外一个软件」. Two columns
    // is not a lighter version of the workbench, it is a different and
    // worse product — search beside the text with no word analysis is
    // just a reader with a search box, which is what YsWords already is
    // and does better. Anything that cannot carry all three is sent
    // there rather than shown a half-tool.
    if (paneCountFor(width) >= 3) return WorkbenchAdvice.none;

    // One column at this width. Offer rotation only when rotating would
    // genuinely cross the two-pane threshold — on a 360x640 phone the
    // landscape width is 640, still short of 736, so rotating there is a
    // promise the layout cannot keep. Square counts as landscape: there
    // is nothing for a rotation to change.
    final portrait = height > width;
    if (portrait && paneCountFor(height) >= 3) return WorkbenchAdvice.rotate;

    return WorkbenchAdvice.largerDisplay;
  }
}
