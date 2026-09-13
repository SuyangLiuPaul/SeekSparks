#!/usr/bin/env python3
"""Build the Hebrew Old Testament asset from the Open Scriptures WLC.

WHY. The originals row offered Greek (`lxxwh`) and no Hebrew, so a
reader who wanted the Old Testament in its own language had a Septuagint
— a translation — and nothing else. 「希伯来」 was the missing half of a
pair the app already advertised.

WHAT IS BEING REDISTRIBUTED, and under what. The OSIS files say it
themselves, in every file's header:

    <rights>Public Domain</rights>               the WLC text
    <rights>Creative Commons Attribution 4.0</rights>   lemma + morphology

So the consonantal/pointed text is public domain, and the tagging data
that travels with it is CC BY 4.0 — which is why `bibleVersions`' row
for this edition carries the attribution the licence asks for. Nothing
here needs a publisher's permission, which is the whole reason this
edition is possible and NIV's was not (see the note in
`bible_versions.dart`).

Source: https://github.com/openscriptures/morphhb — `wlc/<Book>.xml`,
39 OSIS files. Fetch them into a directory and point this script at it.

    python3 tools/import_wlc.py /tmp/wlc          # writes assets/wlc.json

THE TEXT, AND THE THREE THINGS THAT MAKE IT READABLE.

  * `<w>` holds ONE word, with morpheme boundaries marked by `/`:
    `וַ/יְהִ֗י` is the conjunction plus the verb. The slash is markup,
    not orthography — no Hebrew Bible prints it — so it is stripped.
    The lemma attribute keeps its own slashes; we do not read it here.

  * `<seg>` carries the punctuation, and each type joins differently:
    maqqef (־) is a hyphen that binds two words with NO space around
    it; sof pasuq (׃) ends the verse and hugs the last word; paseq (׀)
    is a separator that takes a space. Getting these wrong is not a
    cosmetic fault — a maqqef with spaces reads as two words where the
    text has one.

  * `<note>` is apparatus (ketiv/qere and the like), not text, and is
    dropped. A note rendered inline would be read as scripture.

Book names and the `id` follow `assets/lxxwh.json` exactly — English
canonical names and a `BBBCCCVVV` string keyed on `standardBookOrder` —
because every consumer in the app already keys on those.
"""
import json
import os
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET

# OSIS book code → the English name this app uses, in canonical order.
BOOKS = [
    ('Gen', 'Genesis'), ('Exod', 'Exodus'), ('Lev', 'Leviticus'),
    ('Num', 'Numbers'), ('Deut', 'Deuteronomy'), ('Josh', 'Joshua'),
    ('Judg', 'Judges'), ('Ruth', 'Ruth'), ('1Sam', '1 Samuel'),
    ('2Sam', '2 Samuel'), ('1Kgs', '1 Kings'), ('2Kgs', '2 Kings'),
    ('1Chr', '1 Chronicles'), ('2Chr', '2 Chronicles'), ('Ezra', 'Ezra'),
    ('Neh', 'Nehemiah'), ('Esth', 'Esther'), ('Job', 'Job'),
    ('Ps', 'Psalms'), ('Prov', 'Proverbs'), ('Eccl', 'Ecclesiastes'),
    ('Song', 'Song of Solomon'), ('Isa', 'Isaiah'), ('Jer', 'Jeremiah'),
    ('Lam', 'Lamentations'), ('Ezek', 'Ezekiel'), ('Dan', 'Daniel'),
    ('Hos', 'Hosea'), ('Joel', 'Joel'), ('Amos', 'Amos'),
    ('Obad', 'Obadiah'), ('Jonah', 'Jonah'), ('Mic', 'Micah'),
    ('Nah', 'Nahum'), ('Hab', 'Habakkuk'), ('Zeph', 'Zephaniah'),
    ('Hag', 'Haggai'), ('Zech', 'Zechariah'), ('Mal', 'Malachi'),
]
ORDER = {code: i + 1 for i, (code, _) in enumerate(BOOKS)}
NS = {'o': 'http://www.bibletechnologies.net/2003/OSIS/namespace'}

# Joined with no space on either side; the rest take one before them.
TIGHT = {'x-maqqef', 'x-sof-pasuq'}

# Paragraph marks, not words: ס closes a paragraph, פ opens one, and ׆
# is the inverted nun that brackets Numbers 10:35-36. A reader who met
# one in the running text would see a stray Hebrew letter at the end of
# a verse — 3,171 of them across the corpus — and no printed Hebrew
# Bible sets them as part of the sentence. Dropped for the same reason
# `verse_popup_sheet.dart` drops a 見上節 line: an edition's typesetting
# instruction is not scripture, and quoting one as if it were is worse
# than losing the mark. Paragraph structure itself is the app's own, out
# of `assets/web-ot-paragraphs.json`.
STRUCTURAL = {'x-samekh', 'x-pe', 'x-reversednun'}


def verse_text(verse: ET.Element) -> str:
    """The printed Hebrew of one verse.

    Walks in document order, because the separators only mean anything
    in sequence. `pieces` holds (text, tight) pairs; `tight` means "no
    space before this one".
    """
    pieces: list[tuple[str, bool]] = []
    # DIRECT children only. A descendant walk double-counts the eleven
    # large letters — Deuteronomy 6:4's ע and ד among them — because
    # each is a `<seg type="x-large">` NESTED INSIDE its `<w>`: the
    # word's own itertext already contains it, and a second visit
    # appended it again as a separate piece. The Shema came out as
    # `שְׁמַ֖ע ע יִשְׂרָאֵ֑ל`, which is not a spacing fault but a
    # different text. Direct children also skip `<note>` outright,
    # apparatus being apparatus.
    for el in verse:
        tag = el.tag.split('}')[-1]
        if tag == 'w':
            word = ''.join(el.itertext())
            # The morpheme divider is markup. No Hebrew Bible prints it.
            word = word.replace('/', '').strip()
            if word:
                pieces.append((word, False))
        elif tag == 'seg':
            kind = el.get('type')
            if kind in STRUCTURAL:
                continue
            seg = (el.text or '').strip()
            if seg:
                pieces.append((seg, kind in TIGHT))
    out = ''
    for i, (text, tight) in enumerate(pieces):
        if i == 0:
            out = text
        elif tight or out.endswith('־'):  # maqqef binds forward too
            out += text
        else:
            out += ' ' + text
    # The WLC stores marks in Michigan-Claremont order (shin dot BEFORE
    # the vowel); Unicode canonical order is the reverse, and it is what
    # a Hebrew keyboard and every other modern Hebrew text produce. Two
    # strings that differ only in mark order look identical and compare
    # unequal, which would break search silently. NFC only reorders here
    # — the Hebrew presentation forms (U+FB2A and friends) are
    # composition-excluded, so none appear.
    return unicodedata.normalize('NFC', out.strip())


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = sys.argv[1]
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out: list[dict] = []
    missing: list[str] = []
    for code, name in BOOKS:
        path = os.path.join(src, f'{code}.xml')
        if not os.path.exists(path):
            missing.append(code)
            continue
        tree = ET.parse(path)
        for verse in tree.getroot().iter(
                '{http://www.bibletechnologies.net/2003/OSIS/namespace}verse'):
            osis = verse.get('osisID')
            if not osis:
                continue
            parts = osis.split('.')
            if len(parts) != 3:
                continue
            _, chapter, num = parts
            text = verse_text(verse)
            if not text:
                continue
            out.append({
                'book': name,
                'chapter': chapter,
                'verse': num,
                'text': text,
                'id': f'{ORDER[code]:03d}{int(chapter):03d}{int(num):03d}',
            })
    if missing:
        print(f'!! missing {len(missing)} books: {" ".join(missing)}',
              file=sys.stderr)
        return 1
    dest = os.path.join(root, 'assets', 'wlc.json')
    with open(dest, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    size = os.path.getsize(dest)
    books = len({v['book'] for v in out})
    print(f'assets/wlc.json: {len(out)} verses, {books} books, '
          f'{size / 1024 / 1024:.1f} MB')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
