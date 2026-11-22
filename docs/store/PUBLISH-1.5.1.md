# Publishing 1.5.1 (10501): Firebase Analytics and Meta app events

Branch `release/1.5.1-tracking`. Nothing is committed, tagged or uploaded yet.

## What changed in the app

- `firebase_analytics`: daily new/active users (automatic `first_open`, `session_start`, `user_engagement`) and a
  `screen_view` per screen, named by route pattern (`home`, `listen`, `mandir`, `read`, `more`, `calendar`,
  `books/slug`, …). Logged from a GoRouter delegate listener in `app/lib/app.dart`, so bottom-tab switches count.
- `facebook_app_events` (Meta SDK 19): app ID and client token in `res/values/strings.xml`, manifest meta-data with
  auto-init, automatic app-event logging (installs, app activations) and advertiser-ID collection on.
  `AutoLogMetaDataEnabled` is off, so events don't carry screen titles or the URL that opened the app.
- Both SDKs add the `com.google.android.gms.permission.AD_ID` permission to the merged manifest.
- Settings no longer says "No analytics" (all 11 languages). Privacy policy, README and website updated.

## 1. Meta app (developers.facebook.com → app 2224409311804637)

Settings → Basic → **Add platform → Android** (skip if it's already there with these values):

| Field | Value |
|---|---|
| Google Play package name | `com.chandrachaan.devalay` |
| Class name | `com.chandrachaan.devalay.MainActivity` |
| Key hashes | Optional for app events (needed only for Facebook Login). To add: Play Console → Test and release → App integrity → App signing → copy the **App signing key** SHA-1, then run `echo <SHA1 with colons> \| xxd -r -p \| openssl base64` and paste the result. Do the same for the upload key SHA-1. |
| Log in-app events automatically | On |

Also check that **App mode is Live** (top bar), with the privacy policy URL
`https://chandrachaan.github.io/devalay/privacy.html` and a category set. After 1.5.1 is live, Events Manager →
the app → Overview should show `fb_mobile_activate_app` and installs within a day.

## 2. Play Console → Policy → App content

### Advertising ID (must change, or the release is rejected)
"Does your app use advertising ID?" → **Yes**. Purposes: **Analytics**, **Advertising or marketing**.

### Ads
Unchanged: **No** (the app shows no ads; the SDKs only measure).

### Data safety (Edit → Data types)

Keep the existing answers (crash logs, diagnostics) and change or add:

| Data type | Collected | Shared | Processed ephemerally | Required or optional | Collection purposes | Sharing purposes |
|---|---|---|---|---|---|---|
| **App activity → App interactions** (new) | Yes | Yes | No | Required | Analytics, Advertising or marketing | Analytics, Advertising or marketing |
| **Device or other IDs** (existing, edit) | Yes | Yes (was No) | No | Required | App functionality, Analytics, Advertising or marketing | Analytics, Advertising or marketing |

Other answers stay the same: data encrypted in transit; the deletion answer as today. Firebase Analytics derives a
coarse region from the IP address without storing the IP. Google's Firebase data-disclosure guide doesn't list
that as location collection, so Location stays "not collected".

## 3. Privacy policy

`backend/app/pages/privacy.html` now covers Firebase Analytics and Meta app events, and no longer says "no
advertising IDs and no analytics". The hosted copy (`chandrachaan.github.io/devalay/privacy.html`) is rebuilt by
`.github/workflows/pages.yml` when this reaches `main`. Publish it **before** 1.5.1 goes out on Play.

## 4. Release

Merge, tag `v1.5.1` (CI builds `devalay-play.aab`), upload to Production with `<lang>/release_notes.txt`.
