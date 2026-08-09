#!/usr/bin/env python3
"""Repairs the reference defects the #304 audit found in shipped Bible
assets. Idempotent: re-running it reports "already correct".

Committed rather than done by hand because these are scripture assets —
a change to 254 verses of a Bible text should be reproducible and
reviewable, not an unexplained diff.

1. assets/leb.json labels Micah "Mic" and Nahum "Nah". Neither string is
   in `bookNameToEnglish`, and `Verse.id` is built as
   `bookNameToEnglish[book] ?? book`, so an LEB highlight in Micah is
   keyed `Mic-1-1` while the same verse under every other edition is
   keyed `Micah-1-1`. The comment on `Verse.id` says the English name is
   used precisely to "enable cross-version highlight persistence"; for
   these two books it silently does not. The names are also absent from
   `kBibleBooks`, so the books sort and localise wrongly too — a Chinese
   UI prints the raw "Mic".
   Their `id` fields additionally begin `000`, i.e. book zero.

2. assets/cuvs-yhwh-tr.json labels 2 Timothy 提摩太后書 — simplified 后
   inside an otherwise traditional name. `zhToEn` carries 提摩太后书 and
   提摩太後書 but not the mixed form, so the traditional edition's
   2 Timothy resolves to no English book at all. It is the only unmapped
   book name across all five Chinese editions.

3. assets/cuvs-plus.json numbers 1 Chronicles 22 one verse low for the
   whole chapter: what every other edition calls 22:1 ("大卫说：这就是
   耶和华神的殿…") is filed as 21:31, so chapter 21 carries 31 verses and
   chapter 22 only 18. Verified by normalising away the 雅伟/耶和华
   divine-name restoration and the 藉/借 orthography and comparing
   against cuvs-yhwh: 21:31 is character-identical to cuvs-yhwh 22:1, and
   cuvs-plus 22:N is cuvs-yhwh 22:N+1 for all 18.
   `assets/tagged/cuvs-plus/1_chronicles.json` carries the same shift, so
   the text and its Strong's tags agree with each other — but
   `assets/originals/1_chronicles.json` (the Hebrew corpus, canonical at
   30 and 19 verses) does not, so the Word Study pane was showing a
   cuvs-plus reader the Hebrew of the NEXT verse throughout 1 Chronicles
   22, and nothing at all for 21:31.
   Both cuvs-plus files are renumbered together; the text is untouched.

No repair here invents or alters a single word of scripture. Each changes
only the label a verse is filed under.
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Canonical book order, used only to rebuild the numeric id prefix.
CANON = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
    'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
    'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John',
    'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
    'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
    '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
    'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John',
    '3 John', 'Jude', 'Revelation',
]
BOOK_NUMBER = {b: i + 1 for i, b in enumerate(CANON)}

RENAMES = {
    'leb.json': {'Mic': 'Micah', 'Nah': 'Nahum'},
    'cuvs-yhwh-tr.json': {'提摩太后書': '提摩太後書'},
}


def write_like(path, original, data):
    """Re-serialises [data] in whatever layout [original] used.

    The shipped assets are not uniform — leb.json and cuvs-yhwh-tr.json
    are pretty-printed at indent 2, cuvs-plus.json and the tagged files
    are minified. Guessing wrong reflows eight megabytes and buries a
    nineteen-verse correction in a 217,000-line diff nobody can review.
    """
    indented = original.startswith('[\n') or original.startswith('{\n')
    if indented:
        text = json.dumps(data, ensure_ascii=False, indent=2)
    else:
        text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if original.endswith('\n'):
        text += '\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def repair(filename, renames):
    path = os.path.join(ROOT, 'assets', filename)
    with open(path, encoding='utf-8') as f:
        original = f.read()
    verses = json.loads(original)

    renamed = 0
    reindexed = 0
    for v in verses:
        new = renames.get(v.get('book'))
        if new is None:
            continue
        v['book'] = new
        renamed += 1
        # The `id` field is not read by Verse.fromJson (the model derives
        # its own), but leaving a book-zero prefix behind a corrected name
        # is half a repair and a trap for the next reader of this file.
        num = BOOK_NUMBER.get(new)
        if num and isinstance(v.get('id'), str) and len(v['id']) == 9:
            fixed = f'{num:03d}{v["id"][3:]}'
            if fixed != v['id']:
                v['id'] = fixed
                reindexed += 1

    if renamed == 0:
        print(f'{filename}: already correct, nothing to do')
        return False

    write_like(path, original, verses)
    print(f'{filename}: renamed {renamed} verses '
          f'({", ".join(f"{a} -> {b}" for a, b in renames.items())}), '
          f'reindexed {reindexed} ids')
    return True


def renumber_chronicles():
    """Moves cuvs-plus 1 Chronicles 21:31 to 22:1 and shifts 22:1-18 up
    by one, in both the text and the tagged layer."""
    changed = False

    path = os.path.join(ROOT, 'assets', 'cuvs-plus.json')
    with open(path, encoding='utf-8') as f:
        original = f.read()
    verses = json.loads(original)
    moved = 0
    for v in verses:
        if v.get('book') != '历代志上':
            continue
        ch, num = v.get('chapter'), v.get('verse')
        if ch == '21' and num == '31':
            v['chapter'], v['verse'], v['id'] = '22', '1', '013022001'
            moved += 1
        elif ch == '22':
            n = int(num) + 1
            v['verse'], v['id'] = str(n), f'013022{n:03d}'
            moved += 1
    if moved:
        # Renumbering leaves file order ascending: the old 21:31 record
        # already sat immediately before the old 22:1.
        write_like(path, original, verses)
        print(f'cuvs-plus.json: renumbered {moved} verses of 1 Chronicles 22')
        changed = True
    else:
        print('cuvs-plus.json: 1 Chronicles already correct')

    tagged = os.path.join(ROOT, 'assets', 'tagged', 'cuvs-plus',
                          '1_chronicles.json')
    with open(tagged, encoding='utf-8') as f:
        raw = f.read()
    data = json.loads(raw)
    if '21:31' in data:
        out = {}
        for key, value in data.items():
            ch, num = key.split(':')
            if ch == '21' and num == '31':
                out['22:1'] = value
            elif ch == '22':
                out[f'22:{int(num) + 1}'] = value
            else:
                out[key] = value
        write_like(tagged, raw, out)
        print('tagged/cuvs-plus/1_chronicles.json: renumbered to match')
        changed = True
    else:
        print('tagged/cuvs-plus/1_chronicles.json: already correct')

    return changed


def main():
    changed = False
    for filename, renames in RENAMES.items():
        changed |= repair(filename, renames)
    changed |= renumber_chronicles()
    if not changed:
        print('\nNo changes. Assets already repaired.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
