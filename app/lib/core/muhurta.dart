/// Daily time divisions computed on the phone from sunrise and sunset: Choghadiya, Hora, Gowri
/// Panchangam and Rahu Kalam, plus auspicious weekday–nakshatra days and national holidays.
///
/// Times are city wall-clock values held in UTC [DateTime]s (see [wallClock]) so that adding
/// durations never crosses the phone's own daylight-saving changes.
library;

import 'i18n.dart';
import 'names.dart';

/// "2026-11-13T06:24:10+05:30" -> 06:24:10 on 13 Nov as a UTC DateTime (the city's wall clock).
DateTime wallClock(String iso) => DateTime.parse('${iso.substring(0, 19)}Z');

/// The UTC offset carried by an API time ("+05:30" -> 5h30m). Zero when absent.
Duration isoOffset(String iso) {
  final m = RegExp(r'([+-])(\d\d):(\d\d)$').firstMatch(iso);
  if (m == null) return Duration.zero;
  final d = Duration(hours: int.parse(m[2]!), minutes: int.parse(m[3]!));
  return m[1] == '-' ? -d : d;
}

/// The current time on the city's wall clock.
DateTime nowIn(String iso) => DateTime.now().toUtc().add(isoOffset(iso));

/// "6:24 AM" for a wall-clock time.
String clock(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h12:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

enum Quality { best, good, neutral, bad }

class Period {
  const Period(this.key, this.start, this.end, this.quality, {this.night = false});
  final String key;
  final DateTime start, end;
  final Quality quality;
  final bool night;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

List<Period> _split(
  DateTime from,
  DateTime to,
  List<String> keys,
  Quality Function(String) quality, {
  bool night = false,
}) {
  final step = to.difference(from) ~/ keys.length;
  return [
    for (var i = 0; i < keys.length; i++)
      Period(
        keys[i],
        from.add(step * i),
        i == keys.length - 1 ? to : from.add(step * (i + 1)),
        quality(keys[i]),
        night: night,
      ),
  ];
}

/// Sunday = 0, as the classical tables are laid out.
int _sundayFirst(DateTime day) => day.weekday % 7;

// ---------------------------------------------------------------------------
// Choghadiya
// ---------------------------------------------------------------------------

/// In planetary order Sun, Venus, Mercury, Moon, Saturn, Jupiter, Mars.
const choghadiyaKeys = ['udveg', 'char', 'labh', 'amrit', 'kaal', 'shubh', 'rog'];

/// Index into [choghadiyaKeys] of the first day choghadiya, Sunday first (the weekday lord).
const _choghadiyaDayStart = [0, 3, 6, 2, 5, 1, 4];

Quality _choghadiyaQuality(String k) => switch (k) {
  'amrit' => Quality.best,
  'shubh' || 'labh' => Quality.good,
  'char' => Quality.neutral,
  _ => Quality.bad,
};

/// Eight day choghadiyas (sunrise to sunset) then eight night ones (sunset to next sunrise).
/// The day ones follow planetary order from the weekday lord; the night ones start five places
/// on and step back two each time.
List<Period> choghadiya(DateTime day, DateTime sunrise, DateTime sunset, DateTime nextSunrise) {
  final s = _choghadiyaDayStart[_sundayFirst(day)];
  final dayKeys = [for (var i = 0; i < 8; i++) choghadiyaKeys[(s + i) % 7]];
  final n = (s + 5) % 7;
  final nightKeys = [for (var i = 0; i < 8; i++) choghadiyaKeys[(n - 2 * i) % 7]];
  return [
    ..._split(sunrise, sunset, dayKeys, _choghadiyaQuality),
    ..._split(sunset, nextSunrise, nightKeys, _choghadiyaQuality, night: true),
  ];
}

String choghadiyaLabel(String lang, String k) => switch (k) {
  'udveg' => t3(lang, 'Udveg', 'उद्वेग', 'ఉద్వేగ'),
  'char' => t3(lang, 'Char', 'चर', 'చర'),
  'labh' => t3(lang, 'Labh', 'लाभ', 'లాభ'),
  'amrit' => t3(lang, 'Amrit', 'अमृत', 'అమృత'),
  'kaal' => t3(lang, 'Kaal', 'काल', 'కాల'),
  'shubh' => t3(lang, 'Shubh', 'शुभ', 'శుభ'),
  _ => t3(lang, 'Rog', 'रोग', 'రోగ'),
};

// ---------------------------------------------------------------------------
// Hora
// ---------------------------------------------------------------------------

/// Planetary hours share the Choghadiya planet order.
const horaPlanets = ['sun', 'venus', 'mercury', 'moon', 'saturn', 'jupiter', 'mars'];

Quality _horaQuality(String p) => switch (p) {
  'jupiter' || 'venus' => Quality.best,
  'moon' || 'mercury' => Quality.good,
  'sun' => Quality.neutral,
  _ => Quality.bad,
};

/// Twelve day horas and twelve night horas, starting with the weekday lord at sunrise.
List<Period> hora(DateTime day, DateTime sunrise, DateTime sunset, DateTime nextSunrise) {
  final s = _choghadiyaDayStart[_sundayFirst(day)];
  final keys = [for (var i = 0; i < 24; i++) horaPlanets[(s + i) % 7]];
  return [
    ..._split(sunrise, sunset, keys.sublist(0, 12), _horaQuality),
    ..._split(sunset, nextSunrise, keys.sublist(12), _horaQuality, night: true),
  ];
}

String horaLabel(String lang, String p) => switch (p) {
  'sun' => t3(lang, 'Sun', 'सूर्य', 'సూర్య'),
  'venus' => t3(lang, 'Venus', 'शुक्र', 'శుక్ర'),
  'mercury' => t3(lang, 'Mercury', 'बुध', 'బుధ'),
  'moon' => t3(lang, 'Moon', 'चंद्र', 'చంద్ర'),
  'saturn' => t3(lang, 'Saturn', 'शनि', 'శని'),
  'jupiter' => t3(lang, 'Jupiter', 'गुरु', 'గురు'),
  _ => t3(lang, 'Mars', 'मंगल', 'కుజ'),
};

/// What each hora is traditionally chosen for.
String horaUse(String lang, String p) => switch (p) {
  'sun' => t3(
    lang,
    'Government work, meeting officials',
    'सरकारी काम, अधिकारी से मिलना',
    'ప్రభుత్వ పనులు, అధికారులను కలవడం',
  ),
  'venus' => t3(
    lang,
    'Marriage talks, arts, jewellery, clothes',
    'विवाह बात, कला, आभूषण, वस्त्र',
    'పెళ్లి మాటలు, కళలు, ఆభరణాలు, బట్టలు',
  ),
  'mercury' => t3(
    lang,
    'Study, business, writing, accounts',
    'पढ़ाई, व्यापार, लेखन, हिसाब',
    'చదువు, వ్యాపారం, రాత, లెక్కలు',
  ),
  'moon' => t3(
    lang,
    'Travel, new ventures, meeting people',
    'यात्रा, नए काम, मिलना-जुलना',
    'ప్రయాణం, కొత్త పనులు, కలయికలు',
  ),
  'saturn' => t3(
    lang,
    'Hard labour and repairs; avoid new starts',
    'मेहनत, मरम्मत; नई शुरुआत टालें',
    'శ్రమ, మరమ్మతులు; కొత్త ఆరంభాలు వద్దు',
  ),
  'jupiter' => t3(
    lang,
    'Puja, learning, every good deed',
    'पूजा, विद्या, हर शुभ कार्य',
    'పూజ, విద్య, అన్ని శుభ కార్యాలు',
  ),
  _ => t3(
    lang,
    'Land, courage, sport; avoid quarrels',
    'भूमि, साहस, खेल; विवाद टालें',
    'భూమి, ధైర్యం, ఆటలు; తగాదాలు వద్దు',
  ),
};

// ---------------------------------------------------------------------------
// Gowri Panchangam
// ---------------------------------------------------------------------------

/// Day and night Gowri periods, Sunday first, as Drik Panchang publishes them.
const _gowriDay = [
  ['uthi', 'amirdha', 'rogam', 'laabam', 'dhanam', 'sugam', 'soram', 'visham'],
  ['amirdha', 'visham', 'rogam', 'laabam', 'dhanam', 'sugam', 'soram', 'uthi'],
  ['rogam', 'laabam', 'dhanam', 'sugam', 'soram', 'uthi', 'visham', 'amirdha'],
  ['laabam', 'dhanam', 'sugam', 'soram', 'visham', 'uthi', 'amirdha', 'rogam'],
  ['dhanam', 'sugam', 'soram', 'uthi', 'amirdha', 'visham', 'rogam', 'laabam'],
  ['sugam', 'soram', 'uthi', 'visham', 'amirdha', 'rogam', 'laabam', 'dhanam'],
  ['soram', 'uthi', 'visham', 'amirdha', 'rogam', 'laabam', 'dhanam', 'sugam'],
];
const _gowriNight = [
  ['dhanam', 'sugam', 'soram', 'visham', 'uthi', 'amirdha', 'rogam', 'laabam'],
  ['sugam', 'soram', 'uthi', 'amirdha', 'visham', 'rogam', 'laabam', 'dhanam'],
  ['soram', 'uthi', 'visham', 'amirdha', 'rogam', 'laabam', 'dhanam', 'sugam'],
  ['uthi', 'amirdha', 'rogam', 'laabam', 'dhanam', 'sugam', 'soram', 'visham'],
  ['amirdha', 'visham', 'rogam', 'laabam', 'dhanam', 'sugam', 'soram', 'uthi'],
  ['rogam', 'laabam', 'dhanam', 'sugam', 'soram', 'uthi', 'visham', 'amirdha'],
  ['laabam', 'dhanam', 'sugam', 'soram', 'uthi', 'visham', 'amirdha', 'rogam'],
];

Quality _gowriQuality(String k) => switch (k) {
  'amirdha' => Quality.best,
  'laabam' || 'dhanam' || 'sugam' || 'uthi' => Quality.good,
  _ => Quality.bad,
};

List<Period> gowri(DateTime day, DateTime sunrise, DateTime sunset, DateTime nextSunrise) {
  final w = _sundayFirst(day);
  return [
    ..._split(sunrise, sunset, _gowriDay[w], _gowriQuality),
    ..._split(sunset, nextSunrise, _gowriNight[w], _gowriQuality, night: true),
  ];
}

String gowriLabel(String lang, String k) => switch (k) {
  'amirdha' => t3(lang, 'Amrutham', 'अमृत', 'అమృతం'),
  'uthi' => t3(lang, 'Udyogam', 'उद्योग', 'ఉద్యోగం'),
  'rogam' => t3(lang, 'Rogam', 'रोग', 'రోగం'),
  'laabam' => t3(lang, 'Labham', 'लाभ', 'లాభం'),
  'dhanam' => t3(lang, 'Dhanam', 'धन', 'ధనం'),
  'sugam' => t3(lang, 'Sukham', 'सुख', 'సుఖం'),
  'soram' => t3(lang, 'Choram', 'चोर', 'చోరం'),
  _ => t3(lang, 'Visham', 'विष', 'విషం'),
};

String qualityLabel(String lang, Quality q) => switch (q) {
  Quality.best => t3(lang, 'Best', 'उत्तम', 'ఉత్తమం'),
  Quality.good => t3(lang, 'Good', 'शुभ', 'శుభం'),
  Quality.neutral => t3(lang, 'Neutral', 'सामान्य', 'సామాన్యం'),
  Quality.bad => t3(lang, 'Avoid', 'अशुभ', 'అశుభం'),
};

// ---------------------------------------------------------------------------
// Rahu Kalam
// ---------------------------------------------------------------------------

/// Which eighth of daylight is Rahu Kalam, Sunday first.
const _rahuPart = [8, 2, 7, 5, 6, 4, 3];

(DateTime, DateTime) rahuKalam(DateTime day, DateTime sunrise, DateTime sunset) {
  final part = sunset.difference(sunrise) ~/ 8;
  final n = _rahuPart[_sundayFirst(day)] - 1;
  return (sunrise.add(part * n), sunrise.add(part * (n + 1)));
}

// ---------------------------------------------------------------------------
// Auspicious days and holidays
// ---------------------------------------------------------------------------

const nakshatraNames = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra', 'Punarvasu', 'Pushya', 'Ashlesha', //
  'Magha', 'Purva Phalguni', 'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha',
  'Jyeshtha', 'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana', 'Dhanishta', 'Shatabhisha',
  'Purva Bhadrapada', 'Uttara Bhadrapada', 'Revati',
];

/// Amrita Siddhi nakshatra for each weekday, Sunday first.
const _amritaSiddhi = ['Hasta', 'Mrigashira', 'Ashwini', 'Anuradha', 'Pushya', 'Revati', 'Rohini'];

/// Guru Pushya, Ravi Pushya or Amrita Siddhi yoga from the weekday and the sunrise nakshatra.
String? shubhYoga(DateTime day, String nakshatra) {
  final w = _sundayFirst(day);
  if (nakshatra == 'Pushya' && w == 4) return 'guru-pushya';
  if (nakshatra == 'Pushya' && w == 0) return 'ravi-pushya';
  if (_amritaSiddhi[w] == nakshatra) return 'amrita-siddhi';
  return null;
}

String shubhYogaLabel(String lang, String key) => switch (key) {
  'guru-pushya' => t3(lang, 'Guru Pushya Yoga', 'गुरु पुष्य योग', 'గురు పుష్య యోగం'),
  'ravi-pushya' => t3(lang, 'Ravi Pushya Yoga', 'रवि पुष्य योग', 'రవి పుష్య యోగం'),
  _ => t3(lang, 'Amrita Siddhi Yoga', 'अमृत सिद्धि योग', 'అమృత సిద్ధి యోగం'),
};

String shubhYogaNote(String lang, String key) => switch (key) {
  'guru-pushya' || 'ravi-pushya' => t3(
    lang,
    'Very auspicious for buying gold, starting studies, business and new work.',
    'सोना खरीदने, पढ़ाई, व्यापार और नए कार्य के लिए अति शुभ।',
    'బంగారం కొనుగోలు, విద్యారంభం, వ్యాపారం, కొత్త పనులకు చాలా శుభం.',
  ),
  _ => t3(
    lang,
    'A good day to begin important work.',
    'महत्वपूर्ण कार्य आरंभ करने के लिए शुभ दिन।',
    'ముఖ్యమైన పనులు ప్రారంభించడానికి మంచి రోజు.',
  ),
};

/// National holidays on fixed dates.
String? nationalHoliday(DateTime d) => switch ((d.month, d.day)) {
  (1, 26) => 'republic-day',
  (8, 15) => 'independence-day',
  (10, 2) => 'gandhi-jayanti',
  (12, 25) => 'christmas',
  _ => null,
};

String holidayLabel(String lang, String key) => switch (key) {
  'republic-day' => t3(lang, 'Republic Day', 'गणतंत्र दिवस', 'గణతంత్ర దినోత్సవం'),
  'independence-day' => t3(lang, 'Independence Day', 'स्वतंत्रता दिवस', 'స్వాతంత్ర్య దినోత్సవం'),
  'gandhi-jayanti' => t3(lang, 'Gandhi Jayanti', 'गांधी जयंती', 'గాంధీ జయంతి'),
  _ => t3(lang, 'Christmas', 'क्रिसमस', 'క్రిస్మస్'),
};

// ---------------------------------------------------------------------------
// Lunar months
// ---------------------------------------------------------------------------

const lunarMonthNames = [
  'Chaitra', 'Vaishakha', 'Jyeshtha', 'Ashadha', 'Shravana', 'Bhadrapada', //
  'Ashwin', 'Kartika', 'Margashirsha', 'Pausha', 'Magha', 'Phalguna',
];
const _lunarMonthsHi = [
  'चैत्र', 'वैशाख', 'ज्येष्ठ', 'आषाढ़', 'श्रावण', 'भाद्रपद', //
  'आश्विन', 'कार्तिक', 'मार्गशीर्ष', 'पौष', 'माघ', 'फाल्गुन',
];
const _lunarMonthsTe = [
  'చైత్రం', 'వైశాఖం', 'జ్యేష్ఠం', 'ఆషాఢం', 'శ్రావణం', 'భాద్రపదం', //
  'ఆశ్వయుజం', 'కార్తీకం', 'మార్గశిరం', 'పుష్యం', 'మాఘం', 'ఫాల్గుణం',
];

String lunarMonthLabel(String lang, int i) => switch (lang) {
  'en' => lunarMonthNames[i % 12],
  'hi' => _lunarMonthsHi[i % 12],
  'te' => _lunarMonthsTe[i % 12],
  _ => monthIn(lang, i),
};

// ---------------------------------------------------------------------------
// Tarabalam and Chandrabalam: the day measured from the user's birth star and moon sign
// ---------------------------------------------------------------------------

const rashiNames = [
  'Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya', //
  'Tula', 'Vrishchika', 'Dhanu', 'Makara', 'Kumbha', 'Meena',
];

const _taraKeys = ['janma', 'sampat', 'vipat', 'kshema', 'pratyak', 'sadhana', 'naidhana', 'mitra', 'parama-mitra'];

/// The tara (1–9) of [today] counted from [birth], both nakshatra indexes 0–26, with its quality.
/// Janma tara is mixed: fine for routine work, avoided for big beginnings.
({int tara, String key, Quality quality}) tarabalam(int birth, int today) {
  final count = (today - birth) % 27 + 1;
  final tara = (count - 1) % 9 + 1;
  final quality = switch (tara) {
    2 || 4 || 6 || 8 || 9 => Quality.good,
    1 => Quality.neutral,
    _ => Quality.bad,
  };
  return (tara: tara, key: _taraKeys[tara - 1], quality: quality);
}

String taraLabel(String lang, String key) => switch (key) {
  'janma' => t3(lang, 'Janma', 'जन्म', 'జన్మ'),
  'sampat' => t3(lang, 'Sampat', 'संपत', 'సంపత్'),
  'vipat' => t3(lang, 'Vipat', 'विपत', 'విపత్'),
  'kshema' => t3(lang, 'Kshema', 'क्षेम', 'క్షేమ'),
  'pratyak' => t3(lang, 'Pratyak', 'प्रत्यक', 'ప్రత్యక్'),
  'sadhana' => t3(lang, 'Sadhana', 'साधना', 'సాధన'),
  'naidhana' => t3(lang, 'Naidhana', 'नैधन', 'నైధన'),
  'mitra' => t3(lang, 'Mitra', 'मित्र', 'మిత్ర'),
  _ => t3(lang, 'Parama Mitra', 'परम मित्र', 'పరమ మిత్ర'),
};

/// The house (1–12) the Moon is in from the user's moon sign, both rashi indexes 0–11.
({int house, Quality quality}) chandrabalam(int birthRashi, int moonRashi) {
  final house = (moonRashi - birthRashi) % 12 + 1;
  return (house: house, quality: const {1, 3, 6, 7, 10, 11}.contains(house) ? Quality.good : Quality.bad);
}

/// "1st", "2nd", "3rd" in English; "3वाँ" / "3వ" otherwise.
String ordinal(String lang, int n) => switch (lang) {
  'hi' || 'mr' => '$nवाँ',
  'te' => '$nవ',
  'kn' => '$nನೇ',
  'ta' => '$nஆம்',
  'ml' => '$nാം',
  'gu' => '$nમું',
  'bn' => '$nম',
  'or' => '$nମ',
  'pa' => '$nਵਾਂ',
  _ =>
    '$n${n == 1
        ? 'st'
        : n == 2
        ? 'nd'
        : n == 3
        ? 'rd'
        : 'th'}',
};

const _nakshatraHi = [
  'अश्विनी', 'भरणी', 'कृत्तिका', 'रोहिणी', 'मृगशिरा', 'आर्द्रा', 'पुनर्वसु', 'पुष्य', 'आश्लेषा', //
  'मघा', 'पूर्वा फाल्गुनी', 'उत्तरा फाल्गुनी', 'हस्त', 'चित्रा', 'स्वाति', 'विशाखा', 'अनुराधा',
  'ज्येष्ठा', 'मूल', 'पूर्वाषाढ़ा', 'उत्तराषाढ़ा', 'श्रवण', 'धनिष्ठा', 'शतभिषा',
  'पूर्वा भाद्रपद', 'उत्तरा भाद्रपद', 'रेवती',
];
const _rashiHi = ['मेष', 'वृषभ', 'मिथुन', 'कर्क', 'सिंह', 'कन्या', 'तुला', 'वृश्चिक', 'धनु', 'मकर', 'कुंभ', 'मीन'];

/// Nakshatra 0–26 in the user's language.
String nakshatraLabel(String lang, int i) => switch (lang) {
  'en' => nakshatraNames[i],
  'hi' => _nakshatraHi[i],
  _ => nakshatraIn(lang, nakshatraNames[i]),
};

/// Rashi 0–11 in the user's language.
String rashiLabel(String lang, int i) => lang == 'hi' ? _rashiHi[i] : rashiIn(lang, rashiNames[i]);

/// The rashi holding the first pada of nakshatra [star] (each star is 13°20', each rashi 30°).
int rashiOfStar(int star) => star * 4 ~/ 9;
