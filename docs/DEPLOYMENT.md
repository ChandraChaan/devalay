# Deployment

There are two ways to run Devalay:

- **The public build is live today at no cost.** GitHub Pages hosts a pre-rendered, read-only copy of the API, and
  the APK on the Releases page reads it. Sections 0 and 0.1 cover it.
- **The full server adds accounts, sync, Premium and Claude-written AI.** Sections 1 to 6 cover it. Every step there
  needs your own accounts. Expect about $0–7 a month at launch: Neon free tier, Render Starter or a Fly.io shared
  CPU, and the R2 free tier of 10 GB with zero egress fees.

## 0. Public build: GitHub Pages ("static mode")

`.github/workflows/pages.yml` runs `backend/scripts/export_static.py`.

- **What it does.**
  - Seeds a throwaway SQLite database.
  - Calls every read-only endpoint through FastAPI's test client.
  - Writes about 2,800 JSON files (about 23 MB) to `api/v1/...`, alongside the landing page in `site/`, the seed
    media, and the privacy and terms pages.
- **When it runs.** On each push that touches the backend or site, and daily at 00:10 IST.
- **What it covers.** Date-dependent data covers a rolling window:
  - Panchang: −7 to +45 days.
  - Home feed and Rashifal: −2 to +10 days.
  - Month calendars: −1 to +3 months.
  - Festivals: this year and next.
  - All 28 cities in `app/lib/core/location.dart`.
- **How the app reads it.** Files are named by path plus sorted query (`panchang/city-delhi~day-2026-11-03.json`).
  `backend/scripts/export_static.py` and `app/lib/core/static_api.dart` must agree on the naming, which
  `app/test/static_api_test.dart` checks.
- **What runs on the phone instead.** Search, Ask the Gita and the status maker run on device. Accounts, sync and
  Premium are hidden.

Build it locally:

```bash
cd backend && .venv/bin/python scripts/export_static.py ../_site https://chandrachaan.github.io/devalay
cd ../app && flutter build apk --release --dart-define=STATIC_API=true \
  --dart-define=API_BASE_URL=https://chandrachaan.github.io/devalay
```

GitHub turns off scheduled workflows after 60 days without repository activity. If the Panchang shows "only
available for dates near today", re-enable **Website and static API** in the Actions tab, or push any commit.

## 0.1 Cutting a release

1. Add a `## vX.Y.Z — date` section at the top of `CHANGELOG.md` and bump `version:` in `app/pubspec.yaml`.
2. Commit, then run `git tag -a vX.Y.Z -m "Devalay vX.Y.Z" && git push origin main --tags`.
3. `.github/workflows/release.yml` then:
   - Runs the tests.
   - Builds the static-mode APKs: `devalay.apk` (universal) and the per-ABI APKs, with versionCode
     `major·10000 + minor·100 + patch`.
   - Checks they are signed with the Devalay key.
   - Publishes the release with that changelog section and `SHA256SUMS`.
4. To rebuild an existing tag, run the workflow from the Actions tab with the tag as input.

The release key lives outside git:

- `app/android/app/upload-keystore.jks` and `app/android/key.properties` locally (both git-ignored).
- A backup in `~/.devalay-keys/`.
- The `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEY_PROPERTIES` repository secrets.

`key.properties` has `storeFile=upload-keystore.jks`. **Keep an offline backup of the keystore and its password.**
Android only installs an update when it is signed with the same key, so losing the key means users have to
uninstall the app to update it.

## 1. Database: Neon (or any PostgreSQL 14+)

1. Create a project at neon.tech and copy the connection string.
2. Convert it to SQLAlchemy form:
   `postgresql+psycopg://USER:PASSWORD@HOST/DB?sslmode=require`

## 2. Media: Cloudflare R2

1. Create a bucket (for example `devalay-media`), enable public access through a custom domain (recommended) or
   r2.dev.
2. Create an API token with Object Read & Write for that bucket.
3. Set `DEVALAY_STORAGE_BACKEND=r2`, `DEVALAY_R2_ACCOUNT_ID`, `DEVALAY_R2_ACCESS_KEY_ID`,
   `DEVALAY_R2_SECRET_ACCESS_KEY`, `DEVALAY_R2_BUCKET` and `DEVALAY_R2_PUBLIC_BASE_URL`.
4. After the first deploy, copy the seed media off Wikimedia (recommended for production traffic):
   `python scripts/mirror_media.py`

## 3. API: Render (blueprint) or any Docker host

- **Render**: New → Blueprint → select this repo (`render.yaml`). Fill in the `sync: false` variables. The
  container runs `alembic upgrade head`, seeds content (`DEVALAY_SEED_ON_START=1`; set it to `0` after the first
  boot if you prefer) and starts uvicorn.
- **Fly.io / Railway / a VM**: build `backend/Dockerfile` and pass the same environment variables. Health check:
  `GET /api/v1/health`.

Required: `DEVALAY_ENV=production`, `DEVALAY_DATABASE_URL`, `DEVALAY_SECRET_KEY` (48+ random bytes),
`DEVALAY_PUBLIC_BASE_URL` (for example `https://api.devalay.example.com`) and `DEVALAY_CONTACT_EMAIL` (shown in
the privacy policy).

Then create your admin account (the password is read from stdin):

```bash
docker exec -i <container> python -m app.cli create-admin you@example.com
```

## 4. Optional services

| Feature | Variable(s) | Without it |
|---|---|---|
| Claude AI (status, Gita answers, Rashifal polish) | `DEVALAY_ANTHROPIC_API_KEY`, optional `DEVALAY_ANTHROPIC_MODEL` (default `claude-opus-5-5`; `claude-haiku-5-5` is the cheapest) | Offline generators |
| Password reset email | `DEVALAY_SMTP_*` (for example Resend, Brevo or SES SMTP) | Reset codes are not delivered in production |
| Premium verification | `DEVALAY_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (raw or base64) | `/premium/verify` returns 503 |

## 5. Android release

1. Create an upload keystore and do not commit it:
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Create `app/android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword` (it is
   git-ignored). For CI, add the GitHub secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEY_PROPERTIES`, and the
   repository variable `API_BASE_URL`.
3. Build: `flutter build appbundle --release --dart-define=API_BASE_URL=https://api.devalay.example.com`
4. Play Console: create the app `com.chandrachaan.devalay`; upload the AAB; use `docs/store/icon-512.png`;
   privacy policy URL `https://<api-host>/privacy`; Data safety: email (optional account), app activity (none
   shared), no location, no ads.
5. Subscriptions: create `devalay_premium_monthly` and `devalay_premium_yearly` (base plans with auto-renew), then
   link a Google Cloud service account with "View financial data" and "Manage orders" permissions in Play Console
   → Users & permissions, and set its JSON key as `DEVALAY_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

## 6. After launch

- Check festival dates for the coming year in the admin and add overrides for regional practice.
- Add licensed recordings and more public-domain texts through `/admin/upload` and the content views.
