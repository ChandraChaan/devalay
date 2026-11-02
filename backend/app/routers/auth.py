from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException, Request, status
from sqlalchemy import delete, select, update

from app.config import get_settings
from app.deps import DB, CurrentUser, limiter
from app.models import PasswordReset, RefreshToken, User
from app.schemas import (
    DeleteAccountIn,
    ForgotIn,
    LoginIn,
    RefreshIn,
    RegisterIn,
    ResetIn,
    TokenOut,
    UserOut,
    UserUpdate,
)
from app.security import (
    create_access_token,
    hash_password,
    needs_rehash,
    new_opaque_token,
    new_reset_code,
    sha256,
    verify_password,
)
from app.services.mailer import send_mail

router = APIRouter(prefix="/auth", tags=["auth"])


def _issue_tokens(db, user: User) -> TokenOut:
    access, expires_in = create_access_token(user.id, user.role)
    refresh = new_opaque_token()
    db.add(RefreshToken(
        user_id=user.id,
        token_hash=sha256(refresh),
        expires_at=datetime.now(UTC) + timedelta(days=get_settings().refresh_token_days),
    ))
    db.commit()
    return TokenOut(access_token=access, refresh_token=refresh, expires_in=expires_in)


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=UTC)


@router.post("/register", response_model=TokenOut, status_code=201)
@limiter.limit("5/minute")
def register(request: Request, body: RegisterIn, db: DB):
    email = body.email.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status.HTTP_409_CONFLICT, "An account with this email already exists")
    user = User(email=email, password_hash=hash_password(body.password), display_name=body.display_name.strip())
    db.add(user)
    db.commit()
    return _issue_tokens(db, user)


@router.post("/login", response_model=TokenOut)
@limiter.limit("10/minute")
def login(request: Request, body: LoginIn, db: DB):
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    if not verify_password(body.password, user.password_hash if user else None) or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Incorrect email or password")
    if needs_rehash(user.password_hash):
        user.password_hash = hash_password(body.password)
    user.last_login_at = datetime.now(UTC)
    return _issue_tokens(db, user)


@router.post("/refresh", response_model=TokenOut)
@limiter.limit("30/minute")
def refresh(request: Request, body: RefreshIn, db: DB):
    token = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == sha256(body.refresh_token)))
    if token is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")
    if token.revoked:
        # Reuse of a rotated token suggests theft: revoke the whole family for this user.
        db.execute(update(RefreshToken).where(RefreshToken.user_id == token.user_id).values(revoked=True))
        db.commit()
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Refresh token reused; please sign in again")
    if _aware(token.expires_at) < datetime.now(UTC):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Refresh token expired")
    user = db.get(User, token.user_id)
    if user is None or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Account not available")
    token.revoked = True
    return _issue_tokens(db, user)


@router.post("/logout", status_code=204)
def logout(body: RefreshIn, db: DB):
    db.execute(update(RefreshToken).where(RefreshToken.token_hash == sha256(body.refresh_token)).values(revoked=True))
    db.commit()


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser):
    return user


@router.patch("/me", response_model=UserOut)
def update_me(body: UserUpdate, user: CurrentUser, db: DB):
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    db.add(user)
    db.commit()
    return user


@router.delete("/me", status_code=204)
@limiter.limit("5/minute")
def delete_me(request: Request, body: DeleteAccountIn, user: CurrentUser, db: DB):
    """Permanently delete the account and all personal data (Play Store requirement)."""
    if not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Password is incorrect")
    db.delete(user)
    db.commit()


@router.post("/forgot-password", status_code=202)
@limiter.limit("3/minute")
def forgot_password(request: Request, body: ForgotIn, db: DB):
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    # Always 202 so the endpoint does not reveal which emails have accounts.
    if user and user.is_active:
        code = new_reset_code()
        db.execute(delete(PasswordReset).where(PasswordReset.user_id == user.id))
        db.add(PasswordReset(user_id=user.id, code_hash=sha256(f"{user.id}:{code}"),
                             expires_at=datetime.now(UTC) + timedelta(minutes=15)))
        db.commit()
        send_mail(user.email, "Your Devalay password reset code",
                  f"Your code is {code}. It expires in 15 minutes. If you did not ask for this, ignore this email.")
    return {"detail": "If the account exists, a reset code has been sent."}


@router.post("/reset-password", status_code=204)
@limiter.limit("5/minute")
def reset_password(request: Request, body: ResetIn, db: DB):
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    reset = db.scalar(select(PasswordReset).where(PasswordReset.user_id == user.id)) if user else None
    if reset is None or reset.used or _aware(reset.expires_at) < datetime.now(UTC) or reset.attempts >= 5:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired code")
    if reset.code_hash != sha256(f"{user.id}:{body.code}"):
        reset.attempts += 1
        db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired code")
    user.password_hash = hash_password(body.new_password)
    reset.used = True
    db.execute(update(RefreshToken).where(RefreshToken.user_id == user.id).values(revoked=True))
    db.commit()
