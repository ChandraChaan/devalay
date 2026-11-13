import 'package:flutter/widgets.dart';

/// A language the whole app can be used in. [code] is the ISO 639-1 code used for prefs, string
/// tables (lib/l10n), Flutter's Material localizations and intl date formats.
@immutable
class AppLanguage {
  const AppLanguage(this.code, this.native, this.english, this.greeting);
  final String code;

  /// The name in its own script, as shown in the language picker.
  final String native;
  final String english;

  /// A short line in the language, shown under its name in the picker.
  final String greeting;

  Locale get locale => Locale(code);
}

/// English first (the default), then Indian languages roughly by number of speakers.
const appLanguages = <AppLanguage>[
  AppLanguage('en', 'English', 'English', 'Prayers, Panchang and festivals'),
  AppLanguage('hi', 'हिन्दी', 'Hindi', 'मंत्र, आरती और पंचांग हिन्दी में'),
  AppLanguage('bn', 'বাংলা', 'Bengali', 'মন্ত্র, আরতি ও পঞ্জিকা বাংলায়'),
  AppLanguage('mr', 'मराठी', 'Marathi', 'मंत्र, आरती आणि पंचांग मराठीत'),
  AppLanguage('te', 'తెలుగు', 'Telugu', 'పాటలు, పంచాంగం, శ్లోకాలు తెలుగులో'),
  AppLanguage('ta', 'தமிழ்', 'Tamil', 'மந்திரம், ஆரத்தி, பஞ்சாங்கம் தமிழில்'),
  AppLanguage('gu', 'ગુજરાતી', 'Gujarati', 'મંત્ર, આરતી અને પંચાંગ ગુજરાતીમાં'),
  AppLanguage('kn', 'ಕನ್ನಡ', 'Kannada', 'ಮಂತ್ರ, ಆರತಿ, ಪಂಚಾಂಗ ಕನ್ನಡದಲ್ಲಿ'),
  AppLanguage('ml', 'മലയാളം', 'Malayalam', 'മന്ത്രം, ആരതി, പഞ്ചാംഗം മലയാളത്തിൽ'),
  AppLanguage('or', 'ଓଡ଼ିଆ', 'Odia', 'ମନ୍ତ୍ର, ଆରତି ଓ ପଞ୍ଜିକା ଓଡ଼ିଆରେ'),
  AppLanguage('pa', 'ਪੰਜਾਬੀ', 'Punjabi', 'ਮੰਤਰ, ਆਰਤੀ ਅਤੇ ਪੰਚਾਂਗ ਪੰਜਾਬੀ ਵਿੱਚ'),
];

AppLanguage languageOf(String code) => appLanguages.firstWhere((l) => l.code == code, orElse: () => appLanguages.first);

bool isSupportedLanguage(String code) => appLanguages.any((l) => l.code == code);

/// "Devalay" in the script of [code], for the welcome screen.
String appNameIn(String code) => switch (code) {
  'te' => 'దేవాలయం',
  'kn' => 'ದೇವಾಲಯ',
  'ml' => 'ദേവാലയ്',
  'gu' => 'દેવાલય',
  'bn' => 'দেবালয়',
  'or' => 'ଦେବାଳୟ',
  'pa' => 'ਦੇਵਾਲਯ',
  _ => 'देवालय',
};
