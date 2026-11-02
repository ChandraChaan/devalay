from datetime import timedelta

from fastapi import APIRouter, Response
from sqlalchemy import select

from app.deps import DB
from app.models import Deity, TextItem, Track, Wallpaper
from app.routers import astro, content
from app.routers.astro import Lat, Lon, Tz
from app.schemas import DeityOut, GitaVerseOut, TextSummary, TrackOut, WallpaperOut

router = APIRouter(tags=["home"])


@router.get("/home")
def home(db: DB, response: Response, lat: Lat = None, lon: Lon = None, tz: Tz = None):
    """Everything the home screen needs in one request."""
    loc = astro.location(lat, lon, tz)
    today = astro.today_in(loc.tz)
    p = astro._cached_daily(loc, today)
    weekday_deity = db.scalar(select(Deity).where(Deity.weekday == today.weekday()))
    featured = select(Track).where(Track.published.is_(True), Track.kind.in_(("aarti", "mantra", "bhajan", "chalisa")))
    if weekday_deity:
        featured = featured.order_by((Track.deity_id == weekday_deity.id).desc(), Track.sort)
    else:
        featured = featured.order_by(Track.sort)
    verse = content.verse_of_day(db, today)
    response.headers["Cache-Control"] = "public, max-age=600"
    return {
        "date": today.isoformat(),
        "panchang": {
            "vara": p["vara"], "sunrise": p["sunrise"], "sunset": p["sunset"],
            "tithi": p["tithi"][0], "nakshatra": p["nakshatra"][0], "yoga": p["yoga"][0],
            "lunar_month": p["lunar_month"], "vikram_samvat": p["vikram_samvat"],
            "rahu_kaal": p["rahu_kaal"], "abhijit_muhurta": p["abhijit_muhurta"],
            "moon_rashi": p["moon_rashi"],
        },
        "deity_of_day": DeityOut.model_validate(weekday_deity) if weekday_deity else None,
        "upcoming_festivals": astro.upcoming(db, 4, lat, lon, tz),
        "verse_of_day": GitaVerseOut.model_validate(verse) if verse else None,
        "featured_tracks": [TrackOut.model_validate(t) for t in db.execute(featured.limit(10)).scalars()],
        "aartis": [TextSummary.model_validate(t) for t in db.execute(
            select(TextItem).where(TextItem.published.is_(True), TextItem.kind == "aarti")
            .order_by(TextItem.sort).limit(8)).scalars()],
        "wallpapers": [WallpaperOut.model_validate(w) for w in db.execute(
            select(Wallpaper).where(Wallpaper.published.is_(True))
            .order_by(Wallpaper.sort, Wallpaper.id).limit(8)).scalars()],
        "banners": content.banners(db, today),
        "tomorrow": (today + timedelta(days=1)).isoformat(),
    }
