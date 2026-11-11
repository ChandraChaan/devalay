# Changelog

Each milestone is a git tag and a [GitHub release](https://github.com/ChandraChaan/devalay/releases). Releases from
v1.0.0 on carry a signed APK, built by `.github/workflows/release.yml` from the section below that matches the tag.

## Unreleased

- Temple booking: every online service of Tirumala Tirupati Devasthanams in one place. Special Entry Darshan
  (₹300), senior citizen and SRIVANI darshan, Angapradakshinam, Arjitha Sevas and the Seva e-Dip, rooms, e-Hundi,
  donations and more, each explained in English, Hindi and Telugu, with the steps to book and what to carry.
- The Book button opens the temple's official site inside Devalay. You book and pay there; Devalay takes no booking
  and no money.
- Latest from the temple: TTD's own announcements (which quota opens on which date and time), refreshed every day
  from its official site and shown on the TTD page.
- Usual monthly opening dates for each TTD quota, with a reminder the evening before and again before it opens.
- 17 more temples and temple boards with their official booking sites: Shirdi, Sabarimala, Vaishno Devi, Kashi
  Vishwanath, Ayodhya, Mahakaleshwar, Char Dham, Srisailam, Andhra Pradesh, Tamil Nadu and Karnataka temples and
  others. Search by temple, city or state.
- On Home (Booking, and a card under the shortcuts) and in More.

## v1.3.0 — 2026-11-11

- Bhagavad Gita: a Listen button. Devalay reads each verse aloud (Sanskrit, then the English meaning) with the
  phone's own voices, turns the page by itself and goes on to the next chapter. Choose Sanskrit only, meaning only or
  both, and 0.75× to 1.5× speed. The verse being read is highlighted. Also on each chapter and on Home's verse of the day.
- Calendar: swipe between months, a Sunday-first layout, Today and month/year jump, a legend, and a card for the
  selected day with tithi, nakshatra, sunrise and festivals.
- Calendar full screen: a big month grid with festival names written in each day.
- Day page: tap a day twice (or long-press) for a full-screen page with festival details and the full panchang. Swipe
  to the next or previous day, or share the day.
- Panchang: swipe left or right to change the day.

## v1.2.0 — 2026-11-04

- English is now the default language and New Delhi the default city, because Devalay is for all of India. Hindi
  and Telugu are still one tap away on the first screen and in Settings. Existing users keep their choice.
- Play Store: the listing is English-first, with a Telugu translation.

## v1.1.1 — 2026-11-03

- Force update now compares version names (such as 1.1.1). The per-phone APKs add 1000 to 4000 to Android's build
  number, so a phone with one of them could have skipped a required update.

## v1.1.0 — 2026-11-03

Devalay in Telugu, for the whole family.

- **Telugu everywhere:** Telugu is now the default language, alongside Hindi and English. Shlokas and the Gita appear
  in Telugu script, and the bundled Noto Sans Telugu and Tiro Telugu fonts keep text clear.
- **Telugu Panchangam:**
  - Samvatsaram, masam, paksham, ayanam and ruthuvu.
  - Good times: Abhijit, Amrit Kalam and Brahma muhurtham.
  - Times to avoid: Rahu Kalam, Yamagandam, Durmuhurtham, Varjyam and Gulika.
  - Checked against Drik Panchang for Hyderabad. Covers 19 more Andhra Pradesh and Telangana cities, 47 cities in
    all.
- **Telugu festivals:** Bhogi, Kanuma, Ratha Saptami, Varalakshmi Vratam, Engili Pula and Saddula Bathukamma, Atla
  Taddi and Nagula Chavithi. Their 2025 dates match published calendars.
- **Telugu and Carnatic songs:** 16 recordings, about 7.5 hours: Annamacharya and Ramadasu keerthanas, Tyagaraja
  kritis and stotrams, by M.S. Subbulakshmi, Dr. M. Balamuralikrishna and P.B. Sreenivas. Saregama released them
  under CC BY 3.0. Sri Venkateswara Swamy is added as a deity.
- **A deity for each day:** the home screen shows that day's deity's songs (Telugu homes: Monday Shiva, Saturday
  Venkateswara), and the morning reminder names the day's deity.
- **Bhakti videos:** official TTD (SVBC) temple videos in a large swipe-up feed, easy for elders.
- **Wallpapers with Telugu blessings:** write "ఓం నమః శివాయ" or your own words on sacred art, then set it as the
  wallpaper or share it.
- **Looks:** five app colours, warmer light and dark themes, and a side navigation rail on tablets.
- **Firebase:** Crashlytics crash reports, push announcements (by language topic) and a Remote Config force update.
- **Fixes:**
  - The lock-screen and notification player now shows the song title and picture (it showed only
    "Devalay is running").
  - The app version in Settings is now correct.
- **Play Store:** an App Bundle in every release, a Telugu and English listing, screenshots and a closed-testing
  guide (`docs/PLAY_STORE.md`).

## v1.0.2 — 2026-11-03

- Onboarding: the Moon-sign chips are now readable. They had rendered as light chips with white text, because the
  chip's light canvas showed through its translucent background.

## v1.0.1 — 2026-11-03

- Onboarding: an attempted fix for the unreadable Moon-sign chips, which did not work; fixed in v1.0.2.
- The website now serves search, Ask the Gita and the status maker data at the paths the app requests. This fix
  reached v1.0.0 installs as well, with no update needed.

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
