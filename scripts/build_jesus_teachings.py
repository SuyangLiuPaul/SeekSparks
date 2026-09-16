#!/usr/bin/env python3
"""Build assets/jesus_teachings.json — the spine of "The Teachings of the Lord Jesus".

WHAT THIS IS, AND WHAT IT IS NOT.

There is no canonical enumeration of "all the teachings of Jesus". The
parables are a stable category with old catalogues; "teachings and
discourses" is not — every published list is an editor's scheme, and the
modern ones (NIV Study Bible tables, Nelson's, Scroggie) are in
copyright. So this file's arrangement is EDITORIAL, it says so in its
own `_meta`, and the page says so to the reader.

What it is built from, in order of authority:

  1. THE TEXT'S OWN STRUCTURE. Matthew's five discourses (5-7, 10, 13,
     18, 24-25), each closed by "when Jesus had finished these sayings",
     and John's discourses. This is the one part of the arrangement that
     is not anybody's opinion.
  2. THE OWNER'S OWN SERMON CORPUS. `assets/sermons/index.json` carries
     289 sermons already grouped by topic, of which "The Parables of
     Jesus" (34), "Sermon on the Mount" (18) and "The Beatitudes" (10)
     are an ordered exposition of Jesus' teaching with a passage on each
     entry. Where the corpus covers a teaching, ITS order and ITS title
     are used, because they are the owner's own and not a guess.
  3. NAVE'S TOPICAL BIBLE (1896, public domain), the "JESUS, THE CHRIST"
     article, which is a life-of-Christ outline in order with references
     on each line. Teaching lines are picked out by the keyword rule in
     `_TEACHING_WORDS`, and that rule is the editorial act — it is kept
     in one place, and its misses are a known limitation rather than a
     hidden one.

And what is attached to each teaching, all from data already bundled:

  * SERMONS — `assets/sermons/refs.json` `byVerse`, which is already a
    verse-to-sermon index built by `extract_sermon_refs.py`.
  * OLD TESTAMENT and APOSTLES — `assets/cross_references.json`, the
    Treasury of Scripture Knowledge merged with OpenBible.info votes.
    TSK asserts that two passages are RELATED. It does not assert that
    one rests on the other, and nothing here upgrades that claim: the
    page puts the conviction in its preface, in the owner's voice, and
    keeps the column headings neutral.
  * WHAT THE TEXT ITSELF CLAIMS — `_LORDS_WORD` is the short list of
    places where an apostle says outright that he is passing on the
    Lord's own word. There are five. They are marked, and they are the
    only links on the page that assert dependence, because they are the
    only ones scripture asserts.
  * PLATES — `assets/maps_index.json`, matched by book and chapter.

Run: python3 scripts/build_jesus_teachings.py
"""

import json
import os
import re
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def asset(*parts):
    return os.path.join(ROOT, 'assets', *parts)


BOOKS = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai',
    'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation',
]
OT = set(BOOKS[:39])
GOSPELS = {'Matthew', 'Mark', 'Luke', 'John'}
EPISTLES = set(BOOKS[44:65])  # Romans .. Jude

# The abbreviations the sermon corpus actually uses, measured rather than
# assumed: `Mt` 102, `Lk` 30, `Mk` 9, `Jn` 6, plus full names and a few
# epistle short forms.
ABBREV = {
    'Mt': 'Matthew', 'Mk': 'Mark', 'Lk': 'Luke', 'Jn': 'John',
    'Rom': 'Romans', '1Cor': '1 Corinthians', '2Cor': '2 Corinthians',
    'Gal': 'Galatians', 'Eph': 'Ephesians', 'Phil': 'Philippians',
    'Col': 'Colossians', 'Heb': 'Hebrews', 'Jas': 'James',
    '1Pet': '1 Peter', '2Pet': '2 Peter', 'Song': 'Song of Solomon',
}
for b in BOOKS:
    ABBREV[b] = b

# The lines in Nave's life-of-Christ outline that are a TEACHING. This
# keyword rule is the editorial act in this file; it is here, once, so
# that what it misses can be argued with.
_TEACHING_WORDS = re.compile(
    r'\b(parable|teach|teaches|teaching|discourse|sermon|enunciat|preach'
    r'|expound|instruct|answers|declares|foretells|commissions)', re.I)

# The only places in the New Testament where an apostle says outright
# that he is handing on the Lord's OWN word. Everything else on this page
# is a relation, not a dependence — see the module docstring.
_LORDS_WORD = {
    '1 Corinthians 7:10': 'the Lord, not I',
    '1 Corinthians 7:11': 'the Lord, not I',
    '1 Corinthians 9:14': 'the Lord commanded',
    '1 Corinthians 11:23': 'received of the Lord',
    '1 Corinthians 11:24': 'received of the Lord',
    '1 Corinthians 11:25': 'received of the Lord',
    '1 Thessalonians 4:15': 'by the word of the Lord',
    'Acts 20:35': 'the words of the Lord Jesus',
}

# Matthew's five discourses and John's, which are the text's own
# divisions rather than an editor's. Each Matthean one closes with the
# formula "when Jesus had finished these sayings" (7:28, 11:1, 13:53,
# 19:1, 26:1), which is why this list is not a matter of opinion.
_STRUCTURAL = [
    ('discourse-sermon-mount', 'Matthew', 5, 1, 7, 29,
     {'en': 'The Sermon on the Mount', 'zh-Hans': '登山宝训',
      'zh-Hant': '登山寶訓'}),
    ('discourse-mission', 'Matthew', 10, 1, 10, 42,
     {'en': 'The Mission Discourse', 'zh-Hans': '差遣的教导',
      'zh-Hant': '差遣的教導'}),
    ('discourse-parables', 'Matthew', 13, 1, 13, 52,
     {'en': 'The Parables of the Kingdom', 'zh-Hans': '天国的比喻',
      'zh-Hant': '天國的比喻'}),
    ('discourse-church', 'Matthew', 18, 1, 18, 35,
     {'en': 'On the Church and Forgiveness', 'zh-Hans': '论教会与饶恕',
      'zh-Hant': '論教會與饒恕'}),
    ('discourse-olivet', 'Matthew', 24, 1, 25, 46,
     {'en': 'The Olivet Discourse', 'zh-Hans': '橄榄山的教导',
      'zh-Hant': '橄欖山的教導'}),
    ('discourse-upper-room', 'John', 14, 1, 16, 33,
     {'en': 'The Upper Room Discourse', 'zh-Hans': '临别的教导',
      'zh-Hant': '臨別的教導'}),
    ('discourse-bread-of-life', 'John', 6, 22, 6, 71,
     {'en': 'The Bread of Life', 'zh-Hans': '生命的粮',
      'zh-Hant': '生命的糧'}),
    ('discourse-good-shepherd', 'John', 10, 1, 10, 21,
     {'en': 'The Good Shepherd', 'zh-Hans': '好牧人',
      'zh-Hant': '好牧人'}),
    # THE THREE THE APOSTLES CITE BY NAME. These are here because of
    # `_LORDS_WORD`, not in spite of it: they are the teachings the New
    # Testament itself says an apostle is handing on, so a page about
    # what the apostles received cannot be missing them. Without them
    # the strongest links on the page had nothing to attach to — the
    # first build marked zero.
    ('lords-supper', 'Matthew', 26, 26, 26, 29,
     {'en': 'The Lord\'s Supper', 'zh-Hans': '主的晚餐',
      'zh-Hant': '主的晚餐'}),
    ('on-divorce', 'Matthew', 19, 3, 19, 12,
     {'en': 'On Marriage and Divorce', 'zh-Hans': '论婚姻与休妻',
      'zh-Hant': '論婚姻與休妻'}),
    ('labourer-worthy', 'Luke', 10, 1, 10, 12,
     {'en': 'The Seventy Sent Out', 'zh-Hans': '差遣七十个人',
      'zh-Hant': '差遣七十個人'}),
]


# THE PARABLES, WHICH ARE THE ONE STABLE CATEGORY.
#
# 2026-09-16 「Scholars generally count between 30 and 40 parables told
# by Jesus in the New Testament 这里却并没有看出来 好像只有15个」 — and
# the owner is right about the count. The other three sources cannot
# produce it: the sermon corpus preached the parables it preached,
# Nave's outline names some and not others, and Matthew 13 is a
# DISCOURSE, so everything inside it arrived as one entry.
#
# This list is not an editorial judgement in the way the discourses are.
# The generator's own preamble says why: there is no canonical
# enumeration of Jesus' TEACHINGS, but the parables are a settled
# category, and published lists differ at the edges over whether a
# one-line simile counts, not over which passages are parables. The
# passages here are the ones every such list has; the names are the
# ones a Chinese reader already meets at the head of the passage.
#
# Each is a teaching in its own right, which is why the fold refuses to
# put one inside anything else.
_PARABLES = [
    ('lamp-under-bowl', [('Matthew', 5, 14, 16), ('Mark', 4, 21, 22), ('Luke', 8, 16, 17)],
     {'en': 'The Lamp Under a Bowl', 'zh-Hans': '灯放在灯台上', 'zh-Hant': '燈放在燈臺上'}),
    ('wise-foolish-builders', [('Matthew', 7, 24, 27), ('Luke', 6, 47, 49)],
     {'en': 'The Wise and Foolish Builders', 'zh-Hans': '两种根基：磐石与沙土', 'zh-Hant': '兩種根基：磐石與沙土'}),
    ('new-cloth-old-garment', [('Matthew', 9, 16, 16), ('Mark', 2, 21, 21), ('Luke', 5, 36, 36)],
     {'en': 'New Cloth on an Old Garment', 'zh-Hans': '新布补旧衣服', 'zh-Hant': '新布補舊衣服'}),
    ('new-wine-old-wineskins', [('Matthew', 9, 17, 17), ('Mark', 2, 22, 22), ('Luke', 5, 37, 39)],
     {'en': 'New Wine in Old Wineskins', 'zh-Hans': '新酒装在旧皮袋里', 'zh-Hant': '新酒裝在舊皮袋裡'}),
    ('two-debtors', [('Luke', 7, 41, 43)],
     {'en': 'The Two Debtors', 'zh-Hans': '两个欠债的人', 'zh-Hant': '兩個欠債的人'}),
    ('sower', [('Matthew', 13, 1, 23), ('Mark', 4, 1, 20), ('Luke', 8, 4, 15)],
     {'en': 'The Sower', 'zh-Hans': '撒种的比喻', 'zh-Hant': '撒種的比喻'}),
    ('weeds', [('Matthew', 13, 24, 30), ('Matthew', 13, 36, 43)],
     {'en': 'The Weeds Among the Wheat', 'zh-Hans': '稗子的比喻', 'zh-Hant': '稗子的比喻'}),
    ('growing-seed', [('Mark', 4, 26, 29)],
     {'en': 'The Growing Seed', 'zh-Hans': '种子自己长大的比喻', 'zh-Hant': '種子自己長大的比喻'}),
    ('mustard-seed', [('Matthew', 13, 31, 32), ('Mark', 4, 30, 32), ('Luke', 13, 18, 19)],
     {'en': 'The Mustard Seed', 'zh-Hans': '芥菜种的比喻', 'zh-Hant': '芥菜種的比喻'}),
    ('leaven', [('Matthew', 13, 33, 33), ('Luke', 13, 20, 21)],
     {'en': 'The Leaven', 'zh-Hans': '面酵的比喻', 'zh-Hant': '麵酵的比喻'}),
    ('hidden-treasure', [('Matthew', 13, 44, 44)],
     {'en': 'The Hidden Treasure', 'zh-Hans': '藏在地里的宝贝', 'zh-Hant': '藏在地裡的寶貝'}),
    ('pearl-of-great-price', [('Matthew', 13, 45, 46)],
     {'en': 'The Pearl of Great Price', 'zh-Hans': '重价的珠子', 'zh-Hant': '重價的珠子'}),
    ('net', [('Matthew', 13, 47, 50)],
     {'en': 'The Net', 'zh-Hans': '撒网的比喻', 'zh-Hant': '撒網的比喻'}),
    ('householder-treasure', [('Matthew', 13, 51, 52)],
     {'en': 'The Householder’s Treasure', 'zh-Hans': '家主的库房', 'zh-Hant': '家主的庫房'}),
    ('lost-sheep', [('Matthew', 18, 12, 14), ('Luke', 15, 3, 7)],
     {'en': 'The Lost Sheep', 'zh-Hans': '迷羊的比喻', 'zh-Hant': '迷羊的比喻'}),
    ('unmerciful-servant', [('Matthew', 18, 23, 35)],
     {'en': 'The Unmerciful Servant', 'zh-Hans': '不饶恕人的恶仆', 'zh-Hant': '不饒恕人的惡僕'}),
    ('good-samaritan', [('Luke', 10, 30, 37)],
     {'en': 'The Good Samaritan', 'zh-Hans': '好撒玛利亚人的比喻', 'zh-Hant': '好撒瑪利亞人的比喻'}),
    ('friend-at-midnight', [('Luke', 11, 5, 8)],
     {'en': 'The Friend at Midnight', 'zh-Hans': '半夜求饼的朋友', 'zh-Hant': '半夜求餅的朋友'}),
    ('rich-fool', [('Luke', 12, 16, 21)],
     {'en': 'The Rich Fool', 'zh-Hans': '无知财主的比喻', 'zh-Hant': '無知財主的比喻'}),
    ('watchful-servants', [('Luke', 12, 35, 40)],
     {'en': 'The Watchful Servants', 'zh-Hans': '警醒等候主人的仆人', 'zh-Hant': '警醒等候主人的僕人'}),
    ('faithful-steward', [('Luke', 12, 42, 48), ('Matthew', 24, 45, 51)],
     {'en': 'The Faithful and Wicked Steward', 'zh-Hans': '忠心与不忠心的管家', 'zh-Hant': '忠心與不忠心的管家'}),
    ('barren-fig-tree', [('Luke', 13, 6, 9)],
     {'en': 'The Barren Fig Tree', 'zh-Hans': '不结果子的无花果树', 'zh-Hant': '不結果子的無花果樹'}),
    ('great-banquet', [('Luke', 14, 15, 24)],
     {'en': 'The Great Banquet', 'zh-Hans': '大筵席的比喻', 'zh-Hant': '大筵席的比喻'}),
    ('tower-and-war', [('Luke', 14, 28, 33)],
     {'en': 'The Tower and the King Going to War', 'zh-Hans': '盖楼与出战的比喻', 'zh-Hant': '蓋樓與出戰的比喻'}),
    ('lost-coin', [('Luke', 15, 8, 10)],
     {'en': 'The Lost Coin', 'zh-Hans': '失钱的比喻', 'zh-Hant': '失錢的比喻'}),
    ('prodigal-son', [('Luke', 15, 11, 32)],
     {'en': 'The Prodigal Son', 'zh-Hans': '浪子的比喻', 'zh-Hant': '浪子的比喻'}),
    ('shrewd-manager', [('Luke', 16, 1, 13)],
     {'en': 'The Shrewd Manager', 'zh-Hans': '不义管家的比喻', 'zh-Hant': '不義管家的比喻'}),
    ('rich-man-lazarus', [('Luke', 16, 19, 31)],
     {'en': 'The Rich Man and Lazarus', 'zh-Hans': '财主和拉撒路', 'zh-Hant': '財主和拉撒路'}),
    ('unworthy-servants', [('Luke', 17, 7, 10)],
     {'en': 'The Unworthy Servants', 'zh-Hans': '无用的仆人', 'zh-Hant': '無用的僕人'}),
    ('persistent-widow', [('Luke', 18, 1, 8)],
     {'en': 'The Persistent Widow', 'zh-Hans': '不义的官与寡妇', 'zh-Hant': '不義的官與寡婦'}),
    ('pharisee-and-tax-collector', [('Luke', 18, 9, 14)],
     {'en': 'The Pharisee and the Tax Collector', 'zh-Hans': '法利赛人和税吏', 'zh-Hant': '法利賽人和稅吏'}),
    ('workers-in-the-vineyard', [('Matthew', 20, 1, 16)],
     {'en': 'The Workers in the Vineyard', 'zh-Hans': '葡萄园的工人', 'zh-Hant': '葡萄園的工人'}),
    ('minas', [('Luke', 19, 11, 27)],
     {'en': 'The Ten Minas', 'zh-Hans': '十锭银子的比喻', 'zh-Hant': '十錠銀子的比喻'}),
    ('two-sons', [('Matthew', 21, 28, 32)],
     {'en': 'The Two Sons', 'zh-Hans': '两个儿子的比喻', 'zh-Hant': '兩個兒子的比喻'}),
    ('wicked-tenants', [('Matthew', 21, 33, 46), ('Mark', 12, 1, 12), ('Luke', 20, 9, 19)],
     {'en': 'The Wicked Tenants', 'zh-Hans': '凶恶园户的比喻', 'zh-Hant': '兇惡園戶的比喻'}),
    ('wedding-banquet', [('Matthew', 22, 1, 14)],
     {'en': 'The Wedding Banquet', 'zh-Hans': '娶亲筵席的比喻', 'zh-Hant': '娶親筵席的比喻'}),
    ('budding-fig-tree', [('Matthew', 24, 32, 35), ('Mark', 13, 28, 31), ('Luke', 21, 29, 33)],
     {'en': 'The Budding Fig Tree', 'zh-Hans': '无花果树发嫩长叶', 'zh-Hant': '無花果樹發嫩長葉'}),
    ('ten-virgins', [('Matthew', 25, 1, 13)],
     {'en': 'The Ten Virgins', 'zh-Hans': '十个童女的比喻', 'zh-Hant': '十個童女的比喻'}),
    ('talents', [('Matthew', 25, 14, 30)],
     {'en': 'The Talents', 'zh-Hans': '按才受托的比喻', 'zh-Hant': '按才受託的比喻'}),
    ('sheep-and-goats', [('Matthew', 25, 31, 46)],
     {'en': 'The Sheep and the Goats', 'zh-Hans': '绵羊与山羊', 'zh-Hant': '綿羊與山羊'}),
    ('vine-and-branches', [('John', 15, 1, 8)],
     {'en': 'The Vine and the Branches', 'zh-Hans': '葡萄树与枝子', 'zh-Hant': '葡萄樹與枝子'}),
]

# The eleven Nave lines the app's own section headings do not cover,
# translated. 2026-09-16 「这些也没用根据语言翻译好」.
#
# Translating a DESCRIPTIVE HEADING is localisation, not exegesis — the
# passage it names is printed beside it and can be checked in one tap,
# and nothing here interprets the passage. They are kept literal and
# close to Nave's English, including his parenthetical locations, so
# that what a Chinese reader sees is the same claim an English reader
# sees. Every other title on the page comes from a source that is
# already trilingual.
_NAVE_ZH = {
    'Preaches throughout Galilee': ('在加利利各处传道', '在加利利各處傳道'),
    'Goes up onto a mountain, and calls and commissions twelve disciples '
    '(in Galilee)':
        ('上山呼召并差派十二使徒（在加利利）', '上山呼召並差派十二使徒（在加利利）'),
    'Cautions his disciples against, the leaven (teachings) of hypocrisy '
    '(on Lake Galilee)':
        ('警戒门徒防备假冒为善的酵（教训）（在加利利海上）',
         '警戒門徒防備假冒為善的酵（教訓）（在加利利海上）'),
    'Foretells his own death and resurrection (in Galilee)':
        ('预言自己的死与复活（在加利利）', '預言自己的死與復活（在加利利）'),
    'The parable of the two sons (in Jerusalem)':
        ('两个儿子的比喻（在耶路撒冷）', '兩個兒子的比喻（在耶路撒冷）'),
    'Foretells his betrayal (in Jerusalem)':
        ('预言自己被卖（在耶路撒冷）', '預言自己被賣（在耶路撒冷）'),
    'Teaches the multitude the conditions of discipleship (in Peraea)':
        ('教导众人作门徒的条件（在比利亚）', '教導眾人作門徒的條件（在比利亞）'),
    'Enunciates the parable of the rich man and Lazarus (in Peraea)':
        ('讲财主和拉撒路的比喻（在比利亚）', '講財主和拉撒路的比喻（在比利亞）'),
    'Teaches the Pharisees concerning the coming of his kingdom (in Peraea)':
        ('教导法利赛人论神国的降临（在比利亚）', '教導法利賽人論神國的降臨（在比利亞）'),
    'Teaches daily in the temple courtyard (in Jerusalem)':
        ('天天在殿院里教训人（在耶路撒冷）', '天天在殿院裡教訓人（在耶路撒冷）'),
    'Teaches people (in Jerusalem)': ('教导众人（在耶路撒冷）', '教導眾人（在耶路撒冷）'),
    'Teaches in Galilee': ('在加利利传道', '在加利利傳道'),
    # The eight that survive only as a NOTE under somebody else's
    # heading. Translated for the same reason as the titles above: a
    # note in a language the reader did not ask for is not a note.
    'Teaches in various towns in Galilee':
        ('在加利利各城教导人', '在加利利各城教導人'),
    'Foretells his own death and resurrection (near Caesarea Philippi)':
        ('预言自己的死与复活（在该撒利亚腓立比附近）',
         '預言自己的死與復活（在該撒利亞腓立比附近）'),
    'Foretells his own death and resurrection (in Peraea)':
        ('预言自己的死与复活（在比利亚）', '預言自己的死與復活（在比利亞）'),
    'Tested by the Pharisees and the Herodians, and enunciates the duty of '
    'a citizen to his government (in Jerusalem)':
        ('法利赛人和希律党人试探他，他讲明百姓对政府的本分（在耶路撒冷）',
         '法利賽人和希律黨人試探他，他講明百姓對政府的本分（在耶路撒冷）'),
    'Foretells the destruction of the temple, and of Jerusalem '
    '(in Jerusalem)':
        ('预言圣殿与耶路撒冷的毁灭（在耶路撒冷）',
         '預言聖殿與耶路撒冷的毀滅（在耶路撒冷）'),
    'Commissions the seventy disciples (in Samaria)':
        ('差派七十个门徒（在撒玛利亚）', '差派七十個門徒（在撒瑪利亞）'),
    'Teaches in the house of Mary, Martha, and Lazarus (in Bethany)':
        ('在马利亚、马大和拉撒路家中教导（在伯大尼）',
         '在馬利亞、馬大和拉撒路家中教導（在伯大尼）'),
    'Teaches in the temple (at Jerusalem) at the Feast of Dedication':
        ('修殿节时在殿里教训人（在耶路撒冷）', '修殿節時在殿裡教訓人（在耶路撒冷）'),
    'Teaches his disciples concerning offenses, meekness, and humility '
    '(in Peraea)':
        ('教导门徒论绊倒人的事、温柔与谦卑（在比利亚）',
         '教導門徒論絆倒人的事、溫柔與謙卑（在比利亞）'),
    # Six more, after the entries folded together and longer Nave lines
    # became the surviving name. 2026-09-16 「这里面语言也没用翻译好」.
    'Eats with tax collectors and sinners, and discourses on fasting '
    '(Capernaum)':
        ('与税吏和罪人一同吃饭，并论禁食（在迦百农）',
         '與稅吏和罪人一同吃飯，並論禁食（在迦百農）'),
    'Journeys toward Jerusalem to attend the Passover; heals many who are '
    'diseased, and teaches the people (in Peraea)':
        ('往耶路撒冷守逾越节，医治许多病人，并教导众人（在比利亚）',
         '往耶路撒冷守逾越節，醫治許多病人，並教導眾人（在比利亞）'),
    'Preaches in the cities of Galilee': ('在加利利各城传道', '在加利利各城傳道'),
    'Discourses to his disciples (in Galilee)':
        ('对门徒的讲论（在加利利）', '對門徒的講論（在加利利）'),
    'Visits Sychar and teaches the Samaritan woman':
        ('到叙加，教导撒玛利亚妇人', '到敘加，教導撒瑪利亞婦人'),
    'Teaches in Jerusalem at the Feast of Tabernacles':
        ('住棚节时在耶路撒冷教训人', '住棚節時在耶路撒冷教訓人'),
}


# Sermon titles are EPISODE titles. The corpus is a preached series, so
# a teaching that took two Sundays is 「不要忧虑（上）」 and 「不要忧虑
# （下）」, and both sermons land on the same passage and merge into one
# entry here. The surviving title then told the reader this was part one
# of something whose part two is nowhere on the page.
# 2026-09-16 「讲道分类 为什么分上下了」.
#
# The trailing reference goes for the same reason: 「葡萄园的工人 —
# 马太福音二十章一至十六节」 prints the passage in the title and the page
# prints it again on the line below.
_PART = re.compile(
    r'\s*[（(]\s*(?:上|中|下|續完|续完|續|续|[一二三四五六七八九十]+|'
    r'Part\s*[0-9IVX]+|[0-9]+)\s*[)）]')
_REF_TAIL = re.compile(r'\s*[—–]\s*[^—–]*[章][^—–]*[节節]\s*$')


def clean_title(title):
    """Strip episode markers and a repeated reference, in every locale."""
    out = {}
    for k, v in title.items():
        v = _REF_TAIL.sub('', v)
        v = _PART.sub('', v)
        # 「主祷文：我们在天上的父」 — the colon survives the marker it
        # followed, and a title must not end on it.
        out[k] = re.sub(r'\s+', ' ', v).strip(' ：: —–-')
    return out


def parse_passage(text):
    """`Mt 13:1-9`, `Lk 8:4-8, 11-15`, `Luke 4:5-13` -> spans."""
    out = []
    if not text:
        return out
    book = None
    for part in re.split(r'[;/]', text):
        part = part.strip()
        if not part:
            continue
        m = re.match(r'^((?:[123]\s*)?[A-Za-z][A-Za-z ]*?)\.?\s+(\d.*)$', part)
        if m:
            raw = re.sub(r'\s+', ' ', m.group(1)).strip()
            book = ABBREV.get(raw) or ABBREV.get(raw.replace(' ', ''))
            rest = m.group(2)
        else:
            rest = part
        if not book:
            continue
        for chunk in rest.split(','):
            chunk = chunk.strip()
            cm = re.match(r'^(\d+):(\d+)\s*-\s*(\d+)$', chunk)
            if cm:
                out.append((book, int(cm.group(1)), int(cm.group(2)),
                            int(cm.group(3))))
                continue
            cm = re.match(r'^(\d+):(\d+)$', chunk)
            if cm:
                out.append((book, int(cm.group(1)), int(cm.group(2)),
                            int(cm.group(2))))
                continue
            cm = re.match(r'^(\d+)$', chunk)
            if cm and out and ':' in rest:
                # `8:4-8, 11-15` — a bare range continues the last chapter.
                continue
            cm = re.match(r'^(\d+)\s*-\s*(\d+)$', chunk)
            if cm and out:
                b, ch, _, _ = out[-1]
                out.append((b, ch, int(cm.group(1)), int(cm.group(2))))
                continue
            cm = re.match(r'^(\d+)$', chunk)
            if cm:
                out.append((book, int(cm.group(1)), 1, 200))
    return out


def parse_nave(ref):
    """`40.13.1-23` / `40.13` -> span."""
    bits = ref.split('.')
    try:
        book = BOOKS[int(bits[0]) - 1]
    except (ValueError, IndexError):
        return None
    if len(bits) == 1:
        return None
    ch = int(re.sub(r'\D', '', bits[1]) or 0)
    if not ch:
        return None
    if len(bits) == 2:
        return (book, ch, 1, 200)
    m = re.match(r'^(\d+)(?:-(\d+))?$', bits[2])
    if not m:
        return (book, ch, 1, 200)
    return (book, ch, int(m.group(1)), int(m.group(2) or m.group(1)))


CHAPTER_LEN = {}


def load_chapter_lengths():
    """Real verse counts, from the bundled KJV.

    `versification.json` is a Hebrew/English mapping, not a length table,
    so a "whole chapter" span was being expanded with a 200-verse
    sentinel — which is harmless for a lookup and a lie in a printed
    reference.
    """
    if CHAPTER_LEN:
        return CHAPTER_LEN
    for row in json.load(open(asset('kjv.json'))):
        key = (row['book'], int(row['chapter']))
        v = int(row['verse'])
        if v > CHAPTER_LEN.get(key, 0):
            CHAPTER_LEN[key] = v
    return CHAPTER_LEN


def clamp(spans):
    """Replace the open sentinel with the chapter's real last verse."""
    lens = load_chapter_lengths()
    out = []
    for book, ch, a, b in spans:
        last = lens.get((book, ch))
        if last:
            b = min(b, last)
            a = min(a, last)
        if b >= a:
            out.append((book, ch, a, b))
    return out


def verses(spans):
    out = []
    for book, ch, a, b in spans:
        for v in range(a, min(b, 200) + 1):
            out.append(f'{book} {ch}:{v}')
    return out


def span_label(spans):
    parts = []
    for book, ch, a, b in spans:
        parts.append(f'{book} {ch}:{a}-{b}' if b > a else f'{book} {ch}:{a}')
    return ' · '.join(parts)


def overlaps(x, y):
    for b1, c1, a1, e1 in x:
        for b2, c2, a2, e2 in y:
            if b1 == b2 and c1 == c2 and a1 <= e2 and a2 <= e1:
                return True
    return False


SECTION_SETS = {'zh-Hans': 'cuv', 'zh-Hant': 'cuv-tr', 'en': 'english-classic'}


def load_sections():
    """The app's own trilingual section headings, by book and chapter.

    Nave's outline is English in this dataset, so an entry taken from it
    showed an English sentence to a Chinese reader — 27 of the 87 did.
    Rather than translate Nave myself, the app's OWN section headings
    are used where they cover the passage: they are bundled, trilingual,
    keyed to the verse, and already what this reader sees at the top of
    that passage in the reading pane. Nave's line is kept underneath as
    a note, because it carries what a heading does not — which journey
    it happened on, whether it is the second telling.
    """
    doc = json.load(open(asset('section_titles.json')))
    out = {}
    for locale, name in SECTION_SETS.items():
        for book, chapters in doc['sets'][name].items():
            for ch, entries in chapters.items():
                for e in entries:
                    out.setdefault((book, int(ch)), {}).setdefault(
                        int(e['verse']), {})[locale] = e['title']
    return out


def section_title(sections, spans):
    """A heading that BEGINS inside the teaching, if there is one.

    Not "the nearest heading at or before the first verse", which was
    tried first and is wrong: the heading covering Matthew 4:23 begins
    at 4:18 and is 呼召四个门徒 — the calling of the four — so
    `Preaches throughout Galilee` came out titled as a different event
    entirely. A heading only names this teaching if this teaching is
    where it starts.
    """
    if not spans:
        return None
    book, ch, start, end = spans[0]
    marks = sections.get((book, ch)) or {}
    at = sorted(marks)
    last = load_chapter_lengths().get((book, ch), end)
    for i, verse in enumerate(at):
        if not (start <= verse <= end):
            continue
        # AND IT MUST BEGIN WHERE THE TEACHING BEGINS. Luke 12 carries
        # one heading, 无知财主的比喻 at 12:13, and Nave's line for that
        # chapter is the whole of it — so a fifty-nine-verse discourse
        # came out named after the one parable in the middle of it.
        if verse - start > 2:
            return None
        # AND THE TEACHING MUST BE MOST OF WHAT THE HEADING COVERS.
        # 「begins inside the span」 alone is not enough: Nave's
        # `Preaches in the cities of Galilee` is Luke 8:1-3, the women
        # who provided for him, and the CUV heading that begins at 8:1
        # runs to 8:15 and is 撒种的比喻 — so a three-verse travel note
        # came out titled as the parable of the sower, a third time,
        # next to the two real entries for it. A heading names this
        # teaching only if this teaching is most of what it covers.
        stop = at[i + 1] - 1 if i + 1 < len(at) else last
        covered = min(end, stop) - verse + 1
        if covered * 2 < stop - verse + 1:
            return None
        # AND MOST OF THE TEACHING. The other direction of the same
        # error: Nave's `Discourses to his disciples` is the whole of
        # Luke 12, and the first heading inside it covers 12:13-21 —
        # so a fifty-nine-verse discourse came out named after the one
        # parable in the middle of it.
        if (stop - verse + 1) * 2 < end - start + 1:
            return None
        got = marks[verse]
        return got if len(got) == len(SECTION_SETS) else None
    return None


def _localised(note):
    if not note:
        return None
    kept = {k: v for k, v in note.items()
            if k == 'en' or re.search(r'[\u4e00-\u9fff]', v)}
    return kept or None


def main():
    sermons = json.load(open(asset('sermons', 'index.json')))
    sections = load_sections()
    refs = json.load(open(asset('sermons', 'refs.json')))
    by_verse = refs['byVerse']
    xr = json.load(open(asset('cross_references.json')))
    plates = json.load(open(asset('maps_index.json')))
    nave_idx = json.load(open(asset('nave', 'index.json')))

    entries = []

    # 1. The text's own divisions.
    for eid, book, c0, v0, c1, v1, title in _STRUCTURAL:
        spans = ([(book, c0, v0, 200)] if c1 != c0 else [(book, c0, v0, v1)])
        if c1 != c0:
            for ch in range(c0 + 1, c1):
                spans.append((book, ch, 1, 200))
            spans.append((book, c1, 1, v1))
        entries.append({'id': eid, 'title': title, 'spans': clamp(spans),
                        'origin': 'structure'})

    # 1b. The parables, each a teaching of its own.
    for pid, spans, title in _PARABLES:
        entries.append({'id': 'parable-' + pid, 'title': dict(title),
                        'spans': clamp(list(spans)), 'origin': 'parable'})

    # 2. The owner's own sermon series, in its own order.
    TOPICS = {'The Parables of Jesus', 'Sermon on the Mount',
              'The Beatitudes'}
    for s in sorted(sermons, key=lambda s: s['id']):
        if s.get('topic') not in TOPICS:
            continue
        spans = [sp for sp in parse_passage(s.get('passage', ''))
                 if sp[0] in GOSPELS]
        if not spans:
            continue
        entries.append({
            'id': 'sermon-' + s['id'],
            'title': {'en': s['titles']['en'], 'zh-Hans': s['titles']['zh-CN'],
                      'zh-Hant': s['titles']['zh-TW']},
            'spans': clamp(spans),
            'origin': 'sermon',
            'topic': s['topic'],
        })

    # 3. Nave's life-of-Christ outline, for teachings the corpus misses.
    per = nave_idx['topicsPerShard']
    for i, t in enumerate(nave_idx['topics']):
        if t[0] != 'JESUS, THE CHRIST':
            continue
        shard = json.load(open(asset('nave', 't', f'{i // per}.json')))
        lines = shard[str(i)]['l']
        # ONLY THE LIFE OUTLINE. The article's depth-1 headings are
        # `HISTORY OF` at line 0 and then `MISCELLANEOUS FACTS
        # CONCERNING` at 164, after which the article turns into
        # character attributes — `Teacher`, `Preaching`,
        # `Unostentatious in his teaching`. Those match the keyword rule
        # and are not teachings, so the outline is cut where Nave cuts
        # it rather than where the words happen to fall.
        end = next((j for j, l in enumerate(lines)
                    if j > 0 and l.get('d') == 1), len(lines))
        for line in lines[:end]:
            title = (line.get('t') or '').strip()
            if not line.get('r') or not _TEACHING_WORDS.search(title):
                continue
            spans = [sp for sp in (parse_nave(r) for r in line['r'])
                     if sp and sp[0] in GOSPELS]
            if not spans:
                continue
            spans = clamp(spans)
            # A LINE THAT CITES WHOLE CHAPTERS IS NAMING A DISCOURSE.
            # Nave's `Delivers the "Sermon on the Mount"` carries
            # 40.5, 40.6, 40.7 — Matthew 5, 6 and 7 entire. Merged as
            # an ordinary teaching it was absorbed by the first sermon
            # that touched chapter 5, and the beatitude on 5:3 came out
            # claiming the whole chapter. Whole-chapter lines are
            # containers, like the structural entries, and take the same
            # exemption from merging with their own parts.
            lens = load_chapter_lengths()
            whole = all(a == 1 and z == lens.get((b, c), z)
                        for b, c, a, z in spans)
            # IS THIS LINE A PARALLEL SET? Nave lists the synoptic
            # parallels of one teaching on one line — the sower is
            # Mt 13:1-23, Mk 4:1-25, Lk 8:4-18 — and those belong
            # together on the page 「有平行经文的也要放在一起」.
            #
            # But he also lumps unrelated passages onto a line, and that
            # is where the Mark 15 defect came from: `Teaches in
            # Galilee` cites Mt 4:17, Mk 1:14, Mk 15, Lk 4:14,
            # Lk 15:1-32 and Jn 4:43-45. The two shapes are told apart
            # by a fact about the citation, not by reading it — a true
            # parallel set names AT MOST ONE passage per gospel.
            per_book = collections.Counter(b for b, _, _, _ in spans)
            parallel = max(per_book.values()) == 1 and len(spans) > 1
            # AND A LINE THAT IS NOT A PARALLEL SET IS NOT A SPAN SET.
            # `Teaches in Galilee` cites Matthew 4:17, Mark 1:14, Mark
            # 15, Luke 4:14, Luke 15:1-32 and John 4:43-45 — six places
            # that are not one teaching. Until the parables were added
            # this line was always absorbed by something and the damage
            # never showed; on its own it came out as a teaching whose
            # references include the crucifixion. Nave's lines are in
            # canonical order, so the first is the one he is naming.
            if not parallel and len(per_book) != len(spans):
                spans = spans[:1]
            entries.append({
                'id': 'nave-' + re.sub(r'[^a-z0-9]+', '-', title.lower())[:44],
                'title': {'en': title, 'zh-Hans': title, 'zh-Hant': title},
                'spans': spans,
                'parallel': parallel,
                'origin': 'structure' if whole else 'nave',
            })
        break

    # ── merge ────────────────────────────────────────────────────────
    #
    # Three sources will name the same teaching. They are merged on the
    # verses they cover, not on their titles, because the titles are in
    # three different registers — Nave's is a sentence about Jesus
    # ("Enunciates the parable of the sower"), the sermon's is the
    # owner's own heading, the structural one is the passage's name.
    #
    # WHICH TITLE WINS: the sermon's, then the structural one, then
    # Nave's. The sermon corpus is the owner's own exposition and is
    # already trilingual; Nave's is English-only in this dataset, so a
    # Nave title shows the same English in all three locales and is the
    # last resort rather than the default.
    #
    # STRUCTURAL ENTRIES DO NOT MERGE, and that is the difference
    # between a list and a hierarchy. The Sermon on the Mount CONTAINS
    # the Beatitudes, which contain twelve sermons on single verses; a
    # flat merge cannot say so, and the first build showed what happens
    # when it tries — the first beatitude's sermon absorbed the whole
    # discourse and the Sermon on the Mount stopped existing as an
    # entry. The containers stay whole and the parts point at them
    # through `partOf`.
    # The parable's own name beats an exposition's title, so it is
    # added first and keeps it.
    RANK = {'parable': 0, 'sermon': 1, 'structure': 2, 'nave': 3}
    merged = []
    for e in sorted(entries, key=lambda e: RANK[e['origin']]):
        for m in merged:
            if (m['origin'] == 'structure') != (e['origin'] == 'structure'):
                continue
            # A PARABLE'S REFERENCE IS EXACT AND DOES NOT MOVE.
            #
            # The widening below is right for three sources that are
            # each describing a passage loosely. It is wrong here: the
            # parable list gives the passage itself, and letting it grow
            # destroyed the list it was added to produce. The lamp under
            # a bowl vanished into the sower, because a sermon had
            # widened one of them through Mark 4 until they touched;
            # the weeds came out spanning Matthew 13:24-53.
            #
            # So a parable only TAKES IN — an exposition of it, when
            # most of that exposition lies inside it — and never
            # changes shape. Two parables never merge at all; they are
            # two teachings.
            if m['origin'] == 'parable' or e['origin'] == 'parable':
                if m['origin'] != 'parable' or e['origin'] == 'parable':
                    continue
                mine = set(verses(m['spans']))
                his = verses(e['spans'])
                if not his or sum(v in mine for v in his) * 5 < len(his) * 3:
                    continue
                m['origins'].append(e['origin'])
                break
            if overlaps(m['spans'], e['spans']):
                m['origins'].append(e['origin'])
                # WIDEN ONLY WHERE THEY MEET. Taking the other entry's
                # spans wholesale looked reasonable and was wrong:
                # Nave's outline lines carry the PARALLEL references for
                # one teaching, so `Teaches in Galilee` holds Mt 4:17,
                # Mk 1:14, Mk 15, Lk 4:14, Lk 15:1-32 and Jn 4:43-45.
                # A sermon on Luke 15:1-7 overlaps that on Luke 15 —
                # and the parable of the lost sheep then claimed Mark
                # 15, the crucifixion, as part of itself.
                #
                # So a merge may only extend a span within a chapter the
                # two already share.
                #
                # AND NEVER ADOPT A WHOLE CHAPTER. A reference to a
                # chapter entire is a container reference wherever it
                # turns up, not only in the lines caught above: Nave
                # lines mix `40.5.3-12` with a bare `40.5`, so the
                # whole-chapter test at construction cannot see all of
                # them. Without this, the beatitude on Matthew 5:3 came
                # out spanning Matthew 5:1-48.
                lens = load_chapter_lengths()
                # A parallel set contributes the books the anchor does
                # not have — that is the whole point of merging it.
                if e.get('parallel'):
                    have = {b for b, _, _, _ in m['spans']}
                    for sp in e['spans']:
                        if sp[0] not in have:
                            m['spans'].append(sp)
                grown = []
                for b, c, a, z in m['spans']:
                    for b2, c2, a2, z2 in e['spans']:
                        if b2 != b or c2 != c or a2 > z or a > z2:
                            continue
                        if a2 == 1 and z2 == lens.get((b2, c2), z2):
                            continue
                        a, z = min(a, a2), max(z, z2)
                    grown.append((b, c, a, z))
                m['spans'] = grown
                break
        else:
            e['origins'] = [e['origin']]
            merged.append(e)

    # WHAT KIND OF TEACHING, decided by the sources rather than by me:
    # the owner's own sermon series says which sermons are on parables,
    # Nave says `parable` in the line itself, and the structural entries
    # are discourses by construction. Anything else is left as a plain
    # teaching rather than being forced into a category.
    for e in merged:
        if e['origin'] == 'parable':
            e['kind'] = 'parable'
        elif e['origin'] == 'structure':
            e['kind'] = 'discourse'
        elif e.get('topic') == 'The Parables of Jesus' or \
                re.search(r'parable', e['title']['en'], re.I):
            e['kind'] = 'parable'
        else:
            e['kind'] = 'teaching'

    order = {b: i for i, b in enumerate(BOOKS)}
    merged.sort(key=lambda e: (order[e['spans'][0][0]], e['spans'][0][1],
                               e['spans'][0][2]))

    # ── fold, so that the list is a list ─────────────────────────────
    #
    # The first build made this two levels deep: the Sermon on the Mount
    # held fifteen parts, indented under it, and eighty-seven rows came
    # out of fifty-four teachings. 2026-09-16 「类似于登山宝训下面的都放
    # 在一起 平行经文的放在一个下面但是同时要包含相关信息 所以就要非常
    # 简单」 — one row per teaching, everything the parts knew carried
    # INTO that row rather than shown beside it.
    #
    # Two entries are the same teaching when one's verses lie wholly
    # inside the other's, or when both BEGIN at the same verse. The
    # second test is what catches the pairs that differ only in how far
    # a source ran on: Luke 10:1-12 and Luke 10:1-16 are both the
    # sending of the seventy, and they sat next to each other as two
    # teachings with almost the same name.
    #
    # The longest span survives, because it is the whole teaching. The
    # best-sourced TITLE survives, which is usually a different entry:
    # a Nave line running to Luke 10:16 should not take the name away
    # from the passage's own. Nothing is discarded — the folded entry's
    # own name is kept in `contains`, and its sermons, cross-references
    # and plates were already inside the surviving span, so they are
    # found again when that span is looked up.
    TITLE_RANK = {'parable': 0, 'structure': 1, 'sermon': 2, 'nave': 3}

    def head(e):
        return min((order[b], c, a) for b, c, a, _ in e['spans'])

    for e in merged:
        e['title'] = clean_title(e['title'])
        e['vs'] = set(verses(e['spans']))
        e['contains'] = []

    def starts(e):
        return {(b, c, a) for b, c, a, _ in e['spans']}

    def partOf(x):
        return {'title': x['title'], 'label': span_label(x['spans']),
                'ref': span_label(x['spans'][:1])}

    def loserOf(e, m):
        return m if TITLE_RANK[e['origin']] < TITLE_RANK[m['origin']] else e

    kept = []
    for e in sorted(merged, key=lambda e: (-len(e['vs']), head(e))):
        for m in kept:
            # A PARABLE IS NEVER FOLDED INTO ANYTHING ELSE, and nothing
            # else is folded into a parable.
            #
            # 2026-09-16 「Scholars generally count between 30 and 40
            # parables told by Jesus ... 这里却并没有看出来 好像只有15个」,
            # and that was the folding doing it: Matthew 13 is a
            # discourse, so the sower, the tares, the mustard seed, the
            # treasure, the pearl and the net all disappeared into one
            # row called 天国的比喻. They are not PARTS of a teaching the
            # way a sermon on Matthew 5:4 is part of the Sermon on the
            # Mount — each is a teaching with its own name, and a page
            # that exists so a reader can see what the Lord taught has
            # to show them.
            #
            # Between two parables the test is stricter still: they fold
            # only when they BEGIN at the same verse, never on
            # containment. One sermon covers Matthew 24:45-25:30 as a
            # set, and containment would have swallowed the ten virgins
            # and the talents into it.
            if (e['kind'] == 'parable') != (m['kind'] == 'parable'):
                continue
            if e['kind'] == 'parable':
                if not (starts(e) & starts(m)):
                    continue
            elif not (e['vs'] <= m['vs'] or head(e) == head(m)):
                continue
            m['origins'] += e['origins']
            # A CANONICAL PARABLE STILL DOES NOT MOVE, here either.
            # The fold runs longest-first, and a sermon whose passage
            # the first merge had widened is longer than the parable it
            # expounds — which is how the weeds came out spanning
            # Matthew 13:24-53 and the ten virgins 25:1-30.
            if m['origin'] == 'parable' or e['origin'] == 'parable':
                par = m if m['origin'] == 'parable' else e
                m['spans'] = par['spans']
                m['vs'] = set(verses(par['spans']))
                if loserOf(e, m) is not m:
                    m['contains'].append(partOf(e))
                else:
                    m['contains'].append(partOf(m))
                    m['title'], m['origin'], m['kind'] = (
                        e['title'], e['origin'], e['kind'])
                m['contains'] = m['contains']
                break
            m['vs'] |= e['vs']
            # THE SURVIVING SPAN IS THE UNION. Folding by a shared first
            # verse can meet an entry that runs further than the one it
            # folds into: the sermon on the sower carries the synoptic
            # parallels and starts at Matthew 13:1, the same verse as
            # the discourse that runs to 13:52 — and keeping only the
            # longer-by-verse-count of the two dropped half of Matthew
            # 13 off the page.
            grown = []
            for b, c, a, z in m['spans']:
                for b2, c2, a2, z2 in e['spans']:
                    if b2 == b and c2 == c:
                        a, z = min(a, a2), max(z, z2)
                grown.append((b, c, a, z))
            have = {(b, c) for b, c, _, _ in grown}
            grown += [sp for sp in e['spans'] if (sp[0], sp[1]) not in have]
            m['spans'] = sorted(grown, key=lambda sp: (order[sp[0]], sp[1]))
            m['vs'] |= set(verses(m['spans']))
            loser = e
            if TITLE_RANK[e['origin']] < TITLE_RANK[m['origin']]:
                loser, m['origin'], m['kind'] = m, e['origin'], e['kind']
                # The displaced title is a description of the same
                # passage, so it goes where descriptions of the passage
                # go rather than into the list of what this contains.
                # The displaced title becomes the note. If it is a
                # Nave sentence we have a translation for, it carries
                # that translation with it rather than showing the
                # same English under all three locale keys.
                note = dict(loser['title'])
                zh = _NAVE_ZH.get(
                    re.sub(r'\s+', ' ', note.get('en', '')).strip())
                if zh:
                    note['zh-Hans'], note['zh-Hant'] = zh
                m.setdefault('note', note)
                m['title'] = e['title']
            if loser['title']['zh-Hans'] != m['title']['zh-Hans']:
                m['contains'].append({
                    'title': loser['title'],
                    'label': span_label(loser['spans']),
                    # What a tap opens. The label may name several
                    # parallel passages and `parseReference` takes one.
                    'ref': span_label(loser['spans'][:1])})
            break
        else:
            kept.append(e)
    merged = kept

    for e in merged:
        seen = set()
        e['contains'] = [c for c in e['contains']
                         if not (c['title']['zh-Hans'] in seen
                                 or seen.add(c['title']['zh-Hans']))]

    merged.sort(key=lambda e: head(e))

    # ── attach ───────────────────────────────────────────────────────
    plate_by_book = collections.defaultdict(list)
    for pl in plates:
        for book, rng in (pl.get('books') or {}).items():
            plate_by_book[book].append((rng[0], rng[1], pl))

    def cross(vs, want):
        """TSK links into `want`, most-linked first.

        Ordering is the SOURCE's, twice over: TSK/OpenBible already
        ranks each verse's own references by community vote, and a
        reference several verses of one teaching point at is commoner
        than one only a single verse points at. Nothing here is my
        judgement about which link matters.
        """
        hits = collections.Counter()
        rank = {}
        for v in vs:
            for j, target in enumerate(xr.get(v, [])):
                b = target.split(':')[0].rsplit(' ', 1)[0]
                if b in want:
                    hits[target] += 1
                    rank.setdefault(target, j)
        return [t for t, _ in sorted(
            hits.items(), key=lambda kv: (-kv[1], rank[kv[0]], kv[0]))]

    # Give the English-only entries the app's own heading, in all three
    # locales, and demote Nave's sentence to a note.
    filled = 0
    translated = 0
    for e in merged:
        if re.search(r'[\u4e00-\u9fff]', e['title']['zh-Hans']):
            continue
        got = section_title(sections, e['spans'])
        if got:
            # Nave's own sentence, kept underneath because it carries
            # what a heading does not. Trilingual where we have a
            # translation for it and English-only where we do not — the
            # page then shows nothing rather than a sentence the reader
            # did not ask for. 2026-09-16 「这里面语言也没用翻译好」.
            zh = _NAVE_ZH.get(re.sub(r'\s+', ' ', e['title']['en']).strip())
            e['note'] = {'en': e['title']['en']}
            if zh:
                e['note']['zh-Hans'], e['note']['zh-Hant'] = zh
            e['title'] = dict(got)
            filled += 1
            continue
        zh = _NAVE_ZH.get(re.sub(r'\s+', ' ', e['title']['en']).strip())
        if zh:
            e['title'] = {'en': e['title']['en'],
                          'zh-Hans': zh[0], 'zh-Hant': zh[1]}
            translated += 1

    out = []
    for e in merged:
        vs = verses(e['spans'])
        ids = []
        for v in vs:
            for sid in by_verse.get(v, []):
                if sid not in ids:
                    ids.append(sid)
        by_id = {s['id']: s for s in sermons}
        # PLATES, NARROWEST FIRST. Matched by chapter alone, the whole-
        # book maps win every time — `israel_nt_times` is filed Matthew
        # 1-28 and so belongs to every teaching in Matthew. The first
        # build gave all 76 teachings the same eight general maps.
        # Ranking by how tightly a plate is scoped puts the plate that
        # is about THIS passage first and leaves the atlas behind it.
        scored = {}
        for book, ch, _, _ in e['spans']:
            for lo, hi, pl in plate_by_book.get(book, []):
                if lo <= ch <= hi:
                    width = hi - lo
                    if pl['id'] not in scored or width < scored[pl['id']][0]:
                        scored[pl['id']] = (width, pl)
        pls = [pl for _, pl in sorted(scored.values(),
                                      key=lambda w: (w[0], w[1]['id']))]
        apostles = cross(vs, EPISTLES | {'Acts'})
        out.append({
            'id': e['id'],
            'title': e['title'],
            # A note is shown in the reader's language or not at all.
            # Some of these are a displaced title from a source that is
            # English-only, and its map then carries the same English
            # under every locale key — which is exactly the thing the
            # page was told to stop doing.
            'note': _localised(e.get('note')),
            'origins': sorted(set(e['origins'])),
            'contains': e['contains'],
            'kind': e['kind'],
            'refs': [{'book': b, 'chapter': c, 'start': a, 'end': z}
                     for b, c, a, z in e['spans']],
            'label': span_label(e['spans']),
            'sermons': [
                {'id': i, 'title': by_id[i]['titles'], 'date': by_id[i]['date'],
                 'topic': by_id[i].get('topic', '')}
                # An entry that folded others in stands for all of them,
                # so its sermon list has to hold all of theirs — the
                # Sermon on the Mount alone carries more than twelve.
                for i in ids if i in by_id][:40 if e['contains'] else 12],
            'oldTestament': cross(vs, OT)[:12],
            # THE CAP MAY NOT TRIM A LORD'S-WORD LINK. Those are the
            # only links on the page that assert dependence rather than
            # relation, and it is scripture asserting it. Once the
            # entries folded together their verse sets grew, and
            # 1 Corinthians 9:14 — where Paul says the Lord commanded
            # it — fell past the twelfth place and off the page.
            'apostles': [
                {'ref': r,
                 'lordsWord': _LORDS_WORD.get(r.split('-')[0].strip())}
                for r in apostles[:12] + [
                    a for a in apostles[12:]
                    if a.split('-')[0].strip() in _LORDS_WORD]],
            # The plate's own NAME, not its asset id. The first build
            # printed `illus_tissot_healing_of_the_lepers_at_capernaum`
            # at the reader, which is a filename wearing a chip.
            'plates': [
                {'id': p['id'], 'title': p['title']} for p in pls[:8]],
        })

    doc = {
        '_meta': {
            'title': 'The Teachings of the Lord Jesus',
            'arrangement': (
                "Editorial. There is no canonical enumeration of Jesus' "
                "teachings; the parables are a stable category and the "
                "discourses are not. Ordered canonically. Entries come from "
                "the text's own divisions (Matthew's five discourses, John's "
                "discourses), from the sermon corpus's own series, and from "
                "Nave's Topical Bible life-of-Christ outline."),
            'sources': {
                'sermons': 'assets/sermons — the corpus bundled with this app',
                'outline': "Nave's Topical Bible (1896), 'JESUS, THE CHRIST', "
                           'public domain',
                'crossReferences': 'Treasury of Scripture Knowledge merged '
                                   'with OpenBible.info votes',
                'plates': 'assets/maps_index.json',
            },
            # Trilingual, because this sentence is the page's own
            # statement of what it may claim and a reader who cannot
            # read it is being shown a disclaimer in a language they
            # did not ask for. 2026-09-16 「这里面语言也没用翻译好」.
            'claims': {
                'en': 'Cross-references assert that two passages are '
                      'RELATED. They do not assert that one rests on the '
                      'other. The only links marked as dependence are those '
                      'where an apostle says so: 1 Cor 7:10-11, 9:14, '
                      '11:23-25; 1 Thess 4:15; Acts 20:35.',
                'zh-Hans': '串珠只说明两处经文彼此相关，并不说明其中一处以另一处为'
                           '根基。本页只在使徒自己说明是领受主的话的地方标出这层'
                           '关系：林前7:10-11、9:14、11:23-25；帖前4:15；徒20:35。',
                'zh-Hant': '串珠只說明兩處經文彼此相關，並不說明其中一處以另一處為'
                           '根基。本頁只在使徒自己說明是領受主的話的地方標出這層'
                           '關係：林前7:10-11、9:14、11:23-25；帖前4:15；徒20:35。',
            },
            'generator': 'scripts/build_jesus_teachings.py',
            'version': 1,
        },
        'teachings': out,
    }
    path = asset('jesus_teachings.json')
    with open(path, 'w') as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)

    print(f'{len(entries)} raw -> {len(out)} teachings')
    print(f'section headings filled in: {filled}, translated: {translated}')
    print('kinds:', collections.Counter(e['kind'] for e in out))
    print('with parallels in 2+ gospels:',
          sum(1 for e in out
              if len({r['book'] for r in e['refs']}) > 1))
    left = sum(1 for e in out
               if not re.search(r'[\u4e00-\u9fff]', e['title']['zh-Hans']))
    print(f'still English-only in a Chinese UI: {left}')
    print(collections.Counter(o for e in out for o in e['origins']))
    print(f"with a sermon: {sum(1 for e in out if e['sermons'])}")
    print(f"with OT links: {sum(1 for e in out if e['oldTestament'])}")
    print(f"with apostles: {sum(1 for e in out if e['apostles'])}")
    print(f"with plates:   {sum(1 for e in out if e['plates'])}")
    print(f"Lord's word marked: "
          f"{sum(1 for e in out for a in e['apostles'] if a['lordsWord'])}")
    print(f"written {path} "
          f"({os.path.getsize(path)/1024:.0f} KB)")
    for e in out[:6]:
        print(f"  {e['label'][:26]:28} {e['title']['zh-Hans'][:20]:22} "
              f"讲{len(e['sermons'])} 旧{len(e['oldTestament'])} "
              f"使{len(e['apostles'])} 图{len(e['plates'])}")


if __name__ == '__main__':
    main()
