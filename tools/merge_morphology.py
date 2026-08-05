#!/usr/bin/env python3
"""Merge open-licensed morphology into SeekSparks' assets/originals/*.json.

Sources
  Greek NT  — MorphGNT / SBLGNT            (CC BY-SA 3.0)
  Hebrew OT — Open Scriptures Hebrew Bible  (CC BY 4.0)

Neither source is the same text edition as the Strong's-tagged originals
already shipped, so words are matched with a real sequence alignment over
accent-stripped forms rather than by position. Only words the alignment
proves equal get an `m` code; everything else is left untagged, which the
UI renders as "no parsing available" instead of a wrong parse.

The morph CODE is stored verbatim (e.g. `V-3AAI-S--`, `HVqp3ms`) and
decoded for display in lib/utils/morphology.dart, so the assets stay
small and the labels stay localisable.
"""
import json
import os
import re
import sys
import unicodedata
from difflib import SequenceMatcher
from xml.etree import ElementTree as ET

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(os.path.dirname(ROOT), 'assets', 'originals')

GNT_BOOKS = [
    ('61-Mt', 'matthew'), ('62-Mk', 'mark'), ('63-Lk', 'luke'),
    ('64-Jn', 'john'), ('65-Ac', 'acts'), ('66-Ro', 'romans'),
    ('67-1Co', '1_corinthians'), ('68-2Co', '2_corinthians'),
    ('69-Ga', 'galatians'), ('70-Eph', 'ephesians'),
    ('71-Php', 'philippians'), ('72-Col', 'colossians'),
    ('73-1Th', '1_thessalonians'), ('74-2Th', '2_thessalonians'),
    ('75-1Ti', '1_timothy'), ('76-2Ti', '2_timothy'), ('77-Tit', 'titus'),
    ('78-Phm', 'philemon'), ('79-Heb', 'hebrews'), ('80-Jas', 'james'),
    ('81-1Pe', '1_peter'), ('82-2Pe', '2_peter'), ('83-1Jn', '1_john'),
    ('84-2Jn', '2_john'), ('85-3Jn', '3_john'), ('86-Jud', 'jude'),
    ('87-Re', 'revelation'),
]

HB_BOOKS = [
    ('Gen', 'genesis'), ('Exod', 'exodus'), ('Lev', 'leviticus'),
    ('Num', 'numbers'), ('Deut', 'deuteronomy'), ('Josh', 'joshua'),
    ('Judg', 'judges'), ('Ruth', 'ruth'), ('1Sam', '1_samuel'),
    ('2Sam', '2_samuel'), ('1Kgs', '1_kings'), ('2Kgs', '2_kings'),
    ('1Chr', '1_chronicles'), ('2Chr', '2_chronicles'), ('Ezra', 'ezra'),
    ('Neh', 'nehemiah'), ('Esth', 'esther'), ('Job', 'job'),
    ('Ps', 'psalms'), ('Prov', 'proverbs'), ('Eccl', 'ecclesiastes'),
    ('Song', 'song_of_solomon'), ('Isa', 'isaiah'), ('Jer', 'jeremiah'),
    ('Lam', 'lamentations'), ('Ezek', 'ezekiel'), ('Dan', 'daniel'),
    ('Hos', 'hosea'), ('Joel', 'joel'), ('Amos', 'amos'),
    ('Obad', 'obadiah'), ('Jonah', 'jonah'), ('Mic', 'micah'),
    ('Nah', 'nahum'), ('Hab', 'habakkuk'), ('Zeph', 'zephaniah'),
    ('Hag', 'haggai'), ('Zech', 'zechariah'), ('Mal', 'malachi'),
]

_GK_PUNCT = re.compile(r'[^\w]', re.UNICODE)


def norm_greek(s):
    """Accent-insensitive, punctuation-free, lowercase key."""
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return _GK_PUNCT.sub('', s).lower()


def norm_hebrew(s):
    """Consonantal skeleton — drops pointing, cantillation and joiners."""
    s = s.replace('/', '').replace('־', '').replace('׀', '')
    s = unicodedata.normalize('NFD', s)
    return ''.join(c for c in s if not unicodedata.combining(c))


def align(asset_words, src_words, normalize):
    """Return {asset index -> source index} for provably equal words."""
    a = [normalize(w) for w in asset_words]
    b = [normalize(w) for w in src_words]
    out = {}
    for tag, i1, i2, j1, j2 in SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if tag != 'equal':
            continue
        for k in range(i2 - i1):
            out[i1 + k] = j1 + k
    return out


def load_gnt(path):
    """{(chapter, verse): [(word, morphcode)]} from a MorphGNT book file."""
    verses = {}
    with open(path, encoding='utf-8') as fh:
        for line in fh:
            parts = line.split()
            if len(parts) < 7:
                continue
            bcv = parts[0]
            key = (int(bcv[2:4]), int(bcv[4:6]))
            # parts[1] = POS (2 chars), parts[2] = parse (8 chars),
            # parts[4] = word without surrounding punctuation.
            verses.setdefault(key, []).append((parts[4], parts[1] + parts[2]))
    return verses


def load_hb(path):
    """{(chapter, verse): [(word, morphcode)]} from an OSHB WLC book file."""
    ns = {'o': 'http://www.bibletechnologies.net/2003/OSIS/namespace'}
    verses = {}
    tree = ET.parse(path)
    for v in tree.iter('{http://www.bibletechnologies.net/2003/OSIS/namespace}verse'):
        osis = v.get('osisID')
        if not osis:
            continue
        bits = osis.split('.')
        if len(bits) < 3:
            continue
        try:
            key = (int(bits[1]), int(bits[2]))
        except ValueError:
            continue
        words = []
        for w in v.findall('o:w', ns):
            text = ''.join(w.itertext())
            morph = w.get('morph') or ''
            if text.strip():
                words.append((text.strip(), morph))
        verses[key] = words
    return verses


def merge(asset_name, src_verses, normalize, stats):
    path = os.path.join(ASSETS, asset_name + '.json')
    if not os.path.exists(path):
        print('  ! missing asset', asset_name)
        return
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)

    tagged = total = 0
    for ref, words in data.items():
        try:
            ch, vs = (int(x) for x in ref.split(':'))
        except ValueError:
            continue
        total += len(words)
        src = src_verses.get((ch, vs))
        if not src:
            continue
        mapping = align([w.get('w', '') for w in words],
                        [s[0] for s in src], normalize)
        for ai, si in mapping.items():
            code = src[si][1]
            if code:
                words[ai]['m'] = code
                tagged += 1

    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))
    pct = (100.0 * tagged / total) if total else 0
    stats.append((asset_name, tagged, total, pct))
    print('  %-18s %6d / %6d words tagged (%.1f%%)' % (asset_name, tagged, total, pct))


def main():
    stats = []
    print('Greek NT (MorphGNT / SBLGNT, CC BY-SA 3.0)')
    for src, asset in GNT_BOOKS:
        p = os.path.join(ROOT, 'src', 'gnt', src + '-morphgnt.txt')
        if not os.path.exists(p):
            print('  ! missing source', src)
            continue
        merge(asset, load_gnt(p), norm_greek, stats)

    print('\nHebrew OT (Open Scriptures Hebrew Bible, CC BY 4.0)')
    for src, asset in HB_BOOKS:
        p = os.path.join(ROOT, 'src', 'hb', src + '.xml')
        if not os.path.exists(p):
            print('  ! missing source', src)
            continue
        merge(asset, load_hb(p), norm_hebrew, stats)

    t = sum(s[1] for s in stats)
    n = sum(s[2] for s in stats)
    print('\nTOTAL %d / %d words tagged (%.1f%%) across %d books'
          % (t, n, 100.0 * t / n if n else 0, len(stats)))
    worst = sorted(stats, key=lambda s: s[3])[:8]
    print('Lowest coverage:', ', '.join('%s %.0f%%' % (w[0], w[3]) for w in worst))


if __name__ == '__main__':
    sys.exit(main())
