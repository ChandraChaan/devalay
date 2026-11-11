from datetime import UTC, datetime

from app.services import temple_updates

FEED = {
    "data": [
        {
            "id": 75,
            "attributes": {
                "updatedAt": "2026-11-10T07:18:07.847Z",
                "update": [
                    {
                        "id": 1,
                        "cta": "Accommodation",
                        "data": "Tirumala and Tirupati Accommodation Quota for January-2027 will be available for booking "
                        "w.e.f.\xa024.10.2026, 03:00 PM. Please [Click Here](/accommodation/instructions?flow=acc)\n ",
                    },
                    {
                        "id": 2,
                        "cta": " Seva E-Dip ",
                        "data": "Registrations received: \n\nArchana: **676563** \n\nPlease [Click Here]"
                        "(https://ttdevasthanams.ap.gov.in/assets/list.pdf) to view the selected list.\n\n",
                    },
                    {
                        "id": 3,
                        "cta": None,
                        "data": "To generate the passbook, please [click here](https://tirupatibalaji.ap.gov.in/#/donorPassbook)",
                    },
                    {"id": 4, "cta": "Elsewhere", "data": "See [this page](https://example.com/ttd) or [that](http://tirumala.org/x)"},
                    {"id": 5, "cta": "Empty", "data": "  \n "},
                ],
            },
        },
        {"id": 76, "attributes": {"updatedAt": "2026-12-01T00:00:00.000Z", "update": []}},
    ]
}


def test_parse_ttd_updates_cleans_text_and_keeps_only_official_links():
    out = temple_updates.parse_ttd_updates(FEED, fetched=datetime(2026, 11, 11, 18, 40, tzinfo=UTC))
    assert out["source"] == temple_updates.TTD_PORTAL
    assert out["fetched"] == "2026-11-11T18:40:00Z"
    assert out["updated"] == "2026-11-10T07:18:07.847Z"  # rows without announcements do not count
    rooms, dip, passbook, elsewhere = out["items"]
    # A pointer after a finished sentence is dropped; pages inside the portal need a login, so no link.
    assert rooms == {
        "id": 1,
        "title": "Accommodation",
        "text": "Tirumala and Tirupati Accommodation Quota for January-2027 will be available for booking "
        "w.e.f. 24.10.2026, 03:00 PM.",
        "url": None,
    }
    assert dip["title"] == "Seva E-Dip"
    assert dip["text"] == "Registrations received:\nArchana: 676563\nPlease Click Here to view the selected list."
    assert dip["url"] == "https://ttdevasthanams.ap.gov.in/assets/list.pdf"
    assert passbook["title"] == ""
    assert passbook["text"] == "To generate the passbook, please click here"
    assert passbook["url"] == "https://tirupatibalaji.ap.gov.in/#/donorPassbook"
    assert elsewhere["text"] == "See this page or that"
    assert elsewhere["url"] is None  # not an official site, and not HTTPS


def test_parse_ttd_updates_limits_size():
    feed = {"data": [{"attributes": {"updatedAt": "x", "update": [{"id": i, "data": "word " * 400} for i in range(50)]}}]}
    out = temple_updates.parse_ttd_updates(feed)
    assert len(out["items"]) == temple_updates.MAX_ITEMS
    assert len(out["items"][0]["text"]) == temple_updates.MAX_TEXT
    assert out["items"][0]["text"].endswith("…")
    assert temple_updates.parse_ttd_updates({})["items"] == []


def test_fetch_falls_back_to_the_published_copy(monkeypatch):
    previous = {"source": "s", "fetched": "2026-11-10T18:40:00Z", "items": [{"id": 1, "text": "Earlier"}]}

    def get_json(url, timeout):
        if url == temple_updates.TTD_FEED:
            raise OSError("temple site is down")
        return previous

    monkeypatch.setattr(temple_updates, "_get_json", get_json)
    assert temple_updates.fetch_ttd_updates(previous_url="https://example.org/copy.json") == previous
    assert temple_updates.fetch_ttd_updates() is None

    monkeypatch.setattr(temple_updates, "_get_json", lambda url, timeout: FEED)
    assert len(temple_updates.fetch_ttd_updates()["items"]) == 4
