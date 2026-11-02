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
