#!/usr/bin/env python3
"""Add public-domain plates from Wikimedia Commons to the picture database.

    tools/import_commons_plates.py --dry-run
    tools/import_commons_plates.py --write

The picture database is `assets/maps_index.json` here plus the image
files in `~/Documents/CodingProject/yswords-data/images/illustrations`,
which Netlify serves. This adds to both.

WHAT THIS DOES NOT DO. It does not guess which chapter a plate belongs
to from its caption. `docs/DATA-INTEGRITY.md` has a whole section on
what caption-matching costs when it is wrong — 145 Doré plates once
attached to the town of Dor — and a picture filed under the wrong
chapter is worse than a chapter with no picture: the reader is told
something false about the text in front of them. So the reference for
every plate below was read off the scene and checked against scripture
by hand, and a plate nobody could place is not imported.

LICENCE. Every file's licence is re-checked at download time against
Commons' own metadata, and anything that is not public domain aborts the
run. The candidates were all `PD-old` — Doré died in 1883 — but a
checked claim and an assumed one are different things.

SIZE. The originals are ~6 MB scans; the plates already in the database
have a median of 280 KB. Commons' own thumbnailer is asked for
1280px, which is the width every Doré plate already in the collection
was stored at — matching the neighbours matters more than any number
picked for its own sake.
"""

import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

API = 'https://commons.wikimedia.org/w/api.php'
UA = {'User-Agent': 'SeekSparks-plates/1.0 (https://github.com/SuyangLiuPaul)'}
CDN_DIR = os.path.expanduser(
    '~/Documents/CodingProject/yswords-data/images/illustrations')
THUMB_WIDTH = 1280

# (Commons file, book, first chapter, last chapter, en, zh-Hans, zh-Hant)
#
# Doré's numbered English Bible set, the plates this database was missing.
# The twenty apocryphal ones in the same set — Tobit, Judith, Susanna,
# Bel, the Maccabees, Baruch — are deliberately absent: this app carries
# 66 books, so there is no chapter to file them under.
DORE = [
    ("065.A Levite Finds a Woman's Corpse.jpg", 'Judges', 19, 19,
     'A Levite Finds a Woman’s Corpse', '利未人发现妾的尸体', '利未人發現妾的屍體'),
    ("066.The Levite Carries the Woman's Body Away.jpg", 'Judges', 19, 19,
     'The Levite Carries the Woman’s Body Away', '利未人带走妾的尸身',
     '利未人帶走妾的屍身'),
    ('067.The Benjaminites Take the Virgins of Jabesh-gilead.jpg',
     'Judges', 21, 21, 'The Benjaminites Take the Virgins of Jabesh-gilead',
     '便雅悯人娶基列雅比的女子', '便雅憫人娶基列雅比的女子'),
    ("077.Jabesh-Gileadites Recover the Bodies of Saul and His Sons.jpg",
     '1 Samuel', 31, 31,
     'Jabesh-Gileadites Recover the Bodies of Saul and His Sons',
     '基列雅比人取回扫罗父子的尸身', '基列雅比人取回掃羅父子的屍身'),
    ("078.Combat between Soldiers of Ish-bosheth and David.jpg",
     '2 Samuel', 2, 2, 'Combat between the Soldiers of Ish-bosheth and David',
     '伊施波设与大卫的部下交战', '伊施波設與大衛的部下交戰'),
    ('082.Rizpah’s Kindness toward the Dead.jpg', '2 Samuel', 21, 21,
     'Rizpah’s Kindness toward the Dead', '利斯巴守护死者', '利斯巴守護死者'),
    ("083.Abishai Saves David's Life.jpg", '2 Samuel', 21, 21,
     'Abishai Saves David’s Life', '亚比筛救大卫的命', '亞比篩救大衛的命'),
    ('085.Cedars Are Cut Down for the Jerusalem Temple.jpg',
     '1 Kings', 5, 5, 'Cedars Are Cut Down for the Temple',
     '为圣殿砍伐香柏木', '為聖殿砍伐香柏木'),
    ('088.The Disobedient Prophet Is Slain by a Lion.jpg', '1 Kings', 13, 13,
     'The Disobedient Prophet Is Slain by a Lion', '违命的先知被狮子咬死',
     '違命的先知被獅子咬死'),
    ('092.The Israelites Slaughter the Syrians.jpg', '1 Kings', 20, 20,
     'The Israelites Slaughter the Syrians', '以色列人击杀亚兰人',
     '以色列人擊殺亞蘭人'),
    ('094.Elijah Destroys the Messengers of Ahaziah.jpg', '2 Kings', 1, 1,
     'Elijah Destroys the Messengers of Ahaziah', '以利亚烧灭亚哈谢的使者',
     '以利亞燒滅亞哈謝的使者'),
    ('095.Some Children Are Destroyed by Bears.jpg', '2 Kings', 2, 2,
     'The Children and the Bears', '童子与熊', '童子與熊'),
    ('096.A Famine in Samaria.jpg', '2 Kings', 6, 7,
     'A Famine in Samaria', '撒玛利亚的饥荒', '撒瑪利亞的饑荒'),
    ("098.Jehu's Companions Find Jezebel's Remains.jpg", '2 Kings', 9, 9,
     'Jehu’s Companions Find Jezebel’s Remains', '耶户的人寻见耶洗别的尸首',
     '耶戶的人尋見耶洗別的屍首'),
    ('100.Foreign Nations Are Slain by Lions in Samaria.jpg',
     '2 Kings', 17, 17, 'Lions among the Settlers in Samaria',
     '狮子袭击迁入撒玛利亚的外族', '獅子襲擊遷入撒瑪利亞的外族'),
    ('102A.The Plague of Jerusalem.jpg', '2 Samuel', 24, 24,
     'The Plague of Jerusalem', '耶路撒冷的瘟疫', '耶路撒冷的瘟疫'),
    ('103.The Ammonite and Moabite Armies Are Destroyed.jpg',
     '2 Chronicles', 20, 20, 'The Ammonite and Moabite Armies Are Destroyed',
     '亚扪与摩押的军队被灭', '亞捫與摩押的軍隊被滅'),
    ('104.Cyrus Restores the Vessels of the Temple.jpg', 'Ezra', 1, 1,
     'Cyrus Restores the Vessels of the Temple', '古列归还圣殿的器皿',
     '古列歸還聖殿的器皿'),
    ('105.The Rebuilding of the Temple Is Begun.jpg', 'Ezra', 3, 3,
     'The Rebuilding of the Temple Is Begun', '重建圣殿动工', '重建聖殿動工'),
    ('106.Artaxerxes Grants Freedom to the Jews.jpg', 'Ezra', 7, 7,
     'Artaxerxes Grants Freedom to the Jews', '亚达薛西准许犹大人归回',
     '亞達薛西准許猶大人歸回'),
    ('107.Ezra Kneels in Prayer.jpg', 'Ezra', 9, 9,
     'Ezra Kneels in Prayer', '以斯拉屈膝祷告', '以斯拉屈膝禱告'),
    ("108.Nehemiah Views the Ruins of Jerusalem's Walls.jpg",
     'Nehemiah', 2, 2, 'Nehemiah Views the Ruins of Jerusalem’s Walls',
     '尼希米察看耶路撒冷的城墙', '尼希米察看耶路撒冷的城牆'),
    ('109.Ezra Reads the Law to the People.jpg', 'Nehemiah', 8, 8,
     'Ezra Reads the Law to the People', '以斯拉向民众宣读律法',
     '以斯拉向民眾宣讀律法'),
    ("123.Baruch Writes Jeremiah's Prophecies.jpg", 'Jeremiah', 36, 36,
     'Baruch Writes Jeremiah’s Prophecies', '巴录记录耶利米的预言',
     '巴錄記錄耶利米的預言'),
]


def plate_id(commons_file: str) -> str:
    """The id scheme the 144 Doré plates already in the database use:
    `illus_dore_` + the first 20 characters of the filename with every
    non-alphanumeric removed — the `.jpg` included, which is why some
    ids end in a stray `j`."""
    return 'illus_dore_' + re.sub(r'[^a-z0-9]', '', commons_file.lower())[:20]


def fetch(params: dict) -> dict:
    url = API + '?' + urllib.parse.urlencode(params)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r:
        return json.load(r)


def imageinfo(files: list[str]) -> dict:
    out: dict[str, dict] = {}
    for i in range(0, len(files), 20):
        d = fetch({
            'action': 'query',
            'titles': '|'.join('File:' + f for f in files[i:i + 20]),
            'prop': 'imageinfo',
            'iiprop': 'extmetadata|url|size',
            'iiurlwidth': str(THUMB_WIDTH),
            'format': 'json',
        })
        for page in d['query']['pages'].values():
            info = page.get('imageinfo')
            if info:
                out[page['title'][5:]] = info[0]
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true',
                    help='download the plates and rewrite the index')
    args = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    index_path = os.path.join(root, 'assets', 'maps_index.json')
    index = json.load(open(index_path, encoding='utf-8'))
    have = {e['id'] for e in index}

    rows = [r for r in DORE if plate_id(r[0]) not in have]
    print(f'{len(DORE)} curated, {len(DORE) - len(rows)} already present, '
          f'{len(rows)} to add')
    if not rows:
        return 0

    info = imageinfo([r[0] for r in rows])
    missing = [r[0] for r in rows if r[0] not in info]
    if missing:
        print('!! not on Commons: ' + ', '.join(missing), file=sys.stderr)
        return 1

    entries = []
    for (name, book, lo, hi, en, hans, hant) in rows:
        meta = info[name]['extmetadata']
        licence = meta.get('LicenseShortName', {}).get('value', '')
        if 'public domain' not in licence.lower():
            print(f'!! {name} is "{licence}", not public domain',
                  file=sys.stderr)
            return 1
        pid = plate_id(name)
        ref = f'{book} {lo}' if lo == hi else f'{book} {lo}–{hi}'
        entries.append({
            'id': pid,
            'kind': 'scene',
            'title': {
                'en': f'{en} (Doré)',
                'zh-Hans': f'{hans} (多雷)',
                'zh-Hant': f'{hant} (多雷)',
            },
            'description': {
                'en': f'Gustave Doré, 1866 — {en} ({ref}).',
                'zh-Hans': f'古斯塔夫·多雷,1866 年——{hans}。',
                'zh-Hant': f'古斯塔夫·多雷,1866 年——{hant}。',
            },
            'books': {book: [lo, hi]},
            'file': f'{pid}.jpg',
            'source': 'cdn',
            'collection': 'dore',
        })

    if not args.write:
        for e in entries:
            print(f'  {e["id"]}  {e["books"]}  {e["title"]["en"]}')
        print('\n--write to download and update the index')
        return 0

    os.makedirs(CDN_DIR, exist_ok=True)
    total = 0
    for (name, *_rest), entry in zip(rows, entries):
        url = info[name].get('thumburl') or info[name]['url']
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req) as r:
            data = r.read()
        dest = os.path.join(CDN_DIR, entry['file'])
        with open(dest, 'wb') as f:
            f.write(data)
        total += len(data)
        print(f'  {entry["file"]}  {len(data) // 1024} KB')

    index.extend(entries)
    with open(index_path, 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, separators=(',', ':'))
    print(f'\n{len(entries)} plates, {total / 1048576:.1f} MB, '
          f'index now {len(index)} entries')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
