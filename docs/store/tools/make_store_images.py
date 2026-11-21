"""Builds Devalay's Play Store images from real app screenshots.

  python3 -m venv /tmp/v && /tmp/v/bin/pip install pillow
  /tmp/v/bin/python docs/store/tools/make_store_images.py

Reads docs/store/play/screenshots-v1.4/*.jpg (1080x2160 captures from the 1.4 app) and writes
  docs/store/play/<lang>/screenshots/NN-*.png   captioned 1080x1920 phone screenshots
  docs/store/play/<lang>/feature-graphic.png    1024x500 feature graphic
for en-IN, hi-IN and te-IN. Needs macOS (system Indic fonts) and Pillow built with raqm for shaping.
"""

from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[3]
SHOTS = ROOT / 'docs/store/play/screenshots-v1.4'
OUT = ROOT / 'docs/store/play'
APP_FONTS = ROOT / 'app/assets/fonts'
SYS = Path('/System/Library/Fonts')
SUP = SYS / 'Supplemental'

MAROON = (93, 26, 11)
DEEP = (62, 14, 5)
SAFFRON = (230, 81, 0)
AMBER = (255, 143, 0)
GOLD = (255, 200, 87)
CREAM = (255, 244, 230)

FONT = {
    'latin': APP_FONTS / 'Mukta-Bold.ttf',
    'latin-regular': APP_FONTS / 'Mukta-Medium.ttf',
    'deva': APP_FONTS / 'Mukta-Bold.ttf',
    'deva-regular': APP_FONTS / 'Mukta-Medium.ttf',
    # The app's Telugu fonts are slimmed to Telugu glyphs only; Kohinoor Telugu has digits and punctuation.
    'telu': (SYS / 'KohinoorTelugu.ttc', 3),
    'telu-regular': (SYS / 'KohinoorTelugu.ttc', 2),
    'taml': SUP / 'Tamil Sangam MN.ttc',
    'knda': SYS / 'NotoSansKannada.ttc',
    'mlym': SUP / 'Malayalam Sangam MN.ttc',
    'gujr': SUP / 'Gujarati Sangam MN.ttc',
    'beng': SUP / 'Bangla Sangam MN.ttc',
    'guru': SUP / 'Gurmukhi Sangam MN.ttc',
    'orya': SYS / 'NotoSansOriya.ttc',
}

LANGS = {
    'en-IN': ('latin', 'en'),
    'hi-IN': ('deva', 'hi'),
    'te-IN': ('telu', 'te'),
}

# (screenshot, {lang: (headline, subline)}) in store order: the first two carry the listing.
SCREENS = [
    ('02-calendar.jpg', {
        'en': ('Every festival and vrat, for your city', 'Ekadashi, Purnima, holidays and reminders'),
        'hi': ('हर त्योहार और व्रत, आपके शहर के अनुसार', 'एकादशी, पूर्णिमा, छुट्टियाँ और रिमाइंडर'),
        'te': ('ప్రతి పండుగ, వ్రతం మీ ఊరి సమయాలతో', 'ఏకాదశి, పౌర్ణమి, సెలవులు, రిమైండర్లు'),
    }),
    ('03-timings.jpg', {
        'en': ('Rahu Kaal and Choghadiya, right now', 'Know the good time before you begin'),
        'hi': ('राहु काल और चौघड़िया, अभी का', 'शुरू करने से पहले शुभ समय जानें'),
        'te': ('రాహు కాలం, చౌఘడియ ఇప్పుడే', 'పని మొదలుపెట్టే ముందు మంచి సమయం చూడండి'),
    }),
    ('04-muhurtham.jpg', {
        'en': ('Shubha Muhurtham, with the lagna', 'Marriage, griha pravesham, vehicle, naming'),
        'hi': ('शुभ मुहूर्त, लग्न के साथ', 'विवाह, गृह प्रवेश, वाहन, नामकरण'),
        'te': ('శుభ ముహూర్తం, లగ్నంతో సహా', 'వివాహం, గృహప్రవేశం, వాహనం, నామకరణం'),
    }),
    ('07-tamil-home.jpg', {
        'en': ('In your own language', '11 Indian languages, on every screen'),
        'hi': ('आपकी अपनी भाषा में', '11 भारतीय भाषाएँ, हर स्क्रीन पर'),
        'te': ('మీ సొంత భాషలో', '11 భారతీయ భాషలు, ప్రతి స్క్రీన్‌లో'),
    }),
    ('08-widget.jpg', {
        'en': ("Today's Panchang on your home screen", 'Tithi, nakshatra and Rahu Kaal at a glance'),
        'hi': ('आज का पंचांग होम स्क्रीन पर', 'तिथि, नक्षत्र, राहु काल एक नज़र में'),
        'te': ('నేటి పంచాంగం హోమ్ స్క్రీన్‌పై', 'తిథి, నక్షత్రం, రాహు కాలం ఒక్క చూపులో'),
    }),
    ('06-pooja-guide.jpg', {
        'en': ('Pooja, step by step', 'Vidhanam with a samagri checklist'),
        'hi': ('पूजा, एक-एक चरण', 'पूजा विधि और सामग्री की सूची'),
        'te': ('పూజ, అడుగడుగునా', 'పూజా విధానం, సామగ్రి జాబితాతో'),
    }),
    ('05-jatakam.jpg', {
        'en': ('Your Jatakam in a tap', 'South or North Indian chart, made on your phone'),
        'hi': ('आपकी जन्म कुंडली, एक टैप में', 'उत्तर या दक्षिण भारतीय शैली, आपके फ़ोन पर'),
        'te': ('మీ జాతకం, ఒక్క టచ్‌తో', 'దక్షిణ లేదా ఉత్తర భారత పద్ధతిలో'),
    }),
    ('01-home.jpg', {
        'en': ('Aartis, Gita and the deity of the day', 'Bhakti songs, Mandir, festival wishes and more'),
        'hi': ('आरती, गीता और आज के देवता', 'भक्ति गीत, मंदिर, शुभकामनाएँ और बहुत कुछ'),
        'te': ('హారతులు, గీత, నేటి దైవం', 'భక్తి పాటలు, మందిరం, శుభాకాంక్షలు ఇంకా ఎన్నో'),
    }),
]

FEATURE = {
    'en': ('Devalay', 'Panchang · Festival calendar · Muhurtham · Aartis'),
    'hi': ('देवालय', 'पंचांग · त्योहार कैलेंडर · मुहूर्त · आरती'),
    'te': ('దేవాలయం', 'పంచాంగం · పండుగల క్యాలెండర్ · ముహూర్తం · హారతులు'),
}

# The 11 app languages, each in its own script, for the feature graphic's language strip.
SCRIPT_STRIP = [
    ('English', 'latin'), ('हिन्दी', 'deva'), ('తెలుగు', 'telu'), ('தமிழ்', 'taml'), ('ಕನ್ನಡ', 'knda'),
    ('മലയാളം', 'mlym'), ('मराठी', 'deva'), ('ગુજરાતી', 'gujr'), ('বাংলা', 'beng'), ('ਪੰਜਾਬੀ', 'guru'),
    ('ଓଡ଼ିଆ', 'orya'),
]


def font(key, size):
    path, index = FONT[key] if isinstance(FONT[key], tuple) else (FONT[key], 0)
    return ImageFont.truetype(str(path), size, index=index, layout_engine=ImageFont.Layout.RAQM)


def gradient(w, h, stops):
    """Vertical-diagonal gradient through [stops]."""
    return _gradient(w, h, tuple(stops)).copy()


@lru_cache
def _gradient(w, h, stops):
    img = Image.new('RGB', (w, h))
    px = img.load()
    n = len(stops) - 1
    for y in range(h):
        for x in range(w):
            t = min(1.0, max(0.0, (y / h) * 0.8 + (x / w) * 0.2))
            i = min(n - 1, int(t * n))
            f = t * n - i
            a, b = stops[i], stops[i + 1]
            px[x, y] = tuple(int(a[k] + (b[k] - a[k]) * f) for k in range(3))
    return img


def wrap(draw, text, fnt, width):
    """Greedy wrap, then rebalanced so two-line captions split near the middle."""
    lines = _greedy(draw, text, fnt, width)
    if len(lines) == 2:
        words = text.split(' ')
        best = min(
            (max(draw.textlength(' '.join(words[:i]), font=fnt), draw.textlength(' '.join(words[i:]), font=fnt)), i)
            for i in range(1, len(words))
        )
        if best[0] <= width:
            lines = [' '.join(words[: best[1]]), ' '.join(words[best[1] :])]
    return lines


def _greedy(draw, text, fnt, width):
    words, lines, line = text.split(' '), [], ''
    for w in words:
        trial = f'{line} {w}'.strip()
        if draw.textlength(trial, font=fnt) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = w
    lines.append(line)
    return lines


def rounded(img, radius):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius, fill=255)
    out = Image.new('RGBA', img.size)
    out.paste(img, (0, 0), mask)
    return out


def phone(shot, width):
    """A screenshot inside a dark rounded bezel, with a soft shadow, as RGBA."""
    bezel = 16
    h = int(shot.height * width / shot.width)
    screen = rounded(shot.convert('RGB').resize((width, h), Image.LANCZOS), 38)
    body = Image.new('RGBA', (width + 2 * bezel, h + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, body.width - 1, body.height - 1], 52, fill=(24, 16, 12, 255))
    body.alpha_composite(screen, (bezel, bezel))
    pad = 40
    shadow = Image.new('RGBA', (body.width + 2 * pad, body.height + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [pad, pad + 14, pad + body.width, pad + body.height + 14], 52, fill=(0, 0, 0, 120)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    shadow.alpha_composite(body, (pad, pad))
    return shadow


def mandala(img, cx, cy, r, alpha=26):
    """Faint concentric petals, echoing the app's mandala header."""
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    import math

    for ring in range(4):
        rr = r * (0.35 + ring * 0.22)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=(255, 220, 160, alpha), width=3)
        petals = 12 + ring * 6
        for p in range(petals):
            a = 2 * math.pi * p / petals
            px, py = cx + rr * math.cos(a), cy + rr * math.sin(a)
            s = 10 + ring * 4
            d.ellipse([px - s, py - s, px + s, py + s], outline=(255, 220, 160, alpha), width=2)
    img.alpha_composite(layer)


def screenshot(lang, script, name, caption, index):
    W, H = 1080, 1920
    img = gradient(W, H, [DEEP, MAROON, SAFFRON, AMBER]).convert('RGBA')
    mandala(img, W - 80, 150, 360)
    d = ImageDraw.Draw(img)
    head, sub = caption
    hf = font(script, 70 if script == 'latin' else 64)
    sf = font(f'{script}-regular', 40 if script == 'latin' else 36)
    y = 90
    for line in wrap(d, head, hf, 960):
        d.text((W / 2, y), line, font=hf, fill=CREAM, anchor='ma')
        y += int(hf.size * 1.28)
    y += 8
    for line in wrap(d, sub, sf, 960):
        d.text((W / 2, y), line, font=sf, fill=GOLD, anchor='ma')
        y += int(sf.size * 1.4)
    ph = phone(Image.open(SHOTS / name), 800)
    top = max(y + 30, 430)
    img.alpha_composite(ph, ((W - ph.width) // 2, top - 40))
    out = OUT / lang / 'screenshots'
    out.mkdir(parents=True, exist_ok=True)
    img.convert('RGB').save(out / f'{index:02d}-{Path(name).stem.split("-", 1)[1]}.png', optimize=True)


def feature_graphic(lang, script, key):
    W, H = 1024, 500
    img = gradient(W, H, [DEEP, MAROON, SAFFRON, AMBER]).convert('RGBA')
    mandala(img, 760, 250, 330, alpha=30)
    # Two real screens on the right.
    for name, x, y, w in [('03-timings.jpg', 600, 70, 230), ('02-calendar.jpg', 780, 40, 230)]:
        ph = phone(Image.open(SHOTS / name), w)
        img.alpha_composite(ph, (x - 40, y - 40))
    # Fade the left side so the words read cleanly over the art.
    shade = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for x in range(620):
        sd.line([(x, 0), (x, H)], fill=(62, 14, 5, int(150 * (1 - x / 620))))
    img.alpha_composite(shade)
    icon = Image.open(OUT / 'icon-512.png').convert('RGB').resize((104, 104), Image.LANCZOS)
    img.alpha_composite(rounded(icon, 24), (56, 60))
    d = ImageDraw.Draw(img)
    name, tag = FEATURE[key]
    d.text((180, 112), name, font=font(script, 88 if script == 'latin' else 74), fill=CREAM, anchor='lm')
    tf = font(f'{script}-regular', 31 if script == 'latin' else 27)
    y = 232
    # Wrap between items, so a line never starts with the separator.
    lines, line = [], ''
    for part in tag.split(' · '):
        trial = f'{line} · {part}' if line else part
        if line and d.textlength(trial, font=tf) > 540:
            lines.append(line + ' ·')
            line = part
        else:
            line = trial
    lines.append(line)
    for line in lines:
        d.text((58, y), line, font=tf, fill=GOLD, anchor='ls')
        y += 44
    # Language strip: each language's name in its own script, all at a regular weight.
    regular = {'latin': 'latin-regular', 'deva': 'deva-regular', 'telu': 'telu-regular'}
    x, y = 58, max(y + 44, 360)
    for word, sc in SCRIPT_STRIP:
        f = font(regular.get(sc, sc), 25)
        w = d.textlength(word, font=f)
        if x + w > 590:
            x, y = 58, y + 48
        d.text((x, y), word, font=f, fill=CREAM, anchor='ls')
        x += w + 20
    img.convert('RGB').save(OUT / lang / 'feature-graphic.png', optimize=True)


def main():
    for lang, (script, key) in LANGS.items():
        for i, (name, captions) in enumerate(SCREENS, start=1):
            screenshot(lang, script, name, captions[key], i)
        feature_graphic(lang, script, key)
        print('wrote', lang)


if __name__ == '__main__':
    main()
