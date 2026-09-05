#!/usr/bin/env python3
"""Apply the 2026-09-05 wheel coverage pass to assets/wheel_history.json.

WHY THIS IS A SCRIPT AND NOT A HAND EDIT. The asset is 672 KB of
1-space-indented JSON with three locales on every string; a hand edit
cannot be re-run, cannot be diffed against its own intent, and cannot
prove it left the other 1,124 records alone. This file is the change,
so the change is reviewable and repeatable.

WHAT IT DOES, and why each part is here rather than in a doc:

  ADDS 5 powers and 2 events. Every one fills a hole that was MEASURED,
  not guessed at: the three Chinese bands sit in the three gaps that a
  sweep of `powers` by stream found in a chain that draws Shang, Zhou,
  Han, Jin, Sui, Tang, Song, Yuan, Ming and Qing and skipped the rest;
  `mamluk-sultanate` sits in the 1258-1299 hole between the Abbasids
  and the Ottomans, over the centuries in which the Mamluks, not either
  of them, held Jerusalem; `judges-of-israel` was proposed twice by
  earlier passes, ranked first among their spans, and never shipped.

  REMOVES 4 records that draw an event a second time. `special_relativity`
  and `einstein_relativity` are both 1905 Einstein, on two different
  rings. `powered_flight` and `wright_first_flight` are both 1903 Kitty
  Hawk, on two different rings. `movable_type_china` (1040) and
  `bi_sheng_movable_type` (1045) are both Bi Sheng, on the SAME ring
  five years apart — and the 1040 record states a year outside the
  1041-1048 window that the only source either of them cites, Shen Kuo,
  actually gives. `columbian_exchange` is dated 1500 and titled
  "Columbus Reaches the Americas" while `columbus_caribbean` already
  carries the landfall at 1492 — and 1500 is a round number no reference
  states for it, which is an invented date under this file's own rules.
  Each survivor keeps whatever its twin was carrying that was true, so
  nothing is lost with the record.

  4 removals against 2 additions takes `events` from 747 to 745 in the
  asset, and from 851 to 849 after the bible_timeline merge.

THE ONE RECORD THAT WAS RESEARCHED, WRITTEN, AND THEN LEFT OFF. A third
event was ready and is not here: the prologue to Sirach at 132 BC, the
earliest surviving witness to the Hebrew scriptures in three divisions.
The Israel pass had already flagged it as an optional anchor to add
"only if the annulus has room", and this pass MEASURED whether it does.
It does not. With the prologue in, `wheel_label_legibility_test.dart`
drops to 61 whole Chinese names at 900 px against a floor of 62 — one
name past the budget — and dropping either of the two modern events
instead does not recover it, because the crowding is at 132 BC and not
in the twentieth century. So the answer to the question that file left
open is no, with a number attached. The other two events cost the rim
nothing. See tools/ history and the report for the per-record
measurement.

DATES. Every year below was re-sourced independently for this pass and
none was taken from any chart. Where general references genuinely
disagree, `approximate` is true AND the disagreement is written into
the note in all three locales, rather than being resolved silently:
Qin's end (207 or 206 BC), the Three Kingdoms' close (265 or 280), and
the northern-southern period's opening (386 or 420).
"""

import json
import pathlib

ASSET = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'wheel_history.json'

# --- new powers ------------------------------------------------------

NEW_POWERS = [
    {
        "id": "qin-dynasty",
        "start": -221,
        "end": -206,
        "region": "asia",
        "stream": "china",
        "approximate": True,
        "basis": "conventional",
        "name": {
            "en": "Qin Dynasty",
            "zh-Hans": "秦朝",
            "zh-Hant": "秦朝",
        },
        "note": {
            "en": "The first empire to hold all of China, under the king of Qin who took the title of First Emperor. It set one script, one coinage and one axle width across the country and joined the northern walls into one line, and it fell within four years of his death. References close it at 207 or at 206 BC, so the band's end is rounded.",
            "zh-Hans": "第一个统一全中国的帝国，由自称始皇帝的秦王所建。它在全国推行一种文字、一种钱币、一种车轨，并把北边各段长城连成一线；始皇死后不出四年即亡。各家或断其亡于公元前207年，或断于前206年，故此带末端取约数。",
            "zh-Hant": "第一個統一全中國的帝國，由自稱始皇帝的秦王所建。它在全國推行一種文字、一種錢幣、一種車軌，並把北邊各段長城連成一線；始皇死後不出四年即亡。各家或斷其亡於公元前207年，或斷於前206年，故此帶末端取約數。",
        },
    },
    {
        "id": "three-kingdoms-china",
        "start": 220,
        "end": 280,
        "region": "asia",
        "stream": "china",
        "approximate": True,
        "basis": "conventional",
        "name": {
            "en": "The Three Kingdoms",
            "zh-Hans": "三国",
            "zh-Hant": "三國",
        },
        "note": {
            "en": "Wei, Shu and Wu divided China when the Han ended in 220, and the division closed when the Jin took Wu in 280. Some references stop the period at 265, where the Jin house itself begins, so the band's end is rounded; this chart takes the reunification, which is the year the Jin band already names.",
            "zh-Hans": "公元220年汉亡，魏、蜀、吴三分中国；280年晋灭吴，分裂乃止。有的著作把此期断至265年，即晋室自身之始，故此带末端取约数；本图取统一之年，也就是晋朝那一带已经点明的年份。",
            "zh-Hant": "公元220年漢亡，魏、蜀、吳三分中國；280年晉滅吳，分裂乃止。有的著作把此期斷至265年，即晉室自身之始，故此帶末端取約數；本圖取統一之年，也就是晉朝那一帶已經點明的年份。",
        },
    },
    {
        "id": "northern-southern-dynasties",
        "start": 420,
        "end": 589,
        "region": "asia",
        "stream": "china",
        "approximate": True,
        "basis": "conventional",
        "name": {
            "en": "Northern and Southern Dynasties",
            "zh-Hans": "南北朝",
            "zh-Hant": "南北朝",
        },
        "note": {
            "en": "After the Jin fell in 420 rival houses held the north and the south until the Sui reunited the country in 589. It is the stretch in which Buddhism took root through Chinese society. References that count the northern line from its own founding open the period in 386 instead, so the band's start is rounded.",
            "zh-Hans": "公元420年晋亡，南北各有王朝对峙，直到589年隋朝再度统一。佛教正是在这段年月里深入中国社会。有的著作从北方政权自身立国之年算起，把此期起点定在386年，故此带起端取约数。",
            "zh-Hant": "公元420年晉亡，南北各有王朝對峙，直到589年隋朝再度統一。佛教正是在這段年月裡深入中國社會。有的著作從北方政權自身立國之年算起，把此期起點定在386年，故此帶起端取約數。",
        },
    },
    {
        "id": "mamluk-sultanate",
        "start": 1250,
        "end": 1517,
        "region": "islamic",
        "stream": "islam",
        "approximate": False,
        "basis": "conventional",
        "name": {
            "en": "Mamluk Sultanate",
            "zh-Hans": "马木留克苏丹国",
            "zh-Hant": "馬木留克蘇丹國",
        },
        "note": {
            "en": "The soldier-slave sultans who took Egypt in 1250 and Syria ten years after, and held them until the Ottomans took Cairo in 1517. They stopped the Mongols at Ain Jalut in 1260 and took Acre, the last crusader city, in 1291. Jerusalem was theirs for the whole of that time, which is the stretch this chart otherwise leaves between the Abbasids and the Ottomans.",
            "zh-Hans": "以奴隶出身的军人为苏丹，1250年据有埃及，十年后又据叙利亚，直到1517年奥斯曼军攻取开罗为止。他们1260年在阿音札鲁特挡住蒙古军，1291年攻下十字军最后一座城阿卡。这两百多年间耶路撒冷一直在他们手中，而本图在阿拔斯与奥斯曼之间原是空的。",
            "zh-Hant": "以奴隸出身的軍人為蘇丹，1250年據有埃及，十年後又據敘利亞，直到1517年奧斯曼軍攻取開羅為止。他們1260年在阿音札魯特擋住蒙古軍，1291年攻下十字軍最後一座城阿卡。這兩百多年間耶路撒冷一直在他們手中，而本圖在阿拔斯與奧斯曼之間原是空的。",
        },
    },
    {
        "id": "judges-of-israel",
        "start": -1380,
        "end": -1050,
        "region": "levant",
        "stream": "israel",
        "approximate": True,
        "basis": "conventional",
        "ref": "Judges 2:16",
        "name": {
            "en": "The Judges of Israel",
            "zh-Hans": "以色列的士师时期",
            "zh-Hant": "以色列的士師時期",
        },
        "note": {
            "en": "The stretch between Joshua's death and Israel's first king; both ends are years this chart already draws. NO JUDGE IS DRAWN INSIDE IT, and that is deliberate: the years the book states for the judges add to about 530 while 1 Kings 6:1 allows 479 from the exodus to the temple, so this app counts them by verse and does not put them on the axis. The band is marked approximate for the same reason.",
            "zh-Hans": "自约书亚去世到以色列立第一位王之间的年月；两端都取自本图已经画出的年份。带内不画任何一位士师，这是有意的：士师记所记各段年数合计约530年，而列王纪上6:1只容出埃及至建殿共479年，故本应用按经文逐条计数，不把他们排在年轴上。此带标为约数，也是同一缘故。",
            "zh-Hant": "自約書亞去世到以色列立第一位王之間的年月；兩端都取自本圖已經畫出的年份。帶內不畫任何一位士師，這是有意的：士師記所記各段年數合計約530年，而列王紀上6:1只容出埃及至建殿共479年，故本應用按經文逐條計數，不把他們排在年軸上。此帶標為約數，也是同一緣故。",
        },
    },
]

# --- new events ------------------------------------------------------

NEW_EVENTS = [
    {
        "id": "pope_john_paul_i",
        "year": 1978,
        "era": "church",
        "stream": "church",
        "basis": "conventional",
        "approximate": False,
        "title": {
            "en": "John Paul I Reigns Thirty-Three Days",
            "zh-Hans": "若望保禄一世在位三十三天",
            "zh-Hant": "若望保祿一世在位三十三天",
        },
        "desc": {
            "en": "Albino Luciani was elected on 26 August 1978 and found dead on 28 September, so one year holds two conclaves and three popes. He is a moment on this chart and not a band because a reign of thirty-three days has no width on an axis six thousand years long — the same reason Leo V is drawn this way.",
            "zh-Hans": "阿尔比诺·卢恰尼于1978年8月26日当选，9月28日被发现去世，故这一年之内有两次教宗选举、三位教宗。本图把他画为一个点而非一条带，因为三十三天在长达六千年的年轴上没有宽度——良五世也是照此画的。",
            "zh-Hant": "阿爾比諾·盧恰尼於1978年8月26日當選，9月28日被發現去世，故這一年之內有兩次教宗選舉、三位教宗。本圖把他畫為一個點而非一條帶，因為三十三天在長達六千年的年軸上沒有寬度——良五世也是照此畫的。",
        },
    },
    {
        "id": "kanto_earthquake",
        "year": 1923,
        "era": "world",
        "stream": "japan",
        "basis": "conventional",
        "approximate": False,
        "title": {
            "en": "The Great Kanto Earthquake",
            "zh-Hans": "关东大地震",
            "zh-Hant": "關東大地震",
        },
        "desc": {
            "en": "A quake of about magnitude 7.9 struck the Tokyo and Yokohama plain around noon on 1 September 1923. The fires that followed did most of the killing; counts of the dead and missing run from about 105,000 to 140,000, and it is the deadliest natural disaster in Japan's recorded history.",
            "zh-Hans": "1923年9月1日近正午，东京、横滨一带发生约7.9级地震。随后的大火造成绝大部分死亡；死亡与失踪合计的估数在约十万五千至十四万之间，是日本有记载以来最惨重的天灾。",
            "zh-Hant": "1923年9月1日近正午，東京、橫濱一帶發生約7.9級地震。隨後的大火造成絕大部分死亡；死亡與失蹤合計的估數在約十萬五千至十四萬之間，是日本有記載以來最慘重的天災。",
        },
    },
]

# --- the three that draw something twice -----------------------------

REMOVE_EVENTS = {
    'special_relativity',
    'powered_flight',
    'columbian_exchange',
    'movable_type_china',
}

# The survivor of each pair, corrected. `einstein_relativity` keeps the
# id but takes the narrower title, because a spoke standing on 1905 may
# not describe 1915; and it moves to `europe`, which is where Bern is —
# `world` is not a place.
EDIT_EVENTS = {
    'einstein_relativity': {
        'stream': 'europe',
        'title': {
            "en": "Einstein Publishes Special Relativity",
            "zh-Hans": "爱因斯坦发表狭义相对论",
            "zh-Hant": "愛因斯坦發表狹義相對論",
        },
        'desc': {
            "en": "Space and time are shown to depend on the observer's motion, and mass to be a form of energy. The general theory of gravity followed ten years later.",
            "zh-Hans": "空间与时间被证明取决于观测者的运动，质量亦是能量的一种形式。十年之后又有广义相对论。",
            "zh-Hant": "空間與時間被證明取決於觀測者的運動，質量亦是能量的一種形式。十年之後又有廣義相對論。",
        },
    },
    # Kitty Hawk is in North Carolina, so the survivor takes the stream
    # the removed twin had.
    'wright_first_flight': {
        'stream': 'americas',
    },
    # The survivor of the Bi Sheng pair keeps the date its own source
    # supports and inherits the comparison the deleted record made,
    # which is the part a reader of a Bible-study chart actually wants:
    # China had this four centuries before Europe.
    'bi_sheng_movable_type': {
        'desc': {
            "en": "Shen Kuo records Bi Sheng cutting movable type in fired clay, some time between 1041 and 1048 — four centuries before movable type reaches Europe.",
            "zh-Hans": "沈括记载毕昇于1041至1048年间以胶泥刻制活字，比活字印刷传入欧洲早了四百年。",
            "zh-Hant": "沈括記載畢昇於1041至1048年間以膠泥刻製活字，比活字印刷傳入歐洲早了四百年。",
        },
    },
    # The one true sentence of the deleted 1500 record, moved onto the
    # 1492 landfall it actually belongs to.
    'columbus_caribbean': {
        'desc': {
            "en": "Three Spanish ships make landfall in the Bahamas, opening permanent contact between Europe and America, and with it a lasting exchange of people, crops and diseases between the two hemispheres.",
            "zh-Hans": "三艘西班牙船只在巴哈马登陆，欧洲与美洲自此长期接触，两个半球之间的人口、作物与疾病也从此长期交流。",
            "zh-Hant": "三艘西班牙船隻在巴哈馬登陸，歐洲與美洲自此長期接觸，兩個半球之間的人口、作物與疾病也從此長期交流。",
        },
    },
}


def main() -> None:
    raw = ASSET.read_text()
    data = json.loads(raw)

    before = {'events': len(data['events']), 'powers': len(data['powers'])}

    existing = {
        r['id']
        for k in ('events', 'powers', 'nations', 'ministries', 'omissions', 'streams')
        for r in data[k]
    }
    for rec in NEW_POWERS + NEW_EVENTS:
        if rec['id'] in existing:
            raise SystemExit(f"id already present: {rec['id']}")

    for eid in REMOVE_EVENTS:
        if not any(e['id'] == eid for e in data['events']):
            raise SystemExit(f"nothing to remove under id: {eid}")
    data['events'] = [e for e in data['events'] if e['id'] not in REMOVE_EVENTS]

    for eid, patch in EDIT_EVENTS.items():
        hit = [e for e in data['events'] if e['id'] == eid]
        if len(hit) != 1:
            raise SystemExit(f"expected exactly one {eid}, found {len(hit)}")
        hit[0].update(patch)

    # APPENDED, NOT SORTED. Every earlier pass appended, so the arrays
    # are already in arrival order rather than year order; re-sorting
    # them here would rewrite 1,124 records to move 8, and this checkout
    # is shared. The wheel sorts by year when it draws.
    data['events'].extend(NEW_EVENTS)
    data['powers'].extend(NEW_POWERS)

    ASSET.write_text(json.dumps(data, indent=1, ensure_ascii=False) + '\n')

    after = {'events': len(data['events']), 'powers': len(data['powers'])}
    print(f"events {before['events']} -> {after['events']}  "
          f"(removed {len(REMOVE_EVENTS)}, added {len(NEW_EVENTS)})")
    print(f"powers {before['powers']} -> {after['powers']}  "
          f"(added {len(NEW_POWERS)})")


if __name__ == '__main__':
    main()
