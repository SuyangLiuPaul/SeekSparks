#!/usr/bin/env python3
"""The world's own lane: the wars and pandemics as SPANS, and the
events of the last twenty years that were missing from it.

2026-09-16, three requests in one breath:

  「很多全世界大事情类似于covid 俄乌战争这些也要在最外圈写进去」
  「一战二战这些 持续时间也是可以加进去好像那些环一样」
  「有一个全世界的tick也可以在filter而且default是tick的」

WHAT WAS ACTUALLY WRONG. COVID and the Ukraine war were both already in
the file, which is why this script edits two of them rather than adding
them. But `covid_pandemic` was TITLED 「疫情关闭教会建筑」 — the church
consequence, not the pandemic — while the 1918 influenza on the same
lane is titled as the pandemic and says tens of millions died. The 2020
entry was the inconsistent one, and a reader looking for COVID found a
church story. It is split: the pandemic keeps the id, and the closures
become their own record. The Ukraine war sat on 欧洲 while every other
war of global reach on this chart — both world wars, Korea, Vietnam,
Iraq — sits on 世界. That was the outlier, not a judgement call.

A WAR IS A SPAN. The chart already draws campaigns and movements as
bands: the crusades run 1147-1149, 1189-1192, 1248-1254, and the
Reformation runs 1517-1648. A world war is the same kind of thing and
was drawn only as a one-year tick at its outbreak. Eight bands fix
that, and the outbreak events stay where they are — the tick says when
it began, the band says how long it lasted.
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'wheel_history.json')


def band(pid, start, end, en, hans, hant, note_en, note_hans, note_hant,
         region='modern', stream='world', approximate=False):
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
        row = {'id': pid, 'start': start, 'end': None, 'ongoing': True,
               'region': region, 'stream': stream,
               'approximate': approximate, 'basis': 'conventional',
               'name': row['name'], 'note': row['note']}
    return row


def event(eid, year, en, hans, hant, d_en, d_hans, d_hant,
          stream='world', approximate=False):
    return {
        'id': eid,
        'year': year,
        'era': 'world',
        'stream': stream,
        'approximate': approximate,
        'basis': 'conventional',
        'title': {'en': en, 'zh-Hans': hans, 'zh-Hant': hant},
        'desc': {'en': d_en, 'zh-Hans': d_hans, 'zh-Hant': d_hant},
    }


BANDS = [
    band('influenza-pandemic-band', 1918, 1920,
         'The 1918 Influenza Pandemic', '1918年流感大流行',
         '1918年流感大流行',
         "Three years and three or four waves, and tens of millions of "
         "deaths — more than the war it followed.",
         '历时三年，三四波疫潮，死者数千万，多过它所接续的那场战争。',
         '歷時三年，三四波疫潮，死者數千萬，多過它所接續的那場戰爭。'),
    band('world-war-one', 1914, 1918,
         'First World War', '第一次世界大战', '第一次世界大戰',
         "Four years and three months. Its end took the Ottoman empire "
         "off this chart and put Britain in Jerusalem, both of which "
         "are drawn here as their own records.",
         '四年零三个月。它的结束使奥斯曼帝国从本图消失，又把英国带进耶路'
         '撒冷；二者本图各有其条目。',
         '四年零三個月。它的結束使奧斯曼帝國從本圖消失，又把英國帶進耶路'
         '撒冷；二者本圖各有其條目。'),
    band('world-war-two', 1939, 1945,
         'Second World War', '第二次世界大战', '第二次世界大戰',
         "Six years. The deadliest war there has been, and the one "
         "whose ending set up almost everything later on this lane — "
         "the United Nations, the two Koreas, the state of Israel.",
         '六年。有史以来死伤最重的战争；本条线其后的大半——联合国、两个'
         '朝鲜、以色列国——都由它的结局立定。',
         '六年。有史以來死傷最重的戰爭；本條線其後的大半——聯合國、兩個'
         '朝鮮、以色列國——都由它的結局立定。'),
    band('cold-war', 1947, 1991,
         'The Cold War', '冷战', '冷戰',
         "Forty-four years between the two blocs, from the Truman "
         "doctrine to the Soviet Union's dissolution. Most of the "
         "church-behind-the-curtain records on this chart sit inside "
         "it.",
         '两大阵营对峙四十四年，自杜鲁门主义至苏联解体。本图中铁幕之下的'
         '教会条目，大半都在其中。',
         '兩大陣營對峙四十四年，自杜魯門主義至蘇聯解體。本圖中鐵幕之下的'
         '教會條目，大半都在其中。'),
    band('korean-war-band', 1950, 1953,
         'Korean War', '朝鲜战争', '朝鮮戰爭',
         "Three years, ended by an armistice rather than a peace — "
         "which is why the two Korean bands beside it both run open.",
         '三年，以停战而非和约收场——旁边两条朝鲜半岛的带子因此都作开口。',
         '三年，以停戰而非和約收場——旁邊兩條朝鮮半島的帶子因此都作開口。'),
    band('vietnam-war-band', 1955, 1975,
         'Vietnam War', '越南战争', '越南戰爭',
         "Twenty years by the conventional reckoning, from the "
         "partition to the fall of Saigon.",
         '按通行算法为二十年，自南北分治至西贡陷落。',
         '按通行算法為二十年，自南北分治至西貢陷落。',
         approximate=True),
    band('covid-pandemic-band', 2020, 2023,
         'The COVID-19 Pandemic', '新冠疫情', '新冠疫情',
         "From the declaration of a pandemic in March 2020 to the end "
         "of the global emergency in May 2023. Church buildings closed "
         "worldwide inside it, which is its own record on this chart.",
         '自2020年3月宣告大流行，至2023年5月全球突发事件状态解除。其间全'
         '球教会建筑关闭，本图另有专条。',
         '自2020年3月宣告大流行，至2023年5月全球突發事件狀態解除。其間全'
         '球教會建築關閉，本圖另有專條。'),
    band('war-in-ukraine-band', 2022, None,
         'The War in Ukraine', '俄乌战争', '俄烏戰爭',
         "The full invasion of February 2022, after fighting in the "
         "east and Crimea since 2014. The band is drawn open because "
         "the war has not ended.",
         '2022年2月的全面入侵；此前自2014年起，乌东与克里米亚已有战事。此'
         '段作开口绘制，因战事尚未结束。',
         '2022年2月的全面入侵；此前自2014年起，烏東與克里米亞已有戰事。此'
         '段作開口繪製，因戰事尚未結束。'),
]

EVENTS = [
    event('covid_church_closures', 2020,
          'Pandemic Closes Church Buildings', '疫情关闭教会建筑',
          '疫情關閉教會建築',
          "Congregations worldwide are scattered and worship moves "
          "online for the first time on such a scale.",
          '全球会众被迫分散，敬拜首次如此大规模地转往网上。',
          '全球會眾被迫分散，敬拜首次如此大規模地轉往網上。'),
    event('haiti_earthquake_2010', 2010,
          'Haiti Earthquake', '海地大地震', '海地大地震',
          "A magnitude 7.0 earthquake destroyed much of Port-au-Prince "
          "and killed well over a hundred thousand people.",
          '7.0级地震摧毁太子港大半，死者远逾十万。',
          '7.0級地震摧毀太子港大半，死者遠逾十萬。',
          stream='americas'),
    event('arab_spring', 2011,
          'The Arab Spring', '阿拉伯之春', '阿拉伯之春',
          "Risings across the Arab world unseated four governments and "
          "opened the Syrian war, which displaced more people than any "
          "conflict since 1945.",
          '阿拉伯世界各地的民众运动推翻四国政府，并开启叙利亚战事——1945'
          '年以来流离失所人数最多的一场冲突。',
          '阿拉伯世界各地的民眾運動推翻四國政府，並開啟敘利亞戰事——1945'
          '年以來流離失所人數最多的一場衝突。'),
    event('ebola_west_africa', 2014,
          'Ebola Epidemic in West Africa', '西非埃博拉疫情',
          '西非伊波拉疫情',
          "The largest Ebola outbreak on record, in Guinea, Liberia and "
          "Sierra Leone.",
          '有记录以来规模最大的埃博拉疫情，发生于几内亚、利比里亚与塞拉'
          '利昂。',
          '有記錄以來規模最大的伊波拉疫情，發生於幾內亞、賴比瑞亞與獅子'
          '山。'),
    event('europe_refugee_crisis', 2015,
          'Refugee Crisis in Europe', '欧洲难民危机', '歐洲難民危機',
          "More than a million people crossed the Mediterranean in a "
          "single year, most of them from Syria, Afghanistan and Iraq.",
          '一年之内逾百万人渡过地中海，多来自叙利亚、阿富汗与伊拉克。',
          '一年之內逾百萬人渡過地中海，多來自敘利亞、阿富汗與伊拉克。',
          stream='europe'),
    event('paris_climate_agreement', 2015,
          'Paris Climate Agreement', '《巴黎协定》通过',
          '《巴黎協定》通過',
          "Nearly every country agreed to limit warming — the first "
          "climate treaty with that reach.",
          '几乎所有国家同意限制升温，是第一份有此覆盖面的气候条约。',
          '幾乎所有國家同意限制升溫，是第一份有此覆蓋面的氣候條約。'),
    event('turkey_syria_earthquake_2023', 2023,
          'Turkey and Syria Earthquakes', '土耳其与叙利亚大地震',
          '土耳其與敘利亞大地震',
          "Two earthquakes nine hours apart killed more than fifty "
          "thousand people across southern Turkey and northern Syria.",
          '相隔九小时的两场地震，在土耳其南部与叙利亚北部夺去五万余人的'
          '生命。',
          '相隔九小時的兩場地震，在土耳其南部與敘利亞北部奪去五萬餘人的'
          '生命。'),
]


def main():
    data = json.load(open(ASSET))
    changed = []

    # The pandemic keeps its id and gets its own name back.
    for e in data['events']:
        if e['id'] == 'covid_pandemic' and '关闭' in e['title']['zh-Hans']:
            e['title'] = {
                'en': 'COVID-19 Declared a Pandemic',
                'zh-Hans': '新冠疫情宣告为大流行',
                'zh-Hant': '新冠疫情宣告為大流行',
            }
            e['desc'] = {
                'en': "The WHO declared a pandemic in March 2020; it "
                      "went on to kill millions and to shut most of the "
                      "world indoors.",
                'zh-Hans': '世卫组织于2020年3月宣告大流行；其后夺去数百万'
                           '人的生命，并使世界大半闭门不出。',
                'zh-Hant': '世衛組織於2020年3月宣告大流行；其後奪去數百萬'
                           '人的生命，並使世界大半閉門不出。',
            }
            changed.append('covid_pandemic retitled as the pandemic')
        # Every other war of global reach on this chart is on 世界.
        if e['id'] == 'war_in_ukraine' and e['stream'] == 'europe':
            e['stream'] = 'world'
            changed.append('war_in_ukraine moved to the world lane')

    have_e = {e['id'] for e in data['events']}
    fresh_e = [e for e in EVENTS if e['id'] not in have_e]
    have_p = {p['id'] for p in data['powers']}
    fresh_p = [b for b in BANDS if b['id'] not in have_p]

    streams = {s['id'] for s in data['streams']}
    for r in fresh_e + fresh_p:
        assert r['stream'] in streams, r['id']
    for b in fresh_p:
        assert b['end'] is None or b['end'] > b['start'], b['id']

    data['events'] = sorted(data['events'] + fresh_e,
                            key=lambda r: (r['year'], r['id']))
    data['powers'] = sorted(data['powers'] + fresh_p,
                            key=lambda r: (r['start'], r['id']))
    with open(ASSET, 'w') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
    for line in changed:
        print(' ', line)
    print(f'added {len(fresh_p)} bands, {len(fresh_e)} events; '
          f'{len(data["powers"])} powers, {len(data["events"])} events')


if __name__ == '__main__':
    main()
