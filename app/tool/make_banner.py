"""Render docs/store/banner.png (1280x640 README header and social preview). Run from the repo root."""

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1280, 640
FONTS = "app/assets/fonts/"

bg = Image.new("RGB", (W, H))
d = ImageDraw.Draw(bg)
top, bot = (255, 143, 0), (142, 36, 0)
for y in range(H):
    t = y / H
    d.line([(0, y), (W, y)], fill=tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
glow = Image.new("L", (W, H), 0)
ImageDraw.Draw(glow).ellipse((-200, -250, 700, 550), fill=90)
bg.paste((255, 224, 130), (0, 0), glow.filter(ImageFilter.GaussianBlur(120)))

icon = Image.open("docs/store/icon-512.png").convert("RGBA").resize((120, 120), Image.LANCZOS)
mask = Image.new("L", (120, 120), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 119, 119), 28, fill=255)
bg.paste(icon, (70, 60), mask)

d = ImageDraw.Draw(bg)
d.text((70, 170), "Devalay", font=ImageFont.truetype(FONTS + "Mukta-Bold.ttf", 84), fill="white")
d.text((70, 310), "देवालय", font=ImageFont.truetype(FONTS + "TiroDevanagariSanskrit-Regular.ttf", 84), fill=(255, 236, 179))
med = ImageFont.truetype(FONTS + "Mukta-Medium.ttf", 27)
for i, line in enumerate(["Aarti · Bhajans · Bhagavad Gita · Panchang", "Virtual Mandir · Japa · Rashifal · Wallpapers"]):
    d.text((72, 425 + i * 42), line, font=med, fill="white")
d.rounded_rectangle((70, 540, 470, 590), 25, fill="white")
d.text((95, 548), "Free · Open source · No ads", font=ImageFont.truetype(FONTS + "Mukta-SemiBold.ttf", 24),
       fill=(142, 36, 0))

for k, name in enumerate(["02-home", "03-mandir", "05-gita"]):
    shot = Image.open(f"docs/screenshots/{name}.jpg").convert("RGB").resize((216, 480), Image.LANCZOS)
    x, y = 610 + k * 205, (70 if k == 1 else 110)
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x + 10, y + 18, x + 242, y + 514), 30, fill=120)
    bg.paste((60, 10, 0), (0, 0), shadow.filter(ImageFilter.GaussianBlur(14)))
    frame = Image.new("RGBA", (232, 496), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, 231, 495), 30, fill=(20, 12, 8, 255))
    m = Image.new("L", (216, 480), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 215, 479), 24, fill=255)
    frame.paste(shot, (8, 8), m)
    bg.paste(frame, (x, y), frame)

bg.save("docs/store/banner.png", optimize=True)
