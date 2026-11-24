# Usage statistics and the admin screen (1.5.3)

Modelled on chandrachaan.com's visitor console (live presence + activity) and Vajra Automate's admin
(Google sign-in, access decided by Firebase, never by the app).

## What the app sends

| Where | What | When |
|---|---|---|
| Realtime Database `status/{uid}` | `s` active/offline, `t` server time, `scr` current screen (route pattern), `lang`, `v`, `st` (state) | Every screen change while open; `onDisconnect` marks offline. The app drops the connection when it goes to the background (Spark plan: 100 simultaneous connections). |
| Firestore `installs/{uid}` | `firstSeen` (once), `lastSeen`, `lang`, `v`, `build`, `state`, `src` (installer), `sessions`, `f.{feature}` counters | Batched with the events |
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
- **Overview:** installs, active today / 7 d / 30 d, new today / 7 d, most-used features (times · users),
  language, state, version and installer splits. Reads up to 3000 install docs per open (pull to refresh).
- **Users:** every install by last seen; tap for live status, feature counts and the action timeline.
- **Feedback:** inbox, newest first, mark done.

### Who is an admin

Rules (`firestore.rules`, `database.rules.json`) allow cross-install reads only when the account has the custom claim
`admin: true`, or an `admins/{uid}` record exists (Firestore document, and `admins/{uid}: true` in the Realtime
Database). Neither can be written by any app. To grant:

1. Open the admin screen on your phone and sign in with Google. It shows "not an admin" and the account id.
2. Either run `tools/admin/set-admin-claim.mjs --email you@gmail.com` (needs `gcloud auth application-default login`),
   or add Firestore document `admins/{uid}` (any field) **and** Realtime Database `admins/{uid} = true` in the console.
3. Tap **Check again**.

## Deploying rules

```bash
firebase deploy --only firestore:rules,firestore:indexes,database --project devalay-chandra
```

Firestore is in `asia-south1`, the Realtime Database in `asia-southeast1`, both on the free Spark plan. Google
sign-in needs each signing certificate's SHA-1 on the Firebase Android app (upload key, Play app-signing key and its
predecessor, debug key are registered). The web client id and database URL are constants in the app, so CI's
`GOOGLE_SERVICES_JSON` secret does not have to change.

## Limits

- Spark Realtime Database: 100 simultaneous connections. Past that, presence writes fail quietly (nothing else
  breaks); move to Blaze.
- Spark Firestore: 20k writes and 50k reads a day. About 6–8 writes per user per day plus the admin's reads.
- Events have no automatic expiry yet (a TTL policy needs Blaze). Delete old ones when needed.
