# Architecture

```
 Android app (Flutter)                     Backend (FastAPI, one container)                 Services
 ┌──────────────────────────┐   HTTPS      ┌────────────────────────────────┐              ┌──────────────────┐
 │ Riverpod providers       │ ───────────▶ │ /api/v1  REST (JSON)           │ ───────────▶ │ PostgreSQL (Neon)│
 │ Api client + Hive cache  │ ◀─────────── │ /admin   SQLAdmin dashboard    │              └──────────────────┘
 │ just_audio + background  │              │ /privacy /terms pages          │ ───────────▶ Cloudflare R2 (media)
 │ local notifications      │              │ Panchang engine (Skyfield)     │ ───────────▶ Anthropic API (optional)
 │ Kotlin bridge: wallpaper,│              │ Rashifal rules, BM25 Gita index│ ───────────▶ Google Play Developer API
 │ ringtone, gallery        │              └────────────────────────────────┘              (subscription checks)
 └──────────────────────────┘
```

## Backend (`backend/app`)

- `main.py`: app factory, security headers, CORS, GZip, rate limiting (slowapi), static media, admin mount.
- `routers/`: `auth`, `content` (tracks, texts, Gita, books, wallpapers, videos, search, banners), `astro`
  (Panchang, festivals, Rashifal), `home` (one-request home feed), `ai_routes`, `me` (favourites, premium).
- `services/panchang.py`: Sun and Moon apparent longitudes from DE421, Lahiri ayanamsa, discrete root finding
  for limb end times, sunrise and sunset, amanta months with adhika detection, sankrantis.
- `services/festivals.py`: rules of the form (amanta month, tithi, observance time: sunrise, madhyahna, aparahna,
  pradosh, nishita or sunset), handling vriddhi and kshaya tithis. Validated against 2025 and 2026 published dates.
- `services/rashifal.py`: Chandra-gochar house from each rashi; deterministic bilingual text.
- `services/ai.py`: Claude via the official SDK (structured JSON output, low effort, server-side refusal fallback).
  Every call has an offline fallback; per-identity daily quotas (account, or HMAC of a device id).
- `services/play_billing.py`: Play `subscriptionsv2` verification with a service account; purchase tokens are
  stored only as HMACs and bound to one account.
- `admin/`: SQLAdmin views. Editors manage content; only admins see users and subscriptions. Session cookies are
  SameSite=Strict, HTTPS-only in production, and expire.
- `seed/`: idempotent loader; `scripts/` rebuild the seed from upstream sources (`build_gita.py`,
  `fetch_commons.py`, `build_books.py`, `generate_audio.py`) and mirror media to R2 (`mirror_media.py`).

### Security

Argon2 password hashes; 30-minute HS256 access tokens; opaque refresh tokens stored as SHA-256 hashes with
rotation and reuse detection (reuse revokes the token family); constant-time-ish login for unknown emails;
non-enumerating password reset with attempt limits; rate limits on auth and AI; Pydantic validation and LIKE
escaping on all inputs; upload type allow-list and path containment; no secrets in the repo; production refuses
to start with the default secret; API docs disabled in production; HSTS, nosniff, frame-deny, no-referrer.

### Static mode (public APK)

The public build has no server. Built with `--dart-define=STATIC_API=true`, it works like this:

- **Reading content.** `Api.get` maps each request to a JSON file on GitHub Pages, so `/panchang?lat=…&day=…`
  becomes `panchang/city-delhi~day-….json`. `backend/scripts/export_static.py` pre-renders those files daily from
  the same FastAPI routes, so both modes share one code path for content.
- **Running on device.** `core/static_api.dart` does three things on the phone:
  - Search, over an exported index.
  - Ask the Gita, with the same BM25 ranking and offline answer as `services/gita_search.py`.
  - The status maker, from the exported templates.
- **Not available.** Writes such as auth, sync and Premium throw a friendly "not available in this build" error,
  and the UI hides them. Play and download counters are skipped.

### Cost profile

One small container (about 150 MB RAM) plus serverless Postgres free tier plus R2 (zero egress fees). Panchang and
festival computations are cached in memory and via HTTP `Cache-Control`; Rashifal is computed once per day and
language and stored. AI is optional and quota-limited; `DEVALAY_ANTHROPIC_MODEL=claude-haiku-5-5` is the
lowest-cost option.

## App (`app/lib`)

- `core/`: `api.dart` (Dio, auth refresh, offline JSON cache), `auth.dart`, `audio.dart` (single queue player),
  `downloads.dart`, `favorites.dart`, `notifications.dart`, `native.dart` (MethodChannel), `providers.dart`,
  `storage.dart` (Hive prefs), `i18n.dart`, `theme.dart`, `location.dart` (city list instead of GPS).
- `features/`: one file per screen group. `widgets/`: shared UI (mandala painter, mini player, track tile).
- Android: `MainActivity.kt` extends `AudioServiceActivity` and implements wallpaper, ringtone and gallery calls;
  network security config allows cleartext only to local development hosts; backups exclude app data.

### Privacy by design

No analytics SDKs, ads or advertising IDs; no location permission (city picker); tokens in Android Keystore-backed
secure storage; favourites, downloads, japa and Mandir data stay on device unless the user signs in.
