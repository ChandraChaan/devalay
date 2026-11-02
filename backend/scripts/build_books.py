"""Import public-domain scriptures from Project Gutenberg into app/seed/data/books.json.

All four works were published before 1930 and their translators died more than
70 years ago, so they are public domain in India, the US, the UK and the EU. The
Project Gutenberg licence header and trademark are stripped, as the PG licence
requires when redistributing the plain text.

Usage: python scripts/build_books.py [download dir]
"""

import json
import re
import sys
import time
from pathlib import Path

import httpx

OUT = Path(__file__).resolve().parent.parent / "app" / "seed" / "data" / "books.json"
HEADERS = {"User-Agent": "DevalayContentBuilder/1.0 (https://github.com/ChandraChaan/devalay)"}
ROMAN = re.compile(r"^[IVXLC]+$")


def fetch(book_id: int, cache: Path) -> str:
    path = cache / f"pg{book_id}.txt"
    if not path.exists():
        r = httpx.get(f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt", headers=HEADERS,
                      follow_redirects=True, timeout=120)
        r.raise_for_status()
        path.write_text(r.text)
        time.sleep(2)
    text = path.read_text().replace("\r\n", "\n")
    start = text.index("\n", text.index("*** START OF THE PROJECT GUTENBERG EBOOK")) + 1
    end = text.index("*** END OF THE PROJECT GUTENBERG EBOOK")
    return text[start:end]


def tidy(body: str) -> str:
    lines = [line.rstrip() for line in body.strip("\n").split("\n")]
    # Remove the shared leading indent of verse translations.
    indents = [len(line) - len(line.lstrip()) for line in lines if line.strip()]
    pad = min(indents) if indents else 0
    out = "\n".join(line[pad:] for line in lines)
    out = re.sub(r"\n{3,}", "\n\n", out)
    return out.strip()


def split(text: str, pattern: str, title_of) -> list[dict]:
    matches = list(re.finditer(pattern, text, flags=re.M))
    chapters = []
    for i, m in enumerate(matches):
        body = text[m.end(): matches[i + 1].start() if i + 1 < len(matches) else len(text)]
        chapters.append({"number": i + 1, "title": title_of(m, i), "body": tidy(body)})
    return chapters


def song_celestial(cache: Path) -> dict:
    text = fetch(2388, cache)
    toc = re.findall(r"^\s+([IVX]+)\. (.+)$", text[: text.index("CHAPTER I\n")], flags=re.M)
    names = {r: n.strip().title() for r, n in toc}
    body = text[text.index("\nCHAPTER I\n"):]
    chapters = split(body, r"^\s*CHAPTER ([IVXL]+)\s*$",
                     lambda m, i: f"Chapter {i + 1}: {names.get(m.group(1), '')}".rstrip(": "))
    return {"slug": "song-celestial", "title": "The Song Celestial (Bhagavad Gita)", "title_hi": "श्रीमद्भगवद्गीता (पद्यानुवाद)",
            "author": "Translated by Sir Edwin Arnold (1885)", "language": "en", "license": "Public domain",
            "source_url": "https://www.gutenberg.org/ebooks/2388", "attribution": "Sir Edwin Arnold · Project Gutenberg",
            "description": "Edwin Arnold's celebrated verse rendering of the Bhagavad Gita, admired by Gandhi.",
            "chapters": chapters}


def ramayan(cache: Path) -> dict:
    text = fetch(24869, cache)
    text = text[text.index("\nBOOK I.(6)"):]
    text = text[: text.index("\nINDEX OF PRINCIPAL NAMES")]
    text = re.sub(r"\((\d+)\)", "", text)  # footnote markers
    book_starts = [(m.start(), m.group(1)) for m in re.finditer(r"^BOOK ([IVX]+)\.", text, flags=re.M)]

    def title(m, i):
        book = next((b for pos, b in reversed(book_starts) if pos <= m.start()), "I")
        return f"Book {book}, Canto {m.group(1)}: {m.group(2).strip().rstrip('.')}"

    chapters = split(text, r"^Canto ([IVXLC]+)\. (.+)$", title)
    for ch in chapters:  # drop the next book's heading caught at the end of a canto
        ch["body"] = re.sub(r"\n+BOOK [IVX]+\.\s*$", "", ch["body"]).strip()
    return {"slug": "ramayan-griffith", "title": "The Ramayan of Valmiki", "title_hi": "वाल्मीकि रामायण",
            "author": "Translated by Ralph T. H. Griffith (1870-1874)", "language": "en", "license": "Public domain",
            "source_url": "https://www.gutenberg.org/ebooks/24869", "attribution": "Ralph T. H. Griffith · Project Gutenberg",
            "description": "The complete verse translation of Valmiki's Ramayan, canto by canto, including Sundar Kand (Book V).",
            "chapters": chapters}


def mahabharata(cache: Path) -> dict:
    text = fetch(19630, cache)
    text = text[text.index("\nBOOK I\n"):]
    end = text.find("\nCONCLUSION")
    tail = text[end:] if end > 0 else ""
    text = text[:end] if end > 0 else text

    def title(m, i):
        # "BOOK I" is followed by a Sanskrit title and an English gloss, e.g. "ASTRA DARSANA / (The Tournament)".
        head = [line.strip() for line in text[m.end(): m.end() + 300].split("\n") if line.strip()][:2]
        if len(head) == 2 and head[1].startswith("("):
            return f"Book {m.group(1)}: {head[0].title()} {head[1]}"
        return f"Book {m.group(1)}"

    chapters = split(text, r"^BOOK ([IVX]+)\s*$", title)
    if tail:
        cut = re.search(r"\n\s*\n\s*(FOOTNOTES|INDEX|APPENDIX)", tail)
        chapters.append({"number": len(chapters) + 1, "title": "Conclusion",
                         "body": tidy(tail[len("\nCONCLUSION"): cut.start() if cut else len(tail)])})
    return {"slug": "mahabharata-dutt", "title": "The Mahabharata (condensed)", "title_hi": "महाभारत (संक्षिप्त)",
            "author": "Condensed into English verse by Romesh Chunder Dutt (1898)", "language": "en",
            "license": "Public domain", "source_url": "https://www.gutenberg.org/ebooks/19630",
            "attribution": "Romesh Chunder Dutt · Project Gutenberg",
            "description": "The great epic retold in twelve books, from the tournament to the final ascent of the Pandavas.",
            "chapters": chapters}


def upanishads(cache: Path) -> dict:
    text = fetch(3283, cache)
    text = text[text.index("\n                         Isa-Upanishad"):]
    chapters = split(text, r"^\s{10,}([A-Za-z]+-Upanishad)\s*$", lambda m, i: m.group(1).replace("-", " "))
    # Each Upanishad is preceded by an introduction carrying the same heading.
    for prev, cur in zip(chapters, chapters[1:]):
        if prev["title"] == cur["title"]:
            prev["title"] += ": Introduction"
    return {"slug": "upanishads-paramananda", "title": "The Upanishads", "title_hi": "उपनिषद्",
            "author": "Translated by Swami Paramananda (1919)", "language": "en", "license": "Public domain",
            "source_url": "https://www.gutenberg.org/ebooks/3283", "attribution": "Swami Paramananda · Project Gutenberg",
            "description": "The Isa, Katha and Kena Upanishads with peace chants and gentle commentary.",
            "chapters": chapters}


def main(cache_dir: str) -> None:
    cache = Path(cache_dir)
    cache.mkdir(parents=True, exist_ok=True)
    books = [song_celestial(cache), ramayan(cache), mahabharata(cache), upanishads(cache)]
    for b in books:
        print(f"{b['slug']}: {len(b['chapters'])} chapters, {sum(len(c['body']) for c in b['chapters'])} chars;"
              f" first: {b['chapters'][0]['title']!r}, last: {b['chapters'][-1]['title']!r}")
    OUT.write_text(json.dumps({"books": books}, ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/devalay-gutenberg")
