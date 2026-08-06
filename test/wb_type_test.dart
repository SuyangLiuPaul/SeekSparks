import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/workbench_theme.dart';

/// The workbench used to hardcode every size, so Settings drove nothing
/// there. These pin the mapping: a setting must MOVE the workbench, and
/// must not move it so far the three-pane layout stops working.
void main() {
  WbType at({double font = 20, double line = 1.5, double menu = 1.0}) =>
      WbType.resolve(fontSize: font, lineSpacing: line, menuScale: menu);

  test('app defaults reproduce the original constants exactly', () {
    final t = at();
    expect(t.text, WbMetrics.text);
    expect(t.chrome, WbMetrics.chrome);
    expect(t.original, WbMetrics.original);
    expect(t.lineHeight, closeTo(WbMetrics.lineHeight, 1e-9));
  });

  test('Font Size moves body and original text', () {
    expect(at(font: 30).text, greaterThan(at(font: 20).text));
    expect(at(font: 12).original, lessThan(at(font: 20).original));
  });

  test('Font Size does NOT move the chrome', () {
    // Menu bars and status bars are not reading text; tying them to
    // Font Size makes the frame lurch when a reader wants bigger verses.
    expect(at(font: 30).chrome, at(font: 20).chrome);
  });

  test('Menu Size moves the chrome and the bar heights', () {
    expect(at(menu: 1.3).chrome, greaterThan(at(menu: 1.0).chrome));
    expect(at(menu: 1.3).menuBarHeight, greaterThan(WbMetrics.menuBarHeight));
    expect(at(menu: 0.9).statusBarHeight, lessThan(WbMetrics.statusBarHeight));
  });

  test('Menu Size does NOT move body text', () {
    expect(at(menu: 1.4).text, at(menu: 1.0).text);
  });

  test('Line Spacing moves leading in the reader\'s direction', () {
    expect(at(line: 1.9).lineHeight, greaterThan(at(line: 1.5).lineHeight));
    expect(at(line: 1.1).lineHeight, lessThan(at(line: 1.5).lineHeight));
  });

  test('the workbench stays denser than the reader', () {
    // A reader on 1.9 line spacing should not get 1.9 here — the
    // workbench keeps its own tighter rhythm, shifted.
    expect(at(line: 1.9).lineHeight, lessThan(1.9));
  });

  test('extreme settings are clamped so the layout survives', () {
    expect(at(font: 60).text, lessThanOrEqualTo(WbMetrics.text * 1.6));
    expect(at(font: 4).text, greaterThanOrEqualTo(WbMetrics.text * 0.75));
    expect(at(menu: 9).chrome, lessThanOrEqualTo(WbMetrics.chrome * 1.4));
    expect(at(line: 9).lineHeight, lessThanOrEqualTo(1.9));
  });

  test('an empty font family resolves to null, not an empty string', () {
    // '' would make Flutter look up a font literally named "".
    expect(WbType.resolve(fontSize: 20, lineSpacing: 1.5, menuScale: 1,
        fontFamily: '').fontFamily, isNull);
    expect(WbType.resolve(fontSize: 20, lineSpacing: 1.5, menuScale: 1,
        fontFamily: 'Noto Serif').fontFamily, 'Noto Serif');
  });
}
