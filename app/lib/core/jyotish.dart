import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'i18n.dart';
import 'location.dart';
import 'names.dart';

/// Shubha Muhurtham dates and eclipses for the chosen city, from the server or the static export
/// (backend/app/services/muhurtham.py and eclipses.py).

/// Ceremonies with published dates, in display order.
const muhurthamKinds = ['vivaha', 'griha_pravesha', 'vehicle'];

String muhurthamLabel(String lang, String kind) => switch (kind) {
  'vivaha' => t3(lang, 'Marriage (Vivaham)', 'विवाह', 'వివాహం'),
  'griha_pravesha' => t3(lang, 'House warming (Griha Pravesham)', 'गृह प्रवेश', 'గృహ ప్రవేశం'),
  _ => t3(lang, 'Vehicle purchase', 'वाहन ख़रीद', 'వాహన కొనుగోలు'),
};

String muhurthamEmoji(String kind) => switch (kind) {
  'vivaha' => '💍',
  'griha_pravesha' => '🏠',
  _ => '🚗',
};

/// One auspicious day: windows as minutes from local midnight of [date] (past 1440 after midnight).
class MuhurthamDay {
  MuhurthamDay(this.kind, Map m)
    : date = DateTime.parse('${m['d']}'),
      windows = [for (final w in m['w'] as List) ((w as List)[0] as int, w[1] as int)],
      nakshatras = (m['n'] as List).cast<int>(),
      tithis = (m['t'] as List).cast<int>(),
      lagna = m['l'] == null ? null : ((m['l'] as List)[0] as int, (m['l'] as List)[1] as int, (m['l'] as List)[2] as int);

  final String kind;
  final DateTime date;
  final List<(int, int)> windows;
  final List<int> nakshatras;

  /// 0-29: Shukla Pratipada ... Purnima (14), Krishna Pratipada ... Amavasya (29).
  final List<int> tithis;

  /// Best stretch with a recommended lagna: start, end (minutes) and sign (0 = Mesha).
  final (int, int, int)? lagna;

  DateTime at(int minutes) => date.add(Duration(minutes: minutes));
}

final muhurthamProvider = FutureProvider<Map<String, List<MuhurthamDay>>>((ref) async {
  final city = ref.watch(cityProvider);
  final data = await ref.read(apiProvider).get('/muhurtham', query: city.query) as Map;
  final kinds = data['kinds'] as Map;
  return {
    for (final k in muhurthamKinds)
      k: [for (final d in (kinds[k] as List? ?? const [])) MuhurthamDay(k, d as Map)],
  };
});

/// A solar or lunar eclipse as seen from the chosen city.
class Eclipse {
  Eclipse(Map m)
    : solar = m['kind'] == 'solar',
      type = '${m['type']}',
      localType = m['local_type'] as String?,
      date = DateTime.parse('${m['date']}'),
      visible = m['visible'] == true,
      begins = _time(m['begins']),
      max = _time(m['max']),
      ends = _time(m['ends']),
      visibleFrom = _time(m['visible_from']),
      visibleTo = _time(m['visible_to']),
      magnitude = (m['magnitude'] as num?)?.toDouble(),
      sutakStart = _time((m['sutak'] as Map?)?['starts']),
      sutakEnd = _time((m['sutak'] as Map?)?['ends']),
      contacts = {for (final e in ((m['contacts'] as Map?) ?? const {}).entries) '${e.key}': _time(e.value)!};

  final bool solar;

  /// total, annular, partial or penumbral (worldwide); [localType] is what this city sees of a solar one.
  final String type;
  final String? localType;
  final DateTime date;
  final bool visible;
  final DateTime? begins, max, ends, visibleFrom, visibleTo, sutakStart, sutakEnd;
  final double? magnitude;
  final Map<String, DateTime> contacts;

  /// Times keep the city's wall clock: the offset is dropped rather than converted to the phone's zone.
  static DateTime? _time(Object? v) => v == null ? null : DateTime.parse('$v'.substring(0, 16));

  DateTime get day => DateUtils.dateOnly(date);

  String title(String lang) {
    final kind = localType ?? type;
    if (solar) {
      return switch (kind) {
        'total' => t3(lang, 'Total solar eclipse', 'पूर्ण सूर्य ग्रहण', 'సంపూర్ణ సూర్య గ్రహణం'),
        'annular' => t3(lang, 'Annular solar eclipse', 'वलयाकार सूर्य ग्रहण', 'కంకణాకార సూర్య గ్రహణం'),
        _ => t3(lang, 'Partial solar eclipse', 'आंशिक सूर्य ग्रहण', 'పాక్షిక సూర్య గ్రహణం'),
      };
    }
    return switch (kind) {
      'total' => t3(lang, 'Total lunar eclipse', 'पूर्ण चंद्र ग्रहण', 'సంపూర్ణ చంద్ర గ్రహణం'),
      'partial' => t3(lang, 'Partial lunar eclipse', 'आंशिक चंद्र ग्रहण', 'పాక్షిక చంద్ర గ్రహణం'),
      _ => t3(lang, 'Penumbral lunar eclipse', 'उपच्छाया चंद्र ग्रहण', 'ఉపచ్ఛాయ చంద్ర గ్రహణం'),
    };
  }

  String get emoji => solar ? '🌘' : '🌕';

  /// One line: where it is seen and Sutak.
  String note(String lang) {
    if (!visible) {
      return t3(lang, 'Not visible here. No Sutak.', 'यहाँ दिखाई नहीं देगा। सूतक नहीं।', 'ఇక్కడ కనిపించదు. సూతకం లేదు.');
    }
    final span = '${clock(lang, visibleFrom!)} – ${clock(lang, visibleTo!)}';
    if (sutakStart == null) {
      return t3(
        lang,
        'Visible here {0}. Penumbral only: no Sutak.',
        'यहाँ {0} दिखेगा। केवल उपच्छाया: सूतक नहीं।',
        'ఇక్కడ {0} కనిపిస్తుంది. ఉపచ్ఛాయ మాత్రమే: సూతకం లేదు.',
      ).replaceAll('{0}', span);
    }
    return t3(
      lang,
      'Visible here {0}. Sutak from {1}.',
      'यहाँ {0} दिखेगा। सूतक {1} से।',
      'ఇక్కడ {0} కనిపిస్తుంది. సూతకం {1} నుండి.',
    ).replaceAll('{0}', span).replaceAll('{1}', dayClock(lang, sutakStart!, date));
  }
}

/// "6:20 AM" in English, 24-hour elsewhere (as Indian-language calendars print it).
String clock(String lang, DateTime t) => fmtDate(lang, lang == 'en' ? 'h:mm a' : 'HH:mm', t);

/// [clock], with the date when it falls on another day than [day].
String dayClock(String lang, DateTime t, DateTime day) =>
    DateUtils.isSameDay(t, day) ? clock(lang, t) : '${fmtDate(lang, 'd MMM', t)}, ${clock(lang, t)}';

final eclipsesProvider = FutureProvider<List<Eclipse>>((ref) async {
  final city = ref.watch(cityProvider);
  final data = await ref.read(apiProvider).get('/eclipses', query: city.query) as List;
  return [for (final e in data) Eclipse(e as Map)];
});

/// Eclipses by local date, for calendar markers and the day page.
final eclipsesByDayProvider = Provider<Map<DateTime, List<Eclipse>>>((ref) {
  final out = <DateTime, List<Eclipse>>{};
  for (final e in ref.watch(eclipsesProvider).value ?? const <Eclipse>[]) {
    out.putIfAbsent(e.day, () => []).add(e);
  }
  return out;
});
