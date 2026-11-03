# Changelog

Each milestone is a git tag and a [GitHub release](https://github.com/ChandraChaan/devalay/releases). Releases from
v1.0.0 on carry a signed APK, built by `.github/workflows/release.yml` from the section below that matches the tag.

## v1.0.0 — 2026-11-03

The first public release: a free APK that works without any server.

- **Serverless public build.** The APK reads a pre-rendered copy of the API from GitHub Pages, which a daily job
  refreshes (Panchang −7 to +45 days, home feed and Rashifal −2 to +10 days, festivals for this year and next, all
  28 cities).
- **On-device features.** Search, "Ask the Gita" (the same BM25 ranking as the server) and the status maker now run
  on the phone in the public build. Sign-in, sync and Premium are hidden there, because they need the full server.
- **Gita translation.** The English is now Annie Besant's translation (4th edition, 1922), which is public domain
  worldwide.
- **Website** at https://chandrachaan.github.io/devalay with a download button, live Panchang for the day,
  screenshots, and the privacy policy and terms.
- **Release pipeline.** Tags build a universal APK plus per-ABI APKs, signed with the Devalay release key, with
  SHA-256 checksums.
- **Store assets.** A banner and 12 screenshots.

## v0.2.0 — 2026-11-03

The Android app, CI and documentation.

- Flutter app with these sections:
  - Home, Listen, Mandir, Read and Panchang.
  - Calendar, Rashifal, japa mala and wallpapers.
  - Ringtones, the status maker, Ask the Gita and films.
  - Search, favourites and downloads.
- App features:
  - Background audio with lock-screen controls.
  - Offline cache and on-device reminders, with no Firebase.
  - Hindi and English, light and dark.
- GitHub Actions: backend tests on PostgreSQL and SQLite, a Docker smoke test, and app analyze, test and build.
- Architecture, deployment and feature-matrix docs, plus the content licence register.

## v0.1.0 — 2026-11-03

The backend.

- FastAPI service:
  - Content APIs for deities, tracks, texts, the Gita, books, wallpapers and videos.
  - Search, accounts with rotating refresh tokens, sync and AI with offline fallbacks.
  - Google Play premium verification.
- Panchang and festival engine:
  - Uses Skyfield with the DE421 ephemeris and Lahiri ayanamsa.
  - Checked against 33 published festival dates.
- SQLAdmin dashboard, seed content from public-domain and CC sources, Alembic migrations and a Dockerfile.
