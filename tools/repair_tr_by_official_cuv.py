#!/usr/bin/env python3
"""Corrections to the Traditional edition that only the official
和合本繁體 could settle, one verse at a time.

WHY THIS IS SEPARATE FROM `repair_cuvs_yhwh_tr_onetomany.py`
------------------------------------------------------------
That script needs a witness to PROPOSE a change: it takes yswords'
Traditional import for the positions and, since 2026-09-08, the
official edition for the form. It cannot see a place where **both**
imports carry the same wrong glyph, because nothing proposes anything.

反覆 is exactly that place. 复 is one Simplified character standing for
three Traditional ones -- 復 (again), 複 (compound) and 覆 (turn over)
-- and every converter that has touched this text mapped all 239 of
them to 復. That is right 236 times and wrong three:

    路加福音 1:29    又反覆思想這樣問安是甚麼意思
    路加福音 2:19    存在心裡，反覆思想
    哥林多後書 1:17  豈是反覆不定嗎

read at bible.fhl.net (VERSION1=unv) on 2026-09-08, on the owner's
ruling 「参考和合本繁體官方的去决定」. 反覆 is "over and over"; 反復
is not the word.

WHY IT IS ANCHORED TO A VERSE AND A PHRASE
------------------------------------------
Not `復 -> 覆` -- that would rewrite 復活 233 times. Not even
`反復ap -> 反覆` globally, though it happens to be safe here: a
correction that came from reading ONE verse is applied to THAT verse,
and the phrase is quoted so the next reader can check the same thing
the same way. If a fourth 反復 ever appears it does not get swept in
silently; it gets read.

WHAT IS DELIBERATELY NOT DONE HERE
----------------------------------
The official edition also differs from this one in two ways that are
house style rather than defect, and this script does not touch either:
it prints 甚麼 where this edition prints 什麽, and it mixes 裡 and 裏
where this edition uses 裏 throughout. Those are whole-file
orthographic conventions, not three verses; changing them is an
editorial decision about the edition, not a repair, and it is not one a
script should make on the way past.

Usage:  tools/repair_tr_by_official_cuv.py [--write]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')
PLACES = os.path.join(ROOT, 'assets', 'bible_places.json')

# The atlas's traditional place names follow the CUV pair, by check 53's
# rule: a character in a place name's `t` has to be one the two shipped
# editions actually put opposite the `s` character. Correcting 侖 to 崙
# and 墻 to 牆 in the scripture therefore un-witnesses the atlas's own
# 希伯侖 and 寬牆, and `place_name_script_test` says so immediately.
# Same ruling, same two glyphs, applied to the same names.
PLACE_GLYPHS = {'侖': '崙', '墻': '牆'}

# verse id -> (what we print, what the official edition prints, where)
#
# The second group is a different kind of find. `build_cuv_char_table.py`
# reports which Simplified characters this edition renders with more
# than one Traditional form, and 众 -> 眾 1,892 / 衆 4 is not a variant
# reading, it is four places the edition contradicts itself. The
# official edition prints 眾, and so does this edition everywhere else,
# so the two authorities agree and there is nothing to weigh.
#
# 么 -> 麽 1,230 / 麼 11 is the SAME shape of finding and is NOT here,
# because the two authorities do NOT agree: the official edition prints
# 甚麼 and this one prints 什麽. Normalising the 11 strays would deepen
# a disagreement with the official text; adopting the official form
# would rewrite 1,241 characters and, to be the official reading at
# all, would have to change 什 to 甚 as well -- a word, not a glyph.
# That is the owner's call and it is open. 民數記 24:13 spells it both
# ways inside one verse (「什麽，我就要說什麼？」), so it does need
# making, but not by a script running past on other business.
CORRECTIONS = {
    '042001029': ('反復思想', '反覆思想', '路加福音 1:29'),
    '042002019': ('反復思想', '反覆思想', '路加福音 2:19'),
    '047001017': ('反復不定', '反覆不定', '哥林多後書 1:17'),
    '010005017': ('非利士衆人', '非利士眾人', '撒母耳記下 5:17'),
    '022001008': ('<note: 衆人：>', '<note: 眾人：>', '雅歌 1:8'),
    '022008008': ('<note: 衆人：>', '<note: 眾人：>', '雅歌 8:8'),
    '023022004': ('"衆民"', '"眾民"', '以賽亞書 22:4'),
}


def main():
    write = '--write' in sys.argv
    rows = json.load(open(ASSET, encoding='utf-8'))
    by_id = {r['id']: r for r in rows}

    applied = missing = already = 0
    for vid, (old, new, where) in CORRECTIONS.items():
        r = by_id.get(vid)
        if r is None:
            print('MISSING VERSE  %s  %s' % (vid, where))
            missing += 1
            continue
        if new in r['text'] and old not in r['text']:
            print('already correct %s  %s' % (vid, where))
            already += 1
            continue
        if r['text'].count(old) != 1:
            print('NOT APPLIED    %s  %s: %r appears %d times, expected 1'
                  % (vid, where, old, r['text'].count(old)))
            missing += 1
            continue
        r['text'] = r['text'].replace(old, new)
        print('applied        %s  %s  %s -> %s' % (vid, where, old, new))
        applied += 1

    print('\napplied %d, already correct %d, not applied %d'
          % (applied, already, missing))
    if missing:
        raise SystemExit('REFUSING TO WRITE: a correction did not match; '
                         'go and read the verse rather than loosening this')
    # The atlas follows the scripture.
    atlas = json.load(open(PLACES, encoding='utf-8'))
    place_hits = []
    for r in atlas['places']:
        t = r.get('t')
        if not t or not any(ch in t for ch in PLACE_GLYPHS):
            continue
        new = ''.join(PLACE_GLYPHS.get(ch, ch) for ch in t)
        place_hits.append('%s  %s -> %s' % (r['n'], t, new))
        r['t'] = new
    print('\natlas place names corrected: %d' % len(place_hits))
    for h in place_hits:
        print('    %s' % h)

    if not write:
        print('(dry run; pass --write)')
        return
    if place_hits:
        with open(PLACES, 'w', encoding='utf-8') as f:
            json.dump(atlas, f, ensure_ascii=False, separators=(',', ':'))
            f.write('\n')
        print('WROTE %s' % PLACES)
    if applied:
        with open(ASSET, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
        print('WROTE %s' % ASSET)


if __name__ == '__main__':
    main()
