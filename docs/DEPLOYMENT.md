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
  `app/test/static_api_test.dart` checks. Save every file through `static_file()`, never a hand-written path.
- **What runs on the phone instead.** Search, Ask the Gita and the status maker run on device. Accounts, sync and
  Premium are hidden.

Build it locally:

```bash
cd backend && .venv/bin/python scripts/export_static.py ../_site https://chandrachaan.github.io/devalay
cd ../app && flutter build apk --release --split-debug-info=build/symbols --dart-define=STATIC_API=true \
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
   - Uploads the Dart symbols to Crashlytics when the optional `FIREBASE_SERVICE_ACCOUNT` secret is set.
   - Publishes the release with that changelog section, `SHA256SUMS` and `devalay-symbols.zip`.
4. To rebuild an existing tag, run the workflow from the Actions tab with the tag as input.

The release key lives outside git:

- `app/android/app/upload-keystore.jks` and `app/android/key.properties` locally (both git-ignored).
- A backup in `~/.devalay-keys/`.
- The `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEY_PROPERTIES` repository secrets.

`key.properties` has `storeFile=upload-keystore.jks`. **Keep an offline backup of the keystore and its password.**
Android only installs an update when it is signed with the same key, so losing the key means users have to
uninstall the app to update it.

## 0.2 Keeping the download small

Google Play sends each phone only its own slice of the App Bundle: one CPU type (ABI), one screen density and its
languages. The `.aab` file is about 70 MB, but most of that is upload-only metadata (the R8 mapping and native
debug symbols) that Play keeps and never sends to phones. To see the real per-phone download size:

```bash
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=/tmp/devalay.apks
bundletool get-size total --apks=/tmp/devalay.apks --dimensions=ABI
```

| Play download | v1.4.0 | Now |
|---|---|---|
| arm64-v8a (most phones) | 16.05 MB | 14.15 MB |
| armeabi-v7a (older phones) | 15.90 MB | 13.89 MB |

What keeps it down:

- **Dart symbols stay out of the app.** Release builds pass `--split-debug-info=build/symbols`. That saves about
  0.9 MB per phone. The symbols are attached to each GitHub release as `devalay-symbols.zip`. If Crashlytics
  shows a Dart trace as addresses, run `flutter symbolize -i trace.txt -d app.android-arm64.symbols`. We don't
  use `--obfuscate`: the code is public, so obfuscation would only make crash traces harder to read.
- **Slim fonts.** `app/tool/slim_fonts.sh` strips TrueType hinting (Flutter on Android never uses it) and glyph
  names. It also cuts the two Telugu fallback fonts down to the Telugu block. Run it on any font you add (needs
  `pip install fonttools`). Fonts went from 2.06 MB to 0.99 MB compressed. Bundle only fonts the app draws:
  scripts other than Latin, Devanagari and Telugu use the phone's own Noto fonts.
- **R8 and resource shrinking** are on for release (`isMinifyEnabled`, `isShrinkResources` in
  `app/android/app/build.gradle.kts`). Keep rules live in `proguard-rules.pro`.
- **Material and Cupertino icon fonts** are tree-shaken to the icons the code uses. Don't pass
  `--no-tree-shake-icons`.
- **Check new dependencies.** `flutter build appbundle --analyze-size --target-platform android-arm64` breaks
  `libapp.so` down by package. Flutter itself is about 4 MB of the 12 MB Dart code, and the app is about 1.1 MB.
  `timezone` stays on the full database (`latest_all`): it adds about 80 KB, and the smaller variants drop IDs
  that Android still reports, such as `Asia/Calcutta` and `Asia/Kuala_Lumpur`.
- **Sounds** are AAC (`.m4a`). Keep new ones short and AAC, not WAV.

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
