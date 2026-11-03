def test_health_and_config(client):
    assert client.get("/api/v1/health").json()["status"] == "ok"
    cfg = client.get("/api/v1/config").json()
    assert cfg["ai_enabled"] is False
    assert cfg["privacy_url"].endswith("/privacy")


def test_security_headers(client):
    r = client.get("/api/v1/health")
    assert r.headers["x-content-type-options"] == "nosniff"
    assert r.headers["x-frame-options"] == "DENY"


def test_deities_have_portraits(client):
    deities = client.get("/api/v1/deities").json()
    assert {d["slug"] for d in deities} >= {"shiva", "hanuman", "krishna", "durga", "ganesha"}
    assert all(d["image_url"].startswith("https://") for d in deities if d["slug"] != "general")


def test_tracks_filter_and_licence_metadata(client):
    page = client.get("/api/v1/tracks", params={"kind": "ringtone"}).json()
    assert page["total"] >= 4
    assert all(t["kind"] == "ringtone" for t in page["items"])
    every = client.get("/api/v1/tracks", params={"page_size": 100}).json()["items"]
    assert all(t["license"] and t["attribution"] for t in every)
    assert {t["license"] for t in every} <= {"CC0", "Public domain", "CC BY-SA 3.0", "CC BY-SA 4.0", "FAL",
                                             "CC BY 3.0", "CC BY 4.0"}


def test_tracks_by_deity_and_unknown_deity(client):
    shiva = client.get("/api/v1/tracks", params={"deity": "shiva"}).json()
    assert shiva["total"] >= 2
    assert client.get("/api/v1/tracks", params={"deity": "zeus"}).status_code == 404


def test_play_count_increments(client):
    track = client.get("/api/v1/tracks").json()["items"][0]
    client.post(f"/api/v1/tracks/{track['id']}/play")
    assert client.get(f"/api/v1/tracks/{track['id']}").json()["play_count"] == track["play_count"] + 1


def test_texts_list_and_detail(client):
    aartis = client.get("/api/v1/texts", params={"kind": "aarti"}).json()
    assert aartis["total"] >= 6
    chalisa = client.get("/api/v1/texts/hanuman-chalisa").json()
    assert chalisa["body"].count("॥") > 40
    assert "jay hanumān jñān gun sāgar" in chalisa["transliteration"]
    assert client.get("/api/v1/texts/nonexistent").status_code == 404


def test_gita(client):
    chapters = client.get("/api/v1/gita/chapters").json()
    assert len(chapters) == 18
    assert sum(c["verse_count"] for c in chapters) == 701
    ch2 = client.get("/api/v1/gita/chapters/2").json()
    assert len(ch2["verses"]) == 72
    v = client.get("/api/v1/gita/2/47").json()
    assert "कर्मण्येवाधिकारस्ते" in v["sanskrit"]
    assert v["translation_author"] == "Annie Besant"
    a = client.get("/api/v1/gita/verse-of-the-day", params={"day": "2026-01-01"}).json()
    b = client.get("/api/v1/gita/verse-of-the-day", params={"day": "2026-01-01"}).json()
    c = client.get("/api/v1/gita/verse-of-the-day", params={"day": "2026-01-02"}).json()
    assert a == b and a != c


def test_books_and_chapters(client):
    books = client.get("/api/v1/books").json()
    slugs = {b["slug"]: b for b in books}
    assert {"song-celestial", "ramayan-griffith", "mahabharata-dutt", "upanishads-paramananda"} <= set(slugs)
    assert slugs["ramayan-griffith"]["chapter_count"] > 400
    detail = client.get("/api/v1/books/song-celestial").json()
    assert len(detail["chapters"]) == 18
    ch = client.get("/api/v1/books/song-celestial/chapters/18").json()
    assert ch["has_next"] is False
    assert "PROJECT GUTENBERG" not in ch["body"].upper()


def test_wallpapers_and_videos(client):
    walls = client.get("/api/v1/wallpapers", params={"deity": "krishna"}).json()
    assert walls["total"] >= 2
    w = walls["items"][0]
    assert w["thumb_url"] and w["license"] == "Public domain"
    client.post(f"/api/v1/wallpapers/{w['id']}/download")
    videos = client.get("/api/v1/videos").json()["items"]
    assert any(v["year"] == 1913 for v in videos)


def test_search(client):
    res = client.get("/api/v1/search", params={"q": "hanuman"}).json()
    assert res["tracks"] or res["texts"]
    assert any(t["slug"] == "hanuman-chalisa" for t in res["texts"])
    hindi = client.get("/api/v1/search", params={"q": "गायत्री"}).json()
    assert hindi["texts"] or hindi["tracks"]
    # LIKE wildcards in user input are escaped, not interpreted.
    assert client.get("/api/v1/search", params={"q": "%%"}).status_code == 200


def test_home_payload(client):
    home = client.get("/api/v1/home").json()
    assert home["panchang"]["tithi"]["name"]
    assert home["verse_of_day"]["sanskrit"]
    assert len(home["featured_tracks"]) > 0
    assert len(home["upcoming_festivals"]) > 0
    assert home["banners"][0]["title"]


def test_static_pages(client):
    for path in ("/", "/privacy", "/terms"):
        r = client.get(path)
        assert r.status_code == 200
        assert "Devalay" in r.text
