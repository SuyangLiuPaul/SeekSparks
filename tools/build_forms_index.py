#!/usr/bin/env python3
"""assets/originals/*.json -> assets/forms/, the index behind the Forms tab.

BibleWorks help topic bwh10q. The topic describes two lookups that run in
opposite directions, and the second is the one a naive reading of "Forms"
never produces:

  top     lemma -> every inflected form in the database parsed with it
  bottom  the inflected form -> every way THAT FORM is parsed

The second is a statement about ambiguity. The Analysis pane currently
prints one parse as though it were certain; for 4,438 forms it is not.

Shape follows from three measurements over the bundled corpus (438,821
tagged tokens, 66 books):

  14,039 lemmas, 130,950 distinct surface forms, 136,483 (lemma, form,
  morph) triples -- but only 4,438 forms carry more than one parse and
  only 1,335 carry more than one lemma.

So the form index stores ONLY the ambiguous forms. Absence of an entry is
itself the answer, which turns a 130,950-key map into a ~5,000-key one.
The lemma index is sharded by Strong's number hundreds (G3056 -> "G30")
because the caller only ever holds one number at a time -- the word under
the cursor -- and a shard is a single small fetch that then caches.

Refs are capped per triple: enough to make an entry clickable, not a
concordance. `assets/strongs/concordance.json` already holds the totals.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
from collections import defaultdict

# Enough to answer "show me one" without turning the shard into a
# concordance. The count travels separately, so a capped list never
# misreports the total.
REFS_PER_TRIPLE = 3

# Refs are stored as "<bookIndex> <chapter>:<verse>", with the slug table
# written once into index.json. Spelling the slug out per ref costs about
# 1.5 MB across the shards -- "1_chronicles 10:1" is 18 bytes where "12
# 10:1" is 7 -- for a name the client has to map to a book anyway.
def book_from_path(path: str) -> str:
    return os.path.splitext(os.path.basename(path))[0]


def shard_for(strongs: str) -> str:
    """'G3056' -> 'G30'. Language letter + Strong's number // 100."""
    letter, digits = strongs[0], strongs[1:]
    return f'{letter}{int(digits) // 100}'


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', default='assets/originals')
    ap.add_argument('--out', default='assets/forms')
    args = ap.parse_args()

    # (strongs, form, morph) -> [count, [refs]]
    triples: dict[tuple[str, str, str], list] = defaultdict(
        lambda: [0, []])
    # form -> {(strongs, morph)}, to find the ambiguous ones
    by_form: dict[str, set[tuple[str, str]]] = defaultdict(set)

    tokens = 0
    paths = sorted(glob.glob(os.path.join(args.src, '*.json')))
    if not paths:
        ap.error(f'no book files under {args.src}')

    books = [book_from_path(p) for p in paths]
    for book_index, path in enumerate(paths):
        book = book_index
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
        for ref, words in data.items():
            for w in words:
                s, form, morph = w.get('s'), w.get('w'), w.get('m')
                # A word with no Strong's number or no surface form
                # cannot be indexed by either direction. Morph may be
                # absent on untagged tokens; '' keeps it a valid key and
                # the UI renders it as "unparsed".
                if not s or not form:
                    continue
                morph = morph or ''
                tokens += 1
                slot = triples[(s, form, morph)]
                slot[0] += 1
                if len(slot[1]) < REFS_PER_TRIPLE:
                    slot[1].append(f'{book} {ref}')
                by_form[form].add((s, morph))

    # ---- lemma -> forms, sharded ------------------------------------
    shards: dict[str, dict[str, list]] = defaultdict(dict)
    for (s, form, morph), (count, refs) in triples.items():
        shards[shard_for(s)].setdefault(s, []).append([form, morph, count, refs])

    # Frequency-descending, then alphabetical. bwh10q offers three sort
    # orders; this is the one it calls most useful and the only one that
    # needs the corpus to compute, so it is baked in and the other two
    # are done in the client where they are free.
    for shard in shards.values():
        for entries in shard.values():
            entries.sort(key=lambda e: (-e[2], e[0]))

    # ---- ambiguous forms only ---------------------------------------
    ambiguous: dict[str, list] = {}
    for form, pairs in by_form.items():
        if len(pairs) < 2:
            continue
        rows = [[s, morph, triples[(s, form, morph)][0]] for s, morph in pairs]
        rows.sort(key=lambda r: (-r[2], r[0], r[1]))
        ambiguous[form] = rows

    out = args.out
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(os.path.join(out, 'l'))

    def dump(path: str, obj) -> int:
        blob = json.dumps(obj, ensure_ascii=False,
                          separators=(',', ':')) + '\n'
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(blob)
        return len(blob.encode('utf-8'))

    shard_bytes = 0
    for name, shard in shards.items():
        shard_bytes += dump(os.path.join(out, 'l', f'{name}.json'), shard)
    amb_bytes = dump(os.path.join(out, 'ambiguous.json'), ambiguous)

    dump(os.path.join(out, 'index.json'), {
        'schemaVersion': 1,
        'source': 'Derived from the bundled original-language texts '
                  '(MorphGNT, CC BY-SA; Open Scriptures Hebrew Bible, '
                  'CC BY 4.0). No third-party lexicon or morphology '
                  'database is reproduced here.',
        'tokens': tokens,
        'lemmas': len({s for s, _, _ in triples}),
        'forms': len(by_form),
        'triples': len(triples),
        'ambiguousForms': len(ambiguous),
        'refsPerTriple': REFS_PER_TRIPLE,
        'books': books,
        'shards': sorted(shards),
    })

    print(f'tokens          {tokens}')
    print(f'lemmas          {len({s for s, _, _ in triples})}')
    print(f'surface forms   {len(by_form)}')
    print(f'triples         {len(triples)}')
    print(f'ambiguous forms {len(ambiguous)} '
          f'({100 * len(ambiguous) / len(by_form):.1f}% of forms)')
    print(f'shards          {len(shards)}, '
          f'{shard_bytes / 1e6:.2f} MB total, '
          f'{shard_bytes / len(shards) / 1e3:.1f} KB mean')
    print(f'ambiguous.json  {amb_bytes / 1e3:.1f} KB')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
