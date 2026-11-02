"""Resolve curated Wikimedia Commons files into app/seed/data/commons.json.

Every file listed here was checked to be public domain, CC0 or CC BY/BY-SA. The script
records the author, licence and source page for attribution, plus resized image URLs
and audio/video transcodes served by Wikimedia. For production, mirror the files to
your own R2 bucket with scripts/mirror_media.py rather than hot-linking at scale.

Usage: python scripts/fetch_commons.py
"""

import html
import json
import re
import time
from pathlib import Path

import httpx

OUT = Path(__file__).resolve().parent.parent / "app" / "seed" / "data" / "commons.json"
API = "https://commons.wikimedia.org/w/api.php"
HEADERS = {"User-Agent": "DevalayContentBuilder/1.0 (https://github.com/ChandraChaan/devalay)"}
ALLOWED = {"Public domain", "CC0", "CC BY 2.5", "CC BY 3.0", "CC BY 4.0", "CC BY-SA 3.0", "CC BY-SA 4.0", "FAL"}

# (deity slug, title, Commons file). The first entry per deity also becomes its portrait.
WALLPAPERS = [
    ("shiva", "Shankar", 'File:A version from the Ravi Varma press- "Shankar," c.1910\'s.jpg'),
    ("shiva", "Shiva, Parvati and Nandi", "File:An Oleograph of Shiva, Parvati and Nandi by Raja Ravi Varma.jpg"),
    ("shiva", "Shiva Parvati", "File:Siva-parvati-by-raja-ravi-varma.jpg"),
    ("shiva", "Descent of Ganga", "File:Ravi Varma-Descent of Ganga.jpg"),
    ("shiva", "Markandeya and Mahadev", "File:Raja Ravi Varma, Markandeya.jpg"),
    ("hanuman", "Hanuman lifts the mountain", "File:HANUMAN LIFTS HILL.jpg"),
    ("hanuman", "Hanuman brings Sanjeevani", "File:Hanuman fetches the herb-bearing mountain, in a print from the Ravi Varma Press, 1910's.jpg"),
    ("hanuman", "Ahiravan Vadh", "File:Killing of Ahi Mahi Ravanas by Hanuman.jpeg"),
    ("rama", "Ram Panchayatan", "File:Ramapanchayan, Raja Ravi Varma (Lithograph).jpg"),
    ("rama", "Shri Ram breaks the bow", "File:Ravi Varma-Rama-breaking-bow.jpg"),
    ("rama", "Bharat Milap", "File:Bharata welcoming Rama, Sita, Lakshmana and Hanuman to Ayodhya by Raja Ravi Varma.jpg"),
    ("rama", "Jatayu Vadh", "File:Raja Ravi Varma, Jatayu vadha, 1906.jpg"),
    ("krishna", "Yashoda with Krishna", "File:Yashoda with Krishna, Raja Ravi Varma.jpg"),
    ("krishna", "Birth of Krishna", "File:Raja Ravi Varma, Birth of Krishna (1890).jpg"),
    ("krishna", "Yashoda adorning Krishna", "File:Raja Ravi Varma, Yasoda Adorning Krishna.jpg"),
    ("radha-krishna", "Radha in the Moonlight", "File:Radha in the Moonlight.jpg"),
    ("radha-krishna", "Radha Madhavam", "File:Radha Madhavam.jpg"),
    ("radha-krishna", "Radha waiting for Krishna", "File:Raja Ravi Varma, Radha Waiting for Krishna.jpg"),
    ("ganesha", "Riddhi Siddhi Ganapati", "File:Ganesh himself has two wives, Riddhi and Siddhi, as in this domestic pose from the Ravi Varma Press, c.1910.jpg"),
    ("ganesha", "Shiva, Parvati and Ganesha", "File:Shiva Parvati Ganesha.jpg"),
    ("ganesha", "Ganapati", "File:Ganapati1.jpg"),
    ("durga", "Mahishasura Mardini", "File:Mahishasura-mardini.jpg"),
    ("durga", "Maa Durga", "File:Durga Mahishasura-mardini, the slayer of the buffalo demon.jpg"),
    ("kali", "Maa Kali", "File:Raja Ravi Varma - Kali.jpg"),
    ("kali", "Kali, Ravi Varma Press", "File:Ravi Verma Press - Kali - 20th-century.jpg"),
    ("lakshmi", "Maa Lakshmi", "File:Raja Ravi Varma, Goddess Lakshmi, 1896.jpg"),
    ("lakshmi", "Lakshmi, 1930s", "File:Lakshmi, by Raja Ravi Varma, 1930s.jpg"),
    ("lakshmi", "Lakshmi embellished", "File:Lakshmi Embellished, by Ravi Varma Press, edit.jpg"),
    ("saraswati", "Maa Saraswati", "File:Raja Ravi Varma, Goddess Saraswati.jpg"),
    ("saraswati", "Saraswati, 1896", "File:Goddess Saraswati by Raja Ravi Varma, 1896.jpg"),
    ("saraswati", "Lakshmi and Saraswati", "File:Lakshmi Saraswati Sanyog, by Raja Ravi Varma.jpg"),
    ("vishnu", "Sheshnarayan", "File:Raja Ravi Varma, Seshanarayana (Oleographic print).jpg"),
    ("vishnu", "Garuda Vahan Vishnu", 'File:"Garuda Vahan Vishnu," from the Ravi Varma studio, c.1910\'s Source- ebay, Oct. 2009.jpg'),
    ("vishnu", "Matsya Avatar", "File:Matsya Avatar of Vishnu Printed by Ravi Varma Press - Vintage Poster.jpg"),
    ("shani", "Shani Dev", "File:Shani Deva.jpg"),
    ("surya", "Surya Narayan", "File:Surya Narayana.jpg"),
    ("surya", "Surya in his chariot", "File:Surya the sun deity driving in his chariot. Gouache drawing. Wellcome V0045217.jpg"),
]

# (slug, kind, deity, title, title_hi, Commons file)
AUDIO = [
    ("gayatri-mantra-chant", "mantra", "surya", "Gayatri Mantra", "गायत्री मंत्र", "File:Gayatri mantra.ogg"),
    ("gayatri-mantra-recitation", "mantra", "surya", "Gayatri Mantra (recitation)", "गायत्री मंत्र (पाठ)", "File:Gayatri Mantra as it is.ogg"),
    ("mahamrityunjaya-chant", "mantra", "shiva", "Mahamrityunjaya Mantra", "महामृत्युंजय मंत्र", "File:Mrityunjaya.ogg"),
    ("om-namah-shivaya-khajuraho", "mantra", "shiva", "Om Namah Shivaya (Khajuraho)", "ॐ नमः शिवाय", "File:Om Namah Shivaya Performance at Khajuraho - 2026.ogg"),
    ("aarti-ganpati-vandana", "aarti", "ganesha", "Ganpati Vandana Aarti", "गणपति वंदना आरती", "File:Aarti Puja, Ganpati Vandana.ogg"),
    ("aarti-lakshmi", "aarti", "lakshmi", "Lakshmi Aarti", "लक्ष्मी आरती", "File:Aarti Puja, Lakshmi Laxmi.ogg"),
    ("aarti-santoshi-mata", "aarti", "durga", "Santoshi Mata Aarti", "संतोषी माता आरती", "File:Aarti Puja, deity Santoshi.ogg"),
    ("aarti-radha-govind", "aarti", "radha-krishna", "Aarti Shri Radha Govind", "आरती श्री राधा गोविंद", "File:Aarti Shri Radha Govind, Musical Puja Prayer.ogg"),
    ("sanskrit-aarti-prayer", "aarti", "general", "Sanskrit Aarti Prayer", "संस्कृत आरती प्रार्थना", "File:Sanskrit chanting for Aarti Puja Prayer - Female Voice.ogg"),
    ("guru-stotram", "mantra", "general", "Guru Stotram", "गुरु स्तोत्रम्", "File:Sanskrit Chanting Guru Stotram.ogg"),
    ("shri-vyadeshwar-aarti", "aarti", "shiva", "Shri Vyadeshwar Aarti", "श्री व्याडेश्वर आरती", "File:Shri Vyadshwar Aarti Audio file.ogg"),
    ("kamakhya-temple-bhajan", "bhajan", "durga", "Bhajan at Kamakhya Temple", "कामाख्या मंदिर भजन", "File:Local musicians singing bhajan at Kamakhya temple, Guwahati, Assam, India.ogg"),
    ("guru-tum-na-mile", "bhajan", "general", "Guru Tum Na Mile", "गुरु तुम ना मिले", "File:Guru tum na mile.ogg"),
    ("kirtan-hindi", "bhajan", "krishna", "Kirtan in Hindi", "हिंदी कीर्तन", "File:Kirtana in Hindi.ogg"),
    ("yasomati-nandana", "bhajan", "krishna", "Yasomati Nandana (Nama Kirtan)", "यशोमती नंदन", "File:Yasomati-nandana (Sri Nama-kirtana).ogg"),
    ("niraas-nahi-hone-dega", "bhajan", "general", "Niraas Nahi Hone Dega (Awadhi bhajan)", "निराश नहीं होने देगा", "File:Niraas Nahi Hone Dega - Purvanchali-Bhojpuri-Awadhi Bhajan.ogg"),
    ("pasaydan", "bhajan", "general", "Pasaydan (Sant Dnyaneshwar)", "पसायदान", "File:Pasaydan.ogg"),
    ("samgacchadhvam", "mantra", "general", "Samgacchadhvam (Rigveda)", "संगच्छध्वम्", "File:Samgacchadvam.OGG"),
    ("vamadevyam-sama", "mantra", "general", "Vamadevyam Sama (Samaveda)", "वामदेव्यं साम", "File:वामदेव्यं साम Vamadevyam sama.ogg"),
    ("rathantaram-sama", "mantra", "general", "Rathantaram (Samaveda)", "रथन्तरम्", "File:रथन्तरम् Rathantaram.ogg"),
    ("brihat-sama", "mantra", "general", "Brihat Sama (Samaveda)", "बृहत् साम", "File:बृहत् साम Brihat sama.ogg"),
    ("durga-puja-dhak", "dhun", "durga", "Durga Puja Dhak", "दुर्गा पूजा ढाक", "File:Durga Puja Dhak Dhol.ogg"),
]

VIDEOS = [
    ("Raja Harishchandra (1913)", "Dadasaheb Phalke's landmark silent film on the truthful king Harishchandra, India's first feature film.", "File:Raja Harishchandra (1913).webm", 1913),
    ("Shree Krishna Janma (1918)", "Phalke's silent film on the birth and childhood miracles of Shri Krishna.", "File:Shree Krishna Janma (1918).webm", 1918),
    ("Kaliya Mardan (1919)", "The childhood of Krishna and his victory over the serpent Kaliya, directed by Dadasaheb Phalke.", "File:Kaliya Mardan, The Childhood of Krishna, 1919.webm", 1919),
    ("Lanka Dahan (1917)", "Surviving fragment of Phalke's Ramayan film in which Hanuman sets Lanka ablaze.", "File:Lanka Dahan (1917) by Dadasaheb Phalke.webm", 1917),
]


def strip_html(value: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", value or ""))).strip()


def query(titles: list[str], **extra) -> dict:
    params = {"action": "query", "format": "json", "formatversion": "2", "titles": "|".join(titles), **extra}
    for attempt in range(4):
        r = httpx.get(API, params=params, headers=HEADERS, timeout=60)
        if r.status_code == 429:
            time.sleep(5 * (attempt + 1))
            continue
        r.raise_for_status()
        return {p["title"]: p for p in r.json()["query"]["pages"]}
    raise RuntimeError("Commons API rate limited")


def resolve(titles: list[str], width: int | None = None, video: bool = False) -> dict:
    out = {}
    for i in range(0, len(titles), 20):
        batch = titles[i:i + 20]
        extra = {"prop": "imageinfo|videoinfo" if video else "imageinfo",
                 "iiprop": "url|size|extmetadata|mime|mediatype", "iiextmetadatafilter": "Artist|LicenseShortName|LicenseUrl|Credit"}
        if width:
            extra["iiurlwidth"] = str(width)
        if video:
            extra["viprop"] = "derivatives"
        pages = query(batch, **extra)
        for t in batch:
            norm = t.replace("_", " ")
            page = pages.get(norm) or next((p for k, p in pages.items() if k.lower() == norm.lower()), None)
            if not page or "imageinfo" not in page:
                print("  MISSING", t)
                continue
            out[t] = page
        time.sleep(1)
    return out


def meta(page: dict) -> dict:
    ii = page["imageinfo"][0]
    m = ii.get("extmetadata", {})
    lic = m.get("LicenseShortName", {}).get("value", "")
    artist = strip_html(m.get("Artist", {}).get("value", "")) or "Unknown"
    if lic not in ALLOWED:
        raise ValueError(f"{page['title']}: licence {lic!r} not allowed")
    attribution = f"{artist} · {lic} · Wikimedia Commons"
    if lic == "FAL":
        attribution += " (https://artlibre.org/licence/lal/en/)"
    elif lic.startswith("CC") and lic != "CC0":
        attribution += f" ({m.get('LicenseUrl', {}).get('value', '')})"
    return {"license": lic, "attribution": attribution[:480], "source_url": ii["descriptionurl"]}


def clean_url(url: str) -> str:
    return url.split("?utm_source")[0] if url else url


def duration(page: dict) -> int:
    return round(float(page["imageinfo"][0].get("duration") or 0))


def main() -> None:
    walls = resolve([w[2] for w in WALLPAPERS], width=1080)
    smalls = resolve([w[2] for w in WALLPAPERS], width=480)
    wallpapers, portraits = [], {}
    for deity, title, file in WALLPAPERS:
        page = walls.get(file)
        if not page:
            continue
        ii = page["imageinfo"][0]
        small = clean_url(smalls[file]["imageinfo"][0].get("thumburl") or ii["url"])
        wallpapers.append({"deity": deity, "title": title, "image_url": clean_url(ii.get("thumburl") or ii["url"]),
                           "thumb_url": small, "original_url": clean_url(ii["url"]),
                           "width": ii.get("thumbwidth") or ii["width"],
                           "height": ii.get("thumbheight") or ii["height"], **meta(page)})
        portraits.setdefault(deity, small)

    audio_pages = resolve([a[5] for a in AUDIO], video=True)
    tracks = []
    for slug, kind, deity, title, title_hi, file in AUDIO:
        page = audio_pages.get(file)
        if not page:
            continue
        ii = page["imageinfo"][0]
        derivs = page.get("videoinfo", [{}])[0].get("derivatives", [])
        mp3 = next((d["src"] for d in derivs if d.get("type", "").startswith("audio/mpeg")), None)
        tracks.append({"slug": slug, "kind": kind, "deity": deity, "title": title, "title_hi": title_hi,
                       "audio_url": clean_url(mp3 or ii["url"]), "original_url": clean_url(ii["url"]),
                       "duration_sec": duration(page),
                       **meta(page)})

    video_pages = resolve([v[2] for v in VIDEOS], width=640, video=True)
    videos = []
    for title, desc, file, year in VIDEOS:
        page = video_pages.get(file)
        if not page:
            continue
        ii = page["imageinfo"][0]
        derivs = page.get("videoinfo", [{}])[0].get("derivatives", [])
        # VP9 WebM plays on every Android version we support and is far smaller than the MOV transcode.
        playable = [d for d in derivs if "webm" in d.get("type", "") and d.get("height", 0) <= 480]
        best = max(playable, key=lambda d: d.get("height", 0))["src"] if playable else ii["url"]
        videos.append({"title": title, "description": desc, "video_url": clean_url(best),
                       "original_url": clean_url(ii["url"]), "thumbnail_url": clean_url(ii.get("thumburl", "")),
                       "year": year, "duration_sec": duration(page),
                       **meta(page)})

    OUT.write_text(json.dumps({"wallpapers": wallpapers, "portraits": portraits, "tracks": tracks, "videos": videos},
                              ensure_ascii=False, indent=1))
    print(f"wrote {len(wallpapers)} wallpapers, {len(tracks)} tracks, {len(videos)} videos to {OUT}")


if __name__ == "__main__":
    main()
