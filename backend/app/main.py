import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from sqlalchemy import text

from app.admin.setup import mount_admin
from app.config import get_settings
from app.db import engine
from app.deps import limiter
from app.routers import ai_routes, astro, auth, content, home, me
from app.services import ai, panchang

settings = get_settings()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
PAGES = Jinja2Templates(directory=str(Path(__file__).parent / "pages"))


@asynccontextmanager
async def lifespan(_: FastAPI):
    panchang.ensure_ephemeris()
    yield


app = FastAPI(
    title="Devalay API",
    version="1.0.0",
    description="Backend for the Devalay devotional app: content, Panchang, festivals, Rashifal and AI helpers.",
    lifespan=lifespan,
    docs_url=None if settings.is_production else "/docs",
    redoc_url=None,
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(GZipMiddleware, minimum_size=1024)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type", "X-Device-Id"],
)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Permissions-Policy", "geolocation=(), camera=(), microphone=()")
    if settings.is_production:
        response.headers.setdefault("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
    return response


@app.exception_handler(Exception)
async def unhandled(request: Request, exc: Exception):
    logging.getLogger("app").exception("Unhandled error on %s", request.url.path)
    return JSONResponse({"detail": "Something went wrong. Please try again."}, status_code=500)


API = "/api/v1"
for module in (auth, content, astro, home, ai_routes, me):
    app.include_router(module.router, prefix=API)


@app.api_route(f"{API}/health", methods=["GET", "HEAD"], tags=["meta"])
def health():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok", "ai": ai.ai_enabled(), "version": app.version}


VIDEO_CHANNELS = [
    {"id": "UCS2Y83GD-fc7qqgNW5uj41g", "name": "SVBC TTD", "name_te": "ఎస్వీబీసీ (టీటీడీ)", "name_hi": "SVBC TTD"},
]


@app.get(f"{API}/config", tags=["meta"])
def public_config():
    """Feature flags the app reads at start-up."""
    return {
        "ai_enabled": ai.ai_enabled(),
        "free_ai_daily_limit": settings.ai_free_daily_limit,
        "min_supported_build": 1,
        "privacy_url": f"{settings.public_base_url}/privacy",
        "terms_url": f"{settings.public_base_url}/terms",
        # Official devotional YouTube channels for the Bhakti videos feed (played in YouTube's own
        # embedded player). Edit here to add channels; the app reads the list at start-up.
        "video_channels": VIDEO_CHANNELS,
    }


@app.get("/", include_in_schema=False, response_class=HTMLResponse)
def landing(request: Request):
    return PAGES.TemplateResponse(request, "landing.html", {"settings": settings})


@app.get("/privacy", include_in_schema=False, response_class=HTMLResponse)
def privacy(request: Request):
    return PAGES.TemplateResponse(request, "privacy.html", {"settings": settings})


@app.get("/terms", include_in_schema=False, response_class=HTMLResponse)
def terms(request: Request):
    return PAGES.TemplateResponse(request, "terms.html", {"settings": settings})


if settings.storage_backend == "local":
    Path(settings.media_dir).mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=settings.media_dir), name="media")

mount_admin(app)
