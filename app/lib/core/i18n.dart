import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage.dart';
import 'telugu.dart';

/// UI strings in English, Hindi and Telugu. Content arrives in English and Hindi from the API;
/// Telugu names come from core/telugu.dart and Sanskrit is shown in Telugu script there.
const _strings = <String, Map<String, String>>{
  'home': {'en': 'Home', 'hi': 'होम', 'te': 'హోమ్'},
  'listen': {'en': 'Listen', 'hi': 'सुनें', 'te': 'వినండి'},
  'mandir': {'en': 'Mandir', 'hi': 'मंदिर', 'te': 'మందిరం'},
  'read': {'en': 'Read', 'hi': 'पढ़ें', 'te': 'చదవండి'},
  'more': {'en': 'More', 'hi': 'और', 'te': 'మరిన్ని'},
  'good_morning': {'en': 'Suprabhat', 'hi': 'सुप्रभात', 'te': 'శుభోదయం'},
  'good_afternoon': {'en': 'Namaste', 'hi': 'नमस्ते', 'te': 'నమస్కారం'},
  'good_evening': {'en': 'Shubh Sandhya', 'hi': 'शुभ संध्या', 'te': 'శుభ సాయంత్రం'},
  'good_night': {'en': 'Shubh Ratri', 'hi': 'शुभ रात्रि', 'te': 'శుభ రాత్రి'},
  'today_panchang': {'en': "Today's Panchang", 'hi': 'आज का पंचांग', 'te': 'నేటి పంచాంగం'},
  'tithi': {'en': 'Tithi', 'hi': 'तिथि', 'te': 'తిథి'},
  'nakshatra': {'en': 'Nakshatra', 'hi': 'नक्षत्र', 'te': 'నక్షత్రం'},
  'yoga': {'en': 'Yoga', 'hi': 'योग', 'te': 'యోగం'},
  'karana': {'en': 'Karana', 'hi': 'करण', 'te': 'కరణం'},
  'sunrise': {'en': 'Sunrise', 'hi': 'सूर्योदय', 'te': 'సూర్యోదయం'},
  'sunset': {'en': 'Sunset', 'hi': 'सूर्यास्त', 'te': 'సూర్యాస్తమయం'},
  'rahu_kaal': {'en': 'Rahu Kaal', 'hi': 'राहु काल', 'te': 'రాహుకాలం'},
  'abhijit': {'en': 'Abhijit Muhurta', 'hi': 'अभिजित मुहूर्त', 'te': 'అభిజిత్ ముహూర్తం'},
  'upcoming_festivals': {'en': 'Upcoming festivals', 'hi': 'आने वाले त्योहार', 'te': 'రాబోయే పండుగలు'},
  'verse_of_day': {'en': 'Gita verse of the day', 'hi': 'आज का गीता श्लोक', 'te': 'నేటి గీతా శ్లోకం'},
  'featured': {'en': 'Bhakti for today', 'hi': 'आज की भक्ति', 'te': 'నేటి భక్తి'},
  'aartis': {'en': 'Aarti', 'hi': 'आरती', 'te': 'హారతి'},
  'wallpapers': {'en': 'Wallpapers', 'hi': 'वॉलपेपर', 'te': 'వాల్‌పేపర్లు'},
  'see_all': {'en': 'See all', 'hi': 'सभी देखें', 'te': 'అన్నీ చూడండి'},
  'rashifal': {'en': 'Rashifal', 'hi': 'राशिफल', 'te': 'రాశిఫలాలు'},
  'japa': {'en': 'Japa Mala', 'hi': 'जाप माला', 'te': 'జపమాల'},
  'ai_status': {'en': 'AI Status', 'hi': 'AI स्टेटस', 'te': 'భక్తి స్టేటస్'},
  'ringtones': {'en': 'Ringtones', 'hi': 'रिंगटोन', 'te': 'రింగ్‌టోన్లు'},
  'calendar': {'en': 'Calendar', 'hi': 'कैलेंडर', 'te': 'క్యాలెండర్'},
  'gita': {'en': 'Bhagavad Gita', 'hi': 'भगवद गीता', 'te': 'భగవద్గీత'},
  'ask_gita': {'en': 'Ask the Gita', 'hi': 'गीता से पूछें', 'te': 'గీతను అడగండి'},
  'movies': {'en': 'Classic films', 'hi': 'क्लासिक फ़िल्में', 'te': 'పాత భక్తి చిత్రాలు'},
  'books': {'en': 'Scriptures', 'hi': 'शास्त्र', 'te': 'గ్రంథాలు'},
  'search': {'en': 'Search', 'hi': 'खोजें', 'te': 'వెతకండి'},
  'favorites': {'en': 'Favourites', 'hi': 'पसंदीदा', 'te': 'ఇష్టమైనవి'},
  'downloads': {'en': 'Downloads', 'hi': 'डाउनलोड', 'te': 'డౌన్‌లోడ్లు'},
  'settings': {'en': 'Settings', 'hi': 'सेटिंग्स', 'te': 'సెట్టింగ్స్'},
  'premium': {'en': 'Premium', 'hi': 'प्रीमियम', 'te': 'ప్రీమియం'},
  'retry': {'en': 'Try again', 'hi': 'फिर से कोशिश करें', 'te': 'మళ్ళీ ప్రయత్నించండి'},
  'offline': {
    'en': 'You are offline. Showing saved content.',
    'hi': 'आप ऑफ़लाइन हैं। सहेजी गई सामग्री दिख रही है।',
    'te': 'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. దాచిన కంటెంట్ చూపిస్తున్నాం.',
  },
  'error': {
    'en': 'Could not load. Check your connection.',
    'hi': 'लोड नहीं हो सका। इंटरनेट जाँचें।',
    'te': 'లోడ్ కాలేదు. ఇంటర్నెట్ చూసుకోండి.',
  },
  'light_diya': {'en': 'Light the diya', 'hi': 'दीप जलाएँ', 'te': 'దీపం వెలిగించండి'},
  'offer_flowers': {'en': 'Offer flowers', 'hi': 'पुष्प अर्पित करें', 'te': 'పూలు సమర్పించండి'},
  'ring_bell': {'en': 'Ring bell', 'hi': 'घंटी बजाएँ', 'te': 'గంట కొట్టండి'},
  'blow_shankh': {'en': 'Shankh', 'hi': 'शंख', 'te': 'శంఖం'},
  'do_aarti': {'en': 'Aarti', 'hi': 'आरती', 'te': 'హారతి'},
  'all': {'en': 'All', 'hi': 'सभी', 'te': 'అన్నీ'},
  'bhajan': {'en': 'Bhajan', 'hi': 'भजन', 'te': 'భజన'},
  'aarti': {'en': 'Aarti', 'hi': 'आरती', 'te': 'హారతి'},
  'mantra': {'en': 'Mantra', 'hi': 'मंत्र', 'te': 'మంత్రం'},
  'chalisa': {'en': 'Chalisa', 'hi': 'चालीसा', 'te': 'చాలీసా'},
  'dhun': {'en': 'Dhun', 'hi': 'धुन', 'te': 'ధున్'},
  'ambient': {'en': 'Meditation', 'hi': 'ध्यान', 'te': 'ధ్యానం'},
  'stotra': {'en': 'Stotra', 'hi': 'स्तोत्र', 'te': 'స్తోత్రం'},
  'stuti': {'en': 'Stuti', 'hi': 'स्तुति', 'te': 'స్తుతి'},
  'days_left': {'en': 'days', 'hi': 'दिन', 'te': 'రోజులు'},
  'today': {'en': 'Today', 'hi': 'आज', 'te': 'ఈ రోజు'},
  'videos': {'en': 'Bhakti videos', 'hi': 'भक्ति वीडियो', 'te': 'భక్తి వీడియోలు'},
  'panchang': {'en': 'Panchang', 'hi': 'पंचांग', 'te': 'పంచాంగం'},
  'tomorrow': {'en': 'Tomorrow', 'hi': 'कल', 'te': 'రేపు'},
  'temple_booking': {'en': 'Temple booking', 'hi': 'मंदिर बुकिंग', 'te': 'ఆలయ బుకింగ్'},
  'booking': {'en': 'Booking', 'hi': 'बुकिंग', 'te': 'బుకింగ్'},
  'wishes': {'en': 'Festival wishes', 'hi': 'त्योहार शुभकामनाएँ', 'te': 'పండుగ శుభాకాంక్షలు'},
};

String tr(WidgetRef ref, String key) {
  final lang = ref.watch(prefsProvider.select((p) => p.language));
  return _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
}

String trLang(String lang, String key) => _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;

/// Picks the variant of an API field for the UI language. Telugu uses [te] when the app has a
/// Telugu name for it, otherwise the Hindi text in Telugu script (how Telugu books print aartis).
String pick(WidgetRef ref, String en, String hi, {String? te}) {
  final lang = ref.watch(prefsProvider.select((p) => p.language));
  return pickLang(lang, en, hi, te: te);
}

String pickLang(String lang, String en, String hi, {String? te}) => switch (lang) {
  'hi' when hi.isNotEmpty => hi,
  'te' when te != null && te.isNotEmpty => te,
  'te' when hi.isNotEmpty => toTeluguScript(hi),
  _ => en,
};

String uiLang(WidgetRef ref) => ref.watch(prefsProvider.select((p) => p.language));

/// [t3] for the current UI language.
String l3(WidgetRef ref, String en, String hi, String te) =>
    t3(ref.watch(prefsProvider.select((p) => p.language)), en, hi, te);

/// Three-way inline text for UI copy that is not shared enough to live in [_strings].
String t3(String lang, String en, String hi, String te) => switch (lang) {
  'hi' => hi,
  'te' => te,
  _ => en,
};

extension BuildContextX on BuildContext {
  bool get isDark => MediaQuery.platformBrightnessOf(this) == Brightness.dark;
}
