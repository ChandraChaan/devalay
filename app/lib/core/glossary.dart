import 'package:flutter/material.dart';

import 'i18n.dart';

/// Plain-language meanings of Panchang terms, shown when a term is tapped.
/// Reviews of other calendar apps ask "what is yogam, what is gulika kalam?".
const _glossary = <String, List<String>>{
  // key: [title en, hi, te, meaning en, hi, te]
  'tithi': [
    'Tithi',
    'तिथि',
    'తిథి',
    'The lunar day. Each tithi is the time the Moon takes to move 12° ahead of the Sun, so it can begin at any hour and lasts 19 to 26 hours. Festivals and vratas follow the tithi.',
    'चंद्र दिवस। चंद्रमा को सूर्य से 12° आगे बढ़ने में जितना समय लगता है, वह एक तिथि है, इसलिए यह किसी भी समय शुरू हो सकती है और 19 से 26 घंटे की होती है। त्योहार और व्रत तिथि से चलते हैं।',
    'చాంద్ర దినం. చంద్రుడు సూర్యుని కంటే 12° ముందుకు వెళ్లడానికి పట్టే సమయం ఒక తిథి. అందుకే ఇది ఏ సమయంలోనైనా మొదలై 19 నుంచి 26 గంటలు ఉంటుంది. పండుగలు, వ్రతాలు తిథిని బట్టి జరుగుతాయి.',
  ],
  'nakshatra': [
    'Nakshatra',
    'नक्षत्र',
    'నక్షత్రం',
    "The star the Moon is passing through. The sky is divided into 27 nakshatras; the Moon spends about a day in each. Your birth star is the nakshatra at the time you were born.",
    'चंद्रमा जिस तारामंडल से गुजर रहा है। आकाश 27 नक्षत्रों में बँटा है और चंद्रमा हर नक्षत्र में लगभग एक दिन रहता है। जन्म के समय का नक्षत्र आपका जन्म नक्षत्र है।',
    'చంద్రుడు ప్రయాణిస్తున్న నక్షత్రం. ఆకాశం 27 నక్షత్రాలుగా విభజించబడింది; చంద్రుడు ప్రతి దానిలో సుమారు ఒక రోజు ఉంటాడు. పుట్టిన సమయంలోని నక్షత్రమే మీ జన్మ నక్షత్రం.',
  ],
  'yoga': [
    'Yoga',
    'योग',
    'యోగం',
    'One of 27 daily combinations of the Sun and Moon, found from their added longitudes. A few yogas, such as Vyatipata and Vaidhriti, are avoided for new work.',
    'सूर्य और चंद्रमा के देशांतर जोड़कर बनने वाले 27 योगों में से एक। व्यतीपात और वैधृति जैसे कुछ योग नए कार्य के लिए टाले जाते हैं।',
    'సూర్య చంద్రుల రేఖాంశాల మొత్తంతో ఏర్పడే 27 యోగాలలో ఒకటి. వ్యతీపాతం, వైధృతి వంటి కొన్ని యోగాలలో కొత్త పనులు చేయరు.',
  ],
  'karana': [
    'Karana',
    'करण',
    'కరణం',
    'Half of a tithi, so there are two in a day. Vishti (Bhadra) karana is avoided for auspicious work.',
    'तिथि का आधा भाग, इसलिए एक दिन में दो करण होते हैं। विष्टि (भद्रा) करण शुभ कार्य के लिए टाला जाता है।',
    'తిథిలో సగ భాగం, కాబట్టి రోజుకు రెండు కరణాలు. విష్టి (భద్ర) కరణంలో శుభ కార్యాలు చేయరు.',
  ],
  'paksha': [
    'Paksha',
    'पक्ष',
    'పక్షం',
    'The fortnight. Shukla paksha is the bright half from new moon to full moon; Krishna (Bahula) paksha is the dark half back to new moon.',
    'पखवाड़ा। अमावस्या से पूर्णिमा तक शुक्ल पक्ष, और पूर्णिमा से अमावस्या तक कृष्ण पक्ष।',
    'పక్షం అంటే పదిహేను రోజులు. అమావాస్య నుంచి పౌర్ణమి వరకు శుక్ల పక్షం, పౌర్ణమి నుంచి అమావాస్య వరకు బహుళ పక్షం.',
  ],
  'masa': [
    'Masa (lunar month)',
    'मास',
    'మాసం',
    'Telugu and South Indian calendars count a month from new moon to new moon (amanta). It is named after the solar sign the Sun is in at the new moon, so a year sometimes gets an extra (Adhika) month.',
    'दक्षिण भारत में मास अमावस्या से अमावस्या तक (अमांत) गिना जाता है। अमावस्या पर सूर्य जिस राशि में हो उससे नाम पड़ता है, इसलिए कभी-कभी अधिक मास आता है।',
    'తెలుగు పంచాంగంలో మాసం అమావాస్య నుంచి అమావాస్య వరకు (అమాంత). అమావాస్య నాడు సూర్యుడున్న రాశిని బట్టి పేరు, అందుకే అప్పుడప్పుడు అధిక మాసం వస్తుంది.',
  ],
  'abhijit': [
    'Abhijit Muhurta',
    'अभिजित मुहूर्त',
    'అభిజిత్ ముహూర్తం',
    'About 48 minutes around local noon, held good for starting most work. It is skipped on Wednesdays.',
    'स्थानीय दोपहर के आसपास लगभग 48 मिनट, अधिकतर कार्य आरंभ के लिए शुभ। बुधवार को इसे नहीं लेते।',
    'మధ్యాహ్నం చుట్టూ సుమారు 48 నిమిషాలు, చాలా పనుల ప్రారంభానికి శుభం. బుధవారం దీనిని తీసుకోరు.',
  ],
  'amrit': [
    'Amrit Kalam',
    'अमृत काल',
    'అమృత కాలం',
    'A window of about 1½ hours set by the nakshatra, considered very auspicious; it often helps when Rahu Kalam or Varjyam blocks the day.',
    'नक्षत्र के अनुसार लगभग डेढ़ घंटे का समय, अत्यंत शुभ माना जाता है।',
    'నక్షత్రాన్ని బట్టి సుమారు గంటన్నర సమయం, చాలా శుభంగా భావిస్తారు.',
  ],
  'brahma': [
    'Brahma Muhurta',
    'ब्रह्म मुहूर्त',
    'బ్రహ్మ ముహూర్తం',
    'The hour and a half before sunrise, ending 48 minutes before it: the best time for meditation, prayer and study.',
    'सूर्योदय से पहले का समय (सूर्योदय से 96 से 48 मिनट पहले), ध्यान, पूजा और अध्ययन के लिए श्रेष्ठ।',
    'సూర్యోదయానికి 96 నుంచి 48 నిమిషాల ముందు సమయం, ధ్యానం, పూజ, చదువుకు శ్రేష్ఠం.',
  ],
  'rahu': [
    'Rahu Kalam',
    'राहु काल',
    'రాహు కాలం',
    'One eighth of the daytime, about 1½ hours, ruled by Rahu. People avoid starting journeys, purchases and new work in it. Its place in the day changes with the weekday.',
    'दिन के समय का आठवाँ भाग, लगभग डेढ़ घंटा, जिसका स्वामी राहु है। इसमें यात्रा, खरीद और नए कार्य आरंभ नहीं करते। वार के अनुसार इसका समय बदलता है।',
    'పగటి సమయంలో ఎనిమిదో భాగం, సుమారు గంటన్నర, రాహువు అధిపతి. ఇందులో ప్రయాణాలు, కొనుగోళ్లు, కొత్త పనులు మొదలుపెట్టరు. వారాన్ని బట్టి సమయం మారుతుంది.',
  ],
  'yama': [
    'Yamagandam',
    'यमगंड',
    'యమగండం',
    'Another eighth of the daytime, ruled by Yama, avoided for auspicious beginnings.',
    'दिन का एक और आठवाँ भाग, यम का समय, शुभ आरंभ के लिए टाला जाता है।',
    'పగటిలో మరో ఎనిమిదో భాగం, యముని కాలం, శుభ ప్రారంభాలకు వద్దు.',
  ],
  'gulika': [
    'Gulika Kalam',
    'गुलिक काल',
    'గుళిక కాలం',
    "An eighth of the daytime ruled by Gulika, Saturn's son. Whatever is begun in it is said to repeat, so it suits good deeds but not funerals or debts.",
    'शनि पुत्र गुलिक का समय। इसमें शुरू किया काम दोहराता है, इसलिए शुभ कार्य ठीक हैं पर ऋण या अंतिम संस्कार नहीं।',
    'శని కుమారుడు గుళికుని కాలం. ఇందులో మొదలుపెట్టింది మళ్లీ జరుగుతుందని నమ్మకం; మంచి పనులకు సరే, అప్పులకు కాదు.',
  ],
  'durmuhurtham': [
    'Durmuhurtham',
    'दुर्मुहूर्त',
    'దుర్ముహూర్తం',
    'One or two inauspicious muhurtas (48 minutes each) of the day, fixed by the weekday.',
    'दिन के एक या दो अशुभ मुहूर्त (48 मिनट), वार के अनुसार।',
    'రోజులో ఒకటి లేదా రెండు అశుభ ముహూర్తాలు (ఒక్కొక్కటి 48 నిమిషాలు), వారాన్ని బట్టి.',
  ],
  'varjyam': [
    'Varjyam',
    'वर्ज्यम्',
    'వర్జ్యం',
    'About 1½ hours inside each nakshatra that Telugu and Tamil panchangams mark as unfit for any good work.',
    'हर नक्षत्र के भीतर लगभग डेढ़ घंटा, जिसे दक्षिण भारतीय पंचांग शुभ कार्य के लिए वर्जित मानते हैं।',
    'ప్రతి నక్షత్రంలో సుమారు గంటన్నర సమయం, ఏ శుభ కార్యానికీ పనికిరానిదిగా పంచాంగాలు చెబుతాయి.',
  ],
  'choghadiya': [
    'Choghadiya',
    'चौघड़िया',
    'చోఘడియ',
    'The day and the night are each split into eight parts, each ruled by a planet. Amrit, Shubh and Labh are good for new work, Char for travel; Rog, Kaal and Udveg are avoided. Widely used in Gujarat and North India.',
    'दिन और रात को आठ-आठ भागों में बाँटा जाता है। अमृत, शुभ, लाभ नए कार्य के लिए, चर यात्रा के लिए; रोग, काल, उद्वेग टाले जाते हैं।',
    'పగలు, రాత్రి ఒక్కొక్కటి ఎనిమిది భాగాలు. అమృత, శుభ, లాభ కొత్త పనులకు, చర ప్రయాణానికి మంచివి; రోగ, కాల, ఉద్వేగ వద్దు.',
  ],
  'hora': [
    'Hora',
    'होरा',
    'హోర',
    'Planetary hours: daytime and night are each split into twelve, ruled in turn by the Sun, Venus, Mercury, Moon, Saturn, Jupiter and Mars, starting with the lord of the weekday at sunrise.',
    'ग्रहों के घंटे: दिन और रात बारह-बारह भागों में, सूर्योदय पर वार के स्वामी से शुरू होकर सूर्य, शुक्र, बुध, चंद्र, शनि, गुरु, मंगल क्रम से।',
    'గ్రహ హోరలు: పగలు, రాత్రి పన్నెండు భాగాలుగా, సూర్యోదయాన వారాధిపతితో మొదలై సూర్య, శుక్ర, బుధ, చంద్ర, శని, గురు, కుజ క్రమంలో.',
  ],
  'gowri': [
    'Gowri Panchangam',
    'गौरी पंचांग',
    'గౌరీ పంచాంగం',
    'Eight day and eight night periods named Amrutham, Udyogam, Labham, Dhanam, Sukham (good) and Rogam, Choram, Visham (bad). Popular in Tamil Nadu and Andhra Pradesh for choosing a good time (nalla neram).',
    'दिन और रात के आठ-आठ भाग: अमृत, उद्योग, लाभ, धन, सुख शुभ और रोग, चोर, विष अशुभ।',
    'పగలు, రాత్రి ఎనిమిదేసి భాగాలు: అమృతం, ఉద్యోగం, లాభం, ధనం, సుఖం మంచివి; రోగం, చోరం, విషం చెడ్డవి.',
  ],
  'tarabalam': [
    'Tarabalam',
    'तारा बल',
    'తారాబలం',
    "How today's nakshatra stands from your birth star, counted in nine groups. Sampat, Kshema, Sadhana, Mitra and Parama Mitra are good; Vipat, Pratyak and Naidhana are not.",
    'आज का नक्षत्र आपके जन्म नक्षत्र से किस गिनती में है। संपत, क्षेम, साधना, मित्र, परम मित्र शुभ; विपत, प्रत्यक, नैधन अशुभ।',
    'నేటి నక్షత్రం మీ జన్మ నక్షత్రం నుంచి ఎన్నోది. సంపత్, క్షేమ, సాధన, మిత్ర, పరమ మిత్ర మంచివి; విపత్, ప్రత్యక్, నైధన మంచివి కావు.',
  ],
  'chandrabalam': [
    'Chandrabalam',
    'चंद्र बल',
    'చంద్రబలం',
    "Which house from your moon sign (rashi) the Moon is in today. The 1st, 3rd, 6th, 7th, 10th and 11th are favourable.",
    'आज चंद्रमा आपकी राशि से किस भाव में है। 1, 3, 6, 7, 10 और 11वाँ भाव अनुकूल।',
    'నేడు చంద్రుడు మీ రాశి నుంచి ఎన్నో స్థానంలో ఉన్నాడు. 1, 3, 6, 7, 10, 11 స్థానాలు అనుకూలం.',
  ],
};

bool hasMeaning(String key) => _glossary.containsKey(key);

/// Opens a short explanation of [key].
Future<void> showMeaning(BuildContext context, String lang, String key) {
  final g = _glossary[key];
  if (g == null) return Future.value();
  final i = switch (lang) {
    'hi' => 1,
    'te' => 2,
    _ => 0,
  };
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: Theme.of(c).colorScheme.primary),
                const SizedBox(width: 10),
                Text(g[i], style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Text(g[3 + i], style: const TextStyle(fontSize: 16, height: 1.55)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(c), child: Text(t3(lang, 'Got it', 'ठीक है', 'సరే'))),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A small ⓘ that opens the meaning of [term].
class MeaningButton extends StatelessWidget {
  const MeaningButton(this.term, {super.key, required this.lang, this.color});
  final String term, lang;
  final Color? color;
  @override
  Widget build(BuildContext context) => InkResponse(
    radius: 18,
    onTap: () => showMeaning(context, lang, term),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(Icons.info_outline_rounded, size: 16, color: color ?? Theme.of(context).colorScheme.outline),
    ),
  );
}
