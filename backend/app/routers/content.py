from datetime import date
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Response
from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import selectinload

from app.deps import DB
from app.models import (
    Banner,
    Book,
    BookChapter,
    Deity,
    GitaChapter,
    GitaVerse,
    TextItem,
    Track,
    Video,
    Wallpaper,
)
from app.schemas import (
    BannerOut,
    BookOut,
    BookSummary,
    ChapterOut,
    DeityOut,
    GitaChapterDetail,
    GitaChapterOut,
    GitaVerseOut,
    Page,
    TextOut,
    TextSummary,
    TrackOut,
    VideoOut,
    WallpaperOut,
)

router = APIRouter(tags=["content"])

PageNo = Annotated[int, Query(ge=1, le=10_000)]
PageSize = Annotated[int, Query(ge=1, le=100)]
Search = Annotated[str | None, Query(max_length=80)]

CACHE_SHORT = "public, max-age=300"
CACHE_LONG = "public, max-age=86400"


def _deity_id(db, slug: str | None) -> int | None:
    if not slug:
        return None
    deity = db.scalar(select(Deity).where(Deity.slug == slug))
    if deity is None:
        raise HTTPException(404, "Unknown deity")
    return deity.id


def _paginate(db, stmt, page: int, page_size: int):
    total = db.scalar(select(func.count()).select_from(stmt.order_by(None).subquery())) or 0
    items = db.execute(stmt.offset((page - 1) * page_size).limit(page_size)).scalars().all()
    return {"items": items, "total": total, "page": page, "page_size": page_size}


def _like(term: str) -> str:
    escaped = term.lower().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


@router.get("/deities", response_model=list[DeityOut])
def deities(db: DB, response: Response):
    response.headers["Cache-Control"] = CACHE_LONG
    return db.execute(select(Deity).order_by(Deity.sort, Deity.name)).scalars().all()


@router.get("/tracks", response_model=Page[TrackOut])
def tracks(db: DB, response: Response, kind: str | None = None, deity: str | None = None,
           q: Search = None, page: PageNo = 1, page_size: PageSize = 30):
    stmt = select(Track).where(Track.published.is_(True))
    if kind:
        stmt = stmt.where(Track.kind.in_(kind.split(",")))
    if deity_id := _deity_id(db, deity):
        stmt = stmt.where(Track.deity_id == deity_id)
    if q:
        stmt = stmt.where(or_(func.lower(Track.title).like(_like(q), escape="\\"), Track.title_hi.like(f"%{q}%")))
    response.headers["Cache-Control"] = CACHE_SHORT
    return _paginate(db, stmt.order_by(Track.sort, Track.id), page, page_size)


@router.get("/tracks/{track_id}", response_model=TrackOut)
def track(track_id: int, db: DB):
    item = db.get(Track, track_id)
    if item is None or not item.published:
        raise HTTPException(404, "Not found")
    return item


@router.post("/tracks/{track_id}/play", status_code=204)
def track_played(track_id: int, db: DB):
    db.execute(update(Track).where(Track.id == track_id).values(play_count=Track.play_count + 1))
    db.commit()


@router.get("/texts", response_model=Page[TextSummary])
def texts(db: DB, response: Response, kind: str | None = None, deity: str | None = None,
          q: Search = None, page: PageNo = 1, page_size: PageSize = 50):
    stmt = select(TextItem).where(TextItem.published.is_(True))
    if kind:
        stmt = stmt.where(TextItem.kind.in_(kind.split(",")))
    if deity_id := _deity_id(db, deity):
        stmt = stmt.where(TextItem.deity_id == deity_id)
    if q:
        stmt = stmt.where(or_(func.lower(TextItem.title).like(_like(q), escape="\\"), TextItem.title_hi.like(f"%{q}%")))
    response.headers["Cache-Control"] = CACHE_SHORT
    return _paginate(db, stmt.order_by(TextItem.sort, TextItem.id), page, page_size)


@router.get("/texts/{slug}", response_model=TextOut)
def text(slug: str, db: DB, response: Response):
    item = db.scalar(select(TextItem).where(TextItem.slug == slug, TextItem.published.is_(True)))
    if item is None:
        raise HTTPException(404, "Not found")
    response.headers["Cache-Control"] = CACHE_LONG
    return item


@router.get("/wallpapers", response_model=Page[WallpaperOut])
def wallpapers(db: DB, response: Response, deity: str | None = None, page: PageNo = 1, page_size: PageSize = 30):
    stmt = select(Wallpaper).where(Wallpaper.published.is_(True))
    if deity_id := _deity_id(db, deity):
        stmt = stmt.where(Wallpaper.deity_id == deity_id)
    response.headers["Cache-Control"] = CACHE_SHORT
    return _paginate(db, stmt.order_by(Wallpaper.sort, Wallpaper.id), page, page_size)


@router.post("/wallpapers/{wallpaper_id}/download", status_code=204)
def wallpaper_downloaded(wallpaper_id: int, db: DB):
    db.execute(update(Wallpaper).where(Wallpaper.id == wallpaper_id)
               .values(download_count=Wallpaper.download_count + 1))
    db.commit()


@router.get("/videos", response_model=Page[VideoOut])
def videos(db: DB, response: Response, page: PageNo = 1, page_size: PageSize = 30):
    stmt = select(Video).where(Video.published.is_(True)).order_by(Video.sort, Video.id)
    response.headers["Cache-Control"] = CACHE_SHORT
    return _paginate(db, stmt, page, page_size)


@router.get("/books", response_model=list[BookSummary])
def books(db: DB, response: Response):
    counts = dict(db.execute(select(BookChapter.book_id, func.count()).group_by(BookChapter.book_id)).all())
    rows = db.execute(select(Book).where(Book.published.is_(True)).order_by(Book.sort, Book.id)).scalars().all()
    response.headers["Cache-Control"] = CACHE_SHORT
    return [BookSummary.model_validate(b).model_copy(update={"chapter_count": counts.get(b.id, 0)}) for b in rows]


@router.get("/books/{slug}", response_model=BookOut)
def book(slug: str, db: DB, response: Response):
    item = db.scalar(select(Book).options(selectinload(Book.chapters))
                     .where(Book.slug == slug, Book.published.is_(True)))
    if item is None:
        raise HTTPException(404, "Not found")
    response.headers["Cache-Control"] = CACHE_LONG
    out = BookOut.model_validate(item)
    out.chapter_count = len(item.chapters)
    return out


@router.get("/books/{slug}/chapters/{number}", response_model=ChapterOut)
def book_chapter(slug: str, number: int, db: DB, response: Response):
    book_obj = db.scalar(select(Book).where(Book.slug == slug, Book.published.is_(True)))
    if book_obj is None:
        raise HTTPException(404, "Not found")
    chapter = db.scalar(select(BookChapter).where(BookChapter.book_id == book_obj.id, BookChapter.number == number))
    if chapter is None:
        raise HTTPException(404, "Not found")
    has_next = db.scalar(select(func.count()).where(BookChapter.book_id == book_obj.id,
                                                   BookChapter.number > number)) > 0
    response.headers["Cache-Control"] = CACHE_LONG
    return ChapterOut(number=chapter.number, title=chapter.title, body=chapter.body, book_slug=slug, has_next=has_next)


@router.get("/gita/chapters", response_model=list[GitaChapterOut])
def gita_chapters(db: DB, response: Response):
    response.headers["Cache-Control"] = CACHE_LONG
    return db.execute(select(GitaChapter).order_by(GitaChapter.number)).scalars().all()


@router.get("/gita/chapters/{number}", response_model=GitaChapterDetail)
def gita_chapter(number: int, db: DB, response: Response):
    chapter = db.get(GitaChapter, number)
    if chapter is None:
        raise HTTPException(404, "Not found")
    verses = db.execute(select(GitaVerse).where(GitaVerse.chapter == number).order_by(GitaVerse.verse)).scalars().all()
    response.headers["Cache-Control"] = CACHE_LONG
    return GitaChapterDetail(**GitaChapterOut.model_validate(chapter).model_dump(),
                             verses=[GitaVerseOut.model_validate(v) for v in verses])


def verse_of_day(db, day: date) -> GitaVerse | None:
    total = db.scalar(select(func.count()).select_from(GitaVerse)) or 0
    if not total:
        return None
    offset = (day.toordinal() * 7919) % total  # deterministic, spread across the book
    return db.execute(select(GitaVerse).order_by(GitaVerse.id).offset(offset).limit(1)).scalar_one()


@router.get("/gita/verse-of-the-day", response_model=GitaVerseOut)
def gita_verse_of_day(db: DB, day: date | None = None):
    verse = verse_of_day(db, day or date.today())
    if verse is None:
        raise HTTPException(404, "Gita not loaded")
    return verse


@router.get("/gita/{chapter}/{verse}", response_model=GitaVerseOut)
def gita_verse(chapter: int, verse: int, db: DB):
    item = db.scalar(select(GitaVerse).where(GitaVerse.chapter == chapter, GitaVerse.verse == verse))
    if item is None:
        raise HTTPException(404, "Not found")
    return item


@router.get("/banners", response_model=list[BannerOut])
def banners(db: DB, day: date | None = None):
    today = day or date.today()
    stmt = select(Banner).where(
        Banner.published.is_(True),
        or_(Banner.starts_on.is_(None), Banner.starts_on <= today),
        or_(Banner.ends_on.is_(None), Banner.ends_on >= today),
    ).order_by(Banner.sort, Banner.id)
    return db.execute(stmt).scalars().all()


@router.get("/search")
def search(db: DB, q: Annotated[str, Query(min_length=2, max_length=80)],
           limit: Annotated[int, Query(ge=1, le=30)] = 10):
    """Search across tracks, texts, books, wallpapers and Gita translations."""
    pattern = _like(q)
    hi_pattern = f"%{q}%"
    track_rows = db.execute(select(Track).where(Track.published.is_(True), or_(
        func.lower(Track.title).like(pattern, escape="\\"), Track.title_hi.like(hi_pattern))).limit(limit)).scalars()
    text_rows = db.execute(select(TextItem).where(TextItem.published.is_(True), or_(
        func.lower(TextItem.title).like(pattern, escape="\\"), TextItem.title_hi.like(hi_pattern),
        TextItem.body.like(hi_pattern))).limit(limit)).scalars()
    book_rows = db.execute(select(Book).where(Book.published.is_(True), or_(
        func.lower(Book.title).like(pattern, escape="\\"), Book.title_hi.like(hi_pattern))).limit(limit)).scalars()
    wall_rows = db.execute(select(Wallpaper).where(
        Wallpaper.published.is_(True), func.lower(Wallpaper.title).like(pattern, escape="\\")).limit(limit)).scalars()
    verse_rows = db.execute(select(GitaVerse).where(or_(
        func.lower(GitaVerse.translation_en).like(pattern, escape="\\"), GitaVerse.sanskrit.like(hi_pattern)
    )).limit(limit)).scalars()
    return {
        "tracks": [TrackOut.model_validate(t) for t in track_rows],
        "texts": [TextSummary.model_validate(t) for t in text_rows],
        "books": [BookSummary.model_validate(b) for b in book_rows],
        "wallpapers": [WallpaperOut.model_validate(w) for w in wall_rows],
        "verses": [GitaVerseOut.model_validate(v) for v in verse_rows],
    }
