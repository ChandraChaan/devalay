from __future__ import annotations

from datetime import UTC, date, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


def utcnow() -> datetime:
    return datetime.now(UTC)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(80), default="")
    role: Mapped[str] = mapped_column(String(20), default="user")  # user | editor | admin
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    language: Mapped[str] = mapped_column(String(8), default="hi")
    ishta_devta: Mapped[str | None] = mapped_column(String(40), nullable=True)
    rashi: Mapped[str | None] = mapped_column(String(20), nullable=True)
    premium_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    favorites: Mapped[list[Favorite]] = relationship(back_populates="user", cascade="all, delete-orphan")

    @property
    def is_premium(self) -> bool:
        if not self.premium_until:
            return False
        until = self.premium_until if self.premium_until.tzinfo else self.premium_until.replace(tzinfo=UTC)
        return until > utcnow()

    def __str__(self) -> str:
        return self.email


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class PasswordReset(Base):
    __tablename__ = "password_resets"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    code_hash: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    used: Mapped[bool] = mapped_column(Boolean, default=False)


class Deity(Base):
    __tablename__ = "deities"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(40), unique=True)
    name: Mapped[str] = mapped_column(String(80))
    name_hi: Mapped[str] = mapped_column(String(80), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    image_url: Mapped[str] = mapped_column(String(500), default="")
    color: Mapped[str] = mapped_column(String(9), default="#FF8F00")
    weekday: Mapped[int | None] = mapped_column(Integer, nullable=True)  # 0 = Monday
    sort: Mapped[int] = mapped_column(Integer, default=0)

    def __str__(self) -> str:
        return self.name


class LicensedMixin:
    attribution: Mapped[str] = mapped_column(String(500), default="")
    license: Mapped[str] = mapped_column(String(60), default="")
    source_url: Mapped[str] = mapped_column(String(500), default="")
    published: Mapped[bool] = mapped_column(Boolean, default=True)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)


class Track(LicensedMixin, TimestampMixin, Base):
    """Playable audio: bhajan, aarti, mantra, chalisa, dhun, ringtone or ambient sound."""

    __tablename__ = "tracks"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True)
    title: Mapped[str] = mapped_column(String(200))
    title_hi: Mapped[str] = mapped_column(String(200), default="")
    kind: Mapped[str] = mapped_column(String(20), index=True)
    deity_id: Mapped[int | None] = mapped_column(ForeignKey("deities.id"), nullable=True, index=True)
    audio_url: Mapped[str] = mapped_column(String(500))
    artwork_url: Mapped[str] = mapped_column(String(500), default="")
    duration_sec: Mapped[int] = mapped_column(Integer, default=0)
    artist: Mapped[str] = mapped_column(String(200), default="")
    text_slug: Mapped[str | None] = mapped_column(String(120), nullable=True)  # lyrics in `texts`
    tags: Mapped[list] = mapped_column(JSON, default=list)
    play_count: Mapped[int] = mapped_column(Integer, default=0)
    sort: Mapped[int] = mapped_column(Integer, default=0)

    deity: Mapped[Deity | None] = relationship()

    def __str__(self) -> str:
        return self.title


class TextItem(LicensedMixin, TimestampMixin, Base):
    """Readable devotional text: aarti, chalisa, mantra, stotra, paath."""

    __tablename__ = "texts"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True)
    title: Mapped[str] = mapped_column(String(200))
    title_hi: Mapped[str] = mapped_column(String(200), default="")
    kind: Mapped[str] = mapped_column(String(20), index=True)
    deity_id: Mapped[int | None] = mapped_column(ForeignKey("deities.id"), nullable=True, index=True)
    body: Mapped[str] = mapped_column(Text)  # original script (Devanagari)
    transliteration: Mapped[str] = mapped_column(Text, default="")
    meaning: Mapped[str] = mapped_column(Text, default="")
    benefits: Mapped[str] = mapped_column(Text, default="")
    tags: Mapped[list] = mapped_column(JSON, default=list)
    sort: Mapped[int] = mapped_column(Integer, default=0)

    deity: Mapped[Deity | None] = relationship()

    def __str__(self) -> str:
        return self.title


class Book(LicensedMixin, TimestampMixin, Base):
    __tablename__ = "books"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True)
    title: Mapped[str] = mapped_column(String(200))
    title_hi: Mapped[str] = mapped_column(String(200), default="")
    author: Mapped[str] = mapped_column(String(200), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    language: Mapped[str] = mapped_column(String(8), default="en")
    cover_url: Mapped[str] = mapped_column(String(500), default="")
    sort: Mapped[int] = mapped_column(Integer, default=0)

    chapters: Mapped[list[BookChapter]] = relationship(
        back_populates="book", cascade="all, delete-orphan", order_by="BookChapter.number"
    )

    def __str__(self) -> str:
        return self.title


class BookChapter(Base):
    __tablename__ = "book_chapters"
    __table_args__ = (UniqueConstraint("book_id", "number"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    book_id: Mapped[int] = mapped_column(ForeignKey("books.id", ondelete="CASCADE"), index=True)
    number: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(300))
    body: Mapped[str] = mapped_column(Text)

    book: Mapped[Book] = relationship(back_populates="chapters")

    def __str__(self) -> str:
        return f"{self.number}. {self.title}"


class GitaChapter(Base):
    __tablename__ = "gita_chapters"

    number: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    name_sanskrit: Mapped[str] = mapped_column(String(120))
    name_translit: Mapped[str] = mapped_column(String(120))
    name_en: Mapped[str] = mapped_column(String(120))
    summary: Mapped[str] = mapped_column(Text, default="")
    verse_count: Mapped[int] = mapped_column(Integer)


class GitaVerse(Base):
    __tablename__ = "gita_verses"
    __table_args__ = (UniqueConstraint("chapter", "verse"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    chapter: Mapped[int] = mapped_column(ForeignKey("gita_chapters.number"), index=True)
    verse: Mapped[int] = mapped_column(Integer)
    sanskrit: Mapped[str] = mapped_column(Text)
    transliteration: Mapped[str] = mapped_column(Text)
    translation_en: Mapped[str] = mapped_column(Text, default="")
    translation_author: Mapped[str] = mapped_column(String(120), default="")


class Wallpaper(LicensedMixin, TimestampMixin, Base):
    __tablename__ = "wallpapers"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    deity_id: Mapped[int | None] = mapped_column(ForeignKey("deities.id"), nullable=True, index=True)
    image_url: Mapped[str] = mapped_column(String(600))
    thumb_url: Mapped[str] = mapped_column(String(600), default="")
    width: Mapped[int] = mapped_column(Integer, default=0)
    height: Mapped[int] = mapped_column(Integer, default=0)
    dominant_color: Mapped[str] = mapped_column(String(9), default="#5D4037")
    tags: Mapped[list] = mapped_column(JSON, default=list)
    download_count: Mapped[int] = mapped_column(Integer, default=0)
    sort: Mapped[int] = mapped_column(Integer, default=0)

    deity: Mapped[Deity | None] = relationship()

    def __str__(self) -> str:
        return self.title


class Video(LicensedMixin, TimestampMixin, Base):
    __tablename__ = "videos"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    deity_id: Mapped[int | None] = mapped_column(ForeignKey("deities.id"), nullable=True)
    video_url: Mapped[str] = mapped_column(String(600))
    thumbnail_url: Mapped[str] = mapped_column(String(600), default="")
    duration_sec: Mapped[int] = mapped_column(Integer, default=0)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sort: Mapped[int] = mapped_column(Integer, default=0)

    deity: Mapped[Deity | None] = relationship()

    def __str__(self) -> str:
        return self.title


class Banner(TimestampMixin, Base):
    """Admin-curated cards for the home screen (festival specials, announcements)."""

    __tablename__ = "banners"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    subtitle: Mapped[str] = mapped_column(String(300), default="")
    image_url: Mapped[str] = mapped_column(String(600), default="")
    deep_link: Mapped[str] = mapped_column(String(300), default="")  # e.g. devalay://track/12
    starts_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    ends_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    published: Mapped[bool] = mapped_column(Boolean, default=True)
    sort: Mapped[int] = mapped_column(Integer, default=0)

    def __str__(self) -> str:
        return self.title


class FestivalOverride(TimestampMixin, Base):
    """Admin corrections to computed festival dates, or extra regional events."""

    __tablename__ = "festival_overrides"
    __table_args__ = (UniqueConstraint("slug", "year"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(80))
    year: Mapped[int] = mapped_column(Integer)
    date: Mapped[date | None] = mapped_column(Date, nullable=True)
    name: Mapped[str] = mapped_column(String(200), default="")
    name_hi: Mapped[str] = mapped_column(String(200), default="")
    deity: Mapped[str] = mapped_column(String(40), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)

    def __str__(self) -> str:
        return f"{self.slug} {self.year}"


class Favorite(Base):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("user_id", "item_type", "item_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    item_type: Mapped[str] = mapped_column(String(20))  # track | text | wallpaper | video | verse | book
    item_id: Mapped[str] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    user: Mapped[User] = relationship(back_populates="favorites")


class RashifalEntry(Base):
    __tablename__ = "rashifal"
    __table_args__ = (UniqueConstraint("day", "rashi", "language"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    day: Mapped[date] = mapped_column(Date, index=True)
    rashi: Mapped[str] = mapped_column(String(20))
    language: Mapped[str] = mapped_column(String(8))
    data: Mapped[dict] = mapped_column(JSON)
    source: Mapped[str] = mapped_column(String(10), default="rules")  # rules | ai | editor
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AIUsage(Base):
    __tablename__ = "ai_usage"

    id: Mapped[int] = mapped_column(primary_key=True)
    subject: Mapped[str] = mapped_column(String(80), index=True)  # "user:12" or "device:<sha>"
    kind: Mapped[str] = mapped_column(String(20))
    day: Mapped[date] = mapped_column(Date, index=True)
    provider: Mapped[str] = mapped_column(String(20), default="offline")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Subscription(TimestampMixin, Base):
    __tablename__ = "subscriptions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    platform: Mapped[str] = mapped_column(String(20), default="google_play")
    product_id: Mapped[str] = mapped_column(String(100))
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    status: Mapped[str] = mapped_column(String(30))
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    auto_renewing: Mapped[bool] = mapped_column(Boolean, default=False)
    raw: Mapped[dict] = mapped_column(JSON, default=dict)


class MediaAsset(TimestampMixin, Base):
    """Files uploaded through the admin dashboard."""

    __tablename__ = "media_assets"

    id: Mapped[int] = mapped_column(primary_key=True)
    key: Mapped[str] = mapped_column(String(300), unique=True)
    url: Mapped[str] = mapped_column(String(600))
    content_type: Mapped[str] = mapped_column(String(100))
    size: Mapped[int] = mapped_column(Integer)
    uploaded_by: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    def __str__(self) -> str:
        return self.key
