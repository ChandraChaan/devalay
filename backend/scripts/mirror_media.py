"""Copy seed media to your own storage (Cloudflare R2) and repoint the database at it.

Wikimedia Commons allows hot-linking, but a production app with many users should
serve media from its own bucket/CDN: it is faster, cheaper for Wikimedia and keeps
working if a file is renamed upstream. Attribution fields are left unchanged.

Usage (with DEVALAY_STORAGE_BACKEND=r2 and the R2 settings in the environment):
    python scripts/mirror_media.py            # copy everything not yet mirrored
    python scripts/mirror_media.py --dry-run  # show what would be copied
"""

import argparse
import hashlib
import mimetypes
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

import httpx
from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import get_settings  # noqa: E402
from app.db import SessionLocal  # noqa: E402
from app.models import Deity, Track, Video, Wallpaper  # noqa: E402
from app.services import storage  # noqa: E402

HEADERS = {"User-Agent": "DevalayMediaMirror/1.0 (https://github.com/ChandraChaan/devalay)"}
FIELDS = [
    (Track, ["audio_url", "artwork_url"]),
    (Wallpaper, ["image_url", "thumb_url"]),
    (Video, ["video_url", "thumbnail_url"]),
    (Deity, ["image_url"]),
]
SEED_DIR = Path(__file__).resolve().parent.parent / "media" / "seed"


def key_for(url: str, folder: str) -> str:
    ext = Path(urlparse(url).path).suffix.lower()[:6] or ".bin"
    return f"{folder}/{hashlib.sha256(url.encode()).hexdigest()[:20]}{ext}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    s = get_settings()
    if s.storage_backend != "r2" and not args.dry_run:
        sys.exit("Set DEVALAY_STORAGE_BACKEND=r2 (and the R2 credentials) before mirroring.")
    own_prefix = s.r2_public_base_url.rstrip("/")

    # Original Devalay sounds are uploaded from disk under the same "seed/" keys the loader uses.
    for path in sorted(SEED_DIR.glob("*.m4a")):
        print("seed", path.name)
        if not args.dry_run:
            storage.put(f"seed/{path.name}", path.read_bytes(), "audio/mp4")

    copied: dict[str, str] = {}
    with SessionLocal() as db, httpx.Client(headers=HEADERS, follow_redirects=True, timeout=300) as http:
        for model, fields in FIELDS:
            for row in db.execute(select(model)).scalars():
                for field in fields:
                    url = getattr(row, field)
                    if not url or (own_prefix and url.startswith(own_prefix)):
                        continue
                    if "/media/seed/" in url:
                        new = f"{own_prefix}/seed/{url.rsplit('/', 1)[-1]}"
                    elif url in copied:
                        new = copied[url]
                    else:
                        key = key_for(url, model.__tablename__)
                        print(f"{model.__tablename__}.{field}: {url[:90]}")
                        if args.dry_run:
                            continue
                        resp = http.get(url)
                        resp.raise_for_status()
                        content_type = resp.headers.get("content-type", "").split(";")[0] or \
                            mimetypes.guess_type(url)[0] or "application/octet-stream"
                        new = storage.put(key, resp.content, content_type)
                        copied[url] = new
                        time.sleep(0.5)  # be gentle with Wikimedia
                    if not args.dry_run:
                        setattr(row, field, new)
            if not args.dry_run:
                db.commit()
    print(f"done; {len(copied)} remote files mirrored")


if __name__ == "__main__":
    main()
