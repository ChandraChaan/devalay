"""Render the Devalay launcher icon (gold Om on a saffron gradient) for every density.

Usage: python app/tool/make_icons.py   (needs Pillow)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
FONT = ROOT / "assets/fonts/TiroDevanagariSanskrit-Regular.ttf"
DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def gradient(size: int) -> Image.Image:
    top, bottom = (255, 143, 0), (183, 28, 28)
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            px[x, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img


def om_layer(size: int, scale: float) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    font = ImageFont.truetype(str(FONT), int(size * scale))
    box = draw.textbbox((0, 0), "ॐ", font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    pos = ((size - w) / 2 - box[0], (size - h) / 2 - box[1])
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).text(pos, "ॐ", font=font, fill=(255, 236, 179, 200))
    layer.alpha_composite(glow.filter(ImageFilter.GaussianBlur(size * 0.03)))
    draw.text(pos, "ॐ", font=font, fill=(255, 213, 79, 255))
    return layer


def main() -> None:
    big = 1024
    base = gradient(big).convert("RGBA")
    base.alpha_composite(om_layer(big, 0.62))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big, big), radius=int(big * 0.22), fill=255)
    rounded = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    rounded.paste(base, mask=mask)
    for name, px in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        rounded.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher.png")
        # Adaptive icon foreground: 108dp canvas, art inside the 66dp safe zone.
        fg = om_layer(big, 0.40).resize((int(px * 108 / 48),) * 2, Image.LANCZOS)
        fg.save(folder / "ic_launcher_foreground.png")
    store = ROOT.parent / "docs" / "store"
    store.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").resize((512, 512), Image.LANCZOS).save(store / "icon-512.png")
    print("icons written")


if __name__ == "__main__":
    main()
