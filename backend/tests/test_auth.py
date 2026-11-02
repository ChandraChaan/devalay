from datetime import UTC, datetime, timedelta

import jwt

from app.models import PasswordReset, User
from app.security import sha256


def test_register_login_me(client, user_tokens):
    r = client.post("/api/v1/auth/login", json={"email": user_tokens["email"], "password": "jai-shri-ram-108"})
    assert r.status_code == 200
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {r.json()['access_token']}"})
    assert me.status_code == 200
    body = me.json()
    assert body["email"] == user_tokens["email"]
    assert body["is_premium"] is False
    assert "password_hash" not in body


def test_duplicate_email_rejected(client, user_tokens):
    r = client.post("/api/v1/auth/register", json={"email": user_tokens["email"].upper(), "password": "another-pass-1"})
    assert r.status_code == 409


def test_weak_password_rejected(client):
    r = client.post("/api/v1/auth/register", json={"email": "weak@example.com", "password": "12345678"})
    assert r.status_code == 422


def test_wrong_password_and_unknown_user_look_the_same(client, user_tokens):
    a = client.post("/api/v1/auth/login", json={"email": user_tokens["email"], "password": "wrong-password-1"})
    b = client.post("/api/v1/auth/login", json={"email": "nobody@example.com", "password": "wrong-password-1"})
    assert a.status_code == b.status_code == 401
    assert a.json() == b.json()


def test_refresh_rotation_and_reuse_detection(client, user_tokens):
    first = user_tokens["refresh_token"]
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": first})
    assert r.status_code == 200
    second = r.json()["refresh_token"]
    assert second != first
    # Reusing the rotated token revokes the whole family.
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": first}).status_code == 401
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": second}).status_code == 401


def test_logout_revokes_refresh_token(client, user_tokens):
    assert client.post("/api/v1/auth/logout", json={"refresh_token": user_tokens["refresh_token"]}).status_code == 204
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": user_tokens["refresh_token"]}).status_code == 401


def test_tampered_and_expired_tokens_rejected(client):
    bad = jwt.encode({"sub": "1", "type": "access", "exp": datetime.now(UTC) + timedelta(minutes=5)}, "wrong-key",
                     algorithm="HS256")
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {bad}"}).status_code == 401
    from app.config import get_settings

    expired = jwt.encode({"sub": "1", "type": "access", "exp": datetime.now(UTC) - timedelta(minutes=1)},
                         get_settings().secret_key, algorithm="HS256")
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {expired}"}).status_code == 401


def test_update_profile(client, auth):
    r = client.patch("/api/v1/auth/me", json={"display_name": "Radha", "rashi": "simha", "language": "en"}, headers=auth)
    assert r.status_code == 200
    assert r.json()["rashi"] == "simha"
    assert client.patch("/api/v1/auth/me", json={"rashi": "pluto"}, headers=auth).status_code == 422


def test_password_reset_flow(client, db, user_tokens):
    email = user_tokens["email"]
    assert client.post("/api/v1/auth/forgot-password", json={"email": email}).status_code == 202
    user = db.query(User).filter_by(email=email).one()
    reset = db.query(PasswordReset).filter_by(user_id=user.id).one()
    reset.code_hash = sha256(f"{user.id}:123456")  # we cannot read the mailed code, so set a known one
    db.commit()
    assert client.post("/api/v1/auth/reset-password",
                       json={"email": email, "code": "000000", "new_password": "new-pass-word-9"}).status_code == 400
    assert client.post("/api/v1/auth/reset-password",
                       json={"email": email, "code": "123456", "new_password": "new-pass-word-9"}).status_code == 204
    assert client.post("/api/v1/auth/login", json={"email": email, "password": "new-pass-word-9"}).status_code == 200
    # Old sessions are revoked after a reset.
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": user_tokens["refresh_token"]}).status_code == 401


def test_forgot_password_does_not_reveal_accounts(client):
    assert client.post("/api/v1/auth/forgot-password", json={"email": "ghost@example.com"}).status_code == 202


def test_delete_account_requires_password_and_removes_data(client, db, auth, user_tokens):
    client.put("/api/v1/favorites", json={"item_type": "track", "item_id": "1"}, headers=auth)
    assert client.request("DELETE", "/api/v1/auth/me", json={"password": "nope-nope-1"}, headers=auth).status_code == 403
    assert client.request("DELETE", "/api/v1/auth/me", json={"password": "jai-shri-ram-108"}, headers=auth).status_code == 204
    assert db.query(User).filter_by(email=user_tokens["email"]).first() is None
    assert client.get("/api/v1/auth/me", headers=auth).status_code == 401
