#!/usr/bin/env python3
"""Eagle's View's OT Synopsis -> assets/ot_synopsis.json.

212 groups of Old Testament passages that tell the same thing twice or
more — Uzziah's reign in 2 Chronicles, 2 Kings and Isaiah; the Passover
in Exodus, Leviticus, Numbers and Deuteronomy.

SeekSparks already ships a gospel synopsis, which is the New Testament
half of this idea. This is the Old Testament half, and neither SeekSparks
nor BibleWorks had it: BibleWorks will show you parallel gospel passages
but ships no comparable OT harmony table.

The two source files carry different column ORDERS for the same data —
English is (Desc, Address, ID), Simplified is (ID, Desc, Address) — so
they are read by name, not position, and joined on ID.
"""
from __future__ import annotations
import csv, io, json, re, subprocess, sys
from pathlib import Path

EV = Path('/private/tmp/seeksparks-eaglesview.WWxd2D/msiextracted')
OUT = Path('assets/ot_synopsis.json')

# The abbreviations the Address column uses, to canonical English.
ABBR = {
 'Gen':'Genesis','Exo':'Exodus','Lev':'Leviticus','Num':'Numbers',
 'Deu':'Deuteronomy','Jos':'Joshua','Jdg':'Judges','Rut':'Ruth',
 '1Sa':'1 Samuel','2Sa':'2 Samuel','1Ki':'1 Kings','2Ki':'2 Kings',
 '1Ch':'1 Chronicles','2Ch':'2 Chronicles','Ezr':'Ezra','Neh':'Nehemiah',
 'Est':'Esther','Job':'Job','Psa':'Psalms','Pro':'Proverbs',
 'Ecc':'Ecclesiastes','Sng':'Song of Solomon','Son':'Song of Solomon',
 'Isa':'Isaiah','Jer':'Jeremiah','Lam':'Lamentations','Eze':'Ezekiel',
 'Dan':'Daniel','Hos':'Hosea','Joe':'Joel','Amo':'Amos','Oba':'Obadiah',
 'Jon':'Jonah','Mic':'Micah','Nah':'Nahum','Hab':'Habakkuk',
 'Zep':'Zephaniah','Hag':'Haggai','Zec':'Zechariah','Mal':'Malachi',
}
REF = re.compile(r'([1-3]?[A-Za-z]{2,3})\s+(\d+):(\d+)(?:-(\d+))?')

def export(db, table):
    out = subprocess.run(['mdb-export', str(db), table],
                         capture_output=True, text=True, check=True).stdout
    return list(csv.DictReader(io.StringIO(out)))

def refs(address):
    """'2Ch 26:3-15; 2Ki 15:1-4' -> structured, unknown books dropped."""
    out = []
    for m in REF.finditer(address or ''):
        book = ABBR.get(m.group(1))
        if not book:
            continue
        start = int(m.group(3))
        out.append({'book': book, 'chapter': int(m.group(2)),
                    'start': start, 'end': int(m.group(4) or start)})
    return out

def main():
    en = {r['ID']: r for r in export(EV / 'OT Synopsis.OT', 'Synopsis') if r.get('ID')}
    sc = {r['ID']: r for r in export(EV / 'OT Synopsis SC.OT', 'Synopsis') if r.get('ID')}

    groups, dropped = [], 0
    for gid, e in en.items():
        parsed = refs(e.get('Address'))
        # A group with fewer than two passages is not a parallel. 73 of
        # the 212 rows go this way and that was worth checking rather
        # than assuming: 72 are single-passage entries (1Ch 2:18-24 and
        # the rest of the Chronicles genealogy sections, which have no
        # parallel anywhere) and one is the "The OT Synopsis" heading row
        # with no address. All 72 parse correctly at one reference each —
        # they are not parse failures, they simply are not parallels, and
        # a synopsis of one passage is not a synopsis.
        if len(parsed) < 2:
            dropped += 1
            continue
        s = sc.get(gid, {})
        groups.append({
            'id': int(gid),
            'en': (e.get('Desc') or '').strip(),
            'zh': (s.get('Desc') or '').strip(),
            'refs': parsed,
        })
    groups.sort(key=lambda g: g['en'])

    payload = {
        'schemaVersion': 1,
        'source': "Eagle's View 2.0 / OT Synopsis",
        'attribution': "Old Testament parallel passages from Eagle's View "
                       '(eaglesviewsoftware.com). Used by permission.',
        'groups': groups,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False,
                              separators=(',', ':')) + '\n', encoding='utf-8')
    both = sum(1 for g in groups if g['zh'])
    print(f'groups     {len(groups)} kept, {dropped} dropped (<2 passages)')
    print(f'bilingual  {both}/{len(groups)} have a Chinese title')
    print(f'passages   {sum(len(g["refs"]) for g in groups)}')
    print(f'written    {OUT} ({OUT.stat().st_size/1000:.0f} KB)')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
