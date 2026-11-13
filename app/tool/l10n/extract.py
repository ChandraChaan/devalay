"""Collect every English UI string and Panchang name the app shows, for translators.

Writes tool/l10n/strings.json: a list of {"en", "hi", "te", "where"} entries. English is the key that
lib/l10n/<lang>.dart files translate; Hindi and Telugu are given as context. Interpolations are
replaced by numbered placeholders, so "$major festivals" becomes "{0} festivals".

Usage (from app/): python3 tool/l10n/extract.py
"""

import ast
import json
import re
import sys
from pathlib import Path

APP = Path(__file__).resolve().parents[2]
BACKEND = APP.parent / "backend"
OUT = APP / "tool" / "l10n" / "strings.json"


def skip_ws(s: str, i: int) -> int:
    while i < len(s):
        if s[i].isspace():
            i += 1
        elif s.startswith("//", i):
            i = s.find("\n", i)
            i = len(s) if i < 0 else i
        elif s.startswith("/*", i):
            i = s.index("*/", i) + 2
        else:
            break
    return i


def parse_literal(s: str, i: int):
    """One Dart string literal at i -> (text with {n} placeholders, end, placeholder count) or None."""
    raw = False
    if i >= len(s):
        return None
    if s[i] == "r" and i + 1 < len(s) and s[i + 1] in "'\"":
        raw, i = True, i + 1
    if s[i] not in "'\"":
        return None
    q = s[i] * 3 if s.startswith(s[i] * 3, i) else s[i]
    i += len(q)
    out, n = [], 0
    while not s.startswith(q, i):
        c = s[i]
        if c == "\\" and not raw:
            nxt = s[i + 1]
            out.append({"n": "\n", "t": "\t", "'": "'", '"': '"', "\\": "\\", "$": "$"}.get(nxt, nxt))
            i += 2
        elif c == "$" and not raw:
            if s[i + 1] == "{":
                depth, j = 1, i + 2
                while depth:
                    if s[j] == "{":
                        depth += 1
                    elif s[j] == "}":
                        depth -= 1
                    elif s[j] in "'\"":
                        lit = parse_literal(s, j)
                        j = lit[1] - 1 if lit else j
                    j += 1
                i = j
            else:
                m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", s[i + 1:])
                i += 1 + len(m.group(0))
            out.append("{%d}" % n)
            n += 1
        else:
            out.append(c)
            i += 1
    return "".join(out), i + len(q), n


def parse_strings(s: str, i: int):
    """Adjacent literals ('a' 'b') -> joined text, or None if the argument is not a plain literal."""
    i = skip_ws(s, i)
    parts, count = [], 0
    while True:
        lit = parse_literal(s, i)
        if not lit:
            break
        text, i, n = lit
        # Renumber placeholders of later parts.
        parts.append(re.sub(r"\{(\d+)\}", lambda m: "{%d}" % (int(m.group(1)) + count), text))
        count += n
        i = skip_ws(s, i)
    if not parts:
        return None
    end = skip_ws(s, i)
    if end < len(s) and s[end] not in ",)":
        return None  # 'a' + x, 'a'.toUpperCase() ...
    return "".join(parts), end


def skip_arg(s: str, i: int) -> int:
    depth = 0
    while True:
        c = s[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return i
            depth -= 1
        elif c == "," and depth == 0:
            return i
        elif c in "'\"":
            lit = parse_literal(s, i)
            if lit:
                i = lit[1]
                continue
        i += 1


def calls(src: str, name: str):
    for m in re.finditer(r"\b%s\(" % name, src):
        i = m.end()
        i = skip_arg(src, i)  # lang / ref
        args = []
        for _ in range(3):
            if src[i] != ",":
                break
            got = parse_strings(src, i + 1)
            if not got:
                args = None
                break
            args.append(got[0])
            i = got[1]
        if args and len(args) == 3:
            yield args


def main():
    entries: dict[str, dict] = {}

    def add(en, hi="", te="", where=""):
        en = en.strip()
        if not en or not re.search(r"[A-Za-z]", en):
            return
        e = entries.setdefault(en, {"en": en, "hi": hi, "te": te, "where": where})
        e["hi"] = e["hi"] or hi
        e["te"] = e["te"] or te

    for path in sorted((APP / "lib").rglob("*.dart")):
        if "/l10n/" in str(path):
            continue
        src = path.read_text()
        rel = str(path.relative_to(APP))
        for fn in ("t3", "l3"):
            for en, hi, te in calls(src, fn):
                add(en, hi, te, rel)

    # Keyed UI strings.
    i18n = (APP / "lib/core/i18n.dart").read_text()
    for m in re.finditer(r"'en': (\"[^\"]*\"|'[^']*'), 'hi': ('[^']*'), 'te': ('[^']*')", i18n):
        add(ast.literal_eval(m.group(1)), ast.literal_eval(m.group(2)), ast.literal_eval(m.group(3)), "i18n")
    for m in re.finditer(r"'en': ('[^']*'|\"[^\"]*\"),\n\s*'hi': ('[^']*'),\n\s*'te': ('[^']*')", i18n):
        add(ast.literal_eval(m.group(1)), ast.literal_eval(m.group(2)), ast.literal_eval(m.group(3)), "i18n")

    # Glossary: [title en, hi, te, meaning en, hi, te].
    glossary = (APP / "lib/core/glossary.dart").read_text()
    for block in re.findall(r"\[\n(.*?)\n  \],", glossary, flags=re.S):
        items = []
        i = 0
        while True:
            got = parse_strings(block, i)
            if not got:
                break
            items.append(got[0])
            i = got[1] + 1
        if len(items) == 6:
            add(items[0], items[1], items[2], "glossary")
            add(items[3], items[4], items[5], "glossary")

    # Panchang names from the backend engine, with Telugu from core/telugu.dart.
    sys.path.insert(0, str(BACKEND))
    src = (BACKEND / "app/services/panchang.py").read_text()
    lists = {}
    for name in ("TITHI_NAMES", "NAKSHATRA_NAMES", "YOGA_NAMES", "MONTH_NAMES", "VARA_NAMES", "RASHI_NAMES",
                 "SAMVATSARA_NAMES"):
        m = re.search(name + r" = (\[.*?\])\n", src, flags=re.S)
        lists[name] = ast.literal_eval(m.group(1))
    telugu = (APP / "lib/core/telugu.dart").read_text()

    def te_list(name):
        m = re.search(r"const %s = \[(.*?)\];" % name, telugu, flags=re.S)
        return re.findall(r"'([^']*)'", m.group(1)) if m else []

    def te_map(name):
        m = re.search(r"const %s = <String, String>\{(.*?)\};" % name, telugu, flags=re.S) or re.search(
            r"const %s = \{(.*?)\};" % name, telugu, flags=re.S)
        return dict(re.findall(r"'([^']*)': '([^']*)'", m.group(1))) if m else {}

    for n in lists["TITHI_NAMES"] + ["Purnima", "Amavasya"]:
        add(n, "", te_map("teluguTithi").get(n, ""), "tithi name")
    for n in ("Shukla", "Krishna"):
        add(n, "", te_map("teluguPaksha").get(n, ""), "paksha")
    tn = te_list("teluguNakshatra")
    for i, n in enumerate(lists["NAKSHATRA_NAMES"]):
        add(n, "", tn[i + 1] if len(tn) > i + 1 else "", "nakshatra name")
    ty = te_list("teluguYoga")
    for i, n in enumerate(lists["YOGA_NAMES"]):
        add(n, "", ty[i + 1] if len(ty) > i + 1 else "", "yoga name")
    for n, t in te_map("teluguKarana").items():
        add(n, "", t, "karana name")
    tm = te_list("teluguMonths")
    for i, n in enumerate(lists["MONTH_NAMES"]):
        add(n, "", tm[i] if i < len(tm) else "", "lunar month")
    for n, t in te_map("teluguVara").items():
        add(n, "", t, "weekday (vara)")
    for n, t in te_map("teluguRashi").items():
        add(n, "", t, "rashi")
    ts = te_list("teluguSamvatsara")
    for i, n in enumerate(lists["SAMVATSARA_NAMES"]):
        add(n, "", ts[i] if i < len(ts) else "", "samvatsara (60-year cycle)")
    for i, n in enumerate(["Vasanta", "Grishma", "Varsha", "Sharad", "Hemanta", "Shishira"]):
        add(n, "", te_list("teluguRitu")[i] + " ఋతువు", "ritu (season)")
    for n in ("Uttarayana", "Dakshinayana"):
        add(n, "", "ఉత్తరాయణం" if n[0] == "U" else "దక్షిణాయనం", "ayana")

    # Festivals and recurring observances.
    fest = (BACKEND / "app/services/festivals.py").read_text()
    te_fest = te_map("teluguFestivals")
    for slug, name, name_hi in re.findall(r'FestivalRule\(\s*"([\w-]+)",\s*"([^"]+)",\s*"([^"]+)"', fest):
        add(name, name_hi, te_fest.get(slug, ""), "festival name")
    for slug, name, name_hi in re.findall(r'\("([\w-]+)", "([^"]+)", "([^"]+)", \[', fest):
        add(name, name_hi, te_fest.get(slug, ""), "recurring observance")

    # Deities and cities.
    for slug, te in te_map("teluguDeities").items():
        add(slug.replace("-", " ").title(), "", te, "deity (slug %s)" % slug)
    loc = (APP / "lib/core/location.dart").read_text()
    te_city = te_map("teluguCities")
    for cid, name, name_hi in re.findall(r"City\('([\w-]+)', '([^']*)', '([^']*)'", loc):
        add(name, name_hi, te_city.get(cid, ""), "city")

    # Content files: festival wishes and the temple booking guide ({"en", "hi", "te"} maps).
    content: dict[str, dict] = {}

    def walk(o, where):
        if isinstance(o, dict):
            if isinstance(o.get("en"), str) and o["en"].strip() and o["en"] not in entries:
                content.setdefault(o["en"], {"en": o["en"], "hi": o.get("hi", ""), "te": o.get("te", ""), "where": where})
            for v in o.values():
                walk(v, where)
        elif isinstance(o, list):
            for v in o:
                walk(v, where)

    for name in ("wishes.json", "temples.json"):
        walk(json.loads((APP / "assets/data" / name).read_text()), name)
    (OUT.parent / "strings_content.json").write_text(
        json.dumps(sorted(content.values(), key=lambda e: (e["where"], e["en"])), ensure_ascii=False, indent=1))
    print(f"{len(content)} content strings -> tool/l10n/strings_content.json")

    out = sorted(entries.values(), key=lambda e: (e["where"], e["en"]))
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1))
    print(f"{len(out)} strings -> {OUT.relative_to(APP)}")


if __name__ == "__main__":
    main()
