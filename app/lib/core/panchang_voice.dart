import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

import 'audio.dart';
import 'events.dart';
import 'gita_voice.dart';
import 'i18n.dart';
import 'models.dart';
import 'muhurta.dart';
import 'names.dart';
import 'providers.dart';

/// The device text-to-speech locale for each app language.
const ttsLocales = {
  'en': 'en-IN',
  'hi': 'hi-IN',
  'bn': 'bn-IN',
  'mr': 'mr-IN',
  'te': 'te-IN',
  'ta': 'ta-IN',
  'gu': 'gu-IN',
  'kn': 'kn-IN',
  'ml': 'ml-IN',
  'or': 'or-IN',
  'pa': 'pa-IN',
};

/// A wall-clock time as it should be spoken: "6:24 AM" in English, "morning 6:24" in the others (the
/// voices read "AM" and "PM" letter by letter).
String spokenTime(String lang, int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final t = '$h12:${minute.toString().padLeft(2, '0')}';
  if (lang == 'en') return '$t ${hour >= 12 ? 'PM' : 'AM'}';
  if (hour >= 4 && hour < 12) return t3(lang, '$t in the morning', 'सुबह $t', 'ఉదయం $t');
  if (hour >= 12 && hour < 16) return t3(lang, '$t in the afternoon', 'दोपहर $t', 'మధ్యాహ్నం $t');
  if (hour >= 16 && hour < 20) return t3(lang, '$t in the evening', 'शाम $t', 'సాయంత్రం $t');
  return t3(lang, '$t at night', 'रात $t', 'రాత్రి $t');
}

/// [spokenTime] for an API time ("2026-11-13T06:24:00+05:30"), on the city's wall clock.
String spokenIso(String lang, String iso) {
  final t = wallClock(iso);
  return spokenTime(lang, t.hour, t.minute);
}

/// The sentences read aloud for [day] in [lang]: weekday and date, festivals, tithi, nakshatra,
/// sunrise and sunset, Rahu Kalam and the reader's own events. [panchang] is the full panchang when
/// it is available; otherwise [summary] (the month calendar's entry for the day) gives the basics.
List<String> daySpeech(
  String lang,
  DateTime day, {
  Map? panchang,
  Map? summary,
  List<Festival> festivals = const [],
  List<UserEvent> events = const [],
}) {
  final p = panchang;
  final s = summary;
  final out = <String>[fmtDate(lang, 'EEEE, d MMMM', day)];
  if (festivals.isNotEmpty) {
    final names = festivals.map((f) => f.label(lang)).join(', ');
    out.add(t3(lang, 'Festival: $names', 'त्योहार: $names', 'పండుగ: $names'));
  }
  String until(Object? ends) => ends == null
      ? ''
      : ', ${t3(lang, 'until ${spokenIso(lang, '$ends')}', '${spokenIso(lang, '$ends')} तक', '${spokenIso(lang, '$ends')} వరకు')}';
  if (p != null && (p['tithi'] as List?)?.isNotEmpty == true) {
    final m = (p['tithi'] as List).first as Map;
    out.add(
      '${trLang(lang, 'tithi')}: ${pakshaIn(lang, '${m['paksha']}')} ${tithiIn(lang, '${m['name']}')}${until(m['ends'])}',
    );
  } else if (s?['tithi_index'] is int) {
    out.add('${trLang(lang, 'tithi')}: ${tithiName(lang, s!['tithi_index'] as int)}');
  }
  if (p != null && (p['nakshatra'] as List?)?.isNotEmpty == true) {
    final m = (p['nakshatra'] as List).first as Map;
    out.add('${trLang(lang, 'nakshatra')}: ${nakshatraIn(lang, '${m['name']}')}${until(m['ends'])}');
  } else if (s?['nakshatra'] != null) {
    out.add('${trLang(lang, 'nakshatra')}: ${nakshatraIn(lang, '${s!['nakshatra']}')}');
  }
  final sunrise = p?['sunrise'] ?? s?['sunrise'];
  final sunset = p?['sunset'] ?? s?['sunset'];
  if (sunrise != null && sunset != null) {
    out.add(
      '${trLang(lang, 'sunrise')}: ${spokenIso(lang, '$sunrise')}. ${trLang(lang, 'sunset')}: ${spokenIso(lang, '$sunset')}',
    );
  }
  String? rahu;
  if (p?['rahu_kaal'] case final Map r) {
    rahu = _span(lang, wallClock('${r['starts']}'), wallClock('${r['ends']}'));
  } else if (sunrise != null && sunset != null) {
    final (a, b) = rahuKalam(day, wallClock('$sunrise'), wallClock('$sunset'));
    rahu = _span(lang, a, b);
  }
  if (rahu != null) out.add('${trLang(lang, 'rahu_kaal')}: $rahu');
  if (events.isNotEmpty) {
    final names = events.map((e) => e.title).join(', ');
    out.add(t3(lang, 'Your events: $names', 'आपके दिन: $names', 'మీ రోజులు: $names'));
  }
  return out;
}

String _span(String lang, DateTime a, DateTime b) {
  final from = spokenTime(lang, a.hour, a.minute);
  final to = spokenTime(lang, b.hour, b.minute);
  return t3(lang, 'from $from to $to', '$from से $to तक', '$from నుండి $to వరకు');
}

/// What happened when the reader asked for the day to be read.
enum ReadOutcome { read, englishFallback, failed }

@immutable
class PanchangVoiceState {
  const PanchangVoiceState({this.speaking = false, this.day});
  final bool speaking;
  final DateTime? day;
  bool isReading(DateTime d) => speaking && day != null && DateUtils.isSameDay(day, d);
}

/// Reads a day's Panchang aloud with the phone's own text-to-speech voice in the app language,
/// falling back to the Indian English voice when the phone has none for that language.
class PanchangVoice extends Notifier<PanchangVoiceState> {
  final _tts = FlutterTts();
  bool _configured = false;
  int _session = 0;

  @override
  PanchangVoiceState build() {
    ref.onDispose(() => _tts.stop());
    return const PanchangVoiceState();
  }

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.45);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ]);
    }
  }

  /// Whether the phone can speak [lang] (a voice is installed for it).
  Future<bool> hasVoice(String lang) async {
    final locale = ttsLocales[lang] ?? 'en-IN';
    try {
      final v = await _tts.isLanguageAvailable(locale);
      if (v != true && v != 1) return false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final installed = await _tts.isLanguageInstalled(locale);
        if (installed == false) return false;
      }
      return true;
    } catch (_) {
      return lang == 'en';
    }
  }

  /// Reads [day] aloud. [onEnglishFallback] runs before reading when the phone has no voice for the
  /// app language, so the screen can explain how to add one while the English reading plays.
  Future<ReadOutcome> read(WidgetRef ref, DateTime day, {VoidCallback? onEnglishFallback}) async {
    final session = ++_session;
    await _tts.stop();
    await _configure();
    // Do not talk over a bhajan or the Gita.
    try {
      await this.ref.read(audioProvider).player.pause();
    } catch (_) {}
    await this.ref.read(gitaVoiceProvider.notifier).stop();

    final appLanguage = uiLang(ref);
    final voiced = appLanguage == 'en' || await hasVoice(appLanguage);
    final lang = voiced ? appLanguage : 'en';
    final lines = await _lines(ref, day, lang);
    if (session != _session) return ReadOutcome.read;

    state = PanchangVoiceState(speaking: true, day: day);
    if (!voiced) onEnglishFallback?.call();
    try {
      await _tts.setLanguage(ttsLocales[lang] ?? 'en-IN');
      for (final line in lines) {
        if (session != _session) return ReadOutcome.read;
        await _tts.speak(line);
      }
    } catch (_) {
      if (session == _session) state = const PanchangVoiceState();
      return ReadOutcome.failed;
    }
    if (session == _session) state = const PanchangVoiceState();
    return voiced ? ReadOutcome.read : ReadOutcome.englishFallback;
  }

  Future<List<String>> _lines(WidgetRef ref, DateTime day, String lang) async {
    day = DateUtils.dateOnly(day);
    Map? panchang;
    try {
      panchang = await ref.read(panchangProvider(day).future);
    } catch (_) {}
    Map? summary;
    if (panchang == null) {
      try {
        final month = await ref.read(monthProvider((year: day.year, month: day.month)).future);
        final iso = DateFormat('yyyy-MM-dd').format(day);
        summary = month.where((d) => d['date'] == iso).firstOrNull;
      } catch (_) {}
    }
    var festivals = const <Festival>[];
    try {
      festivals = [
        for (final f in await ref.read(festivalsProvider(day.year).future))
          if (DateUtils.isSameDay(f.date, day)) f,
      ]..sort((a, b) => (b.major ? 1 : 0) - (a.major ? 1 : 0));
    } catch (_) {}
    final events = ref.read(eventsByDayProvider(day.year))[day] ?? const <UserEvent>[];
    return daySpeech(lang, day, panchang: panchang, summary: summary, festivals: festivals, events: events);
  }

  Future<void> stop() async {
    _session++;
    await _tts.stop();
    if (ref.mounted) state = const PanchangVoiceState();
  }
}

final panchangVoiceProvider = NotifierProvider<PanchangVoice, PanchangVoiceState>(PanchangVoice.new);
