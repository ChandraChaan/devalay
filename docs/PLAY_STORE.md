# Publishing on Google Play

This guide covers publishing Devalay from a **personal** Play Console account. Everything Play asks for is already
in this repo; the steps below say where each piece lives.

## Before you start: personal accounts must run a closed test

Google requires every personal developer account created after 13 November 2023 to run a **closed test with at
least 12 testers, each opted in for 14 days in a row**, before it can apply for production. Family and friends can
be the testers. Plan on about three weeks from the first upload to the public listing.

## 1. Create the app

Play Console → **Create app**:

| Field | Value |
|---|---|
| App name | `Devalay: Bhakti & Panchang` |
| Default language | English – en-IN (add Telugu – te-IN as a translation) |
| App or game | App |
| Free or paid | Free |

## 2. App signing and the first bundle

1. Every tagged release (`git tag vX.Y.Z && git push origin vX.Y.Z`) attaches **`devalay-play.aab`** to its
   GitHub release, signed with the Devalay *upload* key (`~/.devalay-keys/upload-keystore.jks`).
2. In Play Console → **Testing → Closed testing → Create track**, upload `devalay-play.aab`.
3. Accept **Play App Signing**. Google keeps the app signing key, and the Devalay key becomes your upload key. If
   the upload key is ever lost, Google can reset it, which is one more reason to keep the backup in
   `~/.devalay-keys/`.
4. After the first upload, copy the **App signing key certificate SHA-1 and SHA-256**
   (Play Console → Setup → App signing) into Firebase → Project settings → Devalay Android → Add fingerprint.

The APKs on GitHub and the Play build are signed with different keys. A phone with the GitHub APK must uninstall
it before installing from Play (favourites and japa counts are stored on the phone and will be lost).

## 3. Store listing

The listing files are in `docs/store/play/`, one folder per Play language: `en-IN` (default), `hi-IN`, `mr-IN`,
`te-IN`, `ta-IN`, `kn-IN`, `ml-IN`, `gu`, `bn-BD` and `pa`. Play has no Odia listing language; Odia readers see
en-IN.

| Play field | File |
|---|---|
| App name (≤30 characters) | `<lang>/title.txt` |
| Short description (≤80; no price words such as "free", no "no ads") | `<lang>/short_description.txt` |
| Full description (≤4000) | `<lang>/full_description.txt` |
| What's new (≤500) | `<lang>/release_notes.txt` |
| App icon 512×512 | `icon-512.png` |
| Feature graphic 1024×500 | `<lang>/feature-graphic.png` (en-IN, hi-IN, te-IN) |
| Phone screenshots (2–8), captioned | `<lang>/screenshots/` (en-IN, hi-IN, te-IN; 1080×1920) |

The captioned screenshots and feature graphics are made from the real 1.4 screens in `screenshots-v1.4/` by
`docs/store/tools/make_store_images.py`; edit the captions there and run it again. Languages without their own
images use the en-IN ones.

Category: **Lifestyle**. Tags (Store settings → Manage tags, up to 5, from Play's list), for example Religion & spirituality, Calendar,
Astrology & horoscope, Music & audio.

## 4. App content (Policy → App content)

- **Privacy policy:** `https://chandrachaan.github.io/devalay/privacy.html`. Set the `CONTACT_EMAIL` repository
  variable first; the policy shows it, and Play requires a real contact address.
- **Ads:** No ads.
- **Advertising ID:** Yes, the app uses the advertising ID (Firebase Analytics and the Meta SDK add the `AD_ID`
  permission). Purposes: Analytics, Advertising or marketing.
- **App access:** All functionality is available without special access.
- **Content rating:** Fill in the questionnaire as a reference/lifestyle app with no violence, no user-to-user
  communication, no gambling and no purchases. The expected result is "Everyone" / 3+.
- **Target audience:** 13 and over. Selecting younger ages brings in the Families policy, which this app does not
  need.
- **News app:** No.
- **Data safety:**

  | Data type | Collected | Shared | Why | Optional |
  |---|---|---|---|---|
  | Crash logs (App info and performance) | Yes | No | Analytics: fixing crashes (Firebase Crashlytics) | No |
  | Diagnostics | Yes | No | Same as above | No |
  | Device or other IDs (Firebase installation ID, push token, Android advertising ID) | Yes | Yes (Meta, Google) | Collected: App functionality, Analytics, Advertising or marketing. Shared: Analytics, Advertising or marketing | No |
  | App interactions (App activity): installs, app opens, screen views | Yes | Yes (Meta, Google) | Collected and shared: Analytics, Advertising or marketing (Firebase Analytics, Meta app events) | No |
  | Approximate location (Location): the Indian state of the city picked for Panchang (1.5.3) | Yes | No | Analytics | Yes (Settings → Privacy) |
  | Other user-generated content (App activity): feedback notes from "Send feedback" (1.5.3) | Yes | No | App functionality, Analytics | Yes |
  | Name (Personal info): "About you" (1.5.11) | Yes | No | App functionality, Personalisation, Analytics | Yes |
  | Email address (Personal info): optional Google sign-in for the backup (1.5.11) | Yes | No | App functionality, Account management | Yes |
  | User IDs (Personal info): the Google/Firebase account ID after sign-in (1.5.11) | Yes | No | App functionality, Account management | Yes |
  | Other info (Personal info): date and time of birth, gender, gotra, rashi/nakshatra/lagna in "About you" (1.5.11) | Yes | No | App functionality, Personalisation, Analytics | Yes |
  | Approximate location (Location): city of birth in "About you" (1.5.11), in addition to the Panchang state | Yes | No | App functionality, Personalisation, Analytics | Yes |

  "About you" (1.5.11) is optional and kept on the phone. Only while "Share usage statistics" is on does a copy go to
  Firestore `installs/{uid}.profile` (name, gender, date and time of birth and age group, city of birth, gotra,
  rashi, nakshatra, lagna; no coordinates), and only when the user signs in with Google is the full
  profile backed up in `profiles/{uid}` (owner-only). Nothing from it goes to Analytics, Meta or ads; for under-18s the
  app also withholds ad-personalisation consent from Analytics and turns Meta's auto-logged events off. Gender: Play
  lists it under Personal info → "Other info" (there is no separate gender type); mention it in that row.

  **Account creation and deletion (1.5.11).** Google sign-in creates an account, so in Data safety answer "Yes, users
  can create an account" with **Google sign-in** (OAuth), and give the account deletion link
  `https://chandrachaan.github.io/devalay/privacy.html#delete-account`. In-app deletion is Settings → About you →
  Delete account (deletes the account, the backup, usage statistics and support chat). The page also offers deletion by
  email for people who no longer have the app.

  From 1.5.3 the app also keeps its own usage statistics in Firestore and the Realtime Database (anonymous Firebase
  ID, screens and features used, live online status), covered by the "App interactions" and "Device or other IDs"
  rows above (purpose: Analytics). Users can turn them off and delete them in Settings → Privacy, so answer **Yes**
  to "Can users request that data be deleted?".

  Data is encrypted in transit. Before 1.5.11 no account was created; from 1.5.11 an account exists only if the user
  signs in with Google (see above). Usage data is deleted from Settings → Privacy → Delete my usage data.
  No precise location, contacts or photos are collected; personal info only through "About you" and Google sign-in.
  Festival wishes let the user add their own photo to a card. The photo is chosen in the Android photo picker, copied
  into the app's private storage and drawn on the card on the phone; it is never uploaded, so under Play's definition
  it is not "collected". Only the finished card leaves the phone, when the user shares it to an app they choose.
  The picker needs no storage or media permission.
- **Temple booking (government information):** the Booking pages describe services of TTD and state temple
  departments and open their official sites. Play's Misleading Claims policy asks apps that show government
  information to name the source and say they are not a government body. The app says this on every booking page.
  Before releasing a version with Booking, add this to the full description as well:

  > Temple booking: Devalay is not affiliated with Tirumala Tirupati Devasthanams (TTD) or any temple, trust or
  > government body. Booking details come from the temples' official sites (TTD: https://ttdevasthanams.ap.gov.in),
  > and every booking and payment is made there, not in Devalay.
- **Foreground service (media playback):** Devalay plays devotional audio in the background with lock-screen
  controls. Play may ask for a short screen recording that shows a song continuing after the screen is locked.
- **Permissions:** `WRITE_SETTINGS` is used only when the user chooses "Set as ringtone"; Android shows its own
  "Modify system settings" screen first. `SET_WALLPAPER` is used only when the user taps "Set as wallpaper".

## 5. Closed test with 12 testers

1. Play Console → Testing → **Closed testing** → your track → **Testers**. Add a Google Group or an email list with
   at least 12 Gmail addresses.
2. Share the **opt-in link** with them. Each tester opens it, taps **Become a tester**, then installs Devalay from
   the Play Store link on that page.
3. Keep at least 12 testers opted in for **14 consecutive days**. It helps if they open the app a few times and
   leave feedback.
4. Play Console → Dashboard → **Apply for production**, and answer the short questionnaire about the test.

## 6. Updates and force update

1. Add a `CHANGELOG.md` section, then tag the release. CI builds the APKs and the AAB.
2. Upload the new `devalay-play.aab` to the production track.
3. To make old versions update, raise `min_version_code` in Firebase **Remote Config** (or in
   `firebase/remoteconfig.template.json`, then run `firebase deploy --only remoteconfig`). The versionCode is
   `major·10000 + minor·100 + patch` of the version name, so v1.1.0 is 10100 (per-ABI APKs carry a larger Android
   versionCode, but the app compares version names). Phones below that number see a full-screen
   "Please update" page, which opens the Play Store for Play installs and the GitHub APK for others.

## 7. Push announcements

Firebase console → **Messaging** → New campaign → Notification. Target the topic `all`, or `lang_te`, `lang_hi` or
`lang_en` for one language. Good uses are festival greetings ("ఉగాది శుభాకాంక్షలు") and new-song announcements.
