# Changelog

Each milestone is a git tag and a [GitHub release](https://github.com/ChandraChaan/devalay/releases). Releases from
v1.0.0 on carry a signed APK, built by `.github/workflows/release.yml` from the section below that matches the tag.

## v1.5.6 — 2026-11-27

Retention: a reason to come back each morning without having to remember to open the app.

- **Morning Panchang** (tithi, nakshatra, Rahu Kalam, sunrise and sunset, festivals) is now offered when you set up
  the app: the switch on the last onboarding page starts on, and the notification permission is asked as you
  finish. Existing users get a card on Home that turns it on in one tap. The time is 6 AM by default and can be
  changed or switched off in Settings. Messages are laid out 45 days ahead on the phone and work offline. They use
  inexact alarms (no exact-alarm permission) and are re-laid after a reboot.
- Tapping the morning message or a festival reminder opens today's Panchang, whether the app was running or not
  (and replaces a Panchang already open, so it always shows today). The daily prayer reminder opens Listen, and event
  reminders open the calendar. A morning message clears itself after 18 hours, so yesterday's never piles up
  under today's.
- **Accurate times for people who never pick a city.** 73% of users never changed the default (New Delhi), so
  Telugu users saw Delhi's sunrise and Rahu Kalam. A city nobody picked now follows the app language (Telugu →
  Hyderabad, Tamil → Chennai, Kannada → Bengaluru, Malayalam → Kochi, Marathi → Mumbai, Bengali → Kolkata, Gujarati →
  Ahmedabad, Punjabi → Chandigarh, Odia → Bhubaneswar; Hindi and English stay on New Delhi). The message names the
  city its times are for, the Home card asks until a city is chosen, and onboarding's city page gains "Use my
  location". Usage statistics report a state only for a city the user chose.
- "Use my location" no longer errors when the city sheet is closed (or a city tapped) while the phone is still
  looking for a fix.
- The Panchang home-screen widget shows sunrise and sunset and opens today's Panchang. Home and Settings can add it
  to the home screen directly on launchers that support it.
- Analytics: `reminder_open` (type, cold start; Firebase reserves `notification_open` for its own pushes), `widget_tap` (which widget), `notification_settings_changed`
  (kind, on/off, time, where), `widget_pin_request`, `morning_card_shown`/`closed`, and the user properties
  `morning_panchang` (on/off/blocked) and `home_widgets`. Screen views now name screens opened on top of a tab
  (`panchang`, `calendar`, `player`, …); until now only the five tabs were recorded.

## v1.5.5 — 2026-11-27

Stability, from Play vitals and Crashlytics (1.5.4: 98% crash-free users; Play's user-perceived ANR rate 1.85%
against a 0.47% bad-behaviour threshold):

- Faster start and fewer "app isn't responding" freezes. Since Flutter 3.29 the app's Dart code runs on Android's
  main thread, so anything slow there holds up touches. Now:
  - the bundled data files (Thought of the day, pooja guides, holidays, temples, wishes) are parsed on a background
    isolate; Thought of the day alone is 690 KB and was parsed on every launch for Home
  - the time-zone database and the notification plugin are set up after the first screen, not before it
  - the public build no longer reads the Keystore at start (it has no accounts to keep tokens for)
  - push topics are renewed when the language changes and once a week, not with 12 calls at every launch
  - cached answers for single days older than a week are cleared, so the cache Hive loads at every start
    stops growing with each day of use
- Chandrabalam and Tarabalam follow the Moon through the day (from in-app feedback). They were worked out from
  the Moon's sign and nakshatra at sunrise, so once the Moon moved on, often within hours, the card was wrong for
  the rest of the day: on 26 Nov the Moon entered Mithuna at 7:11 AM, yet Vrishabha rashi still read "1st house"
  that night. Today's card now counts from where the Moon is now, and every day says when a value changes
  ("Until 7:15 AM: 1st house (Good)"). The Panchang data gains a `moon_rashis` timeline; data without it still
  shows the sunrise value.
- Mandir no longer crashes when it opens on your ishta devata before its shrine carousel is laid out
  (Crashlytics db0eff88).
- The admin screen's live activity feed no longer crashes with "Stream has already been listened to" when someone
  comes online (Crashlytics 0c9897d8).
- Picking a date or time and then leaving the screen (calendar, Panchang, Jatakam) can no longer crash.

## v1.5.4 — 2026-11-24

From Play reviews:

- **Today's guidance** on the Panchang and calendar day pages. It gives a few clear points instead of one line:
  - what the day suits, from its weekday, tithi and nakshatra
  - what to avoid: Rikta tithis, Amavasya, sharp or fierce nakshatras, Rahu Kaal with its times
  - the best time to begin (Abhijit Muhurta, not used on Wednesdays)
- **Day direction (Disha Shool)**: the direction not to start a journey in today, with the traditional remedy if
  the trip can't wait. The Panchang read-aloud now says it too.
- Edge-to-edge on every Android version (Play vitals recommendation): the app draws behind the status and
  navigation bars, and sets no bar colours. The splash's launcher icon is now a drawable layer: the old <bitmap> pointed
  at an adaptive icon, which is invalid from Android 8 on.
- Crash reports: a lost connection (offline, timeout, connection reset) no longer counts as a crash.
  Riverpod 3 reports a failed data load to the app-wide error handler even though its screen already shows "Try
  again", and these made up a large share of the crashes on 1.5.0 and 1.5.1. Real errors are still recorded as fatal.

## v1.5.3 — 2026-11-24

- Send feedback is now in the app: write an idea, a problem or something you like, and it reaches the Devalay
  team directly (More and Settings → Send feedback). No GitHub account needed.
- Anonymous usage statistics, so we know which features to improve: each install gets a random Firebase ID and
  reports which screens and features it uses (Panchang, Gita audio, japa rounds, shares…), whether the app is open
  right now, the language, app version and the state of the chosen city. Nothing typed is sent. Settings → Privacy
  has a switch to turn it off (it also stops Firebase Analytics) and a button to delete everything this phone sent.
- An owner-only admin screen (Google sign-in, admin rights granted outside the app) shows who is online and on which
  screen, a live activity feed, most-used features, users, and the feedback inbox. See docs/ADMIN.md.

## v1.5.2 — 2026-11-23

Crash fixes from Crashlytics (1.5.0 and 1.5.1 had about 75% crash-free users):

- A song that can't be streamed no longer closes the app. Failed loads (offline, a missing file, or Wikimedia
  Commons answering 429 Too Many Requests) are caught in the player, including when the next song in a queue
  fails, and show "Could not load. Check your connection." Streams now send a Devalay User-Agent, as
  Wikimedia's policy asks, so they are rate-limited less.
- Tapping a language twice in the Settings language sheet no longer crashes after the sheet has closed.
- Turning on a reminder twice quickly (onboarding, Settings, Calendar) no longer crashes with "Another
  permission request is already in progress"; both taps share one permission request.

## v1.5.1 — 2026-11-22

- Usage statistics and install measurement. Firebase Analytics now counts daily new and active users and logs a
  screen view for each screen (named by its route, such as `home` or `books/slug`, never by item or user input).
  Meta's app events SDK (`facebook_app_events`, app 2224409311804637) logs installs and app opens automatically,
  so Meta app-install ads can see installs; its extra event metadata (screen titles, opening URLs) is turned off.
  Both collect the Android advertising ID. The Settings line no longer says "No analytics", and the privacy
  policy, README and website describe what is collected.

## v1.5.0 — 2026-11-21

- Every share now ends with "🪔 Devalay" and the app's Play link: the day's Panchang, festival wish cards,
  statuses, wallpapers, Gita verses, Rashifal, songs and stotras. The link carries an install referrer
  (`utm_source=devalay_app`, `utm_medium=share`, `utm_campaign=<what was shared>`), so Play Console's acquisition
  report shows which shares bring installs. The app still has no analytics.
- Share today's Panchang straight from the Panchang card on Home.
- "Share with family" opens WhatsApp with an invitation ready to send (or the share sheet when WhatsApp is not
  installed). From the second day of use, Home shows a card for it until you share or close it.
- The Play rating card can also come right after a happy moment (a share, a finished japa mala), once the app has
  been used for a day. Play's limits and Devalay's own (at most every 120 days, three times in all) still apply.

## v1.4.0 — 2026-11-13

- Sidereal positions use the true Lahiri ayanamsa (mean plus nutation), as Swiss Ephemeris does, so sankranti
  moments, nakshatra and rashi boundaries and the Jatakam agree with it; sankrantis had come 2-4 minutes early.
- Smaller download: Google Play now sends about 14.2 MB to most phones (arm64) instead of 16.1 MB, and 13.9 MB
  instead of 15.9 MB to older 32-bit phones. Nothing is removed: every language, the Mandir sounds and the
  offline Panchang stay the same.
  - The bundled fonts are about half the size. They no longer carry hinting, which Android doesn't use, and the
    Telugu fallback fonts keep only Telugu letters. An italic Sanskrit font that nothing used is gone.
  - Release builds keep the Dart debug symbols out of the app. They are attached to each release as
    `devalay-symbols.zip` and, when the `FIREBASE_SERVICE_ACCOUNT` secret is set, uploaded to Crashlytics.
- Thought of the day: a short verse on Home from your own language's classics, with its meaning in your language
  and in English, and a link to its source. Vemana and Sumathi Satakam (Telugu), Thirukkural (Tamil), Sarvajna
  (Kannada), Tukaram (Marathi), Kabir (Hindi), Narsinh Mehta (Gujarati), Tagore (Bengali), Jagannath Das (Odia),
  Baba Farid and Bulleh Shah (Punjabi), Poonthanam and Sree Narayana Guru (Malayalam), and Sanskrit subhashitas
  for English. About 60 per language, one a day. Every verse was copied from a public-domain edition and checked
  against it (`tool/thoughts/verify.py`). Share any verse as a status image.
- Read the Panchang aloud: a speaker button on the Panchang and on each calendar day reads the weekday, tithi,
  nakshatra, sunrise and sunset, Rahu Kalam, festivals and your own events in the app language, with the
  phone's own voice. If the phone has no voice for your language it reads in English and explains how to add one.
- Pooja guides: step-by-step vidhanam for daily puja, Satyanarayana Vratam, Varalakshmi Vratam, Vinayaka Chavithi,
  Diwali Lakshmi Puja, Maha Shivaratri, and the Ekadashi and Pradosham vratas. Each has a samagri checklist that
  remembers what you have ready, the steps in order, and the mantras in your own script. Find them in More, or
  from the festival on its calendar day. All 11 languages.
- Home-screen widgets: a small 2×1 Tithi widget (date, tithi and a mark on festival and family days), a Festival
  countdown (days left to the next major festival, with the two after it), and Choghadiya & Rahu Kalam (the
  running Choghadiya, or Rahu Kalam while it is on, redrawn at each change without waking the phone). All are
  resizable, show previews in the widget gallery, stay in your language and open the matching screen when tapped.
- Backup & export (Settings, or the menu in My events): save or share a backup file of your days, birth star,
  rashi, city, language and reminder settings, and restore it on a new phone. Days are merged by id, so nothing
  already on the phone is lost. No account and no server; the app suggests a backup after a few changes.
- Export to calendar: an .ics file of a year's festivals and your days for Google Calendar or any calendar app.
  Date-based days repeat yearly; tithi days are listed for this year and next. "Add to calendar" on a festival or
  one of your days opens the phone's calendar app with it filled in.
- Import birthdays from contacts: after a clear explanation and Android's Contacts permission, pick which
  birthdays and anniversaries to add to My events. Only those dates and names are read, and nothing leaves the
  phone.
- Solar calendars: the Tamil (Aippasi 27, with the year's name), Malayalam (Kollam era), Bengali (Bangabda) and
  Odia solar dates in the calendar cells, the month header, the selected day and the day page. They show by
  themselves in Tamil, Malayalam, Bengali and Odia; anyone can turn one on in Settings › Calendar. Each region's
  rule for the first day of a month is followed (Tamil: sunset, Malayalam: three-fifths of the day, Bengali:
  midnight, Odia: Hindu midnight), checked against Drik Panchang for every month of 2026.
- Amanta or Purnimanta: North Indian month names, where the dark fortnight takes the next month's name, for the
  month header, day page, home screen, morning notification, widget and tithi events. Purnimanta is the default
  in Hindi and Punjabi, Amanta elsewhere; change it in Settings › Calendar. Festivals stay on the same days.
- State holidays: public holidays from each state government's order and bank holidays from RBI for 2026 (and
  2027 where already published), marked on the calendar and listed in Important days with their sources. The
  state follows your city, or pick one in Settings › Calendar. The lists are published with the website, so a
  corrected date reaches the app without an update.
- Use my location: one tap in the city picker finds the nearest city from your approximate location. It asks only
  when you tap it, uses the location once on the phone and never tracks you.
- 263 more cities: every district headquarters in Andhra Pradesh, Telangana, Karnataka, Tamil Nadu, Kerala and
  Maharashtra, the main cities of the other states, and Indian communities abroad (the Gulf, Malaysia, Africa,
  Mauritius, Fiji, the Caribbean, Europe, North America, Australia and New Zealand).
- Shubha Muhurtham: good days from today to the end of next year for marriage (Vivaham), house warming (Griha
  Pravesham) and buying a vehicle, for your city, with the good time window of each day (Rahu Kalam left out)
  and the best lagna in it. Dates follow Muhurta Chintamani as Drik Panchang summarises it: solar and lunar
  months, nakshatra, tithi, weekday, yoga and karana, no Adhika masa, Chaturmas or Pitru Paksha where they
  apply, and no Guru or Shukra moudhyami. They agree with Drik Panchang's 2026-2027 lists for Hyderabad and
  New Delhi on 88-90% of marriage dates, 94-95% of house-warming dates and 99.5% of vehicle dates.
- Namakaranam: good days for the naming ceremony in Shubha Muhurtham, agreeing with AstroSage's 2026-2027 list on
  98% of dates.
- Grahanam: solar and lunar eclipses this year and next, as seen from your city, with the begin, maximum and
  end times, whether it is visible, and Sutak (9 hours before a lunar eclipse, 12 before a solar one). They
  show in the calendar, on the day page and in a new Eclipses list in Important days.
- Jatakam: enter the date, time and place of birth for the lagna, Moon rashi, nakshatra and pada and the
  positions of the nine grahas, in a South or North Indian chart. It is worked out on the phone, warns when a
  few minutes of birth time would change the lagna or nakshatra, saves the birth star and rashi for Tarabalam,
  and saved births fill in marriage matching.
- Rashifal: weekly, monthly and yearly readings for every rashi beside the daily one, from the real transits of
  the Moon, Sun, Jupiter and Saturn, with good days, Chandrashtamam and Sade Sati, in every language.

- Devalay now speaks 11 languages: English, हिन्दी, বাংলা, मराठी, తెలుగు, தமிழ், ગુજરાતી, ಕನ್ನಡ, മലയാളം, ଓଡ଼ିଆ
  and ਪੰਜਾਬੀ. Every screen is translated, along with the Panchang names (tithi, nakshatra, yoga, karana, months,
  samvatsara, rashi), festival names, city names, festival wishes and the temple booking guide. Aartis, mantras
  and Gita verses are shown in your own script, and dates, date pickers and month names follow your language.
  A phone set to one of these languages opens the app in it; change it any time in Settings.
- Updates: Play installs update in the background with Google Play's in-app update, and urgent releases use
  Play's full-screen update. Builds that are too old still have to update first (force update), now in every
  language.
- Rate Devalay: a card in More to rate it on Google Play, share it with family or send feedback. After you
  have used the app for a few days, Play may ask once for a rating, with no questions before it.
- Calendar: Choghadiya, Hora and Gowri Panchangam (Nalla Neram) for every day, by day and by night, with the
  running period marked "Now". Each hora says what it suits: puja, study, travel, business or government work.
- Calendar: Rahu Kalam on the selected day, the lunar months of each month in the header (Kartika – Margashirsha),
  national holidays, and auspicious days (Amrita Siddhi, Guru Pushya, Ravi Pushya) marked with ✨.
- Important days: one list for the year of festivals, Ekadashi, Purnima, Amavasya, Pradosham, Sankashti, Masa
  Shivaratri, auspicious days, holidays and your own days, for this year and next.
- My events: keep birthdays, wedding anniversaries and remembrance days (taddinam) in the calendar. Repeat them
  every year by date, or by tithi and lunar month the way families do, with a reminder the evening before and that
  morning.
- Morning Panchang: an optional notification each morning with the day's tithi, nakshatra, Rahu Kalam, festivals
  and your events. Turn it on from the calendar menu or Settings and pick the time.
- The offline calendar now covers every month of this year and next.
- Home-screen widget: today's date, tithi, nakshatra, Rahu Kalam and festival (or your own event) on a saffron
  card, in your language. It holds the next 30 days, so it turns over at midnight even offline. Tap it to open
  the calendar.
- "For you": add your birth star and rashi once, and every day's Panchang shows your Tarabalam and Chandrabalam
  with a plain verdict (good day, mixed, or better to postpone). The morning notification includes it too.
- Moonrise and moonset on every day's Panchang.
- Tap ⓘ next to tithi, nakshatra, yoga, karana, Rahu Kalam, Varjyam, Choghadiya, Hora and more for a short
  explanation in English, Hindi or Telugu.
- Share any day's Panchang to WhatsApp from the calendar card, with tithi and nakshatra end times and the city.
- The city is shown and can be changed right from the calendar header; the city list can be searched.
- Search festivals in Important days, and from the app's main search ("ugadi", "ఏకాదశి").
- Adding a birthday or remembrance day opens the date picker on the year list instead of paging back month by month.
- Marriage matching: pick the bride's and groom's birth nakshatra and rashi (and the pada, if known) to see the
  Ashtakoota Guna Milan score out of 36. Varna, Vashya, Tara, Yoni, Graha Maitri, Gana, Bhakoot and Nadi each show
  their points, what they stand for and both partners' values, with Nadi and Bhakoot dosha called out.
- The South Indian 10 Porutham view (Dina, Gana, Mahendra, Stree Deergha, Yoni, Rasi, Rasyadhipati, Vasya, Rajju
  and Vedha) shows each as a match or not, with Rajju and Vedha marked as the essential two.
- Worked out on the phone, with tables checked against Drik Panchang and other published sources. A note asks you
  to consult your family priest before deciding. In More, in English, Hindi and Telugu.
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
- Festival wishes: make a greeting card with your own photo and name and share it, for example to your WhatsApp
  status. Pick a festival, a theme and one of six layouts (your photo beside the deity, a name banner, a full
  painting with a photo badge, a split card, a portrait card, or words only), then edit the caption, your name, a
  second line and the message. Drag or pinch the photo to fit its frame. Save to the gallery or share at 1080×1920.
- Themes for Diwali, Navratri, Dussehra, Ganesh Chaturthi, Sankranti, Ugadi, Maha Shivaratri, Holi, Rama Navami,
  Hanuman Jayanti, Raksha Bandhan, Varalakshmi Vratam, Janmashtami, Kartik Purnima, Gita Jayanti and New Year, plus
  birthday and anniversary cards: 41 themes, at least two for each, with captions and ready-made wishes in English,
  Hindi and Telugu. The next festival is shown first.
- A daily blessing card that says Good morning, Good evening or Good night by the hour, with the deity of the day.
- Your name and last photo are remembered on the phone for the next card. The photo is never uploaded.
- New festivals and themes can be published without an app update. Wishes are on Home, in More, and on festival
  days in the calendar.

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
