import os
import tempfile
from pathlib import Path

import pytest

_tmp = Path(tempfile.mkdtemp(prefix="devalay-test-"))
if not os.environ.get("DEVALAY_DATABASE_URL"):  # CI sets it to Postgres, or empty for SQLite
    os.environ["DEVALAY_DATABASE_URL"] = f"sqlite:///{_tmp / 'test.db'}"
os.environ["DEVALAY_ENV"] = "test"
os.environ["DEVALAY_MEDIA_DIR"] = str(_tmp / "media")
os.environ["DEVALAY_ANTHROPIC_API_KEY"] = ""
os.environ["DEVALAY_SECRET_KEY"] = "test-secret-key-that-is-long-enough-for-hs256"

from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.seed.loader import load_all  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def database():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        load_all(db, include_books=True)
    yield


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def db():
    with SessionLocal() as session:
        yield session


_counter = {"n": 0}


@pytest.fixture()
def user_tokens(client):
    _counter["n"] += 1
    email = f"devotee{_counter['n']}@example.com"
    r = client.post("/api/v1/auth/register", json={"email": email, "password": "jai-shri-ram-108", "display_name": "Bhakt"})
    assert r.status_code == 201, r.text
    data = r.json()
    data["email"] = email
    return data


@pytest.fixture()
def auth(user_tokens):
    return {"Authorization": f"Bearer {user_tokens['access_token']}"}
