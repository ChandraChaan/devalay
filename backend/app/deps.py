from typing import Annotated

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.models import User
from app.security import decode_access_token, keyed_hash

DB = Annotated[Session, Depends(get_db)]
_bearer = HTTPBearer(auto_error=False)


def _client_ip(request: Request) -> str:
    # Behind a proxy (Render/Fly/Cloudflare) the first X-Forwarded-For hop is the client.
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return get_remote_address(request)


limiter = Limiter(key_func=_client_ip, enabled=get_settings().env != "test", default_limits=["300/minute"])


def optional_user(
    db: DB, creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)]
) -> User | None:
    if creds is None:
        return None
    payload = decode_access_token(creds.credentials)
    if payload is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token")
    user = db.get(User, int(payload["sub"]))
    if user is None or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Account not available")
    return user


def current_user(user: Annotated[User | None, Depends(optional_user)]) -> User:
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sign in required", headers={"WWW-Authenticate": "Bearer"})
    return user


def admin_user(user: Annotated[User, Depends(current_user)]) -> User:
    if user.role not in ("admin", "editor"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin access required")
    return user


OptionalUser = Annotated[User | None, Depends(optional_user)]
CurrentUser = Annotated[User, Depends(current_user)]
AdminUser = Annotated[User, Depends(admin_user)]


def usage_subject(
    user: OptionalUser,
    x_device_id: Annotated[str | None, Header(max_length=100)] = None,
) -> str:
    """Identity used for quotas: the account if signed in, else a hashed device id."""
    if user is not None:
        return f"user:{user.id}"
    if not x_device_id or len(x_device_id) < 8:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "X-Device-Id header required for guests")
    return f"device:{keyed_hash(x_device_id)[:40]}"
