"""Devalay's own modern devotional wallpapers, drawn as SVG and rendered at 1440x3200 with headless Chrome.

Everything here is original artwork (CC0): gradients, symbols and typography drawn in code, with OFL fonts
from app/assets/fonts. build_sections_media.py calls render_all() in its `wallpapers` step.
"""

from __future__ import annotations

import math
import random
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "app" / "assets" / "fonts"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 720, 1600  # CSS pixels; rendered at 2x = 1440x3200

# slug, deity, (en, te, hi), tags, premium rank
DESIGNS = [
    ("om-glow", "general", ("Glowing Om", "వెలుగుల ఓంకారం", "दिव्य ॐ"), ["morning", "monday"], 1),
    ("peacock-flute", "krishna", ("Peacock Feather and Flute", "నెమలి పింఛం, మురళి", "मोरपंख और बाँसुरी"),
     ["krishnashtami", "wednesday"], 2),
    ("trishul-moon", "shiva", ("Trishul and the Moon", "త్రిశూలం, చంద్రుడు", "त्रिशूल और चंद्रमा"),
     ["monday", "maha-shivaratri", "karthika"], 4),
    ("tirumala-namam", "venkateswara", ("Govinda Namam", "గోవింద నామం", "गोविंद नामम्"),
     ["saturday", "vaikuntha-ekadashi"], 5),
    ("butter-pot", "krishna", ("Little Krishna's Butter Pot", "చిన్ని కృష్ణుని వెన్న కుండ", "माखन मटकी"),
     ["krishnashtami"], None),
    ("lotus-mandala", "lakshmi", ("Lotus Mandala", "పద్మ మండలం", "कमल मंडल"), ["friday", "diwali"], None),
    ("sri-yantra", "lakshmi", ("Sri Yantra", "శ్రీ చక్రం", "श्री यंत्र"), ["friday"], None),
    ("diya-bokeh", "general", ("Diya Glow", "దీప కాంతి", "दीप ज्योति"), ["karthika", "diwali", "night"], None),
    ("jai-shri-ram", "rama", ("Jai Shri Ram", "జై శ్రీరామ్", "जय श्री राम"), ["rama-navami", "tuesday"], None),
    ("radhe-radhe", "radha-krishna", ("Radhe Radhe", "రాధే రాధే", "राधे राधे"), ["krishnashtami"], None),
    ("toran-kalash", "ganesha", ("Toran and Kalash", "తోరణం, కలశం", "तोरण और कलश"),
     ["vinayaka-chavithi", "sankranti", "diwali"], None),
    ("hanuman-gada", "hanuman", ("Hanuman's Gada", "హనుమంతుని గద", "हनुमान की गदा"),
     ["tuesday", "saturday", "hanuman-jayanti"], None),
    ("shankh-chakra", "vishnu", ("Sudarshana Chakra", "సుదర్శన చక్రం", "सुदर्शन चक्र"),
     ["thursday", "ekadashi"], None),
]


def _fonts() -> str:
    faces = {"Ramabhadra": "Ramabhadra-Regular.ttf", "Suranna": "Suranna-Regular.ttf",
             "Tiro": "TiroDevanagariSanskrit-Regular.ttf", "Mukta": "Mukta-Bold.ttf"}
    return "".join(f"@font-face{{font-family:{n};src:url('file://{FONTS / f}')}}" for n, f in faces.items())


def _stars(n: int, seed: int, top: float = 0, bottom: float = H * 0.7, color: str = "#fff") -> str:
    rnd = random.Random(seed)
    out = []
    for _ in range(n):
        x, y, r = rnd.uniform(0, W), rnd.uniform(top, bottom), rnd.uniform(0.4, 1.8)
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="{color}" opacity="{rnd.uniform(.25, .95):.2f}"/>')
    return "".join(out)


def _bokeh(n: int, seed: int, colors: list[str], rmin=10, rmax=60, ymin=0, ymax=H) -> str:
    rnd = random.Random(seed)
    return "".join(
        f'<circle cx="{rnd.uniform(0, W):.0f}" cy="{rnd.uniform(ymin, ymax):.0f}" r="{rnd.uniform(rmin, rmax):.0f}" '
        f'fill="{rnd.choice(colors)}" opacity="{rnd.uniform(.08, .35):.2f}" filter="url(#soft)"/>'
        for _ in range(n))


DEFS = """
<defs>
 <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14" result="b"/>
  <feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="glowSm" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="5" result="b"/>
  <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>
 <filter id="blur30" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="30"/></filter>
 <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#FFF4C2"/><stop offset=".45" stop-color="#FFC83D"/>
  <stop offset=".75" stop-color="#E09A16"/><stop offset="1" stop-color="#FFE38A"/></linearGradient>
 <linearGradient id="goldH" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#B8860B"/><stop offset=".5" stop-color="#FFE38A"/><stop offset="1" stop-color="#B8860B"/></linearGradient>
</defs>"""


def _text(x, y, text, size, font="Ramabhadra", fill="url(#gold)", extra="") -> str:
    return (f'<text x="{x}" y="{y}" text-anchor="middle" font-family="{font}" font-size="{size}" fill="{fill}" '
            f'{extra}>{text}</text>')


def om_glow() -> str:
    rings = "".join(f'<circle cx="360" cy="760" r="{r}" fill="none" stroke="#FFC83D" stroke-opacity="{o}" '
                    f'stroke-width="1.2"/>' for r, o in [(250, .35), (300, .22), (360, .14), (430, .08)])
    rays = "".join(
        f'<line x1="{360 + 270 * math.cos(a):.1f}" y1="{760 + 270 * math.sin(a):.1f}" '
        f'x2="{360 + 330 * math.cos(a):.1f}" y2="{760 + 330 * math.sin(a):.1f}" stroke="#FFD36B" '
        f'stroke-opacity=".35" stroke-width="1.5"/>' for a in [i * math.pi / 36 for i in range(72)])
    return f"""
<radialGradient id="bg" cx=".5" cy=".47" r=".75"><stop offset="0" stop-color="#3B1C6B"/>
 <stop offset=".45" stop-color="#1A0B36"/><stop offset="1" stop-color="#05020D"/></radialGradient>
<rect width="720" height="1600" fill="url(#bg)"/>{_stars(160, 1, 0, H)}
<circle cx="360" cy="760" r="230" fill="#FF9F1C" opacity=".18" filter="url(#blur30)"/>
{rings}{rays}
<text x="360" y="900" text-anchor="middle" font-family="Tiro" font-size="380" fill="url(#gold)" filter="url(#glow)">ॐ</text>
{_bokeh(26, 2, ['#FFC83D', '#FF8A3D', '#B388FF'], 4, 18)}"""


def peacock_flute() -> str:
    rnd = random.Random(3)
    # The feather: a gently curving shaft, barbs on both sides, the eye at the top.
    def shaft(t):  # t 0 (bottom) .. 1 (top)
        return 300 + 120 * t + 40 * math.sin(t * 2.2), 1450 - 1150 * t
    barbs = []
    for i in range(360):
        t = i / 359
        x, y = shaft(t)
        length = 60 + 150 * math.sin(min(1, t * 1.15) * math.pi * .55) * (1 - .35 * (1 - t))
        for side in (-1, 1):
            ang = -math.pi / 2 + side * (1.05 - .25 * t) + rnd.uniform(-.05, .05)
            x2, y2 = x + length * math.cos(ang), y + length * math.sin(ang)
            cx, cy = x + length * .5 * math.cos(ang) + side * 10, y + length * .5 * math.sin(ang) - 12
            col = "#9BE15D" if t > .7 else ("#3FB59B" if t > .4 else "#2E8B7A")
            barbs.append(f'<path d="M{x:.1f},{y:.1f} Q{cx:.1f},{cy:.1f} {x2:.1f},{y2:.1f}" stroke="{col}" '
                         f'stroke-opacity="{rnd.uniform(.55, .9):.2f}" stroke-width="1.5" fill="none"/>')
    ex, ey = shaft(.88)
    eye = f"""
<g transform="translate({ex:.1f},{ey:.1f}) rotate(14)">
 <ellipse rx="118" ry="150" fill="#8BC34A" opacity=".55" filter="url(#soft)"/>
 <ellipse rx="100" ry="130" fill="url(#eyeGold)"/>
 <ellipse rx="78" ry="104" fill="#7A4B1E"/>
 <ellipse rx="70" ry="94" fill="url(#eyeTeal)"/>
 <ellipse cy="10" rx="46" ry="62" fill="#1E3FA8"/>
 <ellipse cy="16" rx="30" ry="40" fill="#0B1240"/>
 <ellipse cx="-12" cy="-6" rx="10" ry="14" fill="#fff" opacity=".18"/>
</g>"""
    flute = """
<g transform="translate(360,1060) rotate(-24)">
 <rect x="-330" y="-20" width="660" height="40" rx="20" fill="url(#bamboo)"/>
 <rect x="-330" y="-20" width="660" height="12" rx="6" fill="#fff" opacity=".18"/>
 <rect x="-250" y="-21" width="14" height="42" fill="#8B5A2B"/><rect x="200" y="-21" width="14" height="42" fill="#8B5A2B"/>
 <rect x="-180" y="-21" width="10" height="42" fill="url(#goldH)"/><rect x="150" y="-21" width="10" height="42" fill="url(#goldH)"/>
 """ + "".join(f'<ellipse cx="{x}" cy="0" rx="8" ry="6" fill="#3E2412"/>' for x in (-110, -60, -10, 40, 90, 260)) + """
 <path d="M-200,20 C-205,80 -190,140 -215,200" stroke="#D32F2F" stroke-width="5" fill="none"/>
 <circle cx="-203" cy="60" r="8" fill="url(#gold)"/><circle cx="-207" cy="115" r="7" fill="url(#gold)"/>
 <path d="M-226,196 l12,60 l12,-60 z" fill="#D32F2F"/>
</g>"""
    sx0, sy0 = shaft(0)
    path = "M" + " L".join(f"{shaft(i / 40)[0]:.1f},{shaft(i / 40)[1]:.1f}" for i in range(41))
    return f"""
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#03172B"/>
 <stop offset=".55" stop-color="#062C3D"/><stop offset="1" stop-color="#020B12"/></linearGradient>
<radialGradient id="eyeGold"><stop offset=".7" stop-color="#C9A227"/><stop offset="1" stop-color="#6E8B1E"/></radialGradient>
<radialGradient id="eyeTeal"><stop offset="0" stop-color="#26C6DA"/><stop offset="1" stop-color="#00796B"/></radialGradient>
<linearGradient id="bamboo" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E8C26B"/>
 <stop offset=".5" stop-color="#C8973F"/><stop offset="1" stop-color="#8B5A2B"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>
<circle cx="430" cy="420" r="260" fill="#26C6DA" opacity=".18" filter="url(#blur30)"/>
{_bokeh(30, 4, ['#4DD0E1', '#FFD54F', '#81C784'], 4, 22)}
{''.join(barbs)}
<path d="{path}" stroke="#C5E1A5" stroke-width="3" fill="none" opacity=".85"/>
{eye}{flute}
{_text(360, 1500, 'శ్రీ కృష్ణం వందే జగద్గురుమ్', 34, 'Suranna', '#E0F7FA', 'opacity=".85"')}"""


def trishul_moon() -> str:
    mountains = ("M0,1260 L120,1120 L190,1180 L300,1010 L360,1060 L430,960 L520,1090 L600,1030 L720,1150 L720,1600 "
                 "L0,1600 Z")
    snow = "M300,1010 L330,1040 L310,1045 L345,1062 L360,1060 Z M430,960 L460,1000 L440,1002 L480,1030 L520,1090 Z"
    trishul = """
<g transform="translate(360,0)" filter="url(#glowSm)">
 <rect x="-9" y="430" width="18" height="760" rx="6" fill="url(#steel)"/>
 <path d="M0,250 C14,300 22,360 14,430 L-14,430 C-22,360 -14,300 0,250 Z" fill="url(#steel)"/>
 <path d="M-14,470 C-80,470 -120,420 -122,330 C-110,370 -86,404 -40,420 L-14,420 Z" fill="url(#steel)"/>
 <path d="M14,470 C80,470 120,420 122,330 C110,370 86,404 40,420 L14,420 Z" fill="url(#steel)"/>
 <rect x="-34" y="465" width="68" height="16" rx="8" fill="url(#gold)"/>
 <g transform="translate(0,620)">
  <path d="M-40,-46 L40,-46 L6,0 L40,46 L-40,46 L-6,0 Z" fill="#7B3F00" stroke="url(#gold)" stroke-width="3"/>
  <path d="M-40,-46 L40,-46" stroke="url(#gold)" stroke-width="6"/><path d="M-40,46 L40,46" stroke="url(#gold)" stroke-width="6"/>
  <path d="M0,-2 C40,10 60,60 30,110 C20,130 40,150 60,160" stroke="#E53935" stroke-width="5" fill="none"/>
 </g>
</g>"""
    return f"""
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#090418"/>
 <stop offset=".6" stop-color="#1B1145"/><stop offset="1" stop-color="#2A1A5E"/></linearGradient>
<linearGradient id="steel" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8E9BB5"/>
 <stop offset=".5" stop-color="#F5F7FF"/><stop offset="1" stop-color="#7C88A3"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>{_stars(220, 5)}
<circle cx="360" cy="380" r="190" fill="#B3C7FF" opacity=".35" filter="url(#blur30)"/>
<circle cx="360" cy="380" r="150" fill="#F4F1FF"/>
<circle cx="410" cy="350" r="140" fill="#130B33"/>
{trishul}
<path d="{mountains}" fill="#0C0820"/><path d="{snow}" fill="#C5CAE9" opacity=".55"/>
{_text(360, 1420, 'ఓం నమః శివాయ', 60, 'Ramabhadra', 'url(#gold)', 'filter="url(#glowSm)"')}
{_text(360, 1480, 'हर हर महादेव', 34, 'Tiro', '#D1C4E9', 'opacity=".85"')}"""


def tirumala_namam() -> str:
    hills = ("M0,1180 C60,1140 100,1150 140,1110 C190,1060 230,1090 270,1050 C320,1000 360,1030 400,990 "
             "C450,950 500,1000 540,980 C600,950 650,1010 720,990 L720,1600 L0,1600 Z")
    gopuram = "".join(
        f'<rect x="{330 + i * 6}" y="{1010 - i * 26}" width="{60 - i * 12}" height="26" fill="#3A1A00" opacity=".9"/>'
        for i in range(5))
    return f"""
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0A1A4A"/>
 <stop offset=".55" stop-color="#3A2C7A"/><stop offset=".8" stop-color="#E0663A"/><stop offset="1" stop-color="#FFB74D"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>{_stars(120, 6, 0, 700)}
<circle cx="360" cy="600" r="250" fill="#FFE082" opacity=".22" filter="url(#blur30)"/>
<g transform="translate(360,600)" filter="url(#glowSm)">
 <path d="M-120,-260 C-130,-60 -110,90 -40,170 L-12,170 C-70,90 -86,-40 -78,-260 Z" fill="#FFFFFF"/>
 <path d="M120,-260 C130,-60 110,90 40,170 L12,170 C70,90 86,-40 78,-260 Z" fill="#FFFFFF"/>
 <path d="M-40,170 C-20,196 20,196 40,170 Z" fill="#FFFFFF"/>
 <path d="M-14,-250 C-18,-80 -14,80 0,180 C14,80 18,-80 14,-250 Z" fill="#E53935"/>
 <path d="M-8,-240 C-10,-80 -8,60 0,160" stroke="#FFCDD2" stroke-width="3" fill="none" opacity=".6"/>
</g>
<path d="{hills}" fill="#1A0F2E"/>{gopuram}
{_text(360, 1300, 'ఓం నమో వేంకటేశాయ', 62, 'Ramabhadra', 'url(#gold)', 'filter="url(#glowSm)"')}
{_text(360, 1370, 'గోవిందా గోవిందా', 40, 'Suranna', '#FFE0B2')}"""


def butter_pot() -> str:
    clouds = "".join(
        f'<g opacity=".9"><ellipse cx="{x}" cy="{y}" rx="70" ry="28" fill="#fff"/><ellipse cx="{x - 40}" cy="{y + 6}" '
        f'rx="44" ry="22" fill="#fff"/><ellipse cx="{x + 42}" cy="{y + 8}" rx="40" ry="20" fill="#fff"/></g>'
        for x, y in [(150, 260), (560, 180), (520, 520), (130, 640)])
    feather = """
<g transform="translate(430,790) rotate(22) scale(1.9)">
 <path d="M0,0 C4,-120 6,-220 0,-330" stroke="#5D8C3E" stroke-width="3" fill="none"/>
 <ellipse cy="-300" rx="44" ry="66" fill="#8BC34A"/><ellipse cy="-300" rx="34" ry="52" fill="#C9A227"/>
 <ellipse cy="-296" rx="26" ry="40" fill="#26A69A"/><ellipse cy="-292" rx="15" ry="24" fill="#1E3FA8"/>
 <ellipse cy="-290" rx="8" ry="13" fill="#0B1240"/>
</g>"""
    return f"""
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#B3E5FC"/>
 <stop offset=".7" stop-color="#E1F5FE"/><stop offset="1" stop-color="#FFF8E1"/></linearGradient>
<radialGradient id="pot" cx=".38" cy=".35" r=".8"><stop offset="0" stop-color="#E0884A"/>
 <stop offset=".6" stop-color="#B5562A"/><stop offset="1" stop-color="#7A3315"/></radialGradient>
<rect width="720" height="1600" fill="url(#bg)"/>{clouds}
{feather}
<ellipse cx="360" cy="1225" rx="250" ry="34" fill="#000" opacity=".12"/>
<path d="M200,760 C110,880 110,1140 250,1210 C320,1240 400,1240 470,1210 C610,1140 610,880 520,760 Z" fill="url(#pot)"/>
<path d="M230,800 C260,820 460,820 490,800" stroke="#FFD54F" stroke-width="10" fill="none"/>
<path d="M190,900 C290,935 430,935 530,900" stroke="#F9A825" stroke-width="7" fill="none" stroke-dasharray="2 14" stroke-linecap="round"/>
<ellipse cx="360" cy="760" rx="170" ry="34" fill="#8D3F17"/>
<path d="M200,760 C220,700 290,690 330,700 C360,660 430,680 450,705 C500,690 540,720 520,765 C470,790 250,790 200,760 Z" fill="#FFFDF5"/>
<path d="M250,770 C246,820 262,846 250,880 C276,846 268,812 282,776 Z" fill="#FFFDF5"/>
<path d="M440,772 C452,830 438,860 455,900 C466,860 470,820 462,776 Z" fill="#FFFDF5"/>
<ellipse cx="300" cy="900" rx="40" ry="70" fill="#fff" opacity=".18"/>
{_text(360, 1380, 'చిన్ని కృష్ణా', 66, 'Ramabhadra', '#1565C0')}
{_text(360, 1450, 'माखन चोर नंदकिशोर', 36, 'Tiro', '#5D4037')}"""


def lotus_mandala() -> str:
    def ring(n, r, length, width, color, rot=0):
        return "".join(
            f'<path transform="rotate({i * 360 / n + rot})" d="M0,{-r} C{width},{-r - length * .4} {width * .6},'
            f'{-r - length * .9} 0,{-r - length} C{-width * .6},{-r - length * .9} {-width},{-r - length * .4} 0,{-r} Z" '
            f'fill="{color}" stroke="#FFD54F" stroke-width="1.2" stroke-opacity=".8"/>' for i in range(n))
    dots = "".join(f'<circle transform="rotate({i * 7.5})" cy="-318" r="3" fill="#FFD54F"/>' for i in range(48))
    return f"""
<radialGradient id="bg" cx=".5" cy=".45" r=".8"><stop offset="0" stop-color="#7B1E3A"/>
 <stop offset=".6" stop-color="#3D0A1E"/><stop offset="1" stop-color="#16030B"/></radialGradient>
<radialGradient id="p1"><stop offset="0" stop-color="#FFC1D6"/><stop offset="1" stop-color="#E91E63"/></radialGradient>
<rect width="720" height="1600" fill="url(#bg)"/>
<g transform="translate(360,760)">
 <circle r="330" fill="#E91E63" opacity=".18" filter="url(#blur30)"/>
 {ring(24, 210, 95, 26, '#AD1457')}{ring(16, 140, 100, 36, 'url(#p1)', 11.25)}{ring(8, 70, 100, 44, '#F8BBD0', 22.5)}
 <circle r="70" fill="url(#gold)"/><circle r="52" fill="#7B1E3A"/>
 <text y="22" text-anchor="middle" font-family="Tiro" font-size="64" fill="url(#gold)">श्रीं</text>
 <circle r="318" fill="none" stroke="#FFD54F" stroke-opacity=".5"/>{dots}
</g>
{_bokeh(20, 7, ['#FFD54F', '#F48FB1'], 4, 16)}
{_text(360, 1300, 'శ్రీ మహాలక్ష్మీ', 58, 'Ramabhadra', 'url(#gold)', 'filter="url(#glowSm)"')}"""


def sri_yantra() -> str:
    # A stylised Sri Yantra: four up and five down triangles, two lotus rings and the bhupura gates.
    tris = []
    ups = [(-150, 120, 150), (-110, 60, 110), (-75, 10, 80), (-40, -20, 50)]
    downs = [(150, -140, 150), (115, -80, 118), (82, -30, 88), (50, 10, 58), (25, 40, 34)]
    for apex, base, half in ups:
        tris.append(f'<path d="M0,{apex} L{half},{base} L{-half},{base} Z"/>')
    for apex, base, half in downs:
        tris.append(f'<path d="M0,{apex} L{half},{base} L{-half},{base} Z"/>')
    petals = "".join(
        f'<path transform="rotate({i * 22.5})" d="M0,-180 C16,-196 14,-214 0,-226 C-14,-214 -16,-196 0,-180 Z" '
        f'fill="none" stroke="url(#gold)" stroke-width="2"/>' for i in range(16))
    petals2 = "".join(
        f'<path transform="rotate({i * 45})" d="M0,-158 C22,-170 22,-200 0,-178 C-22,-200 -22,-170 0,-158 Z" '
        f'fill="none" stroke="url(#gold)" stroke-width="2"/>' for i in range(8))
    gate = ("M-270,-270 L-60,-270 L-60,-300 L60,-300 L60,-270 L270,-270 L270,-60 L300,-60 L300,60 L270,60 L270,270 "
            "L60,270 L60,300 L-60,300 L-60,270 L-270,270 L-270,60 L-300,60 L-300,-60 L-270,-60 Z")
    return f"""
<radialGradient id="bg" cx=".5" cy=".46" r=".8"><stop offset="0" stop-color="#2A1600"/>
 <stop offset="1" stop-color="#050300"/></radialGradient>
<rect width="720" height="1600" fill="url(#bg)"/>
<g transform="translate(360,760)" filter="url(#glowSm)">
 <circle r="330" fill="#FFB300" opacity=".12" filter="url(#blur30)"/>
 <path d="{gate}" fill="none" stroke="url(#gold)" stroke-width="3"/>
 <circle r="240" fill="none" stroke="url(#gold)" stroke-width="2"/><circle r="232" fill="none" stroke="url(#gold)"/>
 {petals}{petals2}<circle r="156" fill="none" stroke="url(#gold)" stroke-width="2"/>
 <g fill="none" stroke="url(#gold)" stroke-width="2.4">{''.join(tris)}</g>
 <circle r="5" fill="#FFE38A"/>
</g>
{_text(360, 1260, 'శ్రీ చక్రం', 56, 'Ramabhadra', 'url(#gold)')}
{_text(360, 1320, 'ॐ श्रीं ह्रीं श्रीं', 34, 'Tiro', '#FFE0B2', 'opacity=".85"')}"""


def diya_bokeh() -> str:
    def diya(x, y, s):
        return f"""
<g transform="translate({x},{y}) scale({s})">
 <ellipse cy="-150" rx="90" ry="150" fill="#FF9800" opacity=".35" filter="url(#blur30)"/>
 <path d="M0,-210 C30,-150 34,-100 0,-62 C-34,-100 -30,-150 0,-210 Z" fill="url(#flame)" filter="url(#glowSm)"/>
 <path d="M0,-150 C12,-120 12,-96 0,-80 C-12,-96 -12,-120 0,-150 Z" fill="#FFFDE7"/>
 <path d="M-150,-60 C-120,40 120,40 150,-60 C90,-40 -90,-40 -150,-60 Z" fill="url(#clay)"/>
 <path d="M-150,-60 C-90,-80 90,-80 150,-60 C90,-40 -90,-40 -150,-60 Z" fill="#5D2E0E"/>
 <path d="M-100,-6 C-50,14 50,14 100,-6" stroke="#FFD54F" stroke-width="4" fill="none" stroke-dasharray="3 12" stroke-linecap="round"/>
</g>"""
    return f"""
<radialGradient id="bg" cx=".5" cy=".62" r=".85"><stop offset="0" stop-color="#4A1C05"/>
 <stop offset=".6" stop-color="#1C0A02"/><stop offset="1" stop-color="#070301"/></radialGradient>
<radialGradient id="flame" cx=".5" cy=".7" r=".7"><stop offset="0" stop-color="#FFF59D"/>
 <stop offset=".5" stop-color="#FFB300"/><stop offset="1" stop-color="#E65100"/></radialGradient>
<linearGradient id="clay" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C1652B"/>
 <stop offset="1" stop-color="#6D2A0A"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>
{_bokeh(40, 8, ['#FFB300', '#FF7043', '#FFE082'], 10, 46, 0, 900)}
{diya(360, 1050, 1.25)}{diya(130, 1230, .55)}{diya(590, 1230, .55)}
{_text(360, 1420, 'దీపం జ్యోతి పరబ్రహ్మ', 46, 'Suranna', 'url(#gold)')}"""


def jai_shri_ram() -> str:
    return f"""
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FF6F00"/>
 <stop offset=".45" stop-color="#E65100"/><stop offset="1" stop-color="#4E1400"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>
<circle cx="360" cy="560" r="230" fill="#FFE082" opacity=".9"/>
<circle cx="360" cy="560" r="300" fill="#FFF3E0" opacity=".25" filter="url(#blur30)"/>
""" + "".join(f'<line x1="360" y1="560" x2="{360 + 700 * math.cos(a):.0f}" y2="{560 + 700 * math.sin(a):.0f}" '
              f'stroke="#FFE0B2" stroke-opacity=".12" stroke-width="22"/>'
              for a in [i * math.pi / 12 for i in range(24)]) + f"""
<g transform="translate(360,620)" fill="none" stroke="#3E1200" stroke-linecap="round">
 <path d="M-40,-330 C160,-200 160,200 -40,330" stroke-width="16"/>
 <line x1="-40" y1="-330" x2="-40" y2="330" stroke-width="3"/>
 <line x1="-300" y1="0" x2="230" y2="0" stroke-width="8"/>
 <path d="M230,0 l-40,-22 l8,22 l-8,22 z" fill="#3E1200"/>
 <path d="M-300,0 l-30,-24 M-300,0 l-30,24 M-280,0 l-30,-24 M-280,0 l-30,24" stroke-width="5"/>
</g>
<g transform="translate(520,140)"><line x1="0" y1="0" x2="0" y2="300" stroke="#3E1200" stroke-width="6"/>
 <path d="M0,0 L120,40 L0,110 Z" fill="#FF8F00" stroke="#3E1200" stroke-width="3"/></g>
{_text(360, 1180, 'జై శ్రీరామ్', 96, 'Ramabhadra', '#FFF8E1', 'filter="url(#glowSm)"')}
{_text(360, 1270, 'जय श्री राम', 54, 'Tiro', '#FFE0B2')}"""


def radhe_radhe() -> str:
    rnd = random.Random(9)
    flowers = []
    for _ in range(22):
        x, y, s = rnd.uniform(0, W), rnd.uniform(0, H), rnd.uniform(.5, 1.3)
        col = rnd.choice(["#F48FB1", "#CE93D8", "#FFFFFF", "#F8BBD0"])
        petals = "".join(f'<ellipse transform="rotate({i * 72})" cy="-16" rx="10" ry="16" fill="{col}"/>' for i in range(5))
        flowers.append(f'<g transform="translate({x:.0f},{y:.0f}) scale({s:.2f}) rotate({rnd.uniform(0, 72):.0f})" '
                       f'opacity="{rnd.uniform(.35, .85):.2f}">{petals}<circle r="6" fill="#FFD54F"/></g>')
    return f"""
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FCE4EC"/>
 <stop offset=".5" stop-color="#F3E5F5"/><stop offset="1" stop-color="#E1BEE7"/></linearGradient>
<linearGradient id="ink" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#AD1457"/>
 <stop offset="1" stop-color="#6A1B9A"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>{''.join(flowers)}
<circle cx="360" cy="760" r="250" fill="#fff" opacity=".55" filter="url(#blur30)"/>
{_text(360, 740, 'राधे', 170, 'Tiro', 'url(#ink)')}{_text(360, 930, 'राधे', 170, 'Tiro', 'url(#ink)')}
{_text(360, 1080, 'రాధే రాధే', 64, 'Ramabhadra', '#8E24AA')}"""


def toran_kalash() -> str:
    leaves = "".join(
        f'<path transform="translate({x},70) rotate({rnd})" d="M0,0 C26,40 22,110 0,150 C-22,110 -26,40 0,0 Z" '
        f'fill="{c}"/>' for x, rnd, c in [(40 + i * 64, (i % 2) * 6 - 3, "#2E7D32" if i % 2 else "#43A047")
                                          for i in range(11)])
    marigolds = "".join(f'<circle cx="{8 + i * 32}" cy="{70 + 18 * math.sin(i * .9)}" r="16" fill="#FF8F00"/>'
                        f'<circle cx="{8 + i * 32}" cy="{70 + 18 * math.sin(i * .9)}" r="9" fill="#FFB300"/>'
                        for i in range(23))
    return f"""
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF8E1"/>
 <stop offset=".6" stop-color="#FFE082"/><stop offset="1" stop-color="#FFB300"/></linearGradient>
<linearGradient id="copper" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8D3F17"/>
 <stop offset=".45" stop-color="#E9A06A"/><stop offset="1" stop-color="#8D3F17"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>
<rect width="720" height="60" fill="#C62828"/>{leaves}{marigolds}
<g transform="translate(360,960)">
 <ellipse cy="250" rx="200" ry="26" fill="#000" opacity=".1"/>
 <path d="M-170,0 C-230,120 -150,240 0,250 C150,240 230,120 170,0 C120,-40 -120,-40 -170,0 Z" fill="url(#copper)"/>
 <path d="M-110,-30 C-110,-80 110,-80 110,-30 Z" fill="url(#copper)"/>
 <rect x="-120" y="-60" width="240" height="22" rx="10" fill="url(#gold)"/>
 """ + "".join(f'<path transform="rotate({a})" d="M0,-60 C30,-130 60,-170 90,-200 C40,-190 10,-140 0,-60 Z" fill="#2E7D32"/>'
                 for a in (-50, -25, 0, 25, 50)) + """
 <circle cy="-150" r="72" fill="#8D6E63"/><circle cy="-150" r="60" fill="#A1887F"/>
 <path d="M-50,-140 C-20,-120 20,-120 50,-140" stroke="#6D4C41" stroke-width="4" fill="none"/>
 <g transform="translate(0,110)" stroke="#C62828" stroke-width="12" stroke-linecap="round" fill="none">
  <path d="M0,-60 L0,60 M-60,0 L60,0 M0,-60 L40,-60 M0,60 L-40,60 M-60,0 L-60,40 M60,0 L60,-40"/>
 </g>
</g>
{_text(360, 1420, 'శుభం భవతు', 64, 'Ramabhadra', '#B71C1C')}"""


def hanuman_gada() -> str:
    return f"""
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#B71C1C"/>
 <stop offset=".5" stop-color="#E64A19"/><stop offset="1" stop-color="#3E0A00"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>
<circle cx="360" cy="600" r="320" fill="#FFAB40" opacity=".35" filter="url(#blur30)"/>
{_bokeh(30, 10, ['#FFD180', '#FF6E40'], 4, 20)}
<g transform="translate(360,640) rotate(-18)" filter="url(#glowSm)">
 <rect x="-16" y="40" width="32" height="560" rx="12" fill="url(#goldH)"/>
 <rect x="-24" y="560" width="48" height="40" rx="10" fill="url(#gold)"/>
 <ellipse cy="-90" rx="150" ry="170" fill="url(#gold)"/>
""" + "".join(f'<path d="M{-150 + i * 30},-90 C{-150 + i * 30},-210 {-120 + i * 30},-240 0,-260" '
              f'stroke="#B8860B" stroke-width="3" fill="none" opacity=".6"/>' for i in range(11)) + """
 <ellipse cy="-90" rx="152" ry="26" fill="none" stroke="#8B5A00" stroke-width="6"/>
 <ellipse cy="-150" rx="120" ry="16" fill="none" stroke="#8B5A00" stroke-width="4"/>
 <ellipse cy="-30" rx="120" ry="16" fill="none" stroke="#8B5A00" stroke-width="4"/>
 <path d="M0,-260 L18,-300 L0,-340 L-18,-300 Z" fill="url(#gold)"/>
 <rect x="-40" y="60" width="80" height="22" rx="8" fill="url(#gold)"/>
</g>
""" + f"""{_text(360, 1300, 'జై హనుమాన్', 88, 'Ramabhadra', '#FFF8E1', 'filter="url(#glowSm)"')}
{_text(360, 1380, 'जय बजरंगबली', 46, 'Tiro', '#FFE0B2')}"""


def shankh_chakra() -> str:
    spokes = "".join(f'<line transform="rotate({i * 15})" x1="0" y1="-30" x2="0" y2="-130" stroke="#FFC83D" stroke-width="5"/>'
                     for i in range(24))
    flames = "".join(f'<path transform="rotate({i * 20})" d="M0,-150 C14,-170 10,-190 0,-205 C-10,-190 -14,-170 0,-150 Z" '
                     f'fill="#FFB300"/>' for i in range(18))
    return f"""
<radialGradient id="bg" cx=".5" cy=".45" r=".85"><stop offset="0" stop-color="#1A3A8F"/>
 <stop offset=".6" stop-color="#0A1A4A"/><stop offset="1" stop-color="#030818"/></radialGradient>
<linearGradient id="conch" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFFFFF"/>
 <stop offset=".6" stop-color="#F3E5D8"/><stop offset="1" stop-color="#C9B8A6"/></linearGradient>
<rect width="720" height="1600" fill="url(#bg)"/>{_stars(120, 11)}
<g transform="translate(360,740) scale(1.7)" filter="url(#glowSm)">
 <circle r="230" fill="#FFC83D" opacity=".18" filter="url(#blur30)"/>{flames}
 <circle r="140" fill="none" stroke="url(#gold)" stroke-width="12"/>{spokes}
 <circle r="34" fill="url(#gold)"/><circle r="14" fill="#0A1A4A"/>
</g>
{_text(360, 1360, 'ఓం నమో నారాయణాయ', 58, 'Ramabhadra', 'url(#gold)', 'filter="url(#glowSm)"')}"""


DRAW = {"om-glow": om_glow, "peacock-flute": peacock_flute, "trishul-moon": trishul_moon,
        "tirumala-namam": tirumala_namam, "butter-pot": butter_pot, "lotus-mandala": lotus_mandala,
        "sri-yantra": sri_yantra, "diya-bokeh": diya_bokeh, "jai-shri-ram": jai_shri_ram, "radhe-radhe": radhe_radhe,
        "toran-kalash": toran_kalash, "hanuman-gada": hanuman_gada, "shankh-chakra": shankh_chakra}


def render(slug: str, dest: Path) -> Path:
    """Renders one design to a 1440x3200 PNG at [dest]."""
    body = DRAW[slug]()
    html = (f"<!doctype html><html><head><meta charset='utf-8'><style>{_fonts()}html,body{{margin:0;background:#000}}"
            f"svg{{display:block}}</style></head><body><svg xmlns='http://www.w3.org/2000/svg' width='{W}' "
            f"height='{H}' viewBox='0 0 {W} {H}'>{DEFS}{body}</svg></body></html>")
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / f"{slug}.html"
        page.write_text(html, encoding="utf-8")
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                        f"--window-size={W},{H}", "--force-device-scale-factor=2", "--virtual-time-budget=3000",
                        f"--screenshot={dest}", page.as_uri()], check=True, capture_output=True)
    return dest


if __name__ == "__main__":
    import sys
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name in sys.argv[2:] or DRAW:
        print(render(name, out / f"{name}.png"))
