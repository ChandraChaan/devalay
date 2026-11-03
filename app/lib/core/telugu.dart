/// Telugu support that does not need the API: Devanagari to Telugu script, and Telugu names
/// for deities, cities, Panchang elements and festivals, keyed by the API's slugs and names.
library;

/// Devanagari and Telugu share the ISCII layout, so most letters sit exactly 0x300 apart.
/// Sanskrit transliterates exactly; Hindi words keep their written (not spoken) vowels.
String toTeluguScript(String s) {
  final out = StringBuffer();
  for (final rune in s.runes) {
    if (rune < 0x0900 || rune > 0x097F) {
      out.writeCharCode(rune);
      continue;
    }
    final mapped = _devanagariToTelugu(rune);
    if (mapped != null) out.write(mapped);
  }
  return out.toString();
}

String? _devanagariToTelugu(int c) {
  switch (c) {
    case 0x0950:
      return 'ఓం'; // Om has no single Telugu sign
    case 0x0964 || 0x0965:
      return String.fromCharCode(c); // dandas are shared
    case 0x093C || 0x0951 || 0x0952 || 0x0953 || 0x0954 || 0x093A || 0x093B || 0x094E || 0x094F:
      return null; // nukta and Vedic accents
    case 0x090D || 0x0911:
      return String.fromCharCode(c == 0x090D ? 0x0C0E : 0x0C12); // candra e/o
    case 0x0945 || 0x0949:
      return String.fromCharCode(c == 0x0945 ? 0x0C46 : 0x0C4A);
    case 0x0929:
      return 'న';
  }
  if (c >= 0x0958 && c <= 0x095F) {
    const base = [0x0915, 0x0916, 0x0917, 0x091C, 0x0921, 0x0922, 0x092B, 0x092F];
    return String.fromCharCode(base[c - 0x0958] + 0x300);
  }
  if (c >= 0x0966 && c <= 0x096F) return '${c - 0x0966}';
  return String.fromCharCode(c + 0x300);
}

const teluguDeities = <String, String>{
  'shiva': 'శివుడు',
  'hanuman': 'ఆంజనేయ స్వామి',
  'ganesha': 'వినాయకుడు',
  'vishnu': 'శ్రీ మహావిష్ణువు',
  'venkateswara': 'శ్రీ వేంకటేశ్వర స్వామి',
  'lakshmi': 'లక్ష్మీదేవి',
  'shani': 'శనిదేవుడు',
  'surya': 'సూర్యభగవానుడు',
  'rama': 'శ్రీరాముడు',
  'krishna': 'శ్రీకృష్ణుడు',
  'radha-krishna': 'రాధాకృష్ణులు',
  'durga': 'దుర్గమ్మ',
  'kali': 'కాళీమాత',
  'saraswati': 'సరస్వతీదేవి',
  'general': 'అన్ని భక్తి',
};

/// Telugu households pray to a deity each weekday (Mon=0); Saturday is Venkateswara's day.
const teluguWeekdayDeity = ['shiva', 'hanuman', 'ganesha', 'vishnu', 'lakshmi', 'venkateswara', 'surya'];

const teluguCities = <String, String>{
  'delhi': 'న్యూఢిల్లీ',
  'mumbai': 'ముంబై',
  'kolkata': 'కోల్‌కతా',
  'chennai': 'చెన్నై',
  'bengaluru': 'బెంగళూరు',
  'hyderabad': 'హైదరాబాద్',
  'vijayawada': 'విజయవాడ',
  'visakhapatnam': 'విశాఖపట్నం',
  'tirupati': 'తిరుపతి',
  'guntur': 'గుంటూరు',
  'warangal': 'వరంగల్',
  'nellore': 'నెల్లూరు',
  'kurnool': 'కర్నూలు',
  'rajahmundry': 'రాజమహేంద్రవరం',
  'kakinada': 'కాకినాడ',
  'karimnagar': 'కరీంనగర్',
  'khammam': 'ఖమ్మం',
  'nizamabad': 'నిజామాబాద్',
  'anantapur': 'అనంతపురం',
  'kadapa': 'కడప',
  'srikakulam': 'శ్రీకాకుళం',
  'ongole': 'ఒంగోలు',
  'eluru': 'ఏలూరు',
  'srisailam': 'శ్రీశైలం',
  'bhadrachalam': 'భద్రాచలం',
  'ahmedabad': 'అహ్మదాబాద్',
  'pune': 'పుణె',
  'jaipur': 'జైపూర్',
  'lucknow': 'లక్నో',
  'patna': 'పాట్నా',
  'bhopal': 'భోపాల్',
  'varanasi': 'వారణాసి',
  'ayodhya': 'అయోధ్య',
  'ujjain': 'ఉజ్జయిని',
  'haridwar': 'హరిద్వార్',
  'mathura': 'మథుర',
  'puri': 'పూరి',
  'guwahati': 'గువాహటి',
  'kochi': 'కొచ్చి',
  'kathmandu': 'ఖాట్మండు',
  'dubai': 'దుబాయ్',
  'singapore': 'సింగపూర్',
  'london': 'లండన్',
  'new-york': 'న్యూయార్క్',
  'toronto': 'టొరంటో',
  'san-francisco': 'శాన్ ఫ్రాన్సిస్కో',
  'sydney': 'సిడ్నీ',
};

/// Tithi names by the API's English name. Telugu calendars say Padyami, Vidiya, Tadiya...
const teluguTithi = <String, String>{
  'Pratipada': 'పాడ్యమి',
  'Dwitiya': 'విదియ',
  'Tritiya': 'తదియ',
  'Chaturthi': 'చవితి',
  'Panchami': 'పంచమి',
  'Shashthi': 'షష్ఠి',
  'Saptami': 'సప్తమి',
  'Ashtami': 'అష్టమి',
  'Navami': 'నవమి',
  'Dashami': 'దశమి',
  'Ekadashi': 'ఏకాదశి',
  'Dwadashi': 'ద్వాదశి',
  'Trayodashi': 'త్రయోదశి',
  'Chaturdashi': 'చతుర్దశి',
  'Purnima': 'పౌర్ణమి',
  'Amavasya': 'అమావాస్య',
};

const teluguPaksha = {'Shukla': 'శుక్ల పక్షం', 'Krishna': 'బహుళ పక్షం'};

/// Indexed 1-27 like the API (Ashwini = 1).
const teluguNakshatra = [
  '',
  'అశ్విని',
  'భరణి',
  'కృత్తిక',
  'రోహిణి',
  'మృగశిర',
  'ఆర్ద్ర',
  'పునర్వసు',
  'పుష్యమి',
  'ఆశ్లేష',
  'మఖ',
  'పుబ్బ',
  'ఉత్తర',
  'హస్త',
  'చిత్త',
  'స్వాతి',
  'విశాఖ',
  'అనూరాధ',
  'జ్యేష్ఠ',
  'మూల',
  'పూర్వాషాఢ',
  'ఉత్తరాషాఢ',
  'శ్రవణం',
  'ధనిష్ఠ',
  'శతభిషం',
  'పూర్వాభాద్ర',
  'ఉత్తరాభాద్ర',
  'రేవతి',
];

/// Indexed 1-27 like the API (Vishkambha = 1).
const teluguYoga = [
  '',
  'విష్కంభం',
  'ప్రీతి',
  'ఆయుష్మాన్',
  'సౌభాగ్యం',
  'శోభనం',
  'అతిగండం',
  'సుకర్మ',
  'ధృతి',
  'శూలం',
  'గండం',
  'వృద్ధి',
  'ధ్రువం',
  'వ్యాఘాతం',
  'హర్షణం',
  'వజ్రం',
  'సిద్ధి',
  'వ్యతీపాతం',
  'వరీయాన్',
  'పరిఘం',
  'శివం',
  'సిద్ధం',
  'సాధ్యం',
  'శుభం',
  'శుక్లం',
  'బ్రహ్మం',
  'ఐంద్రం',
  'వైధృతి',
];

const teluguKarana = <String, String>{
  'Bava': 'బవ',
  'Balava': 'బాలవ',
  'Kaulava': 'కౌలవ',
  'Taitila': 'తైతుల',
  'Gara': 'గరజి',
  'Vanija': 'వణిజ',
  'Vishti': 'విష్టి (భద్ర)',
  'Shakuni': 'శకుని',
  'Chatushpada': 'చతుష్పాద',
  'Naga': 'నాగవం',
  'Kimstughna': 'కింస్తుఘ్నం',
};

/// Lunar months, Chaitra = index 0 (the API's lunar_month.index).
const teluguMonths = [
  'చైత్రం',
  'వైశాఖం',
  'జ్యేష్ఠం',
  'ఆషాఢం',
  'శ్రావణం',
  'భాద్రపదం',
  'ఆశ్వయుజం',
  'కార్తీకం',
  'మార్గశిరం',
  'పుష్యం',
  'మాఘం',
  'ఫాల్గుణం',
];

const teluguVara = <String, String>{
  'Somavara': 'సోమవారం',
  'Mangalavara': 'మంగళవారం',
  'Budhavara': 'బుధవారం',
  'Guruvara': 'గురువారం',
  'Shukravara': 'శుక్రవారం',
  'Shanivara': 'శనివారం',
  'Ravivara': 'ఆదివారం',
};

/// Mon=0, like DateTime.weekday - 1.
const teluguWeekdays = ['సోమవారం', 'మంగళవారం', 'బుధవారం', 'గురువారం', 'శుక్రవారం', 'శనివారం', 'ఆదివారం'];

const teluguRashi = <String, String>{
  'Mesha': 'మేషం',
  'Vrishabha': 'వృషభం',
  'Mithuna': 'మిథునం',
  'Karka': 'కర్కాటకం',
  'Simha': 'సింహం',
  'Kanya': 'కన్య',
  'Tula': 'తుల',
  'Vrishchika': 'వృశ్చికం',
  'Dhanu': 'ధనుస్సు',
  'Makara': 'మకరం',
  'Kumbha': 'కుంభం',
  'Meena': 'మీనం',
};

/// By the API's rashi slug (mesha, vrishabha, ...).
const teluguRashiBySlug = <String, String>{
  'mesha': 'మేషం',
  'vrishabha': 'వృషభం',
  'mithuna': 'మిథునం',
  'karka': 'కర్కాటకం',
  'simha': 'సింహం',
  'kanya': 'కన్య',
  'tula': 'తుల',
  'vrishchika': 'వృశ్చికం',
  'dhanu': 'ధనుస్సు',
  'makara': 'మకరం',
  'kumbha': 'కుంభం',
  'meena': 'మీనం',
};

/// The 60-year cycle, Prabhava = 0 (the API's samvatsara.index). Ugadi starts each year.
const teluguSamvatsara = [
  'ప్రభవ', 'విభవ', 'శుక్ల', 'ప్రమోదూత', 'ప్రజోత్పత్తి', 'ఆంగీరస', 'శ్రీముఖ', 'భావ', 'యువ', 'ధాత', //
  'ఈశ్వర', 'బహుధాన్య', 'ప్రమాది', 'విక్రమ', 'వృష', 'చిత్రభాను', 'స్వభాను', 'తారణ', 'పార్థివ', 'వ్యయ', //
  'సర్వజిత్', 'సర్వధారి', 'విరోధి', 'వికృతి', 'ఖర', 'నందన', 'విజయ', 'జయ', 'మన్మథ', 'దుర్ముఖి', //
  'హేవిళంబి', 'విళంబి', 'వికారి', 'శార్వరి', 'ప్లవ', 'శుభకృత్', 'శోభకృత్', 'క్రోధి', 'విశ్వావసు', 'పరాభవ', //
  'ప్లవంగ', 'కీలక', 'సౌమ్య', 'సాధారణ', 'విరోధికృత్', 'పరీధావి', 'ప్రమాదీచ', 'ఆనంద', 'రాక్షస', 'నల', //
  'పింగళ', 'కాళయుక్తి', 'సిద్ధార్థి', 'రౌద్రి', 'దుర్మతి', 'దుందుభి', 'రుధిరోద్గారి', 'రక్తాక్షి', 'క్రోధన', 'అక్షయ',
];

/// Festival names by slug; recurring observances use their `kind`.
const teluguFestivals = <String, String>{
  'makar-sankranti': 'మకర సంక్రాంతి',
  'bhogi': 'భోగి',
  'kanuma': 'కనుమ',
  'ratha-saptami': 'రథసప్తమి',
  'vasant-panchami': 'వసంత పంచమి',
  'maha-shivratri': 'మహా శివరాత్రి',
  'holika-dahan': 'కామదహనం',
  'holi': 'హోళీ',
  'ugadi': 'ఉగాది',
  'ram-navami': 'శ్రీరామ నవమి',
  'hanuman-jayanti': 'హనుమాన్ జయంతి',
  'akshaya-tritiya': 'అక్షయ తృతీయ',
  'buddha-purnima': 'బుద్ధ పౌర్ణమి',
  'ganga-dussehra': 'గంగా దశహరా',
  'nirjala-ekadashi': 'నిర్జల ఏకాదశి',
  'rath-yatra': 'జగన్నాథ రథయాత్ర',
  'devshayani-ekadashi': 'తొలి ఏకాదశి',
  'guru-purnima': 'గురు పౌర్ణమి',
  'nag-panchami': 'నాగ పంచమి',
  'varalakshmi-vratam': 'వరలక్ష్మీ వ్రతం',
  'raksha-bandhan': 'రాఖీ పౌర్ణమి',
  'janmashtami': 'శ్రీకృష్ణ జన్మాష్టమి',
  'hartalika-teej': 'హరితాళిక వ్రతం',
  'ganesh-chaturthi': 'వినాయక చవితి',
  'anant-chaturdashi': 'అనంత చతుర్దశి',
  'pitru-paksha': 'మహాలయ పక్షం ప్రారంభం',
  'engili-pula-bathukamma': 'ఎంగిలి పూల బతుకమ్మ',
  'sharad-navratri': 'దసరా నవరాత్రులు ప్రారంభం',
  'durga-ashtami': 'దుర్గాష్టమి',
  'saddula-bathukamma': 'సద్దుల బతుకమ్మ',
  'dussehra': 'విజయదశమి (దసరా)',
  'sharad-purnima': 'శరత్ పౌర్ణమి',
  'atla-taddi': 'అట్లతద్ది',
  'karwa-chauth': 'కర్వా చౌత్',
  'dhanteras': 'ధన త్రయోదశి',
  'narak-chaturdashi': 'నరక చతుర్దశి',
  'diwali': 'దీపావళి',
  'govardhan-puja': 'గోవర్ధన పూజ',
  'bhai-dooj': 'భగినీ హస్త భోజనం',
  'naga-chaturthi': 'నాగుల చవితి',
  'chhath-puja': 'ఛఠ్ పూజ',
  'dev-uthani-ekadashi': 'ఉత్థాన ఏకాదశి',
  'kartik-purnima': 'కార్తీక పౌర్ణమి',
  'vivah-panchami': 'వివాహ పంచమి',
  'gita-jayanti': 'గీతా జయంతి',
  'ekadashi': 'ఏకాదశి',
  'purnima': 'పౌర్ణమి',
  'amavasya': 'అమావాస్య',
  'pradosh': 'ప్రదోషం',
  'sankashti': 'సంకటహర చతుర్థి',
  'masik-shivratri': 'మాస శివరాత్రి',
};

/// Telugu titles for the Telugu and Carnatic recordings, by track slug.
const teluguTrackTitles = <String, String>{
  'annamacharya-brahma-kadigina-paadamu': 'బ్రహ్మ కడిగిన పాదము – అన్నమాచార్య',
  'annamacharya-jo-achyutananda': 'జో అచ్యుతానంద – అన్నమాచార్య',
  'annamacharya-shriman-narayana': 'శ్రీమన్నారాయణ – అన్నమాచార్య',
  'srinivasa-thiruvenkata': 'శ్రీనివాస తిరువేంకట',
  'nagumomu-tyagaraja': 'నగుమోము – త్యాగరాజ కృతి',
  'siva-panchakshara-mss': 'శివ పంచాక్షర స్తోత్రం',
  'ganesha-pancharatnam-mss': 'గణేశ పంచరత్నం',
  'morning-stotrams-mss': 'ఉదయ స్తోత్రాలు',
  'ramadasu-bhajans-balamurali': 'భద్రాచల రామదాసు కీర్తనలు',
  'ramadasu-keerthanalu-balamurali': 'రామదాసు కీర్తనలు – 2',
  'annamacharya-greatest-mss': 'అన్నమాచార్య కీర్తనలు',
  'annamacharya-samkirtanas-mss': 'అన్నమాచార్య సంకీర్తనలు',
  'bhaja-govindam-mss': 'భజ గోవిందం',
  'pb-sreenivas-devotional': 'పి.బి. శ్రీనివాస్ భక్తి గీతాలు',
  'shiva-songs-mss': 'శివ కీర్తనలు',
  'vishnu-melodies-mss': 'విష్ణు కీర్తనలు',
};

const teluguGregorianMonths = [
  'జనవరి',
  'ఫిబ్రవరి',
  'మార్చి',
  'ఏప్రిల్',
  'మే',
  'జూన్',
  'జూలై',
  'ఆగస్టు',
  'సెప్టెంబర్',
  'అక్టోబర్',
  'నవంబర్',
  'డిసెంబర్',
];

/// Mon..Sun column headers for a month grid.
const teluguWeekdayShort = ['సో', 'మం', 'బు', 'గు', 'శు', 'శ', 'ఆ'];

/// Two lunar months make a ritu (season), starting with Vasanta in Chaitra.
const teluguRitu = ['వసంత', 'గ్రీష్మ', 'వర్ష', 'శరద్', 'హేమంత', 'శిశిర'];

String teluguDate(DateTime d) =>
    '${teluguWeekdays[d.weekday - 1]}, ${d.day} ${teluguGregorianMonths[d.month - 1]} ${d.year}';
