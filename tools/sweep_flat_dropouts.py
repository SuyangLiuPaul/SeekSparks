#!/usr/bin/env python3
"""Sweep the short-dropout class across all 31,102 verses of cuvs-yhwh.

Reproducer for the 89-site figure cited in docs/DATA-INTEGRITY.md §46b.

Written because the refuter surfaced 士师记 12:13 作以色的士师 (missing 列)
from OUTSIDE the adjudicator's list of 21. The adjudicator only fires where
the reading text stands alone; a loss present in BOTH our layers passes it at
100%. This sweep has a different blind spot and so sees a different set: it
compares the two flat Chinese editions on Han characters alone, so it finds
losses the tagged layer shares — but it cannot see a transposition, where the
verse has the right characters in the wrong place, and it cannot see anything
the sibling lost too.

Strip notes and every mark of punctuation, keep Han only, align with
difflib, and report each run of 1–3 characters one edition has and the other
lacks. The Han-only allowlist is load-bearing: a first pass that blocklisted
punctuation returned 426 sites, 308 of them B's ASCII quotes and em-dashes.

A short run is not a defect on its own — the two editions differ in Han
content in ~7,900 verses, mostly by legitimate editorial choice. The output is
a candidate list to read one by one, which is how check 46 used it.

Reported 89 sites (34 of them single-character) before check 46; 82 and 27
after, the seven repairs of this class having closed.
"""
import difflib
import json
import os
import re
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOTE = re.compile(r'<[^>]*>')
HAN = re.compile(r'[㐀-鿿]')

EN = ["Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth",
"1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah",
"Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah",
"Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah","Nahum",
"Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark","Luke","John","Acts",
"Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians",
"1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews",
"James","1 Peter","2 Peter","1 John","2 John","3 John","Jude","Revelation"]


def bare(t):
    """Han characters only -- every mark of punctuation, every note, gone."""
    return ''.join(HAN.findall(NOTE.sub('', t)))


A = json.load(open(os.path.join(ROOT, 'assets/cuvs-yhwh.json'), encoding='utf-8'))
B = json.load(open(os.path.join(ROOT, 'assets/cuvs-plus.json'), encoding='utf-8'))

ZH = []
for r in A:
    if r['book'] not in ZH:
        ZH.append(r['book'])
ZH2EN = dict(zip(ZH, EN))

bidx = {(r['book'], str(r['chapter']), str(r['verse'])): r['text'] for r in B}

gaps, extras = [], []
differing = 0
for r in A:
    key = (r['book'], str(r['chapter']), str(r['verse']))
    a, b = bare(r['text']), bare(bidx[key])
    if a == b:
        continue
    differing += 1
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        ref = f'{ZH2EN[r["book"]]} {r["chapter"]}:{r["verse"]}'
        if tag == 'insert' and j2 - j1 <= 3:
            gaps.append((ref, b[j1:j2],
                         a[max(0, i1-8):i1] + '【' + b[j1:j2] + '】' + a[i1:i1+8]))
        elif tag == 'delete' and i2 - i1 <= 3:
            extras.append((ref, a[i1:i2],
                           a[max(0, i1-8):i1] + '《' + a[i1:i2] + '》' + a[i2:i2+8]))

print(f'{len(A)} verses; {differing} differ in Han content between A and B')
print(f'sites where B has 1-3 Han chars A lacks : {len(gaps)}')
print(f'sites where A has 1-3 Han chars B lacks : {len(extras)}')
print()

one = [g for g in gaps if len(g[1]) == 1]
print(f'== A lacks a single Han character B has: {len(one)} ==')
print(collections.Counter(g[1] for g in one).most_common())
print()
for g in sorted(one):
    print(f'  {g[0]:<24} 【{g[1]}】  {g[2]}')

print()
multi = [g for g in gaps if len(g[1]) > 1]
print(f'== A lacks 2-3 Han characters B has: {len(multi)} ==')
for g in sorted(multi):
    print(f'  {g[0]:<24} 【{g[1]}】  {g[2]}')
