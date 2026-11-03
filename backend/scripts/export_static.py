"""Pre-render the read-only API to static JSON for GitHub Pages ("static mode").

The public APK talks to these files instead of a live server, so it works with
no hosting bill. Content endpoints are exported once; date-dependent ones
(home, Panchang, Rashifal) are exported for a rolling window around today, and
CI re-runs this script daily. Accounts, sync and Premium need the real server.

File layout mirrors the app's request: path + sorted query, see static_file().
The Dart twin lives in app/lib/core/static_api.dart; keep the two in step.

Usage: python scripts/export_static.py OUT_DIR BASE_URL
  e.g. python scripts/export_static.py ../site https://chandrachaan.github.io/devalay
"""

import json
import logging
import os
import re
import shutil
import sys
import tempfile
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT.parent / "site"
BASE_URL = (sys.argv[2] if len(sys.argv) > 2 else "https://chandrachaan.github.io/devalay").rstrip("/")
_tmp = Path(tempfile.mkdtemp(prefix="devalay-static-"))
os.environ.update({
    "DEVALAY_DATABASE_URL": f"sqlite:///{_tmp / 'static.db'}",
    "DEVALAY_PUBLIC_BASE_URL": BASE_URL,
    "DEVALAY_MEDIA_DIR": str(_tmp / "media"),
    "DEVALAY_ANTHROPIC_API_KEY": "",
    "DEVALAY_ENV": "test",  # disables rate limiting for the bulk export
    "DEVALAY_SECRET_KEY": os.urandom(32).hex(),
})
sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.routers import astro  # noqa: E402
from app.seed.loader import load_all  # noqa: E402
from app.services import ai, gita_search  # noqa: E402

CITY = re.compile(r"City\('([\w-]+)', '[^']*', '[^']*', (-?[\d.]+), (-?[\d.]+), '([^']+)'\)")
TRACK_KINDS = [None, "ringtone", "aarti", "mantra", "bhajan", "dhun", "ambient", "aarti,mantra,bhajan,chalisa,dhun,ambient"]
HOME_DAYS = range(-2, 11)
PANCHANG_DAYS = range(-7, 46)
MONTHS_AHEAD = range(-1, 4)
logging.disable(logging.INFO)  # one request log line per file is noise


def static_file(path: str, query: dict | None = None) -> str:
    """'/tracks', {'kind': 'aarti', 'page_size': '100'} -> 'tracks/kind-aarti~page_size-100.json'."""
    q = {k: v for k, v in (query or {}).items() if v is not None}
    name = "~".join(f"{k}-{re.sub(r'[^A-Za-z0-9.-]', '_', str(v))}" for k, v in sorted(q.items())) or "index"
    return f"{path.strip('/')}/{name}.json"


class Exporter:
    def __init__(self, client: TestClient):
        self.client = client
        self.count = 0

    def save(self, rel: str, data) -> None:
        target = OUT / "api" / "v1" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
        self.count += 1

    def get(self, path: str, query: dict | None = None, key: dict | None = None):
        """Fetch path with query, store under key (defaults to query)."""
        r = self.client.get(f"/api/v1{path}", params={k: v for k, v in (query or {}).items() if v is not None})
        r.raise_for_status()
        data = r.json()
        self.save(static_file(path, query if key is None else key), data)
        return data


def cities() -> list[tuple[str, dict]]:
    src = (ROOT.parent / "app" / "lib" / "core" / "location.dart").read_text()
    return [(cid, {"lat": lat, "lon": lon, "tz": tz}) for cid, lat, lon, tz in CITY.findall(src)]


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT / "api", ignore_errors=True)
        shutil.rmtree(OUT / "media", ignore_errors=True)
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        load_all(db, include_books=True)
    today = date.today()
    real_today_in = astro.today_in

    with TestClient(app) as client:
        ex = Exporter(client)
        ex.get("/config")
        ex.get("/premium/plans")
        deities = ex.get("/deities")
        slugs = [None] + [d["slug"] for d in deities]

        for kind in TRACK_KINDS:
            for deity in slugs:
                ex.get("/tracks", {"page_size": "100", "kind": kind, "deity": deity})
        all_tracks = ex.get("/tracks", {"page_size": "100"})["items"]
        for t in all_tracks:
            ex.get(f"/tracks/{t['id']}")

        texts = ex.get("/texts", {"page_size": "100"})["items"]
        for kind in sorted({t["kind"] for t in texts}):
            ex.get("/texts", {"page_size": "100", "kind": kind})
        full_texts = [ex.get(f"/texts/{t['slug']}") for t in texts]

        for deity in slugs:
            ex.get("/wallpapers", {"page_size": "100", "deity": deity})
        ex.get("/videos")

        ex.get("/gita/chapters")
        verses = []
        for n in range(1, 19):
            verses += ex.get(f"/gita/chapters/{n}")["verses"]
        books = ex.get("/books")
        for b in books:
            for ch in ex.get(f"/books/{b['slug']}")["chapters"]:
                ex.get(f"/books/{b['slug']}/chapters/{ch['number']}")

        # Client-side search and offline AI read these two files.
        ex.save(static_file("/search/index"), {
            "tracks": all_tracks,
            "texts": [dict(s, body=f.get("body", "")) for s, f in zip(texts, full_texts, strict=True)],
            "books": books,
            "wallpapers": ex.get("/wallpapers", {"page_size": "100"})["items"],
            "verses": verses,
            "stopwords": sorted(gita_search.STOPWORDS),
            "synonyms": gita_search.SYNONYMS,
        })
        ex.save(static_file("/ai/status"), {
            "deity_names": ai.DEITY_NAMES, "chants": ai.CHANTS, "templates": ai.TEMPLATES,
            "occasion_prefix": ai.OCCASION_PREFIX,
        })

        for lang in ("hi", "en"):
            for offset in HOME_DAYS:
                ex.get("/rashifal", {"lang": lang, "day": (today + timedelta(days=offset)).isoformat()})

        months = sorted({((today.month - 1 + m) // 12 + today.year, (today.month - 1 + m) % 12 + 1)
                         for m in MONTHS_AHEAD})
        for cid, loc in cities():
            key = {"city": cid}
            for offset in HOME_DAYS:
                day = today + timedelta(days=offset)
                astro.today_in = lambda _tz, d=day: d
                try:
                    ex.get("/home", loc, {**key, "day": day.isoformat()})
                finally:
                    astro.today_in = real_today_in
            for offset in PANCHANG_DAYS:
                day = (today + timedelta(days=offset)).isoformat()
                ex.get("/panchang", {**loc, "day": day}, {**key, "day": day})
            for y, m in months:
                ex.get("/panchang/month", {**loc, "year": str(y), "month": str(m)},
                       {**key, "year": str(y), "month": str(m)})
            for y in (today.year, today.year + 1):
                q = {"year": str(y), "include_recurring": "true"}
                ex.get("/festivals", {**loc, **q}, {**key, **q})

        for page, name in (("/privacy", "privacy.html"), ("/terms", "terms.html")):
            (OUT / name).write_text(client.get(page).text)

    shutil.copytree(ROOT / "media" / "seed", OUT / "media" / "seed", dirs_exist_ok=True)
    ex.save("meta/index.json", {"generated": today.isoformat(), "files": ex.count + 1,
                                 "window": {"from": (today + timedelta(days=PANCHANG_DAYS.start)).isoformat(),
                                            "to": (today + timedelta(days=PANCHANG_DAYS.stop - 1)).isoformat()}})
    print(f"Exported {ex.count} files to {OUT}")


if __name__ == "__main__":
    main()
