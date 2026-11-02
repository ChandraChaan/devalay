"""Signed-in user features: favourites sync and premium entitlements."""

from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import delete, func, select

from app.deps import DB, CurrentUser
from app.models import Favorite, Subscription
from app.schemas import FavoriteIn, FavoriteOut, PremiumStatus, VerifyPurchaseIn
from app.security import keyed_hash
from app.services import play_billing

router = APIRouter(tags=["me"])

PLANS = [
    {"product_id": "devalay_premium_monthly", "title": "Premium Monthly", "period": "P1M",
     "display_price_hint": "₹49 / month"},
    {"product_id": "devalay_premium_yearly", "title": "Premium Yearly", "period": "P1Y",
     "display_price_hint": "₹399 / year"},
]
PREMIUM_BENEFITS = [
    "Unlimited offline downloads",
    "100 AI status and Gita answers a day (free: 5)",
    "Original-resolution wallpapers",
    "Exclusive Mandir themes",
    "Support an ad-free, privacy-first devotional app",
]


@router.get("/favorites", response_model=list[FavoriteOut])
def list_favorites(user: CurrentUser, db: DB):
    return db.execute(select(Favorite).where(Favorite.user_id == user.id).order_by(Favorite.created_at.desc())
                      ).scalars().all()


@router.put("/favorites", response_model=FavoriteOut, status_code=201)
def add_favorite(body: FavoriteIn, user: CurrentUser, db: DB):
    existing = db.scalar(select(Favorite).where(Favorite.user_id == user.id, Favorite.item_type == body.item_type,
                                                Favorite.item_id == body.item_id))
    if existing:
        return existing
    if db.scalar(select(func.count()).where(Favorite.user_id == user.id)) >= 2000:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Favourites limit reached")
    fav = Favorite(user_id=user.id, item_type=body.item_type, item_id=body.item_id)
    db.add(fav)
    db.commit()
    return fav


@router.post("/favorites/sync", response_model=list[FavoriteOut])
def sync_favorites(items: list[FavoriteIn], user: CurrentUser, db: DB):
    """Merge favourites saved on the device while signed out."""
    if len(items) > 500:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Too many items")
    have = {(f.item_type, f.item_id) for f in db.execute(select(Favorite).where(Favorite.user_id == user.id)).scalars()}
    for item in items:
        if (item.item_type, item.item_id) not in have:
            db.add(Favorite(user_id=user.id, item_type=item.item_type, item_id=item.item_id))
            have.add((item.item_type, item.item_id))
    db.commit()
    return list_favorites(user, db)


@router.delete("/favorites/{item_type}/{item_id}", status_code=204)
def remove_favorite(item_type: str, item_id: str, user: CurrentUser, db: DB):
    db.execute(delete(Favorite).where(Favorite.user_id == user.id, Favorite.item_type == item_type,
                                      Favorite.item_id == item_id))
    db.commit()


@router.get("/premium/plans")
def plans():
    return {"plans": PLANS, "benefits": PREMIUM_BENEFITS,
            "terms": "Billed by Google Play. Cancel anytime in Play Store > Subscriptions; access continues "
                     "until the end of the paid period. No hidden charges, no auto-pay mandates."}


@router.get("/premium/status", response_model=PremiumStatus)
def premium_status(user: CurrentUser, db: DB):
    sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id)
                    .order_by(Subscription.expires_at.desc()))
    return PremiumStatus(is_premium=user.is_premium, premium_until=user.premium_until,
                         product_id=sub.product_id if sub else None)


def _other_active(db, user_id: int, exclude_id: int | None) -> bool:
    subs = db.execute(select(Subscription).where(Subscription.user_id == user_id, Subscription.id != exclude_id,
                                                 Subscription.status.in_(play_billing.ACTIVE_STATES))).scalars()
    now = datetime.now(UTC)
    return any(s.expires_at and s.expires_at.replace(tzinfo=s.expires_at.tzinfo or UTC) > now for s in subs)


@router.post("/premium/verify", response_model=PremiumStatus)
def verify_purchase(body: VerifyPurchaseIn, user: CurrentUser, db: DB):
    if body.product_id not in {p["product_id"] for p in PLANS}:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown product")
    try:
        result = play_billing.verify(body.product_id, body.purchase_token)
    except play_billing.BillingNotConfigured:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Purchase verification is not configured") from None
    except play_billing.BillingInvalid as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from None
    token_hash = keyed_hash(body.purchase_token)
    sub = db.scalar(select(Subscription).where(Subscription.token_hash == token_hash))
    if sub and sub.user_id != user.id:
        raise HTTPException(status.HTTP_409_CONFLICT, "This purchase belongs to another account")
    if sub is None:
        sub = Subscription(user_id=user.id, token_hash=token_hash, product_id=result.product_id, status=result.status)
        db.add(sub)
    sub.status, sub.expires_at, sub.auto_renewing = result.status, result.expires_at, result.auto_renewing
    sub.raw = {k: v for k, v in result.raw.items() if k != "externalAccountIdentifiers"}
    if result.active:
        user.premium_until = result.expires_at
    elif user.is_premium and not _other_active(db, user.id, sub.id):
        user.premium_until = datetime.now(UTC)  # refunded or revoked: end access now
    db.commit()
    return PremiumStatus(is_premium=user.is_premium, premium_until=user.premium_until, product_id=sub.product_id)
