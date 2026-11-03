<p align="center">
  <img src="docs/store/banner.png" alt="Devalay: aarti, Gita, Panchang and a virtual Mandir for Android" width="100%">
</p>

<h1 align="center">🛕 Devalay · देवालय</h1>

<p align="center">
  <b>A free, open-source, ad-free Hindu devotional app for Android.</b><br>
  Aarti and bhajans · the full Bhagavad Gita · an accurate Panchang · a virtual Mandir · japa mala · Rashifal
</p>

<p align="center">
  <a href="https://github.com/ChandraChaan/devalay/releases/latest/download/devalay.apk"><img alt="Download APK" src="https://img.shields.io/badge/Download-APK-ff7a00?style=for-the-badge&logo=android&logoColor=white"></a>
  <a href="https://chandrachaan.github.io/devalay"><img alt="Website" src="https://img.shields.io/badge/Website-devalay-6b2fbf?style=for-the-badge"></a>
</p>

<p align="center">
  <a href="https://github.com/ChandraChaan/devalay/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/ChandraChaan/devalay?label=release"></a>
  <a href="https://github.com/ChandraChaan/devalay/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/ChandraChaan/devalay/total"></a>
  <a href="https://github.com/ChandraChaan/devalay/actions/workflows/app.yml"><img alt="App CI" src="https://github.com/ChandraChaan/devalay/actions/workflows/app.yml/badge.svg"></a>
  <a href="https://github.com/ChandraChaan/devalay/actions/workflows/backend.yml"><img alt="Backend CI" src="https://github.com/ChandraChaan/devalay/actions/workflows/backend.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="MIT licence" src="https://img.shields.io/badge/licence-MIT-green"></a>
  <a href="https://github.com/ChandraChaan/devalay/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/ChandraChaan/devalay?style=social"></a>
</p>

Devalay brings the temple to your phone: listen to aarti, mantras and bhajans with lock-screen controls, read all
701 verses of the Gita in Sanskrit, IAST and English, check today's tithi, nakshatra and Rahu Kaal for your city,
light a diya in the virtual Mandir, count japa, and make a devotional status to share. It is inspired by apps like
Sanatan, but Devalay is an **original** app with its own name, design, code and legally sourced content.

- **No ads, no trackers, no sign-up.** It works from the first launch.
- **No server bill.** The public APK reads a pre-rendered API on GitHub Pages that refreshes daily.
- **Legal content only.** Every recording, painting and text is public domain or CC-licensed; see
  [CONTENT_LICENSES.md](CONTENT_LICENSES.md).

## Screenshots

| Home | Mandir | Player | Gita |
|:-:|:-:|:-:|:-:|
| <img src="docs/screenshots/02-home.jpg" width="200"> | <img src="docs/screenshots/03-mandir.jpg" width="200"> | <img src="docs/screenshots/04-player.jpg" width="200"> | <img src="docs/screenshots/05-gita.jpg" width="200"> |
| **Panchang** | **Calendar** | **Rashifal** | **Wallpapers** |
| <img src="docs/screenshots/06-panchang.jpg" width="200"> | <img src="docs/screenshots/07-calendar.jpg" width="200"> | <img src="docs/screenshots/08-rashifal.jpg" width="200"> | <img src="docs/screenshots/09-wallpaper.jpg" width="200"> |
| **Status maker** | **Ask the Gita** | **Japa mala** | **Welcome** |
| <img src="docs/screenshots/10-status.jpg" width="200"> | <img src="docs/screenshots/11-ask-gita.jpg" width="200"> | <img src="docs/screenshots/12-japa.jpg" width="200"> | <img src="docs/screenshots/01-welcome.jpg" width="200"> |

## Install

1. Open **[devalay.apk](https://github.com/ChandraChaan/devalay/releases/latest/download/devalay.apk)** on your
   Android phone (Android 7.0 or newer).
2. Allow your browser to install apps when Android asks, then tap **Install**.
3. Updates: download the newer APK from [Releases](https://github.com/ChandraChaan/devalay/releases). It installs
   over the old one and keeps your favourites and japa counts.

Each release lists SHA-256 checksums. `devalay-arm64-v8a.apk` is a smaller download for most phones made since 2017.

## Built with

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

In the public APK, sign-in, sync and Premium are hidden because they need the full server; everything else works.
Run your own backend (below) to enable them.

## Repository layout

```
backend/   FastAPI API, admin dashboard, Panchang engine, seed content, tests, Dockerfile
app/       Flutter Android app (lib/core, lib/features, lib/widgets, test/)
docs/      Architecture, deployment, feature matrix, store assets
site/      Landing page published to GitHub Pages with the static API
.github/   CI: backend tests, app analyze/test/build, daily Pages export, tag-triggered APK releases
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

## Deployment and releases

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md):

- the serverless public build (GitHub Pages);
- cutting a release (`git tag v1.1.0 && git push --tags`);
- Render (blueprint included) or any Docker host, with Neon PostgreSQL and Cloudflare R2 for media;
- the Play Console steps.

Release history: [CHANGELOG.md](CHANGELOG.md).

## Contributing

Contributions are welcome. You could:

- add public-domain chalisas, aartis and stotras;
- translate the UI into more Indian languages;
- add cities to the Panchang;
- pick up an item from the [milestones](https://github.com/ChandraChaan/devalay/milestones).

Please open an issue first for larger changes. Any new content must be public domain or under an open licence, with
its source recorded in [CONTENT_LICENSES.md](CONTENT_LICENSES.md).

If Devalay brings you a moment of peace, **please ⭐ star the repo** and share the APK with family. Both help others
find it.

## Licences

Code: MIT. Content: public domain, CC0 or CC BY/BY-SA, credited per item; see
[CONTENT_LICENSES.md](CONTENT_LICENSES.md).
