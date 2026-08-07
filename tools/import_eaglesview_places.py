#!/usr/bin/env python3
"""Eagle's View's Bible Places -> assets/bible_places.json.

The last Eagle's View module. 1,276 places, each with a name in English,
Simplified AND Traditional Chinese, a latitude and longitude, and the
verses that mention it.

This is the one BibleWorks has no answer to. BibleWorks ships maps; it
does not ship a gazetteer with Chinese place names, which for a bilingual
audience is the difference between a map you can read and one you cannot.
SeekSparks' existing assets/maps_index.json is 1,192 map IMAGES — a
different thing entirely, so these complement rather than duplicate.

The Definition column holds the verse list as RTF link runs:
    {\\cf11\\ul Exo_17:8}, {\\cf11\\ul Exo_17:9}, ...
so references are pulled from inside the groups rather than by stripping
the markup and re-parsing prose.

Coordinates are strings in the source and some are absent or 0/0 — a
place at 0°N 0°E is in the Atlantic, not the Levant, so those are carried
without coordinates rather than plotted wrongly.
"""
from __future__ import annotations
import csv, io, json, re, subprocess
from pathlib import Path

EV = Path('/private/tmp/seeksparks-eaglesview.WWxd2D/msiextracted')
OUT = Path('assets/bible_places.json')

# "Exo_17:8" inside an RTF group. The book part is the concordance's own
# 3-letter abbreviation; kept as-is here and resolved by the app, which
# already owns book-name mapping.
REF = re.compile(r'\{[^}]*?\b([1-3]?[A-Za-z]{2,3})_(\d+):(\d+)[^}]*?\}')

def export(db, table):
    out = subprocess.run(['mdb-export', str(db), table],
                         capture_output=True, text=True, check=True).stdout
    return list(csv.DictReader(io.StringIO(out)))

def coord(v):
    if v is None:
        return None
    v = str(v).strip()
    if not v or v.upper() == 'NULL':
        return None
    try:
        f = float(v)
    except ValueError:
        return None
    return f

def main():
    rows = export(EV / 'BPlaces.dct', 'Dictionary')
    places, located, with_refs, nullisland = [], 0, 0, 0
    for r in rows:
        name = (r.get('Topic') or '').strip()
        if not name:
            continue
        lat, lon = coord(r.get('Lat')), coord(r.get('Lon'))
        # 0/0 is the Atlantic, not a Bible place. Treat as "unknown"
        # rather than plotting every one of them on the same wrong spot.
        if lat == 0 and lon == 0:
            lat = lon = None
            nullisland += 1
        refs = [{'book': m.group(1), 'chapter': int(m.group(2)),
                 'verse': int(m.group(3))}
                for m in REF.finditer(r.get('Definition') or '')]
        # Same verse can be linked twice in one entry; dedupe, keep order.
        seen, uniq = set(), []
        for x in refs:
            k = (x['book'], x['chapter'], x['verse'])
            if k not in seen:
                seen.add(k)
                uniq.append(x)
        entry = {'n': name}
        zhs = (r.get('Topic_Chs') or '').strip()
        zht = (r.get('Topic_Cht') or '').strip()
        if zhs and zhs.upper() != 'NULL':
            entry['s'] = zhs
        if zht and zht.upper() != 'NULL':
            entry['t'] = zht
        if lat is not None and lon is not None:
            entry['ll'] = [lat, lon]
            located += 1
        if uniq:
            entry['refs'] = uniq
            with_refs += 1
        places.append(entry)

    places.sort(key=lambda p: p['n'])
    OUT.write_text(json.dumps({
        'schemaVersion': 1,
        'attribution': "Bible places, coordinates and Chinese names from "
                       "Eagle's View (eaglesviewsoftware.com). "
                       'Used by permission.',
        'places': places,
    }, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')

    both = sum(1 for p in places if 's' in p and 't' in p)
    print(f'places     {len(places)}')
    print(f'located    {located} have coordinates '
          f'({nullisland} were 0/0 and are carried without)')
    print(f'trilingual {both} have both 简 and 繁')
    print(f'with refs  {with_refs} cite at least one verse '
          f'({sum(len(p.get("refs", [])) for p in places)} citations)')
    print(f'written    {OUT} ({OUT.stat().st_size/1000:.0f} KB)')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
