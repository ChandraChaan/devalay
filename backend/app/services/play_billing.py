"""Google Play subscription verification (Android Publisher API, subscriptionsv2)."""

from __future__ import annotations

import base64
import json
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from urllib.parse import quote

import httpx

from app.config import get_settings

ACTIVE_STATES = {"SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"}
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


class BillingNotConfigured(RuntimeError):
    pass


class BillingInvalid(ValueError):
    pass


@dataclass
class Verified:
    status: str
    product_id: str
    expires_at: datetime | None
    auto_renewing: bool
    raw: dict

    @property
    def active(self) -> bool:
        return self.status in ACTIVE_STATES and (self.expires_at is None or self.expires_at > datetime.now(UTC))


def _access_token() -> str:
    from google.auth.transport.requests import Request
    from google.oauth2 import service_account

    raw = get_settings().google_play_service_account_json.strip()
    if not raw:
        raise BillingNotConfigured("Google Play verification is not configured")
    info = json.loads(raw if raw.startswith("{") else base64.b64decode(raw))
    creds = service_account.Credentials.from_service_account_info(info, scopes=[SCOPE])
    creds.refresh(Request())
    return creds.token


def parse_subscription(data: dict, product_id: str) -> Verified:
    items = data.get("lineItems") or []
    item = next((i for i in items if i.get("productId") == product_id), items[0] if items else {})
    expiry = item.get("expiryTime")
    expires_at = datetime.fromisoformat(expiry.replace("Z", "+00:00")) if expiry else None
    auto = bool(item.get("autoRenewingPlan", {}).get("autoRenewEnabled"))
    return Verified(data.get("subscriptionState", "UNKNOWN"), item.get("productId", product_id), expires_at, auto, data)


def verify(product_id: str, purchase_token: str) -> Verified:
    s = get_settings()
    if s.premium_dev_grant and not s.is_production:
        return Verified("SUBSCRIPTION_STATE_ACTIVE", product_id, datetime.now(UTC) + timedelta(days=30), False,
                        {"dev_grant": True})
    token = _access_token()
    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
        f"{s.google_play_package}/purchases/subscriptionsv2/tokens/{quote(purchase_token, safe='')}"
    )
    resp = httpx.get(url, headers={"Authorization": f"Bearer {token}"}, timeout=15)
    if resp.status_code in (400, 404, 410):
        raise BillingInvalid("Purchase token not recognised by Google Play")
    resp.raise_for_status()
    return parse_subscription(resp.json(), product_id)
