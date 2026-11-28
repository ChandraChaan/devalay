"""Build the media for the Ringtones, Wallpapers and WhatsApp Status sections and write their catalogue.

Steps (each reads the cache of the one before, so they can be re-run one at a time):
  fetch       download the source art from Wikimedia Commons with its author and licence
  wallpapers  compose each artwork for 20:9 phones: QHD+ (1440x3200), FHD+ (1080x2400) and a grid thumbnail
  ringtones   cut, loudness-normalise and fade the ringtones, plus a short notification cut of each
  meditation  loudness-normalise the seamless meditation loops (from scripts/synth_tones.py, run first)
  videos      render the 9:16 1080p status videos (slow zoom on the art, typeset text, licensed audio)
  catalog     write app/assets/data/sections.json (bundled, and published by the static API)

Usage:
  python scripts/build_sections_media.py WORK_DIR fetch wallpapers ringtones videos catalog
  gh release upload media-sections-v1 WORK_DIR/out/* --repo ChandraChaan/devalay

Needs ffmpeg and Pillow with libraqm (complex-script shaping for Telugu and Devanagari).
"""

from __future__ import annotations

import hashlib
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import modern_designs  # noqa: E402
from sections_spec import AUDIO, MEDITATION, PHOTOS, RINGTONES, STATUS_VIDEOS, WALLPAPERS  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "app" / "assets" / "data" / "sections.json"
# Every file (grid thumbnails, posters, wallpapers, ringtones, videos, soundscapes) is an asset of the
# media-sections-v1 release, served from GitHub's CDN; the app caches what it shows.
FONTS = ROOT / "app" / "assets" / "fonts"
RELEASE_TAG = "media-sections-v1"
RELEASE = f"https://github.com/ChandraChaan/devalay/releases/download/{RELEASE_TAG}"
TELUGU_RELEASE = "https://github.com/ChandraChaan/devalay/releases/download/media-telugu-v1"
PAGES_SEED = "https://chandrachaan.github.io/devalay/media/seed"
API = "https://commons.wikimedia.org/w/api.php"
HEADERS = {"User-Agent": "DevalayContentBuilder/1.0 (https://github.com/ChandraChaan/devalay)"}
ALLOWED = {"Public domain", "CC0", "CC BY 2.0", "CC BY 2.5", "CC BY 3.0", "CC BY 4.0", "CC BY-SA 2.0",
           "CC BY-SA 2.5", "CC BY-SA 3.0", "CC BY-SA 4.0", "FAL"}
LICENSE_URLS = {
    "CC0": "https://creativecommons.org/publicdomain/zero/1.0/",
    "CC BY 3.0": "https://creativecommons.org/licenses/by/3.0/",
    "CC BY 4.0": "https://creativecommons.org/licenses/by/4.0/",
    "CC BY-SA 2.0": "https://creativecommons.org/licenses/by-sa/2.0/",
    "CC BY-SA 3.0": "https://creativecommons.org/licenses/by-sa/3.0/",
    "CC BY-SA 4.0": "https://creativecommons.org/licenses/by-sa/4.0/",
    "FAL": "https://artlibre.org/licence/lal/en/",
}

QHD = (1440, 3200)
FHD = (1080, 2400)
THUMB = (360, 800)


def run(*cmd: str) -> str:
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def get_json(url: str) -> dict:
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as r:
                return json.load(r)
        except Exception:  # noqa: BLE001 - Commons rate limits now and then; back off and retry
            if attempt == 3:
                raise
            time.sleep(5 * (attempt + 1))
    raise AssertionError


def download(url: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=180) as r:
                dest.write_bytes(r.read())
            return
        except Exception:  # noqa: BLE001
            if attempt == 3:
                raise
            time.sleep(8 * (attempt + 1))


def clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", html.unescape(text or ""))
    return re.sub(r"\s+", " ", text).strip()


def commons_info(title: str, width: int = 2880) -> dict:
    q = urllib.parse.urlencode({
        "action": "query", "format": "json", "titles": title, "prop": "imageinfo",
        "iiprop": "url|size|extmetadata", "iiurlwidth": width,
        "iiextmetadatafilter": "Artist|LicenseShortName|LicenseUrl|ObjectName|Credit"})
    page = next(iter(get_json(f"{API}?{q}")["query"]["pages"].values()))
    if "imageinfo" not in page:
        raise SystemExit(f"Not on Commons: {title}")
    ii = page["imageinfo"][0]
    meta = ii.get("extmetadata", {})
    lic = clean(meta.get("LicenseShortName", {}).get("value", ""))
    if lic not in ALLOWED:
        raise SystemExit(f"{title}: licence {lic!r} is not allowed")
    artist = clean(meta.get("Artist", {}).get("value", "")) or "Unknown"
    if len(artist) > 80:
        artist = artist[:77] + "…"
    # Ask for a resized copy only when the original is larger (or not a JPEG, e.g. museum TIFF scans).
    big = ii["width"] > width or not title.lower().endswith((".jpg", ".jpeg"))
    return {
        "url": ii["thumburl"] if big else ii["url"],
        "width": ii["width"], "height": ii["height"], "license": lic,
        "license_url": clean(meta.get("LicenseUrl", {}).get("value", "")) or LICENSE_URLS.get(lic, ""),
        "author": artist, "source_url": ii["descriptionurl"],
    }


# --- fetch ----------------------------------------------------------------------------------------------------

def fetch(work: Path) -> None:
    src = work / "src"
    src.mkdir(parents=True, exist_ok=True)
    meta_path = work / "art.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    files = {w[3] for w in WALLPAPERS} | {p[3] for p in PHOTOS}
    for title in sorted(files):
        key = slug_for(title)
        if key not in meta:
            meta[key] = {"title": title, **commons_info(title)}
            time.sleep(0.5)
        download(meta[key]["url"], src / f"{key}.jpg")
        print("art", key, meta[key]["width"], meta[key]["height"], meta[key]["license"])
    meta_path.write_text(json.dumps(meta, indent=1, ensure_ascii=False))


def slug_for(title: str) -> str:
    return hashlib.sha1(title.encode()).hexdigest()[:12]


    for step in sys.argv[2:]:
        steps[step](work_dir)


# --- wallpapers -----------------------------------------------------------------------------------------------

def _art(work: Path, slug: str):
    from PIL import Image, ImageOps
    spec = next(w for w in [*WALLPAPERS, *PHOTOS] if w[0] == slug)
    # Phone photos are often stored sideways with an EXIF orientation tag.
    im = ImageOps.exif_transpose(Image.open(work / "src" / f"{slug_for(spec[3])}.jpg")).convert("RGB")
    if spec in PHOTOS:
        return im
    if spec[4]:
        left, top, right, bottom = spec[4]
        im = im.crop((round(left * im.width), round(top * im.height), round(right * im.width),
                      round(bottom * im.height)))
    return im


def compose(art, size: tuple[int, int], center: float = 0.56, max_height: float = 0.8):
    """The artwork at full width over a soft, blurred, darkened copy of itself, its edges feathered into the
    backdrop. The top stays calm for the clock, the bottom for the dock."""
    from PIL import Image, ImageEnhance, ImageFilter
    width, height = size
    # Backdrop: cover-fit at a quarter of the size, blurred, then scaled up (fast and smooth).
    small = (width // 4, height // 4)
    scale = max(small[0] / art.width, small[1] / art.height)
    bg = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
    bg = bg.crop(((bg.width - small[0]) // 2, (bg.height - small[1]) // 2,
                  (bg.width - small[0]) // 2 + small[0], (bg.height - small[1]) // 2 + small[1]))
    bg = bg.filter(ImageFilter.GaussianBlur(small[0] / 22))
    bg = ImageEnhance.Color(bg).enhance(1.15)
    bg = ImageEnhance.Brightness(bg).enhance(0.55).resize(size, Image.BICUBIC)

    scale = min(width / art.width, height * max_height / art.height)
    w, h = round(art.width * scale), round(art.height * scale)
    fg = art.resize((w, h), Image.LANCZOS)
    top = min(max(0, round(height * center - h / 2)), height - h)
    left = (width - w) // 2
    mask = _feather((w, h), feather_x=0 if w >= width else 0.06, feather_y=0.07 if h < height else 0)
    bg.paste(fg, (left, top), mask)
    return _vignette(bg)


def _feather(size: tuple[int, int], feather_x: float, feather_y: float):
    import numpy as np
    from PIL import Image
    w, h = size

    def ramp(n: int, frac: float):
        if frac <= 0:
            return np.ones(n)
        k = max(1, round(n * frac))
        r = np.ones(n)
        edge = np.linspace(0, 1, k) ** 1.6
        r[:k] = edge
        r[-k:] = edge[::-1]
        return r

    alpha = np.outer(ramp(h, feather_y), ramp(w, feather_x))
    return Image.fromarray((alpha * 255).astype("uint8"), "L")


def _vignette(im, strength: float = 0.28):
    import numpy as np
    from PIL import Image
    w, h = im.size
    y, x = np.ogrid[-1:1:complex(0, h), -1:1:complex(0, w)]
    d = np.clip(np.sqrt(x * x * 0.9 + y * y * 0.6), 0, 1.4)
    shade = 1 - strength * np.clip(d - 0.55, 0, None) / 0.85
    arr = np.asarray(im).astype("float32") * shade[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype("uint8"))


def cover(im, size: tuple[int, int], focus: tuple[float, float]):
    """[im] cropped edge to edge to [size]'s aspect around [focus], then resized, lightly sharpened."""
    from PIL import Image, ImageFilter
    w, h = size
    scale = max(w / im.width, h / im.height)
    cw, ch = w / scale, h / scale
    left = min(max(0, im.width * focus[0] - cw / 2), im.width - cw)
    top = min(max(0, im.height * focus[1] - ch / 2), im.height - ch)
    out = im.resize(size, Image.LANCZOS, box=(left, top, left + cw, top + ch))
    return _vignette(out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=35, threshold=2)), strength=0.18)


def dominant_color(im) -> str:
    from PIL import ImageStat
    r, g, b = (int(v * 0.6) for v in ImageStat.Stat(im.resize((32, 32))).mean[:3])
    return f"#{r:02X}{g:02X}{b:02X}"


def wallpapers(work: Path) -> None:
    from PIL import Image
    out = pages = work / "out"
    out.mkdir(parents=True, exist_ok=True)
    colors = {}

    def save(slug: str, qhd) -> None:
        qhd.save(out / f"wp-{slug}-qhd.jpg", quality=92, optimize=True, progressive=True, subsampling=0)
        qhd.resize(FHD, Image.LANCZOS).save(out / f"wp-{slug}-fhd.jpg", quality=90, optimize=True, progressive=True)
        qhd.resize(THUMB, Image.LANCZOS).save(pages / f"wp-{slug}-thumb.jpg", quality=80, optimize=True, progressive=True)
        colors[slug] = dominant_color(qhd)

    for slug, *_rest in modern_designs.DESIGNS:
        png = modern_designs.render(slug, work / "designs" / f"{slug}.png")
        save(slug, Image.open(png).convert("RGB").resize(QHD, Image.LANCZOS))
        print("design", slug)
    for slug, _deity, _t, _file, focus, _tags, _rank in PHOTOS:
        save(slug, cover(_art(work, slug), QHD, focus))
        print("photo", slug)
    for spec in WALLPAPERS:
        slug = spec[0]
        art = _art(work, slug)
        landscape = art.width > art.height
        save(slug, compose(art, QHD, center=0.52 if landscape else 0.56))
        print("wallpaper", slug, art.size)
    (work / "colors.json").write_text(json.dumps(colors, indent=1))


# --- audio ----------------------------------------------------------------------------------------------------

def audio_source(work: Path, key: str) -> Path:
    where, file, *_ = AUDIO[key]
    dest = work / "audio" / f"{key}{Path(file).suffix or '.ogg'}"
    if where == "seed":
        return ROOT / "backend" / "media" / "seed" / file
    if where == "synth":  # scripts/synth_tones.py writes these into WORK_DIR/synth
        return work / "synth" / file
    if where == "telugu":
        download(f"{TELUGU_RELEASE}/{file}", dest)
    else:
        q = urllib.parse.urlencode({"action": "query", "format": "json", "titles": file, "prop": "imageinfo",
                                    "iiprop": "url"})
        page = next(iter(get_json(f"{API}?{q}")["query"]["pages"].values()))
        download(page["imageinfo"][0]["url"], dest)
    return dest


def _envelope(path: Path, seconds: float):
    """Loudness in dB of each 100 ms of the first [seconds], mono at 8 kHz."""
    import numpy as np
    raw = subprocess.run(["ffmpeg", "-v", "error", "-t", str(seconds), "-i", str(path), "-ac", "1", "-ar", "8000",
                          "-f", "f32le", "-"], check=True, capture_output=True).stdout
    pcm = np.frombuffer(raw, dtype="float32")
    frames = pcm[: len(pcm) // 800 * 800].reshape(-1, 800)
    return 20 * np.log10(np.sqrt((frames ** 2).mean(axis=1)) + 1e-6)


def pick_window(path: Path, length: float, start: float | None, search: float = 150) -> tuple[float, float]:
    """(start, end) seconds. With [start] given, cut at the quietest 100 ms near [start]+[length]. Otherwise the
    loudest [length]-second stretch in the first [search] seconds that begins and ends at a breath (a local dip
    in loudness), so the tone starts on a phrase and does not stop mid-word."""
    import numpy as np
    env = _envelope(path, (start or 0) + search + length + 4)
    n = int(length * 10)
    smooth = np.convolve(env, np.ones(5) / 5, mode="same")
    if start is None:
        loud = smooth > smooth.max() - 30
        first = int(np.argmax(loud))  # skip leading silence
        dips = [i for i in range(first + 1, max(first + 2, len(smooth) - n - 1))
                if smooth[i] <= smooth[i - 1] and smooth[i] <= smooth[i + 1]] or [first]
        best = max(dips, key=lambda i: smooth[i + 5:i + n].mean() if i + n < len(smooth) else -999)
        s = best
    else:
        s = int(start * 10)
    lo, hi = s + n - 40, min(len(smooth) - 1, s + n + 20)
    e = s + n if hi <= lo else lo + int(np.argmin(smooth[lo:hi]))
    return s / 10, e / 10


def master(src: Path, dest: Path, start: float, end: float, lufs: float, fade_out: float, fades: bool = True,
           tp: float = -1.0, bitrate: str = "160k") -> float:
    """Trim, two-pass EBU R128 loudness normalisation (linear, so a loop stays seamless), a short fade-in and a
    gentle fade-out unless [fades] is off; AAC in M4A."""
    length = end - start
    trim = ["-ss", f"{start:.2f}", "-t", f"{length:.2f}", "-i", str(src)]
    measure = subprocess.run(["ffmpeg", "-hide_banner", *trim, "-af",
                              f"loudnorm=I={lufs}:TP={tp}:LRA=11:print_format=json", "-f", "null", "-"],
                             capture_output=True, text=True).stderr
    m = json.loads(measure[measure.rindex("{"):measure.rindex("}") + 1])
    norm = (f"loudnorm=I={lufs}:TP={tp}:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
            f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:"
            f"linear=true")
    fade = f",afade=t=in:d=0.12,afade=t=out:st={max(0.0, length - fade_out):.2f}:d={fade_out:.2f}" if fades else ""
    dest.parent.mkdir(parents=True, exist_ok=True)
    run("ffmpeg", "-y", "-v", "error", *trim, "-af", f"{norm},aresample=44100{fade}", "-ac", "2",
        "-c:a", "aac_at", "-b:a", bitrate, "-movflags", "+faststart", str(dest))
    return float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(dest)))


def ringtones(work: Path) -> None:
    out = work / "out"
    windows = {}
    for slug, key, _deity, _title, start, seconds, _rank in RINGTONES:
        src = audio_source(work, key)
        if seconds <= 3:
            begin, end = 0.0, float(seconds) + 0.5
        else:
            begin, end = pick_window(src, seconds, start)
        dur = master(src, out / f"rt-{slug}.m4a", begin, end, lufs=-13, fade_out=min(1.8, (end - begin) / 4))
        note_end = begin + min(3.5, end - begin)
        master(src, out / f"nt-{slug}.m4a", begin, note_end, lufs=-13, fade_out=1.0)
        windows[slug] = {"start": begin, "end": end, "seconds": round(dur, 1)}
        print("ringtone", slug, f"{begin:.1f}-{end:.1f}s")
    (work / "ringtones.json").write_text(json.dumps(windows, indent=1))


def meditation(work: Path) -> None:
    """Seamless 2-minute soundscapes: loudness evened out (−20 LUFS), no fades, so they loop cleanly."""
    out = work / "out"
    lengths = {}
    for slug, key, _title, _rank in MEDITATION:
        src = audio_source(work, key)
        seconds = float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(src)))
        lengths[slug] = round(master(src, out / f"md-{slug}.m4a", 0, seconds, lufs=-20, fade_out=0, fades=False,
                                     tp=-3.0, bitrate="128k"), 1)
        print("meditation", slug, lengths[slug])
    (work / "meditation.json").write_text(json.dumps(lengths, indent=1))


# --- status videos ----------------------------------------------------------------------------------------------

VIDEO = (1080, 1920)
FPS = 30
VIDEO_SECONDS = 15


def _font(name: str, size: int):
    from PIL import ImageFont
    return ImageFont.truetype(str(FONTS / name), size, layout_engine=ImageFont.Layout.RAQM)


def _fit_lines(draw, text: str, font_name: str, size: int, min_size: int, width: int):
    """Lines of [text] and the font: as large as fits [width], wrapping a line at a space when even
    [min_size] is too wide."""
    for s in range(size, min_size - 1, -2):
        f = _font(font_name, s)
        if all(draw.textlength(line, font=f) <= width for line in text.split("\n")):
            return text.split("\n"), f
    f = _font(font_name, min_size)
    lines = []
    for line in text.split("\n"):
        words, cur = line.split(" "), ""
        for wd in words:
            trial = f"{cur} {wd}".strip()
            if cur and draw.textlength(trial, font=f) > width:
                lines.append(cur)
                cur = wd
            else:
                cur = trial
        lines.append(cur)
    return lines, f


def _text_layer(size, lines, font, top, fill, line_gap: float, shadow: int, gold: bool = False):
    """A transparent layer with centred [lines] from [top], a soft dark shadow under them."""
    from PIL import Image, ImageDraw, ImageFilter
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    shade = Image.new("RGBA", size, (0, 0, 0, 0))
    d, ds = ImageDraw.Draw(layer), ImageDraw.Draw(shade)
    step = font.size * line_gap
    y = top
    for line in lines:
        w = d.textlength(line, font=font)
        x = (size[0] - w) / 2
        ds.text((x, y + 4), line, font=font, fill=(0, 0, 0, 220))
        d.text((x, y), line, font=font, fill=fill)
        y += step
    shade = shade.filter(ImageFilter.GaussianBlur(shadow))
    if gold:
        import numpy as np
        arr = np.asarray(layer).copy()
        ys = np.linspace(0, 1, size[1])[:, None]
        tint = np.stack([255 + 0 * ys, 236 - 60 * ys, 160 - 130 * ys], axis=-1)  # pale gold to deep saffron-gold
        mask = arr[..., 3] > 0
        rows = np.broadcast_to(tint, (size[1], size[0], 3))
        arr[..., :3][mask] = rows[mask].astype("uint8")
        layer = Image.fromarray(arr)
    return Image.alpha_composite(shade, layer), y


def _scrims(size):
    """Dark gradients behind the headline (top) and verse (bottom)."""
    import numpy as np
    from PIL import Image
    w, h = size
    ys = np.linspace(0, 1, h)
    top = np.clip((0.22 - ys) / 0.22, 0, 1) ** 1.1 * 0.85
    bottom = np.clip((ys - 0.66) / 0.16, 0, 1) ** 1.1 * 0.92
    alpha = np.maximum(top, bottom)
    arr = np.zeros((h, w, 4), dtype="uint8")
    arr[..., 3] = (alpha[:, None] * 255).astype("uint8")
    return Image.fromarray(arr, "RGBA")


def _ease(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def videos(work: Path) -> None:
    from PIL import Image, ImageDraw
    out = pages = work / "out"
    windows = {}
    only = set(filter(None, os.environ.get("ONLY", "").split(",")))  # ONLY=monday-shiva,sri-rama to try a few
    for v in STATUS_VIDEOS:
        slug = v["slug"]
        if only and slug not in only:
            continue
        dest = out / f"st-{slug}.mp4"
        art = _art(work, v["art"])
        big = (VIDEO[0] * 2, VIDEO[1] * 2)
        # The art framed in the middle (top 16% to 76%), the headline above it and the verse below it.
        base = compose(art, big, center=0.46, max_height=0.6).convert("RGBA")
        base = Image.alpha_composite(base, _scrims(big).resize(big))
        probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
        hindi = v["lang"] == "hi"
        head_lines, head_font = _fit_lines(probe, v["headline"], "Mukta-Bold.ttf" if hindi else "Ramabhadra-Regular.ttf",
                                           92, 64, 940)
        verse_lines, verse_font = _fit_lines(probe, v["verse"], "TiroDevanagariSanskrit-Regular.ttf" if hindi
                                             else "Suranna-Regular.ttf", 50, 44, 980)
        head_h = len(head_lines) * head_font.size * 1.3
        head, _ = _text_layer(VIDEO, head_lines, head_font, max(60, 300 - head_h), (255, 255, 255, 255), 1.3, 10,
                              gold=True)
        verse_h = len(verse_lines) * verse_font.size * 1.55
        verse, _ = _text_layer(VIDEO, verse_lines, verse_font, VIDEO[1] - 190 - verse_h, (255, 255, 255, 250),
                               1.55, 8)
        brand, _ = _text_layer(VIDEO, ["Devalay"], _font("Mukta-Medium.ttf", 30), VIDEO[1] - 110,
                               (255, 255, 255, 170), 1.0, 4)
        rule = Image.new("RGBA", VIDEO, (0, 0, 0, 0))
        ImageDraw.Draw(rule).line((VIDEO[0] / 2 - 70, VIDEO[1] - 150, VIDEO[0] / 2 + 70, VIDEO[1] - 150),
                                  fill=(255, 213, 79, 200), width=3)

        src = audio_source(work, v["audio"])
        begin, _ = pick_window(src, VIDEO_SECONDS, None) if AUDIO[v["audio"]][0] != "seed" else (0.0, 0.0)
        windows[slug] = begin
        audio = work / "tmp" / f"{slug}.m4a"
        master(src, audio, begin, begin + VIDEO_SECONDS, lufs=-16, fade_out=2.0)

        enc = subprocess.Popen(
            ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{VIDEO[0]}x{VIDEO[1]}",
             "-r", str(FPS), "-i", "-", "-i", str(audio), "-map", "0:v", "-map", "1:a", "-c:v", "libx264",
             "-preset", "slow", "-crf", "22", "-maxrate", "3500k", "-bufsize", "7000k", "-profile:v", "high",
             "-pix_fmt", "yuv420p", "-c:a", "copy", "-shortest", "-movflags", "+faststart", str(dest)],
            stdin=subprocess.PIPE)
        frames = VIDEO_SECONDS * FPS
        poster = None
        for i in range(frames):
            t = i / FPS
            z = 1.0 + 0.07 * _ease(t / VIDEO_SECONDS)
            cw, ch = big[0] / z, big[1] / z
            cx, cy = big[0] / 2, big[1] * 0.5
            frame = base.resize(VIDEO, Image.BICUBIC, box=(cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2))
            for layer, t0, rise in ((head, 0.4, 24), (rule, 1.0, 0), (verse, 1.2, 16), (brand, 0.0, 0)):
                a = _ease((t - t0) / 1.0) if t0 else 1.0
                if a <= 0:
                    continue
                lay = layer if a >= 1 else Image.fromarray(
                    (__import__("numpy").asarray(layer) * [1, 1, 1, a]).astype("uint8"))
                frame.alpha_composite(lay, (0, round(rise * (1 - a))))
            rgb = frame.convert("RGB")
            if i == FPS * 3:
                poster = rgb
            enc.stdin.write(rgb.tobytes())
        enc.stdin.close()
        if enc.wait():
            raise SystemExit(f"ffmpeg failed for {slug}")
        poster.resize((360, 640), Image.LANCZOS).save(pages / f"st-{slug}-poster.jpg", quality=82, optimize=True,
                                                       progressive=True)
        print("video", slug, f"{dest.stat().st_size / 1e6:.1f} MB")
    (work / "videos.json").write_text(json.dumps(windows, indent=1))


# --- catalogue --------------------------------------------------------------------------------------------------

def _audio_credit(key: str) -> dict:
    where, file, author, lic, source = AUDIO[key]
    if where == "telugu" and not source:
        for path in (ROOT / "backend/app/seed/data/telugu_audio.json", ROOT / "backend/app/seed/data/commons.json"):
            for t in json.loads(path.read_text())["tracks"]:
                if t["audio_url"].endswith("/" + file):
                    source = t["source_url"]
    if where == "commons":
        source = "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(file.replace(" ", "_"))
    if where in ("seed", "synth"):
        source = "https://github.com/ChandraChaan/devalay"
    return {"author": author, "license": lic, "license_url": LICENSE_URLS.get(lic, ""), "source": source or ""}


def catalog(work: Path) -> None:
    art = json.loads((work / "art.json").read_text())
    colors = json.loads((work / "colors.json").read_text())
    rings = json.loads((work / "ringtones.json").read_text())
    previous = json.loads(CATALOG.read_text()) if CATALOG.exists() else {}

    def art_credit(file: str) -> dict:
        a = art[slug_for(file)]
        return {"author": a["author"], "license": a["license"], "license_url": a["license_url"],
                "source": a["source_url"]}

    def title(t):
        return {"en": t[0], "te": t[1], "hi": t[2]}

    def wall(slug, deity, t, tags, rank, style, credit):
        return {"id": slug, "deity": deity, "title": title(t), "premium": rank, "tags": tags, "style": style,
                "color": colors[slug], "thumb": f"{RELEASE}/wp-{slug}-thumb.jpg", "fhd": f"{RELEASE}/wp-{slug}-fhd.jpg",
                "qhd": f"{RELEASE}/wp-{slug}-qhd.jpg", "credit": credit}

    devalay = {"author": "Devalay", "license": "CC0", "license_url": LICENSE_URLS["CC0"],
               "source": "https://github.com/ChandraChaan/devalay", "changes": ""}
    walls = [
        *(wall(slug, deity, t, tags, rank, "modern", devalay) for slug, deity, t, tags, rank in modern_designs.DESIGNS),
        *(wall(slug, deity, t, tags, rank, "photo", {**art_credit(file), "changes": "cropped for phone screens"})
          for slug, deity, t, file, _focus, tags, rank in PHOTOS),
        *(wall(slug, deity, t, tags, rank, "classic",
               {**art_credit(file), "changes": "cropped and composed for phone screens"})
          for slug, deity, t, file, _crop, tags, rank in WALLPAPERS),
    ]
    tones = [{
        "id": slug, "deity": deity, "title": title(t), "premium": rank, "seconds": rings[slug]["seconds"],
        "audio": f"{RELEASE}/rt-{slug}.m4a", "notification": f"{RELEASE}/nt-{slug}.m4a",
        "credit": {**_audio_credit(key), "changes": "trimmed, loudness-normalised and faded"},
    } for slug, key, deity, t, _start, _secs, rank in RINGTONES]
    vids = [{
        "id": v["slug"], "lang": v["lang"], "deity": next(w[1] for w in [*WALLPAPERS, *PHOTOS] if w[0] == v["art"]),
        "title": title(v["title"]), "premium": v.get("premium"), "tags": v["tags"], "seconds": VIDEO_SECONDS,
        "text": v["headline"].replace("\n", " "),
        "video": f"{RELEASE}/st-{v['slug']}.mp4", "poster": f"{RELEASE}/st-{v['slug']}-poster.jpg",
        "credit": {"art": art_credit(next(w[3] for w in [*WALLPAPERS, *PHOTOS] if w[0] == v["art"])),
                   "audio": _audio_credit(v["audio"])},
    } for v in STATUS_VIDEOS]
    med_len = json.loads((work / "meditation.json").read_text()) if (work / "meditation.json").exists() else {}
    med = [{
        "id": slug, "deity": "general", "title": title(t), "premium": rank, "seconds": med_len.get(slug, 120),
        "audio": f"{RELEASE}/md-{slug}.m4a", "credit": {**_audio_credit(key), "changes": "loudness-normalised"},
    } for slug, key, t, rank in MEDITATION if slug in med_len]
    body = {"wallpapers": walls, "ringtones": tones, "status_videos": vids, "meditation": med}
    version = previous.get("version", 0)
    if {k: previous.get(k) for k in body} != body:
        version += 1
    CATALOG.write_text(json.dumps({"schema": 1, "version": version, **body}, indent=1, ensure_ascii=False) + "\n")
    print("catalogue", CATALOG, "version", version)


def licenses(work: Path) -> None:
    """Writes the sections' credits into CONTENT_LICENSES.md between its sections markers."""
    data = json.loads(CATALOG.read_text())
    md = ROOT / "CONTENT_LICENSES.md"
    start, end = "<!-- sections:start -->", "<!-- sections:end -->"

    def row(title: str, c: dict, note: str = "") -> str:
        src = f"[source]({c['source']})" if c.get("source") else ""
        return f"| {title}{note} | {c['author']} | {c['license']} | {src} |"

    lines = [start, "", "## Ringtones, wallpapers, WhatsApp status and meditation (`media-sections-v1`)", "",
             "Built by `backend/scripts/build_sections_media.py` (with `modern_designs.py` and `synth_tones.py`); "
             "the files are assets of the `media-sections-v1` GitHub release and the catalogue is "
             "`app/assets/data/sections.json`. Wallpapers are cropped and composed for phone screens; tones are "
             "trimmed, loudness-normalised and faded; status videos combine the art and audio credited below. "
             "Devalay's own designs, tones and soundscapes are CC0.", ""]
    for key, heading in (("wallpapers", "Wallpapers"), ("ringtones", "Ringtones"), ("meditation", "Meditation")):
        lines += [f"### {heading}", "", "| Item | Author | Licence | Source |", "|---|---|---|---|"]
        lines += [row(i["title"]["en"], i["credit"], " (Premium)" if i.get("premium") else "") for i in data.get(key, [])]
        lines.append("")
    lines += ["### WhatsApp status videos", "", "| Video | Art | Audio |", "|---|---|---|"]
    for v in data["status_videos"]:
        a, s = v["credit"]["art"], v["credit"]["audio"]
        lines.append(f"| {v['title']['en']}{' (Premium)' if v.get('premium') else ''} | {a['author']}, {a['license']} "
                     f"([source]({a['source']})) | {s['author']}, {s['license']} ([source]({s['source']})) |")
    lines += ["", end]
    text = md.read_text()
    block = "\n".join(lines)
    if start in text:
        text = text[:text.index(start)] + block + text[text.index(end) + len(end):]
    else:
        text = text.replace("## Films", block + "\n\n## Films", 1)
    md.write_text(text)
    print("licences", md)


if __name__ == "__main__":
    work_dir = Path(sys.argv[1]).resolve()
    steps = {"fetch": fetch, "wallpapers": wallpapers, "ringtones": ringtones, "meditation": meditation,
             "videos": videos, "catalog": catalog, "licenses": licenses}
    for step in sys.argv[2:]:
        steps[step](work_dir)
