"""Planetary transits (gochara) behind the weekly, monthly and yearly Rashi phalalu.

The readings themselves are written on the phone in every app language (app/lib/core/gochara.dart);
the server only supplies the sky: the Moon's sidereal sign each day, and the days the Sun, Jupiter and
Saturn change sign or turn retrograde. Signs use the Lahiri ayanamsa, like the rest of the Panchang.
Days are Indian (Asia/Kolkata) calendar days, as for the daily Rashifal.
"""

from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import numpy as np
from skyfield.framelib import ecliptic_frame
from skyfield.searchlib import find_discrete

from app.services import panchang

IST = ZoneInfo("Asia/Kolkata")
PLANETS = {"sun": "sun", "jupiter": "jupiter barycenter", "saturn": "saturn barycenter"}


def _lon(t, body: str):
    _, eph = panchang._ephemeris()
    _, lon, _ = eph["earth"].at(t).observe(eph[body]).apparent().frame_latlon(ecliptic_frame)
    return lon.degrees


def _day(t) -> str:
    return t.utc_datetime().astimezone(IST).date().isoformat()


def transits(start: date, end: date) -> dict:
    ts = panchang._ts()
    days = (end - start).days + 1
    noons = [datetime.combine(start + timedelta(days=i), time(12), tzinfo=IST) for i in range(days)]
    moon = (panchang._sidereal(ts.from_datetimes(noons))[1] // 30).astype(int)
    t0 = ts.from_datetime(datetime.combine(start, time(0), tzinfo=IST))
    t1 = ts.from_datetime(datetime.combine(end + timedelta(days=1), time(0), tzinfo=IST))
    planets = {}
    for key, body in PLANETS.items():
        def sign(t, body=body):
            return ((_lon(t, body) - panchang.ayanamsa(t)) % 360.0 // 30).astype(int)

        sign.step_days = 1.0
        times, values = find_discrete(t0, t1, sign)
        entry = {"signs": [[start.isoformat(), int(sign(ts.tt_jd(np.array([t0.tt])))[0])],
                           *[[_day(t), int(v)] for t, v in zip(times, values)]]}
        if key != "sun":
            def retro(t, body=body):
                speed = (_lon(ts.tt_jd(t.tt + 0.5), body) - _lon(ts.tt_jd(t.tt - 0.5), body) + 180) % 360 - 180
                return (speed < 0).astype(int)

            retro.step_days = 2.0
            rt, rv = find_discrete(ts.tt_jd(t0.tt - 200), t1, retro)
            spans, begin = [], None
            if int(retro(ts.tt_jd(np.array([t0.tt - 200])))[0]):
                begin = (start - timedelta(days=200)).isoformat()
            for t, v in zip(rt, rv):
                if v:
                    begin = _day(t)
                elif begin is not None:
                    spans.append([begin, _day(t)])
                    begin = None
            if begin is not None:
                spans.append([begin, None])
            entry["retro"] = [s for s in spans if s[1] is None or s[1] >= start.isoformat()]
        planets[key] = entry
    return {"from": start.isoformat(), "to": end.isoformat(), "moon": [int(m) for m in moon], "planets": planets}
