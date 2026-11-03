"""Small in-process BM25 index over Gita translations for grounding AI answers."""

from __future__ import annotations

import math
import re
from collections import Counter
from threading import Lock

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import GitaVerse

STOPWORDS = frozenset(
    "a an the and or of to in on for with is are was were be been it its this that these those i me my "
    "we our you your he him his she her they them their what which who whom how why when where do does "
    "did not no so as at by from but if then than there here into out up down over under can could "
    "should would will shall may might must about all any some such only own same too very just also "
    "thou thee thy thine hath doth art ye unto verily said".split()  # Besant's 1922 English
)
# Common question words mapped to vocabulary used in the translations.
SYNONYMS = {
    "anger": ["anger", "wrath", "passion"], "angry": ["anger", "wrath"], "fear": ["fear", "afraid"],
    "stress": ["anxiety", "grief", "sorrow", "peace"], "anxiety": ["anxiety", "grief", "peace"],
    "sad": ["grief", "sorrow"], "sadness": ["grief", "sorrow"], "death": ["death", "die", "born", "eternal"],
    "work": ["action", "work", "duty", "deeds"], "job": ["action", "duty", "work"], "duty": ["duty", "action"],
    "peace": ["peace", "tranquil", "calm"], "happiness": ["happiness", "joy", "bliss"], "god": ["lord", "god", "me"],
    "meditation": ["meditation", "meditate", "yoga", "concentration"],
    "meditate": ["meditation", "meditate", "meditating", "yoga"], "mind": ["mind", "senses", "control"],
    "desire": ["desire", "craving", "attachment"], "success": ["success", "failure", "equal"],
    "failure": ["failure", "success", "equal"], "soul": ["soul", "self", "spirit"],
    "love": ["love", "devotion", "dear"],
}

_lock = Lock()
_index: dict | None = None


def _tokens(text: str) -> list[str]:
    return [w for w in re.findall(r"[a-z]+", text.lower()) if w not in STOPWORDS and len(w) > 2]


def _build(db: Session) -> dict:
    rows = db.execute(select(GitaVerse)).scalars().all()
    docs = [(r, Counter(_tokens(r.translation_en))) for r in rows]
    df: Counter = Counter()
    for _, tf in docs:
        df.update(tf.keys())
    avg = sum(sum(tf.values()) for _, tf in docs) / max(len(docs), 1)
    return {"docs": docs, "df": df, "n": len(docs), "avg": avg}


def reset_index() -> None:
    global _index
    with _lock:
        _index = None


def search(db: Session, query: str, limit: int = 4) -> list[GitaVerse]:
    global _index
    with _lock:
        if _index is None or _index["n"] == 0:
            _index = _build(db)
    idx = _index
    terms: list[str] = []
    for t in _tokens(query):
        terms.extend(SYNONYMS.get(t, [t]))
    if not terms or idx["n"] == 0:
        return []
    k1, b = 1.5, 0.75
    scored = []
    for verse, tf in idx["docs"]:
        length = sum(tf.values()) or 1
        score = 0.0
        for term in set(terms):
            if term not in tf:
                continue
            idf = math.log(1 + (idx["n"] - idx["df"][term] + 0.5) / (idx["df"][term] + 0.5))
            f = tf[term]
            score += idf * f * (k1 + 1) / (f + k1 * (1 - b + b * length / idx["avg"]))
        if score > 0:
            scored.append((score, verse))
    scored.sort(key=lambda x: -x[0])
    return [v for _, v in scored[:limit]]
