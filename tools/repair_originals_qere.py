#!/usr/bin/env python3
"""Mark the Ketiv and the Qere in `assets/originals/*.json`.

WHAT WAS WRONG
--------------
`tools/build_originals.py` reads the Westminster Leningrad Codex from
openscriptures/morphhb with

    for w in verse.iter(f'{NS_OSIS}w'):

`iter` is a *descendant* walk, and the WLC puts the Qere inside a note:

    <w type="x-ketiv" lemma="5921 b" morph="HR">על</w>
    <note type="variant">
      <catchWord>על</catchWord>
      <rdg type="x-qere">
        <w lemma="5921 b" morph="HR">עַל</w>
        <w lemma="3651 b" morph="HTm">כֵּן</w>
      </rdg>
    </note>

So the marginal reading was pulled out of the apparatus and printed as
running text, immediately after the written one. 2 Samuel 18:20 shipped
as `כי על על כן`; Genesis 30:11 as `בגד בא גד`, three words where the
text has one written and two read; Genesis 24:33 opens on the doubled
pair. 1,103 verses, 1,220 sites, and no manuscript reads any of them
that way.

WHAT THIS SCRIPT DOES, AND WHAT IT REFUSES TO DO
------------------------------------------------
It adds one field, `kq`, valued `"k"` (Ketiv, what is written) or `"q"`
(Qere, what the Masoretes direct be read). **It deletes nothing.**
Removing a word from shipped scripture is a text-editorial decision and
is not one an unattended run may take; it is also not what the reference
implementation does — BibleWorks keeps both readings in the WTT stream
and ends every WTM morphology code with `Rq`/`Rk`/`Rx`, so the *reader*
chooses (help topic bwh17, bwh43d). Marking is the conservative repair
and it is the one that makes every other decision available later.

THE JOIN, PROVEN BEFORE IT WAS TRUSTED
--------------------------------------
The role cannot be read off the shipped asset — a Qere is an ordinary
pointed word — so it comes from the WLC, and the join has to be exact or
it would mislabel scripture. It is: rebuilding the importer's own filter
(a `<w>` is kept iff `_hebrew_strongs(lemma)` is non-empty) reproduces
the shipped word sequence in **23,213 of 23,213 verses**, word for word.
Two independent counts agree with that alignment: the WLC marks 1,268
Ketiv words and every one of them is unpointed, while the shipped asset
holds exactly 1,257 unpointed Hebrew words in 300,808 — the 11 missing
are Ketiv forms whose lemma carries no Strong's number, which the
importer drops for every word, not only these.

Idempotent: re-running rewrites the same bytes. Verified round-trip —
a book with no Ketiv is written back byte-for-byte identical.

    python3 tools/repair_originals_qere.py --check   # report, write nothing
    python3 tools/repair_originals_qere.py --write
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import sys
import urllib.request
from xml.etree import ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGINALS_DIR = os.path.join(REPO_ROOT, 'assets', 'originals')
CACHE_DIR = os.path.join(REPO_ROOT, '.cache', 'wlc')

NS_OSIS = '{http://www.bibletechnologies.net/2003/OSIS/namespace}'
WLC_URL = (
    'https://raw.githubusercontent.com/openscriptures/morphhb/master/'
    'wlc/{osis}.xml'
)

def _load_build_originals():
    """The generator, imported rather than restated. The book table and
    the apparatus walk both live there; a second copy here is exactly
    the drift this script exists to prove absent."""
    path = os.path.join(REPO_ROOT, 'tools', 'build_originals.py')
    spec = importlib.util.spec_from_file_location('build_originals', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


build_originals = _load_build_originals()


def osis_books() -> list[tuple[str, str]]:
    return list(build_originals.OSIS_HEBREW)


def slug(english: str) -> str:
    return english.lower().replace(' ', '_').replace("'", '')


def fetch(osis: str) -> bytes:
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, f'{osis}.xml')
    if os.path.exists(path):
        return open(path, 'rb').read()
    req = urllib.request.Request(
        WLC_URL.format(osis=osis),
        headers={'User-Agent': 'SeekSparks originals repair'})
    with urllib.request.urlopen(req) as r:
        raw = r.read()
    open(path, 'wb').write(raw)
    return raw


def wlc_verse_roles(osis: str) -> dict[str, list[tuple[str, str]]]:
    """`{"1:1": [(role, surface), ...]}` for one book, in document order,
    filtered exactly as the importer filters — because it IS the
    importer. `build_originals.wlc_verse_words` is called, not copied:
    a second hand-kept copy of the apparatus walk is how the generator
    comes to disagree with the asset it is supposed to reproduce."""
    root = ET.fromstring(fetch(osis))
    out: dict[str, list[tuple[str, str]]] = {}
    for verse in root.iter(f'{NS_OSIS}verse'):
        osis_id = verse.get('osisID')
        if not osis_id:
            continue
        m = re.match(r'^[^.]+\.(\d+)\.(\d+)$', osis_id)
        if not m:
            continue
        seq = [(w.get('kq', ''), w['w']) for w in build_originals.wlc_verse_words(verse)]
        if seq:
            out[f'{int(m.group(1))}:{int(m.group(2))}'] = seq
    return out


def dump(book: dict) -> str:
    """The shipped serialisation: compact, no spaces, insertion order."""
    return json.dumps(book, ensure_ascii=False, separators=(',', ':'))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    if not (args.write or args.check):
        ap.error('pass --check or --write')

    totals: dict[str, int] = {'k': 0, 'q': 0, 'kx': 0, 'qx': 0}
    verses_touched = 0
    misaligned: list[str] = []
    changed_files = 0

    for osis, english in osis_books():
        path = os.path.join(ORIGINALS_DIR, f'{slug(english)}.json')
        if not os.path.exists(path):
            misaligned.append(f'{english}: no asset')
            continue
        original_bytes = open(path, 'rb').read()
        data = json.loads(original_bytes.decode('utf-8'))
        roles = wlc_verse_roles(osis)
        book: dict[str, int] = {'k': 0, 'q': 0, 'kx': 0, 'qx': 0}
        for key, words in data.items():
            seq = roles.get(key)
            if seq is None:
                misaligned.append(f'{english} {key}: absent from WLC')
                continue
            if len(seq) != len(words) or any(
                    w['w'] != t for w, (_, t) in zip(words, seq)):
                # Refuse to guess. A misaligned verse keeps whatever it
                # has; a wrong Ketiv mark would be a false claim about
                # the text, which is worse than an unmarked one.
                misaligned.append(
                    f'{english} {key}: {len(words)} words vs WLC {len(seq)}')
                continue
            marked = False
            for i, (word, (role, _)) in enumerate(zip(words, seq)):
                if role:
                    marked = True
                    book[role] += 1
                # Rebuild rather than assign, so `kq` lands where the
                # fixed `build_originals.py` puts it — directly after
                # `s`, before the morphology `merge_morphology.py`
                # appends. Insertion order is what json.dumps writes,
                # and a generator whose output no longer diffs clean
                # against its own asset cannot be used to check it.
                rebuilt = {'w': word['w'], 's': word['s']}
                if role:
                    rebuilt['kq'] = role
                for k, v in word.items():
                    if k not in ('w', 's', 'kq'):
                        rebuilt[k] = v
                words[i] = rebuilt
            if marked:
                verses_touched += 1
        for role, n in book.items():
            totals[role] += n
        rewritten = dump(data).encode('utf-8')
        if rewritten != original_bytes:
            changed_files += 1
            if args.write:
                open(path, 'wb').write(rewritten)
        print(f'  {english:<16} ketiv {book["k"]:>4}  qere {book["q"]:>4}'
              f'  ketiv-only {book["kx"]:>2}  qere-only {book["qx"]:>2}'
              f'{"  (rewritten)" if rewritten != original_bytes else ""}')

    print()
    print(f'verses carrying a Ketiv/Qere: {verses_touched}')
    print(f'k  Ketiv, with a Qere:          {totals["k"]}')
    print(f'q  Qere,  with a Ketiv:         {totals["q"]}')
    print(f'kx Ketiv velo Qere (not read):  {totals["kx"]}')
    print(f'qx Qere velo Ketiv (not written): {totals["qx"]}')
    print(f'files {"rewritten" if args.write else "that would change"}: '
          f'{changed_files}')
    if misaligned:
        print(f'\nMISALIGNED, left untouched: {len(misaligned)}')
        for line in misaligned[:40]:
            print('  ', line)
        return 1
    print('alignment: every verse matched the WLC word for word')
    return 0


if __name__ == '__main__':
    sys.exit(main())
