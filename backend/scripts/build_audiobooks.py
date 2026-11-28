"""Write app/assets/data/audiobooks.json: human-voice audio for the Gita and the Read section.

Input is a research file (JSON) listing verified recordings with their licences:
  * LibriVox audiobooks (public domain: volunteers dedicate their readings to the public domain, and every
    translation here is out of copyright), streamed from archive.org;
  * Sanskrit chanting of Bhagavad Gita chapters 1-3 from Wikimedia Commons (CC BY-SA 4.0, "own work" by the
    performers Soorya Hebbar and NehalDaveND), streamed as Wikimedia's MP3 transcodes.
No Telugu or Hindi Gita recording under an open licence was found; none is included.

Usage: python scripts/build_audiobooks.py RESEARCH.json
"""

import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "app" / "assets" / "data" / "audiobooks.json"

GROUPS = {
    9324: ("gita", "song-celestial"), 1497: ("gita", "song-celestial"),
    2731: ("ramayana", "ramayan-griffith"), 5427: ("ramayana", "ramayan-griffith"),
    6515: ("ramayana", "ramayan-griffith"), 7336: ("ramayana", "ramayan-griffith"),
    7905: ("ramayana", "ramayan-griffith"), 7988: ("ramayana", "ramayan-griffith"),
    5143: ("mahabharata", "mahabharata-dutt"),
}
UPANISHADS = {9766, 9770, 9718, 9701, 9742, 9777, 9787, 9811, 9839, 9862, 9660, 9885}


def main(src: Path) -> None:
    r = json.loads(src.read_text())
    english = {}
    for e in r["gita_english"]:
        if e.get("librivox_id") != 9324:
            continue
        english[str(e["section"])] = {"title": e["title"], "url": e["url"], "seconds": round(e["seconds"])}
    sanskrit: dict[str, list] = {}
    performers = set()
    def order(e):  # verses in order; the closing colophon ("iti ...") after the last verse
        v = e["verse"]
        return e["chapter"], v if isinstance(v, int) else (0 if v is None else 999)

    for e in sorted(r["gita_sanskrit"], key=order):
        performers.add(e["performer"])
        sanskrit.setdefault(str(e["chapter"]), []).append({
            "verse": e["verse"] if isinstance(e["verse"], int) else None, "title": e["title"], "url": e.get("url_mp3_transcode") or e["url"],
            "seconds": round(e["seconds"]), "performer": e["performer"], "source": e["source_page"]})
    books = []
    for b in r["audiobooks"]:
        group, app_book = GROUPS.get(b["id"], ("upanishads", "upanishads-paramananda") if b["id"] in UPANISHADS
                                     else ("more", None))
        books.append({
            "id": f"lv-{b['id']}", "group": group, "app_book": app_book, "title": b["title"],
            "author": b.get("author") or "", "translator": b.get("translator") or "",
            "readers": b.get("readers") or [], "license": "Public domain (LibriVox)", "source": b["librivox_url"],
            "seconds": round(b.get("seconds_total") or sum(s["seconds"] for s in b["sections"])),
            "language": b.get("language") or "English",
            "sections": [{"title": s["title"], "url": s["url"], "seconds": round(s["seconds"]),
                          "reader": s.get("reader") or ""} for s in b["sections"]],
        })
    data = {
        "schema": 1, "version": 1,
        "gita": {
            "english": {"title": "The Song Celestial (tr. Sir Edwin Arnold)", "reader": "Jothi Tharavant",
                        "license": "Public domain (LibriVox)", "source": "https://librivox.org/the-bhagavad-gita/",
                        "chapters": english},
            "sanskrit": {"license": "CC BY-SA 4.0", "license_url": "https://creativecommons.org/licenses/by-sa/4.0/",
                         "performers": sorted(performers), "chapters": sanskrit},
        },
        "books": books,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print(OUT, len(books), "books,", sum(len(b["sections"]) for b in books), "sections")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
