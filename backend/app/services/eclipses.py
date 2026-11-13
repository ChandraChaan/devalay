"""Grahanam: solar and lunar eclipses as seen from a place, with Sutak.

Lunar eclipses come from Skyfield's eclipselib (Explanatory Supplement 11.2.3, Danjon's enlargement of
the Earth's shadow). Their contacts (penumbral, partial and total phases) are the instants the Moon's limb
crosses the penumbra and umbra, found with the same geometry. A lunar eclipse is the same instant
everywhere; a place sees the part of it while the Moon is above the horizon.

Solar eclipses are worked out locally: the Sun and Moon are observed from the place (topocentric
apparent positions from DE421), and the eclipse lasts while their discs overlap and the Sun is up.

Sutak (Vedha), as Drik Panchang and Dharmasindhu count it: 9 hours (3 prahar) before a lunar eclipse
begins (the partial phase, sparsha) and 12 hours (4 prahar) before a solar eclipse begins at the place,
until the eclipse ends (moksha). There is no Sutak where the eclipse is not visible, nor for a penumbral
lunar eclipse, which is not observed religiously.
"""

from __future__ import annotations

from datetime import date, timedelta
from functools import lru_cache
from zoneinfo import ZoneInfo

import numpy as np
from skyfield import almanac, eclipselib
from skyfield.api import wgs84
from skyfield.constants import ERAD
from skyfield.functions import angle_between, length_of
from skyfield.searchlib import find_discrete, find_minima

from app.services import panchang
from app.services.panchang import Location

SUN_RADIUS_KM = 696340.0
MOON_RADIUS_KM = 1737.1
LUNAR_SUTAK = timedelta(hours=9)
SOLAR_SUTAK = timedelta(hours=12)
# Moon's or Sun's centre at the horizon, corrected for refraction (as for sunrise).
HORIZON_DEG = -0.5667


def _lunar_geometry(t):
    """Moon-to-shadow-axis angle, Moon radius, penumbra and umbra radii (radians), as eclipselib."""
    _, eph = panchang._ephemeris()
    e = eph["earth"].at(t)
    earth_to_sun = e.observe(eph["sun"]).apparent().position.km
    earth_to_moon = e.observe(eph["moon"]).position.km
    d_moon = length_of(earth_to_moon)
    d_sun = length_of(earth_to_sun)
    pi_m = ERAD / 1e3 / d_moon
    pi_s = ERAD / 1e3 / d_sun
    s_s = SUN_RADIUS_KM / d_sun
    closest = angle_between(earth_to_sun, -earth_to_moon)
    moon_r = np.arcsin(MOON_RADIUS_KM / d_moon)
    pi_1 = 1.01 * pi_m
    return closest, moon_r, pi_1 + pi_s + s_s, pi_1 + pi_s - s_s


def _lunar_phase(t):
    """0 outside the penumbra, 1 penumbral, 2 partial (in the umbra), 3 total."""
    sep, mr, pen, umb = _lunar_geometry(t)
    return (sep < pen + mr).astype(int) + (sep < umb + mr).astype(int) + (sep < umb - mr).astype(int)


def _iso(t, tz: ZoneInfo) -> str:
    return t.utc_datetime().astimezone(tz).isoformat(timespec="minutes")


def _altitude(observer, body: str, t):
    _, eph = panchang._ephemeris()
    alt, _, _ = observer.at(t).observe(eph[body]).apparent().altaz()
    return alt.degrees


def _visible_span(observer, body: str, t0, t1):
    """First and last instant between t0 and t1 with the body above the horizon, or None."""
    ts = panchang._ts()

    def up(t):
        return (_altitude(observer, body, t) > HORIZON_DEG).astype(int)

    up.step_days = 1 / 288
    times, values = find_discrete(t0, t1, up)
    cuts = [t0.tt, *[float(t.tt) for t in times], t1.tt]
    states = [int(up(ts.tt_jd(np.array([t0.tt])))[0]), *[int(v) for v in values]]
    spans = [(cuts[i], cuts[i + 1]) for i, s in enumerate(states) if s]
    if not spans:
        return None
    return ts.tt_jd(spans[0][0]), ts.tt_jd(spans[-1][1])


@lru_cache(maxsize=8)
def _lunar_events(start: date, end: date) -> list[dict]:
    ts = panchang._ts()
    _, eph = panchang._ephemeris()
    times, codes, details = eclipselib.lunar_eclipses(ts.utc(start.year, start.month, start.day),
                                                      ts.utc(end.year, end.month, end.day + 1), eph)
    out = []
    for i, t in enumerate(times):
        _lunar_phase.step_days = 1 / 288
        found, values = find_discrete(ts.tt_jd(t.tt - 0.25), ts.tt_jd(t.tt + 0.25), _lunar_phase)
        contacts: dict[str, object] = {}
        prev = 0
        for ft, v in zip(found, values):
            v = int(v)
            if v > prev:
                contacts[{1: "penumbral_begin", 2: "partial_begin", 3: "total_begin"}[v]] = ft
            else:
                contacts[{0: "penumbral_end", 1: "partial_end", 2: "total_end"}[v]] = ft
            prev = v
        out.append({
            "kind": "lunar",
            "type": ["penumbral", "partial", "total"][int(codes[i])],
            "max": t,
            "contacts": contacts,
            "magnitude": round(float(details["umbral_magnitude"][i]), 3),
            "penumbral_magnitude": round(float(details["penumbral_magnitude"][i]), 3),
        })
    return out


def _solar_geometry(observer, t):
    """Topocentric Sun-Moon separation and the two apparent radii (degrees)."""
    _, eph = panchang._ephemeris()
    o = observer.at(t)
    sun = o.observe(eph["sun"]).apparent()
    moon = o.observe(eph["moon"]).apparent()
    sep = sun.separation_from(moon).degrees
    rs = np.degrees(np.arcsin(SUN_RADIUS_KM / sun.distance().km))
    rm = np.degrees(np.arcsin(MOON_RADIUS_KM / moon.distance().km))
    return sep, rs, rm


@lru_cache(maxsize=4)
def _new_moons_near_node(start: date, end: date) -> list:
    """New moons close enough to a lunar node for a solar eclipse somewhere on Earth."""
    ts = panchang._ts()
    _, eph = panchang._ephemeris()
    times, phases = almanac.find_discrete(ts.utc(start.year, start.month, start.day),
                                          ts.utc(end.year, end.month, end.day + 1), almanac.moon_phases(eph))
    out = []
    for t, p in zip(times, phases):
        if p != 0:
            continue
        e = eph["earth"].at(t)
        lat, _, _ = e.observe(eph["moon"]).apparent().ecliptic_latlon()
        if abs(lat.degrees) < 1.6:  # the solar ecliptic limit is about 1.58 degrees
            out.append(t)
    return out


def _global_solar_type(t_new_moon) -> str | None:
    """Total, annular or partial, from the shadow axis's closest approach to the Earth's centre."""
    ts = panchang._ts()
    _, eph = panchang._ephemeris()

    def geometry(t):
        e = eph["earth"].at(t)
        sun = e.observe(eph["sun"]).apparent().position.km
        moon = e.observe(eph["moon"]).apparent().position.km
        axis = (moon - sun) / length_of(moon - sun)
        # Point of the axis nearest the Earth's centre, and its distance.
        along = -np.einsum("i...,i...->...", moon, axis)
        nearest = moon + axis * along
        return length_of(nearest), along, length_of(moon - sun)

    def miss(t):
        return geometry(t)[0]

    miss.step_days = 0.02
    tt, _ = find_minima(ts.tt_jd(t_new_moon.tt - 0.3), ts.tt_jd(t_new_moon.tt + 0.3), miss)
    if not len(tt):
        return None
    d, along, sun_moon = (float(x[0]) for x in geometry(tt[:1]))
    earth_r = ERAD / 1e3
    penumbra = MOON_RADIUS_KM + (SUN_RADIUS_KM + MOON_RADIUS_KM) * along / sun_moon
    if d > earth_r + penumbra:
        return None
    if d > earth_r:
        return "partial"
    # Umbra radius where the axis meets the Earth's surface (negative = antumbra, an annular eclipse).
    surface = along - np.sqrt(earth_r ** 2 - d ** 2)
    umbra = MOON_RADIUS_KM - (SUN_RADIUS_KM - MOON_RADIUS_KM) * surface / sun_moon
    return "total" if umbra > 0 else "annular"


def _solar_local(loc: Location, t_new_moon) -> dict | None:
    ts = panchang._ts()
    _, eph = panchang._ephemeris()
    observer = eph["earth"] + wgs84.latlon(loc.lat, loc.lon)

    def phase(t):
        sep, rs, rm = _solar_geometry(observer, t)
        return (sep < rs + rm).astype(int) + (sep < np.abs(rs - rm)).astype(int)

    phase.step_days = 1 / 720
    t0, t1 = ts.tt_jd(t_new_moon.tt - 0.25), ts.tt_jd(t_new_moon.tt + 0.25)
    found, values = find_discrete(t0, t1, phase)
    if not len(found):
        return None
    begin, end = found[0], found[-1]
    central = [f for f, v in zip(found, values) if int(v) == 2]
    central_end = [f for f, v in zip(found, values) if int(v) == 1 and central and f.tt > central[0].tt]

    def sep(t):
        return _solar_geometry(observer, t)[0]

    sep.step_days = 1 / 720
    tm, _ = find_minima(begin, end, sep)
    t_max = tm[0] if len(tm) else begin
    s, rs, rm = (float(x) for x in _solar_geometry(observer, t_max))
    visible = _visible_span(observer, "sun", begin, end)
    if visible is None:
        return None
    local_type = ("total" if rm > rs else "annular") if central else "partial"
    return {
        "begin": begin, "end": end, "max": t_max,
        "central_begin": central[0] if central else None,
        "central_end": central_end[0] if central_end else None,
        "visible": visible, "type": local_type,
        "magnitude": round((rs + rm - s) / (2 * rs), 3),
        "sun_altitude_at_max": round(float(_altitude(observer, "sun", t_max)), 1),
    }


def eclipses(loc: Location, start: date, end: date) -> list[dict]:
    """Solar and lunar eclipses between two dates, with local times and Sutak for `loc`.

    Every eclipse on Earth is listed; `visible` says whether it can be seen from the place, and only
    visible ones carry Sutak. Times are ISO strings in the place's time zone.
    """
    tz = ZoneInfo(loc.tz)
    _, eph = panchang._ephemeris()
    observer = eph["earth"] + wgs84.latlon(loc.lat, loc.lon)
    out = []
    for ev in _lunar_events(start, end):
        c = ev["contacts"]
        # The religiously observed eclipse is the umbral one; a penumbral eclipse is listed for completeness.
        first = c["partial_begin"] if "partial_begin" in c else c.get("penumbral_begin")
        last = c["partial_end"] if "partial_end" in c else c.get("penumbral_end")
        visible = _visible_span(observer, "moon", first, last) if first is not None and last is not None else None
        sutak = None
        if visible is not None and ev["type"] != "penumbral":
            sutak = {"starts": (first.utc_datetime() - LUNAR_SUTAK).astimezone(tz).isoformat(timespec="minutes"),
                     "ends": _iso(last, tz)}
        out.append({
            "kind": "lunar",
            "type": ev["type"],
            "date": ev["max"].utc_datetime().astimezone(tz).date().isoformat(),
            "max": _iso(ev["max"], tz),
            "contacts": {k: _iso(v, tz) for k, v in c.items()},
            "begins": _iso(first, tz),
            "ends": _iso(last, tz),
            "magnitude": ev["magnitude"] if ev["type"] != "penumbral" else ev["penumbral_magnitude"],
            "visible": visible is not None,
            "visible_from": _iso(visible[0], tz) if visible else None,
            "visible_to": _iso(visible[1], tz) if visible else None,
            "sutak": sutak,
        })
    for t in _new_moons_near_node(start, end):
        global_type = _global_solar_type(t)
        if global_type is None:
            continue
        local = _solar_local(loc, t)
        item = {
            "kind": "solar",
            "type": global_type,
            "date": t.utc_datetime().astimezone(tz).date().isoformat(),
            "visible": local is not None,
        }
        if local:
            item.update({
                "date": local["max"].utc_datetime().astimezone(tz).date().isoformat(),
                "local_type": local["type"],
                "begins": _iso(local["begin"], tz),
                "max": _iso(local["max"], tz),
                "ends": _iso(local["end"], tz),
                "visible_from": _iso(local["visible"][0], tz),
                "visible_to": _iso(local["visible"][1], tz),
                "magnitude": local["magnitude"],
                "sutak": {"starts": (local["begin"].utc_datetime() - SOLAR_SUTAK).astimezone(tz).isoformat(
                    timespec="minutes"), "ends": _iso(local["end"], tz)},
            })
        else:
            item["sutak"] = None
        out.append(item)
    out.sort(key=lambda e: e["date"])
    return out
