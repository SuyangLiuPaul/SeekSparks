/// The symbol that stands for each stream on the chronology charts.
///
/// 2026-09-15. 「需要的话可以在这些上面生成象征性的东西标志 人物 建筑 放在
/// 这个3D上面」.
///
/// WHY A SYMBOL AND NOT A WORD, on this chart in particular.
///
/// A silhouette is orientation-independent and a word is not. The wheel
/// is a circle and its depth view turns; text laid on either has to
/// pick a bearing, and the owner photographed both failures on the same
/// day — names running in four directions on the flat chart, and a 3D
/// view of coloured blocks with nothing on them at all
/// 「上面也没有写字看不出是什么啊」. A pyramid read from any angle is still
/// a pyramid. That is the whole argument for putting marks here rather
/// than restoring the labels.
///
/// The precedent is the obvious one and it is worth naming: Sebastian
/// Adams' *Synchronological Chart of Universal History* (1871, revised
/// 1881) ran from 4004 BC to 1883 with architectural monuments, tools
/// and rulers' portraits set along the timeline, and it became the
/// standard chart in church schools for a generation. This is that
/// idea, with the illustration reduced to what survives at 16 px.
///
/// THE RULE THAT KEEPS IT FROM BECOMING THE OLD PROBLEM: one symbol per
/// STREAM, never one per event. The corpus holds 1,039 marks; 188 of
/// them are on the church ring alone. A chart with 1,039 pictures on it
/// is the crowding complaint again in a different medium. At most five
/// streams are drawn, so at most five symbols are on screen.
///
/// Streams with no obvious symbol are absent on purpose. Anatolia,
/// Philistia and Arabia get nothing rather than something arbitrary: a
/// mark a reader has to be taught is worse than no mark, because they
/// will read it as meaning something.
library;

/// Stream id → the asset basename in `assets/chart_icons/`.
const Map<String, String> kStreamSymbols = <String, String>{
  'scripture': 'scroll',
  'israel': 'menorah',
  'judah': 'crown',
  'church': 'spire',
  'egypt': 'pyramid',
  'assyria': 'winged_bull',
  'babylon': 'ziggurat',
  'persia': 'lion',
  'greece': 'column',
  'rome': 'arch',
  'byzantium': 'basilica',
  'islam': 'crescent',
  'phoenicia': 'ship',
  'europe': 'wreath',
  'americas': 'stepped_pyramid',
  'china': 'pagoda',
  'japan': 'torii',
  'india': 'stupa',
  'world': 'globe',
};

/// Every asset this table can ask for, for the loader and for the test
/// that checks the folder and the table have not drifted apart.
List<String> get kChartSymbolAssets =>
    (kStreamSymbols.values.toSet().toList()..sort());

/// The symbol for [streamId], or null when that stream has none.
String? symbolForStream(String streamId) => kStreamSymbols[streamId];
