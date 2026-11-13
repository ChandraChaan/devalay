"""Shubha Muhurtham, Grahanam (eclipses) and gochara (transits) endpoints."""

from datetime import date
from functools import lru_cache

from fastapi import APIRouter, Response

from app.config import get_settings
from app.routers.astro import Lat, Lon, Tz, location, today_in
from app.services import eclipses, gochara, muhurtham
from app.services.panchang import Location

router = APIRouter(tags=["jyotish"])


@lru_cache(maxsize=64)
def _muhurtham(loc: Location, today: date) -> dict:
    return muhurtham.all_dates(loc, today, date(today.year + 1, 12, 31))


@router.get("/muhurtham")
def muhurtham_dates(response: Response, lat: Lat = None, lon: Lon = None, tz: Tz = None):
    """Auspicious days from today to the end of next year for vivaha, griha pravesha and vehicle purchase."""
    loc = location(lat, lon, tz)
    response.headers["Cache-Control"] = "public, max-age=86400"
    return _muhurtham(loc, today_in(loc.tz))


@lru_cache(maxsize=64)
def _eclipses(loc: Location, year: int) -> list[dict]:
    return eclipses.eclipses(loc, date(year, 1, 1), date(year + 1, 12, 31))


@router.get("/eclipses")
def eclipse_list(response: Response, lat: Lat = None, lon: Lon = None, tz: Tz = None):
    """Solar and lunar eclipses this year and next, with local times and Sutak."""
    loc = location(lat, lon, tz)
    response.headers["Cache-Control"] = "public, max-age=86400"
    return _eclipses(loc, today_in(loc.tz).year)


@lru_cache(maxsize=4)
def _transits(year: int) -> dict:
    return gochara.transits(date(year, 1, 1), date(year + 1, 12, 31))


@router.get("/gochara")
def transits(response: Response):
    """Moon sign per day and the Sun's, Jupiter's and Saturn's sign changes, this year and next."""
    response.headers["Cache-Control"] = "public, max-age=86400"
    return _transits(today_in(get_settings().default_tz).year)
