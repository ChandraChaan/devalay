import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'api.dart';
import 'i18n.dart';
import 'location.dart';
import 'storage.dart';

/// State public holidays and RBI bank holidays.
///
/// The lists ship in the app (assets/data/holidays.json) and the same file is published with the
/// static API, so a corrected date reaches users without an app update: raise "version" to publish.
/// Every list carries the official source it was copied from (the state government's order or RBI's
/// holiday matrix); states and years without an official list are left out, never guessed.

/// One day off in a state. [public] when the state government lists it, [bank] when RBI does.
class StateHoliday {
  const StateHoliday(this.date, this.name, {this.public = false, this.bank = false});
  final DateTime date;
  final String name;
  final bool public, bank;

  String label(String lang) => translate(lang, name) ?? name;

  /// "Public holiday", "Bank holiday" or both.
  String kindLabel(String lang) => public && bank
      ? t3(lang, 'Public and bank holiday', 'सार्वजनिक व बैंक अवकाश', 'ప్రభుత్వ, బ్యాంకు సెలవు')
      : public
      ? t3(lang, 'Public holiday', 'सार्वजनिक अवकाश', 'ప్రభుత్వ సెలవు')
      : t3(lang, 'Bank holiday', 'बैंक अवकाश', 'బ్యాంకు సెలవు');
}

class HolidayList {
  HolidayList(Map json)
    : year = json['year'] as int,
      kind = '${json['kind']}',
      source = '${json['source'] ?? ''}',
      amendments = [for (final a in json['amendments'] as List? ?? const []) '$a'],
      days = [for (final d in json['days'] as List) (date: DateTime.parse('${(d as List)[0]}'), name: '${d[1]}')];
  final int year;

  /// "public" or "bank".
  final String kind;
  final String source;

  /// Later official orders already applied to [days] (a moved Bakrid, an added holiday).
  final List<String> amendments;
  final List<({DateTime date, String name})> days;
}

class HolidayCatalog {
  HolidayCatalog(Map json)
    : schema = json['schema'] is int ? json['schema'] as int : 0,
      version = json['version'] is int ? json['version'] as int : 0,
      lists = {
        for (final e in (json['states'] as Map? ?? const {}).entries)
          '${e.key}': [for (final l in (e.value as Map)['lists'] as List) HolidayList(l as Map)],
      };

  /// The layout this app understands. A published file with another schema is ignored.
  static const supportedSchema = 1;

  final int schema, version;
  final Map<String, List<HolidayList>> lists;

  List<String> get states => lists.keys.toList()..sort();

  /// Holidays in [state] during [year], one per date; a day both lists name takes the state's name.
  Map<DateTime, StateHoliday> forYear(String state, int year) {
    final out = <DateTime, StateHoliday>{};
    final ordered = [...?lists[state]?.where((l) => l.year == year)]
      ..sort((a, b) => (a.kind == 'public' ? 0 : 1) - (b.kind == 'public' ? 0 : 1));
    for (final l in ordered) {
      for (final d in l.days) {
        final had = out[d.date];
        out[d.date] = StateHoliday(
          d.date,
          had?.name ?? d.name,
          public: (had?.public ?? false) || l.kind == 'public',
          bank: (had?.bank ?? false) || l.kind == 'bank',
        );
      }
    }
    return out;
  }

  /// The official sources for [state] in [year], for the "Source" line.
  List<String> sources(String state, int year) => [
    for (final l in lists[state] ?? const <HolidayList>[])
      if (l.year == year) ...[if (l.source.isNotEmpty) l.source, ...l.amendments],
  ];
}

Future<HolidayCatalog> loadBundledHolidays() async =>
    HolidayCatalog(jsonDecode(await rootBundle.loadString('assets/data/holidays.json')) as Map);

/// The bundled lists at once, then the published ones if they are newer.
final holidayCatalogProvider = StreamProvider<HolidayCatalog>((ref) async* {
  final bundled = await loadBundledHolidays();
  yield bundled;
  try {
    final remote = HolidayCatalog(await ref.read(apiProvider).get('/holidays') as Map);
    if (remote.schema == HolidayCatalog.supportedSchema && remote.version > bundled.version) yield remote;
  } catch (_) {
    // Offline, or a server without the file: the bundled copy stays.
  }
});

/// The state whose holidays are shown: the Settings choice, else the Panchang city's state.
/// "none" turns state holidays off; cities outside India have none.
final holidayStateProvider = Provider<String?>((ref) {
  ref.watch(prefsProvider);
  final city = ref.watch(cityProvider);
  final choice = Boxes.prefs.get('holiday_state') as String?;
  if (choice == 'none') return null;
  if (choice != null && choice.isNotEmpty) return choice;
  return city.state.isEmpty ? null : city.state;
});

/// The chosen state's holidays in [year], by date.
final stateHolidaysProvider = Provider.family<Map<DateTime, StateHoliday>, int>((ref, year) {
  final state = ref.watch(holidayStateProvider);
  final catalog = ref.watch(holidayCatalogProvider).value;
  if (state == null || catalog == null) return const {};
  return catalog.forYear(state, year);
});

/// State and union territory names, by the codes in holidays.json and location.dart.
String stateName(String lang, String code) => switch (code) {
  'AP' => t3(lang, 'Andhra Pradesh', 'आंध्र प्रदेश', 'ఆంధ్రప్రదేశ్'),
  'AS' => t3(lang, 'Assam', 'असम', 'అస్సాం'),
  'BR' => t3(lang, 'Bihar', 'बिहार', 'బీహార్'),
  'CH' => t3(lang, 'Chandigarh', 'चंडीगढ़', 'చండీగఢ్'),
  'CT' => t3(lang, 'Chhattisgarh', 'छत्तीसगढ़', 'ఛత్తీస్‌గఢ్'),
  'DL' => t3(lang, 'Delhi', 'दिल्ली', 'ఢిల్లీ'),
  'GA' => t3(lang, 'Goa', 'गोवा', 'గోవా'),
  'GJ' => t3(lang, 'Gujarat', 'गुजरात', 'గుజరాత్'),
  'HP' => t3(lang, 'Himachal Pradesh', 'हिमाचल प्रदेश', 'హిమాచల్ ప్రదేశ్'),
  'HR' => t3(lang, 'Haryana', 'हरियाणा', 'హర్యానా'),
  'JH' => t3(lang, 'Jharkhand', 'झारखंड', 'ఝార్ఖండ్'),
  'JK' => t3(lang, 'Jammu and Kashmir', 'जम्मू और कश्मीर', 'జమ్మూ కాశ్మీర్'),
  'KA' => t3(lang, 'Karnataka', 'कर्नाटक', 'కర్ణాటక'),
  'KL' => t3(lang, 'Kerala', 'केरल', 'కేరళ'),
  'MH' => t3(lang, 'Maharashtra', 'महाराष्ट्र', 'మహారాష్ట్ర'),
  'ML' => t3(lang, 'Meghalaya', 'मेघालय', 'మేఘాలయ'),
  'MN' => t3(lang, 'Manipur', 'मणिपुर', 'మణిపూర్'),
  'MP' => t3(lang, 'Madhya Pradesh', 'मध्य प्रदेश', 'మధ్యప్రదేశ్'),
  'OD' => t3(lang, 'Odisha', 'ओडिशा', 'ఒడిశా'),
  'PB' => t3(lang, 'Punjab', 'पंजाब', 'పంజాబ్'),
  'RJ' => t3(lang, 'Rajasthan', 'राजस्थान', 'రాజస్థాన్'),
  'TG' => t3(lang, 'Telangana', 'तेलंगाना', 'తెలంగాణ'),
  'TN' => t3(lang, 'Tamil Nadu', 'तमिलनाडु', 'తమిళనాడు'),
  'TR' => t3(lang, 'Tripura', 'त्रिपुरा', 'త్రిపుర'),
  'UK' => t3(lang, 'Uttarakhand', 'उत्तराखंड', 'ఉత్తరాఖండ్'),
  'UP' => t3(lang, 'Uttar Pradesh', 'उत्तर प्रदेश', 'ఉత్తరప్రదేశ్'),
  'WB' => t3(lang, 'West Bengal', 'पश्चिम बंगाल', 'పశ్చిమ బెంగాల్'),
  _ => code,
};
