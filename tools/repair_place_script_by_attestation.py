#!/usr/bin/env python3
"""Make the atlas's Traditional place names agree with the edition.

Check 53 (see `test/place_name_script_test.dart`) built a
simplified→traditional character map out of the 31,102 CUV verse pairs
and repaired 46 place names whose Traditional form disagreed with it,
leaving 5 that the corpus cannot settle at all.

2026-09-14: adopting the official 和合本雅偉版 moved the Traditional
column, and with it four of those correspondences. The official edition
writes 户, 衞, 脱 and 敍 where this atlas had 戶, 衛, 脫 and 敘 — variant
pairs, both forms real, and the edition's choice is the one a reader sees
beside the map. Seven names went unwitnessed at once: Bahurim, Dophkah,
Gate of the Guard, Hukkok, Hukok, Sychar, Syracuse.

The rule is the same one check 53 used: a Traditional character the
corpus does not attest is replaced by the one it does, and ONLY when the
corpus offers exactly one candidate. Where it offers several — 里 stands
opposite both 裏 and 里 — nothing is guessed and the name stays in the
test's deliberately-left set.

Usage:
    tools/repair_place_script_by_attestation.py [--write] [--repo <path>]
"""
import json
import os
import sys


# The five `place_name_script_test.dart` leaves alone, and this pass must
# leave alone too. They are not script variants: 義大利 / 意大利 is Taiwan
# usage against mainland usage, and the corpus "witness" for it is itself
# a mechanical t2s artifact — repairing by attestation there would impose
# mainland vocabulary on a Traditional edition. 基德/吉德 is attested both
# ways; the other three are not attested at all.
#
# A name leaving that test's set has to leave this one too, and the test
# says so from its side.
LEFT_DELIBERATELY = {'Cyprus', 'Italy', 'Malta', 'Geder', 'Neapolis'}


def main():
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    A = lambda *p: os.path.join(repo, 'assets', *p)

    simplified = {r['id']: r['text']
                  for r in json.load(open(A('cuvs-yhwh.json'), encoding='utf-8'))}
    traditional = {r['id']: r['text']
                   for r in json.load(open(A('cuvs-yhwh-tr.json'), encoding='utf-8'))}
    witness = {}
    for vid, s in simplified.items():
        t = traditional.get(vid, '')
        if len(t) != len(s):
            continue
        for a, b in zip(s, t):
            witness.setdefault(a, set()).add(b)

    doc = json.load(open(A('bible_places.json'), encoding='utf-8'))
    fixed, ambiguous = [], []
    for place in doc['places']:
        if place.get('n') in LEFT_DELIBERATELY:
            continue
        s, t = place.get('s', ''), place.get('t', '')
        if len(s) != len(t):
            continue
        out = []
        touched = False
        for a, b in zip(s, t):
            seen = witness.get(a, set())
            if a != b and b not in seen:
                if len(seen) == 1:
                    out.append(next(iter(seen)))
                    touched = True
                    continue
                ambiguous.append((place.get('n'), a, b, sorted(seen)))
            out.append(b)
        if touched:
            fixed.append((place.get('n'), t, ''.join(out)))
            place['t'] = ''.join(out)

    for n, was, now in fixed:
        print('  %-22s %s -> %s' % (n, was, now))
    print('repaired by attestation: %d' % len(fixed))
    for n, a, b, seen in ambiguous:
        print('  ambiguous, left alone: %-16s %s/%s  corpus offers %s'
              % (n, a, b, '/'.join(seen)))

    if write and fixed:
        with open(A('bible_places.json'), 'w', encoding='utf-8') as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % A('bible_places.json'))
    elif not write:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
