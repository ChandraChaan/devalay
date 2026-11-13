/// Panchang names (tithi, nakshatra, yoga, karana, vara, month, rashi, samvatsara, ritu) and
/// calendar dates in the reader's language. Telugu keeps its hand-made tables (core/telugu.dart);
/// Hindi and the other languages come from lib/l10n; dates use intl's native month and day names.
library;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'i18n.dart';
import 'languages.dart';
import 'telugu.dart';

/// Loads intl's month and weekday names for every app language, with Western digits (as Indian
/// calendars print dates). Call once at startup; without it [fmtDate] falls back to English.
Future<void> initDates() async {
  await initializeDateFormatting();
  for (final l in appLanguages) {
    DateFormat.useNativeDigitsByDefaultFor(l.code, false);
  }
}

/// [d] formatted with an intl [pattern] in [lang]. Indian languages get full month names, since
/// their abbreviations are rarely used.
String fmtDate(String lang, String pattern, DateTime d) {
  if (lang == 'en') return DateFormat(pattern).format(d);
  try {
    return DateFormat(pattern.replaceAll(RegExp(r'(?<!M)MMM(?!M)'), 'MMMM'), lang).format(d);
  } catch (_) {
    return DateFormat(pattern).format(d);
  }
}

/// Short weekday headers, Sunday first.
List<String> weekdayInitials(String lang) {
  final sunday = DateTime(2026, 11, 15);
  return [for (var i = 0; i < 7; i++) fmtDate(lang, 'EEE', sunday.add(Duration(days: i)))];
}

const _nakshatras = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra', 'Punarvasu', 'Pushya', 'Ashlesha', //
  'Magha', 'Purva Phalguni', 'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha',
  'Jyeshtha', 'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana', 'Dhanishta', 'Shatabhisha',
  'Purva Bhadrapada', 'Uttara Bhadrapada', 'Revati',
];

String tithiIn(String lang, String name) => nameIn(lang, name, te: teluguTithi[name]);

/// "Shukla" / "Krishna" (Telugu adds పక్షం).
String pakshaIn(String lang, String paksha) => nameIn(
  lang,
  paksha,
  te: teluguPaksha[paksha],
  hi: switch (paksha) {
    'Shukla' => 'शुक्ल',
    'Krishna' => 'कृष्ण',
    _ => null,
  },
);

String nakshatraIn(String lang, String name) {
  final i = _nakshatras.indexOf(name);
  return nameIn(lang, name, te: i < 0 ? null : teluguNakshatra[i + 1]);
}

/// [index] is the API's 1-based yoga index.
String yogaIn(String lang, String name, int index) =>
    nameIn(lang, name, te: index > 0 && index < teluguYoga.length ? teluguYoga[index] : null);

String karanaIn(String lang, String name) => nameIn(lang, name, te: teluguKarana[name]);

/// Weekday from the API's vara name (Somavara ...).
String varaIn(String lang, String vara) => nameIn(lang, vara, te: teluguVara[vara]);

String rashiIn(String lang, String name) => nameIn(lang, name, te: teluguRashi[name]);

const _months = [
  'Chaitra', 'Vaishakha', 'Jyeshtha', 'Ashadha', 'Shravana', 'Bhadrapada', //
  'Ashwin', 'Kartika', 'Margashirsha', 'Pausha', 'Magha', 'Phalguna',
];

/// Jyeshtha, Shravana and Magha are nakshatras too; the l10n tables hold their nakshatra forms.
const _monthForms = <String, Map<String, String>>{
  'hi': {'Jyeshtha': 'ज्येष्ठ', 'Shravana': 'श्रावण', 'Magha': 'माघ'},
  'mr': {'Jyeshtha': 'ज्येष्ठ', 'Shravana': 'श्रावण', 'Magha': 'माघ'},
  'bn': {'Jyeshtha': 'জ্যৈষ্ঠ', 'Shravana': 'শ্রাবণ', 'Magha': 'মাঘ'},
  'ta': {'Jyeshtha': 'ஜ்யேஷ்டம்', 'Shravana': 'ஸ்ராவணம்', 'Magha': 'மாகம்'},
  'gu': {'Jyeshtha': 'જેઠ', 'Shravana': 'શ્રાવણ', 'Magha': 'મહા'},
  'kn': {'Jyeshtha': 'ಜ್ಯೇಷ್ಠ', 'Shravana': 'ಶ್ರಾವಣ', 'Magha': 'ಮಾಘ'},
  'ml': {'Jyeshtha': 'ജ്യേഷ്ഠം', 'Shravana': 'ശ്രാവണം', 'Magha': 'മാഘം'},
  'or': {'Jyeshtha': 'ଜ୍ୟେଷ୍ଠ', 'Shravana': 'ଶ୍ରାବଣ', 'Magha': 'ମାଘ'},
  'pa': {'Jyeshtha': 'ਜੇਠ', 'Shravana': 'ਸਾਵਣ', 'Magha': 'ਮਾਘ'},
};

/// Lunar month 0 (Chaitra) to 11 (Phalguna).
String monthIn(String lang, int index) {
  final en = _months[index % 12];
  if (lang == 'te') return teluguMonths[index % 12];
  return _monthForms[lang]?[en] ?? nameIn(lang, en);
}

/// The 60-year cycle name from the API's samvatsara index and English name.
String samvatsaraIn(String lang, int index, String name) =>
    nameIn(lang, name, te: index >= 0 && index < teluguSamvatsara.length ? teluguSamvatsara[index] : null);

const _ritus = ['Vasanta', 'Grishma', 'Varsha', 'Sharad', 'Hemanta', 'Shishira'];

/// Season 0 (Vasanta) to 5 (Shishira).
String rituIn(String lang, int index) => nameIn(lang, _ritus[index % 6], te: '${teluguRitu[index % 6]} ఋతువు');

String ayanaIn(String lang, bool uttarayana) => nameIn(
  lang,
  uttarayana ? 'Uttarayana' : 'Dakshinayana',
  te: uttarayana ? 'ఉత్తరాయణం' : 'దక్షిణాయనం',
  hi: uttarayana ? 'उत्तरायण' : 'दक्षिणायन',
);
