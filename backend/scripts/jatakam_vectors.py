"""Reference positions for the on-phone Jatakam engine (app/lib/core/jatakam.dart).

Writes app/test/data/jatakam_vectors.json: for random births between 1900 and 2049, the Lahiri sidereal
longitudes of the Sun, Moon and planets and the ascendant, computed with Skyfield and JPL DE421 the same
way as the server's Panchang (apparent ecliptic longitude of date minus the Lahiri ayanamsa).

Usage (from backend/): python scripts/jatakam_vectors.py
"""

import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from skyfield.framelib import ecliptic_frame  # noqa: E402

from app.services import panchang  # noqa: E402
from app.services.muhurtham import _ascendant  # noqa: E402
from app.services.panchang import Location  # noqa: E402

BODIES = {"sun": "sun", "moon": "moon", "mercury": "mercury", "venus": "venus", "mars": "mars",
          "jupiter": "jupiter barycenter", "saturn": "saturn barycenter"}
OUT = ROOT.parent / "app" / "test" / "data" / "jatakam_vectors.json"


def main() -> None:
    rng = random.Random(108)
    ts, eph = panchang._ephemeris()
    cases = []
    for _ in range(150):
        year = rng.randint(1900, 2049)
        # Clock times are taken as UT1: before 1972 there was no UTC as Skyfield defines it, and civil
        # time followed mean solar time.
        parts = (year, rng.randint(1, 12), rng.randint(1, 28), rng.randint(0, 23), rng.randint(0, 59))
        t = ts.ut1(*parts)
        lat, lon = round(rng.uniform(-40, 55), 2), round(rng.uniform(-125, 150), 2)
        earth = eph["earth"].at(t)
        aya = float(panchang.ayanamsa(t))
        y, mo, d, h, mi = parts
        case = {"utc": f"{y:04d}-{mo:02d}-{d:02d}T{h:02d}:{mi:02d}:00Z", "lat": lat, "lon": lon, "ayanamsa": round(aya, 6)}
        for key, body in BODIES.items():
            _, lam, _ = earth.observe(eph[body]).apparent().frame_latlon(ecliptic_frame)
            case[key] = round((lam.degrees - aya) % 360.0, 5)
        case["ascendant"] = round(float(_ascendant(t.tt, Location(lat, lon))), 5)
        cases.append(case)
    OUT.write_text(json.dumps(cases, indent=0))
    print(f"{len(cases)} cases -> {OUT}")


if __name__ == "__main__":
    main()
