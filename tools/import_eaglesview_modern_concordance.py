#!/usr/bin/env python3
"""Export Eagle's View Modern Concordance data without publishing it.

The topic taxonomy follows *Modern Concordance to the New Testament*
(Darton, 1976), so generated data stays outside app assets until the owner has
confirmed reuse permission. This importer is nevertheless complete and
self-validating, so permission can be acted on without redoing the extraction.

Requires mdbtools (`brew install mdbtools`). Example:

    python3 tools/import_eaglesview_modern_concordance.py \
      /path/to/MC.dct --out build/restricted/modern-concordance.json

Passing an output inside ``assets/`` is refused unless
``--acknowledge-rights`` is supplied explicitly.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import shutil
import subprocess
from pathlib import Path


EXPECTED_COUNTS = {
    "topics": 341,
    # Parsed CSV row counts. Simple line counting overstates these because
    # several bilingual descriptions contain embedded newlines.
    "sections": 1645,
    "subsections": 7758,
    "verses": 63930,
    "stats": 7750,
    "greekWords": 5175,
    "wordTypes": 5,
}

TABLES = {
    "topics": "tblTopic",
    "sections": "tblSection",
    "subsections": "tblSubsection",
    "verses": "tblVerse",
    "stats": "tblStat",
    "greekWords": "tblEngGk",
    "wordTypes": "tblWordType",
}

INTEGER_FIELDS = {
    "TopicID",
    "SectionID",
    "SubsectionID",
    "PartID",
    "BookID",
    "Chapter",
    "Verse",
    "NT",
    "G&A T",
    "Paul T",
    "John T",
    "OA T",
    "Mat",
    "Mar",
    "Luk",
    "Joh",
    "Act",
    "Rom",
    "Gal",
    "Phi",
    "Col",
    "Tit",
    "Heb",
    "Jam",
    "Rev",
    "1Co",
    "2Co",
    "Eph",
    "1Th",
    "2Th",
    "1Ti",
    "2Ti",
    "Phm",
    "1Pe",
    "2Pe",
    "1Jo",
    "2Jo",
    "3Jo",
    "Jud",
}


def export_table(database: Path, table: str) -> list[dict[str, object]]:
    result = subprocess.run(
        ["mdb-export", str(database), table],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    rows: list[dict[str, object]] = []
    for row in csv.DictReader(io.StringIO(result.stdout)):
        normalized: dict[str, object] = {}
        for key, value in row.items():
            if value == "":
                normalized[key] = None
            elif key in INTEGER_FIELDS:
                normalized[key] = int(float(value))
            else:
                normalized[key] = value
        rows.append(normalized)
    return rows


def validate(data: dict[str, list[dict[str, object]]]) -> dict[str, object]:
    counts = {name: len(rows) for name, rows in data.items()}
    if counts != EXPECTED_COUNTS:
        raise ValueError(f"unexpected table counts: {counts}")

    topic_ids = {row["TopicID"] for row in data["topics"]}
    section_ids = {
        (row["TopicID"], row["SectionID"]) for row in data["sections"]
    }
    subsection_ids = {
        (row["TopicID"], row["SectionID"], row["SubsectionID"], row["PartID"])
        for row in data["subsections"]
    }
    if any(row["TopicID"] not in topic_ids for row in data["sections"]):
        raise ValueError("section references a missing topic")
    for table in ("subsections", "verses", "stats"):
        if any(
            (row["TopicID"], row["SectionID"]) not in section_ids
            for row in data[table]
        ):
            raise ValueError(f"{table} references a missing section")
    orphan_counts: dict[str, int] = {}
    for table in ("verses", "stats"):
        orphan_counts[table] = sum(
            1
            for row in data[table]
            if (
            (row["TopicID"], row["SectionID"], row["SubsectionID"], row["PartID"])
            not in subsection_ids
            )
        )
    # Eagle's View itself contains 22 verse links without a matching
    # subsection-description record. Preserve them losslessly and make the
    # source defect explicit rather than silently deleting or inventing text.
    if orphan_counts != {"verses": 22, "stats": 0}:
        raise ValueError(f"unexpected orphan reference counts: {orphan_counts}")

    invalid_book_links = 0
    zero_reference_links = 0
    for row in data["verses"]:
        book = int(row["BookID"])
        chapter = int(row["Chapter"])
        verse = int(row["Verse"])
        if not 40 <= book <= 66:
            invalid_book_links += 1
        if chapter == 0 or verse == 0:
            zero_reference_links += 1
    if invalid_book_links != 0 or zero_reference_links != 5:
        raise ValueError(
            "unexpected invalid verse-link counts: "
            f"books={invalid_book_links}, zeroReferences={zero_reference_links}"
        )
    return {
        "orphanVerseLinks": orphan_counts["verses"],
        "orphanStatRows": orphan_counts["stats"],
        "zeroReferenceLinks": zero_reference_links,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("database", type=Path, help="extracted MC.dct file")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("build/restricted/eaglesview-modern-concordance.json"),
    )
    parser.add_argument(
        "--acknowledge-rights",
        action="store_true",
        help="allow writing under assets/ after reuse permission is confirmed",
    )
    args = parser.parse_args()

    if shutil.which("mdb-export") is None:
        parser.error("mdb-export is required; install mdbtools first")
    if not args.database.is_file():
        parser.error(f"database does not exist: {args.database}")

    output = args.out.resolve()
    assets = (Path(__file__).resolve().parent.parent / "assets").resolve()
    if output.is_relative_to(assets) and not args.acknowledge_rights:
        parser.error(
            "refusing to publish the copyrighted topic scheme under assets/; "
            "confirm permission, then pass --acknowledge-rights"
        )

    data = {
        name: export_table(args.database, table) for name, table in TABLES.items()
    }
    integrity = validate(data)
    payload = {
        "schemaVersion": 1,
        "rightsStatus": "permission-required",
        "source": "Eagle's View 2.0 / Modern Concordance",
        "counts": EXPECTED_COUNTS,
        "integrity": integrity,
        **data,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {output}")
    for name, count in EXPECTED_COUNTS.items():
        print(f"  {name}: {count}")
    print("rights: permission-required; not registered or bundled")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
