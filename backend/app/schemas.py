from datetime import date, datetime
from typing import Generic, Literal, TypeVar

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

T = TypeVar("T")

RASHIS = (
    "mesha", "vrishabha", "mithuna", "karka", "simha", "kanya",
    "tula", "vrishchika", "dhanu", "makara", "kumbha", "meena",
)
Language = Literal["hi", "en", "te"]


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Page(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    page_size: int


# ---------- auth ----------
class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(default="", max_length=80)

    @field_validator("password")
    @classmethod
    def strong_enough(cls, v: str) -> str:
        if v.isdigit() or v.isalpha() or len(set(v)) < 4:
            raise ValueError("Use a mix of letters and numbers or symbols")
        return v


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(max_length=128)


class RefreshIn(BaseModel):
    refresh_token: str = Field(max_length=200)


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class ForgotIn(BaseModel):
    email: EmailStr


class ResetIn(BaseModel):
    email: EmailStr
    code: str = Field(pattern=r"^\d{6}$")
    new_password: str = Field(min_length=8, max_length=128)


class UserOut(ORM):
    id: int
    email: str
    display_name: str
    role: str
    language: str
    ishta_devta: str | None
    rashi: str | None
    is_premium: bool
    premium_until: datetime | None
    created_at: datetime


class UserUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=80)
    language: Language | None = None
    ishta_devta: str | None = Field(default=None, max_length=40)
    rashi: str | None = None

    @field_validator("rashi")
    @classmethod
    def valid_rashi(cls, v: str | None) -> str | None:
        if v is not None and v not in RASHIS:
            raise ValueError("unknown rashi")
        return v


class DeleteAccountIn(BaseModel):
    password: str = Field(max_length=128)


# ---------- content ----------
class DeityOut(ORM):
    id: int
    slug: str
    name: str
    name_hi: str
    description: str
    image_url: str
    color: str
    weekday: int | None


class Licensed(ORM):
    attribution: str
    license: str
    source_url: str
    is_premium: bool


class TrackOut(Licensed):
    id: int
    slug: str
    title: str
    title_hi: str
    kind: str
    deity_id: int | None
    audio_url: str
    artwork_url: str
    duration_sec: int
    artist: str
    text_slug: str | None
    tags: list[str]
    play_count: int


class TextSummary(ORM):
    id: int
    slug: str
    title: str
    title_hi: str
    kind: str
    deity_id: int | None
    is_premium: bool


class TextOut(Licensed):
    id: int
    slug: str
    title: str
    title_hi: str
    kind: str
    deity_id: int | None
    body: str
    transliteration: str
    meaning: str
    benefits: str
    tags: list[str]


class WallpaperOut(Licensed):
    id: int
    title: str
    deity_id: int | None
    image_url: str
    thumb_url: str
    width: int
    height: int
    dominant_color: str
    tags: list[str]
    download_count: int


class VideoOut(Licensed):
    id: int
    title: str
    description: str
    deity_id: int | None
    video_url: str
    thumbnail_url: str
    duration_sec: int
    year: int | None


class BookSummary(Licensed):
    id: int
    slug: str
    title: str
    title_hi: str
    author: str
    description: str
    language: str
    cover_url: str
    chapter_count: int = 0


class ChapterSummary(ORM):
    number: int
    title: str


class BookOut(BookSummary):
    chapters: list[ChapterSummary]


class ChapterOut(ORM):
    number: int
    title: str
    body: str
    book_slug: str
    has_next: bool


class GitaChapterOut(ORM):
    number: int
    name_sanskrit: str
    name_translit: str
    name_en: str
    summary: str
    verse_count: int


class GitaVerseOut(ORM):
    chapter: int
    verse: int
    sanskrit: str
    transliteration: str
    translation_en: str
    translation_author: str


class GitaChapterDetail(GitaChapterOut):
    verses: list[GitaVerseOut]


class BannerOut(ORM):
    id: int
    title: str
    subtitle: str
    image_url: str
    deep_link: str


class FestivalOut(BaseModel):
    slug: str
    kind: str
    name: str
    name_hi: str
    deity: str
    date: date
    major: bool
    computed: bool
    description: str


# ---------- favourites ----------
ItemType = Literal["track", "text", "wallpaper", "video", "verse", "book"]


class FavoriteIn(BaseModel):
    item_type: ItemType
    item_id: str = Field(min_length=1, max_length=40, pattern=r"^[A-Za-z0-9_.:-]+$")


class FavoriteOut(ORM):
    item_type: str
    item_id: str
    created_at: datetime


# ---------- AI ----------
Deities = Literal[
    "shiva", "hanuman", "rama", "krishna", "radha-krishna", "ganesha", "durga", "kali",
    "lakshmi", "saraswati", "vishnu", "shani", "surya", "sai", "general",
]
Occasions = Literal[
    "daily", "good-morning", "good-night", "monday", "tuesday", "saturday", "festival",
    "birthday", "anniversary", "gratitude", "strength", "peace",
]


class StatusIn(BaseModel):
    deity: Deities = "general"
    occasion: Occasions = "daily"
    language: Language = "hi"
    festival: str | None = Field(default=None, max_length=60)
    name: str | None = Field(default=None, max_length=40)
    note: str | None = Field(default=None, max_length=120)


class StatusOption(BaseModel):
    text: str
    hashtags: list[str] = []


class StatusOut(BaseModel):
    options: list[StatusOption]
    provider: str
    remaining_today: int


class AskIn(BaseModel):
    question: str = Field(min_length=3, max_length=500)
    language: Language = "en"


class AskOut(BaseModel):
    answer: str
    verses: list[GitaVerseOut]
    provider: str
    remaining_today: int


class QuotaOut(BaseModel):
    limit: int
    used: int
    remaining: int
    ai_enabled: bool


# ---------- premium ----------
class VerifyPurchaseIn(BaseModel):
    product_id: str = Field(max_length=100)
    purchase_token: str = Field(min_length=10, max_length=4096)


class PremiumStatus(BaseModel):
    is_premium: bool
    premium_until: datetime | None
    product_id: str | None = None
