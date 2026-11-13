"""Check that every verse in assets/data/thoughts.json appears in the page its `source` names.

Usage (from app/): python3 -I tool/thoughts/verify.py [thoughts.json or per-language lists ...]
Pages are fetched (Wikisource through ?action=raw) and cached in tool/thoughts/.cache (not committed).
Verse and page are compared as letters and combining marks only, so markup, punctuation, digits,
line breaks and zero-width joiners do not matter; any other difference fails.
"""
import hashlib
import json
import re
import sys
import time
import unicodedata
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = HERE / ".cache"


def fetch(url):
    if "wikisource.org/wiki/" in url and "action=raw" not in url:
        url = url + ("&" if "?" in url else "?") + "action=raw"
    CACHE.mkdir(exist_ok=True)
    f = CACHE / hashlib.sha1(url.encode()).hexdigest()
    if f.exists():
        return f.read_text()
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "devalay-verse-check/1.0"})
            body = urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "replace")
            f.write_text(body)
            return body
        except Exception:
            if attempt == 3:
                raise
            time.sleep(5 * (attempt + 1))


def norm(s):
    s = unicodedata.normalize("NFC", s)
    s = re.sub(r"<[^>]+>", " ", s)
    s = re.sub(r"\{\{[^{}|]*\|", " ", s)
    s = s.replace("‌", "").replace("‍", "")
    return "".join(c for c in s if unicodedata.category(c)[0] in "LM")


def entries(path):
    data = json.loads(Path(path).read_text())
    if isinstance(data, dict):
        for lang, items in data["languages"].items():
            for i, e in enumerate(items):
                yield f"{lang}[{i}]", e
    else:
        for i, e in enumerate(data):
            yield f"{Path(path).stem}[{i}]", e


def main():
    paths = sys.argv[1:] or [str(HERE.parents[1] / "assets/data/thoughts.json")]
    bad = total = 0
    pages = {}
    for path in paths:
        for name, e in entries(path):
            total += 1
            src = e.get("source", "")
            try:
                if src not in pages:
                    pages[src] = norm(fetch(src))
            except Exception as ex:
                print(f"{name} fetch failed {src}: {ex}")
                bad += 1
                continue
            t = norm(e["text"])
            if not t or t not in pages[src]:
                bad += 1
                print(f"{name} NOT FOUND in {src}: {e['text'][:60]!r}")
    print(f"{total - bad}/{total} verses found in their sources")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
