import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage.dart';

/// Lightweight Hindi/English strings. Content itself arrives bilingual from the API.
const _strings = <String, Map<String, String>>{
  'home': {'en': 'Home', 'hi': 'होम'},
  'listen': {'en': 'Listen', 'hi': 'सुनें'},
  'mandir': {'en': 'Mandir', 'hi': 'मंदिर'},
  'read': {'en': 'Read', 'hi': 'पढ़ें'},
  'more': {'en': 'More', 'hi': 'और'},
  'good_morning': {'en': 'Suprabhat', 'hi': 'सुप्रभात'},
  'good_afternoon': {'en': 'Namaste', 'hi': 'नमस्ते'},
  'good_evening': {'en': 'Shubh Sandhya', 'hi': 'शुभ संध्या'},
  'good_night': {'en': 'Shubh Ratri', 'hi': 'शुभ रात्रि'},
  'today_panchang': {'en': "Today's Panchang", 'hi': 'आज का पंचांग'},
  'tithi': {'en': 'Tithi', 'hi': 'तिथि'},
  'nakshatra': {'en': 'Nakshatra', 'hi': 'नक्षत्र'},
  'yoga': {'en': 'Yoga', 'hi': 'योग'},
  'karana': {'en': 'Karana', 'hi': 'करण'},
  'sunrise': {'en': 'Sunrise', 'hi': 'सूर्योदय'},
  'sunset': {'en': 'Sunset', 'hi': 'सूर्यास्त'},
  'rahu_kaal': {'en': 'Rahu Kaal', 'hi': 'राहु काल'},
  'abhijit': {'en': 'Abhijit Muhurta', 'hi': 'अभिजित मुहूर्त'},
  'upcoming_festivals': {'en': 'Upcoming festivals', 'hi': 'आने वाले त्योहार'},
  'verse_of_day': {'en': 'Gita verse of the day', 'hi': 'आज का गीता श्लोक'},
  'featured': {'en': 'Bhakti for today', 'hi': 'आज की भक्ति'},
  'aartis': {'en': 'Aarti', 'hi': 'आरती'},
  'wallpapers': {'en': 'Wallpapers', 'hi': 'वॉलपेपर'},
  'see_all': {'en': 'See all', 'hi': 'सभी देखें'},
  'rashifal': {'en': 'Rashifal', 'hi': 'राशिफल'},
  'japa': {'en': 'Japa Mala', 'hi': 'जाप माला'},
  'ai_status': {'en': 'AI Status', 'hi': 'AI स्टेटस'},
  'ringtones': {'en': 'Ringtones', 'hi': 'रिंगटोन'},
  'calendar': {'en': 'Calendar', 'hi': 'कैलेंडर'},
  'gita': {'en': 'Bhagavad Gita', 'hi': 'भगवद गीता'},
  'ask_gita': {'en': 'Ask the Gita', 'hi': 'गीता से पूछें'},
  'movies': {'en': 'Classic films', 'hi': 'क्लासिक फ़िल्में'},
  'books': {'en': 'Scriptures', 'hi': 'शास्त्र'},
  'search': {'en': 'Search', 'hi': 'खोजें'},
  'favorites': {'en': 'Favourites', 'hi': 'पसंदीदा'},
  'downloads': {'en': 'Downloads', 'hi': 'डाउनलोड'},
  'settings': {'en': 'Settings', 'hi': 'सेटिंग्स'},
  'premium': {'en': 'Premium', 'hi': 'प्रीमियम'},
  'retry': {'en': 'Try again', 'hi': 'फिर से कोशिश करें'},
  'offline': {'en': 'You are offline. Showing saved content.', 'hi': 'आप ऑफ़लाइन हैं। सहेजी गई सामग्री दिख रही है।'},
  'error': {'en': 'Could not load. Check your connection.', 'hi': 'लोड नहीं हो सका। इंटरनेट जाँचें।'},
  'light_diya': {'en': 'Light the diya', 'hi': 'दीप जलाएँ'},
  'offer_flowers': {'en': 'Offer flowers', 'hi': 'पुष्प अर्पित करें'},
  'ring_bell': {'en': 'Ring bell', 'hi': 'घंटी बजाएँ'},
  'blow_shankh': {'en': 'Shankh', 'hi': 'शंख'},
  'do_aarti': {'en': 'Aarti', 'hi': 'आरती'},
  'all': {'en': 'All', 'hi': 'सभी'},
  'bhajan': {'en': 'Bhajan', 'hi': 'भजन'},
  'aarti': {'en': 'Aarti', 'hi': 'आरती'},
  'mantra': {'en': 'Mantra', 'hi': 'मंत्र'},
  'chalisa': {'en': 'Chalisa', 'hi': 'चालीसा'},
  'dhun': {'en': 'Dhun', 'hi': 'धुन'},
  'ambient': {'en': 'Meditation', 'hi': 'ध्यान'},
  'stotra': {'en': 'Stotra', 'hi': 'स्तोत्र'},
  'stuti': {'en': 'Stuti', 'hi': 'स्तुति'},
  'days_left': {'en': 'days', 'hi': 'दिन'},
  'today': {'en': 'Today', 'hi': 'आज'},
  'tomorrow': {'en': 'Tomorrow', 'hi': 'कल'},
};

String tr(WidgetRef ref, String key) {
  final lang = ref.watch(prefsProvider.select((p) => p.language));
  return _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
}

String trLang(String lang, String key) => _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;

/// Picks the Hindi or English variant of a bilingual API field.
String pick(WidgetRef ref, String en, String hi) {
  final lang = ref.watch(prefsProvider.select((p) => p.language));
  return lang == 'hi' && hi.isNotEmpty ? hi : en;
}

extension BuildContextX on BuildContext {
  bool get isDark => MediaQuery.platformBrightnessOf(this) == Brightness.dark;
}
