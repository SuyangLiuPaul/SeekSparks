#!/usr/bin/env python3
"""Eagle's View's name dictionary and Thayer's lexicon -> assets/.

Two small reference sets that SeekSparks does not carry:

  BNames.dct  2,622 Bible proper names with their meanings — "Aaron: a
              teacher; lofty; mountain of strength". Hitchcock's Bible
              Names Dictionary (1869), public domain.
  Thayer.dct  5,913 entries of Thayer's Greek-English Lexicon (1889),
              public domain. BibleWorks ships Thayer too, so this one is
              a gap in SeekSparks rather than an edge over BibleWorks.

Both are public domain; supplied here via Eagle's View, credited as such.

BNames is plain text. Thayer is RTF-ish — `\\par` for breaks and the odd
brace group — so it gets unwrapped rather than shipped raw, which would
put literal backslash-par through the reader.
"""
from __future__ import annotations
import csv, io, json, re, subprocess
from pathlib import Path

EV = Path('/private/tmp/seeksparks-eaglesview.WWxd2D/msiextracted')

def export(db, table):
    out = subprocess.run(['mdb-export', str(db), table],
                         capture_output=True, text=True, check=True).stdout
    return list(csv.DictReader(io.StringIO(out)))

BRACE = re.compile(r'\{[^{}]*\}')
CTRL = re.compile(r'\\[a-z]+-?\d*\s?')

def unwrap(rtf: str) -> str:
    """RTF-ish -> plain paragraphs. Order matters: \\par becomes a break
    BEFORE the generic control-word strip, or it is swallowed with the
    rest and the whole entry collapses into one run-on line.

    Four of the 5,799 entries keep a stray brace afterwards (G251, G3765,
    G4434, G5342). Those are source typos — a group opened with `{` and
    closed with `]` or `)` — so no brace matcher can pair them. Left as
    they are rather than papered over with a blunt `{`-strip that would
    also eat legitimate braces elsewhere.

    Note on counts: an earlier survey put this table at 5,913 rows. That
    was a LINE count, and Thayer bodies contain embedded newlines. The
    real record count is 5,799, and all 5,799 are kept."""
    s = rtf.replace('\\par', '\n')
    prev = None
    while prev != s:                 # nested groups
        prev = s
        s = BRACE.sub('', s)
    s = CTRL.sub('', s)
    s = s.replace('\\', '')
    return re.sub(r'\n{3,}', '\n\n', s).strip()

def main():
    names = []
    for r in export(EV / 'BNames.dct', 'Dictionary'):
        topic = (r.get('Topic') or '').strip()
        meaning = (r.get('Definition') or '').strip()
        if topic and meaning:
            names.append({'n': topic, 'm': meaning})
    names.sort(key=lambda x: x['n'])
    Path('assets/bible_names.json').write_text(json.dumps({
        'schemaVersion': 1,
        'attribution': "Bible name meanings from Hitchcock's Bible Names "
                       "Dictionary (1869, public domain), supplied with "
                       "Eagle's View (eaglesviewsoftware.com).",
        'names': names,
    }, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')

    thayer = {}
    for r in export(EV / 'Thayer.dct', 'Dictionary'):
        key = (r.get('Topic') or '').strip()
        body = unwrap(r.get('Definition') or '')
        if key and body:
            thayer[key] = body
    Path('assets/thayer.json').write_text(json.dumps({
        'schemaVersion': 1,
        'attribution': "Thayer's Greek-English Lexicon of the New Testament "
                       '(1889, public domain), supplied with Eagle\'s View '
                       '(eaglesviewsoftware.com).',
        'entries': thayer,
    }, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')

    print(f'names   {len(names)}  -> assets/bible_names.json '
          f'({Path("assets/bible_names.json").stat().st_size/1000:.0f} KB)')
    print(f'thayer  {len(thayer)} -> assets/thayer.json '
          f'({Path("assets/thayer.json").stat().st_size/1e6:.1f} MB)')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
