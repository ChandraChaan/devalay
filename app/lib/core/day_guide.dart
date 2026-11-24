import 'i18n.dart';

/// The four directions Disha Shool names.
enum Direction { east, west, north, south }

String directionLabel(String lang, Direction d) => switch (d) {
  Direction.east => t3(lang, 'East', 'पूर्व', 'తూర్పు'),
  Direction.west => t3(lang, 'West', 'पश्चिम', 'పడమర'),
  Direction.north => t3(lang, 'North', 'उत्तर', 'ఉత్తరం'),
  Direction.south => t3(lang, 'South', 'दक्षिण', 'దక్షిణం'),
};

/// Disha Shool: the direction in which a journey should not be started on each weekday
/// ([DateTime.weekday], Monday = 1). Monday and Saturday east, Tuesday and Wednesday north,
/// Thursday south, Friday and Sunday west, as most North and South Indian panchangs give it.
Direction dishaShool(int weekday) => switch (weekday) {
  DateTime.monday || DateTime.saturday => Direction.east,
  DateTime.tuesday || DateTime.wednesday => Direction.north,
  DateTime.thursday => Direction.south,
  _ => Direction.west,
};

/// The traditional remedy when a journey that way cannot be put off: something to eat or do
/// before leaving home.
String dishaShoolRemedy(String lang, int weekday) => switch (weekday) {
  DateTime.monday => t3(lang, 'look into a mirror', 'दर्पण देखकर निकलें', 'అద్దంలో చూసుకుని బయలుదేరండి'),
  DateTime.tuesday => t3(lang, 'eat a little jaggery', 'थोड़ा गुड़ खाकर निकलें', 'కొంచెం బెల్లం తిని బయలుదేరండి'),
  DateTime.wednesday => t3(
    lang,
    'eat a few sesame seeds or coriander',
    'तिल या धनिया खाकर निकलें',
    'కొన్ని నువ్వులు లేదా కొత్తిమీర తిని బయలుదేరండి',
  ),
  DateTime.thursday => t3(lang, 'eat a spoon of curd', 'दही खाकर निकलें', 'చెంచా పెరుగు తిని బయలుదేరండి'),
  DateTime.friday => t3(lang, 'eat a little barley', 'जौ खाकर निकलें', 'కొంచెం యవలు (బార్లీ) తిని బయలుదేరండి'),
  DateTime.saturday => t3(
    lang,
    'eat a little ginger or urad dal',
    'अदरक या उड़द खाकर निकलें',
    'కొంచెం అల్లం లేదా మినుములు తిని బయలుదేరండి',
  ),
  _ => t3(lang, 'eat a little ghee or porridge', 'घी या दलिया खाकर निकलें', 'కొంచెం నెయ్యి లేదా గంజి తిని బయలుదేరండి'),
};

/// What each weekday traditionally favours (the weekday's ruling graha).
String weekdaySuits(String lang, int weekday) => switch (weekday) {
  DateTime.monday => t3(
    lang,
    'Monday (Moon): travel, new clothes, farming and family visits',
    'सोमवार (चंद्र): यात्रा, नए वस्त्र, खेती और परिवार से मिलना',
    'సోమవారం (చంద్రుడు): ప్రయాణం, కొత్త బట్టలు, వ్యవసాయం, బంధువులను కలవడం',
  ),
  DateTime.tuesday => t3(
    lang,
    'Tuesday (Mars): courage, sports, property matters and Hanuman puja',
    'मंगलवार (मंगल): साहस, खेल, भूमि-संपत्ति के काम और हनुमान पूजा',
    'మంగళవారం (కుజుడు): ధైర్యం, క్రీడలు, భూమి వ్యవహారాలు, హనుమాన్ పూజ',
  ),
  DateTime.wednesday => t3(
    lang,
    'Wednesday (Mercury): study, writing, trade and accounts',
    'बुधवार (बुध): पढ़ाई, लेखन, व्यापार और हिसाब-किताब',
    'బుధవారం (బుధుడు): చదువు, రాత, వ్యాపారం, లెక్కలు',
  ),
  DateTime.thursday => t3(
    lang,
    'Thursday (Jupiter): learning, guru seva, marriage talks and buying gold',
    'गुरुवार (बृहस्पति): विद्या, गुरु सेवा, विवाह की बात और सोना खरीदना',
    'గురువారం (గురుడు): విద్య, గురు సేవ, వివాహ చర్చలు, బంగారం కొనడం',
  ),
  DateTime.friday => t3(
    lang,
    'Friday (Venus): music and arts, jewellery, vehicles and Lakshmi puja',
    'शुक्रवार (शुक्र): संगीत-कला, आभूषण, वाहन और लक्ष्मी पूजा',
    'శుక్రవారం (శుక్రుడు): సంగీతం, కళలు, ఆభరణాలు, వాహనాలు, లక్ష్మీ పూజ',
  ),
  DateTime.saturday => t3(
    lang,
    'Saturday (Saturn): service, repairs, charity and Shani puja',
    'शनिवार (शनि): सेवा, मरम्मत, दान और शनि पूजा',
    'శనివారం (శని): సేవ, మరమ్మతులు, దానం, శని పూజ',
  ),
  _ => t3(
    lang,
    'Sunday (Sun): health, government work, meeting elders and Surya puja',
    'रविवार (सूर्य): स्वास्थ्य, सरकारी काम, बड़ों से मिलना और सूर्य पूजा',
    'ఆదివారం (సూర్యుడు): ఆరోగ్యం, ప్రభుత్వ పనులు, పెద్దలను కలవడం, సూర్య పూజ',
  ),
};

/// The muhurta nature of a nakshatra (1 Ashwini to 27 Revati): fixed, movable, swift, soft,
/// sharp, fierce or mixed.
enum StarNature { fixed, movable, swift, soft, sharp, fierce, mixed }

StarNature starNature(int nakshatra) => switch (nakshatra) {
  4 || 12 || 21 || 26 => StarNature.fixed, // Rohini, Uttara Phalguni, Uttara Ashadha, Uttara Bhadrapada
  7 || 15 || 22 || 23 || 24 => StarNature.movable, // Punarvasu, Swati, Shravana, Dhanishta, Shatabhisha
  1 || 8 || 13 => StarNature.swift, // Ashwini, Pushya, Hasta
  5 || 14 || 17 || 27 => StarNature.soft, // Mrigashira, Chitra, Anuradha, Revati
  6 || 9 || 18 || 19 => StarNature.sharp, // Ardra, Ashlesha, Jyeshtha, Mula
  2 || 10 || 11 || 20 || 25 => StarNature.fierce, // Bharani, Magha, P. Phalguni, P. Ashadha, P. Bhadrapada
  _ => StarNature.mixed, // Krittika, Vishakha
};

/// What today's nakshatra suits, or null for natures better used for routine work only.
String? starSuits(String lang, StarNature n) => switch (n) {
  StarNature.fixed => t3(
    lang,
    'The nakshatra is fixed: good for lasting work such as laying foundations, a new home or planting',
    'नक्षत्र स्थिर है: नींव रखना, नया घर, पौधे लगाना जैसे स्थायी कामों के लिए अच्छा',
    'నక్షత్రం స్థిరం: పునాది, కొత్త ఇల్లు, మొక్కలు నాటడం వంటి శాశ్వత పనులకు మంచిది',
  ),
  StarNature.movable => t3(
    lang,
    'The nakshatra is movable: good for travel, buying a vehicle and starting a move',
    'नक्षत्र चर है: यात्रा, वाहन खरीदने और स्थान बदलने के लिए अच्छा',
    'నక్షత్రం చరం: ప్రయాణం, వాహనం కొనడం, ఇల్లు మారడం మొదలుపెట్టడానికి మంచిది',
  ),
  StarNature.swift => t3(
    lang,
    'The nakshatra is swift: good for trade, medicine, learning and quick tasks',
    'नक्षत्र क्षिप्र है: व्यापार, औषधि, विद्या और जल्दी होने वाले कामों के लिए अच्छा',
    'నక్షత్రం క్షిప్రం: వ్యాపారం, వైద్యం, విద్య, త్వరగా పూర్తయ్యే పనులకు మంచిది',
  ),
  StarNature.soft => t3(
    lang,
    'The nakshatra is soft: good for music and arts, friendship, new clothes and celebrations',
    'नक्षत्र मृदु है: संगीत-कला, मित्रता, नए वस्त्र और उत्सवों के लिए अच्छा',
    'నక్షత్రం మృదువు: సంగీతం, కళలు, స్నేహం, కొత్త బట్టలు, వేడుకలకు మంచిది',
  ),
  _ => null,
};

/// What today's nakshatra advises against, or null when it does not.
String? starAvoid(String lang, StarNature n) => switch (n) {
  StarNature.sharp => t3(
    lang,
    'The nakshatra is sharp: not for auspicious beginnings; fine for clearing old matters',
    'नक्षत्र तीक्ष्ण है: शुभ आरंभ के लिए नहीं; पुराने काम निपटाने के लिए ठीक',
    'నక్షత్రం తీక్ష్ణం: శుభ ప్రారంభాలకు కాదు; పాత పనులు పూర్తి చేయడానికి సరే',
  ),
  StarNature.fierce => t3(
    lang,
    'The nakshatra is fierce: postpone auspicious beginnings and big purchases',
    'नक्षत्र उग्र है: शुभ आरंभ और बड़ी खरीदारी टालें',
    'నక్షత్రం ఉగ్రం: శుభ ప్రారంభాలు, పెద్ద కొనుగోళ్లు వాయిదా వేయండి',
  ),
  StarNature.mixed => t3(
    lang,
    'The nakshatra is mixed: fine for routine work, less so for new beginnings',
    'नक्षत्र मिश्र है: रोज़ के कामों के लिए ठीक, नए आरंभ के लिए कम',
    'నక్షత్రం మిశ్రమం: రోజువారీ పనులకు సరే, కొత్త ప్రారంభాలకు అంతగా కాదు',
  ),
  _ => null,
};

/// A note for the tithi at sunrise (1–15 Shukla, 16–30 Krishna, 30 Amavasya), or null.
/// Rikta tithis (Chaturthi, Navami, Chaturdashi) are traditionally avoided for beginnings.
({String text, bool avoid})? tithiNote(String lang, int tithi) {
  final inPaksha = (tithi - 1) % 15 + 1;
  if (tithi == 30) {
    return (
      text: t3(
        lang,
        'Amavasya: a day for remembering ancestors (tarpan) and quiet prayer, not for new beginnings',
        'अमावस्या: पितरों के तर्पण और शांत पूजा का दिन, नए आरंभ का नहीं',
        'అమావాస్య: పితృ తర్పణం, ప్రశాంత ప్రార్థనకు రోజు; కొత్త ప్రారంభాలకు కాదు',
      ),
      avoid: true,
    );
  }
  if (tithi == 15) {
    return (
      text: t3(
        lang,
        'Purnima: good for vrat, Satyanarayan puja, charity and holy baths',
        'पूर्णिमा: व्रत, सत्यनारायण पूजा, दान और पवित्र स्नान के लिए अच्छी',
        'పౌర్ణమి: వ్రతం, సత్యనారాయణ పూజ, దానం, పుణ్య స్నానానికి మంచిది',
      ),
      avoid: false,
    );
  }
  if (inPaksha == 11) {
    return (
      text: t3(
        lang,
        'Ekadashi: a day for fasting, Vishnu puja and japa',
        'एकादशी: उपवास, विष्णु पूजा और जप का दिन',
        'ఏకాదశి: ఉపవాసం, విష్ణు పూజ, జపానికి రోజు',
      ),
      avoid: false,
    );
  }
  if (inPaksha == 4 || inPaksha == 9 || inPaksha == 14) {
    return (
      text: t3(
        lang,
        'A Rikta tithi (4th, 9th or 14th): better not to start new ventures; good for finishing work',
        'रिक्ता तिथि (चतुर्थी, नवमी या चतुर्दशी): नए काम शुरू न करें; अधूरे काम पूरे करने के लिए अच्छी',
        'రిక్త తిథి (చవితి, నవమి లేదా చతుర్దశి): కొత్త పనులు మొదలుపెట్టకండి; పాత పనులు పూర్తి చేయడానికి మంచిది',
      ),
      avoid: true,
    );
  }
  return null;
}
