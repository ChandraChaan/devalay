from datetime import UTC, datetime, timedelta
from unittest.mock import patch

from app.models import FestivalOverride, User
from app.services import ai, play_billing, rashifal

GUEST = {"X-Device-Id": "test-device-0001"}


def test_panchang_endpoint_validation(client):
    assert client.get("/api/v1/panchang", params={"lat": 19.07}).status_code == 422
    assert client.get("/api/v1/panchang", params={"tz": "Mars/Olympus"}).status_code == 422
    assert client.get("/api/v1/panchang", params={"day": "2099-01-01"}).status_code == 422
    r = client.get("/api/v1/panchang", params={"lat": 19.076, "lon": 72.877, "tz": "Asia/Kolkata", "day": "2026-11-08"})
    assert r.status_code == 200
    body = r.json()
    assert body["location"]["lat"] == 19.1  # coordinates are coarsened
    assert body["tithi"][-1]["name"] == "Amavasya" or body["tithi"][0]["name"] == "Amavasya"


def test_month_endpoint(client):
    r = client.get("/api/v1/panchang/month", params={"year": 2026, "month": 2})
    assert len(r.json()["days"]) == 28


def test_festivals_with_overrides(client, db):
    db.add(FestivalOverride(slug="holi", year=2026, date=datetime(2026, 3, 4).date()))
    db.add(FestivalOverride(slug="local-temple-day", year=2026, date=datetime(2026, 5, 1).date(), name="Temple Day"))
    db.add(FestivalOverride(slug="nag-panchami", year=2026, hidden=True))
    db.commit()
    items = client.get("/api/v1/festivals", params={"year": 2026}).json()
    by_slug = {i["slug"]: i for i in items}
    assert by_slug["holi"]["date"] == "2026-03-04" and by_slug["holi"]["computed"] is False
    assert by_slug["local-temple-day"]["name"] == "Temple Day"
    assert "nag-panchami" not in by_slug
    recurring = client.get("/api/v1/festivals", params={"year": 2026, "include_recurring": True}).json()
    assert len(recurring) > len(items) + 60


def test_rashifal_all_and_cached(client):
    r = client.get("/api/v1/rashifal", params={"lang": "en", "day": "2026-11-03"}).json()
    assert len(r["readings"]) == 12
    first = r["readings"][0]
    assert first["moon_rashi"] == "simha" and first["moon_house"] == 5
    again = client.get("/api/v1/rashifal/mesha", params={"lang": "en", "day": "2026-11-03"}).json()
    assert again["overview"] == first["overview"] and again["source"] == "rules"
    assert client.get("/api/v1/rashifal/pluto").status_code == 404


def test_rashifal_houses_cover_all_ratings():
    from datetime import date

    readings = rashifal.all_readings(date(2026, 1, 1), "hi")
    assert {r["moon_house"] for r in readings} == set(range(1, 13))
    assert all(r["overview"] and r["remedy"] for r in readings)


def test_ai_status_offline_and_quota(client):
    assert client.post("/api/v1/ai/status", json={"deity": "shiva"}).status_code == 400  # guests need a device id
    r = client.post("/api/v1/ai/status", json={"deity": "shiva", "occasion": "monday", "language": "hi"}, headers=GUEST)
    assert r.status_code == 200
    body = r.json()
    assert body["provider"] == "offline" and len(body["options"]) == 3
    assert "महादेव" in body["options"][0]["text"] and body["options"][0]["text"].startswith("शुभ सोमवार")
    for _ in range(4):
        client.post("/api/v1/ai/status", json={"deity": "rama"}, headers=GUEST)
    assert client.post("/api/v1/ai/status", json={"deity": "rama"}, headers=GUEST).status_code == 429
    q = client.get("/api/v1/ai/quota", headers=GUEST).json()
    assert q["remaining"] == 0 and q["limit"] == 5


def test_ai_status_rejects_unknown_deity(client):
    assert client.post("/api/v1/ai/status", json={"deity": "thor"}, headers={"X-Device-Id": "dev-x-123456"}).status_code == 422


def test_ai_status_uses_claude_when_available(client):
    fake = {"options": [{"text": "हर हर महादेव 🙏", "hashtags": ["#Mahadev"]}]}
    with patch.object(ai, "_complete_json", return_value=fake):
        r = client.post("/api/v1/ai/status", json={"deity": "shiva"}, headers={"X-Device-Id": "claude-device-1"})
    assert r.json()["provider"] == "claude"
    assert r.json()["options"][0]["text"] == "हर हर महादेव 🙏"


def test_ai_falls_back_when_claude_fails(client):
    with patch.object(ai, "_complete_json", return_value=None):
        r = client.post("/api/v1/ai/status", json={"deity": "krishna"}, headers={"X-Device-Id": "fallback-device"})
    assert r.json()["provider"] == "offline"


def test_gita_ask_grounded_offline(client):
    r = client.post("/api/v1/ai/ask", json={"question": "How do I deal with anger?"}, headers={"X-Device-Id": "ask-dev-01"})
    assert r.status_code == 200
    body = r.json()
    assert body["provider"] == "offline"
    assert body["verses"]
    assert any("anger" in v["translation_en"].lower() or "passion" in v["translation_en"].lower() for v in body["verses"])


def test_favorites_crud_and_sync(client, auth):
    assert client.get("/api/v1/favorites").status_code == 401
    assert client.put("/api/v1/favorites", json={"item_type": "track", "item_id": "5"}, headers=auth).status_code == 201
    assert client.put("/api/v1/favorites", json={"item_type": "track", "item_id": "5"}, headers=auth).status_code == 201
    assert client.put("/api/v1/favorites", json={"item_type": "spaceship", "item_id": "5"}, headers=auth).status_code == 422
    synced = client.post("/api/v1/favorites/sync", json=[{"item_type": "verse", "item_id": "2.47"},
                                                       {"item_type": "track", "item_id": "5"}], headers=auth).json()
    assert {(f["item_type"], f["item_id"]) for f in synced} == {("track", "5"), ("verse", "2.47")}
    assert client.delete("/api/v1/favorites/track/5", headers=auth).status_code == 204
    assert len(client.get("/api/v1/favorites", headers=auth).json()) == 1


def test_premium_not_configured(client, auth):
    assert client.get("/api/v1/premium/plans").json()["plans"]
    r = client.post("/api/v1/premium/verify", json={"product_id": "devalay_premium_monthly", "purchase_token": "x" * 20},
                    headers=auth)
    assert r.status_code == 503
    assert client.post("/api/v1/premium/verify", json={"product_id": "free_money", "purchase_token": "x" * 20},
                       headers=auth).status_code == 400


def test_premium_verify_grants_and_raises_ai_limit(client, auth, db, user_tokens):
    expiry = datetime.now(UTC) + timedelta(days=30)
    verified = play_billing.Verified("SUBSCRIPTION_STATE_ACTIVE", "devalay_premium_yearly", expiry, True, {"x": 1})
    with patch.object(play_billing, "verify", return_value=verified):
        r = client.post("/api/v1/premium/verify",
                        json={"product_id": "devalay_premium_yearly", "purchase_token": "token-abc-123456"}, headers=auth)
    assert r.status_code == 200 and r.json()["is_premium"] is True
    assert client.get("/api/v1/ai/quota", headers=auth).json()["limit"] == 100
    # Revoked purchase ends access.
    revoked = play_billing.Verified("SUBSCRIPTION_STATE_EXPIRED", "devalay_premium_yearly",
                                    datetime.now(UTC) - timedelta(days=1), False, {})
    with patch.object(play_billing, "verify", return_value=revoked):
        r = client.post("/api/v1/premium/verify",
                        json={"product_id": "devalay_premium_yearly", "purchase_token": "token-abc-123456"}, headers=auth)
    assert r.json()["is_premium"] is False


def test_purchase_token_cannot_be_shared(client, auth):
    other = client.post("/api/v1/auth/register", json={"email": "sharer@example.com", "password": "share-it-1234"}).json()
    other_auth = {"Authorization": f"Bearer {other['access_token']}"}
    verified = play_billing.Verified("SUBSCRIPTION_STATE_ACTIVE", "devalay_premium_monthly",
                                     datetime.now(UTC) + timedelta(days=5), True, {})
    body = {"product_id": "devalay_premium_monthly", "purchase_token": "shared-token-999999"}
    with patch.object(play_billing, "verify", return_value=verified):
        assert client.post("/api/v1/premium/verify", json=body, headers=auth).status_code == 200
        assert client.post("/api/v1/premium/verify", json=body, headers=other_auth).status_code == 409


def test_parse_subscription_payload():
    data = {"subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "lineItems": [{"productId": "devalay_premium_monthly", "expiryTime": "2030-01-01T00:00:00.000Z",
                           "autoRenewingPlan": {"autoRenewEnabled": True}}]}
    v = play_billing.parse_subscription(data, "devalay_premium_monthly")
    assert v.active and v.auto_renewing and v.expires_at.year == 2030


def test_admin_requires_login_and_role(client, db, user_tokens):
    r = client.get("/admin/dashboard", follow_redirects=False)
    assert r.status_code in (302, 303, 307)
    # A normal user cannot sign in to the dashboard.
    r = client.post("/admin/login", data={"username": user_tokens["email"], "password": "jai-shri-ram-108"},
                    follow_redirects=False)
    assert r.status_code in (400, 401) or "login" in r.headers.get("location", "")
    user = db.query(User).filter_by(email=user_tokens["email"]).one()
    user.role = "admin"
    db.commit()
    r = client.post("/admin/login", data={"username": user_tokens["email"], "password": "jai-shri-ram-108"},
                    follow_redirects=False)
    assert r.status_code in (302, 303)
    dash = client.get("/admin/dashboard")
    assert dash.status_code == 200 and "Devalay overview" in dash.text
    assert client.get("/admin/user/list").status_code == 200
    up = client.post("/admin/upload", data={"folder": "audio"},
                     files={"file": ("bell.mp3", b"ID3fakeaudio", "audio/mpeg")})
    assert "Uploaded" in up.text
    bad = client.post("/admin/upload", data={"folder": "misc"}, files={"file": ("x.exe", b"MZ", "application/x-msdownload")})
    assert "not allowed" in bad.text


def test_every_admin_page_renders(client, db):
    from sqladmin import ModelView

    from app.main import app
    from app.security import hash_password

    db.add(User(email="pages-admin@example.com", password_hash=hash_password("admin-pass-12345"), role="admin"))
    db.commit()
    client.post("/admin/login", data={"username": "pages-admin@example.com", "password": "admin-pass-12345"})
    views = [v for v in app.state.admin_site.views if isinstance(v, ModelView)]
    assert len(views) >= 14
    for view in views:
        assert client.get(f"/admin/{view.identity}/list").status_code == 200, view.identity
        if view.can_create:
            assert client.get(f"/admin/{view.identity}/create").status_code == 200, view.identity
    assert client.get("/admin/does-not-exist/list").status_code == 404
