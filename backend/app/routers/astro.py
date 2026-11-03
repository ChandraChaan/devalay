"""Panchang, festival calendar and Rashifal endpoints."""

from datetime import date, datetime, timedelta
from functools import lru_cache
from typing import Annotated
from zoneinfo import ZoneInfo, available_timezones

from fastapi import APIRouter, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.config import get_settings
from app.deps import DB
from app.models import FestivalOverride, RashifalEntry
from app.schemas import RASHIS, FestivalOut
from app.services import ai, festivals, panchang, rashifal
from app.services.panchang import Location

router = APIRouter(tags=["astro"])

Lat = Annotated[float | None, Query(ge=-66, le=66)]  # sunrise is undefined near the poles
Lon = Annotated[float | None, Query(ge=-180, le=180)]
Tz = Annotated[str | None, Query(max_length=64)]
MIN_DAY, MAX_DAY = date(1901, 1, 1), date(2049, 12, 31)  # DE421 coverage with margin


@lru_cache(maxsize=1)
def _zones() -> frozenset[str]:
    return frozenset(available_timezones())


def location(lat: float | None, lon: float | None, tz: str | None) -> Location:
    s = get_settings()
    tz = tz or s.default_tz
    if tz not in _zones():
        raise HTTPException(422, "Unknown timezone")
    if (lat is None) != (lon is None):
        raise HTTPException(422, "Provide both lat and lon")
    if lat is None:
        return Location(s.default_lat, s.default_lon, tz)
    return Location(lat, lon, tz).rounded()


def _check_day(day: date) -> None:
    if not MIN_DAY <= day <= MAX_DAY:
        raise HTTPException(422, "Date outside supported range (1901-2049)")


@lru_cache(maxsize=512)
def _cached_daily(loc: Location, day: date) -> dict:
    return panchang.daily_panchang(loc, day)


def today_in(tz: str) -> date:
    return datetime.now(ZoneInfo(tz)).date()


@router.get("/panchang")
def panchang_day(response: Response, day: date | None = None, lat: Lat = None, lon: Lon = None, tz: Tz = None):
    loc = location(lat, lon, tz)
    day = day or today_in(loc.tz)
    _check_day(day)
    response.headers["Cache-Control"] = "public, max-age=3600"
    return _cached_daily(loc, day)


@router.get("/panchang/month")
def panchang_month(response: Response, year: Annotated[int, Query(ge=1901, le=2049)],
                   month: Annotated[int, Query(ge=1, le=12)], lat: Lat = None, lon: Lon = None, tz: Tz = None):
    loc = location(lat, lon, tz)
    start = date(year, month, 1)
    days = ((start.replace(day=28) + timedelta(days=4)).replace(day=1) - start).days
    response.headers["Cache-Control"] = "public, max-age=86400"
    return {"year": year, "month": month, "days": panchang.month_sunrise_tithis(loc, start, days)}


def _apply_overrides(db, year: int, items: list[dict]) -> list[dict]:
    overrides = db.execute(select(FestivalOverride).where(FestivalOverride.year == year)).scalars().all()
    by_slug = {o.slug: o for o in overrides}
    out = []
    for item in items:
        o = by_slug.pop(item["slug"], None)
        if o is None:
            out.append(item)
            continue
        if o.hidden:
            continue
        merged = dict(item, computed=False)
        if o.date:
            merged["date"] = o.date.isoformat()
        for field in ("name", "name_hi", "deity", "description"):
            if getattr(o, field):
                merged[field] = getattr(o, field)
        out.append(merged)
    # Remaining overrides are admin-added events (regional festivals, temple days).
    for o in by_slug.values():
        if o.date and not o.hidden:
            out.append({"slug": o.slug, "kind": "festival", "name": o.name or o.slug, "name_hi": o.name_hi,
                        "deity": o.deity, "date": o.date.isoformat(), "major": True, "computed": False,
                        "description": o.description})
    out.sort(key=lambda x: x["date"])
    return out


@router.get("/festivals", response_model=list[FestivalOut])
def festival_list(db: DB, response: Response, year: Annotated[int | None, Query(ge=1902, le=2049)] = None,
                  include_recurring: bool = False, lat: Lat = None, lon: Lon = None, tz: Tz = None):
    loc = location(lat, lon, tz)
    year = year or today_in(loc.tz).year
    items = festivals.compute_festivals(year, loc)
    if include_recurring:
        items = sorted(items + festivals.compute_recurring(year, loc), key=lambda x: x["date"])
    response.headers["Cache-Control"] = "public, max-age=21600"
    return _apply_overrides(db, year, items)


@router.get("/festivals/upcoming", response_model=list[FestivalOut])
def upcoming(db: DB, limit: Annotated[int, Query(ge=1, le=20)] = 5, lat: Lat = None, lon: Lon = None, tz: Tz = None):
    loc = location(lat, lon, tz)
    today = today_in(loc.tz)
    items = _apply_overrides(db, today.year, festivals.compute_festivals(today.year, loc))
    if today.year < 2049:
        items += _apply_overrides(db, today.year + 1, festivals.compute_festivals(today.year + 1, loc))
    return [i for i in items if i["date"] >= today.isoformat()][:limit]


def _rashifal_day(db, day: date, language: str) -> list[dict]:
    cached = db.execute(select(RashifalEntry).where(RashifalEntry.day == day, RashifalEntry.language == language)
                        ).scalars().all()
    if len(cached) == 12:
        order = {slug: i for i, slug in enumerate(RASHIS)}
        return [dict(c.data, source=c.source) for c in sorted(cached, key=lambda c: order.get(c.rashi, 99))]
    readings = rashifal.all_readings(day, language)
    source = "rules"
    if ai.ai_enabled():
        polished = ai.polish_rashifal(readings, language)
        if polished:
            readings, source = polished, "ai"
    existing = {c.rashi for c in cached}
    for r in readings:
        if r["rashi"] not in existing:
            db.add(RashifalEntry(day=day, rashi=r["rashi"], language=language, data=r, source=source))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()  # a concurrent request stored the same day first; ours is equivalent
    return [dict(r, source=source) for r in readings]


@router.get("/rashifal")
def rashifal_all(db: DB, response: Response, day: date | None = None,
                 lang: Annotated[str, Query(pattern="^(hi|en|te)$")] = "hi"):
    day = day or today_in(get_settings().default_tz)
    _check_day(day)
    response.headers["Cache-Control"] = "public, max-age=1800"
    return {"date": day.isoformat(), "readings": _rashifal_day(db, day, lang)}


@router.get("/rashifal/{rashi}")
def rashifal_one(rashi: str, db: DB, day: date | None = None,
                 lang: Annotated[str, Query(pattern="^(hi|en|te)$")] = "hi"):
    if rashi not in RASHIS:
        raise HTTPException(404, "Unknown rashi")
    day = day or today_in(get_settings().default_tz)
    _check_day(day)
    return next(r for r in _rashifal_day(db, day, lang) if r["rashi"] == rashi)
