#!/usr/bin/env python3
"""Fill the modern and medieval holes in the wheel's power bands.

2026-09-16, reported twice by the owner: 「中国还有很多其他的在清朝之后
很多 都missing了在strip里面」 and 「还有很多节点发生的大事件在strip上就
是空的」.

Measured before writing. The China lane stopped at 1912 — 114 years
blank. It was not the worst: Japan stopped at AD 628, so 1,398 years
of a lane a reader can see were empty; India had holes of 940, 684 and
169 years; the Americas stopped at 1533, 493 years short of the axis;
and the catch-all lane's Korean chain stopped at 108 BC.

That is squarely against the file's own stated coverage — 「若无后者，
读者自身所经历的那几个世纪反而会是全图最空白的部分」.

NOT ADDED. The Republic of China on Taiwan after 1949 — 「台湾那个暂时
不用提 很敏感」. The mainland state from 1949 is drawn, which is what
the owner asked for in the same breath.

The two Koreas from 1948 WERE asked for — 「1948后可以韩国 朝鲜」 — and
are drawn as two open bands on the same lane, which is what the lane
already does for polities that share a region and a century.
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'wheel_history.json')


def p(pid, stream, region, start, end, en, hans, hant,
      note_en, note_hans, note_hant, approximate=False):
    row = {
        'id': pid,
        'start': start,
        'end': end,
        'region': region,
        'stream': stream,
        'approximate': approximate,
        'basis': 'conventional',
        'name': {'en': en, 'zh-Hans': hans, 'zh-Hant': hant},
        'note': {'en': note_en, 'zh-Hans': note_hans, 'zh-Hant': note_hant},
    }
    if end is None:
        # The shape `state-of-israel` and `pope-leo-xiv` already use.
        row = {'id': pid, 'start': start, 'end': None, 'ongoing': True,
               'region': region, 'stream': stream,
               'approximate': approximate, 'basis': 'conventional',
               'name': row['name'], 'note': row['note']}
    return row


NEW = [
    # ── 中国 ────────────────────────────────────────────────────────
    p('republic-of-china', 'china', 'asia', 1912, 1949,
      'Republic of China', '中华民国', '中華民國',
      "Proclaimed at the Qing abdication and governing the mainland "
      "until 1949. These years hold the May Fourth movement, the "
      "warlords, the Japanese invasion, and the widest reach the "
      "missionary societies ever had in China.",
      '清帝退位后成立，统治中国大陆至1949年。这几十年间有五四运动、军阀'
      '混战、日本入侵，也是宣教差会在华影响最广的时期。',
      '清帝退位後成立，統治中國大陸至1949年。這幾十年間有五四運動、軍閥'
      '混戰、日本入侵，也是宣教差會在華影響最廣的時期。'),
    p('warlord-era-china', 'china', 'asia', 1916, 1928,
      'Warlord Era in China', '军阀割据', '軍閥割據',
      "Between Yuan Shikai's death and the Northern Expedition's "
      "nominal reunification, the republic's authority was divided "
      "among regional armies. Drawn inside the Republic's own band, as "
      "the Three Kingdoms are drawn inside China's chain.",
      '自袁世凯去世至北伐名义上统一全国，民国政令分散于各地军队之手。此'
      '段画在中华民国的带子里，如同三国画在中国这条链上。',
      '自袁世凱去世至北伐名義上統一全國，民國政令分散於各地軍隊之手。此'
      '段畫在中華民國的帶子裡，如同三國畫在中國這條鏈上。',
      approximate=True),
    p('peoples-republic-of-china', 'china', 'asia', 1949, None,
      "People's Republic of China", '中华人民共和国', '中華人民共和國',
      "Established in 1949. The chart already carries its events — the "
      "missionaries' withdrawal, the Three-Self movement, the Cultural "
      "Revolution's closing of the churches, the reopening of 1979. The "
      "band is drawn open because the state has not ended.",
      '1949年成立。本图已载有其间的事件——宣教士撤离、三自爱国运动、文化'
      '大革命关闭教会、1979年教会重开。此段作开口绘制，因这个国家尚未终'
      '结。',
      '1949年成立。本圖已載有其間的事件——宣教士撤離、三自愛國運動、文化'
      '大革命關閉教會、1979年教會重開。此段作開口繪製，因這個國家尚未終'
      '結。'),

    # ── 日本 ────────────────────────────────────────────────────────
    p('asuka-period', 'japan', 'asia', 538, 710,
      'Asuka Period', '飞鸟时代', '飛鳥時代',
      "Buddhism reached the court from Paekche and the Taika reforms "
      "remade the state on Chinese lines. Suiko, already on this chart, "
      "reigned inside it. The 538 start follows the Gangoji record "
      "rather than the 552 of the Nihon Shoki.",
      '佛教自百济传入朝廷，大化改新按中国制度重整国家。本图已有的推古天'
      '皇即在其中。起于538年是依元兴寺的记载，而非《日本书纪》的552年。',
      '佛教自百濟傳入朝廷，大化改新按中國制度重整國家。本圖已有的推古天'
      '皇即在其中。起於538年是依元興寺的記載，而非《日本書紀》的552年。',
      approximate=True),
    p('nara-period', 'japan', 'asia', 710, 794,
      'Nara Period', '奈良时代', '奈良時代',
      "The capital fixed at Heijo-kyo, and the first written Japanese "
      "histories — the Kojiki and the Nihon Shoki — compiled.",
      '定都平城京，日本最早的史书《古事记》与《日本书纪》于此时编成。',
      '定都平城京，日本最早的史書《古事記》與《日本書紀》於此時編成。'),
    p('heian-period', 'japan', 'asia', 794, 1185,
      'Heian Period', '平安时代', '平安時代',
      "The court at Heian-kyo, modern Kyoto, and the classical age of "
      "Japanese letters — the Tale of Genji among them.",
      '朝廷设于平安京，即今京都；日本古典文学的鼎盛期，《源氏物语》即出'
      '于此时。',
      '朝廷設於平安京，即今京都；日本古典文學的鼎盛期，《源氏物語》即出'
      '於此時。'),
    p('kamakura-shogunate', 'japan', 'asia', 1185, 1333,
      'Kamakura Shogunate', '镰仓幕府', '鎌倉幕府',
      "The first of the warrior governments. It twice turned back "
      "Kublai Khan's fleets, in 1274 and 1281.",
      '第一个武家政权。1274年与1281年两度击退忽必烈的船队。',
      '第一個武家政權。1274年與1281年兩度擊退忽必烈的船隊。'),
    p('muromachi-shogunate', 'japan', 'asia', 1336, 1573,
      'Muromachi Shogunate', '室町幕府', '室町幕府',
      "The Ashikaga shoguns at Kyoto. Francis Xavier landed at "
      "Kagoshima in 1549, inside these years.",
      '足利将军家在京都执政。1549年沙勿略于鹿儿岛登陆，即在此期间。',
      '足利將軍家在京都執政。1549年沙勿略於鹿兒島登陸，即在此期間。'),
    p('sengoku-period', 'japan', 'asia', 1467, 1603,
      'Sengoku Period', '战国时代', '戰國時代',
      "A century and more of civil war, from the Onin War to Tokugawa "
      "Ieyasu's appointment as shogun, drawn across the two shogunates "
      "it broke.",
      '自应仁之乱至德川家康受封征夷大将军，百余年诸侯混战；此段横跨它所'
      '瓦解的两个幕府。',
      '自應仁之亂至德川家康受封征夷大將軍，百餘年諸侯混戰；此段橫跨它所'
      '瓦解的兩個幕府。',
      approximate=True),
    p('tokugawa-shogunate', 'japan', 'asia', 1603, 1868,
      'Tokugawa Shogunate', '江户幕府', '江戶幕府',
      "Two and a half centuries of peace under the Tokugawa at Edo, and "
      "of sakoku, the closed country: Christianity was banned and all "
      "but ended in Japan until the ports reopened.",
      '德川氏在江户维持两个半世纪的太平，同时行锁国之制：基督教遭禁，几'
      '近绝迹，直至开港方再传入。',
      '德川氏在江戶維持兩個半世紀的太平，同時行鎖國之制：基督教遭禁，幾'
      '近絕跡，直至開港方再傳入。'),
    p('empire-of-japan', 'japan', 'asia', 1868, 1947,
      'Empire of Japan', '大日本帝国', '大日本帝國',
      "From the Meiji restoration to the postwar constitution: "
      "industrialisation, the wars with China and Russia, the empire in "
      "Korea, Manchuria and the Pacific, and the defeat of 1945.",
      '自明治维新至战后宪法：工业化、甲午与日俄之战、在朝鲜、满洲与太平'
      '洋的扩张，以及1945年的战败。',
      '自明治維新至戰後憲法：工業化、甲午與日俄之戰、在朝鮮、滿洲與太平'
      '洋的擴張，以及1945年的戰敗。'),
    p('japan-postwar', 'japan', 'asia', 1947, None,
      'Japan', '日本国', '日本國',
      "The state under the 1947 constitution. The band is drawn open "
      "because it has not ended.",
      '1947年宪法下的国家。此段作开口绘制，因尚未终结。',
      '1947年憲法下的國家。此段作開口繪製，因尚未終結。'),

    # ── 印度 ────────────────────────────────────────────────────────
    p('maurya-empire', 'india', 'asia', -322, -185,
      'Maurya Empire', '孔雀王朝', '孔雀王朝',
      "The first empire to hold most of the subcontinent. Ashoka's "
      "edicts, cut in stone after the Kalinga war, are among the oldest "
      "datable Indian inscriptions.",
      '首个统辖印度次大陆大部的帝国。阿育王在羯陵伽战后所刻的诏谕，是印'
      '度最早可系年的铭文之一。',
      '首個統轄印度次大陸大部的帝國。阿育王在羯陵伽戰後所刻的詔諭，是印'
      '度最早可繫年的銘文之一。'),
    p('shunga-empire', 'india', 'asia', -185, -73,
      'Shunga Empire', '巽伽王朝', '巽伽王朝',
      "The dynasty that took the Maurya throne at Pataliputra and held "
      "the middle Ganges for a century.",
      '于华氏城取孔雀王朝而代之，据恒河中游百余年。',
      '於華氏城取孔雀王朝而代之，據恆河中游百餘年。'),
    p('satavahana-empire', 'india', 'asia', -100, 225,
      'Satavahana Empire', '百乘王朝', '百乘王朝',
      "The Deccan power that linked the northern kingdoms to the Roman "
      "sea trade of the western coast. Its dates are argued over by "
      "more than a century at the start.",
      '德干高原的强权，把北方诸国与西海岸对罗马的海上贸易连在一起。其起'
      '始年代，学者之间相差一个世纪以上。',
      '德干高原的強權，把北方諸國與西海岸對羅馬的海上貿易連在一起。其起'
      '始年代，學者之間相差一個世紀以上。',
      approximate=True),
    p('kushan-empire', 'india', 'asia', 30, 375,
      'Kushan Empire', '贵霜帝国', '貴霜帝國',
      "Astride the trade roads from India into Central Asia, and the "
      "setting of the Gandharan workshops that first gave the Buddha a "
      "human figure.",
      '横跨印度通往中亚的商道，犍陀罗造像即出于其境，佛陀首次被塑成人形。',
      '橫跨印度通往中亞的商道，犍陀羅造像即出於其境，佛陀首次被塑成人形。',
      approximate=True),
    p('gupta-empire', 'india', 'asia', 320, 550,
      'Gupta Empire', '笈多王朝', '笈多王朝',
      "The classical age of northern India: the decimal place-value "
      "notation and the zero used as a number belong to these "
      "centuries.",
      '北印度的古典时代：十进位记数法与作为数字使用的零，皆出于这几个世纪。',
      '北印度的古典時代：十進位記數法與作為數字使用的零，皆出於這幾個世紀。'),
    p('chola-empire', 'india', 'asia', 850, 1279,
      'Chola Empire', '朱罗王朝', '朱羅王朝',
      "The Tamil sea power of the south, whose fleets reached Sumatra "
      "and whose temples at Thanjavur still stand.",
      '南印度的泰米尔海上强权，船队远至苏门答腊，坦贾武尔的神庙至今犹存。',
      '南印度的泰米爾海上強權，船隊遠至蘇門答臘，坦賈武爾的神廟至今猶存。'),
    p('delhi-sultanate', 'india', 'asia', 1206, 1526,
      'Delhi Sultanate', '德里苏丹国', '德里蘇丹國',
      "Three centuries of Muslim rule in the north, ended by Babur at "
      "Panipat.",
      '北印度三百年的穆斯林统治，终于巴布尔在帕尼帕特一战。',
      '北印度三百年的穆斯林統治，終於巴布爾在帕尼帕特一戰。'),
    p('british-raj', 'india', 'asia', 1858, 1947,
      'British Raj', '英属印度', '英屬印度',
      "Crown rule after the rebellion of 1857, ending at partition. "
      "William Carey's mission and the Serampore presses came a "
      "generation before it; the church councils and the vernacular "
      "Bibles grew up inside it.",
      '1857年起义之后由英王直辖，终于1947年分治。克理的宣教与塞兰坡的印'
      '刷所早其一代；教会公会与各方言圣经则在其间成长。',
      '1857年起義之後由英王直轄，終於1947年分治。克理的宣教與塞蘭坡的印'
      '刷所早其一代；教會公會與各方言聖經則在其間成長。'),
    p('republic-of-india', 'india', 'asia', 1947, None,
      'Republic of India', '印度共和国', '印度共和國',
      "Independent from 1947. The band is drawn open because it has not "
      "ended.",
      '1947年独立。此段作开口绘制，因尚未终结。',
      '1947年獨立。此段作開口繪製，因尚未終結。'),

    # ── 美洲 ────────────────────────────────────────────────────────
    p('portuguese-brazil', 'americas', 'americas', 1500, 1822,
      'Portuguese Brazil', '葡属巴西', '葡屬巴西',
      "Claimed by Cabral in 1500 and governed from Lisbon until "
      "independence in 1822 — the one American empire that was "
      "Portuguese rather than Spanish.",
      '1500年卡布拉尔宣示占有，由里斯本治理至1822年独立——美洲唯一属葡萄'
      '牙而非西班牙的疆域。',
      '1500年卡布拉爾宣示佔有，由里斯本治理至1822年獨立——美洲唯一屬葡萄'
      '牙而非西班牙的疆域。'),
    p('viceroyalty-new-spain', 'americas', 'americas', 1535, 1821,
      'Viceroyalty of New Spain', '新西班牙总督辖区', '新西班牙總督轄區',
      "Mexico City ruled New Spain from soon after the fall of "
      "Tenochtitlan until 1821, with the friars' missions running north "
      "into what is now the United States.",
      '特诺奇提特兰陷落后不久至1821年，墨西哥城统辖新西班牙，修会的传教'
      '站北至今日美国境内。',
      '特諾奇提特蘭陷落後不久至1821年，墨西哥城統轄新西班牙，修會的傳教'
      '站北至今日美國境內。'),
    p('viceroyalty-peru', 'americas', 'americas', 1542, 1824,
      'Viceroyalty of Peru', '秘鲁总督辖区', '秘魯總督轄區',
      "Lima ruled Spanish South America after the fall of the Inca, "
      "until the wars of independence.",
      '印加覆亡后，利马统辖西属南美，直至独立战争。',
      '印加覆亡後，利馬統轄西屬南美，直至獨立戰爭。'),
    p('united-states', 'americas', 'americas', 1776, None,
      'United States of America', '美利坚合众国', '美利堅合眾國',
      "Independent from 1776. The band is drawn open because it has not "
      "ended.",
      '1776年独立。此段作开口绘制，因尚未终结。',
      '1776年獨立。此段作開口繪製，因尚未終結。'),

    # ── 其他 ────────────────────────────────────────────────────────
    p('three-kingdoms-korea', 'world', 'asia', 300, 668,
      'Three Kingdoms of Korea', '朝鲜三国时代', '朝鮮三國時代',
      "Koguryo, Paekche and Silla. Paekche is the kingdom that sent "
      "Buddhism to the Japanese court, which is why the Asuka band "
      "opens where it does. Drawn from the fourth century, when the "
      "three were states: the Samguk Sagi's foundation years — Silla "
      "57 BC, Koguryo 37 BC, Paekche 18 BC — are tradition, and this "
      "chart draws tradition only where it says so.",
      '高句丽、百济、新罗三国并立。百济即向日本朝廷传入佛教的一国，飞鸟'
      '时代的起点由此而来。此段自四世纪画起，即三者成国之时；《三国史记》'
      '所记的建国之年——新罗前57年、高句丽前37年、百济前18年——属传说，本'
      '图只在注明之处才画传说。',
      '高句麗、百濟、新羅三國並立。百濟即向日本朝廷傳入佛教的一國，飛鳥'
      '時代的起點由此而來。此段自四世紀畫起，即三者成國之時；《三國史記》'
      '所記的建國之年——新羅前57年、高句麗前37年、百濟前18年——屬傳說，本'
      '圖只在註明之處才畫傳說。',
      approximate=True),
    p('unified-silla', 'world', 'asia', 668, 935,
      'Unified Silla', '统一新罗', '統一新羅',
      "Silla held the peninsula for nearly three centuries after "
      "defeating its two rivals with Tang help.",
      '新罗借唐之力灭其二敌，统治半岛近三百年。',
      '新羅借唐之力滅其二敵，統治半島近三百年。'),
    p('goryeo', 'world', 'asia', 918, 1392,
      'Goryeo', '高丽王朝', '高麗王朝',
      "The kingdom the name Korea comes from. Its craftsmen cut the "
      "Tripitaka Koreana into eighty thousand woodblocks, and cast "
      "movable metal type two centuries before Gutenberg.",
      'Korea 一名即出于此。其匠人将《高丽大藏经》刻成八万余块经版，并早'
      '于古腾堡两个世纪铸出金属活字。',
      'Korea 一名即出於此。其匠人將《高麗大藏經》刻成八萬餘塊經版，並早'
      '於古騰堡兩個世紀鑄出金屬活字。'),
    p('joseon', 'world', 'asia', 1392, 1897,
      'Joseon', '朝鲜王朝', '朝鮮王朝',
      "Five centuries under the Yi. Sejong's scholars published the "
      "Korean alphabet in 1446, and the first Protestant missionaries "
      "arrived in its last decades.",
      '李氏五百年之治。世宗朝的学者于1446年颁行谚文，其末期迎来最早的新'
      '教宣教士。',
      '李氏五百年之治。世宗朝的學者於1446年頒行諺文，其末期迎來最早的新'
      '教宣教士。'),
    p('korean-empire', 'world', 'asia', 1897, 1910,
      'Korean Empire', '大韩帝国', '大韓帝國',
      "Thirteen years as a declared empire between the end of Chinese "
      "suzerainty and annexation by Japan.",
      '自脱离中国宗主至被日本吞并，称帝十三年。',
      '自脫離中國宗主至被日本吞併，稱帝十三年。'),
    p('korea-under-japan', 'world', 'asia', 1910, 1945,
      'Korea under Japanese Rule', '日本统治朝鲜', '日本統治朝鮮',
      "Thirty-five years of annexation, ended by the Japanese surrender. "
      "Pyongyang's churches were large enough in these years to be "
      "called the Jerusalem of the East, and the refusal of Shinto "
      "shrine worship cost many of their leaders their freedom.",
      '吞并三十五年，终于日本投降。这些年间平壤教会之盛，有东方耶路撒冷'
      '之称；拒拜神社使其中许多领袖身陷囹圄。',
      '吞併三十五年，終於日本投降。這些年間平壤教會之盛，有東方耶路撒冷'
      '之稱；拒拜神社使其中許多領袖身陷囹圄。'),
    p('republic-of-korea', 'world', 'asia', 1948, None,
      'Republic of Korea', '大韩民国', '大韓民國',
      "The southern state, declared in 1948. The band is drawn open "
      "because it has not ended.",
      '1948年宣告成立的南方国家。此段作开口绘制，因尚未终结。',
      '1948年宣告成立的南方國家。此段作開口繪製，因尚未終結。'),
    p('dpr-korea', 'world', 'asia', 1948, None,
      "Democratic People's Republic of Korea",
      '朝鲜民主主义人民共和国', '朝鮮民主主義人民共和國',
      "The northern state, declared in 1948. The band is drawn open "
      "because it has not ended.",
      '1948年宣告成立的北方国家。此段作开口绘制，因尚未终结。',
      '1948年宣告成立的北方國家。此段作開口繪製，因尚未終結。'),
    p('mongol-empire', 'world', 'asia', 1206, 1368,
      'Mongol Empire', '蒙古帝国', '蒙古帝國',
      "The largest contiguous land empire there has been, from Korea to "
      "Hungary. Its Chinese half is on this chart as the Yuan; the "
      "roads it held open carried the friars and the Polos east.",
      '历史上疆域相连最广的帝国，自朝鲜直抵匈牙利。其中国部分即本图的元'
      '朝；它所维持的道路，把方济各会士与波罗一家带向东方。',
      '歷史上疆域相連最廣的帝國，自朝鮮直抵匈牙利。其中國部分即本圖的元'
      '朝；它所維持的道路，把方濟各會士與波羅一家帶向東方。',
      approximate=True),
]


def main():
    data = json.load(open(ASSET))
    have = {p['id'] for p in data['powers']}
    fresh = [r for r in NEW if r['id'] not in have]
    if not fresh:
        print('nothing to add')
        return
    streams = {s['id'] for s in data['streams']}
    for r in fresh:
        assert r['stream'] in streams, r['id']
        assert r['end'] is None or r['end'] > r['start'], r['id']
        for k in ('en', 'zh-Hans', 'zh-Hant'):
            assert r['name'][k] and r['note'][k], (r['id'], k)
    data['powers'] = sorted(data['powers'] + fresh,
                            key=lambda r: (r['start'], r['id']))
    with open(ASSET, 'w') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
    print(f'added {len(fresh)} powers; {len(data["powers"])} total')
    for r in fresh:
        print(f"  {r['start']:>6} {str(r['end']):>6}  "
              f"{r['stream']:<9} {r['name']['zh-Hans']}")


if __name__ == '__main__':
    main()
