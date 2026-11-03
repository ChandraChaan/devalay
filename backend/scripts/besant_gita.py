"""Fill the English verses of app/seed/data/gita.json from Annie Besant's translation.

The Bhagavad-Gita, translated by Annie Besant (4th edition, 1922; Besant died in 1933) is
public domain worldwide, including the USA. Wikisource has a proofread transcription with
each verse's Sanskrit followed by its English, which this script pairs by verse number.

Usage: python scripts/besant_gita.py [CACHE_DIR]
  Downloaded pages are kept in CACHE_DIR (default: a temp dir) so re-runs stay offline.
"""

import html
import json
import re
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

GITA = Path(__file__).resolve().parent.parent / "app" / "seed" / "data" / "gita.json"
SOURCE = "https://en.wikisource.org/w/index.php?title=Bhagavad-Gita_(Besant_4th)/Discourse_{}&action=render"
TRANSLATOR = "Annie Besant"
DEVANAGARI = re.compile(r"[ऀ-ॿ]")
DIGITS = str.maketrans("०१२३४५६७८९", "0123456789")


def page(n: int, cache: Path) -> str:
    f = cache / f"discourse-{n}.html"
    if not f.exists():
        req = urllib.request.Request(SOURCE.format(n), headers={"User-Agent": "Devalay content import"})  # noqa: S310
        with urllib.request.urlopen(req, timeout=60) as r:  # noqa: S310 (fixed https URL)
            f.write_bytes(r.read())
        time.sleep(3)  # Wikimedia rate limits bulk fetches
    return f.read_text()


def plain(markup: str) -> str:
    t = re.sub(r"data-mw=('[^']*'|\"[^\"]*\")", "", markup)
    t = re.sub(r"<style.*?</style>", "", t, flags=re.S)
    t = re.sub(r'<sup[^>]*class="reference".*?</sup>', "", t, flags=re.S)
    t = re.sub(r'<ol class="references">.*', "", t, flags=re.S)
    t = re.sub(r"<br\s*/?>|</(p|div)>", "\n", t)
    t = html.unescape(re.sub(r"<[^>]+>", "", t)).replace("​", "")
    return re.sub(r"\[\d+\]", "", t)


def verses(text: str) -> dict[int, str]:
    """Each Sanskrit verse ends in '॥ N ॥'; its English follows until the next Devanagari line."""
    out: dict[int, str] = {}
    parts = re.split(r"॥\s*([०-९]+)\s*॥", text)
    for k in range(1, len(parts) - 1, 2):
        lines = []
        for line in parts[k + 1].split("\n"):
            if DEVANAGARI.search(line):
                break
            if line.strip():
                lines.append(line.strip())
        english = re.sub(r"\s+", " ", " ".join(lines)).strip()
        english = re.sub(r"\s*\(?\d+(-\d+)?\)?\s*$", "", english)  # the printed "(N)", sometimes mistyped
        out.setdefault(int(parts[k].translate(DIGITS)), english)  # the colophon reuses the chapter number
    return out


def main() -> None:
    cache = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(tempfile.mkdtemp(prefix="besant-"))
    cache.mkdir(parents=True, exist_ok=True)
    data = json.loads(GITA.read_text())
    english = {c: verses(plain(page(c, cache))) for c in range(1, 19)}
    missing = [f"{v['chapter']}.{v['verse']}" for v in data["verses"] if not english[v["chapter"]].get(v["verse"])]
    if missing:
        sys.exit(f"no English found for {missing}")
    for v in data["verses"]:
        v["translation_en"] = english[v["chapter"]][v["verse"]]
        v["translation_author"] = TRANSLATOR
    GITA.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    print(f"wrote {len(data['verses'])} verses by {TRANSLATOR} to {GITA}")


if __name__ == "__main__":
    main()
