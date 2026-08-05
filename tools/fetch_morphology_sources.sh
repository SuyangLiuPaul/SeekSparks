#!/usr/bin/env bash
# Download MorphGNT (SBLGNT, CC BY-SA 3.0) + Open Scriptures Hebrew Bible
# (WLC + morphology, CC BY 4.0) into ./src/.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p src/gnt src/hb

GNT_BASE=https://raw.githubusercontent.com/morphgnt/sblgnt/master
HB_BASE=https://raw.githubusercontent.com/openscriptures/morphhb/master/wlc

GNT_FILES="61-Mt 62-Mk 63-Lk 64-Jn 65-Ac 66-Ro 67-1Co 68-2Co 69-Ga 70-Eph \
71-Php 72-Col 73-1Th 74-2Th 75-1Ti 76-2Ti 77-Tit 78-Phm 79-Heb 80-Jas \
81-1Pe 82-2Pe 83-1Jn 84-2Jn 85-3Jn 86-Jud 87-Re"

HB_FILES="Gen Exod Lev Num Deut Josh Judg Ruth 1Sam 2Sam 1Kgs 2Kgs 1Chr 2Chr \
Ezra Neh Esth Job Ps Prov Eccl Song Isa Jer Lam Ezek Dan Hos Joel Amos Obad \
Jonah Mic Nah Hab Zeph Hag Zech Mal"

for f in $GNT_FILES; do
  [ -s "src/gnt/$f-morphgnt.txt" ] && continue
  curl -sfL --max-time 120 -o "src/gnt/$f-morphgnt.txt" "$GNT_BASE/$f-morphgnt.txt" \
    && echo "gnt  $f" || echo "FAIL gnt $f"
done

for f in $HB_FILES; do
  [ -s "src/hb/$f.xml" ] && continue
  curl -sfL --max-time 180 -o "src/hb/$f.xml" "$HB_BASE/$f.xml" \
    && echo "hb   $f" || echo "FAIL hb $f"
done

echo "--- done: $(ls src/gnt | wc -l) GNT, $(ls src/hb | wc -l) HB"
