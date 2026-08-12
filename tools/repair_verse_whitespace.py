#!/usr/bin/env python3
"""Strip leading/trailing whitespace from every verse record in an edition.

2026-08-12 (docs/DATA-INTEGRITY.md check 31c).

`assets/leb.json` is the only edition in the repository whose verses end
in whitespace, and it is not a few of them: all 31,199 close with a
newline (`"…the heavens and the earth--\\n"`). Every other edition has
zero. That is the shape check 27c already ruled a defect rather than an
editorial choice -- a systematic difference is an edition, a difference
one edition has and twelve do not is an import artifact.

The reader never showed it, because `buildAnnotatedSpans` calls
`trimRight()` and every sanitiser in `text_patterns.dart` ends in
`.trim()`. Browse does not: it hands the raw string to `parseScripture`,
which strips markup and nothing else, so a trailing newline becomes a
blank line and every LEB row in the compare pane stood one line taller
than the editions beside it.

INTERNAL newlines are load-bearing and are left alone -- LJK2 and
biblexg-v2 mark OT-quote poetry with them, and `build_verse_content_spans`
documents that they must survive. Only the ends are touched.

Verifies by default; `--write` applies. Re-running after a write is a
no-op, and the file is re-serialised with the same
`json.dumps(indent=2, ensure_ascii=False)` shape it already has, so the
diff is exactly the repaired verses.
"""

import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")


def verse_files():
    for path in sorted(glob.glob(os.path.join(ASSETS, "*.json"))):
        try:
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)
        except (ValueError, UnicodeDecodeError):
            continue
        if not isinstance(data, list) or not data:
            continue
        if not isinstance(data[0], dict) or "text" not in data[0]:
            continue
        yield path, data


def offenders(records):
    return [
        i
        for i, r in enumerate(records)
        if isinstance(r.get("text"), str) and r["text"] != r["text"].strip()
    ]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true", help="apply the repair")
    args = ap.parse_args()

    dirty = 0
    for path, records in verse_files():
        name = os.path.basename(path)
        bad = offenders(records)
        if not bad:
            print(f"  {name:24s} {len(records):6d} records  clean")
            continue
        dirty += len(bad)
        print(f"  {name:24s} {len(records):6d} records  {len(bad):6d} padded")
        if not args.write:
            continue
        for i in bad:
            records[i]["text"] = records[i]["text"].strip()
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(records, indent=2, ensure_ascii=False))
        print(f"  {'':24s} rewritten")

    if dirty and not args.write:
        print(f"\n{dirty} padded verse(s). Re-run with --write to repair.")
        return 1
    print(f"\n{'repaired' if args.write else 'checked'}: {dirty} padded verse(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
