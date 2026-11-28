/// What a birth star (nakshatra) is in the tradition: its presiding deity, ruling planet, symbol and
/// gana, and the ruling planet's seed mantra. Standard Jyotisha reference values.
library;

typedef Tri = (String en, String te, String hi);

enum Graha {
  sun(('Sun', 'సూర్యుడు', 'सूर्य'), 'ॐ घृणि सूर्याय नमः'),
  moon(('Moon', 'చంద్రుడు', 'चंद्र'), 'ॐ सों सोमाय नमः'),
  mars(('Mars', 'కుజుడు', 'मंगल'), 'ॐ अं अङ्गारकाय नमः'),
  mercury(('Mercury', 'బుధుడు', 'बुध'), 'ॐ बुं बुधाय नमः'),
  jupiter(('Jupiter', 'గురువు', 'गुरु'), 'ॐ बृं बृहस्पतये नमः'),
  venus(('Venus', 'శుక్రుడు', 'शुक्र'), 'ॐ शुं शुक्राय नमः'),
  saturn(('Saturn', 'శని', 'शनि'), 'ॐ शं शनैश्चराय नमः'),
  rahu(('Rahu', 'రాహువు', 'राहु'), 'ॐ रां राहवे नमः'),
  ketu(('Ketu', 'కేతువు', 'केतु'), 'ॐ कें केतवे नमः');

  const Graha(this.name, this.mantra);
  final Tri name;

  /// The planet's seed (beeja) mantra, in Devanagari (shown in the reader's script).
  final String mantra;
}

enum Gana {
  deva(('Deva', 'దేవ గణం', 'देव गण')),
  manushya(('Manushya', 'మనుష్య గణం', 'मनुष्य गण')),
  rakshasa(('Rakshasa', 'రాక్షస గణం', 'राक्षस गण'));

  const Gana(this.name);
  final Tri name;
}

typedef NakshatraInfo = ({Tri deity, Graha lord, Tri symbol, Gana gana});

/// Indexed 0-26 (Ashwini = 0), like the app's birth star.
const nakshatraInfo = <NakshatraInfo>[
  (
    deity: ('the Ashwini Kumaras', 'అశ్వినీ దేవతలు', 'अश्विनी कुमार'),
    lord: Graha.ketu,
    symbol: ("a horse's head", 'గుర్రపు ముఖం', 'अश्व का मुख'),
    gana: Gana.deva,
  ),
  (deity: ('Yama', 'యముడు', 'यम'), lord: Graha.venus, symbol: ('the yoni', 'యోని', 'योनि'), gana: Gana.manushya),
  (
    deity: ('Agni', 'అగ్ని', 'अग्नि'),
    lord: Graha.sun,
    symbol: ('a flame', 'అగ్ని జ్వాల', 'अग्नि शिखा'),
    gana: Gana.rakshasa,
  ),
  (deity: ('Brahma', 'బ్రహ్మ', 'ब्रह्मा'), lord: Graha.moon, symbol: ('a chariot', 'రథం', 'रथ'), gana: Gana.manushya),
  (
    deity: ('Soma', 'సోముడు', 'सोम'),
    lord: Graha.mars,
    symbol: ("a deer's head", 'జింక తల', 'मृग का सिर'),
    gana: Gana.deva,
  ),
  (
    deity: ('Rudra', 'రుద్రుడు', 'रुद्र'),
    lord: Graha.rahu,
    symbol: ('a teardrop', 'కన్నీటి బిందువు', 'अश्रु बिंदु'),
    gana: Gana.manushya,
  ),
  (
    deity: ('Aditi', 'అదితి', 'अदिति'),
    lord: Graha.jupiter,
    symbol: ('a quiver of arrows', 'అమ్ముల పొది', 'तरकश'),
    gana: Gana.deva,
  ),
  (
    deity: ('Brihaspati', 'బృహస్పతి', 'बृहस्पति'),
    lord: Graha.saturn,
    symbol: ('a flower', 'పుష్పం', 'पुष्प'),
    gana: Gana.deva,
  ),
  (
    deity: ('the Nagas', 'నాగదేవతలు', 'नाग देवता'),
    lord: Graha.mercury,
    symbol: ('a coiled serpent', 'చుట్టుకున్న సర్పం', 'कुंडली मारे सर्प'),
    gana: Gana.rakshasa,
  ),
  (
    deity: ('the Pitrs (ancestors)', 'పితృదేవతలు', 'पितृ'),
    lord: Graha.ketu,
    symbol: ('a royal throne', 'రాజ సింహాసనం', 'राजसिंहासन'),
    gana: Gana.rakshasa,
  ),
  (
    deity: ('Bhaga', 'భగుడు', 'भग'),
    lord: Graha.venus,
    symbol: ('the front legs of a bed', 'మంచం ముందు కాళ్లు', 'पलंग के अगले पाए'),
    gana: Gana.manushya,
  ),
  (
    deity: ('Aryaman', 'అర్యముడు', 'अर्यमा'),
    lord: Graha.sun,
    symbol: ('the back legs of a bed', 'మంచం వెనుక కాళ్లు', 'पलंग के पिछले पाए'),
    gana: Gana.manushya,
  ),
  (deity: ('Savitr', 'సవిత', 'सविता'), lord: Graha.moon, symbol: ('a hand', 'హస్తం', 'हाथ'), gana: Gana.deva),
  (
    deity: ('Vishwakarma', 'విశ్వకర్మ', 'विश्वकर्मा'),
    lord: Graha.mars,
    symbol: ('a bright jewel', 'మెరిసే మణి', 'चमकता रत्न'),
    gana: Gana.rakshasa,
  ),
  (
    deity: ('Vayu', 'వాయువు', 'वायु'),
    lord: Graha.rahu,
    symbol: ('a sprout in the wind', 'గాలికి ఊగే మొలక', 'हवा में अंकुर'),
    gana: Gana.deva,
  ),
  (
    deity: ('Indra and Agni', 'ఇంద్రాగ్నులు', 'इंद्र और अग्नि'),
    lord: Graha.jupiter,
    symbol: ('a triumphal arch', 'తోరణం', 'तोरण'),
    gana: Gana.rakshasa,
  ),
  (deity: ('Mitra', 'మిత్రుడు', 'मित्र'), lord: Graha.saturn, symbol: ('a lotus', 'పద్మం', 'कमल'), gana: Gana.deva),
  (
    deity: ('Indra', 'ఇంద్రుడు', 'इंद्र'),
    lord: Graha.mercury,
    symbol: ('an earring', 'కుండలం', 'कुंडल'),
    gana: Gana.rakshasa,
  ),
  (
    deity: ('Nirriti', 'నిరృతి', 'निरृति'),
    lord: Graha.ketu,
    symbol: ('tied roots', 'కట్టిన వేర్లు', 'बंधी जड़ें'),
    gana: Gana.rakshasa,
  ),
  (
    deity: ('Apas (the waters)', 'జలదేవత', 'आपः (जल)'),
    lord: Graha.venus,
    symbol: ('a winnowing fan', 'చేట', 'सूप'),
    gana: Gana.manushya,
  ),
  (
    deity: ('the Vishvedevas', 'విశ్వేదేవతలు', 'विश्वेदेव'),
    lord: Graha.sun,
    symbol: ("an elephant's tusk", 'ఏనుగు దంతం', 'हाथी दाँत'),
    gana: Gana.manushya,
  ),
  (deity: ('Vishnu', 'విష్ణువు', 'विष्णु'), lord: Graha.moon, symbol: ('an ear', 'చెవి', 'कान'), gana: Gana.deva),
  (
    deity: ('the eight Vasus', 'అష్టవసువులు', 'अष्ट वसु'),
    lord: Graha.mars,
    symbol: ('a drum', 'మృదంగం', 'मृदंग'),
    gana: Gana.rakshasa,
  ),
  (
    deity: ('Varuna', 'వరుణుడు', 'वरुण'),
    lord: Graha.rahu,
    symbol: ('an empty circle', 'శూన్య వృత్తం', 'खाली वृत्त'),
    gana: Gana.rakshasa,
  ),
  (
    deity: ('Aja Ekapada', 'అజైకపాదుడు', 'अज एकपाद'),
    lord: Graha.jupiter,
    symbol: ('a sword', 'ఖడ్గం', 'तलवार'),
    gana: Gana.manushya,
  ),
  (
    deity: ('Ahir Budhnya', 'అహిర్బుధ్న్యుడు', 'अहिर्बुध्न्य'),
    lord: Graha.saturn,
    symbol: ('twins', 'కవలలు', 'जुड़वाँ'),
    gana: Gana.manushya,
  ),
  (deity: ('Pushan', 'పూషుడు', 'पूषा'), lord: Graha.mercury, symbol: ('a fish', 'చేప', 'मछली'), gana: Gana.deva),
];

String tri(Tri t, String lang) => switch (lang) {
  'te' => t.$2,
  'hi' => t.$3,
  _ => t.$1,
};
