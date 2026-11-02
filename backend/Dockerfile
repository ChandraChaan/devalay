# syntax=docker/dockerfile:1
FROM python:3.13-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /srv

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app
COPY alembic ./alembic
COPY alembic.ini docker-entrypoint.sh ./
COPY media/seed ./media/seed

# Bake the NASA JPL DE421 ephemeris (public domain, 17 MB) into the image.
RUN python -c "from app.services.panchang import ensure_ephemeris; ensure_ephemeris()" \
 && useradd --uid 10001 --no-create-home devalay \
 && chown -R devalay /srv/media \
 && chmod +x docker-entrypoint.sh
USER devalay

ENV DEVALAY_ENV=production PORT=8000
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD python -c "import urllib.request,os; urllib.request.urlopen(f'http://127.0.0.1:{os.environ.get(\"PORT\",\"8000\")}/api/v1/health', timeout=4)"
ENTRYPOINT ["./docker-entrypoint.sh"]
