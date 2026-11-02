# 🛕 Devalay · देवालय

A calm, privacy-first Hindu devotional app for Android: aarti, bhajans and mantras, the full Bhagavad Gita,
scriptures, an astronomically computed Panchang and festival calendar, a virtual Mandir, japa mala, Rashifal,
wallpapers, ringtones, an AI status maker and "Ask the Gita".

Inspired by apps like Sanatan, Devalay is an **original** app with its own name, design, code and legally
sourced content. Core devotion is free forever; an optional Premium tier is billed transparently through Google
Play with no AutoPay mandates.

| | |
|---|---|
| **Android app** | Flutter 3.44 · Riverpod · go_router · just_audio (background playback) · Hive (offline) |
| **Backend** | Python 3.13 · FastAPI · SQLAlchemy 2 · PostgreSQL 17 · Alembic |
| **Admin** | SQLAdmin dashboard at `/admin` (content, media upload, users, stats) |
| **Panchang** | Skyfield + NASA JPL DE421 ephemeris, Lahiri ayanamsa |
| **Media** | Cloudflare R2 (S3 API) or local disk |
| **AI (optional)** | Claude via the Anthropic SDK, with free offline fallbacks |
| **Notifications** | On-device scheduled notifications (no Firebase, no push server) |

## Features

- **Home**: greeting, deity of the day, today's Panchang, festival countdown, Gita verse of the day, bhakti picks.
- **Listen**: aarti, mantra, bhajan, dhun and meditation tracks; deity filters; lock-screen controls; queue,
  repeat, sleep timer; offline downloads; lyrics link.
- **Virtual Mandir**: swipe between deities, light a flickering diya, shower flowers, ring the bells, blow the
  shankh, perform aarti with a circling thali, daily darshan streak. Works offline with bundled sounds.
- **Read**: Bhagavad Gita (701 verses: Sanskrit, IAST, English) with a swipe reader and resume; Hanuman
  Chalisa, aartis, stotras and 26 mantras with transliteration and meanings; Ramayan (493 cantos, incl. Sundar
  Kand), Mahabharata, Upanishads, *The Song Celestial*.
- **Panchang & calendar**: tithi, nakshatra, yoga, karana with end times; sunrise and sunset; Rahu Kaal,
  Yamaganda, Gulika, Abhijit and Brahma muhurta; month calendar with Ekadashi, Purnima and Amavasya markers;
  37 major festivals computed for any year from 1902 to 2049 for 28 cities; reminders.
- **Rashifal**: daily reading for 12 rashis from the Moon's actual transit (Chandra gochar), Hindi and English.
- **Japa mala**: 108-bead counter with haptics, rounds, and daily and lifetime totals.
- **AI status maker**: devotional status lines for any deity and occasion, composed over sacred art and exported
  as a 1080×1920 image to share or save.
- **Ask the Gita**: answers grounded in retrieved verses (BM25 retrieval, optional Claude synthesis).
- **Wallpapers** (set home or lock screen, save, share), **ringtones** (set as ringtone, notification or alarm),
  **classic films** (Phalke's public-domain mythologicals).
- **Search**, **favourites** (offline-first, synced when signed in), **downloads**, Hindi/English, light/dark.
- **Accounts are optional**: email and password, rotating refresh tokens, password reset, in-app account deletion.

See [docs/FEATURES.md](docs/FEATURES.md) for the full parity matrix against the reference app, including what is
intentionally not built.

## Repository layout

```
backend/   FastAPI API, admin dashboard, Panchang engine, seed content, tests, Dockerfile
app/       Flutter Android app (lib/core, lib/features, lib/widgets, test/)
docs/      Architecture, deployment, feature matrix, store assets
.github/   CI: backend (Postgres + SQLite tests, Docker smoke test) and app (analyze, test, release build)
```

## Quick start (local)

Backend (Python 3.12+):

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m app.cli init-db && .venv/bin/python -m app.cli seed
DEVALAY_PUBLIC_BASE_URL=http://10.0.2.2:8000 .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Open http://localhost:8000/docs for the API and http://localhost:8000/admin for the dashboard. Create an admin
(the password is read from stdin):

```bash
cd backend && .venv/bin/python -m app.cli create-admin you@example.com
```

Or run Postgres and the API together with `docker compose up --build`.

Android app (Flutter 3.44+, Android SDK 36):

```bash
cd app && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` is your computer as seen from the Android emulator. For a phone on the same Wi-Fi, use your
computer's LAN address (HTTPS is required for any non-local host).

## Tests

```bash
cd backend && .venv/bin/pytest -q && .venv/bin/ruff check .
```

```bash
cd app && flutter analyze && flutter test
```

The backend suite (48 tests) covers auth and token rotation, content APIs, admin access, AI quotas and fallbacks,
premium verification, and the Panchang engine, which is checked against 33 published festival dates for 2025 and 2026.
CI runs it on PostgreSQL and SQLite.

## Configuration

All backend settings are environment variables prefixed `DEVALAY_`; see
[backend/.env.example](backend/.env.example). Nothing secret is committed. Without optional keys the app still
works fully: AI uses offline generators, Play billing reports "not configured", and email reset codes are logged in
development.

## Deployment

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md): Render (blueprint included) or any Docker host, Neon PostgreSQL,
Cloudflare R2 for media, and Play Console steps.

## Licences

Code: MIT. Content: public domain, CC0 or CC BY/BY-SA, credited per item; see
[CONTENT_LICENSES.md](CONTENT_LICENSES.md).
