"""Admin dashboard (SQLAdmin) mounted at /admin.

Only users with role "admin" or "editor" can sign in. Editors manage content;
user accounts and subscriptions are visible to admins only.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from pathlib import Path

from fastapi import FastAPI
from sqladmin import Admin, BaseView, ModelView, expose
from sqladmin.authentication import AuthenticationBackend
from sqladmin.filters import AllUniqueStringValuesFilter, BooleanFilter
from sqlalchemy import func, select
from starlette.requests import Request
from starlette.responses import RedirectResponse

from app.config import get_settings
from app.db import SessionLocal, engine
from app.models import (
    AIUsage,
    Banner,
    Book,
    BookChapter,
    Deity,
    Favorite,
    FestivalOverride,
    GitaChapter,
    GitaVerse,
    MediaAsset,
    RashifalEntry,
    Subscription,
    TextItem,
    Track,
    User,
    Video,
    Wallpaper,
)
from app.security import verify_password
from app.services import gita_search, storage

TEMPLATES = str(Path(__file__).parent / "templates")


class AdminAuth(AuthenticationBackend):
    async def login(self, request: Request) -> bool:
        form = await request.form()
        email = str(form.get("username", "")).strip().lower()
        password = str(form.get("password", ""))
        with SessionLocal() as db:
            user = db.scalar(select(User).where(User.email == email))
            ok = verify_password(password, user.password_hash if user else None)
            if not ok or not user.is_active or user.role not in ("admin", "editor"):
                return False
            request.session.update({
                "admin_uid": user.id, "admin_role": user.role,
                "admin_exp": (datetime.now(UTC) + timedelta(minutes=get_settings().admin_session_minutes)).timestamp(),
            })
        return True

    async def logout(self, request: Request) -> bool:
        request.session.clear()
        return True

    async def authenticate(self, request: Request) -> bool:
        uid = request.session.get("admin_uid")
        if not uid or request.session.get("admin_exp", 0) < datetime.now(UTC).timestamp():
            request.session.clear()
            return False
        with SessionLocal() as db:
            user = db.get(User, uid)
            if not user or not user.is_active or user.role not in ("admin", "editor"):
                request.session.clear()
                return False
        return True


def _is_admin(request: Request) -> bool:
    return request.session.get("admin_role") == "admin"


class ContentView(ModelView):
    page_size = 50
    can_export = True


class AdminOnlyView(ModelView):
    def is_accessible(self, request: Request) -> bool:
        return _is_admin(request)

    def is_visible(self, request: Request) -> bool:
        return _is_admin(request)


class DeityAdmin(ContentView, model=Deity):
    icon = "fa-solid fa-om"
    column_list = [Deity.id, Deity.slug, Deity.name, Deity.name_hi, Deity.weekday, Deity.sort]
    column_searchable_list = [Deity.name, Deity.slug]


class TrackAdmin(ContentView, model=Track):
    icon = "fa-solid fa-music"
    column_list = [Track.id, Track.title, Track.kind, Track.deity, Track.license, Track.published,
                   Track.is_premium, Track.play_count]
    column_searchable_list = [Track.title, Track.title_hi, Track.slug]
    column_filters = [AllUniqueStringValuesFilter(Track.kind), BooleanFilter(Track.published)]
    column_sortable_list = [Track.id, Track.title, Track.play_count]
    form_excluded_columns = [Track.created_at, Track.updated_at, Track.play_count]


class TextAdmin(ContentView, model=TextItem):
    name, name_plural, icon = "Text", "Texts (aarti, chalisa, mantra)", "fa-solid fa-scroll"
    column_list = [TextItem.id, TextItem.title, TextItem.kind, TextItem.deity, TextItem.published]
    column_searchable_list = [TextItem.title, TextItem.title_hi, TextItem.slug]
    column_filters = [AllUniqueStringValuesFilter(TextItem.kind), BooleanFilter(TextItem.published)]
    form_excluded_columns = [TextItem.created_at, TextItem.updated_at]


class BookAdmin(ContentView, model=Book):
    icon = "fa-solid fa-book"
    column_list = [Book.id, Book.title, Book.author, Book.language, Book.license, Book.published]
    column_searchable_list = [Book.title, Book.author]
    form_excluded_columns = [Book.created_at, Book.updated_at, Book.chapters]


class ChapterAdmin(ContentView, model=BookChapter):
    name_plural, icon = "Book chapters", "fa-solid fa-file-lines"
    column_list = [BookChapter.id, BookChapter.book, BookChapter.number, BookChapter.title]
    column_searchable_list = [BookChapter.title]


class GitaChapterAdmin(ContentView, model=GitaChapter):
    name_plural, icon = "Gita chapters", "fa-solid fa-dharmachakra"
    column_list = [GitaChapter.number, GitaChapter.name_translit, GitaChapter.name_en, GitaChapter.verse_count]

    async def after_model_change(self, data, model, is_created, request) -> None:
        gita_search.reset_index()


class GitaVerseAdmin(ContentView, model=GitaVerse):
    name_plural, icon = "Gita verses", "fa-solid fa-feather"
    column_list = [GitaVerse.chapter, GitaVerse.verse, GitaVerse.translation_author]
    column_searchable_list = [GitaVerse.translation_en]
    column_filters = [AllUniqueStringValuesFilter(GitaVerse.chapter)]

    async def after_model_change(self, data, model, is_created, request) -> None:
        gita_search.reset_index()


class WallpaperAdmin(ContentView, model=Wallpaper):
    icon = "fa-solid fa-image"
    column_list = [Wallpaper.id, Wallpaper.title, Wallpaper.deity, Wallpaper.license, Wallpaper.published,
                   Wallpaper.download_count]
    column_searchable_list = [Wallpaper.title]
    column_formatters = {Wallpaper.title: lambda m, a: m.title}
    form_excluded_columns = [Wallpaper.created_at, Wallpaper.updated_at, Wallpaper.download_count]


class VideoAdmin(ContentView, model=Video):
    icon = "fa-solid fa-film"
    column_list = [Video.id, Video.title, Video.year, Video.license, Video.published]
    form_excluded_columns = [Video.created_at, Video.updated_at]


class BannerAdmin(ContentView, model=Banner):
    icon = "fa-solid fa-bullhorn"
    column_list = [Banner.id, Banner.title, Banner.starts_on, Banner.ends_on, Banner.published, Banner.sort]
    form_excluded_columns = [Banner.created_at, Banner.updated_at]


class FestivalAdmin(ContentView, model=FestivalOverride):
    name, name_plural, icon = "Festival override", "Festival overrides", "fa-solid fa-calendar-days"
    column_list = [FestivalOverride.slug, FestivalOverride.year, FestivalOverride.date, FestivalOverride.name,
                   FestivalOverride.hidden]
    form_excluded_columns = [FestivalOverride.created_at, FestivalOverride.updated_at]


class RashifalAdmin(ContentView, model=RashifalEntry):
    name_plural, icon = "Rashifal cache", "fa-solid fa-star"
    column_list = [RashifalEntry.day, RashifalEntry.rashi, RashifalEntry.language, RashifalEntry.source]
    column_filters = [AllUniqueStringValuesFilter(RashifalEntry.language),
                      AllUniqueStringValuesFilter(RashifalEntry.source)]
    can_create = False


class MediaAdmin(ContentView, model=MediaAsset):
    name_plural, icon = "Media library", "fa-solid fa-photo-film"
    column_list = [MediaAsset.id, MediaAsset.key, MediaAsset.content_type, MediaAsset.size, MediaAsset.url,
                   MediaAsset.created_at]
    can_create = can_edit = False

    async def after_model_delete(self, model, request) -> None:
        storage.delete(model.key)


class UserAdmin(AdminOnlyView, model=User):
    icon = "fa-solid fa-users"
    column_list = [User.id, User.email, User.display_name, User.role, User.is_active, User.premium_until,
                   User.created_at, User.last_login_at]
    column_searchable_list = [User.email, User.display_name]
    column_filters = [AllUniqueStringValuesFilter(User.role), BooleanFilter(User.is_active)]
    form_columns = [User.display_name, User.role, User.is_active, User.premium_until]
    column_details_exclude_list = [User.password_hash]
    can_create = False


class SubscriptionAdmin(AdminOnlyView, model=Subscription):
    icon = "fa-solid fa-crown"
    column_list = [Subscription.id, Subscription.user_id, Subscription.product_id, Subscription.status,
                   Subscription.expires_at, Subscription.auto_renewing]
    column_filters = [AllUniqueStringValuesFilter(Subscription.status)]
    can_create = can_edit = False


class DashboardView(BaseView):
    name, icon, identity = "Dashboard", "fa-solid fa-gauge", "dashboard"

    @expose("/dashboard", methods=["GET"])
    async def dashboard(self, request: Request):
        today = date.today()
        with SessionLocal() as db:
            def count(model, *where):
                return db.scalar(select(func.count()).select_from(model).where(*where)) or 0

            stats = {
                "users": count(User),
                "new_users_7d": count(User, User.created_at >= datetime.now(UTC) - timedelta(days=7)),
                "premium": count(User, User.premium_until > datetime.now(UTC)),
                "tracks": count(Track), "texts": count(TextItem), "books": count(Book),
                "verses": count(GitaVerse), "wallpapers": count(Wallpaper), "videos": count(Video),
                "favorites": count(Favorite),
                "ai_today": count(AIUsage, AIUsage.day == today),
                "ai_claude_today": count(AIUsage, AIUsage.day == today, AIUsage.provider == "claude"),
            }
            top_tracks = db.execute(select(Track.title, Track.play_count).order_by(Track.play_count.desc())
                                    .limit(8)).all()
            top_walls = db.execute(select(Wallpaper.title, Wallpaper.download_count)
                                   .order_by(Wallpaper.download_count.desc()).limit(8)).all()
            ai_days = db.execute(select(AIUsage.day, func.count()).where(AIUsage.day >= today - timedelta(days=13))
                                 .group_by(AIUsage.day).order_by(AIUsage.day)).all()
        s = get_settings()
        return await self.templates.TemplateResponse(request, "dashboard.html", {
            "stats": stats, "top_tracks": top_tracks, "top_walls": top_walls, "ai_days": ai_days,
            "config": {"storage": s.storage_backend, "ai": bool(s.anthropic_api_key), "model": s.anthropic_model,
                       "billing": bool(s.google_play_service_account_json), "smtp": bool(s.smtp_host),
                       "env": s.env},
        })


class UploadView(BaseView):
    name, icon, identity = "Upload media", "fa-solid fa-cloud-arrow-up", "upload"

    @expose("/upload", methods=["GET", "POST"])
    async def upload(self, request: Request):
        message, url, error = None, None, None
        if request.method == "POST":
            form = await request.form()
            file = form.get("file")
            folder = str(form.get("folder", "misc"))
            if not getattr(file, "filename", None):
                error = "Choose a file to upload."
            else:
                try:
                    content_type = storage.guess_type(file.filename, file.content_type)
                    data = await file.read()
                    key = storage.safe_key(folder, file.filename)
                    url = storage.put(key, data, content_type)
                    with SessionLocal() as db:
                        db.add(MediaAsset(key=key, url=url, content_type=content_type, size=len(data),
                                          uploaded_by=request.session.get("admin_uid")))
                        db.commit()
                    message = "Uploaded. Paste this URL into a track, wallpaper or video."
                except storage.StorageError as exc:
                    error = str(exc)
        return await self.templates.TemplateResponse(request, "upload.html", {
            "message": message, "url": url, "error": error,
            "folders": ["audio", "ringtones", "wallpapers", "thumbnails", "videos", "covers", "misc"],
        })


def mount_admin(app: FastAPI) -> Admin:
    s = get_settings()
    auth = AdminAuth(secret_key=s.secret_key, https_only=s.is_production, same_site="strict",
                     max_age=s.admin_session_minutes * 60)
    admin = Admin(app, engine, title="Devalay Admin", authentication_backend=auth, templates_dir=TEMPLATES,
                  base_url="/admin")
    admin.add_view(DashboardView)
    admin.add_view(UploadView)
    for view in (TrackAdmin, TextAdmin, GitaChapterAdmin, GitaVerseAdmin, BookAdmin, ChapterAdmin, WallpaperAdmin,
                 VideoAdmin, DeityAdmin, BannerAdmin, FestivalAdmin, RashifalAdmin, MediaAdmin, UserAdmin,
                 SubscriptionAdmin):
        admin.add_view(view)

    app.state.admin_site = admin

    @app.get("/admin/", include_in_schema=False)
    async def _admin_home():
        return RedirectResponse("/admin/dashboard")

    return admin
