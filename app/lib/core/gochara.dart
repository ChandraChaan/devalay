import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'i18n.dart';
import 'names.dart';

/// Weekly, monthly and yearly Rashi phalalu from real transits (gochara), counted from the reader's
/// Moon sign as Indian almanacs do. The server exports the sky (backend/app/services/gochara.py); the
/// words are written here so every app language has them.
///
/// Favourable houses from the Moon sign follow Phaladeepika, chapter 26 (Gochara phala):
/// Sun 3, 6, 10, 11; Moon 1, 3, 6, 7, 10, 11; Jupiter 2, 5, 7, 9, 11; Saturn 3, 6, 11.
/// Saturn in the 12th, 1st and 2nd is Sade Sati, in the 4th Ardhashtama and in the 8th Ashtama Shani;
/// the Moon in the 8th is Chandrashtamam.
class Transits {
  Transits(Map m)
    : from = DateTime.parse('${m['from']}'),
      moon = (m['moon'] as List).cast<int>(),
      signs = {
        for (final e in (m['planets'] as Map).entries)
          '${e.key}': [
            for (final s in (e.value as Map)['signs'] as List) (DateTime.parse('${(s as List)[0]}'), s[1] as int),
          ],
      },
      retro = {
        for (final e in (m['planets'] as Map).entries)
          '${e.key}': [
            for (final s in ((e.value as Map)['retro'] as List?) ?? const [])
              (DateTime.parse('${(s as List)[0]}'), s[1] == null ? null : DateTime.parse('${s[1]}')),
          ],
      };

  final DateTime from;
  final List<int> moon;
  final Map<String, List<(DateTime, int)>> signs;
  final Map<String, List<(DateTime, DateTime?)>> retro;

  DateTime get to => from.add(Duration(days: moon.length - 1));

  bool covers(DateTime d) => !d.isBefore(from) && !d.isAfter(to);

  int moonOn(DateTime d) => moon[d.difference(from).inDays.clamp(0, moon.length - 1)];

  int signOn(String planet, DateTime d) {
    var sign = signs[planet]!.first.$2;
    for (final (day, s) in signs[planet]!) {
      if (day.isAfter(d)) break;
      sign = s;
    }
    return sign;
  }

  /// Sign changes after [a] up to and including [b].
  List<(DateTime, int)> changes(String planet, DateTime a, DateTime b) => [
    for (final (day, s) in signs[planet]!.skip(1))
      if (day.isAfter(a) && !day.isAfter(b)) (day, s),
  ];

  /// Retrograde spans that overlap [a]..[b].
  List<(DateTime, DateTime?)> retroIn(String planet, DateTime a, DateTime b) => [
    for (final (s, e) in retro[planet] ?? const <(DateTime, DateTime?)>[])
      if (!s.isAfter(b) && (e == null || !e.isBefore(a))) (s, e),
  ];
}

final gocharaProvider = FutureProvider<Transits>((ref) async {
  return Transits(await ref.read(apiProvider).get('/gochara') as Map);
});

enum Period { week, month, year }

const goodHouses = {
  'sun': {3, 6, 10, 11},
  'moon': {1, 3, 6, 7, 10, 11},
  'jupiter': {2, 5, 7, 9, 11},
  'saturn': {3, 6, 11},
};

const _weights = {
  Period.week: {'moon': 0.5, 'sun': 0.3, 'jupiter': 0.1, 'saturn': 0.1},
  Period.month: {'moon': 0.25, 'sun': 0.35, 'jupiter': 0.2, 'saturn': 0.2},
  Period.year: {'jupiter': 0.5, 'saturn': 0.5},
};

/// House (1-12) of a sign counted from the Moon sign.
int houseFrom(int rashi, int sign) => (sign - rashi) % 12 + 1;

/// The week (Monday to Sunday), calendar month or calendar year that holds [day].
(DateTime, DateTime) periodSpan(Period p, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return switch (p) {
    Period.week => (d.subtract(Duration(days: d.weekday - 1)), d.add(Duration(days: 7 - d.weekday))),
    Period.month => (DateTime(d.year, d.month), DateTime(d.year, d.month + 1, 0)),
    Period.year => (DateTime(d.year), DateTime(d.year, 12, 31)),
  };
}

class Section {
  const Section(this.emoji, this.title, this.text);
  final String emoji, title, text;
}

class PeriodReading {
  PeriodReading(this.start, this.end, this.stars, this.overview, this.sections, this.goodDays, this.careDays);
  final DateTime start, end;

  /// 1-5.
  final int stars;
  final String overview;
  final List<Section> sections;

  /// Days with the Moon in a favourable house, and Chandrashtamam days (week and month only).
  final List<DateTime> goodDays, careDays;
}

String planetName(String lang, String planet) => switch (planet) {
  'sun' => t3(lang, 'Sun', 'सूर्य', 'సూర్యుడు'),
  'moon' => t3(lang, 'Moon', 'चंद्र', 'చంద్రుడు'),
  'jupiter' => t3(lang, 'Jupiter (Guru)', 'गुरु (बृहस्पति)', 'గురువు (బృహస్పతి)'),
  _ => t3(lang, 'Saturn (Shani)', 'शनि', 'శని'),
};

const _signNames = [
  'Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya', //
  'Tula', 'Vrishchika', 'Dhanu', 'Makara', 'Kumbha', 'Meena',
];

String signName(String lang, int sign) => rashiIn(lang, _signNames[sign % 12]);

PeriodReading periodReading(String lang, Transits tx, int rashi, Period period, DateTime day) {
  final (start, end) = periodSpan(period, day);
  final days = [for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) d];
  final inRange = days.where(tx.covers).toList();
  double share(String planet) {
    if (inRange.isEmpty) return 0.5;
    final good = inRange.where((d) {
      final sign = planet == 'moon' ? tx.moonOn(d) : tx.signOn(planet, d);
      return goodHouses[planet]!.contains(houseFrom(rashi, sign));
    }).length;
    return good / inRange.length;
  }

  final weights = _weights[period]!;
  final score = weights.entries.fold<double>(0, (s, e) => s + e.value * share(e.key));
  final stars = (1 + score * 4).round().clamp(1, 5);
  final tier = stars >= 4 ? 0 : (stars == 3 ? 1 : 2);

  final good = <DateTime>[], care = <DateTime>[];
  if (period != Period.year) {
    for (final d in inRange) {
      final h = houseFrom(rashi, tx.moonOn(d));
      if (goodHouses['moon']!.contains(h)) good.add(d);
      if (h == 8) care.add(d);
    }
  }

  final sections = <Section>[];
  String dates(List<DateTime> list) =>
      list.map((d) => fmtDate(lang, period == Period.week ? 'EEE d' : 'd MMM', d)).join(', ');

  void planet(String key, String emoji, String Function(String, int) text) {
    final at = tx.covers(start) ? start : (inRange.isEmpty ? start : inRange.first);
    final parts = [text(lang, houseFrom(rashi, tx.signOn(key, at)))];
    for (final (moved, sign) in tx.changes(key, start, end)) {
      parts.add(
        t3(lang, 'From {0} it moves into {1}: {2}', '{0} से {1} में: {2}', '{0} నుండి {1}లో: {2}')
            .replaceAll('{0}', fmtDate(lang, 'd MMM', moved))
            .replaceAll('{1}', signName(lang, sign))
            .replaceAll('{2}', text(lang, houseFrom(rashi, sign))),
      );
    }
    if (key != 'sun' && tx.retroIn(key, start, end).isNotEmpty) {
      parts.add(
        t3(
          lang,
          'Retrograde for part of this time: results come slowly; revisit old plans.',
          'इस अवधि में कुछ समय वक्री: परिणाम धीरे मिलेंगे; पुरानी योजनाओं पर फिर से ध्यान दें।',
          'ఈ కాలంలో కొంతకాలం వక్రగతి: ఫలితాలు నెమ్మదిగా వస్తాయి; పాత ప్రణాళికలను మళ్ళీ చూడండి.',
        ),
      );
    }
    sections.add(Section(emoji, planetName(lang, key), parts.join('\n\n')));
  }

  if (period != Period.year) {
    final moonParts = [
      if (good.isNotEmpty)
        t3(lang, 'Good days: {0}', 'शुभ दिन: {0}', 'మంచి రోజులు: {0}').replaceAll('{0}', dates(good)),
      if (care.isNotEmpty)
        t3(
          lang,
          'Chandrashtamam (Moon in the 8th), go gently: {0}',
          'चंद्राष्टम (आठवें भाव में चंद्र), संभलकर चलें: {0}',
          'చంద్రాష్టమం (8వ ఇంట చంద్రుడు), జాగ్రత్తగా ఉండండి: {0}',
        ).replaceAll('{0}', dates(care)),
    ];
    if (moonParts.isNotEmpty) sections.add(Section('🌙', planetName(lang, 'moon'), moonParts.join('\n\n')));
    planet('sun', '☀️', sunText);
  }
  if (period != Period.week) {
    planet('jupiter', '🪐', jupiterText);
    planet('saturn', '🪐', saturnText);
  } else {
    final h = houseFrom(rashi, tx.signOn('saturn', inRange.isEmpty ? start : inRange.first));
    if ({12, 1, 2, 4, 8}.contains(h)) sections.add(Section('🪐', planetName(lang, 'saturn'), saturnText(lang, h)));
  }

  return PeriodReading(start, end, stars, overview(lang, period, tier), sections, good, care);
}

String overview(String lang, Period p, int tier) => switch ((p, tier)) {
  (Period.week, 0) => t3(
    lang,
    'A favourable week. Begin important work on the good days.',
    'अनुकूल सप्ताह। महत्वपूर्ण काम शुभ दिनों में शुरू करें।',
    'అనుకూలమైన వారం. ముఖ్యమైన పనులు మంచి రోజుల్లో మొదలుపెట్టండి.',
  ),
  (Period.week, 1) => t3(
    lang,
    'A mixed week. Keep important work for the good days.',
    'मिला-जुला सप्ताह। महत्वपूर्ण काम शुभ दिनों के लिए रखें।',
    'మిశ్రమ ఫలితాల వారం. ముఖ్యమైన పనులు మంచి రోజులకు ఉంచుకోండి.',
  ),
  (Period.week, _) => t3(
    lang,
    'A week to go slowly. Keep to routine, pray, and start new things on the good days.',
    'धीरे चलने का सप्ताह। दिनचर्या बनाए रखें, प्रार्थना करें और नए काम शुभ दिनों में शुरू करें।',
    'నెమ్మదిగా సాగాల్సిన వారం. దినచర్య పాటించండి, ప్రార్థించండి, కొత్త పనులు మంచి రోజుల్లో మొదలుపెట్టండి.',
  ),
  (Period.month, 0) => t3(
    lang,
    'A favourable month. Efforts bear fruit and support comes easily.',
    'अनुकूल महीना। प्रयास सफल होंगे और सहयोग आसानी से मिलेगा।',
    'అనుకూలమైన నెల. ప్రయత్నాలు ఫలిస్తాయి, సహకారం సులువుగా అందుతుంది.',
  ),
  (Period.month, 1) => t3(
    lang,
    'A mixed month. Steady work and patience bring results.',
    'मिला-जुला महीना। लगातार मेहनत और धैर्य से परिणाम मिलेंगे।',
    'మిశ్రమ ఫలితాల నెల. నిలకడైన కృషి, ఓపిక ఫలితాన్నిస్తాయి.',
  ),
  (Period.month, _) => t3(
    lang,
    'A demanding month. Avoid big risks, look after health and keep faith.',
    'कठिन महीना। बड़े जोखिम से बचें, स्वास्थ्य का ध्यान रखें और आस्था बनाए रखें।',
    'శ్రమతో కూడిన నెల. పెద్ద సాహసాలు వద్దు, ఆరోగ్యం చూసుకోండి, విశ్వాసం కోల్పోకండి.',
  ),
  (Period.year, 0) => t3(
    lang,
    'A favourable year. Jupiter and Saturn support growth; plan big steps.',
    'अनुकूल वर्ष। गुरु और शनि उन्नति में सहायक हैं; बड़े कदमों की योजना बनाएँ।',
    'అనుకూలమైన సంవత్సరం. గురు, శని అభివృద్ధికి తోడ్పడతారు; పెద్ద అడుగులు ప్లాన్ చేసుకోండి.',
  ),
  (Period.year, 1) => t3(
    lang,
    'A mixed year. Gains come with effort; choose your moments.',
    'मिला-जुला वर्ष। मेहनत से लाभ मिलेगा; सही समय चुनें।',
    'మిశ్రమ ఫలితాల సంవత్సరం. కృషితో లాభాలు వస్తాయి; సరైన సమయం ఎంచుకోండి.',
  ),
  (Period.year, _) => t3(
    lang,
    'A year of tests. Slow, honest work and devotion carry you through.',
    'परीक्षा का वर्ष। धीमी, ईमानदार मेहनत और भक्ति आपको पार लगाएगी।',
    'పరీక్షల సంవత్సరం. నెమ్మదైన, నిజాయితీ కృషి, భక్తి మిమ్మల్ని గట్టెక్కిస్తాయి.',
  ),
};

/// The Sun's transit through each house from the Moon sign (Phaladeepika 26).
String sunText(String lang, int house) => switch (house) {
  1 => t3(
    lang,
    'The Sun over your Moon sign brings fatigue and a short temper. Rest well and keep your words soft.',
    'चंद्र राशि पर सूर्य थकान और चिड़चिड़ापन लाता है। भरपूर आराम करें और वाणी मधुर रखें।',
    'మీ చంద్ర రాశిపై సూర్యుడు అలసట, కోపం తెస్తాడు. బాగా విశ్రాంతి తీసుకోండి, మృదువుగా మాట్లాడండి.',
  ),
  2 => t3(
    lang,
    'Money goes out faster and family talks need patience. Avoid lending.',
    'धन जल्दी ख़र्च होगा और परिवार में बातचीत धैर्य से करें। उधार देने से बचें।',
    'డబ్బు త్వరగా ఖర్చవుతుంది, కుటుంబంలో మాటలు ఓపికగా ఉండాలి. అప్పులు ఇవ్వకండి.',
  ),
  3 => t3(
    lang,
    'Courage and success: efforts, short trips and dealings with officials go well.',
    'साहस और सफलता: प्रयास, छोटी यात्राएँ और अधिकारियों से काम अच्छे बनेंगे।',
    'ధైర్యం, విజయం: ప్రయత్నాలు, చిన్న ప్రయాణాలు, అధికారులతో పనులు బాగా సాగుతాయి.',
  ),
  4 => t3(
    lang,
    'Peace at home may be disturbed. Look after your health and your mother.',
    'घर की शांति भंग हो सकती है। अपने और माता के स्वास्थ्य का ध्यान रखें।',
    'ఇంట్లో ప్రశాంతత దెబ్బతినవచ్చు. మీ ఆరోగ్యం, అమ్మ ఆరోగ్యం చూసుకోండి.',
  ),
  5 => t3(
    lang,
    'The mind is unsettled and plans slip. Take care with children and speculation.',
    'मन अस्थिर रहेगा और योजनाएँ खिसक सकती हैं। संतान और सट्टे में सावधानी रखें।',
    'మనసు నిలకడగా ఉండదు, ప్రణాళికలు జారిపోవచ్చు. పిల్లలు, ఊహాజనిత పెట్టుబడుల విషయంలో జాగ్రత్త.',
  ),
  6 => t3(
    lang,
    'Opponents and illness retreat. You win disputes and finish pending work.',
    'विरोधी और रोग पीछे हटेंगे। विवादों में जीत और रुके काम पूरे होंगे।',
    'ప్రత్యర్థులు, అనారోగ్యం వెనక్కి తగ్గుతాయి. వివాదాల్లో గెలుపు, పెండింగ్ పనులు పూర్తవుతాయి.',
  ),
  7 => t3(
    lang,
    'Travel tires you and partners may disagree. Give relationships extra care.',
    'यात्रा थकाएगी और साथी से मतभेद हो सकते हैं। रिश्तों पर अधिक ध्यान दें।',
    'ప్రయాణాలు అలసటనిస్తాయి, భాగస్వామితో భేదాభిప్రాయాలు రావచ్చు. బంధాలపై ఎక్కువ శ్రద్ధ పెట్టండి.',
  ),
  8 => t3(
    lang,
    'Health and money need caution. Avoid risks and quarrels.',
    'स्वास्थ्य और धन में सावधानी चाहिए। जोखिम और झगड़ों से बचें।',
    'ఆరోగ్యం, డబ్బు విషయంలో జాగ్రత్త అవసరం. సాహసాలు, గొడవలు వద్దు.',
  ),
  9 => t3(
    lang,
    'Elders and superiors may be displeased. Keep faith and avoid long journeys.',
    'बड़े और वरिष्ठ नाराज़ हो सकते हैं। आस्था रखें और लंबी यात्राओं से बचें।',
    'పెద్దలు, పై అధికారులు అసంతృప్తి చెందవచ్చు. విశ్వాసం ఉంచండి, దూర ప్రయాణాలు వద్దు.',
  ),
  10 => t3(
    lang,
    'Work goes well: a good time for recognition and important tasks.',
    'कार्य अच्छा चलेगा: सम्मान और महत्वपूर्ण कामों के लिए अच्छा समय।',
    'పని బాగా సాగుతుంది: గుర్తింపుకు, ముఖ్యమైన పనులకు మంచి సమయం.',
  ),
  11 => t3(
    lang,
    'Gains, honour and good news. Wishes come true.',
    'लाभ, सम्मान और शुभ समाचार। मनोकामनाएँ पूरी होंगी।',
    'లాభాలు, గౌరవం, శుభవార్తలు. కోరికలు నెరవేరుతాయి.',
  ),
  _ => t3(
    lang,
    'Expenses and travel rise. Sleep well and spend on good causes.',
    'ख़र्च और यात्राएँ बढ़ेंगी। अच्छी नींद लें और शुभ कार्यों में व्यय करें।',
    'ఖర్చులు, ప్రయాణాలు పెరుగుతాయి. బాగా నిద్రపోండి, మంచి పనులకు ఖర్చు చేయండి.',
  ),
};

/// Jupiter's transit through each house from the Moon sign (Phaladeepika 26).
String jupiterText(String lang, int house) => switch (house) {
  1 => t3(
    lang,
    'Jupiter over your Moon sign: a testing stretch with changes of place and some worry. Stay patient.',
    'चंद्र राशि पर गुरु: स्थान परिवर्तन और कुछ चिंता के साथ परीक्षा का समय। धैर्य रखें।',
    'చంద్ర రాశిపై గురువు: స్థాన మార్పులు, కొంత ఆందోళనతో పరీక్షా సమయం. ఓపికగా ఉండండి.',
  ),
  2 => t3(
    lang,
    'Wealth and family grow, your words carry weight and savings rise.',
    'धन और परिवार में वृद्धि, वाणी में प्रभाव और बचत बढ़ेगी।',
    'ధనం, కుటుంబం వృద్ధి చెందుతాయి, మీ మాటకు విలువ పెరుగుతుంది, పొదుపు పెరుగుతుంది.',
  ),
  3 => t3(
    lang,
    'Efforts bring less than hoped and changes come at work. Keep steady.',
    'प्रयासों का फल अपेक्षा से कम और कार्य में बदलाव। स्थिर रहें।',
    'ప్రయత్నాలకు ఆశించినంత ఫలితం రాదు, పనిలో మార్పులు. నిలకడగా ఉండండి.',
  ),
  4 => t3(
    lang,
    'Comforts and peace at home need care, and relatives may trouble you.',
    'घर के सुख और शांति पर ध्यान दें; संबंधी परेशान कर सकते हैं।',
    'ఇంటి సుఖశాంతులపై శ్రద్ధ అవసరం; బంధువుల వల్ల ఇబ్బందులు రావచ్చు.',
  ),
  5 => t3(
    lang,
    'Children, learning and devotion flourish. Wise counsel and good decisions.',
    'संतान, विद्या और भक्ति फलेंगी। सही सलाह और अच्छे निर्णय।',
    'సంతానం, విద్య, భక్తి వర్ధిల్లుతాయి. మంచి సలహాలు, సరైన నిర్ణయాలు.',
  ),
  6 => t3(
    lang,
    'Opponents and health need watching. Avoid loans and disputes.',
    'विरोधियों और स्वास्थ्य पर नज़र रखें। कर्ज़ और विवाद से बचें।',
    'ప్రత్యర్థులు, ఆరోగ్యంపై కన్నేసి ఉంచండి. అప్పులు, వివాదాలు వద్దు.',
  ),
  7 => t3(
    lang,
    'Marriage, partnership and travel are blessed. A good time for alliances.',
    'विवाह, साझेदारी और यात्रा शुभ। संबंध जोड़ने का अच्छा समय।',
    'వివాహం, భాగస్వామ్యం, ప్రయాణాలు శుభప్రదం. సంబంధాలు కుదుర్చుకోవడానికి మంచి సమయం.',
  ),
  8 => t3(
    lang,
    'A hard stretch with obstacles and worries about health and money. Prayer and patience help.',
    'बाधाओं और स्वास्थ्य व धन की चिंता वाला कठिन समय। प्रार्थना और धैर्य सहायक होंगे।',
    'అడ్డంకులు, ఆరోగ్యం-డబ్బు ఆందోళనలతో కష్టకాలం. ప్రార్థన, ఓపిక సహాయపడతాయి.',
  ),
  9 => t3(
    lang,
    "Fortune and faith rise: pilgrimage, elders' blessings and progress.",
    'भाग्य और आस्था बढ़ेगी: तीर्थयात्रा, बड़ों का आशीर्वाद और उन्नति।',
    'అదృష్టం, విశ్వాసం పెరుగుతాయి: తీర్థయాత్రలు, పెద్దల ఆశీస్సులు, పురోగతి.',
  ),
  10 => t3(
    lang,
    'Pressure or changes at work. Hold your place through careful effort.',
    'कार्य में दबाव या बदलाव। सावधानीपूर्वक प्रयास से अपना स्थान बनाए रखें।',
    'పనిలో ఒత్తిడి లేదా మార్పులు. జాగ్రత్తైన కృషితో మీ స్థానం నిలబెట్టుకోండి.',
  ),
  11 => t3(
    lang,
    'Gains from many sides. Wishes are fulfilled and friends help.',
    'कई ओर से लाभ। मनोकामनाएँ पूरी होंगी और मित्र सहायता करेंगे।',
    'అనేక వైపుల నుండి లాభాలు. కోరికలు నెరవేరుతాయి, మిత్రులు సహాయం చేస్తారు.',
  ),
  _ => t3(
    lang,
    'Spending and travel rise, much of it on good causes. Guard your savings.',
    'ख़र्च और यात्राएँ बढ़ेंगी, अधिकतर शुभ कार्यों पर। अपनी बचत संभालें।',
    'ఖర్చులు, ప్రయాణాలు పెరుగుతాయి, ఎక్కువగా మంచి పనులకే. పొదుపును కాపాడుకోండి.',
  ),
};

/// Saturn's transit through each house from the Moon sign (Phaladeepika 26).
String saturnText(String lang, int house) => switch (house) {
  1 => t3(
    lang,
    'Saturn over your Moon sign, the peak of Sade Sati: heavy duties and fatigue. Slow, honest work pays.',
    'चंद्र राशि पर शनि, साढ़े साती का चरम: भारी ज़िम्मेदारियाँ और थकान। धीमी, ईमानदार मेहनत फल देगी।',
    'చంద్ర రాశిపై శని, ఏలినాటి శని మధ్య దశ: భారమైన బాధ్యతలు, అలసట. నెమ్మదైన, నిజాయితీ కృషి ఫలిస్తుంది.',
  ),
  2 => t3(
    lang,
    'The last phase of Sade Sati: family and money need care. Speak gently and save.',
    'साढ़े साती का अंतिम चरण: परिवार और धन पर ध्यान दें। मधुर बोलें और बचत करें।',
    'ఏలినాటి శని చివరి దశ: కుటుంబం, డబ్బుపై శ్రద్ధ అవసరం. మృదువుగా మాట్లాడండి, పొదుపు చేయండి.',
  ),
  3 => t3(
    lang,
    'Saturn in the third: courage, success and steady gains.',
    'तीसरे भाव में शनि: साहस, सफलता और स्थिर लाभ।',
    'మూడవ ఇంట శని: ధైర్యం, విజయం, స్థిరమైన లాభాలు.',
  ),
  4 => t3(
    lang,
    'Ardhashtama Shani: worries at home and health need care. Avoid hasty moves.',
    'अर्धाष्टम शनि: घर की चिंताएँ और स्वास्थ्य पर ध्यान दें। जल्दबाज़ी न करें।',
    'అర్ధాష్టమ శని: ఇంటి సమస్యలు, ఆరోగ్యంపై శ్రద్ధ అవసరం. తొందరపడకండి.',
  ),
  5 => t3(
    lang,
    'The mind and children need attention. Avoid speculation.',
    'मन और संतान पर ध्यान दें। सट्टे से बचें।',
    'మనసు, సంతానంపై శ్రద్ధ పెట్టండి. ఊహాజనిత పెట్టుబడులు వద్దు.',
  ),
  6 => t3(
    lang,
    'Saturn in the sixth: victory over opponents, better health and debts reduce.',
    'छठे भाव में शनि: विरोधियों पर विजय, स्वास्थ्य में सुधार और कर्ज़ घटेगा।',
    'ఆరవ ఇంట శని: ప్రత్యర్థులపై విజయం, ఆరోగ్యం మెరుగు, అప్పులు తగ్గుతాయి.',
  ),
  7 => t3(
    lang,
    'Partnerships and your spouse need patience; travel is tiring.',
    'साझेदारी और जीवनसाथी के साथ धैर्य रखें; यात्रा थकाएगी।',
    'భాగస్వామ్యాలు, జీవిత భాగస్వామితో ఓపిక అవసరం; ప్రయాణాలు అలసటనిస్తాయి.',
  ),
  8 => t3(
    lang,
    'Ashtama Shani: a demanding time. Avoid risks and look after your health.',
    'अष्टम शनि: कठिन समय। जोखिम से बचें और स्वास्थ्य का ध्यान रखें।',
    'అష్టమ శని: శ్రమతో కూడిన కాలం. సాహసాలు వద్దు, ఆరోగ్యం చూసుకోండి.',
  ),
  9 => t3(
    lang,
    'Luck moves slowly and elders may be displeased. Keep faith.',
    'भाग्य धीरे चलेगा और बड़े नाराज़ हो सकते हैं। आस्था बनाए रखें।',
    'అదృష్టం నెమ్మదిగా కలిసొస్తుంది, పెద్దలు అసంతృప్తి చెందవచ్చు. విశ్వాసం ఉంచండి.',
  ),
  10 => t3(
    lang,
    'Work is heavy and delayed, but persistence brings results.',
    'कार्य भारी और विलंबित रहेगा, पर लगन से परिणाम मिलेंगे।',
    'పని భారంగా, ఆలస్యంగా సాగుతుంది, కానీ పట్టుదలతో ఫలితాలు వస్తాయి.',
  ),
  11 => t3(
    lang,
    'Saturn in the eleventh: steady income and gains.',
    'ग्यारहवें भाव में शनि: स्थिर आय और लाभ।',
    'పదకొండవ ఇంట శని: స్థిరమైన ఆదాయం, లాభాలు.',
  ),
  _ => t3(
    lang,
    'The start of Sade Sati: expenses and travel rise. Spend wisely.',
    'साढ़े साती का आरंभ: ख़र्च और यात्राएँ बढ़ेंगी। सोच-समझकर व्यय करें।',
    'ఏలినాటి శని ప్రారంభం: ఖర్చులు, ప్రయాణాలు పెరుగుతాయి. ఆలోచించి ఖర్చు చేయండి.',
  ),
};
