#!/usr/bin/env python3
"""Build assets/hebrew_kings.json — the kings of Judah and Israel on
Thiele's chronology.

WHY A SCRIPT AND NOT A HAND-WRITTEN ASSET
-----------------------------------------
A JSON file of ancient dates is indistinguishable, by inspection, from a
JSON file of invented ancient dates. `assets/bible_geo.json` arrived in
this repo with a provenance claim and no generator, and verifying it
after the fact cost a whole iteration. So the source table lives here,
in the open, next to the citation for every figure.

SOURCES
-------
[T]  Edwin R. Thiele, *The Mysterious Numbers of the Hebrew Kings*,
     3rd ed. (Grand Rapids: Zondervan/Kregel, 1983). The chronology
     itself. Not consulted directly; used through [W] and [M] below,
     both of which reproduce and attribute it.

[W]  Wikipedia, "Kings of Judah" and "Kings of Israel (Samaria)", the
     columns explicitly headed *Thiele* (retrieved 2026-08-08). These
     give each king's reign span as Thiele reckoned it.

[M]  Leslie McFall, "A Translation Guide to the Chronological Data in
     Kings and Chronicles", *Bibliotheca Sacra* 148 (1991): 3-45.
     McFall builds on Thiele and marks every departure from him. His
     summary of "nine minor alterations" and "four coregencies that
     Thiele overlooked" states Thiele's own figure in each case, which
     is how the co-regency years below are sourced — Wikipedia's
     columns collapse a co-regency into the sole reign and so cannot
     supply them.

[C]  The accession synchronism verse for each king was read out of this
     repo's own `assets/cuvs-yhwh.json` / `-tr.json`, which is also
     where every Chinese name below was verified rather than recalled.

WHY ONLY THIELE
---------------
The user settled this on 2026-08-08: Thiele is the reconstruction most
used in churches, and building a three-way switcher would triple the
sourcing burden for a question already answered. `system` is a named
field so another system could be added later without a migration, but
no second system is offered and none should be implied.

DATES ARE NOT ARITHMETIC
------------------------
Nothing here is derived from the regnal-year totals in Kings. Accession
vs non-accession reckoning, Nisan vs Tishri new year, and co-regencies
are precisely what Thiele's system resolves; naive arithmetic over the
biblical totals contradicts him. Every figure is copied from [W] or [M].

DUAL YEARS
----------
Thiele writes many dates as a pair (792/791) because a Hebrew regnal
year straddles two Julian years. The integers below are the conventional
single-year form as [W] reproduces it; `_meta.note` says so in the asset
so no reader mistakes them for precision they do not have.

Run:  python3 scripts/build_hebrew_kings.py
"""

import json
import os
import re

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "hebrew_kings.json")

# Span kinds:
#   sole      — reigning alone
#   coregency — reigning alongside his father, per Thiele
#   rival     — a contested parallel reign (Tibni against Omri; Pekah in
#               Gilead against Menahem and Pekahiah)
#
# Years are negative for BC, matching assets/bible_timeline.json and
# assets/family_tree.json.

UNITED = [
    # [M] chart: David APR 1010 - APR 971/970; Solomon APR 970 - 931.
    dict(
        id="david", house="david",
        en="David", zh_hans="大卫", zh_hant="大衛",
        spans=[("sole", -1010, -970)],
        kings_ref="1 Kings 1:1-2:11", chron_ref="1 Chronicles 11-29",
        accession_ref=None,
    ),
    dict(
        id="solomon", house="david",
        en="Solomon", zh_hans="所罗门", zh_hant="所羅門",
        spans=[("sole", -970, -931)],
        kings_ref="1 Kings 2:11-11:43", chron_ref="2 Chronicles 1-9",
        accession_ref=None,
    ),
]

# ---------------------------------------------------------------------
# JUDAH — spans from [W] Thiele column; co-regency starts from [M].
# ---------------------------------------------------------------------
JUDAH = [
    dict(id="rehoboam", house="david", en="Rehoboam",
         zh_hans="罗波安", zh_hant="羅波安",
         spans=[("sole", -931, -913)],
         kings_ref="1 Kings 14:21-31", chron_ref="2 Chronicles 10-12",
         accession_ref="1 Kings 12:1"),
    dict(id="abijah", house="david", en="Abijah",
         alt_en="Abijam", zh_hans="亚比雅", zh_hant="亞比雅",
         alt_zh_hans="亚比央", alt_zh_hant="亞比央",
         spans=[("sole", -913, -911)],
         kings_ref="1 Kings 15:1-8", chron_ref="2 Chronicles 13",
         accession_ref="1 Kings 15:1"),
    dict(id="asa", house="david", en="Asa",
         zh_hans="亚撒", zh_hant="亞撒",
         spans=[("sole", -911, -870)],
         kings_ref="1 Kings 15:9-24", chron_ref="2 Chronicles 14-16",
         accession_ref="1 Kings 15:9"),
    # [M] "Jehoshaphat became coregent in September 873, not 872/871"
    # — i.e. Thiele's figure is 872/871.
    dict(id="jehoshaphat", house="david", en="Jehoshaphat",
         zh_hans="约沙法", zh_hant="約沙法",
         spans=[("coregency", -872, -870), ("sole", -870, -848)],
         kings_ref="1 Kings 22:41-51", chron_ref="2 Chronicles 17-20",
         accession_ref="1 Kings 22:41"),
    # [M] "Jehoram of Judah became coregent in September 854, not 853."
    dict(id="jehoram_judah", house="david", en="Jehoram",
         alt_en="Joram", zh_hans="约兰", zh_hant="約蘭",
         spans=[("coregency", -853, -848), ("sole", -848, -841)],
         kings_ref="2 Kings 8:16-24", chron_ref="2 Chronicles 21",
         accession_ref="2 Kings 8:16"),
    dict(id="ahaziah_judah", house="david", en="Ahaziah",
         alt_en="Jehoahaz", zh_hans="亚哈谢", zh_hant="亞哈謝",
         spans=[("sole", -841, -841)],
         kings_ref="2 Kings 8:25-9:29", chron_ref="2 Chronicles 22:1-9",
         accession_ref="2 Kings 8:25",
         note_en="Reigned one year. Killed by Jehu in the same purge that "
                 "ended the house of Omri in Israel.",
         note_zh_hans="在位一年，与以色列暗利家同在耶户的清洗中被杀。",
         note_zh_hant="在位一年，與以色列暗利家同在耶戶的清洗中被殺。"),
    dict(id="athaliah", house="omri", en="Athaliah",
         zh_hans="亚他利雅", zh_hant="亞他利雅",
         spans=[("sole", -841, -835)],
         kings_ref="2 Kings 11:1-21", chron_ref="2 Chronicles 22:10-23:21",
         accession_ref="2 Kings 11:1",
         note_en="The one break in the Davidic line: a queen of the house "
                 "of Omri who seized Judah's throne after her son died.",
         note_zh_hans="大卫王朝唯一的中断：暗利家的王后在儿子死后夺取犹大王位。",
         note_zh_hant="大衛王朝唯一的中斷：暗利家的王后在兒子死後奪取猶大王位。"),
    dict(id="joash_judah", house="david", en="Joash",
         alt_en="Jehoash", zh_hans="约阿施", zh_hant="約阿施",
         spans=[("sole", -835, -796)],
         kings_ref="2 Kings 12:1-21", chron_ref="2 Chronicles 24",
         accession_ref="2 Kings 12:1"),
    dict(id="amaziah", house="david", en="Amaziah",
         zh_hans="亚玛谢", zh_hant="亞瑪謝",
         spans=[("sole", -796, -767)],
         kings_ref="2 Kings 14:1-22", chron_ref="2 Chronicles 25",
         accession_ref="2 Kings 14:1"),
    # [M] "Azariah became coregent in September 791, not 792/791" —
    # Thiele's figure is 792/791.
    dict(id="uzziah", house="david", en="Uzziah",
         alt_en="Azariah", zh_hans="乌西雅", zh_hant="烏西雅",
         alt_zh_hans="亚撒利雅", alt_zh_hant="亞撒利雅",
         spans=[("coregency", -792, -767), ("sole", -767, -740)],
         kings_ref="2 Kings 15:1-7", chron_ref="2 Chronicles 26",
         accession_ref="2 Kings 15:1",
         note_en="Struck with leprosy, after which his son Jotham governed "
                 "the household (2 Chronicles 26:21) — the reason Thiele "
                 "reads a second co-regency at the other end of his reign.",
         note_zh_hans="后来长大痲疯，由儿子约坦管理家事（历代志下26:21）；"
                      "这正是锡尔在其在位末期另立摄政的理由。",
         note_zh_hant="後來長大痲瘋，由兒子約坦管理家事（歷代志下26:21）；"
                      "這正是錫爾在其在位末期另立攝政的理由。"),
    dict(id="jotham", house="david", en="Jotham",
         zh_hans="约坦", zh_hant="約坦",
         spans=[("coregency", -750, -740), ("sole", -740, -732)],
         kings_ref="2 Kings 15:32-38", chron_ref="2 Chronicles 27",
         accession_ref="2 Kings 15:32"),
    dict(id="ahaz", house="david", en="Ahaz",
         zh_hans="亚哈斯", zh_hant="亞哈斯",
         spans=[("coregency", -735, -732), ("sole", -732, -716)],
         kings_ref="2 Kings 16:1-20", chron_ref="2 Chronicles 28",
         accession_ref="2 Kings 16:1"),
    dict(id="hezekiah", house="david", en="Hezekiah",
         zh_hans="希西家", zh_hant="希西家",
         spans=[("sole", -716, -687)],
         kings_ref="2 Kings 18:1-20:21", chron_ref="2 Chronicles 29-32",
         accession_ref="2 Kings 18:1",
         note_en="Thiele gives Hezekiah no co-regency. Later scholars, "
                 "McFall among them, argue for one from 729 BC; that "
                 "reading is outside Thiele's system and is not charted "
                 "here.",
         note_zh_hans="锡尔未给希西家设摄政期。后来学者（如麦克福尔）主张自"
                      "公元前729年起有摄政；该说不属锡尔系统，本表不列。",
         note_zh_hant="錫爾未給希西家設攝政期。後來學者（如麥克福爾）主張自"
                      "公元前729年起有攝政；該說不屬錫爾系統，本表不列。"),
    # [M] "Manasseh became coregent in September 697, not 697/696."
    dict(id="manasseh", house="david", en="Manasseh",
         zh_hans="玛拿西", zh_hant="瑪拿西",
         spans=[("coregency", -697, -687), ("sole", -687, -643)],
         kings_ref="2 Kings 21:1-18", chron_ref="2 Chronicles 33:1-20",
         accession_ref="2 Kings 21:1"),
    dict(id="amon", house="david", en="Amon",
         zh_hans="亚们", zh_hant="亞們",
         spans=[("sole", -643, -641)],
         kings_ref="2 Kings 21:19-26", chron_ref="2 Chronicles 33:21-25",
         accession_ref="2 Kings 21:19"),
    dict(id="josiah", house="david", en="Josiah",
         zh_hans="约西亚", zh_hant="約西亞",
         spans=[("sole", -641, -609)],
         kings_ref="2 Kings 22:1-23:30", chron_ref="2 Chronicles 34-35",
         accession_ref="2 Kings 22:1"),
    dict(id="jehoahaz_judah", house="david", en="Jehoahaz",
         alt_en="Shallum", zh_hans="约哈斯", zh_hant="約哈斯",
         spans=[("sole", -609, -609)],
         kings_ref="2 Kings 23:31-35", chron_ref="2 Chronicles 36:1-3",
         accession_ref="2 Kings 23:31",
         note_en="Three months, then deposed by Pharaoh Necho.",
         note_zh_hans="在位三个月，被法老尼哥废黜。",
         note_zh_hant="在位三個月，被法老尼哥廢黜。"),
    dict(id="jehoiakim", house="david", en="Jehoiakim",
         alt_en="Eliakim", zh_hans="约雅敬", zh_hant="約雅敬",
         spans=[("sole", -609, -598)],
         kings_ref="2 Kings 23:36-24:7", chron_ref="2 Chronicles 36:4-8",
         accession_ref="2 Kings 23:36"),
    dict(id="jehoiachin", house="david", en="Jehoiachin",
         alt_en="Jeconiah, Coniah", zh_hans="约雅斤", zh_hant="約雅斤",
         spans=[("sole", -598, -597)],
         kings_ref="2 Kings 24:8-17", chron_ref="2 Chronicles 36:9-10",
         accession_ref="2 Kings 24:8",
         note_en="Three months, then carried to Babylon. Released from "
                 "prison there long after (2 Kings 25:27-30).",
         note_zh_hans="在位三个月即被掳往巴比伦，多年后获释出监"
                      "（列王纪下25:27-30）。",
         note_zh_hant="在位三個月即被擄往巴比倫，多年後獲釋出監"
                      "（列王紀下25:27-30）。"),
    dict(id="zedekiah", house="david", en="Zedekiah",
         alt_en="Mattaniah", zh_hans="西底家", zh_hant="西底家",
         spans=[("sole", -597, -586)],
         kings_ref="2 Kings 24:18-25:7", chron_ref="2 Chronicles 36:11-21",
         accession_ref="2 Kings 24:18",
         note_en="The last king of Judah. Jerusalem fell in his eleventh "
                 "year.",
         note_zh_hans="犹大末代君王，耶路撒冷于其在位第十一年陷落。",
         note_zh_hant="猶大末代君王，耶路撒冷於其在位第十一年陷落。"),
]

# ---------------------------------------------------------------------
# ISRAEL — spans from [W] Thiele column; Jeroboam II's co-regency from
# [M] ("Jeroboam II became coregent in April 793, not 793/792 or 792
# (Thiele, p. 96)"). Chronicles has no parallel account of the northern
# kingdom, so `chron_ref` is null throughout — that absence is itself
# information and the UI says so rather than hiding the row.
# ---------------------------------------------------------------------
ISRAEL = [
    dict(id="jeroboam_i", house="jeroboam_i", en="Jeroboam I",
         zh_hans="耶罗波安", zh_hant="耶羅波安",
         spans=[("sole", -931, -910)],
         kings_ref="1 Kings 12:1-14:20", chron_ref=None,
         accession_ref="1 Kings 12:20"),
    dict(id="nadab", house="jeroboam_i", en="Nadab",
         zh_hans="拿答", zh_hant="拿答",
         spans=[("sole", -910, -909)],
         kings_ref="1 Kings 15:25-32", chron_ref=None,
         accession_ref="1 Kings 15:25"),
    dict(id="baasha", house="baasha", en="Baasha",
         zh_hans="巴沙", zh_hant="巴沙",
         spans=[("sole", -909, -886)],
         kings_ref="1 Kings 15:33-16:7", chron_ref=None,
         accession_ref="1 Kings 15:33"),
    dict(id="elah", house="baasha", en="Elah",
         zh_hans="以拉", zh_hant="以拉",
         spans=[("sole", -886, -885)],
         kings_ref="1 Kings 16:8-14", chron_ref=None,
         accession_ref="1 Kings 16:8"),
    dict(id="zimri", house="zimri", en="Zimri",
         zh_hans="心利", zh_hant="心利",
         spans=[("sole", -885, -885)],
         kings_ref="1 Kings 16:15-20", chron_ref=None,
         accession_ref="1 Kings 16:15",
         note_en="Seven days — the shortest reign in either kingdom.",
         note_zh_hans="在位七日，两国之中最短。",
         note_zh_hant="在位七日，兩國之中最短。"),
    dict(id="tibni", house="tibni", en="Tibni",
         zh_hans="提比尼", zh_hant="提比尼",
         spans=[("rival", -885, -880)],
         kings_ref="1 Kings 16:21-22", chron_ref=None,
         accession_ref="1 Kings 16:21",
         note_en="Never reigned alone: half of Israel followed him and "
                 "half followed Omri for about five years.",
         note_zh_hans="从未独自作王：以色列民分为两半，一半随从他，一半随从"
                      "暗利，约五年之久。",
         note_zh_hant="從未獨自作王：以色列民分為兩半，一半隨從他，一半隨從"
                      "暗利，約五年之久。"),
    dict(id="omri", house="omri", en="Omri",
         zh_hans="暗利", zh_hant="暗利",
         spans=[("rival", -885, -880), ("sole", -880, -874)],
         kings_ref="1 Kings 16:23-28", chron_ref=None,
         accession_ref="1 Kings 16:23",
         note_en="Bought the hill of Samaria and made it the northern "
                 "capital; Assyrian records call Israel 'the house of "
                 "Omri' long after his dynasty ended.",
         note_zh_hans="购撒玛利亚山，立为北国京都；其王朝覆亡后多年，亚述文献"
                      "仍称以色列为「暗利家」。",
         note_zh_hant="購撒瑪利亞山，立為北國京都；其王朝覆亡後多年，亞述文獻"
                      "仍稱以色列為「暗利家」。"),
    dict(id="ahab", house="omri", en="Ahab",
         zh_hans="亚哈", zh_hant="亞哈",
         spans=[("sole", -874, -853)],
         kings_ref="1 Kings 16:29-22:40", chron_ref=None,
         accession_ref="1 Kings 16:29"),
    dict(id="ahaziah_israel", house="omri", en="Ahaziah",
         zh_hans="亚哈谢", zh_hant="亞哈謝",
         spans=[("sole", -853, -852)],
         # His account straddles the book division (1 Kings 22:51 - 2
         # Kings 1:18), which the app's reference parser cannot express
         # and which would make the row a dead tap. The accession
         # formula in 1 Kings is carried by accession_ref, so this
         # points at the narrative proper.
         kings_ref="2 Kings 1:1-18", chron_ref=None,
         accession_ref="1 Kings 22:51"),
    dict(id="joram_israel", house="omri", en="Joram",
         alt_en="Jehoram", zh_hans="约兰", zh_hant="約蘭",
         spans=[("sole", -852, -841)],
         kings_ref="2 Kings 3:1-8:15", chron_ref=None,
         accession_ref="2 Kings 3:1"),
    dict(id="jehu", house="jehu", en="Jehu",
         zh_hans="耶户", zh_hant="耶戶",
         spans=[("sole", -841, -814)],
         kings_ref="2 Kings 9:30-10:36", chron_ref=None,
         accession_ref="2 Kings 10:36",
         note_en="841 BC is the anchor: the Black Obelisk records Jehu's "
                 "tribute in Shalmaneser III's eighteenth year, one of the "
                 "fixed points Thiele's whole reconstruction hangs on.",
         note_zh_hans="公元前841年是定点：黑方尖碑记载耶户在撒缦以色三世第十八年"
                      "进贡，为锡尔整个系统所依据的固定年代之一。",
         note_zh_hant="公元前841年是定點：黑方尖碑記載耶戶在撒縵以色三世第十八年"
                      "進貢，為錫爾整個系統所依據的固定年代之一。"),
    dict(id="jehoahaz_israel", house="jehu", en="Jehoahaz",
         zh_hans="约哈斯", zh_hant="約哈斯",
         spans=[("sole", -814, -798)],
         kings_ref="2 Kings 13:1-9", chron_ref=None,
         accession_ref="2 Kings 13:1"),
    dict(id="jehoash_israel", house="jehu", en="Jehoash",
         alt_en="Joash", zh_hans="约阿施", zh_hant="約阿施",
         spans=[("sole", -798, -782)],
         kings_ref="2 Kings 13:10-25", chron_ref=None,
         accession_ref="2 Kings 13:10"),
    dict(id="jeroboam_ii", house="jehu", en="Jeroboam II",
         zh_hans="耶罗波安二世", zh_hant="耶羅波安二世",
         spans=[("coregency", -793, -782), ("sole", -782, -753)],
         kings_ref="2 Kings 14:23-29", chron_ref=None,
         accession_ref="2 Kings 14:23",
         note_en="The one co-regency Thiele finds in the northern kingdom.",
         note_zh_hans="锡尔在北国所认定的唯一一次摄政。",
         note_zh_hant="錫爾在北國所認定的唯一一次攝政。"),
    dict(id="zechariah_israel", house="jehu", en="Zechariah",
         zh_hans="撒迦利雅", zh_hant="撒迦利雅",
         spans=[("sole", -753, -752)],
         kings_ref="2 Kings 15:8-12", chron_ref=None,
         accession_ref="2 Kings 15:8",
         note_en="Six months. The last of Jehu's house, as promised to "
                 "Jehu to the fourth generation.",
         note_zh_hans="在位六个月。耶户家末代，应验神应许耶户的四代之限。",
         note_zh_hant="在位六個月。耶戶家末代，應驗神應許耶戶的四代之限。"),
    dict(id="shallum_israel", house="shallum", en="Shallum",
         zh_hans="沙龙", zh_hant="沙龍",
         spans=[("sole", -752, -752)],
         kings_ref="2 Kings 15:13-15", chron_ref=None,
         accession_ref="2 Kings 15:13",
         note_en="One month.",
         note_zh_hans="在位一个月。",
         note_zh_hant="在位一個月。"),
    dict(id="menahem", house="menahem", en="Menahem",
         zh_hans="米拿现", zh_hant="米拿現",
         spans=[("sole", -752, -742)],
         kings_ref="2 Kings 15:16-22", chron_ref=None,
         accession_ref="2 Kings 15:17"),
    dict(id="pekahiah", house="menahem", en="Pekahiah",
         zh_hans="比加辖", zh_hant="比加轄",
         spans=[("sole", -742, -740)],
         kings_ref="2 Kings 15:23-26", chron_ref=None,
         accession_ref="2 Kings 15:23"),
    dict(id="pekah", house="pekah", en="Pekah",
         zh_hans="比加", zh_hant="比加",
         spans=[("rival", -752, -740), ("sole", -740, -732)],
         kings_ref="2 Kings 15:27-31", chron_ref=None,
         accession_ref="2 Kings 15:27",
         note_en="2 Kings 15:27 gives Pekah twenty years, which will not "
                 "fit after Pekahiah. Thiele reads the first twelve as a "
                 "rival reign in Gilead, running alongside Menahem and "
                 "Pekahiah in Samaria — one of the load-bearing moves of "
                 "his system.",
         note_zh_hans="列王纪下15:27记比加在位二十年，若排在比加辖之后则无法容纳。"
                      "锡尔视其前十二年为在基列的对立王权，与撒玛利亚的米拿现、"
                      "比加辖并行——这是其系统的关键一环。",
         note_zh_hant="列王紀下15:27記比加在位二十年，若排在比加轄之後則無法容納。"
                      "錫爾視其前十二年為在基列的對立王權，與撒瑪利亞的米拿現、"
                      "比加轄並行——這是其系統的關鍵一環。"),
    dict(id="hoshea", house="hoshea", en="Hoshea",
         zh_hans="何细亚", zh_hant="何細亞",
         spans=[("sole", -732, -722)],
         kings_ref="2 Kings 17:1-41", chron_ref=None,
         accession_ref="2 Kings 17:1",
         note_en="The last king of Israel. Samaria fell and the northern "
                 "kingdom ended; the Israel column stops here.",
         note_zh_hans="以色列末代君王。撒玛利亚陷落，北国灭亡；以色列一栏至此为止。",
         note_zh_hant="以色列末代君王。撒瑪利亞陷落，北國滅亡；以色列一欄至此為止。"),
]

# Full-width markers. 931 / 722 / 586 were named by the user; 841 is
# added because it is Thiele's own anchor (Jehu's tribute) and explains
# why the chart's dates are what they are.
EPOCHS = [
    dict(id="division", year=-931,
         en="The kingdom divides", zh_hans="王国分裂", zh_hant="王國分裂",
         ref="1 Kings 12:16-20"),
    dict(id="jehu_tribute", year=-841,
         en="Jehu pays tribute to Shalmaneser III",
         zh_hans="耶户向撒缦以色三世进贡",
         zh_hant="耶戶向撒縵以色三世進貢",
         ref="2 Kings 10:32"),
    dict(id="samaria", year=-722,
         en="Samaria falls; Israel ends",
         zh_hans="撒玛利亚陷落，以色列亡",
         zh_hant="撒瑪利亞陷落，以色列亡",
         ref="2 Kings 17:5-6"),
    dict(id="jerusalem", year=-586,
         en="Jerusalem falls; Judah ends",
         zh_hans="耶路撒冷陷落，犹大亡",
         zh_hant="耶路撒冷陷落，猶大亡",
         ref="2 Kings 25:8-10"),
]


def build_king(k, kingdom):
    spans = [dict(kind=s[0], start=s[1], end=s[2]) for s in k["spans"]]
    out = {
        "id": k["id"],
        "kingdom": kingdom,
        "house": k["house"],
        "name": {"en": k["en"], "zh-Hans": k["zh_hans"], "zh-Hant": k["zh_hant"]},
        "spans": spans,
        "reignStart": spans[0]["start"],
        "reignEnd": spans[-1]["end"],
        "kingsRef": k["kings_ref"],
        "chroniclesRef": k["chron_ref"],
        "accessionRef": k["accession_ref"],
    }
    if k.get("alt_en"):
        out["altName"] = {
            "en": k["alt_en"],
            "zh-Hans": k.get("alt_zh_hans") or k["alt_en"],
            "zh-Hant": k.get("alt_zh_hant") or k["alt_en"],
        }
    if k.get("note_en"):
        out["note"] = {
            "en": k["note_en"],
            "zh-Hans": k["note_zh_hans"],
            "zh-Hant": k["note_zh_hant"],
        }
    return out


def main():
    kings = (
        [build_king(k, "united") for k in UNITED]
        + [build_king(k, "judah") for k in JUDAH]
        + [build_king(k, "israel") for k in ISRAEL]
    )

    # Sanity checks. These are cheap and they are the difference between
    # a table and a table you can trust.
    seen = set()
    for k in kings:
        assert k["id"] not in seen, f"duplicate id {k['id']}"
        seen.add(k["id"])
        assert k["spans"], f"{k['id']} has no spans"
        for s in k["spans"]:
            assert s["start"] <= s["end"], f"{k['id']} span runs backwards"
            assert -1100 < s["start"] < -500, f"{k['id']} start out of range"
        for a, b in zip(k["spans"], k["spans"][1:]):
            assert a["end"] == b["start"], (
                f"{k['id']}: co-regency must hand over to the sole reign "
                f"at one year, got {a['end']} -> {b['start']}"
            )
        assert sum(1 for s in k["spans"] if s["kind"] == "sole") <= 1, (
            f"{k['id']} has more than one sole reign"
        )

    # Within a kingdom the throne is never vacant: every year from the
    # division to the fall is covered by somebody's sole reign, or — for
    # the two contested stretches — by a rival claim.
    #
    # The naive form of this check (sole reigns tile the axis end to end)
    # fails on Israel at 885-880, and it is right to fail: between
    # Zimri's death and Omri's sole reign the kingdom had no single
    # recognised king, only Omri and Tibni against each other. That gap
    # is a fact about the period, so the invariant has to be stated over
    # sole-and-rival together.
    for kingdom, expect_end in (("judah", -586), ("israel", -722)):
        held = sorted(
            (s["start"], s["end"], k["id"])
            for k in kings
            if k["kingdom"] == kingdom
            for s in k["spans"]
            if s["kind"] in ("sole", "rival")
        )
        assert held[0][0] == -931, f"{kingdom} does not begin at 931 BC"
        reach = held[0][1]
        for start, end, kid in held[1:]:
            assert start <= reach, (
                f"{kingdom}: throne vacant between {reach} and {start} "
                f"(before {kid})"
            )
            reach = max(reach, end)
        assert reach == expect_end, (
            f"{kingdom} runs to {reach}, expected {expect_end}"
        )

    # Two sole reigns in one kingdom may touch at a year boundary but
    # must never overlap — that is what "sole" means, and it is the
    # check that would catch a mistyped date.
    for kingdom in ("judah", "israel"):
        sole = sorted(
            (s["start"], s["end"], k["id"])
            for k in kings
            if k["kingdom"] == kingdom
            for s in k["spans"]
            if s["kind"] == "sole"
        )
        for (_, enda, ida), (startb, _, idb) in zip(sole, sole[1:]):
            assert startb >= enda, (
                f"{kingdom}: sole reigns of {ida} and {idb} overlap"
            )

    # Every reference has to be one the app's parser can resolve, or the
    # detail panel offers a row that does nothing when tapped. The parser
    # has no notion of a range that crosses a book boundary, so a second
    # book name after the dash is the failure mode to catch.
    for k in kings:
        for field in ("kingsRef", "chroniclesRef", "accessionRef"):
            ref = k[field]
            if ref and re.search(r"-\s*\d?\s*[A-Za-z]", ref):
                raise AssertionError(
                    f"{k['id']}.{field} spans two books: {ref!r}"
                )

    doc = {
        "schemaVersion": 1,
        "system": "thiele",
        "systemName": {
            "en": "Thiele",
            "zh-Hans": "锡尔年代系统",
            "zh-Hant": "錫爾年代系統",
        },
        "_meta": {
            "generator": "scripts/build_hebrew_kings.py",
            "kingCount": len(kings),
            "note": (
                "Years are negative for BC. Thiele frequently writes a "
                "date as a pair (792/791) because a Hebrew regnal year "
                "straddles two Julian years; the single years here are "
                "the conventional reproduction of his figures, not a "
                "claim of greater precision."
            ),
            "systems": (
                "Chronologies of the Hebrew kings differ over Nisan vs "
                "Tishri new year, accession vs non-accession year "
                "reckoning, co-regencies, and the Assyrian synchronisms. "
                "Albright, Galil and Kitchen each give different dates. "
                "This chart follows Thiele throughout and offers no "
                "other system."
            ),
            "sources": [
                "Edwin R. Thiele, The Mysterious Numbers of the Hebrew "
                "Kings, 3rd ed. (Grand Rapids: Zondervan/Kregel, 1983).",
                "Leslie McFall, 'A Translation Guide to the Chronological "
                "Data in Kings and Chronicles', Bibliotheca Sacra 148 "
                "(1991): 3-45 — source of the co-regency years, which "
                "McFall states for Thiele in the course of departing "
                "from them.",
                "Wikipedia, 'Kings of Judah' and 'Kings of Israel "
                "(Samaria)', Thiele columns (retrieved 2026-08-08).",
            ],
        },
        "epochs": [
            {
                "id": e["id"],
                "year": e["year"],
                "name": {
                    "en": e["en"],
                    "zh-Hans": e["zh_hans"],
                    "zh-Hant": e["zh_hant"],
                },
                "ref": e["ref"],
            }
            for e in EPOCHS
        ],
        "kings": kings,
    }

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"wrote {OUT}: {len(kings)} kings, {len(EPOCHS)} epochs")


if __name__ == "__main__":
    main()
