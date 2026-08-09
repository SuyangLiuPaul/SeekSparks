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

Two orthographic differences are NOT textual differences and are matched
anyway, because leaving them blank puts an inexplicable gap under an
ordinary word:

  * Hebrew Ketiv/Qere. OSHB writes the Ketiv as the verse's direct <w>
    and hangs the Qere off a following <note><rdg type="x-qere">, which
    a direct-children read never sees. The shipped originals carry the
    Qere, so the two disagree on 1,244 slots — and on 653 of them the
    Qere's own parse differs from the Ketiv's, so borrowing the Ketiv's
    code would have printed a wrong parse, not merely a different one.
    Both readings are tried, Qere first.

  * Greek movable nu. ἀπέχουσι/ἀπέχουσιν is one word with one parse.
    The environment test in `movable_nu_equal` is load-bearing rather
    than decorative: Luke 23:42's τῇ/τὴν and βασιλείᾳ/βασιλείαν also
    differ by a final nu and are a real dative/accusative variant.

What is left untagged after that is genuine divergence between editions —
the shipped Greek is a received-text edition and SBLGNT is a critical
one, so its αὐτῷ at Matthew 3:16 has no counterpart to take a parse
from. Do NOT close that gap by reusing the same surface form found
elsewhere in the verse: SBLGNT's only τοῦ at Matthew 3:16 is the neuter
of ἀπὸ τοῦ ὕδατος, and the received text's second τοῦ is the masculine
of τοῦ Θεοῦ. That fallback is plausible and prints the wrong gender.

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


_MOVABLE_NU_ENVIRONMENTS = ('σι', 'ε', 'τι')


def movable_nu_equal(short, long_, code):
    """True when two accent-stripped Greek forms are one word spelled with
    and without the euphonic nu.

    Both tests are needed. The environment test rejects τῇ/τὴν, a real
    dative/accusative variant that happens to differ by a final nu. The
    part-of-speech test rejects οὐδέ/οὐδέν, which passes the environment
    test and is two different words: the nu on -ε is the 3rd singular
    verb ending, and on -σι it is the 3rd plural or a dative plural.
    """
    if long_ != short + 'ν' or not short.endswith(_MOVABLE_NU_ENVIRONMENTS):
        return False
    if code.startswith('V-'):
        return True
    # MorphGNT parse slots: case at index 6, number at index 7.
    return (short.endswith('σι') and len(code) > 7
            and code[6] == 'D' and code[7] == 'P')


def align(asset_words, src_words, normalize, variant_equal=None):
    """Return {asset index -> source index} for provably equal words.

    [variant_equal] salvages same-length `replace` runs whose members are
    the same word spelled two ways. It is only consulted position-wise
    inside such a run, so it can never pair words the sequence alignment
    did not already put opposite one another.
    """
    a = [normalize(w) for w in asset_words]
    b = [normalize(w) for w in src_words]
    out = {}
    for tag, i1, i2, j1, j2 in SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if tag == 'equal':
            for k in range(i2 - i1):
                out[i1 + k] = j1 + k
        elif (tag == 'replace' and variant_equal is not None
                and (i2 - i1) == (j2 - j1)):
            for k in range(i2 - i1):
                if variant_equal(a[i1 + k], b[j1 + k], j1 + k):
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


_OSIS = '{http://www.bibletechnologies.net/2003/OSIS/namespace}'


def _qere_for(siblings, i):
    """The Qere words replacing the Ketiv at [i], or None if there is no
    Qere. A Qere of zero words is "written but not read" and returns []."""
    nxt = siblings[i + 1] if i + 1 < len(siblings) else None
    if nxt is None or nxt.tag != _OSIS + 'note':
        return None
    for rdg in nxt.findall(_OSIS + 'rdg'):
        if rdg.get('type') != 'x-qere':
            continue
        return [(''.join(w.itertext()).strip(), w.get('morph') or '')
                for w in rdg.findall(_OSIS + 'w')]
    return None


def load_hb(path, reading='qere'):
    """{(chapter, verse): [(word, morphcode)]} from an OSHB WLC book file.

    [reading] picks which side of a Ketiv/Qere slot is emitted, and under
    'qere' also inserts the ten Qere-without-Ketiv words — read by the
    Masoretes but absent from the consonantal text, so they appear in the
    shipped edition with no <w> of their own to align against. The other
    editorial notes are BHS commentary and accent variants, never
    alternative words, so they are ignored.
    """
    verses = {}
    tree = ET.parse(path)
    for v in tree.iter(_OSIS + 'verse'):
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
        children = list(v)
        for i, el in enumerate(children):
            prev = children[i - 1] if i else None
            after_ketiv = (prev is not None and prev.tag == _OSIS + 'w'
                           and prev.get('type') == 'x-ketiv')
            if el.tag == _OSIS + 'note':
                if reading != 'qere' or after_ketiv:
                    continue
                slot = _qere_for(children, i - 1) or []
            elif el.tag == _OSIS + 'w':
                slot = [(''.join(el.itertext()).strip(), el.get('morph') or '')]
                if reading == 'qere' and el.get('type') == 'x-ketiv':
                    qere = _qere_for(children, i)
                    if qere is not None:
                        slot = qere
            else:
                continue
            words.extend((t, m) for t, m in slot if t)
        verses[key] = words
    return verses


def merge(asset_name, readings, normalize, stats, variant_equal=None):
    """Tag one book from [readings], an ordered list of source verse maps.

    The first reading is authoritative; later ones only fill words it
    could not prove. A code that disagrees with one already in the asset
    is reported rather than written silently — that is the signal that a
    change to this script moved an existing parse, which matters far more
    than the count of new ones.
    """
    path = os.path.join(ASSETS, asset_name + '.json')
    if not os.path.exists(path):
        print('  ! missing asset', asset_name)
        return
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)

    tagged = total = added = changed = 0
    for ref, words in data.items():
        try:
            ch, vs = (int(x) for x in ref.split(':'))
        except ValueError:
            continue
        total += len(words)
        for rank, src_verses in enumerate(readings):
            src = src_verses.get((ch, vs))
            if not src:
                continue
            eq = None
            if variant_equal is not None:
                eq = lambda x, y, j, s=src: variant_equal(x, y, s[j][1])
            mapping = align([w.get('w', '') for w in words],
                            [s[0] for s in src], normalize, eq)
            for ai, si in mapping.items():
                code = src[si][1]
                old = words[ai].get('m')
                if not code or old == code:
                    continue
                if old is not None:
                    if rank:
                        continue
                    changed += 1
                    print('    ~ %s %s word %d: %s -> %s'
                          % (asset_name, ref, ai, old, code))
                else:
                    added += 1
                words[ai]['m'] = code

    for words in data.values():
        tagged += sum(1 for w in words if w.get('m'))

    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))
    pct = (100.0 * tagged / total) if total else 0
    stats.append((asset_name, tagged, total, pct, added, changed))
    print('  %-18s %6d / %6d words tagged (%.1f%%)  +%d new'
          % (asset_name, tagged, total, pct, added))


def main():
    stats = []
    print('Greek NT (MorphGNT / SBLGNT, CC BY-SA 3.0)')
    for src, asset in GNT_BOOKS:
        p = os.path.join(ROOT, 'src', 'gnt', src + '-morphgnt.txt')
        if not os.path.exists(p):
            print('  ! missing source', src)
            continue
        merge(asset, [load_gnt(p)], norm_greek, stats,
              variant_equal=lambda x, y, code: movable_nu_equal(
                  *sorted((x, y), key=len), code))

    print('\nHebrew OT (Open Scriptures Hebrew Bible, CC BY 4.0)')
    for src, asset in HB_BOOKS:
        p = os.path.join(ROOT, 'src', 'hb', src + '.xml')
        if not os.path.exists(p):
            print('  ! missing source', src)
            continue
        merge(asset, [load_hb(p, 'qere'), load_hb(p, 'ketiv')],
              norm_hebrew, stats)

    t = sum(s[1] for s in stats)
    n = sum(s[2] for s in stats)
    print('\nTOTAL %d / %d words tagged (%.1f%%) across %d books'
          % (t, n, 100.0 * t / n if n else 0, len(stats)))
    print('%d newly tagged, %d existing parses changed, %d still untagged'
          % (sum(s[4] for s in stats), sum(s[5] for s in stats), n - t))
    worst = sorted(stats, key=lambda s: s[3])[:8]
    print('Lowest coverage:', ', '.join('%s %.0f%%' % (w[0], w[3]) for w in worst))


if __name__ == '__main__':
    sys.exit(main())
