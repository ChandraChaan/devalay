"""Daily Rashifal from the Moon's transit (Chandra gochar).

The Moon's sidereal sign today is counted from each Moon sign (rashi) to get a
transit house 1-12. Classical gochar treats houses 1, 3, 6, 7, 10 and 11 as
favourable, 2, 5 and 9 as mixed and 4, 8 and 12 as challenging. Text is
assembled deterministically from the house and the weekday so every reader of
a rashi sees the same reading for the day. Presented for reflection and
entertainment, not as prediction.
"""

from __future__ import annotations

import hashlib
from datetime import date

from app.services import panchang

RASHIS = [
    ("mesha", "Aries", "मेष", "♈"), ("vrishabha", "Taurus", "वृषभ", "♉"),
    ("mithuna", "Gemini", "मिथुन", "♊"), ("karka", "Cancer", "कर्क", "♋"),
    ("simha", "Leo", "सिंह", "♌"), ("kanya", "Virgo", "कन्या", "♍"),
    ("tula", "Libra", "तुला", "♎"), ("vrishchika", "Scorpio", "वृश्चिक", "♏"),
    ("dhanu", "Sagittarius", "धनु", "♐"), ("makara", "Capricorn", "मकर", "♑"),
    ("kumbha", "Aquarius", "कुंभ", "♒"), ("meena", "Pisces", "मीन", "♓"),
]
RASHI_INDEX = {slug: i for i, (slug, *_rest) in enumerate(RASHIS)}

HOUSE_RATING = {1: 4, 2: 3, 3: 5, 4: 2, 5: 3, 6: 5, 7: 4, 8: 2, 9: 3, 10: 5, 11: 5, 12: 2}

OVERVIEW = {
    "en": {
        1: ["The Moon in your own sign brings emotional clarity. A good day to begin something you care about.",
            "You feel centred and visible today; people respond warmly to your initiative."],
        2: ["Focus on family and finances. Speak gently; words carry extra weight today.",
            "Spending may rise. Keep a budget in mind and value what you already have."],
        3: ["Courage and energy run high. Short trips, calls and bold efforts go well.",
            "A day to act rather than wait. Siblings and friends lend a helping hand."],
        4: ["The mind may feel restless. Stay close to home and keep plans simple.",
            "Some unease at home or within; a quiet evening and prayer restore calm."],
        5: ["Creative ideas flow, but avoid hasty decisions in money matters.",
            "Children, learning and devotion bring joy; keep expectations realistic."],
        6: ["You overcome obstacles with ease. Health routines and pending work succeed.",
            "Competitors step back and problems shrink. Serve others and you gain."],
        7: ["Partnerships and relationships are in focus. Cooperation brings good results.",
            "A pleasant day for meetings, travel and time with your spouse or partner."],
        8: ["Move carefully and avoid risks. Guard your health and postpone big decisions.",
            "Unexpected delays are possible. Patience and chanting keep you steady."],
        9: ["Faith and guidance from elders help you. Results come, though slowly.",
            "A good day for pilgrimage, scripture and charity; avoid arguments with seniors."],
        10: ["Work and reputation shine. Your efforts are noticed by people who matter.",
             "Responsibilities grow, and so does recognition. Stay humble and focused."],
        11: ["Gains and good news are likely. Friends and networks bring opportunities.",
             "Wishes move toward fulfilment. Share your happiness and give thanks."],
        12: ["Expenses and fatigue may rise. Rest, meditate and spend for good causes.",
             "Let go of what you cannot control. Spiritual practice brings deep peace."],
    },
    "hi": {
        1: ["अपनी ही राशि में चंद्रमा मन को स्पष्टता देता है। मनपसंद कार्य की शुरुआत के लिए शुभ दिन।",
            "आज आप स्वयं को संतुलित महसूस करेंगे; लोग आपकी पहल का स्वागत करेंगे।"],
        2: ["परिवार और धन पर ध्यान दें। मधुर वाणी रखें, आज शब्दों का प्रभाव अधिक है।",
            "खर्च बढ़ सकता है। बजट का ध्यान रखें और जो है उसका सम्मान करें।"],
        3: ["साहस और ऊर्जा भरपूर रहेगी। छोटी यात्राएँ और साहसी प्रयास सफल होंगे।",
            "प्रतीक्षा नहीं, कर्म का दिन। भाई-बहन और मित्र सहयोग करेंगे।"],
        4: ["मन कुछ बेचैन रह सकता है। घर के पास रहें और योजनाएँ सरल रखें।",
            "घर या मन में थोड़ी अशांति संभव है; शांत संध्या और प्रार्थना से सुकून मिलेगा।"],
        5: ["रचनात्मक विचार आएँगे, पर धन के मामलों में जल्दबाज़ी न करें।",
            "संतान, विद्या और भक्ति से प्रसन्नता मिलेगी; अपेक्षाएँ व्यावहारिक रखें।"],
        6: ["आप बाधाओं को आसानी से पार करेंगे। स्वास्थ्य और रुके हुए कार्य सफल होंगे।",
            "विरोधी पीछे हटेंगे और समस्याएँ घटेंगी। सेवा से लाभ होगा।"],
        7: ["साझेदारी और संबंध केंद्र में रहेंगे। सहयोग से अच्छे परिणाम मिलेंगे।",
            "मुलाकातों, यात्रा और जीवनसाथी के साथ समय बिताने के लिए सुखद दिन।"],
        8: ["सावधानी से चलें और जोखिम से बचें। स्वास्थ्य का ध्यान रखें, बड़े निर्णय टालें।",
            "अचानक देरी संभव है। धैर्य और जप आपको स्थिर रखेंगे।"],
        9: ["आस्था और बड़ों का मार्गदर्शन सहायक होगा। परिणाम धीरे-धीरे मिलेंगे।",
            "तीर्थ, शास्त्र-पाठ और दान के लिए शुभ दिन; बड़ों से विवाद न करें।"],
        10: ["कार्य और प्रतिष्ठा चमकेगी। आपके प्रयास सही लोगों की नज़र में आएँगे।",
             "ज़िम्मेदारियाँ बढ़ेंगी और सम्मान भी। विनम्र और केंद्रित रहें।"],
        11: ["लाभ और शुभ समाचार की संभावना है। मित्रों से नए अवसर मिलेंगे।",
             "मनोकामनाएँ पूर्ति की ओर बढ़ेंगी। खुशी बाँटें और आभार व्यक्त करें।"],
        12: ["खर्च और थकान बढ़ सकती है। विश्राम, ध्यान और शुभ कार्यों में व्यय करें।",
             "जो वश में नहीं, उसे छोड़ दें। साधना से गहरी शांति मिलेगी।"],
    },
}

AREAS = {
    "en": {
        "love": {"good": "Warmth and understanding grow in relationships.",
                 "mixed": "Listen more than you speak with loved ones.",
                 "bad": "Avoid misunderstandings; choose patience over pride."},
        "career": {"good": "Work moves forward; take the lead on important tasks.",
                   "mixed": "Steady effort pays off; double-check details.",
                   "bad": "Keep a low profile at work and finish pending tasks."},
        "health": {"good": "Energy is good; a walk or yoga keeps it that way.",
                   "mixed": "Eat on time and stay hydrated.",
                   "bad": "Rest well and avoid overexertion today."},
    },
    "hi": {
        "love": {"good": "संबंधों में स्नेह और समझ बढ़ेगी।",
                 "mixed": "प्रियजनों की बात अधिक सुनें।",
                 "bad": "गलतफहमी से बचें; अहंकार नहीं, धैर्य चुनें।"},
        "career": {"good": "कार्य आगे बढ़ेगा; महत्वपूर्ण कामों में नेतृत्व करें।",
                   "mixed": "निरंतर प्रयास फल देगा; विवरण दोबारा जाँचें।",
                   "bad": "कार्यस्थल पर संयम रखें और लंबित काम पूरे करें।"},
        "health": {"good": "ऊर्जा अच्छी रहेगी; टहलना या योग लाभ देगा।",
                   "mixed": "समय पर भोजन करें और पानी पीते रहें।",
                   "bad": "भरपूर विश्राम करें, आज अधिक श्रम से बचें।"},
    },
}

# Weekday (Mon=0) -> deity of the day, remedy and colour.
WEEKDAY = [
    {"deity": "shiva", "color": ("White", "सफ़ेद"),
     "remedy": ("Offer water to Shiva and chant Om Namah Shivaya 108 times.", "शिवलिंग पर जल अर्पित करें और 108 बार ॐ नमः शिवाय जपें।")},
    {"deity": "hanuman", "color": ("Red", "लाल"),
     "remedy": ("Recite the Hanuman Chalisa and offer sindoor or jaggery.", "हनुमान चालीसा का पाठ करें और गुड़ अर्पित करें।")},
    {"deity": "ganesha", "color": ("Green", "हरा"),
     "remedy": ("Offer durva grass to Ganesha and chant Om Gan Ganapataye Namah.", "गणेश जी को दूर्वा अर्पित करें और ॐ गं गणपतये नमः जपें।")},
    {"deity": "vishnu", "color": ("Yellow", "पीला"),
     "remedy": ("Light a ghee lamp for Vishnu and read a chapter of the Gita.", "विष्णु जी के लिए घी का दीप जलाएँ और गीता का एक अध्याय पढ़ें।")},
    {"deity": "lakshmi", "color": ("Pink", "गुलाबी"),
     "remedy": ("Offer white flowers to Maa Lakshmi and keep your home tidy.", "माँ लक्ष्मी को सफ़ेद फूल अर्पित करें और घर स्वच्छ रखें।")},
    {"deity": "shani", "color": ("Blue", "नीला"),
     "remedy": ("Light a mustard-oil lamp and help someone in need.", "सरसों के तेल का दीप जलाएँ और किसी ज़रूरतमंद की सहायता करें।")},
    {"deity": "surya", "color": ("Orange", "नारंगी"),
     "remedy": ("Offer water to the rising Sun and chant the Gayatri Mantra.", "उगते सूर्य को अर्घ्य दें और गायत्री मंत्र का जप करें।")},
]

DISCLAIMER = {
    "en": "Based on today's Moon transit. For reflection and inspiration only.",
    "hi": "आज के चंद्र गोचर पर आधारित। केवल चिंतन और प्रेरणा हेतु।",
}


def _tier(rating: int) -> str:
    return "good" if rating >= 4 else ("mixed" if rating == 3 else "bad")


def _pick(seq, seed: str):
    h = int(hashlib.sha256(seed.encode()).hexdigest(), 16)
    return seq[h % len(seq)], h


def reading(rashi: str, day: date, language: str = "en", moon_index: int | None = None) -> dict:
    idx = RASHI_INDEX[rashi]
    moon = panchang.moon_rashi_on(day) if moon_index is None else moon_index
    house = (moon - idx) % 12 + 1
    rating = HOUSE_RATING[house]
    tier = _tier(rating)
    lang = "hi" if language == "hi" else "en"
    overview, h = _pick(OVERVIEW[lang][house], f"{day.isoformat()}:{rashi}")
    wd = WEEKDAY[day.weekday()]
    slug, name_en, name_hi, symbol = RASHIS[idx]
    return {
        "rashi": slug,
        "name": name_hi if lang == "hi" else name_en,
        "name_en": name_en,
        "name_hi": name_hi,
        "symbol": symbol,
        "date": day.isoformat(),
        "language": lang,
        "moon_rashi": RASHIS[moon][0],
        "moon_house": house,
        "rating": rating,
        "overview": overview,
        "love": AREAS[lang]["love"][tier],
        "career": AREAS[lang]["career"][tier],
        "health": AREAS[lang]["health"][tier],
        "remedy": wd["remedy"][1 if lang == "hi" else 0],
        "lucky_color": wd["color"][1 if lang == "hi" else 0],
        "lucky_number": (h % 9) + 1,
        "deity_of_day": wd["deity"],
        "disclaimer": DISCLAIMER[lang],
    }


def all_readings(day: date, language: str = "en") -> list[dict]:
    moon = panchang.moon_rashi_on(day)
    return [reading(slug, day, language, moon) for slug, *_ in RASHIS]
