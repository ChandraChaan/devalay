"""Build assets/data/pooja_guides.json: step-by-step pooja guides in English, Hindi and Telugu.

The steps are written in our own words. Mantras are copied verbatim from the app's mantra library
(backend/app/seed/texts.py, MANTRAS), so every mantra a guide shows is one the app already ships and
credits; nothing is typed here. The other languages translate the English through
lib/l10n/<code>_pooja.dart (tool/l10n/extract.py lists the strings in strings_pooja.json).

Usage (from app/): python3 tool/pooja/build_guides.py
"""

import ast
import json
from pathlib import Path

APP = Path(__file__).resolve().parents[2]
TEXTS = APP.parent / "backend/app/seed/texts.py"
OUT = APP / "assets/data/pooja_guides.json"


def t(en, hi, te):
    return {"en": en, "hi": hi, "te": te}


# --- Samagri (items) -------------------------------------------------------------------------------
TURMERIC = t("Turmeric", "हल्दी", "పసుపు")
KUMKUM = t("Kumkum", "कुमकुम (रोली)", "కుంకుమ")
SANDAL = t("Sandalwood paste", "चंदन", "గంధం")
AKSHATA = t("Akshata (rice mixed with turmeric)", "अक्षत (हल्दी मिले चावल)", "అక్షతలు (పసుపు కలిపిన బియ్యం)")
FLOWERS = t("Fresh flowers", "ताज़े फूल", "తాజా పూలు")
INCENSE = t("Incense sticks", "अगरबत्ती", "అగరుబత్తీలు")
LAMP = t("Lamp with ghee or oil, and wicks", "घी या तेल का दीया और बाती", "నెయ్యి లేదా నూనె దీపం, వత్తులు")
CAMPHOR = t("Camphor", "कपूर", "కర్పూరం")
BELL = t("Bell", "घंटी", "గంట")
WATER = t("A small pot of water and a spoon", "जल का लोटा और चम्मच", "నీటి చెంబు, ఉద్ధరిణి")
BETEL = t("Betel leaves and areca nuts", "पान के पत्ते और सुपारी", "తమలపాకులు, వక్కలు")
FRUITS = t("Fruits", "फल", "పండ్లు")
COCONUT = t("Coconut", "नारियल", "కొబ్బరికాయ")
NAIVEDYA = t("Naivedyam (food to offer)", "नैवेद्य (भोग)", "నైవేద్యం")
MATCHES = t("Matchbox", "माचिस", "అగ్గిపెట్టె")
ASANA = t("A mat or low seat to sit on", "बैठने के लिए आसन", "కూర్చోవడానికి ఆసనం (చాప లేదా పీట)")
KALASH = t(
    "Kalash: a pot of water with mango leaves and a coconut on top",
    "कलश: जल से भरा लोटा, ऊपर आम के पत्ते और नारियल",
    "కలశం: నీటి చెంబు, పైన మామిడాకులు, కొబ్బరికాయ",
)
PANCHAMRIT = t(
    "Panchamrit: milk, curd, ghee, honey and sugar",
    "पंचामृत: दूध, दही, घी, शहद और शक्कर",
    "పంచామృతం: పాలు, పెరుగు, నెయ్యి, తేనె, పంచదార",
)
TULSI = t("Tulsi leaves (picked the day before)", "तुलसी दल (एक दिन पहले तोड़े हुए)", "తులసి దళాలు (ముందు రోజే కోసినవి)")
BILVA = t("Bilva (bel) leaves", "बेलपत्र", "మారేడు దళాలు (బిల్వ పత్రాలు)")
CLOTH = t("A new cloth for the deity", "देवता के लिए नया वस्त्र", "దేవునికి కొత్త వస్త్రం")
PLATFORM = t(
    "A raised platform covered with a clean cloth",
    "साफ़ कपड़ा बिछी चौकी",
    "శుభ్రమైన వస్త్రం పరిచిన పీట",
)

# --- Steps shared by several guides ----------------------------------------------------------------


def step(title, text, mantra=None):
    s = {"title": title, "text": text}
    if mantra:
        s["mantra"] = mantra
    return s


PREPARE = step(
    t("Prepare", "तैयारी", "సిద్ధం కావడం"),
    t(
        "Bathe and wear clean clothes. Clean the puja place, draw a small rangoli and set the deity on a raised "
        "seat, facing east or north. Keep every item within reach.",
        "स्नान करके साफ़ कपड़े पहनें। पूजा का स्थान साफ़ करें, छोटी रंगोली बनाएँ और देवता को पूर्व या उत्तर की ओर "
        "ऊँचे आसन पर रखें। सारी सामग्री पास रख लें।",
        "స్నానం చేసి శుభ్రమైన బట్టలు ధరించండి. పూజ చేసే చోటు శుభ్రం చేసి, చిన్న ముగ్గు వేసి, దేవుణ్ణి తూర్పు లేదా "
        "ఉత్తరం వైపు ఎత్తైన పీటపై ఉంచండి. సామగ్రి అంతా దగ్గర పెట్టుకోండి.",
    ),
)
LIGHT = step(
    t("Light the lamp", "दीप जलाएँ", "దీపం వెలిగించండి"),
    t(
        "Light the lamp and the incense. The lamp is the witness of the puja; keep it burning until the end.",
        "दीया और अगरबत्ती जलाएँ। दीप पूजा का साक्षी है; इसे अंत तक जलता रहने दें।",
        "దీపం, అగరుబత్తీ వెలిగించండి. దీపమే పూజకు సాక్షి; పూజ పూర్తయ్యే వరకు అది వెలుగుతూ ఉండాలి.",
    ),
)
GANESHA = step(
    t("Pray to Ganesha first", "पहले गणेश वंदना", "ముందుగా గణపతి ప్రార్థన"),
    t(
        "Every puja begins with Ganesha, the remover of obstacles. Fold your hands and chant his prayer.",
        "हर पूजा विघ्नहर्ता गणेश से शुरू होती है। हाथ जोड़कर उनकी वंदना करें।",
        "ప్రతి పూజ విఘ్నాలను తొలగించే గణపతితో మొదలవుతుంది. చేతులు జోడించి ఆయన ప్రార్థన చేయండి.",
    ),
    "vakratunda-mahakaya",
)
SANKALPA = step(
    t("Sankalpa: say your intention", "संकल्प", "సంకల్పం"),
    t(
        "Take a little water and akshata in your right palm. Say your name, your family name (gotra) if you know "
        "it, today's date and why you are doing this puja. Then let the water fall into a plate.",
        "दाहिनी हथेली में थोड़ा जल और अक्षत लें। अपना नाम, गोत्र (यदि पता हो), आज की तिथि और पूजा का उद्देश्य कहें। "
        "फिर जल थाली में छोड़ दें।",
        "కుడి అరచేతిలో కొద్దిగా నీళ్ళు, అక్షతలు తీసుకోండి. మీ పేరు, గోత్రం (తెలిస్తే), ఈ రోజు తిథి, ఈ పూజ ఎందుకు "
        "చేస్తున్నారో చెప్పి, నీటిని పళ్ళెంలో వదలండి.",
    ),
)
UPACHARA = step(
    t("Offer the upacharas", "उपचार अर्पित करें", "ఉపచారాలు సమర్పించండి"),
    t(
        "Welcome the deity as an honoured guest: offer water for the feet, hands and mouth, sprinkle water as a "
        "bath, offer a cloth, then sandal, kumkum, akshata and flowers. Show the incense and the lamp.",
        "देवता का आदरणीय अतिथि की तरह स्वागत करें: पैर, हाथ और आचमन के लिए जल, स्नान के लिए जल छिड़कें, वस्त्र, फिर "
        "चंदन, कुमकुम, अक्षत और फूल चढ़ाएँ। धूप और दीप दिखाएँ।",
        "దేవుణ్ణి గౌరవ అతిథిగా ఆహ్వానించండి: పాదాలకు, చేతులకు, ఆచమనానికి నీళ్ళు, స్నానానికి నీళ్ళు చల్లి, వస్త్రం, "
        "తర్వాత గంధం, కుంకుమ, అక్షతలు, పూలు సమర్పించండి. ధూపం, దీపం చూపించండి.",
    ),
)
NAIVEDYAM = step(
    t("Offer naivedyam", "नैवेद्य अर्पित करें", "నైవేద్యం సమర్పించండి"),
    t(
        "Place the food before the deity, sprinkle a little water around it and offer it with love. Then offer "
        "betel leaves, areca nut and fruit.",
        "भोग देवता के सामने रखें, उसके चारों ओर थोड़ा जल छिड़कें और प्रेम से अर्पित करें। फिर पान, सुपारी और फल चढ़ाएँ।",
        "నైవేద్యాన్ని దేవుని ముందు ఉంచి, చుట్టూ కొద్దిగా నీళ్ళు చల్లి, ప్రేమతో సమర్పించండి. తర్వాత తాంబూలం, పండ్లు "
        "సమర్పించండి.",
    ),
)
AARTI = step(
    t("Aarti", "आरती", "హారతి"),
    t(
        "Light camphor and wave it clockwise before the deity while ringing the bell and singing the aarti. "
        "Take the warmth of the flame with both hands to your eyes.",
        "कपूर जलाकर घंटी बजाते और आरती गाते हुए देवता के सामने घड़ी की दिशा में घुमाएँ। दोनों हाथों से लौ की आँच "
        "आँखों से लगाएँ।",
        "కర్పూరం వెలిగించి, గంట కొడుతూ, హారతి పాడుతూ దేవుని ముందు సవ్యదిశలో తిప్పండి. రెండు చేతులతో హారతి "
        "వెచ్చదనాన్ని కళ్ళకు అద్దుకోండి.",
    ),
)
NAMASKAR = step(
    t("Pradakshina and namaskar", "प्रदक्षिणा और नमस्कार", "ప్రదక్షిణ, నమస్కారం"),
    t(
        "Turn around clockwise three times where you stand, or walk around the deity, then bow down fully.",
        "जहाँ खड़े हैं वहीं घड़ी की दिशा में तीन बार घूमें, या देवता की परिक्रमा करें, फिर साष्टांग प्रणाम करें।",
        "నిల్చున్న చోటే సవ్యదిశలో మూడుసార్లు తిరగండి, లేదా దేవుని చుట్టూ ప్రదక్షిణ చేయండి, తర్వాత సాష్టాంగ నమస్కారం "
        "చేయండి.",
    ),
)
CLOSE = step(
    t("Ask forgiveness and share prasad", "क्षमा प्रार्थना और प्रसाद", "క్షమాపణ, ప్రసాదం"),
    t(
        "Ask pardon for anything missed or done wrong, pray for the well-being of all, and share the prasad with "
        "your family.",
        "पूजा में हुई किसी भी भूल के लिए क्षमा माँगें, सबके कल्याण की प्रार्थना करें और परिवार में प्रसाद बाँटें।",
        "పూజలో ఏదైనా లోపం జరిగితే క్షమించమని వేడుకోండి, అందరి మేలు కోసం ప్రార్థించి, కుటుంబంతో ప్రసాదం పంచుకోండి.",
    ),
    "sarve-bhavantu-sukhinah",
)

BASIC = [TURMERIC, KUMKUM, SANDAL, AKSHATA, FLOWERS, INCENSE, LAMP, CAMPHOR, BELL, WATER, MATCHES, ASANA]

GUIDES = [
    {
        "id": "daily",
        "emoji": "🪔",
        "match": [],
        "title": t("Daily puja", "दैनिक पूजा", "నిత్య పూజ"),
        "summary": t(
            "A simple ten-minute puja at home, morning or evening.",
            "घर पर सुबह या शाम की दस मिनट की सरल पूजा।",
            "ఇంట్లో ఉదయం లేదా సాయంత్రం పది నిమిషాల సులభమైన పూజ.",
        ),
        "when": t(
            "Every day after bath, ideally at sunrise or at dusk.",
            "प्रतिदिन स्नान के बाद, हो सके तो सूर्योदय या संध्या के समय।",
            "ప్రతిరోజూ స్నానం తర్వాత, వీలైతే సూర్యోదయం లేదా సంధ్యా సమయంలో.",
        ),
        "samagri": [TURMERIC, KUMKUM, AKSHATA, FLOWERS, INCENSE, LAMP, CAMPHOR, BELL, WATER, NAIVEDYA, MATCHES],
        "steps": [
            PREPARE,
            LIGHT,
            GANESHA,
            step(
                t("Remember your deity", "इष्टदेव का ध्यान", "ఇష్టదైవ ధ్యానం"),
                t(
                    "Sit quietly for a moment, picture your chosen deity and chant a mantra you know, or the Gayatri.",
                    "एक क्षण शांत बैठें, अपने इष्टदेव का ध्यान करें और कोई परिचित मंत्र या गायत्री मंत्र जपें।",
                    "ఒక క్షణం నిశ్శబ్దంగా కూర్చుని, మీ ఇష్టదైవాన్ని తలచుకుని, మీకు తెలిసిన మంత్రం లేదా గాయత్రి జపించండి.",
                ),
                "gayatri-mantra",
            ),
            UPACHARA,
            NAIVEDYAM,
            AARTI,
            NAMASKAR,
            CLOSE,
        ],
    },
    {
        "id": "satyanarayana",
        "emoji": "🌕",
        "match": ["purnima", "kartik-purnima"],
        "title": t("Satyanarayana Vratam", "सत्यनारायण व्रत", "సత్యనారాయణ వ్రతం"),
        "summary": t(
            "Worship of Lord Vishnu as Satyanarayana, with the five chapters of the vrata katha.",
            "भगवान विष्णु के सत्यनारायण रूप की पूजा, व्रत कथा के पाँच अध्यायों के साथ।",
            "సత్యనారాయణ స్వామిగా శ్రీమహావిష్ణువు పూజ, ఐదు అధ్యాయాల వ్రత కథతో.",
        ),
        "when": t(
            "On Purnima, Ekadashi or any auspicious day, such as a housewarming or after a wish comes true; "
            "usually in the evening.",
            "पूर्णिमा, एकादशी या किसी भी शुभ दिन, जैसे गृहप्रवेश या मनोकामना पूरी होने पर; प्रायः शाम को।",
            "పౌర్ణమి, ఏకాదశి లేదా గృహప్రవేశం, కోరిక తీరినప్పుడు వంటి ఏ శుభదినమైనా; సాధారణంగా సాయంత్రం.",
        ),
        "samagri": [
            PLATFORM,
            t("A picture of Satyanarayana Swamy", "सत्यनारायण भगवान का चित्र", "సత్యనారాయణ స్వామి పటం"),
            KALASH,
            *BASIC,
            TULSI,
            PANCHAMRIT,
            BETEL,
            t("Bananas", "केले", "అరటిపండ్లు"),
            CLOTH,
            t(
                "Prasad: semolina roasted in ghee with sugar, banana and milk",
                "प्रसाद: घी में भुनी सूजी, शक्कर, केला और दूध (शीरा)",
                "ప్రసాదం: నెయ్యిలో వేయించిన రవ్వ, పంచదార, అరటిపండు, పాలు",
            ),
            t("The vrata katha book", "व्रत कथा की पुस्तक", "వ్రత కథ పుస్తకం"),
        ],
        "steps": [
            PREPARE,
            step(
                t("Set up the mandapam", "मंडप सजाएँ", "మండపం అలంకరణ"),
                t(
                    "Cover the platform with cloth, spread a little rice and place the kalash on it. Set the picture of "
                    "Satyanarayana Swamy behind the kalash and decorate with flowers and banana leaves.",
                    "चौकी पर कपड़ा बिछाकर थोड़े चावल फैलाएँ और उस पर कलश रखें। कलश के पीछे सत्यनारायण भगवान का चित्र रखें "
                    "और फूलों व केले के पत्तों से सजाएँ।",
                    "పీటపై వస్త్రం పరిచి కొద్దిగా బియ్యం పోసి దానిపై కలశం ఉంచండి. కలశం వెనుక సత్యనారాయణ స్వామి పటం పెట్టి, "
                    "పూలు, అరటి ఆకులతో అలంకరించండి.",
                ),
            ),
            LIGHT,
            GANESHA,
            SANKALPA,
            step(
                t("Worship Satyanarayana", "सत्यनारायण पूजन", "సత్యనారాయణ పూజ"),
                t(
                    "Invite the Lord into the kalash, bathe the picture with panchamrit (sprinkle it), offer a cloth, "
                    "sandal, tulsi and flowers, chanting his name.",
                    "भगवान का कलश में आवाहन करें, पंचामृत से स्नान (छिड़ककर) कराएँ, वस्त्र, चंदन, तुलसी और फूल अर्पित करते "
                    "हुए उनका नाम जपें।",
                    "స్వామిని కలశంలోకి ఆవాహన చేసి, పంచామృతంతో అభిషేకం (చల్లి), వస్త్రం, గంధం, తులసి, పూలు సమర్పిస్తూ "
                    "నామం జపించండి.",
                ),
                "om-namo-bhagavate-vasudevaya",
            ),
            step(
                t("Read the vrata katha", "व्रत कथा पढ़ें", "వ్రత కథ చదవండి"),
                t(
                    "Read or listen to the five chapters of the Satyanarayana katha with the family, holding akshata. "
                    "After each chapter, offer the akshata to the Lord.",
                    "परिवार के साथ हाथ में अक्षत लेकर सत्यनारायण कथा के पाँचों अध्याय पढ़ें या सुनें। हर अध्याय के बाद अक्षत "
                    "भगवान को अर्पित करें।",
                    "కుటుంబంతో కలిసి అక్షతలు చేతపట్టుకుని సత్యనారాయణ వ్రత కథ ఐదు అధ్యాయాలు చదవండి లేదా వినండి. ప్రతి "
                    "అధ్యాయం తర్వాత అక్షతలు స్వామికి సమర్పించండి.",
                ),
            ),
            NAIVEDYAM,
            step(
                t("Aarti", "आरती", "హారతి"),
                t(
                    "Do the aarti with camphor and ghee lamps while everyone sings.",
                    "सब मिलकर गाते हुए कपूर और घी के दीयों से आरती करें।",
                    "అందరూ కలిసి పాడుతూ కర్పూరం, నేతి దీపాలతో హారతి ఇవ్వండి.",
                ),
                "shantakaram-bhujagashayanam",
            ),
            CLOSE,
        ],
    },
    {
        "id": "varalakshmi",
        "emoji": "🪷",
        "match": ["varalakshmi-vratam"],
        "title": t("Varalakshmi Vratam", "वरलक्ष्मी व्रत", "వరలక్ష్మీ వ్రతం"),
        "summary": t(
            "Worship of Goddess Lakshmi as the giver of boons, for the well-being of the family.",
            "परिवार के कल्याण के लिए वर देने वाली माँ लक्ष्मी की पूजा।",
            "కుటుంబ క్షేమం కోసం వరాలిచ్చే వరలక్ష్మీ అమ్మవారి పూజ.",
        ),
        "when": t(
            "The Friday before Shravana Purnima, in the morning.",
            "श्रावण पूर्णिमा से पहले वाले शुक्रवार को, सुबह।",
            "శ్రావణ పౌర్ణమికి ముందు వచ్చే శుక్రవారం, ఉదయం.",
        ),
        "samagri": [
            PLATFORM,
            KALASH,
            t(
                "A face or picture of Goddess Lakshmi for the kalash",
                "कलश के लिए माँ लक्ष्मी का मुख या चित्र",
                "కలశానికి అమ్మవారి ముఖం లేదా పటం",
            ),
            t("A new saree or blouse piece for the Goddess", "देवी के लिए नई साड़ी या ब्लाउज़ पीस", "అమ్మవారికి కొత్త చీర లేదా రవికె గుడ్డ"),
            t(
                "Yellow thread (thoram) with nine knots for the wrist",
                "कलाई पर बाँधने के लिए नौ गाँठ वाला पीला धागा",
                "చేతికి కట్టుకోవడానికి తొమ్మిది ముడుల తోరం",
            ),
            *BASIC,
            BETEL,
            FRUITS,
            t("Sweets such as payasam or pongal", "खीर या पायसम जैसी मिठाई", "పాయసం, పొంగలి వంటి తీపి వంటకాలు"),
            t(
                "Gifts for married women (vayanam): turmeric, kumkum, bangles, fruit",
                "सुहागिनों के लिए वायन: हल्दी, कुमकुम, चूड़ियाँ, फल",
                "ముత్తైదువులకు వాయనం: పసుపు, కుంకుమ, గాజులు, పండ్లు",
            ),
        ],
        "steps": [
            PREPARE,
            step(
                t("Decorate the kalash", "कलश सजाएँ", "కలశం అలంకరణ"),
                t(
                    "Fill the kalash with water, rice or coins, put mango leaves and a coconut on top, fix the face of the "
                    "Goddess and drape the saree around it. Place it on rice spread over the platform.",
                    "कलश में जल, चावल या सिक्के भरें, ऊपर आम के पत्ते और नारियल रखें, देवी का मुख लगाकर साड़ी पहनाएँ। इसे "
                    "चौकी पर फैले चावलों पर रखें।",
                    "కలశంలో నీళ్ళు, బియ్యం లేదా నాణేలు నింపి, పైన మామిడాకులు, కొబ్బరికాయ ఉంచి, అమ్మవారి ముఖం అమర్చి చీర "
                    "కట్టండి. పీటపై పోసిన బియ్యంపై ఉంచండి.",
                ),
            ),
            LIGHT,
            GANESHA,
            SANKALPA,
            step(
                t("Invite the Goddess", "देवी का आवाहन", "అమ్మవారి ఆవాహన"),
                t(
                    "With akshata in your hands, invite Varalakshmi into the kalash and offer her a seat, water, a cloth, "
                    "turmeric, kumkum and flowers.",
                    "हाथ में अक्षत लेकर वरलक्ष्मी का कलश में आवाहन करें और आसन, जल, वस्त्र, हल्दी, कुमकुम और फूल अर्पित करें।",
                    "చేతిలో అక్షతలతో వరలక్ష్మిని కలశంలోకి ఆవాహన చేసి, ఆసనం, నీళ్ళు, వస్త్రం, పసుపు, కుంకుమ, పూలు "
                    "సమర్పించండి.",
                ),
                "om-shreem-mahalakshmyai-namah",
            ),
            step(
                t("Worship the thread", "धागे की पूजा", "తోర పూజ"),
                t(
                    "Place the nine-knot thread before the Goddess, offer kumkum and flowers to it, then tie it on the right "
                    "wrist.",
                    "नौ गाँठ वाला धागा देवी के सामने रखें, उस पर कुमकुम और फूल चढ़ाएँ, फिर दाहिनी कलाई पर बाँधें।",
                    "తొమ్మిది ముడుల తోరాన్ని అమ్మవారి ముందు ఉంచి, కుంకుమ, పూలతో పూజించి, కుడి చేతికి కట్టుకోండి.",
                ),
                "sarva-mangala-mangalye",
            ),
            NAIVEDYAM,
            AARTI,
            step(
                t("Give vayanam", "वायन दें", "వాయనం ఇవ్వండి"),
                t(
                    "Offer turmeric, kumkum, fruit and sweets to married women of the family or neighbourhood and take "
                    "their blessings. Read the vrata katha if you have it.",
                    "परिवार या पड़ोस की सुहागिनों को हल्दी, कुमकुम, फल और मिठाई देकर आशीर्वाद लें। हो सके तो व्रत कथा पढ़ें।",
                    "ఇంట్లో లేదా ఇరుగుపొరుగు ముత్తైదువులకు పసుపు, కుంకుమ, పండ్లు, తీపి వాయనంగా ఇచ్చి ఆశీర్వాదం "
                    "తీసుకోండి. వీలైతే వ్రత కథ చదవండి.",
                ),
            ),
            CLOSE,
        ],
    },
    {
        "id": "vinayaka-chavithi",
        "emoji": "🐘",
        "match": ["ganesh-chaturthi"],
        "title": t("Vinayaka Chavithi puja", "गणेश चतुर्थी पूजा", "వినాయక చవితి పూజ"),
        "summary": t(
            "Bringing home a clay Ganesha and worshipping him with twenty-one kinds of leaves.",
            "मिट्टी के गणेश को घर लाकर इक्कीस प्रकार की पत्तियों से पूजा।",
            "మట్టి వినాయకుణ్ణి ఇంటికి తెచ్చి ఇరవై ఒక్క రకాల పత్రితో చేసే పూజ.",
        ),
        "when": t(
            "Bhadrapada Shukla Chaturthi, in the late morning (madhyahna).",
            "भाद्रपद शुक्ल चतुर्थी, दोपहर से पहले (मध्याह्न) में।",
            "భాద్రపద శుద్ధ చవితి, మధ్యాహ్నానికి ముందు.",
        ),
        "samagri": [
            t("A clay Ganesha idol", "मिट्टी की गणेश प्रतिमा", "మట్టి వినాయక విగ్రహం"),
            PLATFORM,
            t(
                "A canopy of fruits and leaves to hang above the idol",
                "प्रतिमा के ऊपर बाँधने के लिए फल-पत्तों का मंडप",
                "విగ్రహం పైన కట్టడానికి పండ్లు, ఆకులతో పాలవెల్లి",
            ),
            t("Durva grass", "दूर्वा घास", "గరిక"),
            t("Twenty-one kinds of leaves (patri)", "इक्कीस प्रकार की पत्तियाँ (पत्री)", "ఇరవై ఒక్క రకాల పత్రి"),
            *BASIC,
            BETEL,
            FRUITS,
            COCONUT,
            t("Modaks or kudumulu", "मोदक", "ఉండ్రాళ్ళు, కుడుములు"),
        ],
        "steps": [
            PREPARE,
            step(
                t("Install the idol", "प्रतिमा स्थापना", "విగ్రహ స్థాపన"),
                t(
                    "Place the clay idol on the platform under the canopy, facing east or west.",
                    "मिट्टी की प्रतिमा को मंडप के नीचे चौकी पर पूर्व या पश्चिम मुख करके रखें।",
                    "మట్టి విగ్రహాన్ని పాలవెల్లి కింద పీటపై తూర్పు లేదా పడమర ముఖంగా ఉంచండి.",
                ),
            ),
            LIGHT,
            SANKALPA,
            step(
                t("Invite Ganesha", "गणेश का आवाहन", "గణపతి ఆవాహన"),
                t(
                    "Invite Ganesha into the idol and offer the upacharas: water, a cloth, a sacred thread, sandal, "
                    "kumkum, akshata and flowers.",
                    "प्रतिमा में गणेश का आवाहन करें और उपचार अर्पित करें: जल, वस्त्र, यज्ञोपवीत, चंदन, कुमकुम, अक्षत और फूल।",
                    "విగ్రహంలోకి గణపతిని ఆవాహన చేసి ఉపచారాలు సమర్పించండి: నీళ్ళు, వస్త్రం, యజ్ఞోపవీతం, గంధం, కుంకుమ, "
                    "అక్షతలు, పూలు.",
                ),
                "vakratunda-mahakaya",
            ),
            step(
                t("Patri puja", "पत्री पूजा", "పత్రి పూజ"),
                t(
                    "Offer the twenty-one kinds of leaves and the durva one by one, chanting one of Ganesha's names "
                    "with each.",
                    "इक्कीस प्रकार की पत्तियाँ और दूर्वा एक-एक कर चढ़ाएँ, हर एक के साथ गणेश का एक नाम लें।",
                    "ఇరవై ఒక్క రకాల పత్రి, గరికను ఒక్కొక్కటిగా సమర్పిస్తూ ప్రతిదానితో గణపతి ఒక్కో నామం చెప్పండి.",
                ),
                "om-gan-ganapataye-namah",
            ),
            step(
                t("Offer modaks", "मोदक का भोग", "ఉండ్రాళ్ళ నైవేద్యం"),
                t(
                    "Offer modaks or kudumulu, fruit and coconut as naivedyam.",
                    "मोदक, फल और नारियल का भोग लगाएँ।",
                    "ఉండ్రాళ్ళు, కుడుములు, పండ్లు, కొబ్బరికాయ నైవేద్యంగా సమర్పించండి.",
                ),
            ),
            AARTI,
            step(
                t("Hear the story", "कथा सुनें", "కథ వినండి"),
                t(
                    "Read the Vinayaka katha, including the story of the Syamantaka jewel, and place the akshata on your "
                    "head afterwards. Many families avoid looking at the moon on this night.",
                    "विनायक कथा पढ़ें, जिसमें स्यमंतक मणि की कथा भी है, और बाद में अक्षत सिर पर रखें। कई परिवार इस रात "
                    "चंद्रमा नहीं देखते।",
                    "శమంతకమణి కథతో సహా వినాయక కథ చదివి, తర్వాత అక్షతలు తలపై వేసుకోండి. చాలా కుటుంబాలు ఈ రాత్రి చంద్రుణ్ణి "
                    "చూడరు.",
                ),
            ),
            step(
                t("Immersion", "विसर्जन", "నిమజ్జనం"),
                t(
                    "On the day you choose (the 1st, 3rd, 5th, 9th or 11th day), do a short puja and immerse the clay "
                    "idol in a bucket or tank of water at home, then pour the water into plants.",
                    "चुने हुए दिन (पहले, तीसरे, पाँचवें, नौवें या ग्यारहवें दिन) छोटी पूजा करके मिट्टी की प्रतिमा का घर पर "
                    "बाल्टी या टब में विसर्जन करें, फिर वह पानी पौधों में डालें।",
                    "మీరు ఎంచుకున్న రోజున (1, 3, 5, 9 లేదా 11వ రోజు) చిన్న పూజ చేసి, మట్టి విగ్రహాన్ని ఇంట్లోనే బకెట్ లేదా "
                    "తొట్టిలో నిమజ్జనం చేసి, ఆ నీటిని మొక్కలకు పోయండి.",
                ),
            ),
        ],
    },
    {
        "id": "diwali-lakshmi",
        "emoji": "🪔",
        "match": ["diwali"],
        "title": t("Diwali Lakshmi Puja", "दीपावली लक्ष्मी पूजा", "దీపావళి లక్ష్మీ పూజ"),
        "summary": t(
            "Worship of Lakshmi and Ganesha on Diwali evening, with lamps all around the home.",
            "दीपावली की शाम घर भर में दीप जलाकर लक्ष्मी-गणेश की पूजा।",
            "దీపావళి సాయంత్రం ఇల్లంతా దీపాలు పెట్టి లక్ష్మీ గణపతుల పూజ.",
        ),
        "when": t(
            "Amavasya of Kartika (Ashvin in some calendars), in the evening after sunset (pradosha).",
            "कार्तिक अमावस्या, सूर्यास्त के बाद प्रदोष काल में।",
            "ఆశ్వయుజ అమావాస్య (కొన్ని పంచాంగాల్లో కార్తీక), సూర్యాస్తమయం తర్వాత ప్రదోష కాలంలో.",
        ),
        "samagri": [
            PLATFORM,
            t("Idols or a picture of Lakshmi and Ganesha", "लक्ष्मी-गणेश की प्रतिमा या चित्र", "లక్ష్మీ గణపతుల విగ్రహాలు లేదా పటం"),
            KALASH,
            t("Many small clay lamps", "मिट्टी के कई दीये", "చాలా మట్టి ప్రమిదలు"),
            *BASIC,
            t("Lotus or red flowers", "कमल या लाल फूल", "తామర లేదా ఎర్ర పూలు"),
            t("Coins or a silver coin", "सिक्के या चाँदी का सिक्का", "నాణేలు లేదా వెండి నాణెం"),
            t("Puffed rice and sugar drops", "खील-बताशे", "మరమరాలు, పటిక బెల్లం"),
            t("Sweets", "मिठाई", "మిఠాయిలు"),
            BETEL,
            FRUITS,
        ],
        "steps": [
            step(
                t("Clean and decorate", "सफ़ाई और सजावट", "శుభ్రం చేసి అలంకరించండి"),
                t(
                    "Clean the house, draw a rangoli at the door and arrange lamps at the entrance and in every room.",
                    "घर साफ़ करें, दरवाज़े पर रंगोली बनाएँ और द्वार व हर कमरे में दीये सजाएँ।",
                    "ఇల్లు శుభ్రం చేసి, గుమ్మం ముందు ముగ్గు వేసి, వాకిట్లో, ప్రతి గదిలో దీపాలు అమర్చండి.",
                ),
            ),
            step(
                t("Set up the altar", "पूजा स्थल सजाएँ", "పూజా పీఠం"),
                t(
                    "Place Lakshmi and Ganesha side by side on the platform, with the kalash beside them and the coins in "
                    "a plate before them.",
                    "चौकी पर लक्ष्मी जी और गणेश जी को साथ-साथ रखें, पास में कलश और सामने थाली में सिक्के।",
                    "పీటపై లక్ష్మీదేవిని, గణపతిని పక్కపక్కనే ఉంచి, పక్కన కలశం, ముందు పళ్ళెంలో నాణేలు పెట్టండి.",
                ),
            ),
            LIGHT,
            GANESHA,
            SANKALPA,
            step(
                t("Worship Lakshmi", "लक्ष्मी पूजन", "లక్ష్మీ పూజ"),
                t(
                    "Offer the Goddess water, kumkum, turmeric, akshata, lotus or red flowers, and worship the coins "
                    "and account books as her form.",
                    "देवी को जल, कुमकुम, हल्दी, अक्षत, कमल या लाल फूल अर्पित करें और सिक्कों व बही-खातों की उनके रूप में पूजा करें।",
                    "అమ్మవారికి నీళ్ళు, కుంకుమ, పసుపు, అక్షతలు, తామర లేదా ఎర్ర పూలు సమర్పించి, నాణేలను, లెక్కల పుస్తకాలను "
                    "ఆమె రూపంగా పూజించండి.",
                ),
                "om-shreem-mahalakshmyai-namah",
            ),
            step(
                t("Offer sweets", "मिठाई का भोग", "మిఠాయిల నైవేద్యం"),
                t(
                    "Offer puffed rice, sugar drops, sweets and fruit.",
                    "खील-बताशे, मिठाई और फल का भोग लगाएँ।",
                    "మరమరాలు, పటిక బెల్లం, మిఠాయిలు, పండ్లు నైవేద్యంగా సమర్పించండి.",
                ),
            ),
            AARTI,
            step(
                t("Light the lamps", "दीप जलाएँ", "దీపాలు వెలిగించండి"),
                t(
                    "Light the lamps from the puja lamp and place them around the home. Leave one burning near the altar "
                    "through the night.",
                    "पूजा के दीप से बाकी दीये जलाकर घर भर में रखें। एक दीया रात भर पूजा स्थल के पास जलने दें।",
                    "పూజ దీపం నుంచి మిగతా దీపాలు వెలిగించి ఇల్లంతా పెట్టండి. ఒక దీపం రాత్రంతా పూజా పీఠం దగ్గర వెలగనివ్వండి.",
                ),
            ),
            CLOSE,
        ],
    },
    {
        "id": "maha-shivaratri",
        "emoji": "🔱",
        "match": ["maha-shivratri", "masik-shivratri"],
        "title": t("Maha Shivaratri puja", "महाशिवरात्रि पूजा", "మహాశివరాత్రి పూజ"),
        "summary": t(
            "A night of fasting, abhishekam and wakefulness for Lord Shiva.",
            "भगवान शिव के लिए उपवास, अभिषेक और जागरण की रात।",
            "శివుని కోసం ఉపవాసం, అభిషేకం, జాగరణ చేసే రాత్రి.",
        ),
        "when": t(
            "Krishna Chaturdashi of Magha (Phalguna in North India). The main puja is at night, in four parts "
            "(praharas) if you can.",
            "फाल्गुन कृष्ण चतुर्दशी (दक्षिण में माघ)। मुख्य पूजा रात में, हो सके तो चार प्रहरों में।",
            "మాఘ బహుళ చతుర్దశి. ప్రధాన పూజ రాత్రి, వీలైతే నాలుగు జాముల్లో.",
        ),
        "samagri": [
            t("A Shiva linga or picture", "शिवलिंग या चित्र", "శివలింగం లేదా పటం"),
            t(
                "Water, milk, curd, honey and ghee for abhishekam",
                "अभिषेक के लिए जल, दूध, दही, शहद और घी",
                "అభిషేకానికి నీళ్ళు, పాలు, పెరుగు, తేనె, నెయ్యి",
            ),
            BILVA,
            t("Vibhuti (sacred ash)", "भस्म (विभूति)", "విభూతి"),
            t("White flowers", "सफ़ेद फूल", "తెల్లని పూలు"),
            SANDAL,
            AKSHATA,
            INCENSE,
            LAMP,
            CAMPHOR,
            BELL,
            FRUITS,
            MATCHES,
            ASANA,
            t("A rudraksha mala for japa", "जप के लिए रुद्राक्ष माला", "జపానికి రుద్రాక్ష మాల"),
        ],
        "steps": [
            step(
                t("Fast through the day", "दिन भर उपवास", "పగలంతా ఉపవాసం"),
                t(
                    "Keep a fast from morning: water and fruit, or a full fast if your health allows. Spend the day "
                    "chanting Om Namah Shivaya.",
                    "सुबह से उपवास रखें: जल और फल, या स्वास्थ्य अनुमति दे तो निर्जल। दिन भर ॐ नमः शिवाय जपें।",
                    "ఉదయం నుంచి ఉపవాసం ఉండండి: నీళ్ళు, పండ్లు, లేదా ఆరోగ్యం అనుకూలిస్తే పూర్తి ఉపవాసం. రోజంతా ఓం నమః శివాయ "
                    "జపించండి.",
                ),
                "om-namah-shivaya",
            ),
            PREPARE,
            LIGHT,
            GANESHA,
            SANKALPA,
            step(
                t("Abhishekam", "अभिषेक", "అభిషేకం"),
                t(
                    "Pour water over the linga, then milk, curd, honey and ghee, and water again after each, chanting "
                    "Om Namah Shivaya.",
                    "ॐ नमः शिवाय जपते हुए शिवलिंग पर जल, फिर दूध, दही, शहद और घी चढ़ाएँ, हर एक के बाद फिर जल।",
                    "ఓం నమః శివాయ జపిస్తూ లింగంపై నీళ్ళు, తర్వాత పాలు, పెరుగు, తేనె, నెయ్యి, ప్రతిదాని తర్వాత మళ్ళీ నీళ్ళతో "
                    "అభిషేకం చేయండి.",
                ),
                "om-namah-shivaya",
            ),
            step(
                t("Bilva archana", "बेलपत्र अर्पण", "బిల్వార్చన"),
                t(
                    "Apply vibhuti and sandal, then offer bilva leaves with the smooth side down, one with each "
                    "chant, along with white flowers.",
                    "भस्म और चंदन लगाएँ, फिर हर जप के साथ एक बेलपत्र (चिकनी सतह नीचे) और सफ़ेद फूल चढ़ाएँ।",
                    "విభూతి, గంధం పూసి, ప్రతి జపంతో ఒక మారేడు దళం (నునుపు వైపు కిందకు), తెల్లని పూలు సమర్పించండి.",
                ),
                "mahamrityunjaya-mantra",
            ),
            NAIVEDYAM,
            step(
                t("Aarti", "आरती", "హారతి"),
                t(
                    "Do the aarti with camphor and sing Shiva's praise.",
                    "कपूर से आरती करें और शिव की स्तुति गाएँ।",
                    "కర్పూర హారతి ఇచ్చి శివుని స్తుతి పాడండి.",
                ),
                "karpur-gauram",
            ),
            step(
                t("Stay awake", "जागरण", "జాగరణ"),
                t(
                    "Stay awake through the night with japa, bhajans or stories of Shiva, repeating the abhishekam in "
                    "each prahara if you can. Break the fast the next morning after bath and a short puja.",
                    "रात भर जप, भजन या शिव कथा के साथ जागें, हो सके तो हर प्रहर में अभिषेक दोहराएँ। अगली सुबह स्नान और छोटी "
                    "पूजा के बाद व्रत खोलें।",
                    "రాత్రంతా జపం, భజనలు, శివ కథలతో జాగరణ చేయండి; వీలైతే ప్రతి జాములో అభిషేకం చేయండి. మరుసటి ఉదయం స్నానం, "
                    "చిన్న పూజ తర్వాత ఉపవాసం విరమించండి.",
                ),
            ),
        ],
    },
    {
        "id": "ekadashi",
        "emoji": "🌿",
        "match": ["ekadashi", "nirjala-ekadashi", "devshayani-ekadashi", "dev-uthani-ekadashi"],
        "title": t("Ekadashi vrata", "एकादशी व्रत", "ఏకాదశి వ్రతం"),
        "summary": t(
            "A fast for Lord Vishnu on the eleventh lunar day, ended on Dwadashi morning.",
            "ग्यारहवीं तिथि पर भगवान विष्णु के लिए उपवास, जो द्वादशी की सुबह खोला जाता है।",
            "పదకొండో తిథి నాడు శ్రీమహావిష్ణువు కోసం ఉపవాసం, ద్వాదశి ఉదయం విరమిస్తారు.",
        ),
        "when": t(
            "Both Ekadashis of every lunar month, from sunrise to the parana time on Dwadashi.",
            "हर माह की दोनों एकादशियों पर, सूर्योदय से द्वादशी के पारण समय तक।",
            "ప్రతి నెలా రెండు ఏకాదశుల్లో, సూర్యోదయం నుంచి ద్వాదశి పారణ సమయం వరకు.",
        ),
        "samagri": [
            t("A picture of Lord Vishnu or Krishna", "भगवान विष्णु या कृष्ण का चित्र", "శ్రీమహావిష్ణువు లేదా కృష్ణుని పటం"),
            TULSI,
            FLOWERS,
            SANDAL,
            INCENSE,
            LAMP,
            CAMPHOR,
            WATER,
            MATCHES,
            t("Fruit and milk for the fast", "व्रत के लिए फल और दूध", "ఉపవాసానికి పండ్లు, పాలు"),
        ],
        "steps": [
            step(
                t("The day before", "एक दिन पहले", "ముందు రోజు"),
                t(
                    "On Dashami, eat a light, simple meal before sunset and pick the tulsi leaves you will need, since "
                    "tulsi is not picked on Ekadashi.",
                    "दशमी को सूर्यास्त से पहले हल्का सादा भोजन करें और ज़रूरी तुलसी दल तोड़ लें, क्योंकि एकादशी को तुलसी नहीं "
                    "तोड़ते।",
                    "దశమి నాడు సూర్యాస్తమయానికి ముందే తేలికైన సాదా భోజనం చేసి, కావలసిన తులసి దళాలు కోసి పెట్టుకోండి; "
                    "ఏకాదశి నాడు తులసి కోయరు.",
                ),
            ),
            step(
                t("Begin the fast", "व्रत आरंभ", "ఉపవాస ప్రారంభం"),
                t(
                    "After bath, take the vow before the Lord. Avoid rice and grains for the day; take only water, fruit "
                    "and milk, or keep a full fast if your health allows.",
                    "स्नान के बाद भगवान के सामने व्रत का संकल्प लें। दिन भर चावल और अनाज न लें; केवल जल, फल और दूध लें, या "
                    "स्वास्थ्य अनुमति दे तो पूर्ण उपवास रखें।",
                    "స్నానం తర్వాత స్వామి ముందు వ్రత సంకల్పం చేయండి. రోజంతా బియ్యం, ధాన్యాలు తీసుకోవద్దు; నీళ్ళు, పండ్లు, "
                    "పాలు మాత్రమే, లేదా ఆరోగ్యం అనుకూలిస్తే పూర్తి ఉపవాసం.",
                ),
            ),
            LIGHT,
            step(
                t("Worship Vishnu", "विष्णु पूजन", "విష్ణు పూజ"),
                t(
                    "Offer sandal, flowers and tulsi leaves to the Lord, chanting his name, and offer fruit as naivedyam.",
                    "भगवान को चंदन, फूल और तुलसी दल अर्पित करते हुए नाम जपें, और फल का भोग लगाएँ।",
                    "స్వామికి గంధం, పూలు, తులసి దళాలు సమర్పిస్తూ నామం జపించి, పండ్లు నైవేద్యంగా పెట్టండి.",
                ),
                "om-namo-bhagavate-vasudevaya",
            ),
            step(
                t("Spend the day in remembrance", "दिन भर स्मरण", "రోజంతా స్మరణ"),
                t(
                    "Read the Gita or the Vishnu Sahasranama, sing bhajans and keep the mind calm. Many stay awake in "
                    "the night.",
                    "गीता या विष्णु सहस्रनाम पढ़ें, भजन गाएँ और मन शांत रखें। कई लोग रात में जागरण करते हैं।",
                    "గీత లేదా విష్ణు సహస్రనామం చదవండి, భజనలు పాడండి, మనసు ప్రశాంతంగా ఉంచుకోండి. చాలా మంది రాత్రి జాగరణ "
                    "చేస్తారు.",
                ),
                "shantakaram-bhujagashayanam",
            ),
            AARTI,
            step(
                t("Break the fast (parana)", "पारण", "పారణ"),
                t(
                    "On Dwadashi, after bath and a short puja, break the fast within the parana window after sunrise, "
                    "ideally by first offering food to someone in need.",
                    "द्वादशी को स्नान और छोटी पूजा के बाद सूर्योदय के बाद के पारण समय में व्रत खोलें, हो सके तो पहले किसी "
                    "ज़रूरतमंद को भोजन देकर।",
                    "ద్వాదశి నాడు స్నానం, చిన్న పూజ తర్వాత సూర్యోదయం తర్వాతి పారణ సమయంలో ఉపవాసం విరమించండి; వీలైతే ముందుగా "
                    "అవసరమైన వారికి అన్నం పెట్టండి.",
                ),
            ),
        ],
    },
    {
        "id": "pradosham",
        "emoji": "🌗",
        "match": ["pradosh"],
        "title": t("Pradosham vrata", "प्रदोष व्रत", "ప్రదోష వ్రతం"),
        "summary": t(
            "Worship of Shiva and Nandi in the evening twilight of Trayodashi.",
            "त्रयोदशी की संध्या में शिव और नंदी की पूजा।",
            "త్రయోదశి సంధ్యా సమయంలో శివుడు, నందీశ్వరుల పూజ.",
        ),
        "when": t(
            "Both Trayodashis of every lunar month, about an hour and a half before and after sunset. Pradosham on "
            "a Monday or Saturday is held especially sacred.",
            "हर माह की दोनों त्रयोदशी पर, सूर्यास्त से लगभग डेढ़ घंटा पहले और बाद। सोमवार या शनिवार का प्रदोष विशेष "
            "पवित्र माना जाता है।",
            "ప్రతి నెలా రెండు త్రయోదశుల్లో, సూర్యాస్తమయానికి సుమారు గంటన్నర ముందు, తర్వాత. సోమవారం లేదా శనివారం "
            "వచ్చే ప్రదోషం మరింత పవిత్రం.",
        ),
        "samagri": [
            t("A Shiva linga or picture", "शिवलिंग या चित्र", "శివలింగం లేదా పటం"),
            t("Water and milk for abhishekam", "अभिषेक के लिए जल और दूध", "అభిషేకానికి నీళ్ళు, పాలు"),
            BILVA,
            t("Vibhuti (sacred ash)", "भस्म (विभूति)", "విభూతి"),
            SANDAL,
            FLOWERS,
            INCENSE,
            LAMP,
            CAMPHOR,
            BELL,
            NAIVEDYA,
            MATCHES,
        ],
        "steps": [
            step(
                t("Fast until evening", "शाम तक उपवास", "సాయంత్రం వరకు ఉపవాసం"),
                t(
                    "Keep a light fast through the day with fruit and milk, and bathe again before sunset.",
                    "दिन भर फल और दूध के साथ हल्का उपवास रखें और सूर्यास्त से पहले फिर स्नान करें।",
                    "పగలంతా పండ్లు, పాలతో తేలికపాటి ఉపవాసం ఉండి, సూర్యాస్తమయానికి ముందు మళ్ళీ స్నానం చేయండి.",
                ),
            ),
            LIGHT,
            GANESHA,
            step(
                t("Pray to Nandi", "नंदी वंदना", "నందీశ్వర ప్రార్థన"),
                t(
                    "At a temple, bow to Nandi first and look at the linga between his horns. At home, remember Nandi "
                    "before you begin.",
                    "मंदिर में पहले नंदी को प्रणाम करें और उनके सींगों के बीच से शिवलिंग के दर्शन करें। घर पर पूजा से पहले "
                    "नंदी का स्मरण करें।",
                    "ఆలయంలో ముందుగా నందికి నమస్కరించి, ఆయన కొమ్ముల మధ్య నుంచి శివలింగ దర్శనం చేయండి. ఇంట్లో పూజకు ముందు "
                    "నందిని తలచుకోండి.",
                ),
            ),
            step(
                t("Abhishekam and archana", "अभिषेक और अर्चना", "అభిషేకం, అర్చన"),
                t(
                    "In the twilight, bathe the linga with water and milk, apply vibhuti and sandal, and offer bilva "
                    "leaves and flowers.",
                    "संध्या समय शिवलिंग पर जल और दूध से अभिषेक करें, भस्म और चंदन लगाएँ, बेलपत्र और फूल चढ़ाएँ।",
                    "సంధ్యా సమయంలో లింగానికి నీళ్ళు, పాలతో అభిషేకం చేసి, విభూతి, గంధం పూసి, మారేడు దళాలు, పూలు సమర్పించండి.",
                ),
                "om-namah-shivaya",
            ),
            step(
                t("Chant", "जप", "జపం"),
                t(
                    "Chant Om Namah Shivaya 108 times, or the Mahamrityunjaya mantra.",
                    "ॐ नमः शिवाय 108 बार, या महामृत्युंजय मंत्र जपें।",
                    "ఓం నమః శివాయ 108 సార్లు, లేదా మహామృత్యుంజయ మంత్రం జపించండి.",
                ),
                "mahamrityunjaya-mantra",
            ),
            NAIVEDYAM,
            step(
                t("Aarti", "आरती", "హారతి"),
                t(
                    "Do the aarti with camphor and sing Shiva's praise.",
                    "कपूर से आरती करें और शिव की स्तुति गाएँ।",
                    "కర్పూర హారతి ఇచ్చి శివుని స్తుతి పాడండి.",
                ),
                "karpur-gauram",
            ),
            step(
                t("Break the fast", "व्रत खोलें", "ఉపవాసం విరమించండి"),
                t(
                    "After the puja, eat a simple meal with the prasad.",
                    "पूजा के बाद प्रसाद के साथ सादा भोजन करें।",
                    "పూజ తర్వాత ప్రసాదంతో సాదా భోజనం చేయండి.",
                ),
            ),
        ],
    },
]

# Telugu titles for the mantras the guides use; English and Hindi come from texts.py.
TITLES_TE = {
    "vakratunda-mahakaya": "వక్రతుండ మహాకాయ",
    "gayatri-mantra": "గాయత్రీ మంత్రం",
    "om-namo-bhagavate-vasudevaya": "ఓం నమో భగవతే వాసుదేవాయ",
    "shantakaram-bhujagashayanam": "శాంతాకారం భుజగశయనం",
    "om-shreem-mahalakshmyai-namah": "ఓం శ్రీం మహాలక్ష్మ్యై నమః",
    "sarva-mangala-mangalye": "సర్వమంగళ మాంగల్యే",
    "om-gan-ganapataye-namah": "ఓం గం గణపతయే నమః",
    "om-namah-shivaya": "ఓం నమః శివాయ",
    "mahamrityunjaya-mantra": "మహామృత్యుంజయ మంత్రం",
    "karpur-gauram": "కర్పూరగౌరం",
    "sarve-bhavantu-sukhinah": "సర్వే భవంతు సుఖినః",
}

# Hindi and Telugu meanings for the mantras the guides use; English comes from texts.py.
MEANINGS = {
    "vakratunda-mahakaya": (
        "हे वक्रतुंड, विशाल देह वाले, करोड़ों सूर्यों के समान तेजस्वी देव, मेरे सभी कार्य सदा निर्विघ्न करें।",
        "వంకర తొండం, పెద్ద శరీరం, కోటి సూర్యుల కాంతి గల దేవా, నా పనులన్నీ ఎల్లప్పుడూ విఘ్నం లేకుండా చేయి.",
    ),
    "gayatri-mantra": (
        "हम सृष्टिकर्ता सविता देव के तेज का ध्यान करते हैं; वह हमारी बुद्धि को प्रेरित करे।",
        "సృష్టికర్త అయిన సవితృ దేవుని తేజస్సును ధ్యానిస్తున్నాం; ఆయన మా బుద్ధిని ప్రేరేపించుగాక.",
    ),
    "om-namo-bhagavate-vasudevaya": (
        "भगवान वासुदेव को नमस्कार। बारह अक्षरों का मंत्र।",
        "భగవంతుడైన వాసుదేవునికి నమస్కారం. పన్నెండు అక్షరాల మంత్రం.",
    ),
    "shantakaram-bhujagashayanam": (
        "शांत स्वरूप, शेषनाग पर शयन करने वाले, कमलनाभ, विश्व के आधार, मेघ के समान श्याम, लक्ष्मीपति, कमलनयन, "
        "संसार के भय को हरने वाले विष्णु को मैं प्रणाम करता हूँ।",
        "ప్రశాంత రూపుడు, శేషశాయి, పద్మనాభుడు, విశ్వానికి ఆధారం, మేఘవర్ణుడు, లక్ష్మీపతి, కమలనయనుడు, భవభయాన్ని "
        "హరించే విష్ణువుకు నమస్కారం.",
    ),
    "om-shreem-mahalakshmyai-namah": (
        "महालक्ष्मी को नमस्कार; 'श्रीं' उनका समृद्धि का बीज मंत्र है।",
        "మహాలక్ష్మికి నమస్కారం; 'శ్రీం' ఆమె సమృద్ధి బీజాక్షరం.",
    ),
    "sarva-mangala-mangalye": (
        "हे नारायणी, सभी मंगलों में मंगलमयी, सब मनोरथ पूरे करने वाली, शरणदायिनी, त्रिनेत्री गौरी, आपको नमस्कार।",
        "సర్వ మంగళాలకు మంగళమైన, అన్ని కోరికలు తీర్చే, శరణునిచ్చే, ముక్కంటి గౌరీ, నారాయణీ, నీకు నమస్కారం.",
    ),
    "om-gan-ganapataye-namah": (
        "गणपति को नमस्कार; 'गं' उनका बीज मंत्र है।",
        "గణపతికి నమస్కారం; 'గం' ఆయన బీజాక్షరం.",
    ),
    "om-namah-shivaya": (
        "मंगलमय शिव को नमस्कार। पाँच अक्षरों का पंचाक्षरी मंत्र।",
        "మంగళకరుడైన శివునికి నమస్కారం. ఐదు అక్షరాల పంచాక్షరి మంత్రం.",
    ),
    "mahamrityunjaya-mantra": (
        "हम सुगंधित, पोषण करने वाले त्रिनेत्र शिव की उपासना करते हैं। जैसे पका खरबूजा बेल से छूटता है, वैसे हम मृत्यु से "
        "मुक्त हों, अमरत्व से नहीं।",
        "సుగంధభరితుడు, పోషకుడు అయిన ముక్కంటిని పూజిస్తున్నాం. పండిన దోసపండు తీగ నుంచి విడిపోయినట్లు మృత్యువు నుంచి "
        "విముక్తి కలుగుగాక, అమృతత్వం నుంచి కాదు.",
    ),
    "karpur-gauram": (
        "कपूर के समान गौर, करुणा के अवतार, संसार के सार, सर्पराज का हार पहने, सदा हृदय-कमल में भवानी सहित बसने वाले "
        "शिव को मैं नमन करता हूँ।",
        "కర్పూరం వలె తెల్లనివాడు, కరుణావతారుడు, సంసార సారం, నాగరాజును హారంగా ధరించినవాడు, హృదయ కమలంలో భవానీ "
        "సమేతంగా ఉండే శివునికి నమస్కారం.",
    ),
    "sarve-bhavantu-sukhinah": (
        "सब सुखी हों, सब निरोगी हों, सब शुभ देखें, कोई दुःखी न हो।",
        "అందరూ సుఖంగా ఉండాలి, అందరూ ఆరోగ్యంగా ఉండాలి, అందరూ మంచిని చూడాలి, ఎవరూ దుఃఖపడకూడదు.",
    ),
}


def main():
    tree = ast.parse(TEXTS.read_text())
    library = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") == "MANTRAS":
            for slug, _deity, title, title_hi, sanskrit, meaning in ast.literal_eval(node.value):
                library[slug] = (title, title_hi, sanskrit, meaning)
    used = sorted({s["mantra"] for g in GUIDES for s in g["steps"] if "mantra" in s})
    mantras = {}
    for slug in used:
        title, title_hi, sanskrit, meaning = library[slug]
        hi, te = MEANINGS[slug]
        mantras[slug] = {"title": t(title, title_hi, TITLES_TE[slug]), "sa": sanskrit, "meaning": t(meaning, hi, te)}
    OUT.write_text(
        json.dumps({"schema": 1, "version": 1, "guides": GUIDES, "mantras": mantras}, ensure_ascii=False, indent=1)
        + "\n"
    )
    n = sum(len(g["steps"]) for g in GUIDES)
    print(f"{len(GUIDES)} guides, {n} steps, {len(mantras)} mantras -> {OUT.relative_to(APP)}")


if __name__ == "__main__":
    main()
