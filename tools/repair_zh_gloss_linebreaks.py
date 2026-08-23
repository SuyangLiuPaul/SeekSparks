#!/usr/bin/env python3
"""Rebuild `glossZh` / `glossZhTw` in the shipped Strong's lexicons from
the definition bodies that ship beside them (check 44f, DATA-INTEGRITY
"Next, in order" item 0).

`tools/build_originals.py` used to keep only the first physical LINE of
CBOL's sense 1. CBOL wraps a long sense at its own column width, so the
shipped gloss for 491 entries stopped wherever the printed page broke —
H204 read `位于埃及低地的一个城市, 歌珊的边界处, 崇拜太阳神的中心,`
and the clause naming it as Potiphera's home town was on line two.
`glossZh` is the row summary in the Lexicon Browser and the gloss in
word study, so a reader met the fragment and had no way to tell it was
one.

This runs the fixed generator's `sense_one_gloss` over the assets that
are already in the tree. **No network is needed**: `defZh` and `defZhTw`
ship whole, so the joined gloss is derivable from what we already have.

Importing the function rather than restating it is the point. Check 44f
asked for the generator and the shipped asset to be fixed "in one
change, or they drift"; sharing the implementation means they cannot.

`glossZhTw` is parsed out of `defZhTw`, NOT converted from the repaired
`glossZh`. `scripts/build_strongs_traditional.py` would give the same
answer, but running OpenCC again introduces a conversion this repair
does not need — and s2t is not a safe blanket operation on this corpus
(see `tools/repair_cuvs_yhwh_tr.py`). Reading the Traditional gloss out
of the Traditional body keeps every character one that already shipped.

Idempotent. Run from the repo root:

    python3 tools/repair_zh_gloss_linebreaks.py [--dry-run]
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from build_originals import sense_one_gloss  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = [
    os.path.join(REPO, 'assets', 'strongs', 'hebrew.json'),
    os.path.join(REPO, 'assets', 'strongs', 'greek.json'),
]

# Serialisation must match `build_originals.py` exactly, or the repair
# reformats five megabytes and buries itself.
DUMP = dict(ensure_ascii=False, separators=(',', ':'))

_DANGLING = re.compile(r'[,，、;；]\s*$')

PAIRS = (('glossZh', 'defZh'), ('glossZhTw', 'defZhTw'))


def repair(path: str, dry_run: bool) -> dict[str, int]:
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    stats = {'entries': len(data), 'changed': 0, 'dangling_before': 0,
             'dangling_after': 0, 'gained_chars': 0}
    for entry in data.values():
        touched = False
        for gloss_key, def_key in PAIRS:
            old = entry.get(gloss_key)
            body = entry.get(def_key)
            if old is None or not body:
                continue
            if _DANGLING.search(old):
                stats['dangling_before'] += 1
            new = sense_one_gloss(body)
            # A body we cannot parse leaves the shipped value alone: an
            # empty gloss is a regression, not a repair.
            if not new or new == old:
                if _DANGLING.search(entry.get(gloss_key) or ''):
                    stats['dangling_after'] += 1
                continue
            entry[gloss_key] = new
            stats['gained_chars'] += len(new) - len(old)
            touched = True
            if _DANGLING.search(new):
                stats['dangling_after'] += 1
        if touched:
            stats['changed'] += 1
    if not dry_run:
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, **DUMP)
    return stats


def main() -> None:
    dry_run = '--dry-run' in sys.argv
    for path in TARGETS:
        s = repair(path, dry_run)
        print(f'{os.path.relpath(path, REPO)}: {s["changed"]} of '
              f'{s["entries"]} entries rewritten, '
              f'{s["gained_chars"]:+d} characters, '
              f'glosses ending on a separator '
              f'{s["dangling_before"]} -> {s["dangling_after"]}')
    if dry_run:
        print('(dry run — nothing written)')


if __name__ == '__main__':
    main()
