"""Cut single songs out of CC BY Telugu/Carnatic albums and write app/seed/data/telugu_audio.json.

Saregama published the albums on its "Saregama Carnatic Classical" YouTube channel under CC BY 3.0. They were
imported to Wikimedia Commons, where the licence was reviewed. The Mantra Manjusha suktams are the uploader's
own work on Commons (CC BY 3.0). Each song below is one chapter of an album, cut at the silence nearest to the
chapter time in the Commons description, then encoded as AAC. The credit says "trimmed" as CC BY asks.

The m4a files are hosted as assets of the `media-telugu-v1` GitHub release, next to the full albums.

Usage:
  python scripts/cut_telugu_audio.py SRC_DIR OUT_DIR   # cut and encode (needs ffmpeg), then write the JSON
  python scripts/cut_telugu_audio.py --json-only       # rewrite the JSON from the spec and OUT_DIR durations
  gh release upload media-telugu-v1 OUT_DIR/*.m4a --repo ChandraChaan/devalay

SRC_DIR holds the albums: the release's own m4a files (by slug) for albums Devalay already hosts, and the audio
track of each new Commons file (name given in SOURCES).
"""

import json
import subprocess
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "app" / "seed" / "data" / "telugu_audio.json"
RELEASE = "https://github.com/ChandraChaan/devalay/releases/download/media-telugu-v1"
COMMONS = "https://commons.wikimedia.org/wiki/File:"
CC_BY_3 = "https://creativecommons.org/licenses/by/3.0/"

# key: (local file in SRC_DIR, Commons file, credit)
SOURCES = {
    "ramadasu": ("ramadasu-bhajans-balamurali.m4a",
                 "Popular_Shri_Ram_Bhajans_-_Dr._M._Balamuralikrishna_-_Sri_Bhadrachala_Ramadasu_-_Carnatic_Music.webm",
                 "Dr. M. Balamuralikrishna · Saregama"),
    "annamayya": ("annamacharya-greatest-mss.m4a",
                  "Annamacharya%27s_Greatest_Hits_Collection_-_M.S._Subblakshmi_-_Namo_Narayanaya_-_Carnatic_Music.webm",
                  "M.S. Subbulakshmi · Saregama"),
    "samkirtanas": ("annamacharya-samkirtanas-mss.m4a",
                    "Sri_Annamacharya_Samkirtanas_-_M.S._Subbulakshmi_-_Radha_Vishwanathan_-_Carnatic_Classical_Music.webm",
                    "M.S. Subbulakshmi, Radha Vishwanathan · Saregama"),
    "devadevam": ("devadevam.mka",
                  "Sri_Annamacharya_Devotional_Songs_-_M.S._Subblakshmi_-_Deva_Devam_Bhaje_-_Carnatic_Classical_Music.webm",
                  "M.S. Subbulakshmi · Saregama"),
    "ennaga": ("ennaga.mka", "Ennaga_Manasuku_with_Lyrics_by_Semmangudi_%26_M_S_Subbulakshmi.webm",
               "Semmangudi Srinivasa Iyer, M.S. Subbulakshmi · Saregama"),
    "tatvameruga": ("tatvameruga.mka",
                    "Tatvameruga_-_U.Srinivas_(Raga_Garudahwani)_Tyagaraja_Carnatic_classical_music.ogg",
                    "U. Srinivas (mandolin) · Saregama"),
    "sudha": ("sudha.mka",
              "Sudha_Raghunathan_-_Timeless_Carnatic_Hits_-_Marukelara_-_Kalyana_Gopalam_-_Sri_Sankara_Guruvaram.webm",
              "Sudha Raghunathan · Saregama"),
    "divine": ("divine.mka",
               "Divine_Melodies_of_M.S.Subbulakshmi_-_Srimannarayan_-_Kurai_Onrum_Illai_-_Carnatic_Music.webm",
               "M.S. Subbulakshmi · Saregama"),
    "pbs": ("pb-sreenivas-devotional.m4a",
            "Best_of_P.B._Sreenivas_Devotional_Hits_-_Sri_Krishna_Ashtaga_-_Sri_Hanuman_Chalisa_-_Carnatic_Music.webm",
            "P.B. Sreenivas · Saregama"),
    "vishnu": ("vishnu-melodies-mss.m4a",
               "Sacred_Melodies_of_Lord_Vishnu_-_M.S._Subbulakshmi%2C_Radha_Viswanathan_-_Carnatic_Classical_Music.webm",
               "M.S. Subbulakshmi, Radha Viswanathan · Saregama"),
    "shiva": ("siva-panchakshara-mss.m4a",
              "Most_Powerful_Shivan_Song_-_M.S._Subbulakshmi_-_Siva_Panchakshara_Stotram_-_Carnatic_Classical_Music.webm",
              "M.S. Subbulakshmi · Saregama"),
    "ganesha": ("ganesha-pancharatnam-mss.m4a",
                "Ganesh_Chaturthi_Special_Bhajan%2C_M.S._Subbulakshmi%2C_Ganesha_Pancharatnam%2C_Carnatic_Classical_Music.webm",
                "M.S. Subbulakshmi · Saregama"),
    "morning": ("morning-stotrams-mss.m4a",
                "Top_5_Morning_Stotram_-_M.S_Subbulakshmi_-_Ganesa_Pancharatnam_-_Lakshmi_Ashtothram_-_Carnatic_Music.webm",
                "M.S. Subbulakshmi · Saregama"),
    "krishna": ("bhaja-govindam-mss.m4a",
                "Popular_Shri_Krishna_Bhajan_-_M.S._Subbulakshmi_-_Bhaja_Govindam_-_Sikshashtakam_-_Carnatic_Music.webm",
                "M.S. Subbulakshmi · Saregama"),
    "mm-03": ("mm-03.mka", "03-GANAPATHI_SUKTHA-MANTRA_MANJUSHA.ogg", "VedadhayanaGosthi"),
    "mm-04": ("mm-04.mka", "04-DEVI_SUKTHAM-MANTRA_MANJUSHA.ogg", "VedadhayanaGosthi"),
    "mm-05": ("mm-05.mka", "05-PURUSHA_SUKTHAM-MANTRA_MANJUSHA.ogg", "VedadhayanaGosthi"),
    "mm-06": ("mm-06.mka", "06-SREE_SUKTHAM-MANTRA_MANJUSHA.ogg", "VedadhayanaGosthi"),
    "mm-07": ("mm-07.mka", "07-RUDRA_PRASNAM-MANTRA_MANJUSHA.ogg", "VedadhayanaGosthi"),
}

# (slug, kind, deity, title, title_hi, source, start s, end s or None for the end of the file).
# Times sit in the 3-5 s silences between songs (ffmpeg silencedetect at -45 dB near the description's chapter
# times). The Vishnu album crossfades, so Vishnu Sahasranamam ends at the one dip before Bhavamu Lona. Three
# albums end with a few seconds of another song after the last track, so those tracks end at the song's own end.
# Takkuvemi Manaku is left out: it runs to the end of its album file and is cut off there.
TRACKS = [
    # Bhadrachala Ramadasu
    ("ramadasu-paluke-bangaramayena", "bhajan", "rama", "Paluke Bangaramayena (Ramadasu)", "पलुके बंगारमायेना", "ramadasu", 3.7, 251.1),
    ("ramadasu-idigo-bhadradri", "bhajan", "rama", "Idigo Bhadradri (Ramadasu)", "इदिगो भद्राद्रि", "ramadasu", 255.1, 416.3),
    ("ramadasu-taraka-mantramu", "bhajan", "rama", "Taraka Mantramu (Ramadasu)", "तारक मंत्रमु", "ramadasu", 419.5, 621.2),
    ("ramadasu-ee-teeruga", "bhajan", "rama", "Ee Teeruga Nanu Daya Choochedavo (Ramadasu)", "ए तीरुग ननु दय चूचेदवो", "ramadasu", 624.5, 997.1),
    ("ramadasu-ramachandrulu-napai", "bhajan", "rama", "Ramachandrulu Napai (Ramadasu)", "रामचंद्रुलु नापै", "ramadasu", 1000.3, 1109.0),
    ("ramadasu-nanu-brovamani", "bhajan", "rama", "Nanu Brovamani Cheppave (Ramadasu)", "ननु ब्रोवमनि चेप्पवे", "ramadasu", 1112.1, 1303.7),
    ("ramadasu-ikshvaku-kula-tilaka", "bhajan", "rama", "Ikshvaku Kula Tilaka (Ramadasu)", "इक्ष्वाकु कुल तिलक", "ramadasu", 1306.5, 1730.5),
    # Annamacharya
    ("annamacharya-namo-namo-raghukula", "bhajan", "rama", "Namo Namo Raghukula Nayaka (Annamacharya)", "नमो नमो रघुकुल नायक", "annamayya", 2.1, 227.1),
    ("annamacharya-marali-marali", "bhajan", "venkateswara", "Marali Marali Jayamangalamu (Annamacharya)", "मरलि मरलि जयमंगलमु", "annamayya", 232.8, 467.2),
    ("annamacharya-deenuda-nenu", "bhajan", "venkateswara", "Deenuda Nenu Devudavu Neevu (Annamacharya)", "दीनुड नेनु देवुडवु नीवु", "annamayya", 470.3, 1247.9),
    ("annamacharya-namo-narayanaya", "bhajan", "vishnu", "Namo Narayanaya (Annamacharya)", "नमो नारायणाय", "annamayya", 1255.1, 1595.5),
    ("annamacharya-nanati-batuku", "bhajan", "venkateswara", "Nanati Batuku (Annamacharya)", "नानाटि बतुकु", "annamayya", 1600.7, 1889.7),
    ("annamacharya-kaladinte-mata", "bhajan", "venkateswara", "Kaladinte Mata (Annamacharya)", "कलदिंते माट", "annamayya", 1898.2, 2238.3),
    ("annamacharya-kannuleduta", "bhajan", "venkateswara", "Kannuleduta (Annamacharya)", "कन्नुलेदुट", "annamayya", 2250.4, 2532.8),
    ("annamacharya-idiye-sadhana", "bhajan", "venkateswara", "Idiye Sadhana (Annamacharya)", "इदिये साधन", "annamayya", 2540.8, 2813.8),
    ("annamacharya-adi-purusha", "bhajan", "venkateswara", "Adi Purusha (Annamacharya)", "आदि पुरुषा", "annamayya", 2822.4, 3265.4),
    ("annamacharya-bhavamu-lona", "bhajan", "venkateswara", "Bhavamu Lona (Annamacharya)", "भावमु लोन", "samkirtanas", 3.3, 310.0),
    ("annamacharya-dolayam", "bhajan", "venkateswara", "Dolayam (Annamacharya)", "डोलायाम्", "samkirtanas", 682.8, 843.7),
    ("annamacharya-rara-chinnanna", "bhajan", "krishna", "Rara Chinnanna (Annamacharya)", "रारा चिन्नन्ना", "samkirtanas", 1123.5, 1526.0),
    ("annamacharya-deva-devam-bhaje", "bhajan", "rama", "Deva Devam Bhaje (Annamacharya)", "देव देवं भजे", "devadevam", 918.7, 1165.5),
    ("annamacharya-koluvudee-bhakti", "bhajan", "venkateswara", "Koluvudee Bhakti Kondala (Annamacharya)", "कोलुवुडी भक्ति कोंडल", "devadevam", 1167.8, 1496.0),
    ("annamacharya-cheri-yashodaku", "bhajan", "krishna", "Cheri Yashodaku Shishuvitadu (Annamacharya)", "चेरि यशोदकु शिशुवितडु", "devadevam", 1499.5, 1939.3),
    ("annamacharya-manujudai-putti", "bhajan", "venkateswara", "Manujudai Putti (Annamacharya)", "मनुजुडै पुट्टि", "devadevam", 2105.8, 2569.8),
    ("annamacharya-parama-purusha", "bhajan", "vishnu", "Parama Purusha (Annamacharya)", "परम पुरुष", "devadevam", 2572.5, 3474.4),
    # Tyagaraja
    ("tyagaraja-ennaga-manasuku", "bhajan", "rama", "Ennaga Manasuku (Tyagaraja)", "एन्नग मनसुकु", "ennaga", 0, None),
    ("tyagaraja-tatvameruga-mandolin", "bhajan", "rama", "Tatvameruga, mandolin (Tyagaraja)", "तत्वमेरुग", "tatvameruga", 0, None),
    ("tyagaraja-marukelara", "bhajan", "rama", "Marukelara (Tyagaraja)", "मरुगेलरा", "sudha", 0.5, 313.6),
    ("tyagaraja-jagadananda-karaka", "bhajan", "rama", "Jagadananda Karaka (Tyagaraja)", "जगदानंद कारक", "divine", 2367.7, 2845.4),
    ("tyagaraja-bantu-reeti", "bhajan", "rama", "Bantu Reeti (Tyagaraja)", "बंटु रीति", "divine", 2845.7, 3113.7),
    ("tyagaraja-ninnu-vina", "bhajan", "rama", "Ninnu Vina Namadendu (Tyagaraja)", "निन्नु विना नामदेंदु", "divine", 3486.4, 3831.1),
    # Stotrams
    ("hanuman-chalisa-pb-sreenivas", "mantra", "hanuman", "Hanuman Chalisa (P.B. Sreenivas)", "हनुमान चालीसा", "pbs", 576.3, 1380.8),
    ("venkatesa-stotram-pb-sreenivas", "mantra", "venkateswara", "Sri Venkatesa Stotram", "श्री वेंकटेश स्तोत्रम्", "pbs", 1383.7, 1577.2),
    ("mahalakshmi-ashtakam-pb-sreenivas", "mantra", "lakshmi", "Mahalakshmi Ashtakam", "महालक्ष्मी अष्टकम्", "pbs", 333.5, 573.3),
    ("vishnu-sahasranamam-mss", "mantra", "vishnu", "Vishnu Sahasranamam (M.S. Subbulakshmi)", "विष्णु सहस्रनाम", "vishnu", 0.5, 1391.2),
    ("kashi-vishwanatha-suprabhatam", "mantra", "shiva", "Kashi Vishwanatha Suprabhatam", "काशी विश्वनाथ सुप्रभातम्", "shiva", 185.8, 846.8),
    ("shiva-panchakshara-stotram", "mantra", "shiva", "Shiva Panchakshara Stotram", "शिव पंचाक्षर स्तोत्रम्", "shiva", 4.4, 181.5),
    ("ganesha-pancharatnam", "mantra", "ganesha", "Ganesha Pancharatnam", "गणेश पंचरत्नम्", "ganesha", 1.2, 277.3),
    ("lakshmi-ashtottaram", "mantra", "lakshmi", "Lakshmi Ashtottaram", "लक्ष्मी अष्टोत्तरम्", "morning", 664.5, 980.6),
    ("durga-pancharatnam", "mantra", "durga", "Durga Pancharatnam", "दुर्गा पंचरत्नम्", "morning", 185.4, 380.5),
    ("bhaja-govindam", "mantra", "krishna", "Bhaja Govindam", "भज गोविन्दम्", "krishna", 0.2, 658.7),
    ("madhurashtakam", "mantra", "krishna", "Madhurashtakam", "मधुराष्टकम्", "krishna", 923.6, 1250.2),
    # Vedic suktams
    ("sri-suktam", "mantra", "lakshmi", "Sri Suktam", "श्री सूक्तम्", "mm-06", 0, None),
    ("purusha-suktam", "mantra", "vishnu", "Purusha Suktam", "पुरुष सूक्तम्", "mm-05", 0, None),
    ("ganapati-suktam", "mantra", "ganesha", "Ganapati Suktam", "गणपति सूक्तम्", "mm-03", 0, None),
    ("devi-suktam", "mantra", "durga", "Devi Suktam", "देवी सूक्तम्", "mm-04", 0, None),
    ("sri-rudram", "mantra", "shiva", "Sri Rudram (Rudra Prashnam)", "श्री रुद्रम्", "mm-07", 0, None),
]

FADE_IN, FADE_OUT = 0.25, 0.5  # cuts sit in the silence between songs; the fades only stop clicks
FADE_OUT_WHOLE = 2.0  # two of the whole uploads stop abruptly on a held note


def probe_seconds(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         check=True, capture_output=True, text=True).stdout
    return float(out.strip())


def cut(src: Path, dst: Path, start: float, end: float | None) -> None:
    length = (end if end is not None else probe_seconds(src)) - start
    fade_out = FADE_OUT if end is not None else FADE_OUT_WHOLE
    fades = ([f"afade=t=in:d={FADE_IN}"] if start > 0 else []) + \
        [f"afade=t=out:st={length - fade_out:.2f}:d={fade_out}"]
    cmd = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(start), "-i", str(src),
           "-t", f"{length:.2f}", "-vn", "-af", ",".join(fades),
           "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", str(dst)]
    subprocess.run(cmd, check=True)


def entry(slug, kind, deity, title, title_hi, source, start, end, seconds: int) -> dict:
    _, file, credit = SOURCES[source]
    whole = start == 0 and end is None
    note = "" if whole else " (trimmed)"
    return {"slug": slug, "kind": kind, "deity": deity, "title": title, "title_hi": title_hi,
            "audio_url": f"{RELEASE}/{slug}.m4a", "duration_sec": seconds, "license": "CC BY 3.0",
            "attribution": f"{credit}{note} · CC BY 3.0 · Wikimedia Commons ({CC_BY_3})",
            "source_url": COMMONS + file}


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "--json-only":
        out_dir = Path(args[1]) if len(args) > 1 else None
    elif len(args) == 2:
        src_dir, out_dir = Path(args[0]), Path(args[1])
        out_dir.mkdir(parents=True, exist_ok=True)
        for slug, *_, source, start, end in TRACKS:
            cut(src_dir / SOURCES[source][0], out_dir / f"{slug}.m4a", start, end)
            print("cut", slug)
    else:
        sys.exit(__doc__)
    old = {t["slug"]: t for t in json.loads(OUT.read_text())["tracks"]} if OUT.exists() else {}
    tracks = []
    for t in TRACKS:
        slug = t[0]
        if out_dir and (out_dir / f"{slug}.m4a").exists():
            seconds = round(probe_seconds(out_dir / f"{slug}.m4a"))
        else:
            seconds = old[slug]["duration_sec"]
        tracks.append(entry(*t, seconds=seconds))
    OUT.write_text(json.dumps({"tracks": tracks}, ensure_ascii=False, indent=1) + "\n")
    print(f"wrote {len(tracks)} tracks to {OUT}")


if __name__ == "__main__":
    main()
