"""Idempotent loader for the bundled, legally reusable seed content."""

from __future__ import annotations

import json
import re
from pathlib import Path

from indic_transliteration import sanscript
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import Banner, Book, BookChapter, Deity, GitaChapter, GitaVerse, TextItem, Track, Video, Wallpaper
from app.seed.texts import DEITIES, MANTRAS, TEXTS
from app.services import gita_search

DATA = Path(__file__).parent / "data"
VOWELS = set("aāiīuūṛṝeoṃṁ")
ASPIRATES = ("kh", "gh", "ch", "jh", "ṭh", "ḍh", "th", "dh", "ph", "bh")

ORIGINAL_AUDIO = [
    # slug, kind, deity, title, title_hi, file, seconds
    ("om-chant-drone", "ambient", "shiva", "Om Drone (136.1 Hz)", "ॐ नाद", "om-chant-drone.m4a", 48),
    ("tanpura-drone", "ambient", "general", "Tanpura Drone for Meditation", "तानपुरा", "tanpura-drone.m4a", 40),
    ("temple-bell", "ambient", "general", "Temple Bell", "मंदिर की घंटी", "temple-bell.m4a", 6),
    ("shankh-naad", "ambient", "vishnu", "Shankh Naad", "शंख नाद", "shankh.m4a", 5),
    ("ghanti", "ambient", "general", "Puja Ghanti", "पूजा घंटी", "ghanti.m4a", 4),
    ("bhupali-flute", "dhun", "krishna", "Bhupali on Bansuri", "भूपाली बाँसुरी", "bhupali-flute.m4a", 11),
    ("damru-rhythm", "dhun", "shiva", "Damru Rhythm", "डमरू", "damru-rhythm.m4a", 6),
    ("ringtone-temple-bells", "ringtone", "general", "Temple Bells", "मंदिर घंटियाँ", "ringtone-temple-bells.m4a", 24),
    ("ringtone-shankh-naad", "ringtone", "vishnu", "Shankh Naad", "शंख नाद", "ringtone-shankh-naad.m4a", 20),
    ("ringtone-bhupali-flute", "ringtone", "krishna", "Krishna Bansuri", "कृष्ण बाँसुरी", "ringtone-bhupali-flute.m4a", 14),
    ("ringtone-om-shanti", "ringtone", "shiva", "Om Shanti", "ॐ शांति", "ringtone-om-shanti.m4a", 24),
    ("notification-ghanti", "ringtone", "general", "Ghanti (notification)", "घंटी (सूचना)", "notification-ghanti.m4a", 2),
]


def media_base() -> str:
    s = get_settings()
    if s.storage_backend == "r2" and s.r2_public_base_url:
        return f"{s.r2_public_base_url.rstrip('/')}/seed"
    return f"{s.public_base_url.rstrip('/')}/media/seed"


def _drop_schwa(word: str) -> str:
    """Hindi drops a word-final inherent 'a' after a single consonant (jaya -> jay, putra stays)."""
    if len(word) < 3 or not word.endswith("a") or word.endswith(("aa", "ia", "ua")):
        return word
    consonant = 2 if word[:-1].endswith(ASPIRATES) else 1
    before = word[: -1 - consonant]
    return word[:-1] if before and before[-1] in VOWELS else word


def transliterate(text: str, hindi: bool) -> str:
    plain = text.replace("॥", "").replace("।", "").replace("ॐ", "ओम्")
    out = sanscript.transliterate(plain, sanscript.DEVANAGARI, sanscript.IAST).replace("~", "ṁ")
    if hindi:
        out = re.sub(r"[a-zāīūṛṝṃḥṅñṇṭḍśṣ]+", lambda m: _drop_schwa(m.group(0)), out)
    return "\n".join(line.strip() for line in out.splitlines())


def _upsert(db: Session, model, key: str, value, fields: dict):
    obj = db.scalar(select(model).where(getattr(model, key) == value))
    if obj is None:
        obj = model(**{key: value})
        db.add(obj)
    for k, v in fields.items():
        setattr(obj, k, v)
    return obj


def load_all(db: Session, include_books: bool = True) -> dict[str, int]:
    commons = json.loads((DATA / "commons.json").read_text())
    counts: dict[str, int] = {}

    deities = {}
    for sort, (slug, name, name_hi, color, weekday, desc) in enumerate(DEITIES):
        deities[slug] = _upsert(db, Deity, "slug", slug, {
            "name": name, "name_hi": name_hi, "color": color, "weekday": weekday, "description": desc,
            "image_url": commons["portraits"].get(slug, ""), "sort": sort})
    db.flush()
    counts["deities"] = len(deities)

    for sort, t in enumerate(TEXTS):
        _upsert(db, TextItem, "slug", t["slug"], {
            "title": t["title"], "title_hi": t["title_hi"], "kind": t["kind"], "deity_id": deities[t["deity"]].id,
            "body": t["body"], "transliteration": transliterate(t["body"], t["lang"] == "hi"),
            "meaning": t["meaning"], "benefits": t.get("benefits", ""), "attribution": t["attribution"],
            "license": "Public domain", "sort": sort})
    for sort, (slug, deity, title, title_hi, body, meaning) in enumerate(MANTRAS):
        _upsert(db, TextItem, "slug", slug, {
            "title": title, "title_hi": title_hi, "kind": "mantra", "deity_id": deities[deity].id, "body": body,
            "transliteration": transliterate(body, False), "meaning": meaning,
            "attribution": "Traditional Sanskrit", "license": "Public domain", "sort": 100 + sort})
    counts["texts"] = len(TEXTS) + len(MANTRAS)

    text_for = {"gayatri-mantra-chant": "gayatri-mantra", "gayatri-mantra-recitation": "gayatri-mantra",
                "mahamrityunjaya-chant": "mahamrityunjaya-mantra", "om-namah-shivaya-khajuraho": "om-namah-shivaya",
                "aarti-lakshmi": "om-jai-lakshmi-mata", "aarti-ganpati-vandana": "jai-ganesh-deva"}
    for sort, tr in enumerate(commons["tracks"]):
        deity = deities.get(tr["deity"])
        _upsert(db, Track, "slug", tr["slug"], {
            "title": tr["title"], "title_hi": tr["title_hi"], "kind": tr["kind"], "deity_id": deity.id if deity else None,
            "audio_url": tr["audio_url"], "duration_sec": tr["duration_sec"],
            "artwork_url": deity.image_url if deity else "", "artist": tr["attribution"].split(" · ")[0][:200],
            "attribution": tr["attribution"], "license": tr["license"], "source_url": tr["source_url"],
            "text_slug": text_for.get(tr["slug"]), "sort": sort})
    base = media_base()
    for sort, (slug, kind, deity, title, title_hi, file, seconds) in enumerate(ORIGINAL_AUDIO):
        _upsert(db, Track, "slug", slug, {
            "title": title, "title_hi": title_hi, "kind": kind, "deity_id": deities[deity].id,
            "audio_url": f"{base}/{file}", "duration_sec": seconds, "artwork_url": deities[deity].image_url,
            "artist": "Devalay (synthesised)", "attribution": "Original sound by Devalay · CC0",
            "license": "CC0", "source_url": "https://github.com/ChandraChaan/devalay", "sort": 200 + sort})
    counts["tracks"] = len(commons["tracks"]) + len(ORIGINAL_AUDIO)

    for sort, w in enumerate(commons["wallpapers"]):
        deity = deities.get(w["deity"])
        _upsert(db, Wallpaper, "image_url", w["image_url"], {
            "title": w["title"], "deity_id": deity.id if deity else None, "thumb_url": w["thumb_url"],
            "width": w["width"], "height": w["height"], "dominant_color": deity.color if deity else "#5D4037",
            "attribution": w["attribution"], "license": w["license"], "source_url": w["source_url"],
            "tags": [w["deity"]], "sort": sort})
    counts["wallpapers"] = len(commons["wallpapers"])

    for sort, v in enumerate(commons["videos"]):
        _upsert(db, Video, "title", v["title"], {
            "description": v["description"], "video_url": v["video_url"], "thumbnail_url": v["thumbnail_url"],
            "duration_sec": v["duration_sec"], "year": v["year"], "attribution": v["attribution"],
            "license": v["license"], "source_url": v["source_url"],
            "deity_id": deities["krishna"].id if "Krishna" in v["title"] or "Kaliya" in v["title"] else None,
            "sort": sort})
    counts["videos"] = len(commons["videos"])

    gita = json.loads((DATA / "gita.json").read_text())
    for c in gita["chapters"]:
        _upsert(db, GitaChapter, "number", c["number"], {k: v for k, v in c.items() if k != "number"})
    db.flush()
    existing = {(v.chapter, v.verse): v for v in db.execute(select(GitaVerse)).scalars()}
    for v in gita["verses"]:
        obj = existing.get((v["chapter"], v["verse"]))
        if obj is None:
            db.add(GitaVerse(**v))
        else:
            for k, val in v.items():
                setattr(obj, k, val)
    counts["gita_verses"] = len(gita["verses"])
    gita_search.reset_index()

    if include_books:
        books = json.loads((DATA / "books.json").read_text())["books"]
        for sort, b in enumerate(books):
            book = _upsert(db, Book, "slug", b["slug"], {
                **{k: b[k] for k in ("title", "title_hi", "author", "language", "license", "source_url",
                                     "attribution", "description")}, "sort": sort})
            db.flush()
            db.execute(delete(BookChapter).where(BookChapter.book_id == book.id))
            db.add_all(BookChapter(book_id=book.id, number=c["number"], title=c["title"][:300], body=c["body"])
                       for c in b["chapters"])
        counts["books"] = len(books)

    if not db.scalar(select(Banner).limit(1)):
        db.add(Banner(title="Welcome to Devalay", subtitle="Light a diya in the Mandir and begin your day with a prayer",
                      deep_link="devalay://mandir", sort=0))
    db.commit()
    return counts
