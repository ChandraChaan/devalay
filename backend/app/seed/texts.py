"""Traditional devotional texts, all in the public domain.

The Devanagari texts are centuries-old compositions (Tulsidas, Surdas, Vedic and
Puranic hymns) or 19th-century aartis whose authors died long ago. Meanings and
notes are original summaries written for Devalay.
"""

DEITIES = [
    # slug, name, name_hi, colour, weekday (Mon=0), description
    ("shiva", "Shiva", "शिव", "#3949AB", 0, "Mahadev, the auspicious one: destroyer of ignorance, lord of yoga and compassion."),
    ("hanuman", "Hanuman", "हनुमान", "#E64A19", 1, "Bajrangbali, devoted servant of Shri Ram, giver of strength, courage and wisdom."),
    ("ganesha", "Ganesha", "गणेश", "#F57C00", 2, "Ganpati, remover of obstacles, worshipped first before every undertaking."),
    ("vishnu", "Vishnu", "विष्णु", "#1E88E5", 3, "Narayan, the preserver, who descends as avatars to protect dharma."),
    ("lakshmi", "Lakshmi", "लक्ष्मी", "#D81B60", 4, "Goddess of prosperity, beauty and good fortune, consort of Vishnu."),
    ("shani", "Shani Dev", "शनि देव", "#37474F", 5, "Lord of Saturday and karma, who rewards patience and honest effort."),
    ("surya", "Surya", "सूर्य", "#FFA000", 6, "The Sun, the visible god, source of light, health and the Gayatri Mantra."),
    ("rama", "Shri Ram", "श्री राम", "#2E7D32", None, "Maryada Purushottam, the ideal king and seventh avatar of Vishnu."),
    ("krishna", "Shri Krishna", "श्री कृष्ण", "#1565C0", None, "The eighth avatar, teacher of the Bhagavad Gita and the playful cowherd of Vrindavan."),
    ("radha-krishna", "Radha Krishna", "राधा कृष्ण", "#AD1457", None, "The divine couple, the highest expression of loving devotion."),
    ("durga", "Durga", "दुर्गा", "#C62828", None, "Mata Rani, the invincible mother who destroys evil and protects her children."),
    ("kali", "Kali", "काली", "#212121", None, "The fierce mother beyond time, who frees devotees from fear."),
    ("saraswati", "Saraswati", "सरस्वती", "#5E35B1", None, "Goddess of knowledge, music, speech and the arts."),
    ("general", "All Devotion", "सर्व भक्ति", "#6D4C41", None, "Prayers and mantras for every day."),
]

TEXTS = [
    {
        "slug": "hanuman-chalisa", "kind": "chalisa", "deity": "hanuman", "lang": "hi",
        "title": "Hanuman Chalisa", "title_hi": "हनुमान चालीसा", "attribution": "Goswami Tulsidas (16th century)",
        "meaning": "Forty verses by Tulsidas praising Hanuman's strength, wisdom and devotion to Shri Ram. It recalls his "
                   "deeds in the Ramayan, from finding Sita in Lanka to bringing the Sanjeevani herb, and ends with a "
                   "prayer that Hanuman dwell in the devotee's heart along with Ram, Lakshman and Sita.",
        "benefits": "Traditionally recited on Tuesdays and Saturdays for courage, protection and peace of mind.",
        "body": """॥ दोहा ॥
श्रीगुरु चरन सरोज रज, निज मनु मुकुरु सुधारि।
बरनउँ रघुबर बिमल जसु, जो दायकु फल चारि॥
बुद्धिहीन तनु जानिके, सुमिरौं पवन-कुमार।
बल बुद्धि बिद्या देहु मोहिं, हरहु कलेस बिकार॥

॥ चौपाई ॥
जय हनुमान ज्ञान गुन सागर। जय कपीस तिहुँ लोक उजागर॥
राम दूत अतुलित बल धामा। अंजनि-पुत्र पवनसुत नामा॥
महाबीर बिक्रम बजरंगी। कुमति निवार सुमति के संगी॥
कंचन बरन बिराज सुबेसा। कानन कुंडल कुंचित केसा॥
हाथ बज्र औ ध्वजा बिराजै। काँधे मूँज जनेऊ साजै॥
संकर सुवन केसरीनंदन। तेज प्रताप महा जग बंदन॥
बिद्यावान गुनी अति चातुर। राम काज करिबे को आतुर॥
प्रभु चरित्र सुनिबे को रसिया। राम लखन सीता मन बसिया॥
सूक्ष्म रूप धरि सियहिं दिखावा। बिकट रूप धरि लंक जरावा॥
भीम रूप धरि असुर सँहारे। रामचंद्र के काज सँवारे॥
लाय सजीवन लखन जियाये। श्रीरघुबीर हरषि उर लाये॥
रघुपति कीन्ही बहुत बड़ाई। तुम मम प्रिय भरतहि सम भाई॥
सहस बदन तुम्हरो जस गावैं। अस कहि श्रीपति कंठ लगावैं॥
सनकादिक ब्रह्मादि मुनीसा। नारद सारद सहित अहीसा॥
जम कुबेर दिगपाल जहाँ ते। कबि कोबिद कहि सके कहाँ ते॥
तुम उपकार सुग्रीवहिं कीन्हा। राम मिलाय राज पद दीन्हा॥
तुम्हरो मंत्र बिभीषन माना। लंकेस्वर भए सब जग जाना॥
जुग सहस्र जोजन पर भानू। लील्यो ताहि मधुर फल जानू॥
प्रभु मुद्रिका मेलि मुख माहीं। जलधि लाँघि गये अचरज नाहीं॥
दुर्गम काज जगत के जेते। सुगम अनुग्रह तुम्हरे तेते॥
राम दुआरे तुम रखवारे। होत न आज्ञा बिनु पैसारे॥
सब सुख लहै तुम्हारी सरना। तुम रच्छक काहू को डर ना॥
आपन तेज सम्हारो आपै। तीनों लोक हाँक तें काँपै॥
भूत पिसाच निकट नहिं आवै। महाबीर जब नाम सुनावै॥
नासै रोग हरै सब पीरा। जपत निरंतर हनुमत बीरा॥
संकट तें हनुमान छुड़ावै। मन क्रम बचन ध्यान जो लावै॥
सब पर राम तपस्वी राजा। तिन के काज सकल तुम साजा॥
और मनोरथ जो कोई लावै। सोइ अमित जीवन फल पावै॥
चारों जुग परताप तुम्हारा। है परसिद्ध जगत उजियारा॥
साधु संत के तुम रखवारे। असुर निकंदन राम दुलारे॥
अष्ट सिद्धि नौ निधि के दाता। अस बर दीन जानकी माता॥
राम रसायन तुम्हरे पासा। सदा रहो रघुपति के दासा॥
तुम्हरे भजन राम को पावै। जनम जनम के दुख बिसरावै॥
अंत काल रघुबर पुर जाई। जहाँ जन्म हरि-भक्त कहाई॥
और देवता चित्त न धरई। हनुमत सेइ सर्ब सुख करई॥
संकट कटै मिटै सब पीरा। जो सुमिरै हनुमत बलबीरा॥
जै जै जै हनुमान गोसाईं। कृपा करहु गुरुदेव की नाईं॥
जो सत बार पाठ कर कोई। छूटहि बंदि महा सुख होई॥
जो यह पढ़ै हनुमान चालीसा। होय सिद्धि साखी गौरीसा॥
तुलसीदास सदा हरि चेरा। कीजै नाथ हृदय मँह डेरा॥

॥ दोहा ॥
पवनतनय संकट हरन, मंगल मूरति रूप।
राम लखन सीता सहित, हृदय बसहु सुर भूप॥""",
    },
    {
        "slug": "om-jai-jagdish-hare", "kind": "aarti", "deity": "vishnu", "lang": "hi",
        "title": "Om Jai Jagdish Hare", "title_hi": "ॐ जय जगदीश हरे",
        "attribution": "Pandit Shardha Ram Phillauri (1870s)",
        "meaning": "The most widely sung aarti, addressed to Vishnu as Lord of the universe. The devotee calls God mother, "
                   "father and only refuge, asks for the removal of sorrow and faults, and offers everything back: "
                   "'what is Yours I offer to You.'",
        "benefits": "Sung at the close of puja in homes and temples, especially on Thursdays.",
        "body": """ॐ जय जगदीश हरे, स्वामी जय जगदीश हरे।
भक्त जनों के संकट, दास जनों के संकट, क्षण में दूर करे॥
॥ ॐ जय जगदीश हरे ॥

जो ध्यावे फल पावे, दुःख बिनसे मन का, स्वामी दुःख बिनसे मन का।
सुख सम्पति घर आवे, कष्ट मिटे तन का॥

मात पिता तुम मेरे, शरण गहूँ मैं किसकी, स्वामी शरण गहूँ मैं किसकी।
तुम बिन और न दूजा, आस करूँ मैं जिसकी॥

तुम पूरण परमात्मा, तुम अन्तर्यामी, स्वामी तुम अन्तर्यामी।
पारब्रह्म परमेश्वर, तुम सब के स्वामी॥

तुम करुणा के सागर, तुम पालनकर्ता, स्वामी तुम पालनकर्ता।
मैं मूरख फलकामी, मैं सेवक तुम स्वामी, कृपा करो भर्ता॥

तुम हो एक अगोचर, सबके प्राणपति, स्वामी सबके प्राणपति।
किस विधि मिलूँ दयामय, तुमको मैं कुमति॥

दीन बन्धु दुःख हर्ता, ठाकुर तुम मेरे, स्वामी रक्षक तुम मेरे।
अपने हाथ उठाओ, अपने शरण लगाओ, द्वार पड़ा तेरे॥

विषय विकार मिटाओ, पाप हरो देवा, स्वामी पाप हरो देवा।
श्रद्धा भक्ति बढ़ाओ, सन्तन की सेवा॥

तन मन धन सब कुछ है तेरा, स्वामी सब कुछ है तेरा।
तेरा तुझको अर्पण, क्या लागे मेरा॥
॥ ॐ जय जगदीश हरे ॥""",
    },
    {
        "slug": "jai-ganesh-deva", "kind": "aarti", "deity": "ganesha", "lang": "hi",
        "title": "Jai Ganesh Deva", "title_hi": "जय गणेश देवा", "attribution": "Traditional, attributed to Surdas",
        "meaning": "Aarti of Ganesha, son of Parvati and Mahadev: the one-tusked, four-armed lord who rides a mouse, "
                   "loves laddoos, and blesses the blind with sight and the poor with plenty.",
        "benefits": "Sung first in every puja and throughout Ganesh Chaturthi.",
        "body": """जय गणेश, जय गणेश, जय गणेश देवा।
माता जाकी पार्वती, पिता महादेवा॥

एक दंत दयावंत, चार भुजा धारी।
माथे सिंदूर सोहे, मूसे की सवारी॥

पान चढ़े, फूल चढ़े, और चढ़े मेवा।
लड्डुअन का भोग लगे, संत करें सेवा॥

अंधन को आँख देत, कोढ़िन को काया।
बाँझन को पुत्र देत, निर्धन को माया॥

'सूर' श्याम शरण आए, सफल कीजे सेवा।
माता जाकी पार्वती, पिता महादेवा॥

दीनन की लाज रखो, शंभु सुतकारी।
कामना को पूर्ण करो, जाऊँ बलिहारी॥
॥ जय गणेश देवा ॥""",
    },
    {
        "slug": "om-jai-shiv-omkara", "kind": "aarti", "deity": "shiva", "lang": "hi",
        "title": "Om Jai Shiv Omkara", "title_hi": "ॐ जय शिव ओंकारा", "attribution": "Traditional, attributed to Swami Shivanand",
        "meaning": "Aarti of Shiva as Omkara, in whom Brahma, Vishnu and Shiva are one. It describes his many forms, "
                   "garlands, ornaments and companions, and promises happiness to whoever sings it.",
        "benefits": "Sung on Mondays, Pradosh and Maha Shivratri.",
        "body": """ॐ जय शिव ओंकारा, स्वामी जय शिव ओंकारा।
ब्रह्मा, विष्णु, सदाशिव, अर्द्धांगी धारा॥
॥ ॐ जय शिव ओंकारा ॥

एकानन चतुरानन पंचानन राजे।
हंसासन गरूड़ासन वृषवाहन साजे॥

दो भुज चार चतुर्भुज दसभुज अति सोहे।
त्रिगुण रूप निरखते त्रिभुवन जन मोहे॥

अक्षमाला वनमाला मुण्डमाला धारी।
चंदन मृगमद सोहै, भाले शशिधारी॥

श्वेताम्बर पीताम्बर बाघम्बर अंगे।
सनकादिक गरुणादिक भूतादिक संगे॥

कर के मध्य कमण्डल चक्र त्रिशूलधारी।
सुखकारी दुखहारी जगपालन कारी॥

ब्रह्मा विष्णु सदाशिव जानत अविवेका।
प्रणवाक्षर में शोभित ये तीनों एका॥

त्रिगुणस्वामी जी की आरति जो कोइ नर गावे।
कहत शिवानंद स्वामी सुख संपति पावे॥
॥ ॐ जय शिव ओंकारा ॥""",
    },
    {
        "slug": "aarti-kunj-bihari-ki", "kind": "aarti", "deity": "krishna", "lang": "hi",
        "title": "Aarti Kunj Bihari Ki", "title_hi": "आरती कुंजबिहारी की", "attribution": "Traditional (Braj)",
        "meaning": "Aarti of Krishna, who roams the groves of Vrindavan: his garland, flute, peacock crown and dark "
                   "radiance beside Radha, the Ganga flowing from his feet, and the flute that frees devotees from bondage.",
        "benefits": "Sung on Janmashtami and in daily Krishna worship.",
        "body": """आरती कुंजबिहारी की, श्री गिरिधर कृष्ण मुरारी की॥

गले में बैजंती माला, बजावै मुरली मधुर बाला।
श्रवण में कुण्डल झलकाला, नंद के आनंद नंदलाला।
गगन सम अंग कांति काली, राधिका चमक रही आली।
लतन में ठाढ़े बनमाली, भ्रमर सी अलक, कस्तूरी तिलक, चंद्र सी झलक,
ललित छवि श्यामा प्यारी की॥ श्री गिरिधर कृष्ण मुरारी की॥

कनकमय मोर मुकुट बिलसै, देवता दरसन को तरसैं।
गगन सों सुमन रासि बरसै, बजे मुरचंग, मधुर मिरदंग, ग्वालिन संग,
अतुल रति गोप कुमारी की॥ श्री गिरिधर कृष्ण मुरारी की॥

जहाँ ते प्रकट भई गंगा, सकल मन हारिणि श्री गंगा।
स्मरन ते होत मोह भंगा, बसी शिव सीस, जटा के बीच, हरै अघ कीच,
चरन छवि श्रीबनवारी की॥ श्री गिरिधर कृष्ण मुरारी की॥

चमकती उज्ज्वल तट रेनू, बज रही वृंदावन बेनू।
चहुँ दिसि गोपि ग्वाल धेनू, हँसत मृदु मंद, चाँदनी चंद, कटत भव फंद,
टेर सुन दीन दुखारी की॥ श्री गिरिधर कृष्ण मुरारी की॥

आरती कुंजबिहारी की, श्री गिरिधर कृष्ण मुरारी की॥""",
    },
    {
        "slug": "aarti-hanuman-lala-ki", "kind": "aarti", "deity": "hanuman", "lang": "hi",
        "title": "Aarti Kije Hanuman Lala Ki", "title_hi": "आरती कीजै हनुमान लला की", "attribution": "Traditional",
        "meaning": "Aarti of Hanuman, whose strength makes mountains tremble: he burnt Lanka, brought news of Sita, revived "
                   "Lakshman with the Sanjeevani herb and freed Ram and Lakshman from Ahiravan in the netherworld.",
        "benefits": "Sung on Tuesdays, Saturdays and Hanuman Jayanti, often after the Hanuman Chalisa.",
        "body": """आरती कीजै हनुमान लला की। दुष्ट दलन रघुनाथ कला की॥

जाके बल से गिरिवर काँपे। रोग दोष जाके निकट न झाँके॥
अंजनि पुत्र महा बलदाई। संतन के प्रभु सदा सहाई॥
दे बीरा रघुनाथ पठाए। लंका जारि सिया सुधि लाए॥
लंका सो कोट समुद्र सी खाई। जात पवनसुत बार न लाई॥
लंका जारि असुर संहारे। सियारामजी के काज सँवारे॥
लक्ष्मण मूर्छित पड़े सकारे। आनि सजीवन प्रान उबारे॥
पैठि पाताल तोरि जम-कारे। अहिरावण की भुजा उखारे॥
बाएँ भुजा असुरदल मारे। दाहिने भुजा संतजन तारे॥
सुर नर मुनि आरती उतारें। जय जय जय हनुमान उचारें॥
कंचन थार कपूर लौ छाई। आरती करत अंजना माई॥
जो हनुमानजी की आरती गावे। बसि बैकुंठ परम पद पावे॥

आरती कीजै हनुमान लला की। दुष्ट दलन रघुनाथ कला की॥""",
    },
    {
        "slug": "jai-ambe-gauri", "kind": "aarti", "deity": "durga", "lang": "hi",
        "title": "Jai Ambe Gauri", "title_hi": "जय अम्बे गौरी", "attribution": "Traditional, attributed to Swami Shivanand",
        "meaning": "Aarti of Maa Durga, adorned with sindoor and red garlands, riding a lion with sword in hand. It recalls "
                   "her victories over Shumbha, Nishumbha, Mahishasur, Chanda, Munda and Raktabeej, and praises her as "
                   "mother and sustainer of the world.",
        "benefits": "Sung every evening of Navratri and on Fridays.",
        "body": """जय अम्बे गौरी, मैया जय श्यामा गौरी।
तुमको निशदिन ध्यावत, हरि ब्रह्मा शिवरी॥
॥ जय अम्बे गौरी ॥

माँग सिंदूर विराजत, टीको मृगमद को।
उज्ज्वल से दोउ नैना, चंद्रवदन नीको॥

कनक समान कलेवर, रक्ताम्बर राजै।
रक्तपुष्प गल माला, कंठन पर साजै॥

केहरि वाहन राजत, खड्ग खप्पर धारी।
सुर-नर-मुनिजन सेवत, तिनके दुखहारी॥

कानन कुण्डल शोभित, नासाग्रे मोती।
कोटिक चंद्र दिवाकर, सम राजत ज्योती॥

शुंभ-निशुंभ बिदारे, महिषासुर घाती।
धूम्र विलोचन नैना, निशदिन मदमाती॥

चण्ड-मुण्ड संहारे, शोणित बीज हरे।
मधु-कैटभ दोउ मारे, सुर भयहीन करे॥

ब्रह्माणी, रूद्राणी, तुम कमला रानी।
आगम निगम बखानी, तुम शिव पटरानी॥

चौंसठ योगिनी गावत, नृत्य करत भैरों।
बाजत ताल मृदंगा, अरू बाजत डमरू॥

तुम ही जग की माता, तुम ही हो भरता।
भक्तन की दुख हरता, सुख संपति करता॥

भुजा चार अति शोभित, वर मुद्रा धारी।
मनवांछित फल पावत, सेवत नर नारी॥

कंचन थाल विराजत, अगर कपूर बाती।
श्रीमालकेतु में राजत, कोटि रतन ज्योती॥

श्री अंबेजी की आरति, जो कोइ नर गावे।
कहत शिवानंद स्वामी, सुख-संपति पावे॥
॥ जय अम्बे गौरी ॥""",
    },
    {
        "slug": "om-jai-lakshmi-mata", "kind": "aarti", "deity": "lakshmi", "lang": "hi",
        "title": "Om Jai Lakshmi Mata", "title_hi": "ॐ जय लक्ष्मी माता", "attribution": "Traditional",
        "meaning": "Aarti of Maa Lakshmi, worshipped by Shiva, Vishnu and Brahma, born of the ocean of milk. Wherever she "
                   "dwells, virtue, plenty and fearlessness follow.",
        "benefits": "Sung on Fridays and during Diwali Lakshmi Puja.",
        "body": """ॐ जय लक्ष्मी माता, मैया जय लक्ष्मी माता।
तुमको निशदिन सेवत, हर विष्णु विधाता॥
॥ ॐ जय लक्ष्मी माता ॥

उमा रमा ब्रह्माणी, तुम ही जग-माता।
सूर्य चन्द्रमा ध्यावत, नारद ऋषि गाता॥

दुर्गा रूप निरंजनि, सुख सम्पत्ति दाता।
जो कोई तुमको ध्यावत, ऋद्धि-सिद्धि धन पाता॥

तुम पाताल-निवासिनि, तुम ही शुभदाता।
कर्म-प्रभाव-प्रकाशिनी, भवनिधि की त्राता॥

जिस घर में तुम रहतीं, सब सद्गुण आता।
सब सम्भव हो जाता, मन नहीं घबराता॥

तुम बिन यज्ञ न होते, वस्त्र न कोई पाता।
खान-पान का वैभव, सब तुमसे आता॥

शुभ-गुण मन्दिर सुन्दर, क्षीरोदधि-जाता।
रत्न चतुर्दश तुम बिन, कोई नहीं पाता॥

महालक्ष्मीजी की आरती, जो कोई जन गाता।
उर आनन्द समाता, पाप उतर जाता॥
॥ ॐ जय लक्ष्मी माता ॥""",
    },
    {
        "slug": "shri-ramchandra-kripalu", "kind": "stuti", "deity": "rama", "lang": "hi",
        "title": "Shri Ramchandra Kripalu", "title_hi": "श्री रामचन्द्र कृपालु भजु मन",
        "attribution": "Goswami Tulsidas, Vinay Patrika (16th century)",
        "meaning": "Tulsidas urges the mind to worship compassionate Ram, who removes the fear of worldly existence. He "
                   "describes Ram's lotus eyes, cloud-dark beauty and yellow garments, and asks Ram to dwell in his heart "
                   "and destroy desire and other inner enemies.",
        "benefits": "Sung as Ram stuti on Ram Navami and in evening prayers.",
        "body": """श्री रामचन्द्र कृपालु भजु मन हरण भवभय दारुणं।
नव कंज लोचन कंज मुख कर कंज पद कंजारुणं॥

कन्दर्प अगणित अमित छवि नव नील नीरद सुन्दरं।
पट पीत मानहुँ तड़ित रुचि शुचि नौमि जनक सुतावरं॥

भजु दीनबन्धु दिनेश दानव दैत्य वंश निकन्दनं।
रघुनन्द आनन्द कन्द कोशल चन्द दशरथ नन्दनं॥

सिर मुकुट कुण्डल तिलक चारु उदारु अंग विभूषणं।
आजानु भुज शर चाप धर संग्राम जित खरदूषणं॥

इति वदति तुलसीदास शंकर शेष मुनि मन रंजनं।
मम हृदय कंज निवास कुरु कामादि खल दल गंजनं॥""",
    },
    {
        "slug": "ya-devi-sarvabhuteshu", "kind": "stotra", "deity": "durga", "lang": "sa",
        "title": "Ya Devi Sarvabhuteshu", "title_hi": "या देवी सर्वभूतेषु", "attribution": "Devi Mahatmya (Markandeya Purana)",
        "meaning": "Salutations, again and again, to the Goddess who dwells in all beings as power, as mother, as "
                   "intelligence, as prosperity and as peace.",
        "benefits": "Chanted during Navratri and Durga Puja.",
        "body": """या देवी सर्वभूतेषु शक्तिरूपेण संस्थिता।
नमस्तस्यै नमस्तस्यै नमस्तस्यै नमो नमः॥

या देवी सर्वभूतेषु मातृरूपेण संस्थिता।
नमस्तस्यै नमस्तस्यै नमस्तस्यै नमो नमः॥

या देवी सर्वभूतेषु बुद्धिरूपेण संस्थिता।
नमस्तस्यै नमस्तस्यै नमस्तस्यै नमो नमः॥

या देवी सर्वभूतेषु लक्ष्मीरूपेण संस्थिता।
नमस्तस्यै नमस्तस्यै नमस्तस्यै नमो नमः॥

या देवी सर्वभूतेषु शान्तिरूपेण संस्थिता।
नमस्तस्यै नमस्तस्यै नमस्तस्यै नमो नमः॥""",
    },
    {
        "slug": "saraswati-vandana", "kind": "stotra", "deity": "saraswati", "lang": "sa",
        "title": "Saraswati Vandana", "title_hi": "सरस्वती वंदना", "attribution": "Traditional Sanskrit prayer",
        "meaning": "May Goddess Saraswati, white as jasmine, the moon and snow, clad in white, holding the veena and seated "
                   "on a white lotus, ever worshipped by Brahma, Vishnu and Shiva, protect me and remove all dullness.",
        "benefits": "Recited before study and on Vasant Panchami.",
        "body": """या कुन्देन्दुतुषारहारधवला या शुभ्रवस्त्रावृता।
या वीणावरदण्डमण्डितकरा या श्वेतपद्मासना॥
या ब्रह्माच्युतशङ्करप्रभृतिभिर्देवैः सदा वन्दिता।
सा मां पातु सरस्वती भगवती निःशेषजाड्यापहा॥""",
    },
]

# Short mantras: (slug, deity, title, title_hi, sanskrit, meaning)
MANTRAS = [
    ("gayatri-mantra", "surya", "Gayatri Mantra", "गायत्री मंत्र",
     "ॐ भूर्भुवः स्वः।\nतत्सवितुर्वरेण्यं।\nभर्गो देवस्य धीमहि।\nधियो यो नः प्रचोदयात्॥",
     "We meditate on the radiant light of the divine Sun, the creator; may it inspire and guide our intellect. (Rigveda 3.62.10)"),
    ("mahamrityunjaya-mantra", "shiva", "Mahamrityunjaya Mantra", "महामृत्युंजय मंत्र",
     "ॐ त्र्यम्बकं यजामहे सुगन्धिं पुष्टिवर्धनम्।\nउर्वारुकमिव बन्धनान्मृत्योर्मुक्षीय माऽमृतात्॥",
     "We worship the three-eyed Lord, fragrant and nourishing. As a ripe cucumber is freed from its vine, may we be freed from death, not from immortality. (Rigveda 7.59.12)"),
    ("om-namah-shivaya", "shiva", "Om Namah Shivaya", "ॐ नमः शिवाय", "ॐ नमः शिवाय",
     "Salutations to Shiva, the auspicious one. The five-syllable Panchakshari mantra."),
    ("karpur-gauram", "shiva", "Karpur Gauram", "कर्पूरगौरं",
     "कर्पूरगौरं करुणावतारं संसारसारं भुजगेन्द्रहारम्।\nसदा वसन्तं हृदयारविन्दे भवं भवानीसहितं नमामि॥",
     "I bow to Shiva, white as camphor, compassion incarnate, essence of the world, wearing the serpent king as a garland, ever dwelling in the lotus of the heart with Bhavani."),
    ("hare-krishna-mahamantra", "krishna", "Hare Krishna Mahamantra", "हरे कृष्ण महामंत्र",
     "हरे कृष्ण हरे कृष्ण कृष्ण कृष्ण हरे हरे।\nहरे राम हरे राम राम राम हरे हरे॥",
     "The great mantra of the holy names, calling on Hari, Krishna and Ram. (Kali-Santarana Upanishad)"),
    ("krishna-vande-jagadgurum", "krishna", "Krishnam Vande Jagadgurum", "कृष्णं वन्दे जगद्गुरुम्",
     "वसुदेवसुतं देवं कंसचाणूरमर्दनम्।\nदेवकीपरमानन्दं कृष्णं वन्दे जगद्गुरुम्॥",
     "I bow to Krishna, son of Vasudeva, destroyer of Kamsa and Chanura, supreme joy of Devaki, teacher of the world."),
    ("vakratunda-mahakaya", "ganesha", "Vakratunda Mahakaya", "वक्रतुण्ड महाकाय",
     "वक्रतुण्ड महाकाय सूर्यकोटि समप्रभ।\nनिर्विघ्नं कुरु मे देव सर्वकार्येषु सर्वदा॥",
     "O Lord with the curved trunk and mighty body, radiant as a million suns, remove the obstacles from all my work, always."),
    ("om-gan-ganapataye-namah", "ganesha", "Om Gan Ganapataye Namah", "ॐ गं गणपतये नमः", "ॐ गं गणपतये नमः",
     "Salutations to Ganapati; 'Gam' is his seed syllable."),
    ("manojavam-marutatulyavegam", "hanuman", "Manojavam Marutatulyavegam", "मनोजवं मारुततुल्यवेगम्",
     "मनोजवं मारुततुल्यवेगं जितेन्द्रियं बुद्धिमतां वरिष्ठम्।\nवातात्मजं वानरयूथमुख्यं श्रीरामदूतं शरणं प्रपद्ये॥",
     "I take refuge in Hanuman, swift as the mind and the wind, master of the senses, foremost of the wise, son of the wind god, leader of the vanaras, messenger of Shri Ram."),
    ("shri-ram-jai-ram", "rama", "Shri Ram Jai Ram", "श्री राम जय राम", "श्री राम जय राम जय जय राम",
     "The thirteen-syllable Ram Taraka mantra, popularised by Samarth Ramdas."),
    ("ramaya-ramabhadraya", "rama", "Ramaya Ramabhadraya", "रामाय रामभद्राय",
     "रामाय रामभद्राय रामचन्द्राय वेधसे।\nरघुनाथाय नाथाय सीतायाः पतये नमः॥",
     "Salutations to Ram, the auspicious Ramabhadra, the moon-like Ramachandra, lord of the Raghus, husband of Sita."),
    ("sarva-mangala-mangalye", "durga", "Sarva Mangala Mangalye", "सर्वमङ्गलमाङ्गल्ये",
     "सर्वमङ्गलमाङ्गल्ये शिवे सर्वार्थसाधिके।\nशरण्ये त्र्यम्बके गौरि नारायणि नमोऽस्तु ते॥",
     "Salutations to you, Narayani: auspiciousness of all that is auspicious, who fulfils every aim, the refuge, three-eyed Gauri. (Devi Mahatmya)"),
    ("om-dum-durgayai-namah", "durga", "Om Dum Durgayai Namah", "ॐ दुं दुर्गायै नमः", "ॐ दुं दुर्गायै नमः",
     "Salutations to Durga; 'Dum' is her seed syllable."),
    ("om-shreem-mahalakshmyai-namah", "lakshmi", "Om Shreem Mahalakshmyai Namah", "ॐ श्रीं महालक्ष्म्यै नमः",
     "ॐ श्रीं महालक्ष्म्यै नमः", "Salutations to Mahalakshmi; 'Shreem' is her seed syllable of abundance."),
    ("shantakaram-bhujagashayanam", "vishnu", "Shantakaram Bhujagashayanam", "शान्ताकारं भुजगशयनं",
     "शान्ताकारं भुजगशयनं पद्मनाभं सुरेशं\nविश्वाधारं गगनसदृशं मेघवर्णं शुभाङ्गम्।\nलक्ष्मीकान्तं कमलनयनं योगिभिर्ध्यानगम्यं\nवन्दे विष्णुं भवभयहरं सर्वलोकैकनाथम्॥",
     "I bow to Vishnu: peaceful, resting on the serpent, lotus-naveled, lord of the gods, support of the universe, vast as the sky, dark as a rain cloud, beloved of Lakshmi, reached by yogis in meditation, remover of the fear of worldly existence."),
    ("om-namo-bhagavate-vasudevaya", "vishnu", "Om Namo Bhagavate Vasudevaya", "ॐ नमो भगवते वासुदेवाय",
     "ॐ नमो भगवते वासुदेवाय", "The twelve-syllable mantra of salutation to Lord Vasudeva."),
    ("shani-mantra", "shani", "Shani Mantra", "शनि मंत्र",
     "नीलाञ्जनसमाभासं रविपुत्रं यमाग्रजम्।\nछायामार्तण्डसम्भूतं तं नमामि शनैश्चरम्॥",
     "I bow to Shani, dark as blue collyrium, son of the Sun and Chhaya, elder brother of Yama, the slow-moving one."),
    ("om-ghrini-suryaya-namah", "surya", "Om Ghrini Suryaya Namah", "ॐ घृणि सूर्याय नमः", "ॐ घृणि सूर्याय नमः",
     "Salutations to Surya, the radiant one."),
    ("guru-brahma", "general", "Guru Brahma Guru Vishnu", "गुरुर्ब्रह्मा गुरुर्विष्णुः",
     "गुरुर्ब्रह्मा गुरुर्विष्णुः गुरुर्देवो महेश्वरः।\nगुरुः साक्षात् परब्रह्म तस्मै श्री गुरवे नमः॥",
     "The Guru is Brahma, Vishnu and Maheshwara; the Guru is the supreme Brahman itself. Salutations to that Guru."),
    ("asato-ma-sadgamaya", "general", "Asato Ma Sadgamaya", "असतो मा सद्गमय",
     "ॐ असतो मा सद्गमय।\nतमसो मा ज्योतिर्गमय।\nमृत्योर्मा अमृतं गमय।\nॐ शान्तिः शान्तिः शान्तिः॥",
     "Lead me from the unreal to the real, from darkness to light, from death to immortality. Om, peace, peace, peace. (Brihadaranyaka Upanishad 1.3.28)"),
    ("sarve-bhavantu-sukhinah", "general", "Sarve Bhavantu Sukhinah", "सर्वे भवन्तु सुखिनः",
     "सर्वे भवन्तु सुखिनः सर्वे सन्तु निरामयाः।\nसर्वे भद्राणि पश्यन्तु मा कश्चिद्दुःखभाग्भवेत्॥",
     "May all be happy, may all be free from illness, may all see what is good, may no one suffer."),
    ("om-saha-navavatu", "general", "Om Saha Navavatu", "ॐ सह नाववतु",
     "ॐ सह नाववतु। सह नौ भुनक्तु। सह वीर्यं करवावहै।\nतेजस्वि नावधीतमस्तु मा विद्विषावहै॥\nॐ शान्तिः शान्तिः शान्तिः॥",
     "May we be protected together, nourished together, work together with vigour; may our study be illuminating; may we not quarrel. (Katha and Taittiriya Upanishads)"),
    ("purnamadah-purnamidam", "general", "Purnamadah Purnamidam", "ॐ पूर्णमदः पूर्णमिदं",
     "ॐ पूर्णमदः पूर्णमिदं पूर्णात्पूर्णमुदच्यते।\nपूर्णस्य पूर्णमादाय पूर्णमेवावशिष्यते॥\nॐ शान्तिः शान्तिः शान्तिः॥",
     "That is whole, this is whole; from the whole the whole arises. Taking the whole from the whole, the whole remains. (Isha Upanishad)"),
    ("om-aim-saraswatyai-namah", "saraswati", "Om Aim Saraswatyai Namah", "ॐ ऐं सरस्वत्यै नमः", "ॐ ऐं सरस्वत्यै नमः",
     "Salutations to Saraswati; 'Aim' is her seed syllable of learning."),
    ("om-kreem-kalikayai-namah", "kali", "Om Kreem Kalikayai Namah", "ॐ क्रीं कालिकायै नमः", "ॐ क्रीं कालिकायै नमः",
     "Salutations to Maa Kali; 'Kreem' is her seed syllable."),
    ("radhe-radhe", "radha-krishna", "Radhe Krishna Jap", "राधे कृष्ण जाप",
     "श्री राधे कृष्णा, राधे कृष्णा, कृष्णा कृष्णा राधे राधे।\nश्री राधे श्यामा, राधे श्यामा, श्यामा श्यामा राधे राधे॥",
     "A simple chant of the divine names of Radha and Krishna, popular in Braj."),
]
