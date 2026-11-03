"""Build app/seed/data/gita.json from the open gita/gita dataset (Unlicense).

Uses only public-domain material:
  * the Sanskrit text of the Bhagavad Gita;
  * an IAST transliteration generated here from that text.
The dataset's translations, word meanings and commentaries are not used: none of them is
public domain in every country. The English comes from Annie Besant's 1922 translation via
scripts/besant_gita.py, run after this script. Chapter summaries below were written for Devalay.

Usage: python scripts/build_gita.py <dir with verse.json, chapters.json>
       python scripts/besant_gita.py
"""

import json
import re
import sys
from pathlib import Path

from indic_transliteration import sanscript

OUT = Path(__file__).resolve().parent.parent / "app" / "seed" / "data" / "gita.json"

CHAPTERS = {
    1: ("Arjuna's Despondency", "On the field of Kurukshetra, Arjuna sees teachers, cousins and friends in both armies. Overcome by grief and doubt, he lays down his bow and refuses to fight."),
    2: ("The Yoga of Knowledge", "Krishna teaches that the Self is eternal and cannot be slain, urges Arjuna to do his duty, and describes acting without attachment to results and the steady wisdom of the sthita-prajna."),
    3: ("The Yoga of Action", "Action is unavoidable, so act selflessly as an offering. Krishna explains how desire clouds wisdom and why the wise keep working for the welfare of the world."),
    4: ("The Yoga of Knowledge and Renunciation of Action", "Krishna reveals that He descends age after age to protect dharma, and shows how knowledge burns away karma so that work becomes a form of worship."),
    5: ("The Yoga of Renunciation", "Renouncing the fruits of action and performing action with a pure mind lead to the same goal. The wise see the same Self in all beings."),
    6: ("The Yoga of Meditation", "Krishna describes the practice of meditation: a quiet place, a steady posture, a disciplined life and a mind brought back patiently whenever it wanders."),
    7: ("Knowledge and Realisation", "Krishna explains His lower and higher natures, how everything rests on Him like pearls on a thread, and the kinds of people who turn to Him."),
    8: ("The Imperishable Brahman", "Arjuna asks about Brahman, karma and the moment of death. Krishna teaches that one who remembers Him at the end attains Him."),
    9: ("The Royal Secret", "The sovereign knowledge: God pervades all yet stands beyond all. Even a leaf, a flower, fruit or water offered with love is accepted."),
    10: ("Divine Glories", "Krishna describes His vibhutis, the splendours through which He can be recognised: whatever is glorious or mighty springs from a spark of His radiance."),
    11: ("The Vision of the Universal Form", "Granted divine sight, Arjuna beholds the cosmic form containing all worlds and all time, and prays in awe for Krishna's gentle form to return."),
    12: ("The Yoga of Devotion", "Loving devotion is the surest path. Krishna lists the qualities of His dear devotee: free of hatred, compassionate, balanced in joy and sorrow."),
    13: ("The Field and the Knower of the Field", "The body is the field and the Self is its knower. Krishna distinguishes matter from spirit and describes the qualities that make up true knowledge."),
    14: ("The Three Gunas", "Sattva, rajas and tamas bind the soul in different ways. One who rises above all three is free from birth, death and sorrow."),
    15: ("The Supreme Person", "The world is an eternal ashvattha tree with roots above. Cutting it with detachment, one reaches the Supreme Person beyond the perishable and imperishable."),
    16: ("Divine and Demonic Natures", "Krishna contrasts the divine qualities that lead to freedom with the demonic ones that bind, and names lust, anger and greed as the gates to ruin."),
    17: ("The Threefold Faith", "Faith, food, sacrifice, austerity and charity each take sattvic, rajasic or tamasic forms. Krishna explains the meaning of Om Tat Sat."),
    18: ("Liberation through Renunciation", "A summary of the whole teaching: true renunciation, duty according to one's nature, and the final call to surrender to Krishna, after which Arjuna stands ready."),
}


def clean_sanskrit(text: str) -> str:
    text = re.sub(r"।।\s*\d+\.\d+\s*।।", "॥", text)
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return "\n".join(lines)


def main(src: str) -> None:
    root = Path(src)
    verses = json.loads((root / "verse.json").read_text())
    chapters = json.loads((root / "chapters.json").read_text())
    out_chapters = []
    for c in sorted(chapters, key=lambda c: c["chapter_number"]):
        n = c["chapter_number"]
        out_chapters.append({
            "number": n,
            "name_sanskrit": c["name"],
            "name_translit": sanscript.transliterate(c["name"], sanscript.DEVANAGARI, sanscript.IAST),
            "name_en": CHAPTERS[n][0],
            "summary": CHAPTERS[n][1],
            "verse_count": c["verses_count"],
        })
    out_verses = []
    for v in sorted(verses, key=lambda v: (v["chapter_number"], v["verse_number"])):
        sanskrit = clean_sanskrit(v["text"])
        out_verses.append({
            "chapter": v["chapter_number"],
            "verse": v["verse_number"],
            "sanskrit": sanskrit,
            "transliteration": sanscript.transliterate(sanskrit.replace("॥", "").replace("।", ""),
                                                       sanscript.DEVANAGARI, sanscript.IAST).strip(),
            "translation_en": "",  # filled by scripts/besant_gita.py
            "translation_author": "",
        })
    for ch in out_chapters:
        ch["verse_count"] = sum(1 for v in out_verses if v["chapter"] == ch["number"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"chapters": out_chapters, "verses": out_verses}, ensure_ascii=False, indent=1))
    print(f"wrote {len(out_chapters)} chapters, {len(out_verses)} verses to {OUT}")


if __name__ == "__main__":
    main(sys.argv[1])
