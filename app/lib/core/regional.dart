/// Regional ways of naming the day: Amanta or Purnimanta lunar months, and the Tamil, Malayalam,
/// Bengali and Odia solar calendars.
///
/// The server sends lunar months the Amanta way (a month runs new moon to new moon, 0 = Chaitra) and,
/// per day of the month summary, each solar calendar's month and day (`solar`: {"ta": [6, 27], ...},
/// month 0 = the Sun in Mesha). The rules that decide day 1 of a solar month are in
/// backend/app/services/panchang.py (SOLAR_RULES).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'i18n.dart';
import 'muhurta.dart';
import 'names.dart';
import 'storage.dart';

// ---------------------------------------------------------------------------
// Amanta / Purnimanta
// ---------------------------------------------------------------------------

/// Amanta months end at the new moon (South and West India); Purnimanta months end at the full moon
/// (North India), so a Krishna paksha carries the name of the month that follows it. Shukla paksha
/// has the same name in both, which is why festivals keep their dates.
enum MonthSystem { amanta, purnimanta }

/// Hindi and Punjabi readers mostly follow Purnimanta; everyone else Amanta.
MonthSystem defaultMonthSystem(String lang) =>
    lang == 'hi' || lang == 'pa' ? MonthSystem.purnimanta : MonthSystem.amanta;

/// The month system chosen in Settings, or the default for [lang].
MonthSystem monthSystemFor(String lang) => switch (Boxes.prefs.get('month_system')) {
  'amanta' => MonthSystem.amanta,
  'purnimanta' => MonthSystem.purnimanta,
  _ => defaultMonthSystem(lang),
};

final monthSystemProvider = Provider<MonthSystem>((ref) {
  final lang = ref.watch(prefsProvider).language;
  return monthSystemFor(lang);
});

/// The month to show for Amanta month [amanta] (0 = Chaitra). In Purnimanta a Krishna paksha moves to
/// the next month, except in an Adhika month, which keeps both its fortnights: the Adhika month sits
/// whole between the Krishna and Shukla halves of the true month. In 2026 North Indian calendars list
/// Jyeshtha 2–16 May, Adhik Jyeshtha 17 May – 15 Jun, then Jyeshtha again 16–29 Jun
/// (https://www.hindu-blog.com/2026/05/extra-jyeshta-month-in-hindu-north.html).
({int index, bool adhika}) shownMonth(MonthSystem system, int amanta, {required bool krishna, bool adhika = false}) {
  if (system == MonthSystem.purnimanta && krishna && !adhika) return (index: (amanta + 1) % 12, adhika: false);
  return (index: amanta % 12, adhika: adhika);
}

/// [shownMonth] for one day of the month summary (lunar_month, adhika, paksha), or null.
({int index, bool adhika})? shownMonthOf(MonthSystem system, Map day) {
  final m = day['lunar_month'];
  if (m is! int) return null;
  final krishna = day['paksha'] == 'Krishna' || ((day['tithi_index'] as int? ?? 0) > 15);
  return shownMonth(system, m, krishna: krishna, adhika: day['adhika'] == true);
}

/// "Kartika" / "Adhika Jyeshtha" in [lang].
String shownMonthLabel(String lang, ({int index, bool adhika}) m) =>
    '${m.adhika ? '${t3(lang, 'Adhika', 'अधिक', 'అధిక')} ' : ''}${lunarMonthLabel(lang, m.index)}';

String monthSystemLabel(String lang, MonthSystem s) => switch (s) {
  MonthSystem.amanta => t3(
    lang,
    'Amanta (month ends on Amavasya)',
    'अमांत (अमावस्या पर मास पूरा)',
    'అమాంత (అమావాస్యతో మాసం ముగింపు)',
  ),
  MonthSystem.purnimanta => t3(
    lang,
    'Purnimanta (month ends on Purnima)',
    'पूर्णिमांत (पूर्णिमा पर मास पूरा)',
    'పూర్ణిమాంత (పౌర్ణమితో మాసం ముగింపు)',
  ),
};

// ---------------------------------------------------------------------------
// Solar calendars
// ---------------------------------------------------------------------------

/// The solar calendars the server computes, by the language that reads them.
const solarCalendars = ['ta', 'ml', 'bn', 'or'];

/// Month names, month 0 = Sun in Mesha (Tamil Chithirai, Malayalam Medam, Bengali Boishakh, Odia Baisakha).
const _solarMonthsEn = <String, List<String>>{
  'ta': [
    'Chithirai', 'Vaikasi', 'Aani', 'Aadi', 'Aavani', 'Purattasi', //
    'Aippasi', 'Karthigai', 'Margazhi', 'Thai', 'Maasi', 'Panguni',
  ],
  'ml': [
    'Medam', 'Edavam', 'Mithunam', 'Karkidakam', 'Chingam', 'Kanni', //
    'Thulam', 'Vrischikam', 'Dhanu', 'Makaram', 'Kumbham', 'Meenam',
  ],
  'bn': [
    'Boishakh', 'Joishtho', 'Asharh', 'Srabon', 'Bhadro', 'Ashwin', //
    'Kartik', 'Ogrohayon', 'Poush', 'Magh', 'Falgun', 'Choitro',
  ],
  'or': [
    'Baisakha', 'Jyeshtha', 'Ashadha', 'Shrabana', 'Bhadraba', 'Ashwina', //
    'Kartika', 'Margashira', 'Pausha', 'Magha', 'Phalguna', 'Chaitra',
  ],
};

const _solarMonthsNative = <String, List<String>>{
  'ta': [
    'சித்திரை', 'வைகாசி', 'ஆனி', 'ஆடி', 'ஆவணி', 'புரட்டாசி', //
    'ஐப்பசி', 'கார்த்திகை', 'மார்கழி', 'தை', 'மாசி', 'பங்குனி',
  ],
  'ml': [
    'മേടം', 'ഇടവം', 'മിഥുനം', 'കർക്കടകം', 'ചിങ്ങം', 'കന്നി', //
    'തുലാം', 'വൃശ്ചികം', 'ധനു', 'മകരം', 'കുംഭം', 'മീനം',
  ],
  'bn': [
    'বৈশাখ', 'জ্যৈষ্ঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন', //
    'কার্তিক', 'অগ্রহায়ণ', 'পৌষ', 'মাঘ', 'ফাল্গুন', 'চৈত্র',
  ],
  'or': [
    'ବୈଶାଖ', 'ଜ୍ୟେଷ୍ଠ', 'ଆଷାଢ଼', 'ଶ୍ରାବଣ', 'ଭାଦ୍ରବ', 'ଆଶ୍ୱିନ', //
    'କାର୍ତ୍ତିକ', 'ମାର୍ଗଶିର', 'ପୌଷ', 'ମାଘ', 'ଫାଲ୍ଗୁନ', 'ଚୈତ୍ର',
  ],
};

/// A solar month name: in its own script when the app is in that calendar's language, else in English.
String solarMonthName(String calendar, String lang, int month) =>
    (lang == calendar ? _solarMonthsNative : _solarMonthsEn)[calendar]![month % 12];

/// The calendar's name, for Settings.
String solarCalendarLabel(String lang, String calendar) => switch (calendar) {
  'ta' => t3(lang, 'Tamil solar calendar', 'तमिल सौर पंचांग', 'తమిళ సౌరమానం'),
  'ml' => t3(lang, 'Malayalam calendar (Kollam era)', 'मलयालम पंचांग (कोल्लम संवत)', 'మలయాళ క్యాలెండర్ (కొల్లం శకం)'),
  'bn' => t3(lang, 'Bengali calendar (Bangabda)', 'बंगाली पंचांग (बंगाब्द)', 'బెంగాలీ క్యాలెండర్ (బంగాబ్దం)'),
  _ => t3(lang, 'Odia solar calendar', 'ओड़िया सौर पंचांग', 'ఒడియా సౌరమానం'),
};

/// A day's date in [calendar], from the month summary's `solar` field.
class SolarDate {
  const SolarDate(this.calendar, this.month, this.day, this.gregorian);
  final String calendar;

  /// 0 = Sun in Mesha.
  final int month;
  final int day;
  final DateTime gregorian;

  static SolarDate? of(String calendar, Map summaryDay) {
    final v = (summaryDay['solar'] as Map?)?[calendar];
    if (v is! List || v.length < 2) return null;
    return SolarDate(calendar, v[0] as int, v[1] as int, DateTime.parse('${summaryDay['date']}'));
  }

  /// Whether the date falls after the calendar's New Year in its Gregorian year. Tamil, Bengali and
  /// Odia years start in Mesha (mid-April); the Kollam year starts in Chingam (Simha, mid-August).
  /// Months 9–11 (Makara to Meena) only fall early in the Gregorian year, month 8 (Dhanu) spans New Year.
  bool get _pastNewYear =>
      calendar == 'ml' ? gregorian.month >= 8 && month >= 4 && month <= 8 : gregorian.month >= 4 && month <= 8;

  /// Kollam era year (Malayalam): Chingam 1, 1202 is 17 Aug 2026.
  int get kollamYear => gregorian.year - 825 + (_pastNewYear ? 1 : 0);

  /// Bangabda (Bengali): Boishakh 1, 1433 is 15 Apr 2026.
  int get bangabda => gregorian.year - 594 + (_pastNewYear ? 1 : 0);

  /// The 60-year cycle index (0 = Prabhava) of the Tamil year: Chithirai 2026 begins Parabhava (39).
  int get tamilYearIndex => (gregorian.year - 79 + (_pastNewYear ? 1 : 0) + 11) % 60;

  /// "Aippasi 27" / "ஐப்பசி 27".
  String label(String lang) => '${solarMonthName(calendar, lang, month)} $day';

  /// The era for headers: "Parabhava", "Kollam 1202", "Bangabda 1433"; Odia shows none.
  String? era(String lang) => switch (calendar) {
    'ta' => samvatsaraIn(lang, tamilYearIndex, samvatsaraNames[tamilYearIndex]),
    'ml' => '${t3(lang, 'Kollam Era', 'कोल्लम संवत', 'కొల్లం శకం')} $kollamYear',
    'bn' => '${t3(lang, 'Bangabda', 'बंगाब्द', 'బంగాబ్దం')} $bangabda',
    _ => null,
  };
}

/// The 60-year cycle in English, Prabhava = 0 (as the server's SAMVATSARA_NAMES).
const samvatsaraNames = [
  'Prabhava', 'Vibhava', 'Shukla', 'Pramoduta', 'Prajotpatti', 'Angirasa', 'Shrimukha', 'Bhava', 'Yuva', //
  'Dhatri', 'Ishvara', 'Bahudhanya', 'Pramathi', 'Vikrama', 'Vrisha', 'Chitrabhanu', 'Svabhanu', 'Tarana',
  'Parthiva', 'Vyaya', 'Sarvajit', 'Sarvadhari', 'Virodhi', 'Vikriti', 'Khara', 'Nandana', 'Vijaya', 'Jaya',
  'Manmatha', 'Durmukhi', 'Hevilambi', 'Vilambi', 'Vikari', 'Sharvari', 'Plava', 'Shubhakrit', 'Shobhakrit',
  'Krodhi', 'Vishvavasu', 'Parabhava', 'Plavanga', 'Kilaka', 'Saumya', 'Sadharana', 'Virodhikrit', 'Paridhavi',
  'Pramadicha', 'Ananda', 'Rakshasa', 'Nala', 'Pingala', 'Kalayukti', 'Siddharthi', 'Raudri', 'Durmati',
  'Dundubhi', 'Rudhirodgari', 'Raktakshi', 'Krodhana', 'Akshaya',
];

/// The solar calendar shown alongside the Gregorian one: the Settings choice ("none" hides it), or by
/// default the one that matches the app language (Tamil, Malayalam, Bengali, Odia), else none.
String? solarCalendarFor(String lang) {
  final choice = Boxes.prefs.get('solar_calendar') as String?;
  if (choice == 'none') return null;
  if (solarCalendars.contains(choice)) return choice;
  return solarCalendars.contains(lang) ? lang : null;
}

final solarCalendarProvider = Provider<String?>((ref) {
  final lang = ref.watch(prefsProvider).language;
  return solarCalendarFor(lang);
});
