#!/usr/bin/env python3
"""Defects in 和合本雅偉版 that only the official 和合本 could settle.

WHY THESE EXIST AT ALL
----------------------
This app's copy of the edition is **99.1% the publisher's current text**
(30,834 of 31,102 verses, measured against their own edit log). That is
the right place to be — it is their edition. It also means that where
their current text is wrong, we ship it wrong, and nothing internal to
this repo can tell the difference between their reading and a defect.

So the owner's ruling decides: 「参考和合本繁體官方的去决定」 — consult
the official 和合本繁體. The witness is the plain 和合本繁體 (耶和華, not
雅偉), 31,103 verses, kept in the Yahweh's Words repository's history at
git blob **7a2dc43** and spot-checked against bible.fhl.net
(VERSION1=unv), where it agrees character for character.

Every entry below was read there first. Every one was also found in
Yahweh's Words on the same day and fixed there by the same reading:
the two apps carry the same edition and neither should carry it wrong.

WHY EACH IS ANCHORED TO ITS VERSE
---------------------------------
Never a global substitution — a rule that fixed 五壳 by rewriting 壳
would also rewrite every shell in the Bible. A correction that came
from reading one verse is applied to that verse.

Usage:  tools/repair_by_official_cuv.py [--write]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMP = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
TRAD = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')

# (verse id, scripts, ours, the official reading, where and why)
# scripts: 's' simplified, 't' traditional, 'st' both.
CORRECTIONS = [
    # 五壳 / 五殼 is not a word. 以賽亞書 36:17 promises 五穀和新酒 —
    # grain and new wine — and 壳 got there in place of 谷/穀 before the
    # script split, so BOTH files carry it and no simplified-leak sweep
    # can see it. Only reading the verse finds this one.
    ('023036017', 's', '有五壳和新酒', '有五谷和新酒', '以賽亞書 36:17'),
    ('023036017', 't', '有五殼和新酒', '有五穀和新酒', '以賽亞書 36:17'),

    # Punctuation doubled by an edit. None of these is a reading:
    # 「當醒起；！」 and 「日子，，那時辰」 are keystrokes.
    ('019057008', 's', '当醒起；！', '当醒起！', '詩篇 57:8'),
    ('019057008', 't', '當醒起；！', '當醒起！', '詩篇 57:8'),
    ('040025013', 's', '那日子，，那时辰', '那日子，那时辰', '馬太福音 25:13'),
    ('040025013', 't', '那日子，，那時辰', '那日子，那時辰', '馬太福音 25:13'),
    ('058008002', 's', '所支的，，不是', '所支的，不是', '希伯來書 8:2'),
    ('058008002', 't', '所支的，，不是', '所支的，不是', '希伯來書 8:2'),

    # 何鹹 is 何咸, and this one is the reverse of what it looks like.
    # 咸 reads as a Simplified leak for 鹹 and is not: the official
    # edition prints 「希伯崙王何咸」, our own Simplified reads 咸, and
    # Yahweh's Words' Traditional reads 咸. This file is the odd one
    # out, so it moves — and this comment exists so the next
    # simplified-leak sweep does not move it back.
    ('006010003', 't', '希伯崙王何鹹', '希伯崙王何咸', '約書亞記 10:3'),

    # One note inside another. 馬太福音 17:21 is a wholly-editorial
    # verse — the whole of it is the publisher's 〔有古卷在此有21節：…〕
    # — and it is the only verse in the edition with a second bracket
    # nested inside the first. Whatever converted 〔…〕 to <note: …>
    # matched to the FIRST 〕, which is the inner one, so the note closed
    # early and 。」〕 was left standing outside it as if it were
    # scripture. The other thirteen wholly-editorial verses have no
    # nesting and came through intact. It goes back to the shape its
    # thirteen siblings have.
    ('040017021', 's',
     '<note: 有古卷在此有21节：“至于这一类的鬼，若不祷告、禁食，'
     '它就不出来〔或作："不能赶它出来">。”〕',
     '〔有古卷在此有21节：“至于这一类的鬼，若不祷告、禁食，'
     '它就不出来〔或作："不能赶它出来"〕。”〕', '馬太福音 17:21'),
    ('040017021', 't',
     '<note: 有古卷在此有21節：「至於這一類的鬼，若不禱告、禁食，'
     '它就不出來〔或作："不能趕它出來">。」〕',
     '〔有古卷在此有21節：「至於這一類的鬼，若不禱告、禁食，'
     '它就不出來〔或作："不能趕它出來"〕。」〕', '馬太福音 17:21'),
]

# OPEN, AND NOT DECIDED HERE
# --------------------------
# This edition holds **6,217 enumeration commas and the official holds
# 6,349**. 出埃及記 39:24 reads 「用藍色紫色朱紅色線」 where the official
# prints 「用藍色、紫色、朱紅色線」 — a list of three colours with no
# separator. Yahweh's Words had an older copy that still carried them
# and could restore from its own history; this app has no such baseline,
# so putting 132 marks back means taking them from another edition, one
# at a time, and that is a pass of its own with the owner's eye on it.
# Recorded here with the measurement so it is a known gap, not a
# surprise.


def main():
    write = '--write' in sys.argv
    files = {'s': (SIMP, json.load(open(SIMP, encoding='utf-8'))),
             't': (TRAD, json.load(open(TRAD, encoding='utf-8')))}
    index = {k: {r['id']: r for r in rows} for k, (_, rows) in files.items()}

    applied = already = failed = 0
    touched = set()
    for vid, scripts, old, new, where in CORRECTIONS:
        for k in scripts:
            r = index[k].get(vid)
            if r is None:
                print('MISSING  %s %s  %s' % (vid, k, where))
                failed += 1
                continue
            if old not in r['text']:
                if new in r['text']:
                    print('already  %s %s  %s' % (vid, k, where))
                    already += 1
                else:
                    print('NO MATCH %s %s  %s: neither %r nor %r'
                          % (vid, k, where, old, new))
                    failed += 1
                continue
            if r['text'].count(old) != 1:
                print('AMBIGUOUS %s %s  %s: %r appears %d times'
                      % (vid, k, where, old, r['text'].count(old)))
                failed += 1
                continue
            r['text'] = r['text'].replace(old, new)
            print('applied  %s %s  %s' % (vid, k, where))
            applied += 1
            touched.add(k)

    print('\napplied %d, already correct %d, could not apply %d'
          % (applied, already, failed))
    if failed:
        raise SystemExit('REFUSING TO WRITE: go and read the verse rather '
                         'than loosening this')
    if not write:
        print('(dry run; pass --write)')
        return
    for k in sorted(touched):
        path, rows = files[k]
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
        print('WROTE %s' % path)


if __name__ == '__main__':
    main()
