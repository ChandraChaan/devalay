"""Shubha Muhurtham dates checked against Drik Panchang's published 2027 lists (tests/data/drik_muhurat.json)."""

import json
from datetime import date
from pathlib import Path

import pytest

from app.services import muhurtham
from app.services.panchang import Location

DRIK = json.loads((Path(__file__).parent / "data" / "drik_muhurat.json").read_text())
YEAR = 2027
# Share of Drik's dates we must find, and how many dates of our own Drik does not list. Vivaha misses come
# from Shukra and Guru combustion: we use the Surya Siddhanta orbs on modern positions, Drik its own model.
EXPECT = {"vivaha": (0.85, 6), "griha_pravesha": (0.95, 1), "vehicle": (0.97, 4)}


@pytest.fixture(scope="module")
def ours():
    out = {}
    for city, c in DRIK["meta"]["cities"].items():
        loc = Location(c["lat"], c["lon"], "Asia/Kolkata")
        for kind in EXPECT:
            days = muhurtham.muhurtham_dates(kind, loc, date(YEAR, 1, 1), date(YEAR, 12, 31), cut_rahu=False)
            out[kind, city] = {d["d"]: d for d in days}
    return out


@pytest.mark.parametrize("kind", list(EXPECT))
@pytest.mark.parametrize("city", ["hyderabad", "delhi"])
def test_dates_agree_with_drik(ours, kind, city):
    drik = {d: w for d, w in DRIK[kind][city].items() if d.startswith(str(YEAR))}
    mine = ours[kind, city]
    found = set(drik) & set(mine)
    share, extra = EXPECT[kind]
    assert len(found) >= share * len(drik), sorted(set(drik) - set(mine))
    assert len(set(mine) - set(drik)) <= extra, sorted(set(mine) - set(drik))
    # On the shared days the window opens and closes at the same minute, give or take five.
    close = [d for d in found if abs(mine[d]["w"][0][0] - drik[d][0][0]) <= 5
             and abs(mine[d]["w"][-1][1] - drik[d][-1][1]) <= 5]
    assert len(close) >= 0.93 * len(found)


def test_rahu_kalam_is_cut_and_lagna_is_recommended():
    loc = Location(17.384, 78.456, "Asia/Kolkata")
    day = date(2027, 2, 22)  # a long vivaha window across the whole day
    plain = muhurtham.muhurtham_dates("vivaha", loc, day, day, cut_rahu=False)[0]
    cut = muhurtham.muhurtham_dates("vivaha", loc, day, day)[0]
    assert len(cut["w"]) == len(plain["w"]) + 1  # Monday's Rahu Kalam splits the window
    s, e, sign = cut["l"]
    assert sign in muhurtham.VIVAHA.lagnas and e - s > 30
    assert cut["w"][0][0] <= s < e <= cut["w"][-1][1]


def test_combustion_spans():
    sk = muhurtham.sky(date(YEAR, 1, 1), date(YEAR, 12, 31))
    tz = muhurtham.ZoneInfo("Asia/Kolkata")
    # Drik Panchang: Guru asta 17 Aug - 13 Sep 2027, Shukra asta 21 Jul - 9 Sep 2027 (New Delhi).
    assert muhurtham.asta_reason(sk, date(2027, 8, 30), tz) == "guru_asta"
    assert muhurtham.asta_reason(sk, date(2027, 7, 25), tz) == "shukra_asta"
    assert muhurtham.asta_reason(sk, date(2027, 9, 20), tz) == "guru_bala"
    assert muhurtham.asta_reason(sk, date(2027, 3, 1), tz) is None
