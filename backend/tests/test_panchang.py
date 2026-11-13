"""Panchang and festival engine checked against published dates."""

from datetime import date

import pytest

from app.services import festivals, panchang
from app.services.panchang import Location

DELHI = Location(28.6139, 77.2090, "Asia/Kolkata")

# Widely published dates for New Delhi (Drik Panchang, Government of India holiday lists).
KNOWN_2025 = {
    "makar-sankranti": "2025-01-14",
    "vasant-panchami": "2025-02-02",
    "maha-shivratri": "2025-02-26",
    "holika-dahan": "2025-03-13",
    "holi": "2025-03-14",
    "ugadi": "2025-03-30",
    "ram-navami": "2025-04-06",
    "hanuman-jayanti": "2025-04-12",
    "akshaya-tritiya": "2025-04-30",
    "buddha-purnima": "2025-05-12",
    "rath-yatra": "2025-06-27",
    "guru-purnima": "2025-07-10",
    "raksha-bandhan": "2025-08-09",
    "janmashtami": "2025-08-16",
    "ganesh-chaturthi": "2025-08-27",
    "sharad-navratri": "2025-09-22",
    "dussehra": "2025-10-02",
    "karwa-chauth": "2025-10-10",
    "dhanteras": "2025-10-18",
    "diwali": "2025-10-20",
    "govardhan-puja": "2025-10-22",
    "bhai-dooj": "2025-10-23",
    "chhath-puja": "2025-10-27",
    "kartik-purnima": "2025-11-05",
    "gita-jayanti": "2025-12-01",
}
KNOWN_2026 = {
    "maha-shivratri": "2026-02-15",
    "ugadi": "2026-03-19",
    "raksha-bandhan": "2026-08-28",
    "janmashtami": "2026-09-04",
    "ganesh-chaturthi": "2026-09-14",
    "sharad-navratri": "2026-10-11",
    "dussehra": "2026-10-20",
    "diwali": "2026-11-08",
}


HYDERABAD = Location(17.385, 78.4867, "Asia/Kolkata")
# Telugu festivals for Hyderabad, 2025 (Telugu calendars and the Telangana holiday list).
KNOWN_TELUGU_2025 = {
    "bhogi": "2025-01-13",
    "kanuma": "2025-01-15",
    "ratha-saptami": "2025-02-04",
    "varalakshmi-vratam": "2025-08-08",
    "engili-pula-bathukamma": "2025-09-21",
    "saddula-bathukamma": "2025-09-30",
    "atla-taddi": "2025-10-09",
    "naga-chaturthi": "2025-10-25",
}


def test_telugu_festivals_match_published_dates():
    computed = {f["slug"]: f["date"] for f in festivals.compute_festivals(2025, HYDERABAD)}
    assert {s: computed.get(s) for s in KNOWN_TELUGU_2025} == KNOWN_TELUGU_2025


@pytest.mark.parametrize(("year", "known"), [(2025, KNOWN_2025), (2026, KNOWN_2026)])
def test_major_festivals_match_published_dates(year, known):
    computed = {f["slug"]: f["date"] for f in festivals.compute_festivals(year, DELHI)}
    mismatches = {slug: (computed.get(slug), want) for slug, want in known.items() if computed.get(slug) != want}
    assert not mismatches


def test_adhika_masa_2026_detected():
    months = panchang.lunar_months(2026)
    adhika = [m for m in months if m["adhika"]]
    assert [m["name"] for m in adhika] == ["Jyeshtha"]
    assert adhika[0]["start"].date() == date(2026, 5, 16)


def test_daily_panchang_structure_and_values():
    p = panchang.daily_panchang(DELHI, date(2025, 10, 20))  # Diwali
    assert p["vara"] == "Somavara"
    assert p["lunar_month"]["name"] == "Ashwin"
    # Chaturdashi at sunrise, Amavasya begins in the afternoon.
    assert [t["name"] for t in p["tithi"]][:2] == ["Chaturdashi", "Amavasya"]
    assert p["sunrise"].startswith("2025-10-20T06:2")
    assert p["sunset"].startswith("2025-10-20T17:4")
    assert p["rahu_kaal"]["starts"] < p["rahu_kaal"]["ends"]
    assert p["vikram_samvat"] == 2082


def test_purnima_full_moon_tithi():
    p = panchang.daily_panchang(DELHI, date(2025, 7, 10))  # Guru Purnima
    assert p["tithi"][0]["name"] == "Purnima"
    assert p["tithi"][0]["paksha"] == "Shukla"


def test_recurring_ekadashis_about_24_per_year():
    items = [i for i in festivals.compute_recurring(2025, DELHI) if i["kind"] == "ekadashi"]
    assert 23 <= len(items) <= 26


def test_month_calendar_has_every_day():
    days = panchang.month_sunrise_tithis(DELHI, date(2026, 2, 1), 28)
    assert len(days) == 28
    assert all(1 <= d["tithi_index"] <= 30 for d in days)
    # 1 Feb 2026 is Magha Purnima; Phalguna (amanta) begins after the 17 Feb new moon.
    assert days[0]["lunar_month"] == 10 and days[0]["tithi_index"] == 15
    assert days[-1]["lunar_month"] == 11
    assert not any(d["adhika"] for d in days)
    assert all(d["sunset"] > d["sunrise"] for d in days)


def test_telugu_timings_match_drik_panchang_hyderabad():
    # Drik Panchang, Hyderabad, 3 Nov 2026: Varjyam 15:36-17:11, Amrit Kalam 01:04-02:39 (4 Nov),
    # Durmuhurtham 08:33-09:19, Parabhava samvatsara (Shaka 1948).
    p = panchang.daily_panchang(Location(17.385, 78.4867, "Asia/Kolkata"), date(2026, 11, 3))

    def hm(iso: str) -> int:
        return int(iso[11:13]) * 60 + int(iso[14:16])

    def near(span: dict, start: str, end: str) -> bool:
        return abs(hm(span["starts"]) - hm(start)) <= 2 and abs(hm(span["ends"]) - hm(end)) <= 2

    assert near(p["varjyam"][0], "2026-11-03T15:36", "2026-11-03T17:11")
    assert near(p["amrit_kalam"][0], "2026-11-04T01:04", "2026-11-04T02:39")
    assert near(p["durmuhurtham"][0], "2026-11-03T08:33", "2026-11-03T09:19")
    assert len(p["durmuhurtham"]) == 2  # Tuesday also has a night Durmuhurtham
    assert p["samvatsara"]["name"] == "Parabhava" and p["shaka_samvat"] == 1948


def test_moonrise_and_moonset_hyderabad():
    # Drik Panchang, Hyderabad, 3 Nov 2026: moonset 13:43, moonrise 01:50 on 4 Nov (the day runs to next sunrise).
    p = panchang.daily_panchang(Location(17.385, 78.4867, "Asia/Kolkata"), date(2026, 11, 3))

    def hm(iso: str) -> int:
        return int(iso[11:13]) * 60 + int(iso[14:16])

    assert p["moonset"].startswith("2026-11-03") and abs(hm(p["moonset"]) - hm("2026-11-03T13:43")) <= 6
    assert p["moonrise"].startswith("2026-11-04") and abs(hm(p["moonrise"]) - hm("2026-11-04T01:50")) <= 6
