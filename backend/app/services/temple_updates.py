"""Announcements from a temple's official site, for the app's temple booking pages.

TTD publishes its "Latest Updates" (which quota opens when) as a public JSON feed on its booking
portal. The static export reads it once a day and republishes a cleaned copy, so phones never
call the temple's servers for it. Only this public announcements feed is read: booking, login
and payment stay on the official site.
"""

import json
import re
import urllib.request
from datetime import UTC, datetime
from urllib.parse import urlsplit

TTD_PORTAL = "https://ttdevasthanams.ap.gov.in/home/dashboard"
TTD_FEED = "https://ttdevasthanams.ap.gov.in/cms/api/universal-latest-updates?populate=*"
MAX_ITEMS = 30
MAX_TEXT = 600

_LINK = re.compile(r"\[([^\]]*)\]\(([^)\s]*)\)")
# "... at 10:00 AM. Please Click Here": the pointer after a finished sentence says nothing without its link.
_TRAILING_POINTER = re.compile(r"(?<=[.!?])\s*please\s+click\s+here\.?\s*$", re.IGNORECASE)
# Links may only lead to the temple's own government sites.
_OFFICIAL_HOSTS = ("ttdevasthanams.ap.gov.in", "tirupatibalaji.ap.gov.in", "tirumala.org")


def _official_url(link: str) -> str | None:
    """An absolute HTTPS link to an official TTD site, or None (pages inside the portal need a login)."""
    parts = urlsplit(link)
    host = (parts.hostname or "").lower()
    if parts.scheme == "https" and any(host == h or host.endswith("." + h) for h in _OFFICIAL_HOSTS):
        return link
    return None


def clean_text(markdown: str) -> str:
    """Plain text from the feed's light Markdown: link labels kept, bold marks and stray spaces removed."""
    text = _LINK.sub(lambda m: m.group(1), markdown or "").replace("**", "").replace("\xa0", " ")
    paragraphs = [" ".join(p.split()) for p in re.split(r"\n\s*\n", text)]
    text = "\n".join(p for p in paragraphs if p)
    text = _TRAILING_POINTER.sub("", text).strip()
    return text if len(text) <= MAX_TEXT else text[: MAX_TEXT - 1].rstrip() + "…"


def parse_ttd_updates(payload: dict, fetched: datetime | None = None) -> dict:
    """The feed as the app reads it: `{source, fetched, updated, items: [{id, title, text, url}]}`."""
    items: list[dict] = []
    updated: list[str] = []
    for row in payload.get("data") or []:
        attributes = row.get("attributes") or {}
        entries = attributes.get("update") or []
        if entries and attributes.get("updatedAt"):
            updated.append(str(attributes["updatedAt"]))
        for entry in entries:
            raw = str(entry.get("data") or "")
            text = clean_text(raw)
            if not text:
                continue
            links = [url for url in (_official_url(m.group(2)) for m in _LINK.finditer(raw)) if url]
            items.append({
                "id": entry.get("id"),
                "title": " ".join(str(entry.get("cta") or "").split()),
                "text": text,
                "url": links[0] if links else None,
            })
    return {
        "source": TTD_PORTAL,
        "fetched": (fetched or datetime.now(UTC)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "updated": max(updated) if updated else None,
        "items": items[:MAX_ITEMS],
    }


def _get_json(url: str, timeout: float) -> dict:
    request = urllib.request.Request(url, headers={  # noqa: S310 - fixed https URLs
        "Accept": "application/json",
        "User-Agent": "Mozilla/5.0 (compatible; static-site-export)",
    })
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
        return json.loads(response.read().decode("utf-8"))


def fetch_ttd_updates(previous_url: str | None = None, timeout: float = 20) -> dict | None:
    """Today's announcements. If TTD cannot be reached, the copy published last time; else None."""
    try:
        updates = parse_ttd_updates(_get_json(TTD_FEED, timeout))
        if updates["items"]:
            return updates
    except Exception as error:  # a temple site being down must not fail the export
        print(f"TTD announcements not fetched: {error}")
    if previous_url:
        try:
            previous = _get_json(previous_url, timeout)
            if isinstance(previous.get("items"), list) and previous.get("fetched"):
                return previous
        except Exception as error:
            print(f"No earlier copy of the TTD announcements: {error}")
    return None
