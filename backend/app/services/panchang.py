"""Astronomical Panchang engine.

Computes the five limbs of the Hindu almanac (tithi, vara, nakshatra, yoga,
karana), sunrise/sunset, inauspicious periods and amanta lunar months from
NASA JPL's DE421 ephemeris through Skyfield. Sidereal longitudes use the
Lahiri (Chitrapaksha) ayanamsa.

All public functions take a location (lat, lon) and an IANA timezone, and
return timezone-aware datetimes in that zone.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from functools import lru_cache
from pathlib import Path
from zoneinfo import ZoneInfo

import numpy as np
from skyfield import almanac
from skyfield.api import Loader, wgs84
from skyfield.framelib import ecliptic_frame
from skyfield.searchlib import find_discrete

from app.config import get_settings

TITHI_NAMES = [
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi",
]
NAKSHATRA_NAMES = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra",
    "Punarvasu", "Pushya", "Ashlesha", "Magha", "Purva Phalguni",
    "Uttara Phalguni", "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha",
    "Jyeshtha", "Mula", "Purva Ashadha", "Uttara Ashadha", "Shravana",
    "Dhanishta", "Shatabhisha", "Purva Bhadrapada", "Uttara Bhadrapada",
    "Revati",
]
YOGA_NAMES = [
    "Vishkambha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda",
    "Sukarma", "Dhriti", "Shula", "Ganda", "Vriddhi", "Dhruva", "Vyaghata",
    "Harshana", "Vajra", "Siddhi", "Vyatipata", "Variyana", "Parigha",
    "Shiva", "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma", "Indra",
    "Vaidhriti",
]
MOVABLE_KARANAS = ["Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti"]
RASHI_NAMES = [
    "Mesha", "Vrishabha", "Mithuna", "Karka", "Simha", "Kanya",
    "Tula", "Vrishchika", "Dhanu", "Makara", "Kumbha", "Meena",
]
# Amanta month names, indexed so that 0 = Chaitra.
MONTH_NAMES = [
    "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
    "Ashwin", "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna",
]
VARA_NAMES = ["Somavara", "Mangalavara", "Budhavara", "Guruvara", "Shukravara", "Shanivara", "Ravivara"]
# 1-based eighth of daytime for each weekday (Python weekday: Mon=0 ... Sun=6).
RAHU_KAAL_PART = [2, 7, 5, 6, 4, 3, 8]
YAMAGANDA_PART = [4, 3, 2, 1, 7, 6, 5]
GULIKA_PART = [6, 5, 4, 3, 2, 1, 7]

LAHIRI_J2000 = 23.85709  # degrees at J2000.0
PRECESSION_PER_YEAR = 50.2788 / 3600.0  # degrees per Julian year


@dataclass(frozen=True)
class Location:
    lat: float
    lon: float
    tz: str = "Asia/Kolkata"

    def rounded(self) -> Location:
        # Coarse rounding keeps caches effective and avoids storing precise user locations.
        return Location(round(self.lat, 1), round(self.lon, 1), self.tz)


@lru_cache(maxsize=1)
def _ephemeris():
    settings = get_settings()
    directory = Path(settings.ephemeris_dir)
    directory.mkdir(parents=True, exist_ok=True)
    loader = Loader(str(directory), verbose=False)
    ts = loader.timescale(builtin=True)
    eph = loader("de421.bsp")
    return ts, eph


def _ts():
    return _ephemeris()[0]


def ayanamsa(t) -> np.ndarray | float:
    years = (t.tt - 2451545.0) / 365.25
    return LAHIRI_J2000 + PRECESSION_PER_YEAR * years


def _longitudes(t):
    """Tropical apparent ecliptic longitudes (of date) of the Sun and Moon, degrees."""
    _, eph = _ephemeris()
    earth = eph["earth"].at(t)
    _, sun_lon, _ = earth.observe(eph["sun"]).apparent().frame_latlon(ecliptic_frame)
    _, moon_lon, _ = earth.observe(eph["moon"]).apparent().frame_latlon(ecliptic_frame)
    return sun_lon.degrees, moon_lon.degrees


def _elongation(t):
    s, m = _longitudes(t)
    return (m - s) % 360.0


def _sidereal(t):
    s, m = _longitudes(t)
    a = ayanamsa(t)
    return (s - a) % 360.0, (m - a) % 360.0


def tithi_at(moment: datetime) -> int:
    """Tithi index 0..29 in force at a moment (0 = Shukla Pratipada, 14 = Purnima, 29 = Amavasya)."""
    return int(_elongation(_ts().from_datetime(moment)) // 12.0)


def tithis_at(moments: list[datetime]) -> list[int]:
    return [int(x) for x in (_elongation(_ts().from_datetimes(moments)) // 12.0)]


def tithi_label(idx: int) -> tuple[str, str]:
    paksha = "Shukla" if idx < 15 else "Krishna"
    n = idx % 15
    if n == 14:
        name = "Purnima" if idx < 15 else "Amavasya"
    else:
        name = TITHI_NAMES[n]
    return paksha, name


def karana_name(half_index: int) -> str:
    if half_index == 0:
        return "Kimstughna"
    if half_index >= 57:
        return ["Shakuni", "Chatushpada", "Naga"][half_index - 57]
    return MOVABLE_KARANAS[(half_index - 1) % 7]


def _to_local(t, tz: ZoneInfo) -> datetime:
    return t.utc_datetime().astimezone(tz)


def _utc_bounds(day: date, tz: ZoneInfo):
    start = datetime.combine(day, time(0, 0), tzinfo=tz)
    end = start + timedelta(days=1)
    ts = _ts()
    return ts.from_datetime(start), ts.from_datetime(end)


def _transitions(t0, t1, fn, step_days: float):
    fn.step_days = step_days
    times, values = find_discrete(t0, t1, fn)
    return list(zip(times, values))


def sun_events(loc: Location, start: date, days: int):
    """Sunrise and sunset per local date for `days` days starting at `start`."""
    _, eph = _ephemeris()
    tz = ZoneInfo(loc.tz)
    observer = eph["earth"] + wgs84.latlon(loc.lat, loc.lon)
    t0, _ = _utc_bounds(start, tz)
    _, t1 = _utc_bounds(start + timedelta(days=days - 1), tz)
    rises, rflags = almanac.find_risings(observer, eph["sun"], t0, t1)
    sets, sflags = almanac.find_settings(observer, eph["sun"], t0, t1)
    out: dict[date, dict] = {}
    for t, ok in zip(rises, rflags):
        if ok:
            local = _to_local(t, tz)
            out.setdefault(local.date(), {})["sunrise"] = local
    for t, ok in zip(sets, sflags):
        if ok:
            local = _to_local(t, tz)
            out.setdefault(local.date(), {})["sunset"] = local
    for i in range(days):
        d = start + timedelta(days=i)
        ev = out.setdefault(d, {})
        # Polar day/night fallback: use local 06:00 / 18:00.
        ev.setdefault("sunrise", datetime.combine(d, time(6, 0), tzinfo=tz))
        ev.setdefault("sunset", datetime.combine(d, time(18, 0), tzinfo=tz))
    return out


def _segment(sunrise: datetime, sunset: datetime, part: int, parts: int = 8):
    span = (sunset - sunrise) / parts
    begin = sunrise + span * (part - 1)
    return begin, begin + span


def _limb_timeline(t0, t1, kind: str, tz: ZoneInfo):
    """Each limb value in force between t0 and t1, with its local start/end."""
    def tithi_fn(t):
        return (_elongation(t) // 12.0).astype(int)

    def nak_fn(t):
        return (_sidereal(t)[1] // (360.0 / 27)).astype(int)

    def yoga_fn(t):
        s, m = _sidereal(t)
        return (((s + m) % 360.0) // (360.0 / 27)).astype(int)

    def karana_fn(t):
        return (_elongation(t) // 6.0).astype(int)

    fn, step = {
        "tithi": (tithi_fn, 0.2),
        "nakshatra": (nak_fn, 0.2),
        "yoga": (yoga_fn, 0.2),
        "karana": (karana_fn, 0.1),
    }[kind]
    first = int(fn(_ts().tt_jd(np.array([t0.tt])))[0])
    segments = [[first, None, None]]
    for t, value in _transitions(t0, t1, fn, step):
        segments[-1][2] = _to_local(t, tz)
        segments.append([int(value), _to_local(t, tz), None])
    return segments


def daily_panchang(loc: Location, day: date) -> dict:
    """Full Panchang for a local civil day, measured from sunrise to next sunrise."""
    tz = ZoneInfo(loc.tz)
    ts = _ts()
    ev = sun_events(loc, day, 2)
    sunrise, sunset = ev[day]["sunrise"], ev[day]["sunset"]
    next_sunrise = ev[day + timedelta(days=1)]["sunrise"]
    t_rise = ts.from_datetime(sunrise)
    t_next = ts.from_datetime(next_sunrise)

    def describe(kind: str):
        items = []
        for value, begin, end in _limb_timeline(t_rise, t_next, kind, tz):
            if kind == "tithi":
                paksha, name = tithi_label(value)
                label = {"index": value + 1, "name": name, "paksha": paksha}
            elif kind == "nakshatra":
                label = {"index": value + 1, "name": NAKSHATRA_NAMES[value]}
            elif kind == "yoga":
                label = {"index": value + 1, "name": YOGA_NAMES[value]}
            else:
                label = {"index": value + 1, "name": karana_name(value)}
            label["starts"] = begin.isoformat() if begin else None
            label["ends"] = end.isoformat() if end else None
            items.append(label)
        return items

    sun_sid, moon_sid = _sidereal(t_rise)
    month = lunar_month_at(sunrise)
    wd = day.weekday()
    rahu = _segment(sunrise, sunset, RAHU_KAAL_PART[wd])
    yama = _segment(sunrise, sunset, YAMAGANDA_PART[wd])
    gulika = _segment(sunrise, sunset, GULIKA_PART[wd])
    muhurta = (sunset - sunrise) / 15
    abhijit = (sunrise + muhurta * 7, sunrise + muhurta * 8)
    brahma = (sunrise - timedelta(minutes=96), sunrise - timedelta(minutes=48))

    def span(pair):
        return {"starts": pair[0].isoformat(), "ends": pair[1].isoformat()}

    return {
        "date": day.isoformat(),
        "location": {"lat": loc.lat, "lon": loc.lon, "tz": loc.tz},
        "vara": VARA_NAMES[wd],
        "sunrise": sunrise.isoformat(),
        "sunset": sunset.isoformat(),
        "tithi": describe("tithi"),
        "nakshatra": describe("nakshatra"),
        "yoga": describe("yoga"),
        "karana": describe("karana"),
        "sun_rashi": RASHI_NAMES[int(sun_sid // 30)],
        "moon_rashi": RASHI_NAMES[int(moon_sid // 30)],
        "lunar_month": month,
        "vikram_samvat": vikram_samvat(day, month["index"]),
        "rahu_kaal": span(rahu),
        "yamaganda": span(yama),
        "gulika_kaal": span(gulika),
        "abhijit_muhurta": span(abhijit),
        "brahma_muhurta": span(brahma),
    }


def vikram_samvat(day: date, month_index: int) -> int:
    # The Vikram year increments at Chaitra Shukla Pratipada.
    # Pausha, Magha and Phalguna early in the Gregorian year still belong to the previous year.
    return day.year + 56 if day.month < 6 and month_index >= 9 else day.year + 57


@lru_cache(maxsize=16)
def _new_moons(year: int):
    ts = _ts()
    _, eph = _ephemeris()
    t0 = ts.utc(year - 1, 11, 1)
    t1 = ts.utc(year + 1, 3, 1)
    times, phases = almanac.find_discrete(t0, t1, almanac.moon_phases(eph))
    return [t for t, p in zip(times, phases) if p == 0]


def lunar_months(year: int) -> list[dict]:
    """Amanta lunar months overlapping the Gregorian year (UTC instants)."""
    moons = _new_moons(year)
    months = []
    for start, end in zip(moons, moons[1:]):
        s_start = int(_sidereal(start)[0] // 30)
        s_end = int(_sidereal(end)[0] // 30)
        idx = (s_start + 1) % 12
        months.append({
            "index": idx,
            "name": MONTH_NAMES[idx],
            "adhika": s_start == s_end,
            "start": start.utc_datetime(),
            "end": end.utc_datetime(),
        })
    return months


def lunar_month_at(moment: datetime) -> dict:
    for m in lunar_months(moment.year):
        if m["start"] <= moment < m["end"]:
            return {"index": m["index"], "name": m["name"], "adhika": m["adhika"]}
    raise ValueError("moment outside supported range")


def month_sunrise_tithis(loc: Location, start: date, days: int) -> list[dict]:
    """Compact per-day summary (sunrise tithi, nakshatra) used by calendars."""
    ts = _ts()
    ev = sun_events(loc, start, days)
    rises = [ev[start + timedelta(days=i)]["sunrise"] for i in range(days)]
    t = ts.from_datetimes(rises)
    tithi = (_elongation(t) // 12.0).astype(int)
    nak = (_sidereal(t)[1] // (360.0 / 27)).astype(int)
    out = []
    for i, d in enumerate(rises):
        paksha, name = tithi_label(int(tithi[i]))
        out.append({
            "date": (start + timedelta(days=i)).isoformat(),
            "sunrise": d.isoformat(),
            "tithi_index": int(tithi[i]) + 1,
            "tithi": name,
            "paksha": paksha,
            "nakshatra": NAKSHATRA_NAMES[int(nak[i])],
        })
    return out


def sankranti_times(year: int) -> list[tuple[int, datetime]]:
    """Moments the Sun enters each sidereal sign during the year (UTC)."""
    ts = _ts()

    def sign_fn(t):
        return (_sidereal(t)[0] // 30).astype(int)

    sign_fn.step_days = 5
    times, values = find_discrete(ts.utc(year, 1, 1), ts.utc(year + 1, 1, 1), sign_fn)
    return [(int(v), t.utc_datetime()) for t, v in zip(times, values)]


def moon_rashi_on(day: date, tz: str = "Asia/Kolkata") -> int:
    """Index of the Moon's sidereal sign at local noon (used for daily Rashifal)."""
    ts = _ts()
    noon = datetime.combine(day, time(12, 0), tzinfo=ZoneInfo(tz))
    return int(_sidereal(ts.from_datetime(noon))[1] // 30)


def ensure_ephemeris() -> None:
    """Load (and download on first use) the ephemeris so the first request is fast."""
    _ephemeris()
