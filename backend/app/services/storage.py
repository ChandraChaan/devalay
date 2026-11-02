"""Media storage: local disk in development, Cloudflare R2 (S3 API) in production."""

from __future__ import annotations

import mimetypes
import re
import uuid
from functools import lru_cache
from pathlib import Path

from app.config import get_settings

ALLOWED_TYPES = {
    "audio/mpeg", "audio/mp4", "audio/aac", "audio/ogg", "audio/x-m4a", "audio/wav", "audio/x-wav",
    "image/jpeg", "image/png", "image/webp", "video/mp4", "video/webm", "application/pdf",
}
MAX_BYTES = 200 * 1024 * 1024


class StorageError(ValueError):
    pass


def safe_key(folder: str, filename: str) -> str:
    stem = re.sub(r"[^a-zA-Z0-9._-]+", "-", Path(filename).stem).strip("-").lower()[:60] or "file"
    ext = Path(filename).suffix.lower()[:8]
    folder = re.sub(r"[^a-z0-9-]+", "", folder.lower()) or "misc"
    return f"{folder}/{uuid.uuid4().hex[:12]}-{stem}{ext}"


def guess_type(filename: str, declared: str | None) -> str:
    content_type = (declared or "").split(";")[0].strip() or mimetypes.guess_type(filename)[0] or ""
    if content_type not in ALLOWED_TYPES:
        raise StorageError(f"File type {content_type or 'unknown'} is not allowed")
    return content_type


@lru_cache(maxsize=1)
def _r2_client():
    import boto3

    s = get_settings()
    return boto3.client(
        "s3",
        endpoint_url=f"https://{s.r2_account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=s.r2_access_key_id,
        aws_secret_access_key=s.r2_secret_access_key,
        region_name="auto",
    )


def put(key: str, data: bytes, content_type: str) -> str:
    """Store bytes and return the public URL."""
    if len(data) > MAX_BYTES:
        raise StorageError("File too large")
    s = get_settings()
    if s.storage_backend == "r2":
        _r2_client().put_object(
            Bucket=s.r2_bucket, Key=key, Body=data, ContentType=content_type,
            CacheControl="public, max-age=31536000, immutable",
        )
        return f"{s.r2_public_base_url.rstrip('/')}/{key}"
    root = Path(s.media_dir).resolve()
    path = (root / key).resolve()
    if root not in path.parents:
        raise StorageError("Invalid key")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return f"{s.public_base_url.rstrip('/')}/media/{key}"


def delete(key: str) -> None:
    s = get_settings()
    if s.storage_backend == "r2":
        _r2_client().delete_object(Bucket=s.r2_bucket, Key=key)
        return
    root = Path(s.media_dir).resolve()
    path = (root / key).resolve()
    if root in path.parents and path.exists():
        path.unlink()
