#!/usr/bin/env python3
"""Three family-tree names that no Bible we ship contains (check 36).

`assets/family_tree.json` prints a name for each of 277 people and cites
the verses that person appears in. Check 25 proved those references
resolve. It never asked whether the passage they resolve to contains the
name printed over it — and for three people it does not, in any of the
five English editions the app ships:

    Melki         -> Melchi    bsb, kjv, kjv+s, nasb and leb all read
                               "Melchi" at Luke 3:24, the record's only
                               reference. "Melki" occurs 0 times in all
                               five. The file already calls the other man
                               of that name "Melchi (II)", so the record
                               being repaired is the (I) the convention
                               was written for, and an English reader
                               could not previously see that the two
                               entries were the same name.

    Josek         -> Josech    bsb, nasb and leb read "Josech" at Luke
                               3:26; kjv and kjv+s read "Joseph" there,
                               following a different Greek text. "Josek"
                               occurs 0 times in all five.

    Joshua / Jose -> Joshua    not a name at all: two editions' spellings
                               of one man joined by a slash, sitting in a
                               field the app prints verbatim. bsb, nasb
                               and leb read "Joshua" at Luke 3:29; kjv
                               and kjv+s read "Jose".

Both surviving choices follow the same tradition the rest of the file
follows, and that was measured rather than assumed: of the 39 people in
the Lukan chain, 11 carry a name only bsb/nasb/leb print and exactly 1
carries a name only the kjv prints. The file's English is the modern
critical text, 11 to 1.

`Janna` is that one, and it is deliberately NOT touched. The kjv and
kjv+s do read "Janna" at Luke 3:24, so the name is witnessed by a Bible
the app ships; changing it would be a consistency preference, not an
accuracy repair, and the standing rule is about what is true.

No Chinese name is touched either, although ten of them are absent from
the CUV at their own verses. Eight are transliterations of the modern
critical name in a chain where the CUV follows the Textus Receptus and
therefore reads a different name entirely — an editorial policy, not an
error. Telling those apart from the two that look like slips is a
translation judgement and is left to a human; check 36 in
docs/DATA-INTEGRITY.md lists all ten with the CUV's reading.

Idempotent: re-running reports "already correct".

    python3 tools/repair_family_tree_names.py [--dry-run]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / 'assets' / 'family_tree.json'

# person id -> (field, as shipped, as repaired, why)
NAMES = [
    ('melki_nt', 'name', 'Melki', 'Melchi',
     'Luke 3:24, the record\'s only reference, reads "Melchi" in bsb, kjv, '
     'kjv+s, nasb and leb; "Melki" appears in none of the five. The file '
     'already names the other man "Melchi (II)"'),
    ('josek_lk_26', 'name', 'Josek', 'Josech',
     'Luke 3:26, the record\'s only reference, reads "Josech" in bsb, nasb '
     'and leb and "Joseph" in kjv and kjv+s; "Josek" appears in none of '
     'the five'),
    ('joshua_lk_29', 'name', 'Joshua / Jose', 'Joshua',
     'two editions\' spellings joined by a slash in a field the app prints '
     'verbatim; Luke 3:29 reads "Joshua" in bsb, nasb and leb and "Jose" '
     'in kjv and kjv+s'),
    # The name also stands in another record's summary, where it was
    # equally unwitnessed.
    ('janna', 'summary', 'Father of Melki; listed in Mary\'s Lukan ancestry.',
     'Father of Melchi; listed in Mary\'s Lukan ancestry.',
     'follows the repair of melki_nt'),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    raw = ASSET.read_text(encoding='utf-8')
    data = json.loads(raw)
    people = {p['id']: p for p in data['people']}
    corrections = data.setdefault('corrections', [])
    already = {(c['id'], c['field']) for c in corrections}

    changed, done, missing = 0, 0, []
    for pid, field, before, after, why in NAMES:
        p = people.get(pid)
        if p is None:
            missing.append(f'{pid} is not in the asset')
            continue
        if p[field] == after:
            done += 1
            if (pid, field) not in already:
                corrections.append(
                    {'id': pid, 'field': field, 'from': before, 'why': why})
                changed += 1
            continue
        if p[field] != before:
            missing.append(
                f'{pid}.{field}: expected {before!r}, found {p[field]!r}')
            continue
        print(f'  {pid}.{field}: {before!r} -> {after!r}')
        p[field] = after
        corrections.append(
            {'id': pid, 'field': field, 'from': before, 'why': why})
        changed += 1

    for line in missing:
        print('  !', line)
    if not changed:
        print(f'already correct ({done}/{len(NAMES)} names)')
        return 1 if missing else 0

    corrections.sort(key=lambda c: (c['id'], c['field']))
    if args.dry_run:
        print(f'{changed} names would change (dry run)')
        return 0
    # indent=2 reproduces the shipped file byte for byte, so the diff
    # shows the repair and nothing else.
    ASSET.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')
    print(f'{changed} names repaired, {len(corrections)} corrections recorded')
    print(f'written {ASSET}')
    return 1 if missing else 0


if __name__ == '__main__':
    raise SystemExit(main())
