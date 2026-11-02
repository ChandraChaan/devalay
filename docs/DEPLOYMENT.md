# Deployment

Nothing is deployed yet; every step below needs your own accounts. Estimated cost at launch: about $0–7 a month
(Neon free tier, Render Starter or Fly.io shared CPU, R2 free tier of 10 GB with zero egress fees).

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
