#!/bin/sh
set -e
alembic upgrade head
if [ "${DEVALAY_SEED_ON_START:-0}" = "1" ]; then
  python -m app.cli seed
fi
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" --workers "${WEB_CONCURRENCY:-2}" \
  --proxy-headers --forwarded-allow-ips="*" --no-server-header
