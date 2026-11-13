"""Eclipses for 2026-2027 checked against published local times."""

from datetime import date

import pytest

from app.services import eclipses
from app.services.panchang import Location

DELHI = Location(28.61, 77.21, "Asia/Kolkata")


@pytest.fixture(scope="module")
def delhi():
    return {(e["kind"], e["date"]): e for e in eclipses.eclipses(DELHI, date(2026, 1, 1), date(2027, 12, 31))}


def test_every_eclipse_is_listed(delhi):
    # NASA Five Millennium Canon: 2026 Feb 17 annular, Mar 3 total lunar, Aug 12 total, Aug 28 partial lunar;
    # 2027 Feb 6 annular, Feb 20/21 penumbral, Jul 18 penumbral, Aug 2 total, Aug 17 penumbral.
    assert [(k, e["type"]) for (k, _), e in sorted(delhi.items(), key=lambda x: x[0][1])] == [
        ("solar", "annular"), ("lunar", "total"), ("solar", "total"), ("lunar", "partial"),
        ("solar", "annular"), ("lunar", "penumbral"), ("lunar", "penumbral"), ("solar", "total"),
        ("lunar", "penumbral"),
    ]


def test_total_lunar_eclipse_3_march_2026(delhi):
    # Drik Panchang, New Delhi: partial phase 15:20-18:47, the Moon rises eclipsed at about 18:22,
    # penumbra ends 19:53, Sutak from 06:20 (9 hours before the eclipse begins).
    e = delhi["lunar", "2026-03-03"]
    assert e["begins"].endswith("T15:20+05:30") and e["ends"].endswith("T18:47+05:30")
    assert e["contacts"]["total_begin"].endswith("T16:35+05:30") and e["max"].endswith("T17:03+05:30")
    assert e["contacts"]["penumbral_end"].endswith("T19:53+05:30")
    assert e["visible"] and e["visible_from"][11:16] in ("18:22", "18:23")
    assert e["sutak"] == {"starts": "2026-03-03T06:20+05:30", "ends": "2026-03-03T18:47+05:30"}


def test_partial_solar_eclipse_2_august_2027(delhi):
    # Partial in Delhi: 15:53, greatest 16:29, ends 17:02 (muhuratam.in); Sutak 12 hours before.
    e = delhi["solar", "2027-08-02"]
    assert e["type"] == "total" and e["local_type"] == "partial"
    assert (e["begins"][11:16], e["max"][11:16], e["ends"][11:16]) == ("15:53", "16:29", "17:02")
    assert e["sutak"]["starts"] == "2027-08-02T03:53+05:30"


def test_no_sutak_when_not_visible_or_penumbral(delhi):
    assert not delhi["lunar", "2026-08-28"]["visible"]  # daytime in India
    assert delhi["lunar", "2026-08-28"]["sutak"] is None
    assert delhi["solar", "2026-08-12"]["sutak"] is None
    feb = delhi["lunar", "2027-02-21"]
    assert feb["visible"] and feb["sutak"] is None


def test_visible_abroad():
    london = eclipses.eclipses(Location(51.51, -0.13, "Europe/London"), date(2026, 8, 1), date(2026, 8, 31))
    solar = next(e for e in london if e["kind"] == "solar")
    assert solar["visible"] and solar["local_type"] == "partial" and solar["magnitude"] > 0.9


def test_api_endpoints(client):
    r = client.get("/api/v1/eclipses", params={"lat": 17.39, "lon": 78.49, "tz": "Asia/Kolkata"})
    assert r.status_code == 200 and {e["kind"] for e in r.json()} == {"solar", "lunar"}
    g = client.get("/api/v1/gochara").json()
    assert set(g["planets"]) == {"sun", "jupiter", "saturn"}
    assert len(g["moon"]) == (date.fromisoformat(g["to"]) - date.fromisoformat(g["from"])).days + 1
    m = client.get("/api/v1/muhurtham", params={"lat": 17.39, "lon": 78.49, "tz": "Asia/Kolkata"}).json()
    assert set(m["kinds"]) == {"vivaha", "griha_pravesha", "vehicle", "namakarana"}
    day = m["kinds"]["vivaha"][0]
    assert day["d"] >= m["from"] and day["w"] and day["n"]
