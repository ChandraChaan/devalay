import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'storage.dart';
import 'usage.dart';

/// Translation on the phone with Google ML Kit: free, private (text never leaves the phone) and offline
/// once the language (about 30 MB) is downloaded. Used to read the English meanings, Gita translations
/// and books in the reader's own language. Results are cached, so a page translated once opens at once.

/// App language → ML Kit language. Malayalam, Odia and Punjabi are not offered by ML Kit.
const translatableLanguages = <String, TranslateLanguage>{
  'te': TranslateLanguage.telugu,
  'hi': TranslateLanguage.hindi,
  'ta': TranslateLanguage.tamil,
  'kn': TranslateLanguage.kannada,
  'mr': TranslateLanguage.marathi,
  'bn': TranslateLanguage.bengali,
  'gu': TranslateLanguage.gujarati,
};

/// Language names for the picker, in their own script.
const translatableNames = <String, String>{
  'te': 'తెలుగు',
  'hi': 'हिन्दी',
  'ta': 'தமிழ்',
  'kn': 'ಕನ್ನಡ',
  'mr': 'मराठी',
  'bn': 'বাংলা',
  'gu': 'ગુજરાતી',
};

/// The language the reader translates into: the app language when it can, otherwise the last one chosen.
final translateTargetProvider = NotifierProvider<TranslateTarget, String?>(TranslateTarget.new);

class TranslateTarget extends Notifier<String?> {
  static const _key = 'translate_to';
  @override
  String? build() => Boxes.prefs.get(_key) as String?;
  Future<void> set(String? lang) async {
    state = lang;
    if (lang == null) {
      await Boxes.prefs.delete(_key);
    } else {
      await Boxes.prefs.put(_key, lang);
    }
  }
}

class Translation {
  Translation._();
  static final _translators = <String, OnDeviceTranslator>{};
  static final _models = OnDeviceTranslatorModelManager();

  static Future<bool> isReady(String lang) async {
    final l = translatableLanguages[lang];
    return l != null && await _models.isModelDownloaded(l.bcpCode);
  }

  /// Downloads the language once (works on mobile data too: the reader asked for it).
  static Future<bool> prepare(String lang) async {
    final l = translatableLanguages[lang];
    if (l == null) return false;
    if (await _models.isModelDownloaded(l.bcpCode)) return true;
    Usage.record('translate_download', item: lang);
    return _models.downloadModel(l.bcpCode, isWifiRequired: false);
  }

  /// [text] in [lang], paragraph by paragraph, cached on the phone.
  static Future<String> translate(String text, String lang) async {
    final l = translatableLanguages[lang];
    if (l == null || text.trim().isEmpty) return text;
    final key = cacheKey(text, lang);
    final cached = Boxes.cache.get(key);
    if (cached is String) return cached;
    final t = _translators.putIfAbsent(
      lang,
      () => OnDeviceTranslator(sourceLanguage: TranslateLanguage.english, targetLanguage: l),
    );
    final parts = <String>[];
    for (final para in text.split('\n')) {
      parts.add(para.trim().isEmpty ? para : await t.translateText(para));
    }
    final out = parts.join('\n');
    await Boxes.cache.put(key, out);
    return out;
  }

  @visibleForTesting
  static String cacheKey(String text, String lang) {
    // FNV-1a over the UTF-8 bytes: stable across runs, unlike String.hashCode.
    var h = 0x811c9dc5;
    for (final b in utf8.encode(text)) {
      h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    return 'tr:$lang:${h.toRadixString(16)}:${text.length}';
  }
}

/// Whether the readers show translations (one switch for texts, books and the Gita).
final translateOnProvider = NotifierProvider<TranslateOn, bool>(TranslateOn.new);

class TranslateOn extends Notifier<bool> {
  @override
  bool build() => Boxes.prefs.get('translate_on', defaultValue: false) == true;
  Future<void> set(bool on) async {
    state = on;
    await Boxes.prefs.put('translate_on', on);
  }
}
