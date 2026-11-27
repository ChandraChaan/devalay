# Usage statistics, the admin screen and pushes (1.5.3, 1.5.7)

Modelled on chandrachaan.com's visitor console (live presence + activity) and Vajra Automate's admin
(Google sign-in, access decided by Firebase, never by the app).

## What the app sends

| Where | What | When |
|---|---|---|
| Realtime Database `status/{uid}` | `s` active/offline, `t` server time, `scr` current screen (route pattern), `lang`, `v`, `st` (state) | Every screen change while open; `onDisconnect` marks offline. The app drops the connection when it goes to the background (Spark plan: 100 simultaneous connections). |
| Firestore `installs/{uid}` | `firstSeen` (once), `lastSeen`, `lang`, `v`, `build`, `state` (only for a city the user chose), `src` (installer), `sessions`, `f.{feature}` counters; 1.5.7+: `dev` phone model, `os` Android API level, `ram` MB, `cc` city chosen, `t` FCM token, `np` morning Panchang on/off/blocked, `na` notifications allowed, `nw` home-screen widgets | Batched with the events |
| Firestore `events/{auto}` | `uid`, `at`, `sid` (session), `items[]` of `{k, n?, t}`: `screen`, `app_open`, `audio_play`, `gita_listen`, `panchang_listen`, `japa_round`, `share`, `share_app`, `city_set`, `language_set`, `feedback_sent` | At most once a minute; 10 s after the app opens; on leaving the app |
| Firestore `feedback/{auto}` | `uid`, `at`, `kind` (idea/problem/praise), `text` ≤ 2000, `lang`, `v`, `done` | When the user sends feedback |

`uid` is a Firebase anonymous account per install. Nothing typed is recorded except feedback text. Code:
`app/lib/core/usage.dart`, `app/lib/features/feedback.dart`. Custom actions also go to Firebase Analytics as events.

Settings → Privacy → **Share usage statistics** (default on) stops all of it, Firebase Analytics included.
**Delete my usage data** deletes presence, the install summary and every event of this install, deletes the anonymous
account and turns sharing off.

## Admin screen

Settings → tap the version line 7 times → `/admin` (`app/lib/features/admin.dart`). Sign in with Google.

- **Live:** online now, last hour / 24 h, each online user's current screen, a live activity feed, recently seen.
- **Overview** (computed by `app/lib/core/admin_stats.dart`, unit-tested): new today / 7 d, active today / 7 d,
  back next day (D1) and on day 7 (D7), opened-once share, installs reachable by a push; new · active for the last
  14 days; a cohort table (install day × D1..D7); the 30-day funnel install → setup → city → morning Panchang →
  back next day; daily-habit shares; screens and actions of the week (people · times); language, chosen state,
  version, phone brand, Android, memory and installer splits. Reads up to 5000 install docs and 15 days of event
  batches per open (refresh button / pull to refresh).
- **Users:** search by install id or phone model; filter by language, state, away 3+ days, morning Panchang on,
  reachable by push. Tap for live status, phone, reminders, feature counts, the action timeline and
  **Send a notification to this install**.
- **Send:** title and message in Telugu, English and Hindi (other languages get the English, else the first
  written); what a tap opens (today's Panchang, calendar, Listen, Mandir, wishes, muhurtham, or any devalay:// /
  https:// link); optional picture; audience: everyone, one language, one state, one app version, not seen for N
  days, one install ("This phone" = the admin's own install); reach check; preview; history with sent, failed and
  opens (open rate = opens ÷ reach).
- **Feedback:** new / replied / fixed, with a note per item.

## Pushes (`functions/index.js`, Cloud Function `sendPush`, region asia-south1)

- Only an admin (claim or `admins/{uid}`) can call it; it validates everything (`functions/lib.js`, tested with
  `npm test` in `functions/`).
- Everyone / one language go to the FCM topics `lang_xx` every install subscribes to (each language gets its own
  text), so they also reach installs that turned off usage statistics. State, version, inactive and one install go
  to the FCM tokens installs report (only installs that share usage statistics, 1.5.7+). Tokens of uninstalled
  apps are removed after a send.
- Broadcasts are refused 9 PM–6 AM India time unless "Send anyway" is ticked.
- Each send is `campaigns/{id}` (written by the function before sending). The app adds 1 to `opens` when a push is
  tapped (rules allow exactly +1) and logs `push_open`.
- The app shows a push that arrives while it is open as a local notification on the same `announcements` channel,
  so a tap works the same in the foreground, the background and from a cold start.

### Who is an admin

Rules (`firestore.rules`, `database.rules.json`) allow cross-install reads only when the account has the custom claim
`admin: true`, or an `admins/{uid}` record exists (Firestore document, and `admins/{uid}: true` in the Realtime
Database). Neither can be written by any app. To grant:

1. Open the admin screen on your phone and sign in with Google. It shows "not an admin" and the account id.
2. Either run `tools/admin/set-admin-claim.mjs --email you@gmail.com` (needs `gcloud auth application-default login`),
   or add Firestore document `admins/{uid}` (any field) **and** Realtime Database `admins/{uid} = true` in the console.
3. Tap **Check again**.

## Deploying

Rules first, before any app build that sends the 1.5.7 install fields (older rules refuse them, and that install's
usage reports fail), then the function:

```bash
firebase deploy --only firestore:rules,firestore:indexes,database --project devalay-chandra
firebase deploy --only functions --project devalay-chandra
```

The function needs the Blaze plan (the project is on Blaze); cost at this scale is a few rupees a month at most.
Firestore is in `asia-south1`, the Realtime Database in `asia-southeast1`. Google
sign-in needs each signing certificate's SHA-1 on the Firebase Android app (upload key, Play app-signing key and its
predecessor, debug key are registered). The web client id and database URL are constants in the app, so CI's
`GOOGLE_SERVICES_JSON` secret does not have to change.

## Limits

- Spark Realtime Database: 100 simultaneous connections. Past that, presence writes fail quietly (nothing else
  breaks); move to Blaze.
- Spark Firestore: 20k writes and 50k reads a day. About 6–8 writes per user per day plus the admin's reads.
- Events have no automatic expiry yet (a TTL policy needs Blaze). Delete old ones when needed.

## Trying it locally (emulators)

Nothing here touches real data except FCM delivery itself.

```bash
firebase emulators:start --project devalay-chandra --only auth,firestore,functions,database   # needs Java 21+
cd app && flutter run --dart-define=STATIC_API=true --dart-define=API_BASE_URL=https://chandrachaan.github.io/devalay --dart-define=USE_EMULATORS=true
```

A debug build with `USE_EMULATORS=true` connects to the emulators on 10.0.2.2 (`app/lib/core/dev_emulators.dart`)
and the admin sign-in page then also offers email sign-in for a test admin made in the Auth emulator (custom claim
`admin: true`). Release builds never do either. The Functions emulator sends real FCM messages with your gcloud/
Firebase credentials, so only target "One install" there.

