import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'storage.dart';
import 'temples.dart' show loc;

/// Step-by-step pooja guides (assets/data/pooja_guides.json, built by tool/pooja/build_guides.py).
/// Text is English, Hindi and Telugu in the file; the other languages translate the English through
/// lib/l10n/<code>_pooja.dart. Mantras are Devanagari, shown in the reader's script with scriptFor.
class PoojaGuide {
  PoojaGuide(this._j, this._mantras);
  final Map _j;
  final Map _mantras;

  String get id => '${_j['id']}';
  String get emoji => '${_j['emoji'] ?? '🪔'}';
  String title(String lang) => loc(_j['title'], lang);
  String summary(String lang) => loc(_j['summary'], lang);
  String when(String lang) => loc(_j['when'], lang);
  List<String> samagri(String lang) => [for (final s in _j['samagri'] as List) loc(s, lang)];
  int get samagriCount => (_j['samagri'] as List).length;

  List<PoojaStep> get steps => [
    for (final s in (_j['steps'] as List).cast<Map>())
      PoojaStep(s, s['mantra'] == null ? null : PoojaMantra(_mantras[s['mantra']] as Map)),
  ];

  /// Festival slugs or recurring kinds this guide is for ("diwali", "ekadashi"...).
  List<String> get match => (_j['match'] as List).cast<String>();
  bool covers(Festival f) => match.contains(f.slug) || match.contains(f.kind);
}

class PoojaStep {
  PoojaStep(this._j, this.mantra);
  final Map _j;
  final PoojaMantra? mantra;
  String title(String lang) => loc(_j['title'], lang);
  String text(String lang) => loc(_j['text'], lang);
}

class PoojaMantra {
  PoojaMantra(this._j);
  final Map _j;

  /// Devanagari; pass through scriptFor for the reader.
  String get sanskrit => '${_j['sa']}';
  String title(String lang) => loc(_j['title'], lang);
  String meaning(String lang) => loc(_j['meaning'], lang);
}

class PoojaGuides {
  PoojaGuides(Map j) : guides = [for (final g in (j['guides'] as List).cast<Map>()) PoojaGuide(g, j['mantras'] as Map)];
  final List<PoojaGuide> guides;

  PoojaGuide? byId(String id) => guides.where((g) => g.id == id).firstOrNull;

  /// The guide for a festival on the calendar, if there is one.
  PoojaGuide? forFestival(Festival f) => guides.where((g) => g.covers(f)).firstOrNull;
}

final poojaGuidesProvider = FutureProvider<PoojaGuides>(
  (ref) async => PoojaGuides(jsonDecode(await rootBundle.loadString('assets/data/pooja_guides.json')) as Map),
);

/// Which samagri items are ticked, per guide, kept on the phone.
class SamagriChecks extends Notifier<Map<String, Set<int>>> {
  static const _key = 'pooja_samagri';

  @override
  Map<String, Set<int>> build() {
    final raw = Boxes.prefs.get(_key);
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is List) '${e.key}': {for (final i in e.value as List) i as int},
    };
  }

  bool isChecked(String guide, int item) => state[guide]?.contains(item) ?? false;

  Future<void> toggle(String guide, int item) async {
    final set = {...?state[guide]};
    set.contains(item) ? set.remove(item) : set.add(item);
    await _save({...state, guide: set});
  }

  Future<void> clear(String guide) => _save({...state}..remove(guide));

  Future<void> _save(Map<String, Set<int>> next) async {
    state = next;
    await Boxes.prefs.put(_key, {for (final e in next.entries) e.key: e.value.toList()..sort()});
  }
}

final samagriChecksProvider = NotifierProvider<SamagriChecks, Map<String, Set<int>>>(SamagriChecks.new);
