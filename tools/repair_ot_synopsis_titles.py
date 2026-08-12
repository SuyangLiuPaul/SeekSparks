#!/usr/bin/env python3
"""Seven OT Synopsis titles that the passage they label contradicts (check 35).

`assets/ot_synopsis.json` ships 139 group titles imported from Eagle's
View, and each one is printed over the passages it names. Seven of them
misspell a word. Four are proper names, and in every one of those four
the correct spelling is carried by the group's own verses in two
independent translations — so nothing outside this repository is
consulted and nothing is guessed:

    27   Jepheth  -> Japheth     1 Chronicles 1:4 "Shem, Ham, and
                                 Japheth"; CUV 雅弗
    165  Johoash  -> Jehoash     2 Kings 14:15-16, the very verses the
                                 group points at, twice; CUV 约阿施
    188  Manesseh -> Manasseh    2 Chronicles 33:1, 2 Kings 21:1; CUV 玛拿西
    17   Oholiah  -> Oholiab     Exodus 31:6 and 35:34 read "Aholiab";
                                 CUV 亚何利亚伯, which transliterates a
                                 final b. "Oholiah" is not a name.

The other three are ordinary English:

    157  Assasination -> Assassination
    186  Illneess     -> Illness
    57   Settler's    -> Settlers   (a possessive with no noun after it)

`Bezalel` in group 17 is deliberately NOT touched. The KJV spells him
Bezaleel and the audit flags the difference at one edit, but Bezalel is
the spelling every modern version uses; it is a translation convention,
not an error, and repairing it would be the tool overruling the editor.
The same reasoning protects Joash/Jehoash, Melchizedek/Melchisedec and
Pergamum/Pergamos elsewhere in the corpus.

Only the `en` titles change. No reference, no Chinese title and no verse
is touched: the audit checked all 48 proper names that the Chinese
titles could be tested on against the CUV's own spelling and found no
disagreement.

Idempotent: re-running reports "already correct".

    python3 tools/repair_ot_synopsis_titles.py [--dry-run]
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / 'assets' / 'ot_synopsis.json'

# group id -> (as imported, as repaired, why)
TITLES = {
    17: ('Bezalel and Oholiah', 'Bezalel and Oholiab',
         'Exodus 31:6 and 35:34, the group\'s own verses, read "Aholiab" '
         'and the CUV reads 亚何利亚伯; "Oholiah" is not a name'),
    27: ("Jepheth's Descendants", "Japheth's Descendants",
         '1 Chronicles 1:4 reads "Japheth" and the CUV reads 雅弗'),
    57: ("Settler's in Jerusalem after Exile",
         'Settlers in Jerusalem after Exile',
         'a possessive apostrophe followed by a preposition; the title '
         'names the settlers, it does not belong to one'),
    157: ("Athaliah's Assasination", "Athaliah's Assassination",
          'spelling'),
    165: ("Johoash's Death", "Jehoash's Death",
          '2 Kings 14:15-16, the group\'s own verses, read "Jehoash" '
          'twice and the CUV reads 约阿施'),
    186: ("Hezekiah's Illneess", "Hezekiah's Illness", 'spelling'),
    188: ("Manesseh's Reign", "Manasseh's Reign",
          '2 Chronicles 33:1 and 2 Kings 21:1 read "Manasseh" and the '
          'CUV reads 玛拿西'),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    data = json.loads(ASSET.read_text(encoding='utf-8'))
    groups = {g['id']: g for g in data['groups']}
    corrections = data.setdefault('corrections', [])
    already = {c.get('group') for c in corrections if c.get('field') == 'en'}

    changed, done, missing = 0, 0, []
    for gid, (before, after, why) in sorted(TITLES.items()):
        g = groups.get(gid)
        if g is None:
            missing.append(f'group {gid} is not in the asset')
            continue
        if g['en'] == after:
            done += 1
            if gid not in already:
                corrections.append({'group': gid, 'field': 'en',
                                    'from': before, 'why': why})
                changed += 1
            continue
        if g['en'] != before:
            missing.append(f'group {gid}: expected {before!r}, found {g["en"]!r}')
            continue
        print(f'  [{gid:>3}] {before!r} -> {after!r}')
        g['en'] = after
        corrections.append({'group': gid, 'field': 'en',
                            'from': before, 'why': why})
        changed += 1

    for line in missing:
        print('  !', line)
    if not changed:
        print(f'already correct ({done}/{len(TITLES)} titles)')
        return 1 if missing else 0

    corrections.sort(key=lambda c: (c['group'], c.get('field', '')))
    # The importer emits the groups sorted by English title, and two of
    # these titles change their first letter. Re-sorting keeps the asset
    # byte-reproducible from a re-import; the app indexes by book and
    # sorts by chapter, so the order in the file is not read.
    data['groups'].sort(key=lambda g: g['en'])
    if args.dry_run:
        print(f'{changed} titles would change (dry run)')
        return 0
    ASSET.write_text(json.dumps(data, ensure_ascii=False,
                                separators=(',', ':')) + '\n', encoding='utf-8')
    print(f'{changed} titles repaired, {len(corrections)} corrections recorded')
    print(f'written {ASSET}')
    return 1 if missing else 0


if __name__ == '__main__':
    raise SystemExit(main())
