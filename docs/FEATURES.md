# Feature parity with the reference app

The reference is the Play Store listing of *Sanatan App* (com.duolop.sanatan), reviewed on 3 Nov 2026. Devalay
re-implements the feature set with original code and design and only legally reusable content.

| Reference feature | Devalay | Notes |
|---|---|---|
| Aarti & bhajan audio | ✅ Built | 22 CC0/CC-BY-SA recordings from Wikimedia Commons plus 12 original synthesised tracks. **Content gap:** popular studio bhajans are copyrighted; add licensed recordings through the admin uploader. |
| Mantra & chalisa (read + listen) | ✅ Built | 37 texts with transliteration and meanings; Gayatri, Mahamrityunjaya, Om Namah Shivaya audio. Only the Hanuman Chalisa is bundled among chalisas (Shiv, Durga and other chalisas still need verified public-domain texts entered in the admin). |
| Devotional ringtones | ✅ Built | Set as ringtone, notification or alarm through MediaStore and RingtoneManager (Android "Modify system settings" permission). 5 original CC0 tones. |
| AI devotional status | ✅ Built (image) | Claude-written or offline-generated text composed on art, exported at 1080×1920. **Not built:** rendered *video* statuses (needs on-device video encoding; ffmpeg_kit is discontinued). |
| Hindu movies & series | ✅ Partial | 4 public-domain Dadasaheb Phalke films with a built-in player. Modern films and TV series need distribution licences. |
| Live wallpapers | ✅ Static wallpapers | 37 public-domain paintings (Raja Ravi Varma and others): set home, lock or both; save; share. **Not built:** animated live wallpapers (needs an Android WallpaperService renderer). |
| Daily Rashifal | ✅ Built | Computed from the Moon's real transit; optional AI polish; Hindi and English. |
| Virtual Mandir (diya, flowers, darshan) | ✅ Built | Diya, flower shower, bells, shankh, aarti thali animation, streak, per-deity glow, offline sounds. |
| Ramayan, Sunderkand, Gita, Shiv/Vishnu Puran | ✅ Partial | Full Gita (Sanskrit + English), Valmiki Ramayan incl. Sundar Kand (Griffith's English), Mahabharata, Upanishads. **Gap:** Tulsidas's Ramcharitmanas Sunderkand in Awadhi, and Shiv/Vishnu Puran (no public-domain digital text was imported; Wilson's 1840 Vishnu Purana is PD and can be added with `scripts/build_books.py`). |
| Festival specials | ✅ Built | Astronomically computed festival calendar, reminders, admin banners for festival campaigns, admin date overrides. |
| Offline downloads | ✅ Built | Audio stored privately; text and lists cached for offline use. |
| Search | ✅ Built | Tracks, texts, books, wallpapers and Gita translations; Hindi and English. |
| Favourites | ✅ Built | Offline-first, synced to the account after sign-in. |
| Premium subscription | ✅ Built | Google Play Billing plus server-side verification. Prices come from Play, cancel anytime, no AutoPay mandates. Products must be created in Play Console. |
| Notifications | ✅ Built (local) | Daily prayer and festival reminders scheduled on device; no Firebase. Server-pushed campaigns are not built (would need FCM or UnifiedPush). |

## Added beyond the reference

- Accurate Panchang with tithi, nakshatra, yoga and karana end times, and muhurta and Rahu Kaal for 28 cities.
- Month calendar with Ekadashi, Purnima, Amavasya, Pradosh and Sankashti markers.
- Japa mala counter.
- "Ask the Gita" Q&A grounded in verses.
- Full scriptures library (four public-domain books, about 2.5 million characters).
- Account deletion, data-minimal design, no ads or trackers, Hindi and English UI, dark mode.
- A free public APK that needs no server: content comes from a daily-refreshed static API on GitHub Pages; search,
  Ask the Gita and the status maker run on device. Accounts, sync and Premium need the full server.
