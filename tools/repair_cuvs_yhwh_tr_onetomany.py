#!/usr/bin/env python3
"""Repair one-to-many conversion collapses in `assets/cuvs-yhwh-tr.json`.

THE DEFECT
----------
Our Traditional asset was produced by a converter that maps each
Simplified character to exactly one Traditional character. Several
Simplified characters stand for two different Traditional ones, and for
those the converter always picked the wrong one when the sense was the
rarer of the two:

    发 -> 發 (send) or 髮 (hair)      we have 髮 0 times
    谷 -> 谷 (valley) or 穀 (grain)    we have 穀 0 times
    松 -> 松 (pine) or 鬆 (loose)      we have 鬆 0 times
    胡 -> 胡 or 鬍 (beard)             we have 鬍 0 times
    须 -> 須 (must) or 鬚 (beard)      we have 鬚 0 times
    采 -> 采 or 採 (to pick)           we have 採 0 times

plus two plain variant-form misses that are not one-to-many at all,
墻/牆 and 侖/崙, where our file simply carries the variant glyph.

So 創世記 41:49 has Joseph storing 谷 (a valley) rather than 穀 (grain),
創世記 42:38 has 白發 (white sending) rather than 白髮 (white hair), and
利未記 13:33 has 剃去須發 rather than 剃去鬚髮.

WHAT THIS DOES NOT DO
---------------------
It does not decide any of these by reasoning about the Chinese. An
earlier pass on this file reasoned its way to a conclusion, was
confident, had measurements, and was wrong -- and the note that talked
it into it is now corrected in docs/DATA-INTEGRITY.md.

Every change here needs TWO independent witnesses to the same edition
to agree on it, at the same place, in a verse that is otherwise
identical to ours:

  witness 1  yswords' assets/cuvs-yhwh-tr.json  (a separate import of
             this edition, repaired over ~20 commits in 2026-08)
  witness 2  Yahwehdehua's app/build/bible.db, table cuvt (built by the
             publisher's own converter from the table the edition is
             maintained in)

The two disagree plenty -- witness 1 has 麵 107 times and witness 2 has
it zero times -- and where they disagree this script changes nothing.
That is the point: 183 verses are dropped for exactly that reason, and
they are reported rather than resolved.

Quote style, 説/說 and 着/著 are folded before comparing, because the
three files use three different conventions there and those are house
style, not evidence. They are NOT changed by this pass.

Usage:  tools/repair_cuvs_yhwh_tr_onetomany.py [--write]
"""
import collections
import difflib
import json
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')
WITNESS_1 = os.path.expanduser(
    '~/Documents/yswords/assets/cuvs-yhwh-tr.json')
DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')

# ours -> what it should be. Nothing outside this map is touched, so a
# witness that disagrees about anything else cannot drag it in.
PAIRS = {
    '發': '髮', '谷': '穀', '面': '麵', '松': '鬆',
    '胡': '鬍', '須': '鬚', '采': '採',
    '墻': '牆', '侖': '崙', '崘': '崙',
}


def norm(s):
    """Fold the three files' house styles so the comparison is about
    the glyphs in question and nothing else."""
    s = re.sub(r'<note:\s*([^>]*)>',
               lambda m: '〔' + m.group(1).strip() + '〕', s)
    s = (s.replace('「', '“').replace('」', '”')
          .replace('『', '‘').replace('』', '’'))
    return s.replace('説', '說').replace('着', '著')


def subs(a, b):
    """The single-character substitutions turning a into b, or None if
    the two differ by anything other than substitution -- an inserted
    or deleted character means the verses are not aligned and no
    position in them can be trusted."""
    out = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
            None, a, b, autojunk=False).get_opcodes():
        if tag == 'equal':
            continue
        if tag != 'replace' or (i2 - i1) != (j2 - j1):
            return None
        out.extend(zip(a[i1:i2], b[j1:j2]))
    return out


def main():
    write = '--write' in sys.argv
    con = sqlite3.connect(DB)
    seq = {code: s for s, code in con.execute('select seq, code from books')}
    w2 = {'%03d%03d%03d' % (seq[b], c, v): p
          for b, c, v, p in con.execute(
              "select book, chapter, verse, plain from verses "
              "where version='cuvt'")}
    w1 = {r['id']: r['text']
          for r in json.load(open(WITNESS_1, encoding='utf-8'))}

    rows = json.load(open(ASSET, encoding='utf-8'))
    fixes = collections.Counter()
    blocked = collections.Counter()
    disagreements = []
    changed = 0

    for r in rows:
        ours = norm(r['text'])
        a, b = w1.get(r['id']), w2.get(r['id'])
        if a is None or b is None:
            continue
        s1, s2 = subs(ours, norm(a)), subs(ours, norm(b))
        if s1 is None or s2 is None:
            blocked['verses not alignable'] += 1
            continue
        proposed = [p for p in s1 if PAIRS.get(p[0]) == p[1]]
        if not proposed:
            continue
        if any(PAIRS.get(p[0]) != p[1] for p in s1):
            blocked['verse differs for other reasons too'] += 1
            continue
        agreed = [p for p in proposed if p in s2]
        if not agreed:
            blocked['witnesses disagree'] += 1
            disagreements.append((r['id'], proposed))
            continue
        # Apply positionally against the unfolded text, so house style
        # survives: walk our own string and rewrite only the indices
        # the agreed substitutions land on.
        chars = list(r['text'])
        folded = list(ours)
        pending = collections.Counter(agreed)
        for i, ch in enumerate(folded):
            tgt = PAIRS.get(ch)
            if tgt and pending[(ch, tgt)] > 0 and chars[i] == ch:
                chars[i] = tgt
                pending[(ch, tgt)] -= 1
                fixes[(ch, tgt)] += 1
        if ''.join(chars) != r['text']:
            r['text'] = ''.join(chars)
            changed += 1

    print('verses changed: %d   glyphs repaired: %d'
          % (changed, sum(fixes.values())))
    for (x, y), n in fixes.most_common():
        print('    %s -> %s  %d' % (x, y, n))
    print('not changed: %s' % dict(blocked))
    print('\nwitness disagreements (left exactly as they are, %d verses):'
          % len(disagreements))
    for vid, props in disagreements[:15]:
        print('    %s  yswords proposes %s, the publisher converter does not'
              % (vid, props))

    if write:
        with open(ASSET, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
        print('\nWROTE %s' % ASSET)
    else:
        print('\n(dry run; pass --write)')


if __name__ == '__main__':
    main()
