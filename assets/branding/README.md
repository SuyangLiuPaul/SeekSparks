# Brand marks

The app's mark is **`assets/app_icon.png`** — a 1024 px book-and-sword on
a pale blue ground. Everything else is derived from it:

```bash
python3 tools/generate_brand_marks.py    # loading screen, rounded, Dark, macOS, Windows
python3 tools/generate_themed_icons.py   # the alternate-icon sizes
```

Both take `--check`, and `test/brand_marks_test.dart` runs them that way,
so a derived file that stops matching its master fails the suite.

The launcher icons for iOS, Android and web come from `flutter_launcher_icons`,
which reads the same master (`flutter_icons.image_path` in `pubspec.yaml`).

## There is no vector source for the current mark

`retired_seeksparks_icon.svg` and `retired_seeksparks_mark.svg` draw the
**previous** identity — the dark ground with an open book and gold sparks
that the app used when it was called SeekSparks. They are kept for
reference only. Do not regenerate anything from them.

They are named "retired" because they were not: for the whole of the
rename they sat here under their old names, described in the commit that
added them as the source the mark could be rebuilt from, while the mark
they draw had already been replaced. Anyone who trusted that claim would
have put the retired drawing back.

## The five colour variants are authored, not derived

`assets/themed_icons/{Green,Orange,Pink,Purple,Red}.png` are their own
masters. A green icon is a green *drawing*: the ground, the book, the
spine and the line down the blade were all recoloured together, and no
hue rotation of the blue master reproduces it — the closest fit measured
18 levels per channel out. `Dark.png` is the exception and IS derived,
because it is the default drawing on a dark ground rather than a
different palette.
