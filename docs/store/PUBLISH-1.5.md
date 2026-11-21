# Publishing 1.5

Status 21 Nov 2026: sections 1 (listing) and 3 (release) were sent to Google for review. Sections 2 and 4 are open.

## 1. Store listing (Play Console → Grow users → Store presence → Store listings → Default listing)

The default listing already has **unsaved draft changes** (a 75-character short description, a 3660-character
full description and the eight `screenshots-v1.4` images). Review them first; the steps below replace them.

1. **en-IN text:** `docs/store/play/en-IN/` title (unchanged), short description, full description.
   - Short: "Panchang, Hindu calendar, Rahu Kalam, muhurtham and aartis in 11 languages" (74). Drops "Free, no
     ads", which contradicted Play's "Contains ads" badge (YouTube's player).
   - Full: new first lines lead with Panchang and festival calendar; the rest is the 1.4 text (300+ cities,
     Muhurtham, eclipses, Jatakam, pooja guides), replacing the stale live text that says 47 cities.
2. **en-IN graphics:** feature graphic `en-IN/feature-graphic.png`; phone screenshots `en-IN/screenshots/01…08`.
3. **Translations** (Manage languages → add, then paste each folder's four files):
   hi-IN, mr-IN, te-IN, ta-IN, kn-IN, ml-IN, gu, bn-BD, pa. Play has no Odia.
   hi-IN and te-IN also get their own feature graphic and screenshots; the others use en-IN's.
4. Send the listing for review.

## 2. Store settings

Tags (empty today): add up to five from Play's list, such as Religion & spirituality, Calendar, Astrology &
horoscope, Music & audio.

## 3. Release 1.5.0 (10500)

Branch `growth/store-listing-and-sharing`: share links with an install referrer, Panchang share on Home, the
WhatsApp-first "Share with family" card, review prompt after happy moments. `flutter analyze` clean, all tests
pass, release bundle builds. To ship: merge, tag `v1.5.0` (CI builds `devalay-play.aab`), upload to Production
with the release notes in `<lang>/release_notes.txt`.

## 4. Not done, needs a decision: Firebase Analytics

The app promises "No ads · No analytics · Open source" in Settings, the privacy policy and Data safety declare
no analytics. Google Ads App campaigns optimising for **installs** use Play's own install data and need no SDK.
Adding Firebase Analytics (for in-app conversion events) would mean changing that promise, the privacy policy and
the Data safety form ("App activity → App interactions", collected, not shared, analytics).
