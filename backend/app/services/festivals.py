"""Festival dates computed from the lunar calendar.

Each lunar festival is defined by its amanta month, tithi and the part of the
day at which that tithi must prevail (udaya/sunrise, madhyahna, aparahna,
pradosh or nishita), following common Panchang conventions. Solar festivals
use the Sun's sidereal ingress. Results are approximations of regional
practice; admins can override any date from the dashboard.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta
from functools import lru_cache
from zoneinfo import ZoneInfo

from app.services import panchang
from app.services.panchang import Location


@dataclass(frozen=True)
class FestivalRule:
    slug: str
    name: str
    name_hi: str
    deity: str
    month: int | None = None  # amanta month index, 0 = Chaitra
    tithi: int | None = None  # 0..29, 14 = Purnima, 29 = Amavasya
    observe: str = "sunrise"  # sunrise | madhyahna | aparahna | pradosh | nishita | sunset
    sankranti: int | None = None  # sidereal sign the Sun enters
    after: str | None = None  # observed the day after another festival
    major: bool = True
    description: str = ""


S, K = 0, 15  # offsets for Shukla / Krishna paksha (tithi numbers are 1-based below)


def _t(paksha: int, n: int) -> int:
    return paksha + n - 1


FESTIVALS: list[FestivalRule] = [
    FestivalRule("makar-sankranti", "Makar Sankranti", "मकर संक्रांति", "surya", sankranti=9,
                 description="The Sun enters Makara; a harvest festival of holy dips, til-gud and kites."),
    FestivalRule("vasant-panchami", "Vasant Panchami", "वसंत पंचमी", "saraswati", 10, _t(S, 5), "madhyahna",
                 description="Worship of Maa Saraswati, goddess of learning, at the start of spring."),
    FestivalRule("maha-shivratri", "Maha Shivratri", "महाशिवरात्रि", "shiva", 10, _t(K, 14), "nishita",
                 description="The great night of Shiva, kept with fasting, night-long vigil and abhishek."),
    FestivalRule("holika-dahan", "Holika Dahan", "होलिका दहन", "vishnu", 11, _t(S, 15), "pradosh",
                 description="The bonfire recalling Prahlad's devotion and Holika's defeat."),
    FestivalRule("holi", "Holi", "होली", "krishna", after="holika-dahan",
                 description="The festival of colours celebrating spring, love and the victory of good."),
    FestivalRule("ugadi", "Ugadi / Gudi Padwa", "उगादी / गुड़ी पड़वा", "brahma", 0, _t(S, 1),
                 description="New Year by the lunar calendar; Chaitra Navratri also begins today."),
    FestivalRule("ram-navami", "Ram Navami", "राम नवमी", "rama", 0, _t(S, 9), "madhyahna",
                 description="The birth of Shri Ram, celebrated at midday with Ramayan path and bhajans."),
    FestivalRule("hanuman-jayanti", "Hanuman Jayanti", "हनुमान जयंती", "hanuman", 0, _t(S, 15),
                 description="The birth of Hanuman Ji, honoured with Hanuman Chalisa and Sundarkand."),
    FestivalRule("akshaya-tritiya", "Akshaya Tritiya", "अक्षय तृतीया", "lakshmi", 1, _t(S, 3),
                 description="An auspicious day for new beginnings, charity and Lakshmi-Narayan puja."),
    FestivalRule("buddha-purnima", "Buddha Purnima", "बुद्ध पूर्णिमा", "vishnu", 1, _t(S, 15), major=False,
                 description="Vaishakha Purnima, remembered as the birth of the Buddha."),
    FestivalRule("ganga-dussehra", "Ganga Dussehra", "गंगा दशहरा", "ganga", 2, _t(S, 10), major=False,
                 description="The descent of Maa Ganga to earth."),
    FestivalRule("nirjala-ekadashi", "Nirjala Ekadashi", "निर्जला एकादशी", "vishnu", 2, _t(S, 11), major=False,
                 description="The strictest Ekadashi fast, kept without water."),
    FestivalRule("rath-yatra", "Jagannath Rath Yatra", "जगन्नाथ रथ यात्रा", "krishna", 3, _t(S, 2),
                 description="Lord Jagannath's chariot procession, famous at Puri."),
    FestivalRule("devshayani-ekadashi", "Devshayani Ekadashi", "देवशयनी एकादशी", "vishnu", 3, _t(S, 11), major=False,
                 description="Lord Vishnu begins his cosmic rest; Chaturmas starts."),
    FestivalRule("guru-purnima", "Guru Purnima", "गुरु पूर्णिमा", "guru", 3, _t(S, 15),
                 description="Gratitude to the Guru and to Maharishi Ved Vyas."),
    FestivalRule("nag-panchami", "Nag Panchami", "नाग पंचमी", "shiva", 4, _t(S, 5), major=False,
                 description="Worship of the serpent deities."),
    FestivalRule("raksha-bandhan", "Raksha Bandhan", "रक्षा बंधन", "krishna", 4, _t(S, 15),
                 description="Sisters tie rakhi; a festival of love and protection."),
    FestivalRule("janmashtami", "Krishna Janmashtami", "कृष्ण जन्माष्टमी", "krishna", 4, _t(K, 8),
                 description="The birth of Shri Krishna, celebrated with midnight puja and bhajans."),
    FestivalRule("hartalika-teej", "Hartalika Teej", "हरतालिका तीज", "parvati", 5, _t(S, 3), major=False,
                 description="A fast honouring Maa Parvati's devotion to Shiva."),
    FestivalRule("ganesh-chaturthi", "Ganesh Chaturthi", "गणेश चतुर्थी", "ganesha", 5, _t(S, 4), "madhyahna",
                 description="The arrival of Ganpati Bappa, welcomed for ten days of celebration."),
    FestivalRule("anant-chaturdashi", "Anant Chaturdashi", "अनंत चतुर्दशी", "ganesha", 5, _t(S, 14), major=False,
                 description="Ganesh Visarjan and worship of Anant (Vishnu)."),
    FestivalRule("pitru-paksha", "Pitru Paksha begins", "पितृ पक्ष आरंभ", "pitru", 5, _t(K, 1), major=False,
                 description="A fortnight of remembrance and offerings for ancestors."),
    FestivalRule("sharad-navratri", "Sharad Navratri begins", "शारदीय नवरात्रि आरंभ", "durga", 6, _t(S, 1),
                 description="Nine nights of Maa Durga's worship begin with Ghatasthapana."),
    FestivalRule("durga-ashtami", "Durga Ashtami", "दुर्गा अष्टमी", "durga", 6, _t(S, 8),
                 description="Maha Ashtami, with Kanya Puja and Sandhi Puja."),
    FestivalRule("dussehra", "Dussehra / Vijayadashami", "दशहरा / विजयादशमी", "rama", 6, _t(S, 10), "aparahna",
                 description="Victory of Shri Ram over Ravan and of Maa Durga over Mahishasur."),
    FestivalRule("sharad-purnima", "Sharad Purnima", "शरद पूर्णिमा", "lakshmi", 6, _t(S, 15), "pradosh", major=False,
                 description="The full moon of autumn; kheer is kept under moonlight."),
    FestivalRule("karwa-chauth", "Karwa Chauth", "करवा चौथ", "parvati", 6, _t(K, 4),
                 description="Married women fast from sunrise to moonrise for their husbands."),
    FestivalRule("dhanteras", "Dhanteras", "धनतेरस", "lakshmi", 6, _t(K, 13), "pradosh",
                 description="The first day of Diwali; worship of Dhanvantari and Kuber."),
    FestivalRule("narak-chaturdashi", "Narak Chaturdashi", "नरक चतुर्दशी", "krishna", 6, _t(K, 14), major=False,
                 description="Choti Diwali, remembering Krishna's victory over Narakasur."),
    FestivalRule("diwali", "Diwali / Lakshmi Puja", "दीपावली / लक्ष्मी पूजा", "lakshmi", 6, _t(K, 15), "pradosh",
                 description="The festival of lights: Lakshmi-Ganesh puja on Kartika Amavasya evening."),
    FestivalRule("govardhan-puja", "Govardhan Puja", "गोवर्धन पूजा", "krishna", 7, _t(S, 1),
                 description="Annakoot offered to Krishna, who lifted Govardhan hill."),
    FestivalRule("bhai-dooj", "Bhai Dooj", "भाई दूज", "yama", 7, _t(S, 2),
                 description="Sisters pray for their brothers' long life."),
    FestivalRule("chhath-puja", "Chhath Puja", "छठ पूजा", "surya", 7, _t(S, 6), "sunset",
                 description="Evening arghya to the setting Sun and Chhathi Maiya."),
    FestivalRule("dev-uthani-ekadashi", "Dev Uthani Ekadashi", "देवउठनी एकादशी", "vishnu", 7, _t(S, 11),
                 description="Lord Vishnu awakens; Tulsi Vivah and the wedding season begin."),
    FestivalRule("kartik-purnima", "Kartik Purnima / Dev Deepawali", "कार्तिक पूर्णिमा / देव दीपावली", "shiva", 7,
                 _t(S, 15), description="Holy dips and lamps on the ghats; Guru Nanak Jayanti falls today too."),
    FestivalRule("vivah-panchami", "Vivah Panchami", "विवाह पंचमी", "rama", 8, _t(S, 5), major=False,
                 description="The divine wedding of Shri Ram and Mata Sita."),
    FestivalRule("gita-jayanti", "Gita Jayanti", "गीता जयंती", "krishna", 8, _t(S, 11),
                 description="The day Shri Krishna spoke the Bhagavad Gita to Arjuna."),
]

FESTIVALS_BY_SLUG = {f.slug: f for f in FESTIVALS}

# Recurring observances generated for every lunar month.
RECURRING = [
    ("ekadashi", "Ekadashi", "एकादशी", [_t(S, 11), _t(K, 11)], "sunrise", "vishnu"),
    ("purnima", "Purnima", "पूर्णिमा", [_t(S, 15)], "sunrise", "vishnu"),
    ("amavasya", "Amavasya", "अमावस्या", [_t(K, 15)], "sunrise", "pitru"),
    ("pradosh", "Pradosh Vrat", "प्रदोष व्रत", [_t(S, 13), _t(K, 13)], "pradosh", "shiva"),
    ("sankashti", "Sankashti Chaturthi", "संकष्टी चतुर्थी", [_t(K, 4)], "sunrise", "ganesha"),
    ("masik-shivratri", "Masik Shivratri", "मासिक शिवरात्रि", [_t(K, 14)], "nishita", "shiva"),
]


def _observance_moments(ev: dict, days: list[date]) -> dict[str, list[datetime]]:
    out: dict[str, list[datetime]] = {k: [] for k in ("sunrise", "madhyahna", "aparahna", "pradosh", "nishita", "sunset")}
    for d in days:
        rise, set_ = ev[d]["sunrise"], ev[d]["sunset"]
        nxt = ev[d + timedelta(days=1)]["sunrise"]
        daylight = set_ - rise
        out["sunrise"].append(rise)
        out["madhyahna"].append(rise + daylight * 0.5)
        out["aparahna"].append(rise + daylight * 0.7)
        out["sunset"].append(set_)
        out["pradosh"].append(set_ + timedelta(minutes=60))
        out["nishita"].append(set_ + (nxt - set_) / 2)
    return out


@lru_cache(maxsize=64)
def _year_grid(year: int, loc: Location):
    """Per-day observance moments, tithi and lunar month for the year (+/- a margin)."""
    start = date(year, 1, 1) - timedelta(days=20)
    days = [start + timedelta(days=i) for i in range(365 + 50)]
    ev = panchang.sun_events(loc, start, len(days) + 1)
    moments = _observance_moments(ev, days)
    months = panchang.lunar_months(year)
    grid = {}
    for kind, items in moments.items():
        tithis = panchang.tithis_at(items)
        month_info = []
        for m in items:
            info = next((x for x in months if x["start"] <= m < x["end"]), None)
            month_info.append((info["index"], info["adhika"]) if info else (None, None))
        grid[kind] = list(zip(days, tithis, month_info))
    return grid


def _match_days(grid_rows, month: int | None, tithi: int) -> list[date]:
    """First day of each run where `tithi` prevails at the observance time in a nija month."""
    picked: list[date] = []
    prev_hit = False
    for i, (d, t, (m, adhika)) in enumerate(grid_rows):
        hit = t == tithi and not adhika and (month is None or m == month)
        if hit and not prev_hit:
            picked.append(d)
        prev_hit = hit
        # Kshaya: tithi begins and ends between two consecutive observance moments.
        # The tithi may straddle a month boundary (e.g. Pratipada), so either side's month counts.
        if not hit and i + 1 < len(grid_rows):
            _, nt, (nm, nadhika) = grid_rows[i + 1]
            month_ok = month is None or (m == month and not adhika) or (nm == month and not nadhika)
            if t == (tithi - 1) % 30 and nt == (tithi + 1) % 30 and month_ok:
                picked.append(d)
    return picked


def compute_festivals(year: int, loc: Location) -> list[dict]:
    loc = loc.rounded()
    grid = _year_grid(year, loc)
    tz = ZoneInfo(loc.tz)
    results: dict[str, list[date]] = {}
    for rule in FESTIVALS:
        if rule.sankranti is not None:
            ev_days = []
            for sign, moment in panchang.sankranti_times(year):
                if sign != rule.sankranti:
                    continue
                local = moment.astimezone(tz)
                sunset = panchang.sun_events(loc, local.date(), 1)[local.date()]["sunset"]
                ev_days.append(local.date() + timedelta(days=1) if local > sunset else local.date())
            results[rule.slug] = ev_days
        elif rule.after is None:
            results[rule.slug] = _match_days(grid[rule.observe], rule.month, rule.tithi)
    for rule in FESTIVALS:
        if rule.after:
            results[rule.slug] = [d + timedelta(days=1) for d in results.get(rule.after, [])]

    out = []
    for rule in FESTIVALS:
        for d in results.get(rule.slug, []):
            if d.year == year:
                out.append(_festival_dict(rule, d))
    out.sort(key=lambda x: x["date"])
    return out


def compute_recurring(year: int, loc: Location) -> list[dict]:
    loc = loc.rounded()
    grid = _year_grid(year, loc)
    out = []
    for slug, name, name_hi, tithis, observe, deity in RECURRING:
        rows = grid[observe]
        for tithi in tithis:
            for d in _match_days(rows, None, tithi):
                if d.year != year:
                    continue
                paksha = "Shukla" if tithi < 15 else "Krishna"
                month = next((m for (dd, _, m) in rows if dd == d), (None, None))[0]
                month_name = panchang.MONTH_NAMES[month] if month is not None else ""
                out.append({
                    "slug": f"{slug}-{d.isoformat()}",
                    "kind": slug,
                    "name": f"{month_name} {paksha} {name}".strip(),
                    "name_hi": name_hi,
                    "deity": deity,
                    "date": d.isoformat(),
                    "major": False,
                    "computed": True,
                    "description": "",
                })
    out.sort(key=lambda x: x["date"])
    return out


def _festival_dict(rule: FestivalRule, d: date) -> dict:
    return {
        "slug": rule.slug,
        "kind": "festival",
        "name": rule.name,
        "name_hi": rule.name_hi,
        "deity": rule.deity,
        "date": d.isoformat(),
        "major": rule.major,
        "computed": True,
        "description": rule.description,
    }
