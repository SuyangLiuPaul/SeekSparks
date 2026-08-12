#!/usr/bin/env python3
r"""Eagle's View's OT Synopsis -> assets/ot_synopsis.json.

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

2026-08-12 (schema 2, check 25). The first version of this importer read
a reference with `(\d+):(\d+)(?:-(\d+))?`, which cannot express a range
that crosses a chapter boundary. The source has **16 of them**, and each
one was silently truncated: `2Ki 23:35-24:7` became "2 Kings 23:35-24",
a range whose end verse precedes its start. Seven such references named
a verse that does not exist; five more truncated into a range that
resolves and is simply wrong — `2Ki 4:1-8:15`, five chapters of Elisha,
became eight verses. `endChapter` now carries the second chapter and the
regex reads the trailing `:verse` that used to be dropped on the floor.

Two source values are corrected here rather than copied, each with its
reason recorded in the asset's `corrections` block. Nothing else in the
source is second-guessed.

The source is the Eagle's View 2.0 installer. Re-extract it with:

    unzip EV_2_0_Setup_EN.zip && unzip EVSetup_EN_2_0.zip
    msiextract setup.msi          # gives 'OT Synopsis.OT' + '... SC.OT'

and point --source at the directory that lands in. The default below is
a scratch path and will not survive a reboot.
"""
from __future__ import annotations
import argparse, csv, io, json, re, subprocess, sys
from pathlib import Path

EV = Path('/tmp/evsrc/ext')
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
# A reference token. The optional `(\d+):` before the end verse is the
# whole point: without it a cross-chapter range loses its end verse and
# the end CHAPTER is written into the asset as though it were a verse.
REF = re.compile(r'([1-3]?[A-Za-z]{2,3})\s+(\d+):(\d+)(?:-(?:(\d+):)?(\d+))?')

# Two source values that are corrected rather than copied. Both are
# recorded in the asset so a reader of the data can see that we differ
# from Eagle's View here and why.
CORRECTIONS = {
    # The source files this under 2 Chronicles, whose chapter 1 ends at
    # verse 17, so the reference cannot be read at all. 1 Chronicles
    # 1:32-33 is the passage meant: it names Keturah, Zimran, Jokshan,
    # Medan, Midian, Ishbak and Shuah, which is the group's other
    # passage (Genesis 25:1-4) almost word for word. Checked against
    # assets/kjv.json, not assumed.
    ('30', '2 Chronicles', 1, 32): {
        'book': '1 Chronicles',
        'why': "source reads '2Ch 1:32-33'; 2 Chronicles 1 has 17 verses "
               'and 1 Chronicles 1:32-33 is the Keturah genealogy that '
               "parallels this group's Genesis 25:1-4",
    },
    # 'Psa 18:0-50' — verse 0 is the superscription, which the Hebrew
    # numbers as verse 1 and every edition we ship folds into the
    # heading. Starting at 1 under-claims by a line rather than printing
    # a verse number no edition has.
    ('207', 'Psalms', 18, 0): {
        'start': 1,
        'why': "source reads 'Psa 18:0-50'; verse 0 is the "
               'superscription, which no shipped edition numbers',
    },
}

# 2026-08-12 (check 35). Seven English titles the source misspells,
# each contradicted by the passage the group itself points at. See
# tools/repair_ot_synopsis_titles.py, which holds the evidence for each
# and applies the same seven to the shipped asset; they are duplicated
# here so a re-import from the source does not undo the repair.
# `Bezalel` (group 17) is a modern-spelling convention against the KJV's
# `Bezaleel` and is deliberately left alone.
TITLE_CORRECTIONS = {
    '17': ('Bezalel and Oholiah', 'Bezalel and Oholiab'),
    '27': ("Jepheth's Descendants", "Japheth's Descendants"),
    '57': ("Settler's in Jerusalem after Exile",
           'Settlers in Jerusalem after Exile'),
    '157': ("Athaliah's Assasination", "Athaliah's Assassination"),
    '165': ("Johoash's Death", "Jehoash's Death"),
    '186': ("Hezekiah's Illneess", "Hezekiah's Illness"),
    '188': ("Manesseh's Reign", "Manasseh's Reign"),
}

def export(db, table):
    out = subprocess.run(['mdb-export', str(db), table],
                         capture_output=True, text=True, check=True).stdout
    return list(csv.DictReader(io.StringIO(out)))

def refs(address, gid, applied):
    """'2Ch 26:3-15; 2Ki 15:1-4' -> structured, unknown books dropped.

    `endChapter` is emitted only when the range crosses a chapter, so
    the common case keeps the schema-1 shape and a reader of the JSON
    can see at a glance which passages span chapters.
    """
    out = []
    for m in REF.finditer(address or ''):
        book = ABBR.get(m.group(1))
        if not book:
            continue
        chapter, start = int(m.group(2)), int(m.group(3))
        end_chapter = int(m.group(4)) if m.group(4) else chapter
        end = int(m.group(5)) if m.group(5) else start

        fix = CORRECTIONS.get((gid, book, chapter, start))
        if fix:
            applied.append({'group': int(gid), 'from': m.group(0),
                            'why': fix['why']})
            book = fix.get('book', book)
            start = fix.get('start', start)

        ref = {'book': book, 'chapter': chapter, 'start': start, 'end': end}
        if end_chapter != chapter:
            ref['endChapter'] = end_chapter
        out.append(ref)
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', type=Path, default=EV,
                    help='directory holding the extracted .OT databases')
    src = ap.parse_args().source

    en = {r['ID']: r for r in export(src / 'OT Synopsis.OT', 'Synopsis') if r.get('ID')}
    sc = {r['ID']: r for r in export(src / 'OT Synopsis SC.OT', 'Synopsis') if r.get('ID')}

    groups, dropped, applied = [], 0, []
    for gid, e in en.items():
        parsed = refs(e.get('Address'), gid, applied)
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
        en_title = (e.get('Desc') or '').strip()
        fix = TITLE_CORRECTIONS.get(gid)
        if fix and en_title == fix[0]:
            applied.append({'group': int(gid), 'field': 'en', 'from': fix[0],
                            'why': 'see tools/repair_ot_synopsis_titles.py'})
            en_title = fix[1]
        groups.append({
            'id': int(gid),
            'en': en_title,
            'zh': (s.get('Desc') or '').strip(),
            'refs': parsed,
        })
    groups.sort(key=lambda g: g['en'])

    payload = {
        'schemaVersion': 2,
        'source': "Eagle's View 2.0 / OT Synopsis",
        'attribution': "Old Testament parallel passages from Eagle's View "
                       '(eaglesviewsoftware.com). Used by permission.',
        # Where we knowingly differ from the source. Two entries; see
        # CORRECTIONS in tools/import_eaglesview_ot_synopsis.py.
        'corrections': applied,
        'groups': groups,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False,
                              separators=(',', ':')) + '\n', encoding='utf-8')
    both = sum(1 for g in groups if g['zh'])
    spans = sum(1 for g in groups for r in g['refs'] if 'endChapter' in r)
    print(f'groups     {len(groups)} kept, {dropped} dropped (<2 passages)')
    print(f'bilingual  {both}/{len(groups)} have a Chinese title')
    print(f'passages   {sum(len(g["refs"]) for g in groups)}')
    print(f'spans      {spans} cross a chapter boundary')
    print(f'corrected  {len(applied)} source values')
    print(f'written    {OUT} ({OUT.stat().st_size/1000:.0f} KB)')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
