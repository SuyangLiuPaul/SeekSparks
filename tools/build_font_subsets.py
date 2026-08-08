#!/usr/bin/env python3
"""Build the bundled font subsets in assets/fonts/.

WHY THIS EXISTS
---------------
Flutter web's CanvasKit only draws glyphs that are in its Skia font
registry. When a code point is covered by no registered font the ENGINE
(not this app's Dart) fetches a Noto face from `fontFallbackBaseUrl`,
which defaults to https://fonts.gstatic.com/s/. That host is not
reachable from mainland China, and CanvasKit renders a missing font as
*absent text* — not tofu — so the failure is silent and total.

Measured on dev v1.6.62: opening a Hebrew word study pulled
notosanshebrew, notosans, notosanssymbols and notosanssymbols2 from
fonts.gstatic.com. Bundled Roboto has 922 code points (Latin, Cyrillic
and *monotonic* Greek only) and NotoSansSC-Sub covers CJK, so the gaps
were: the whole Hebrew block, the whole of Greek Extended (U+1F00-1FFF,
i.e. every accented word in the Greek NT and the LXX), the Semitic
transliteration diacritics, and a handful of UI symbols.

BibleWorks authored and shipped its own BWHEBB / BWHEBL / BWGRKL fonts
rather than trusting the host machine. Same principle: a tool whose
subject is Hebrew and Greek bundles the faces that render them.

WHAT IS BUNDLED, AND ON WHAT RULE
---------------------------------
Everything a reader *reads* — scripture, lexicon, transliteration and
the search syntax shown in the command line's own help. Decorative
iconography is left to the platform, because bundling a monochrome
symbol face would replace the colour emoji that iOS and macOS already
draw. The line is visible in the data: the decorative glyphs in
`assets/bible_evidence.json` carry U+FE0F (emoji presentation); the
load-bearing ones do not.

  NotoSansHebrew-Sub    Hebrew + Hebrew presentation forms, BY RANGE
  NotoSansExt-Sub       polytonic Greek, combining marks, Latin
                        Extended Additional, spacing modifiers, BY
                        RANGE, minus everything Roboto already has
  NotoSansSymbols2-Sub  five text symbols, BY LIST
  NotoSansSC-Sub        CJK, BY SCAN of this repo (union-only)

The script blocks are subset BY RANGE, not by the characters that
happen to appear in today's assets, because Hebrew and Greek are also
*input*: a reader can type ἀγάπη or אהב into the command line, and a
scan-derived subset would blank on the first form no asset contains.
The CJK subset stays scan-derived because the full face is 16 MB.

NEVER SHRINKS
-------------
Every subset is unioned with the cmap of the file already in
assets/fonts/, so re-running this can only add coverage. The previous
script (tools/build_cjk_font_subset.sh, removed) scanned
/Users/pliu0036/Documents/yswords — the fork *parent* — so it had been
subsetting against the wrong repo's text, and 384 characters that
appear in SeekSparks assets (assets/strongs/thayer_zh.json,
assets/strongs/bdb_zh.json, the zh-TW sermons) were missing from the
bundle.

Requires: pip install fonttools brotli  (or: brew install fonttools)
Usage:    python3 tools/build_font_subsets.py
"""

from __future__ import annotations

import glob
import os
import subprocess
import sys
import tempfile
import urllib.request

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(PROJECT, 'assets', 'fonts')

GF = 'https://github.com/google/fonts/raw/main/ofl'
SOURCES = {
    'hebrew': f'{GF}/notosanshebrew/NotoSansHebrew%5Bwdth,wght%5D.ttf',
    'ext': f'{GF}/notosans/NotoSans%5Bwdth,wght%5D.ttf',
    'symbols2': f'{GF}/notosanssymbols2/NotoSansSymbols2-Regular.ttf',
    'cjk': ('https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/'
            'SimplifiedChinese/NotoSansCJKsc-Regular.otf'),
}


def rng(a: int, b: int) -> set[int]:
    return set(range(a, b + 1))


# Hebrew consonants, niqqud, cantillation, maqaf, sof pasuq, plus the
# presentation forms (U+FB1D-FB4F) that some Strong's data uses.
HEBREW = rng(0x0590, 0x05FF) | rng(0xFB1D, 0xFB4F)

# Everything Roboto stops short of on the Greek/Latin side. Greek
# Extended is the important one: it is where every breathing mark and
# accent in the Westcott-Hort NT and the LXX lives.
EXT = (
    rng(0x0100, 0x024F)   # Latin Extended-A/B (ǎ in a sermon, etc.)
    | rng(0x0250, 0x02FF)  # IPA + spacing modifiers: ʾ ʿ, aleph/ayin
    | rng(0x0300, 0x036F)  # combining marks — decomposed Greek forms
    | rng(0x0370, 0x03FF)  # Greek, for the variant letters ϐ ϕ ϰ ϲ
    | rng(0x1D00, 0x1D7F)  # phonetic extensions: superscript ᵃ ᵉ
    | rng(0x1E00, 0x1EFF)  # Latin Ext Additional: ḥ ḫ ṣ ṭ ṯ ḵ ḇ
    | rng(0x1F00, 0x1FFF)  # GREEK EXTENDED — polytonic
)

# By list, not by range. These are text-presentation glyphs that carry
# meaning: U+25A1 stands in for a character lost from Judges 13:7 and
# 18:10 in assets/cuvs-plus.json (so if it vanishes the verse silently
# reads as though nothing were missing); U+2736 is how the command
# line's own help draws the wildcard operator; U+25B6/U+25C0 are the
# phrasing pane's indent instructions; U+2713 is the family tree's
# source-reference column.
SYMBOLS2 = {0x25A1, 0x25B6, 0x25C0, 0x2713, 0x2736}

# Arrows and the info circle are UI copy — `↑ ↓ recalls the last
# command`, `LXX · 旧约↔希腊文对照`, `click ⓘ for details`. Noto Sans CJK
# has them and most of their occurrences sit inside Chinese sentences,
# so they ride along in the CJK subset rather than earning a file.
# The second row is the same argument for glyphs found in the data:
# ∧ in the Greek stats shards, ⊕ in Settings, ⋯ in the evidence and
# map indexes, the box-drawing rules the family tree and the
# concordance draw with, and the small-form comma in thayer_zh.
CJK_EXTRA = {
    0x2190, 0x2191, 0x2192, 0x2193, 0x2194, 0x24D8,
    0x2227, 0x2295, 0x22EF, 0x2500, 0x2550, 0xFE50,
}

# Kept unconditionally in the CJK subset so a Chinese line never falls
# back mid-sentence for its punctuation.
CJK_BASE = (
    rng(0x0020, 0x007E) | rng(0x00A0, 0x00FF)
    | rng(0x2000, 0x206F) | rng(0x3000, 0x303F) | rng(0xFF00, 0xFFEF)
)


def scan_repo_chars() -> set[int]:
    """Every character that appears anywhere in this repo's data or code."""
    chars: set[int] = set()
    for root in ('assets', 'lib'):
        for ext in ('json', 'dart', 'txt', 'md'):
            pat = os.path.join(PROJECT, root, '**', f'*.{ext}')
            for path in glob.glob(pat, recursive=True):
                try:
                    with open(path, encoding='utf-8') as fh:
                        chars.update(ord(c) for c in fh.read())
                except (OSError, UnicodeDecodeError):
                    pass
    return chars


def existing_cmap(filename: str) -> set[int]:
    path = os.path.join(FONTS, filename)
    if not os.path.exists(path):
        return set()
    return set(TTFont(path, lazy=True).getBestCmap().keys())


def fetch(url: str, dest: str) -> None:
    print(f'  downloading {url.rsplit("/", 1)[-1]}')
    with urllib.request.urlopen(url) as r, open(dest, 'wb') as out:
        out.write(r.read())


def build(work: str, key: str, out_name: str, wanted: set[int]) -> None:
    src = os.path.join(work, key)
    if not os.path.exists(src):
        fetch(SOURCES[key], src)

    font = TTFont(src)
    if 'fvar' in font:
        # Pin to the default instance. The engine downloads the static
        # Regular today, so a static subset keeps rendering identical.
        axes = {a.axisTag: a.defaultValue for a in font['fvar'].axes}
        font = instancer.instantiateVariableFont(font, axes)
        src = os.path.join(work, key + '-static')
        font.save(src)

    have = set(font.getBestCmap().keys())
    keep = (wanted | existing_cmap(out_name)) & have
    missing = sorted(wanted - have)
    if missing:
        print(f'  note: {len(missing)} requested code points absent from '
              f'source ({key}), e.g. '
              + ' '.join(f'U+{c:04X}' for c in missing[:6]))

    charfile = os.path.join(work, key + '.txt')
    with open(charfile, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(chr(c) for c in sorted(keep)))

    dest = os.path.join(FONTS, out_name)
    subprocess.run([
        'pyftsubset', src,
        f'--text-file={charfile}',
        f'--output-file={dest}',
        '--no-hinting',
        '--no-recommended-glyphs',
        '--layout-features=*',
    ], check=True)
    size = os.path.getsize(dest)
    print(f'  {out_name}: {len(keep):,} code points, {size // 1024:,} KB')


def main() -> int:
    os.makedirs(FONTS, exist_ok=True)
    work = tempfile.mkdtemp(prefix='ss-fonts-')
    print(f'work dir: {work}')

    print('==> scanning repo for characters')
    repo = scan_repo_chars()
    print(f'  {len(repo):,} distinct code points in assets/ + lib/')

    print('==> NotoSansHebrew-Sub')
    build(work, 'hebrew', 'NotoSansHebrew-Sub.ttf', HEBREW)

    print('==> NotoSansExt-Sub')
    roboto = existing_cmap('Roboto-VariableFont_wdth,wght.ttf')
    if not roboto:
        print('  ERROR: bundled Roboto missing; cannot compute the gap')
        return 1
    build(work, 'ext', 'NotoSansExt-Sub.ttf', EXT - roboto)

    print('==> NotoSansSymbols2-Sub')
    build(work, 'symbols2', 'NotoSansSymbols2-Sub.ttf', SYMBOLS2)

    print('==> NotoSansSC-Sub')
    cjk_wanted = CJK_BASE | CJK_EXTRA | {
        c for c in repo
        if 0x2E80 <= c <= 0x9FFF        # CJK radicals through Unified
        or 0xAC00 <= c <= 0xD7AF        # Hangul (sermon 393 quotes Korean)
        or 0xF900 <= c <= 0xFAFF        # CJK compatibility ideographs
        or 0x3040 <= c <= 0x312F        # kana + bopomofo
        or 0x20000 <= c <= 0x2FA1F      # CJK Extension B and beyond
    }
    build(work, 'cjk', 'NotoSansSC-Sub.otf', cjk_wanted)

    print('\nDone. Re-run `flutter build web` to bundle the new subsets.')
    print('Verify with test/bundled_font_coverage_test.dart.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
