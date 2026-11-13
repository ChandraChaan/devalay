"""Shubha Muhurtham: auspicious dates, with a good time window on each, for ceremonies.

This is Panchang Shuddhi, the first step of muhurta election: a day qualifies when, for part of the
Panchang day (sunrise to next sunrise), the nakshatra, tithi, weekday, yoga, karana, lunar month and
solar month all suit the ceremony, and nothing general rules the day out. The window printed for a day
is that part, less Rahu Kalam, and the best lagna inside it is given as well. Personal checks (the
couple's Tarabalam and Chandrabalam, Lagna and Navamsha Shuddhi) are left to the family priest.

General rules, applied to every ceremony that observes them:
- No Adhika (leap) lunar month (Muhurta Chintamani, Shubhashubha Prakarana; Dharmasindhu).
- No Guru or Shukra moudhyami (combustion): Jupiter within 11 degrees of the Sun, Venus within
  10 degrees, 8 when retrograde (Surya Siddhanta 9.6-9). Longitudes are from JPL DE421 via Skyfield.
  Like Drik Panchang's muhurat lists, the three days before the planet sets (vriddhatva) and after it
  rises again (shishutva, bala) are also avoided.
- Rahu Kalam is cut out of every window.

Per-ceremony tables follow Drik Panchang's Panchang Shuddhi pages, which summarise Muhurta Chintamani:
- Vivaha: https://www.drikpanchang.com/shubh-dates/info/choosing-auspicious-marriage-date.html,
  /panchang/nakshatra/auspicious-marriage-nakshatra.html and /panchang/yoga/prohibited-marriage-yoga.html
  (Sun in Mesha, Vrishabha, Mithuna, Vrischika, Makara or Kumbha; not in Chaturmas; 11 nakshatras;
  9 yogas and 4 karanas prohibited; Mithuna, Kanya and Tula are the best lagnas).
- Griha Pravesham: /shubh-dates/griha-pravesh-dates-with-muhurat.html (Nakshatra, Weekday, Tithi and
  Lunar month Shuddhi; the fixed and gentle nakshatras; Magha, Phalguna, Vaishakha and Jyeshtha).
- Vehicle purchase: /shubh-dates/vehicle-buying-auspicious-dates-with-muhurat.html (movable, gentle
  and short nakshatras; no Pitru Paksha; windows starting after 9 pm are dropped; movable and dual
  lagnas suit driving).

The windows are a starting point, not a substitute for a priest who knows the family's horoscopes.
"""

from __future__ import annotations

from bisect import bisect_right
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta
from functools import lru_cache
from zoneinfo import ZoneInfo

import numpy as np
from skyfield.framelib import ecliptic_frame
from skyfield.searchlib import find_discrete

from app.services import panchang
from app.services.panchang import Location

# Nakshatra indexes, 0 = Ashwini ... 26 = Revati.
ASHWINI, BHARANI, KRITTIKA, ROHINI, MRIGASHIRA, ARDRA, PUNARVASU, PUSHYA, ASHLESHA = range(9)
MAGHA, P_PHALGUNI, U_PHALGUNI, HASTA, CHITRA, SWATI, VISHAKHA, ANURADHA, JYESHTHA = range(9, 18)
MULA, P_ASHADHA, U_ASHADHA, SHRAVANA, DHANISHTA, SHATABHISHA, P_BHADRA, U_BHADRA, REVATI = range(18, 27)
MOVABLE = {PUNARVASU, SWATI, SHRAVANA, DHANISHTA, SHATABHISHA}
GENTLE = {MRIGASHIRA, CHITRA, ANURADHA, REVATI}

# Weekdays as Python numbers (Mon=0 ... Sun=6).
MON, TUE, WED, THU, FRI, SAT, SUN = range(7)
# Signs, 0 = Mesha ... 11 = Meena.
MESHA, VRISHABHA, MITHUNA, KARKA, SIMHA, KANYA, TULA, VRISCHIKA, DHANU, MAKARA, KUMBHA, MEENA = range(12)
MOVABLE_SIGNS = {MESHA, KARKA, TULA, MAKARA}
DUAL_SIGNS = {MITHUNA, KANYA, DHANU, MEENA}
FIXED_SIGNS = {VRISHABHA, SIMHA, VRISCHIKA, KUMBHA}
# Amanta months, 0 = Chaitra.
CHAITRA, VAISHAKHA, JYESHTHA_M, ASHADHA_M, SHRAVANA_M, BHADRAPADA, ASHWIN, KARTIKA, MARGASHIRSHA, PAUSHA, \
    MAGHA_M, PHALGUNA = range(12)


def _tithis(shukla: tuple[int, ...], krishna: tuple[int, ...] | None = None) -> frozenset[int]:
    """Tithi numbers per paksha (1-15; 15 is Purnima or Amavasya) as indexes 0-29."""
    return frozenset({n - 1 for n in shukla} | {n + 14 for n in (shukla if krishna is None else krishna)})


@dataclass(frozen=True)
class Rule:
    key: str
    nakshatras: frozenset[int]
    tithis: frozenset[int] | None = None
    weekdays: frozenset[int] | None = None
    lunar_months: frozenset[int] | None = None
    sun_signs: frozenset[int] | None = None
    bad_yogas: frozenset[int] = frozenset()
    bad_karanas: frozenset[str] = frozenset()
    bad_padas: frozenset[int] = frozenset()  # 0..107, nakshatra * 4 + pada - 1
    asta: bool = True
    chaturmas: bool = False
    pitru_paksha: bool = False
    latest_start: time | None = None  # windows starting later than this local time are dropped
    min_minutes: int = 5
    lagnas: frozenset[int] = field(default_factory=frozenset)


VIVAHA = Rule(
    "vivaha",
    nakshatras=frozenset({ROHINI, MRIGASHIRA, MAGHA, U_PHALGUNI, HASTA, SWATI, ANURADHA, MULA, U_ASHADHA, U_BHADRA,
                          REVATI}),
    # Muhurta Chintamani's six solar months; Drik Panchang's lists also open Tula once Chaturmas ends.
    sun_signs=frozenset({MESHA, VRISHABHA, MITHUNA, TULA, VRISCHIKA, MAKARA, KUMBHA}),
    # Vishkambha, Atiganda, Shula, Ganda, Vyaghata, Vajra, Vyatipata, Parigha, Vaidhriti.
    bad_yogas=frozenset({0, 5, 8, 9, 12, 14, 16, 18, 26}),
    bad_karanas=frozenset({"Vishti", "Shakuni", "Chatushpada", "Naga"}),
    # First quarter of Magha and Mula and last quarter of Revati are rejected (Jyotirnibandha).
    bad_padas=frozenset({MAGHA * 4, MULA * 4, REVATI * 4 + 3}),
    chaturmas=True,
    lagnas=frozenset({MITHUNA, KANYA, TULA}),
)
GRIHA_PRAVESHA = Rule(
    "griha_pravesha",
    nakshatras=frozenset({ROHINI, MRIGASHIRA, U_PHALGUNI, CHITRA, ANURADHA, U_ASHADHA, U_BHADRA, REVATI}),
    # Shukla paksha without Pratipada and Dwadashi; Krishna paksha up to Ekadashi, without Rikta tithis.
    tithis=_tithis((2, 3, 5, 7, 10, 11, 13), (1, 2, 3, 5, 7, 10, 11)),
    weekdays=frozenset({MON, WED, THU, FRI, SAT}),
    # Vaishakha, Jyeshtha, Magha and Phalguna are best; Kartika and Margashirsha are middling.
    lunar_months=frozenset({VAISHAKHA, JYESHTHA_M, KARTIKA, MARGASHIRSHA, MAGHA_M, PHALGUNA}),
    lagnas=frozenset(FIXED_SIGNS | DUAL_SIGNS),
)
VEHICLE = Rule(
    "vehicle",
    nakshatras=frozenset(MOVABLE | GENTLE | {ROHINI, PUSHYA, HASTA}),
    tithis=_tithis((3, 5, 6, 8, 10, 11, 13, 15), (1, 3, 5, 6, 8, 10, 11, 13)),
    weekdays=frozenset({SUN, MON, WED, THU, FRI}),
    asta=False,
    pitru_paksha=True,
    # Drik Panchang drops late-night windows; its lists keep ones starting up to about 9:40 pm.
    latest_start=time(22, 0),
    lagnas=frozenset(MOVABLE_SIGNS | DUAL_SIGNS),
)
# Only kinds that could be checked against Drik Panchang's yearly lists for Hyderabad and New Delhi
# (tests/test_muhurtham.py). Namakaranam, Aksharabhyasam and business openings are left out until
# they can be validated the same way.
RULES = {r.key: r for r in (VIVAHA, GRIHA_PRAVESHA, VEHICLE)}

JUPITER_ORB, VENUS_ORB, VENUS_RETRO_ORB = 11.0, 10.0, 8.0
BALA_VRIDDHA_DAYS = 3


class Timeline:
    """A quantity that changes in steps: its value from each transition instant (TT Julian dates)."""

    def __init__(self, t0, t1, fn, step_days: float):
        fn.step_days = step_days
        first = int(fn(panchang._ts().tt_jd(np.array([t0.tt])))[0])
        times, values = find_discrete(t0, t1, fn)
        self.jd = [t0.tt, *[float(t.tt) for t in times]]
        self.values = [first, *[int(v) for v in values]]

    def at(self, jd: float) -> int:
        return self.values[max(bisect_right(self.jd, jd) - 1, 0)]

    def between(self, a: float, b: float) -> list[float]:
        i, j = bisect_right(self.jd, a), bisect_right(self.jd, b)
        return self.jd[i:j]


def _elong(t):
    return panchang._elongation(t)


def _planet_lon(t, body: str):
    _, eph = panchang._ephemeris()
    _, lon, _ = eph["earth"].at(t).observe(eph[body]).apparent().frame_latlon(ecliptic_frame)
    return lon.degrees


@dataclass
class Sky:
    """Location-independent timelines for a span of dates."""

    start: date
    end: date
    tithi: Timeline
    karana: Timeline
    pada: Timeline
    yoga: Timeline
    sun_sign: Timeline
    months: list[dict]
    asta: dict[str, list[tuple[float, float]]]


def _asta_spans(t0, t1, body: str, orb: float, retro_orb: float | None) -> list[tuple[float, float]]:
    ts = panchang._ts()

    def combust(t):
        d = np.abs((_planet_lon(t, body) - panchang._longitudes(t)[0] + 180.0) % 360.0 - 180.0)
        if retro_orb is None:
            return (d < orb).astype(int)
        speed = (_planet_lon(ts.tt_jd(t.tt + 0.5), body) - _planet_lon(ts.tt_jd(t.tt - 0.5), body) + 180) % 360 - 180
        return (d < np.where(speed < 0, retro_orb, orb)).astype(int)

    tl = Timeline(t0, t1, combust, 1.0)
    spans, begin = [], None
    for jd, v in zip(tl.jd, tl.values):
        if v and begin is None:
            begin = jd
        elif not v and begin is not None:
            spans.append((begin, jd))
            begin = None
    if begin is not None:
        spans.append((begin, t1.tt))
    return spans


@lru_cache(maxsize=4)
def sky(start: date, end: date) -> Sky:
    ts = panchang._ts()
    t0, t1 = ts.utc(start.year, start.month, start.day - 3), ts.utc(end.year, end.month, end.day + 3)

    def tithi(t):
        return (_elong(t) // 12.0).astype(int)

    def karana(t):
        return (_elong(t) // 6.0).astype(int)

    def pada(t):
        return (panchang._sidereal(t)[1] // (360.0 / 108)).astype(int)

    def yoga(t):
        s, m = panchang._sidereal(t)
        return (((s + m) % 360.0) // (360.0 / 27)).astype(int)

    def sun_sign(t):
        return (panchang._sidereal(t)[0] // 30.0).astype(int)

    months = [m for y in range(start.year - 1, end.year + 2) for m in panchang.lunar_months(y)]
    months = list({m["start"]: m for m in months}.values())
    months.sort(key=lambda m: m["start"])
    wide0, wide1 = ts.utc(start.year, start.month, start.day - 60), ts.utc(end.year, end.month, end.day + 60)
    asta = {
        "guru": _asta_spans(wide0, wide1, "jupiter barycenter", JUPITER_ORB, None),
        "shukra": _asta_spans(wide0, wide1, "venus", VENUS_ORB, VENUS_RETRO_ORB),
    }
    return Sky(start, end, Timeline(t0, t1, tithi, 0.2), Timeline(t0, t1, karana, 0.1), Timeline(t0, t1, pada, 0.05),
               Timeline(t0, t1, yoga, 0.2), Timeline(t0, t1, sun_sign, 5.0), months,
               asta)


def _jd(moment: datetime) -> float:
    return float(panchang._ts().from_datetime(moment).tt)


def _local(jd: float, tz: ZoneInfo) -> datetime:
    return panchang._ts().tt_jd(jd).utc_datetime().astimezone(tz)


def asta_reason(sk: Sky, day: date, tz: ZoneInfo) -> str | None:
    """Why Guru or Shukra rules the day out ('guru_asta', 'shukra_bala', ...), or None."""
    span = timedelta(days=BALA_VRIDDHA_DAYS)
    for planet in ("guru", "shukra"):
        for ja, jb in sk.asta[planet]:
            a, b = _local(ja, tz).date(), _local(jb, tz).date()
            if a <= day <= b:
                return f"{planet}_asta"
            if a - span <= day < a:
                return f"{planet}_vriddha"
            if b < day <= b + span:
                return f"{planet}_bala"
    return None


def _month_at(sk: Sky, jd: float) -> dict | None:
    moment = _local(jd, ZoneInfo("UTC"))
    for m in sk.months:
        if m["start"] <= moment < m["end"]:
            return m
    return None


def _window_bounds(sk: Sky, month: dict, tithi_index: int) -> float:
    """Instant a tithi begins inside a lunar month."""
    a, b = _jd(month["start"]), _jd(month["end"])
    for jd in sk.tithi.between(a, b):
        if sk.tithi.at(jd) == tithi_index:
            return jd
    return a


@lru_cache(maxsize=4)
def _special_periods(start: date, end: date) -> dict[str, list[tuple[float, float]]]:
    """Chaturmas (Devshayani to Prabodhini Ekadashi) and Pitru Paksha (Bhadrapada Krishna paksha)."""
    sk = sky(start, end)
    out: dict[str, list[tuple[float, float]]] = {"chaturmas": [], "pitru_paksha": []}
    for m in sk.months:
        if m["adhika"]:
            continue
        if m["index"] == ASHADHA_M:
            begin = _window_bounds(sk, m, 10)
            later = [k for k in sk.months if k["index"] == KARTIKA and not k["adhika"] and k["start"] > m["start"]]
            kartika = later[0] if later else None
            if kartika:
                out["chaturmas"].append((begin, _window_bounds(sk, kartika, 10)))
        if m["index"] == BHADRAPADA:
            out["pitru_paksha"].append((_window_bounds(sk, m, 15), _jd(m["end"])))
    return out


def _ascendant(jd: np.ndarray | float, loc: Location):
    """Sidereal (Lahiri) ascendant longitude in degrees."""
    t = panchang._ts().tt_jd(jd)
    ramc = np.radians((t.gast * 15.0 + loc.lon) % 360.0)
    eps = np.radians(23.4392911 - 0.0130042 * (t.tt - 2451545.0) / 36525.0)
    phi = np.radians(loc.lat)
    asc = np.degrees(np.arctan2(np.cos(ramc), -(np.sin(ramc) * np.cos(eps) + np.tan(phi) * np.sin(eps))))
    return (asc - panchang.ayanamsa(t)) % 360.0


def lagna_segments(loc: Location, a: float, b: float) -> list[tuple[float, float, int]]:
    """Lagna (sign) in force between two instants, as (start, end, sign) in TT Julian dates."""
    ts = panchang._ts()

    def sign(t):
        return (_ascendant(t.tt, loc) // 30.0).astype(int)

    sign.step_days = 0.02
    first = int(sign(ts.tt_jd(np.array([a])))[0])
    times, values = find_discrete(ts.tt_jd(a), ts.tt_jd(b), sign)
    cuts = [a, *[float(t.tt) for t in times], b]
    vals = [first, *[int(v) for v in values]]
    return [(cuts[i], cuts[i + 1], vals[i]) for i in range(len(vals))]


def _calendar_ok(rule: Rule, sk: Sky, special: dict, jd: float) -> bool:
    """Month-level conditions. A day that touches a prohibited month is dropped whole, as Drik Panchang does."""
    if rule.sun_signs is not None and sk.sun_sign.at(jd) not in rule.sun_signs:
        return False
    month = _month_at(sk, jd)
    if month is None or month["adhika"]:
        return False
    if rule.lunar_months is not None and month["index"] not in rule.lunar_months:
        return False
    return not any(getattr(rule, key) and any(a <= jd < b for a, b in special[key])
                   for key in ("chaturmas", "pitru_paksha"))


def _limbs_ok(rule: Rule, sk: Sky, jd: float, weekday: int) -> bool:
    pada = sk.pada.at(jd)
    if pada // 4 not in rule.nakshatras or pada in rule.bad_padas:
        return False
    if rule.tithis is not None and sk.tithi.at(jd) not in rule.tithis:
        return False
    if rule.weekdays is not None and weekday not in rule.weekdays:
        return False
    if sk.yoga.at(jd) in rule.bad_yogas:
        return False
    return not (rule.bad_karanas and panchang.karana_name(sk.karana.at(jd)) in rule.bad_karanas)


def day_windows(rule: Rule, loc: Location, day: date, sunrise: datetime, next_sunrise: datetime,
                sunset: datetime, sk: Sky, special: dict, cut_rahu: bool = True) -> list[tuple[float, float]]:
    """Good stretches of one Panchang day (TT Julian dates), Rahu Kalam removed."""
    tz = ZoneInfo(loc.tz)
    if rule.asta and asta_reason(sk, day, tz):
        return []
    a, b = _jd(sunrise), _jd(next_sunrise)
    rahu = panchang._segment(sunrise, sunset, panchang.RAHU_KAAL_PART[day.weekday()])
    r0, r1 = _jd(rahu[0]), _jd(rahu[1])
    cuts = {a, b, r0, r1}
    for tl in (sk.tithi, sk.karana, sk.pada, sk.yoga, sk.sun_sign):
        cuts.update(tl.between(a, b))
    for spans in special.values():
        for s, e in spans:
            cuts.update((s, e))
    for m in sk.months:
        cuts.add(_jd(m["start"]))
    points = sorted(c for c in cuts if a <= c <= b)
    if not all(_calendar_ok(rule, sk, special, (s + e) / 2) for s, e in zip(points, points[1:]) if e - s > 1e-6):
        return []
    good: list[list[float]] = []
    for s, e in zip(points, points[1:]):
        if e - s < 1e-6 or (cut_rahu and r0 <= s and e <= r1):
            continue
        if _limbs_ok(rule, sk, (s + e) / 2, day.weekday()):
            if good and abs(good[-1][1] - s) < 1e-6:
                good[-1][1] = e
            else:
                good.append([s, e])
    out = [(s, e) for s, e in good if (e - s) * 1440 >= rule.min_minutes]
    if rule.latest_start is not None:
        limit = _jd(datetime.combine(day, rule.latest_start, tzinfo=tz))
        out = [(s, e) for s, e in out if s <= limit]
    return out


def _minutes(jd: float, day: date, tz: ZoneInfo) -> int:
    """Minutes from local midnight of `day` (past 1440 for times after midnight)."""
    local = _local(jd, tz)
    return round((local - datetime.combine(day, time(0), tzinfo=tz)).total_seconds() / 60)


def muhurtham_dates(kind: str, loc: Location, start: date, end: date, cut_rahu: bool = True) -> list[dict]:
    """Auspicious days for one ceremony between two dates (inclusive).

    Each day: {"d": date, "w": [[start, end], ...], "n": [nakshatra...], "t": [tithi...], "l": [start, end, sign]}
    with times as minutes from local midnight of the day (past 1440 after midnight), nakshatras 0-26,
    tithis 0-29 and the best lagna window (longest one with a recommended lagna) or null.
    """
    rule = RULES[kind]
    tz = ZoneInfo(loc.tz)
    sk = sky(start, end)
    special = _special_periods(start, end)
    days = (end - start).days + 1
    ev = panchang.sun_events(loc, start, days + 1)
    out = []
    for i in range(days):
        day = start + timedelta(days=i)
        windows = day_windows(rule, loc, day, ev[day]["sunrise"], ev[day + timedelta(days=1)]["sunrise"],
                              ev[day]["sunset"], sk, special, cut_rahu)
        if not windows:
            continue
        naks, tithis = [], []
        best = None
        for s, e in windows:
            for jd in (s, *sk.pada.between(s, e)):
                n = sk.pada.at(jd + 1e-7) // 4
                if n not in naks and n in rule.nakshatras:
                    naks.append(n)
            for jd in (s, *sk.tithi.between(s, e)):
                t = sk.tithi.at(jd + 1e-7)
                if t not in tithis:
                    tithis.append(t)
            if rule.lagnas:
                for ls, le, sign in lagna_segments(loc, s, e):
                    if sign in rule.lagnas and (best is None or le - ls > best[1] - best[0]):
                        best = (ls, le, sign)
        out.append({
            "d": day.isoformat(),
            "w": [[_minutes(s, day, tz), _minutes(e, day, tz)] for s, e in windows],
            "n": naks,
            "t": tithis,
            "l": [_minutes(best[0], day, tz), _minutes(best[1], day, tz), best[2]] if best else None,
        })
    return out


def all_dates(loc: Location, start: date, end: date) -> dict:
    return {"from": start.isoformat(), "to": end.isoformat(),
            "kinds": {k: muhurtham_dates(k, loc, start, end) for k in RULES}}
