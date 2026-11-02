from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import func, select

from app.config import get_settings
from app.deps import DB, OptionalUser, limiter, usage_subject
from app.models import AIUsage
from app.schemas import AskIn, AskOut, GitaVerseOut, QuotaOut, StatusIn, StatusOut
from app.services import ai, gita_search

router = APIRouter(prefix="/ai", tags=["ai"])
Subject = Annotated[str, Depends(usage_subject)]


def _limit(user) -> int:
    s = get_settings()
    return s.ai_premium_daily_limit if user is not None and user.is_premium else s.ai_free_daily_limit


def _used(db, subject: str) -> int:
    return db.scalar(select(func.count()).where(AIUsage.subject == subject, AIUsage.day == date.today())) or 0


def _consume(db, subject: str, user, kind: str, provider: str) -> int:
    db.add(AIUsage(subject=subject, kind=kind, day=date.today(), provider=provider))
    db.commit()
    return max(_limit(user) - _used(db, subject), 0)


def _guard(db, subject: str, user) -> None:
    if _used(db, subject) >= _limit(user):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS,
                            "Daily AI limit reached. It resets at midnight; Premium raises the limit.")


@router.get("/quota", response_model=QuotaOut)
def quota(db: DB, user: OptionalUser, subject: Subject):
    used, limit = _used(db, subject), _limit(user)
    return QuotaOut(limit=limit, used=used, remaining=max(limit - used, 0), ai_enabled=ai.ai_enabled())


@router.post("/status", response_model=StatusOut)
@limiter.limit("10/minute")
def make_status(request: Request, body: StatusIn, db: DB, user: OptionalUser, subject: Subject):
    _guard(db, subject, user)
    options, provider = ai.generate_status(body.deity, body.occasion, body.language, body.festival, body.name,
                                           body.note)
    remaining = _consume(db, subject, user, "status", provider)
    return StatusOut(options=options, provider=provider, remaining_today=remaining)


@router.post("/ask", response_model=AskOut)
@limiter.limit("10/minute")
def ask_gita(request: Request, body: AskIn, db: DB, user: OptionalUser, subject: Subject):
    _guard(db, subject, user)
    verses = gita_search.search(db, body.question, limit=4)
    payload = [GitaVerseOut.model_validate(v).model_dump() for v in verses]
    answer, provider = ai.answer_from_verses(body.question, payload, body.language)
    remaining = _consume(db, subject, user, "ask", provider)
    return AskOut(answer=answer, verses=payload, provider=provider, remaining_today=remaining)
