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

The listing files are in `docs/store/play/`:

| Play field | File |
|---|---|
| Short description (≤80 characters) | `te-IN/short_description.txt`, `en-IN/short_description.txt` |
| Full description (≤4000 characters) | `te-IN/full_description.txt`, `en-IN/full_description.txt` |
| App icon 512×512 | `icon-512.png` |
| Feature graphic 1024×500 | `feature-graphic.png` |
| Phone screenshots (2–8) | `docs/screenshots/` (Telugu screens) |

Category: **Lifestyle**. Tags: Religion & spirituality.

## 4. App content (Policy → App content)

- **Privacy policy:** `https://chandrachaan.github.io/devalay/privacy.html`. Set the `CONTACT_EMAIL` repository
  variable first; the policy shows it, and Play requires a real contact address.
- **Ads:** No ads.
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
  | Device or other IDs (Firebase installation ID, push token) | Yes | No | App functionality: notifications, update checks | No |

  Data is encrypted in transit. No account is created, so there is nothing to request deletion of. No location,
  contacts, photos or personal info are collected.
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
