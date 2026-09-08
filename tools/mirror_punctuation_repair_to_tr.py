#!/usr/bin/env python3
"""Apply the Simplified punctuation repair to the Traditional edition at
the same character positions.

WHY POSITIONS AND NOT A SECOND WITNESS
--------------------------------------
`assets/cuvs-yhwh.json` and `assets/cuvs-yhwh-tr.json` are one edition in
two scripts, regenerated together, and `test/edition_script_purity_test`
holds them to it: same 31,102 verses, and every verse pair the same
length with a character-for-character correspondence. That invariant is
what makes this script correct and also what makes it necessary --
repairing one file alone breaks the pair.

So this does not ask a witness what the Traditional should say. A stray
space at index 37 of the Simplified verse is the same stray space at
index 37 of the Traditional one; the correspondence is the evidence.
It replays the exact edit script from
`repair_cuvs_yhwh_ascii_punctuation.py` -- computed by diffing the
pre-repair Simplified out of git against the repaired one -- onto the
Traditional text, and refuses any verse where the two scripts are not
actually aligned, rather than guessing.

Usage:  tools/mirror_punctuation_repair_to_tr.py [--write]
"""
import difflib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMP = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
TRAD = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')


def load(path):
    return {r['id']: r['text']
            for r in json.load(open(path, encoding='utf-8'))}


def main():
    write = '--write' in sys.argv
    before = {r['id']: r['text'] for r in json.loads(subprocess.check_output(
        ['git', 'show', 'HEAD:assets/cuvs-yhwh.json'], cwd=ROOT
    ).decode('utf-8'))}
    after = load(SIMP)

    rows = json.load(open(TRAD, encoding='utf-8'))
    mirrored = misaligned = 0
    for r in rows:
        old, new = before.get(r['id']), after.get(r['id'])
        if old is None or new is None or old == new:
            continue
        trad = r['text']
        if len(trad) != len(old):
            # The pair is not character-aligned here, so no index in it
            # means anything. Leave it and say so.
            misaligned += 1
            print('  NOT ALIGNED %s  simplified %d chars, traditional %d'
                  % (r['id'], len(old), len(trad)))
            continue
        out = []
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
                None, old, new, autojunk=False).get_opcodes():
            if tag == 'equal':
                out.append(trad[i1:i2])
            elif tag == 'delete':
                pass
            elif tag == 'insert':
                out.append(new[j1:j2])
            else:  # replace: take the Simplified's new mark, which for
                   # punctuation is script-neutral
                out.append(new[j1:j2])
        r['text'] = ''.join(out)
        mirrored += 1

    print('verses mirrored into the Traditional edition: %d' % mirrored)
    print('verses skipped because the two scripts are not aligned: %d'
          % misaligned)
    if write:
        with open(TRAD, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
        print('WROTE %s' % TRAD)
    else:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
