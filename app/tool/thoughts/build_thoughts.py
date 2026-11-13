"""Build assets/data/thoughts.json from per-language verse lists.

Each input is <dir>/<code>.json: a list of {text, author, author_native, work, ref, meaning, meaning_en, source},
where text was copied by script from the source page (never typed) and meanings are our own words. "sa" holds
Sanskrit subhashitas for English readers. Run tool/thoughts/verify.py afterwards; it must find every verse.

Usage (from app/): python3 tool/thoughts/build_thoughts.py <dir>
"""
import json
import sys
from pathlib import Path

APP = Path(__file__).resolve().parents[2]
OUT = APP / "assets/data/thoughts.json"
ORDER = ["sa", "hi", "bn", "mr", "te", "ta", "gu", "kn", "ml", "or", "pa"]
FIELDS = ["text", "author", "author_native", "work", "ref", "meaning", "meaning_en", "source"]


def main():
    src = Path(sys.argv[1])
    languages = {}
    for code in ORDER:
        f = src / f"{code}.json"
        if not f.exists():
            print(f"missing {f}")
            continue
        items = json.loads(f.read_text())
        seen = set()
        out = []
        for e in items:
            if e["text"] in seen:
                continue
            seen.add(e["text"])
            for k in ("text", "author", "meaning", "meaning_en", "source"):
                assert str(e.get(k, "")).strip(), (code, k, e.get("text", "")[:40])
            out.append({k: str(e.get(k, "") or "").strip() if k != "text" else e["text"].strip() for k in FIELDS})
        languages[code] = out
        print(f"{code}: {len(out)}")
    OUT.write_text(json.dumps({"schema": 1, "languages": languages}, ensure_ascii=False, indent=1) + "\n")
    print(f"-> {OUT.relative_to(APP)}")


if __name__ == "__main__":
    main()
